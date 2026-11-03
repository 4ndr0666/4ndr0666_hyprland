"""Provider safety/packaging contracts; no host package changes or ARM build claims."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('provider_builds',
    Path(__file__).resolve().parents[2] / 'scripts/pi-r7-build-providers.py')
build = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(build)

class FakeRunner:
    def __init__(self, work):
        self.work, self.commands, self.env = work, [], {}
        (work / 'logs').mkdir()

    def run(self, label, argv, cwd=None):
        self.commands.append({'label': label, 'argv': [str(x) for x in argv]})
        if argv[0] == 'curl':
            Path(argv[-1]).write_bytes(b'source fixture')
        if label.endswith('-build'):
            name = label.removesuffix('-build')
            (cwd / (name + '-1-1-aarch64.pkg.tar.zst')).write_bytes(b'package fixture')
        return '[GNUPG:] VALIDSIG ' + build.FINGERPRINT + ' 2024-04-22\n'

class ProviderBuildTests(unittest.TestCase):
    def test_recipes_have_explicit_arch_and_preserve_validation(self):
        for name, recipe in build.RECIPES.items():
            subprocess.run(['bash', '-n'], input=recipe.encode(), check=True)
            self.assertIn('arch=(any)' if name.startswith('ttf-') else 'arch=(aarch64)', recipe)
            self.assertIn('sha256sums=(', recipe)
            self.assertNotIn('SKIP', recipe)
        self.assertIn('validpgpkeys=(' + build.FINGERPRINT, build.RECIPES['wlogout'])
        self.assertIn('--features themes,doc --frozen --release', build.RECIPES['wallust'])
        self.assertIn('/usr/share/licenses/ttf-victor-mono/LICENSE', build.RECIPES['ttf-victor-mono'])

    def test_inherited_build_destinations_are_removed_but_proxy_is_retained(self):
        values = {'PKGDEST': '/existing', 'LOGDEST': '/existing', 'BUILDDIR': '/existing',
                  'CARCH': 'x86_64', 'MAKEPKG_LIBRARY': '/evil', 'GIT_DIR': '/existing',
                  'BASH_ENV': '/evil', 'BASH_FUNC_install%%': 'evil',
                  'https_proxy': 'http://normal-proxy', 'SSL_CERT_FILE': '/trusted.pem'}
        with patch.dict(build.os.environ, values, clear=True):
            env = build.build_environment(Path('/private'))
        for key in values:
            if key not in {'https_proxy', 'SSL_CERT_FILE'}:
                self.assertNotIn(key, env)
        self.assertEqual(env['https_proxy'], values['https_proxy'])
        self.assertEqual(env['GNUPGHOME'], '/private/gnupg')
        self.assertEqual(env['PATH'], '/usr/bin:/bin')

    def test_config_paths_are_shell_quoted_and_build_root_is_not_nested(self):
        text = build.makepkg_config(Path("/private/space ' dir"))
        script = 'source /dev/stdin\nprintf "%s\\n" "$PKGDEST" "${BUILDDIR-unset}"'
        # Replace system defaults only inside this disposable test process.
        text = text.replace('source /etc/makepkg.conf', 'BUILDDIR=/inherited')
        result = subprocess.run(['bash', '-c', script], input=text, text=True,
                                capture_output=True, check=True)
        self.assertEqual(result.stdout.splitlines(), ["/private/space ' dir", 'unset'])

    def test_low_resources_stop_before_source_or_privileged_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(Path(directory))
            with patch.object(build.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 0})()):
                with self.assertRaisesRegex(RuntimeError, '6 GiB'):
                    build.collect(runner, {})
            self.assertEqual(runner.commands, [])

    def test_source_hash_mismatch_stops_before_dependency_transaction(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(Path(directory))
            with patch.object(build.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 8 * 1024**3})()):
                with self.assertRaisesRegex(RuntimeError, 'Source hash mismatch'):
                    build.collect(runner, {})
            self.assertFalse(any(c['argv'][0] == 'sudo' for c in runner.commands))

    def test_bad_signer_stops_before_dependency_transaction(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(Path(directory))
            original = runner.run
            def run(label, argv, cwd=None):
                text = original(label, argv, cwd)
                return 'VALIDSIG WRONG' if label == 'wlogout-signature' else text
            runner.run = run
            def source_hash(path):
                return build.SOURCES[path.name][1]
            with patch.object(build.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 8 * 1024**3})()), patch.object(build, 'sha', side_effect=source_hash):
                with self.assertRaisesRegex(RuntimeError, 'Unexpected release signing key'):
                    build.collect(runner, {})
            self.assertFalse(any(c['argv'][0] == 'sudo' for c in runner.commands))

    def test_success_only_builds_packages_and_keeps_normal_pacman_confirmation(self):
        with tempfile.TemporaryDirectory() as directory:
            runner, report = FakeRunner(Path(directory)), {}
            def source_hash(path):
                return build.SOURCES[path.name][1]
            with patch.object(build.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 8 * 1024**3})()), patch.object(build, 'sha', side_effect=source_hash), patch.object(build, 'inspect_package', return_value={'status': 'fixture'}):
                build.collect(runner, report)
            self.assertEqual(report['status'], 'NATIVE_PACKAGES_BUILT_REVIEW_REQUIRED')
            privileged = [c['argv'] for c in runner.commands if c['argv'][0] == 'sudo']
            self.assertEqual(privileged, [['sudo', 'pacman', '-Syu', '--needed', '--', *build.DEPENDENCIES]])
            builds = [c['argv'] for c in runner.commands if c['argv'][0] == 'makepkg']
            self.assertEqual(len(builds), 3)
            for argv in builds:
                self.assertFalse(set(argv) & {'-A', '--ignorearch', '--skipinteg', '--skippgpcheck', '-i', '--install', '-s', '--syncdeps'})
            self.assertFalse(any('install.sh' in ' '.join(c['argv']) for c in runner.commands))

    def test_mislabeled_x86_binary_cannot_pass_aarch64_package_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(Path(directory))
            runner.run = lambda *a, **k: 'pkgname = wallust\narch = aarch64\n'
            raw = b'\x7fELF\x02\x01' + b'\0' * 12 + (62).to_bytes(2, 'little')
            proc = subprocess.CompletedProcess([], 0, raw, b'')
            with patch.object(build.subprocess, 'run', return_value=proc):
                with self.assertRaisesRegex(RuntimeError, 'not little-endian AArch64'):
                    build.inspect_package(runner, 'wallust', Path(directory) / 'fixture.pkg.tar.zst')

    def test_network_state_change_stops_before_any_build(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(Path(directory))
            original = runner.run
            def run(label, argv, cwd=None):
                text = original(label, argv, cwd)
                return 'ActiveState=inactive' if label == 'network-after-dependencies' else text
            runner.run = run
            with patch.object(build.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 8 * 1024**3})()), patch.object(build, 'sha', side_effect=lambda p: build.SOURCES[p.name][1]):
                with self.assertRaisesRegex(RuntimeError, 'Network unit state changed'):
                    build.collect(runner, {})
            self.assertFalse(any(c['argv'][0] == 'makepkg' for c in runner.commands))

    def test_wrong_package_identity_is_rejected_before_elf_check(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(Path(directory))
            runner.run = lambda *a, **k: 'pkgname = another-package\narch = aarch64\n'
            with self.assertRaisesRegex(RuntimeError, 'Unexpected package name'):
                build.inspect_package(runner, 'wallust', Path(directory) / 'fixture.pkg.tar.zst')

    def test_repeated_package_metadata_retains_all_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(Path(directory))
            runner.run = lambda *a, **k: 'pkgname = ttf-victor-mono\narch = any\ndepend = first\ndepend = second\ndepend = third\n'
            package = Path(directory) / 'fixture.pkg.tar.zst'
            package.write_bytes(b'fixture')
            result = build.inspect_package(runner, 'ttf-victor-mono', package)
            self.assertEqual(result['metadata']['depend'], ['first', 'second', 'third'])

    def test_evidence_excludes_sources_keys_cache_and_built_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory) / 'providers-test'
            work.mkdir()
            (work / 'logs').mkdir()
            (work / 'logs/probe.combined').write_text('actual probe output')
            for name in ['sources/private', 'gnupg/private', 'cargo/private', 'wallust/package.pkg.tar.zst']:
                path = work / name
                path.parent.mkdir(exist_ok=True)
                path.write_text('excluded payload')
            with patch('sys.stdout', new=io.StringIO()):
                build.seal(work, {'status': 'BLOCKED'})
            with build.tarfile.open(work.with_suffix('.tar.gz')) as archive:
                names = set(archive.getnames())
                self.assertEqual(names, {'report.json', 'logs/probe.combined', 'SHA256SUMS'})
                for line in archive.extractfile('SHA256SUMS').read().decode().splitlines():
                    expected, name = line.split('  ', 1)
                    self.assertEqual(hashlib.sha256(archive.extractfile(name).read()).hexdigest(), expected)

if __name__ == '__main__':
    unittest.main()
