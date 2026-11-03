"""Package-stage ordering and preservation gates; all privileged commands mocked."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('package_installation',
    Path(__file__).resolve().parents[2] / 'scripts/pi-r7-install-packages.py')
stage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stage)

def units(nm='inactive', installed=False, backend='active'):
    return '\n\n'.join('Id=' + name + '\nActiveState=' + (nm if name == stage.UNITS[-1] else backend) +
                       '\nUnitFileState=' + ('disabled' if installed else '') if name == stage.UNITS[-1]
                       else 'Id=' + name + '\nActiveState=' + backend + '\nUnitFileState=enabled'
                       for name in stage.UNITS)

class Fixture:
    def __init__(self, root):
        self.work = root / 'evidence'
        self.work.mkdir()
        (self.work / 'logs').mkdir()
        self.source = root / 'predeploy-fixture/source'
        (self.source / '.git').mkdir(parents=True)
        self.commands = []
        self.manifest = ''.join(group + '=(\n' +
            (' '.join([*stage.PACKAGES, *['p' + str(i) for i in range(59)]]) + '\n' if i == 0 else '') + ')\n'
            for i, group in enumerate(stage.GROUPS))
        self.packages = {}
        for name in stage.PACKAGES:
            path = root / 'providers-fixture' / name / (name + '.pkg.tar.xz')
            path.parent.mkdir(parents=True)
            path.write_bytes(b'fixture package')
            self.packages[name] = (path.name, stage.sha(path))
        self.responses = {}

    def run(self, label, argv):
        self.commands.append([str(x) for x in argv])
        value = self.responses.get(label)
        if value is None:
            if label.startswith('source-head-'):
                value = stage.COMMIT
            elif label == 'source-tree':
                value = stage.TREE
            elif label == 'canonical-manifest':
                value = self.manifest
            elif label.startswith('network-'):
                value = units(installed=label != 'network-before')
            elif label == 'kernel-before':
                value = '7.3.1-2-aarch64-ARCH'
            elif label == 'kernel-ownership-before':
                value = '/usr/lib/modules/7.3.1-2-aarch64-ARCH/kernel/'
            elif label.startswith('refs-'):
                value = 'stable fixture refs'
            else:
                value = ''
        (self.work / 'logs' / (label + '.combined')).write_text(value)
        return value.strip()

    def git(self, source, label, *args):
        return self.run(label, ['git', '-C', source, *args])

class InstallationTests(unittest.TestCase):
    def collect(self, fixture, state, report):
        original = Path.is_dir
        with patch.object(stage, 'PACKAGES', fixture.packages), patch.object(stage, 'MANIFEST', hashlib.sha256(fixture.manifest.encode()).hexdigest()), patch.object(Path, 'is_dir', lambda p: str(p) == '/usr/lib/modules/7.3.1-2-aarch64-ARCH' or original(p)):
            stage.collect(fixture, state, report)

    def test_success_has_two_confirmed_package_transactions_and_no_deployment(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            fixture, report = Fixture(state), {}
            self.collect(fixture, state, report)
            privileged = [a for a in fixture.commands if a[0] == 'sudo']
            self.assertEqual(len(privileged), 2)
            self.assertEqual(privileged[0][:5], ['sudo', 'pacman', '-Syu', '--needed', '--'])
            self.assertEqual(privileged[1][:5], ['sudo', 'pacman', '-U', '--needed', '--'])
            self.assertFalse(any('--noconfirm' in a for a in privileged))
            self.assertEqual(report['status'], 'PACKAGES_INSTALLED_CONFIGURATION_PENDING')
            for argv in fixture.commands:
                self.assertFalse(set(argv) & {'enable', 'start', 'stop', 'disable', 'reboot', '--ignorearch', '--skippgpcheck'})
                self.assertNotIn('install.sh', ' '.join(argv))
            probe = next(a for a in fixture.commands if a[:2] == ['python3', '-c'])
            self.assertNotIn('NM.Client(', probe[-1])

    def test_modified_local_bytes_stop_before_any_privileged_transaction(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            fixture = Fixture(state)
            next(state.glob('providers-*/wallust/*')).write_bytes(b'changed after build')
            with self.assertRaisesRegex(RuntimeError, 'Missing or modified reviewed local package'):
                self.collect(fixture, state, {})
            self.assertFalse(any(a[0] == 'sudo' for a in fixture.commands))

    def test_dirty_user_checkout_is_preserved_and_blocks_install(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            fixture = Fixture(state)
            fixture.responses['source-clean-before'] = ' M user-owned-file'
            with self.assertRaisesRegex(RuntimeError, 'user changes'):
                self.collect(fixture, state, {})
            self.assertFalse(any(a[0] == 'sudo' for a in fixture.commands))

    def test_manifest_pin_mismatch_stops_before_privilege(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            fixture = Fixture(state)
            fixture.responses['canonical-manifest'] = fixture.manifest + '# changed\n'
            with self.assertRaisesRegex(RuntimeError, 'Manifest pin mismatch'):
                self.collect(fixture, state, {})
            self.assertFalse(any(a[0] == 'sudo' for a in fixture.commands))

    def test_networkmanager_activation_stops_before_local_package_install(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            fixture = Fixture(state)
            fixture.responses['network-after-sync'] = units(nm='active', installed=True)
            with self.assertRaisesRegex(RuntimeError, 'NetworkManager became active'):
                self.collect(fixture, state, {})
            self.assertEqual(len([a for a in fixture.commands if a[0] == 'sudo']), 1)

    def test_inactive_new_networkmanager_unit_is_allowed_without_backend_change(self):
        stage.preserve_network(stage.network_state(units()), stage.network_state(units(installed=True)))
        with self.assertRaisesRegex(RuntimeError, 'Existing network backend'):
            stage.preserve_network(stage.network_state(units()), stage.network_state(units(backend='inactive')))

    def test_missing_unit_observation_is_not_treated_as_preservation(self):
        with self.assertRaisesRegex(RuntimeError, 'Incomplete network'):
            stage.network_state('Id=NetworkManager.service\nActiveState=inactive')

    def test_environment_isolates_git_and_python_injection_but_keeps_transport(self):
        values = {'GIT_DIR': '/user-repo', 'PYTHONPATH': '/user-injection', 'BASH_ENV': '/user-script',
                  'https_proxy': 'http://normal-proxy', 'SSL_CERT_FILE': '/trusted'}
        with patch.dict(stage.os.environ, values, clear=True):
            env = stage.environment()
        for key in ['GIT_DIR', 'PYTHONPATH', 'BASH_ENV']:
            self.assertNotIn(key, env)
        self.assertEqual(env['https_proxy'], values['https_proxy'])
        self.assertEqual(env['PATH'], '/usr/bin:/bin')

if __name__ == '__main__':
    unittest.main()
