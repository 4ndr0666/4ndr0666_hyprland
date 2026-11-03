"""No real mount, mkfs, loop allocation, package transaction or disk write."""
import argparse
import contextlib
import copy
import hashlib
import io
import json
import os
import pty
import select
import signal
import time
import fcntl
import termios
from pathlib import Path
import subprocess
import tarfile
import tempfile
import types
import unittest
from unittest.mock import patch, mock_open

SCRIPT = Path(__file__).resolve().parents[2] / 'install_arch-pi4.sh'
SOURCE = SCRIPT.read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
app = types.ModuleType('provision_under_test')
exec(compile(SOURCE, str(SCRIPT), 'exec'), app.__dict__)


def regular(name, data):
    item = tarfile.TarInfo(name)
    item.size = len(data)
    return item, data


class ProvisionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        capacity = patch.object(app.shutil, 'disk_usage', return_value=types.SimpleNamespace(free=1024**4))
        capacity.start(); self.addCleanup(capacity.stop)
        self.key = self.root / 'key'
        subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(self.key)], check=True)
        self.pw = self.root / 'pw'
        self.pw.write_text('$6$testsalt$' + 'A' * 86 + '\n')
        self.pw.chmod(0o600)
        self.bundle = self.root / 'source.bundle'
        # Plan deliberately verifies header/prerequisites only; build must clone/fsck.
        self.bundle.write_bytes(('# v2 git bundle\n' + app.R6[0] + ' refs/heads/recovery\n\n').encode())
        self.archive = self.root / 'rootfs.tar.gz'
        elf = b'\x7fELF\x02\x01' + b'\0' * 12 + b'\xb7\x00'
        self.entries = [regular(n, b'x') for n in ['etc/passwd', 'etc/shadow', 'etc/group', 'etc/os-release', 'usr/bin/pacman', 'usr/bin/sudo']]
        self.entries += [regular('usr/bin/bash', elf), regular('boot/cmdline.txt', b'console=tty1 root=/dev/mmcblk0p2 rw\n')]
        self.make_archive()

    def make_archive(self, entries=None):
        with tarfile.open(self.archive, 'w:gz') as archive:
            for item, data in self.entries if entries is None else entries:
                item = copy.copy(item)
                if item.isfile():
                    item.size = len(data)
                archive.addfile(item, io.BytesIO(data) if item.isfile() else None)

    def args(self, **changes):
        args = argparse.Namespace(output=str(self.root / 'new.img'), size_gib=8,
             rootfs=str(self.archive), rootfs_sha256=app.digest(self.archive),
             bundle=str(self.bundle), baseline='r6', ssh_key=str(self.key) + '.pub',
             password_hash_file=str(self.pw), root_password_hash_file=None,
             wifi_ssid='', wifi_password_file=None, autologin=False)
        for key, value in changes.items():
            setattr(args, key, value)
        return args

    def test_default_help_and_explicit_modes(self):
        with contextlib.redirect_stdout(io.StringIO()), patch.object(app, 'run', side_effect=AssertionError('unexpected subprocess')):
            self.assertEqual(app.main([]), 0)
        with self.assertRaises(app.Refusal):
            app.parse(['--build'])
        with self.assertRaises(app.Refusal):
            app.parse(['--flash', 'a.img'])

    def test_read_only_plan_and_hash_refusal(self):
        before = set(self.root.rglob('*'))
        report = app.plan(self.args())
        self.assertEqual(set(self.root.rglob('*')), before)
        self.assertEqual(report['commit'], app.R6[0])
        self.assertFalse(report['auto_upgrade'])
        self.assertIn('NOT_CERTIFIED', report['certification'])
        with self.assertRaises(app.Refusal):
            app.plan(self.args(rootfs_sha256='0' * 64))

    def test_output_never_overwritten_and_capacity_checked(self):
        target = self.root / 'new.img'
        target.write_bytes(b'USER DATA')
        with self.assertRaises(app.Refusal):
            app.plan(self.args())
        self.assertEqual(target.read_bytes(), b'USER DATA')
        target.unlink()
        with patch.object(app.shutil, 'disk_usage', return_value=types.SimpleNamespace(free=1)):
            with self.assertRaises(app.Refusal):
                app.plan(self.args())

    def test_archive_rejects_traversal_specials_duplicates_and_wrong_arch(self):
        bads = [self.entries + [regular('../escape', b'bad')], self.entries + [self.entries[0]]]
        special = tarfile.TarInfo('dev/evil'); special.type = tarfile.CHRTYPE
        bads.append(self.entries + [(special, b'')])
        bads.append([(i, b'not ELF' if i.name == 'usr/bin/bash' else data) for i, data in self.entries])
        for entries in bads:
            self.make_archive(entries)
            with self.assertRaises(app.Refusal):
                app.archive_inventory(self.archive)

    def test_archive_rejects_symlink_parent_and_unsafe_hardlink(self):
        link = tarfile.TarInfo('escape'); link.type = tarfile.SYMTYPE; link.linkname = '/etc'
        self.make_archive(self.entries + [(link, b''), regular('escape/hosts', b'evil')])
        with self.assertRaises(app.Refusal):
            app.archive_inventory(self.archive)
        hard = tarfile.TarInfo('hard'); hard.type = tarfile.LNKTYPE; hard.linkname = '../outside'
        self.make_archive(self.entries + [(hard, b'')])
        with self.assertRaises(app.Refusal):
            app.archive_inventory(self.archive)

    def test_secret_permissions_and_wifi_encoding(self):
        self.pw.chmod(0o644)
        with self.assertRaises(app.Refusal):
            app.private_text(self.pw)
        config = app.wifi_config('IEEE', 'password')
        self.assertIn('f42c6fc52df0ebef9ebb4b90b38a5f902e83fe1b135a70e23aed762e9710a12e', config)
        self.assertNotIn('password', config)
        config = app.wifi_config('a"b\\c', 'validpass')
        self.assertIn('ssid=6122625c63', config)
        for ssid, password in [('bad\nssid', 'password'), ('X', 'short'), ('X' * 33, 'password')]:
            with self.assertRaises(app.Refusal):
                app.wifi_config(ssid, password)

    def test_incremental_or_wrong_source_bundles_rejected(self):
        for content in ['# v2 git bundle\n-' + '0' * 40 + ' prerequisite\n\n',
                        '# v2 git bundle\n' + '0' * 40 + ' refs/heads/main\n\n', 'broken']:
            self.bundle.write_text(content)
            with self.assertRaises(app.Refusal):
                app.plan(self.args())

    def test_split_bundle_is_verified_and_joined_without_operator_commands(self):
        source = self.root / 'downloads'; source.mkdir()
        cache = self.root / 'state'; cache.mkdir()
        first, second = b'first bundle bytes', b'second bundle bytes'
        whole = first + second
        names = ('gup-source-r6.bundle.part.00', 'gup-source-r6.bundle.part.01')
        for name, content in zip(names, (first, second)):
            (source / name).write_bytes(content)
        specification = {'name': 'gup-source-r6.bundle', 'sha256': hashlib.sha256(whole).hexdigest(),
            'parts': tuple((name, len(content), hashlib.sha256(content).hexdigest())
                           for name, content in zip(names, (first, second)))}
        evidence = cache / 'evidence.json'
        ui = types.SimpleNamespace(folder=cache, uid=os.getuid(), gid=os.getgid(), saved={},
             roots=lambda: [source], find_files=lambda patterns: [], say=lambda message='': None,
             private_file=lambda label, text: (evidence.write_text(text), str(evidence))[1], save=lambda: None)
        with patch.dict(app.SPLIT_BUNDLES, {'r6': specification}, clear=True):
            result = Path(app.assemble_supplied_bundle(ui, 'r6'))
            self.assertEqual(result.read_bytes(), whole)
            self.assertEqual(app.select_source_bundle(ui, 'r6'), str(result))
        self.assertEqual(json.loads(evidence.read_text())['sha256'], specification['sha256'])

    def test_split_bundle_damage_is_rejected_before_joining(self):
        source = self.root / 'downloads'; source.mkdir()
        cache = self.root / 'state'; cache.mkdir()
        name = 'gup-source-r6.bundle.part.00'
        (source / name).write_bytes(b'damaged')
        specification = {'name': 'gup-source-r6.bundle', 'sha256': hashlib.sha256(b'good').hexdigest(),
                         'parts': ((name, 4, hashlib.sha256(b'good').hexdigest()),)}
        ui = types.SimpleNamespace(folder=cache, roots=lambda: [source], say=lambda message='': None)
        with patch.dict(app.SPLIT_BUNDLES, {'r6': specification}, clear=True):
            with self.assertRaises(app.Refusal):
                app.assemble_supplied_bundle(ui, 'r6')
        self.assertFalse(list(cache.glob('gup-source-r6.bundle.*')))

    def test_rootfs_without_sudo_needs_explicit_recovery_root(self):
        self.make_archive([(i, data) for i, data in self.entries if i.name != 'usr/bin/sudo'])
        with self.assertRaises(app.Refusal):
            app.plan(self.args())
        root_pw = self.root / 'root-pw'; root_pw.write_text('$6$rootsalt$' + 'B' * 86); root_pw.chmod(0o600)
        self.assertEqual(app.plan(self.args(root_password_hash_file=str(root_pw)))['baseline'], 'r6')

    def make_root(self, root=None):
        root = root or self.root / 'stage'; root.mkdir(exist_ok=True)
        files = {'etc/passwd': 'root:x:0:0:root:/root:/bin/bash\nalarm:x:1000:1000::/home/alarm:/bin/bash\n',
                 'etc/shadow': 'root:default:1:0:99999:7:::\nalarm:default:1:0:99999:7:::\n',
                 'etc/group': 'root:x:0:\nwheel:x:10:\n', 'etc/os-release': 'ID=archarm\n',
                 'usr/bin/sudo': 'fixture', 'etc/ssh/sshd_config': '# fixture\n',
                 'etc/ssh/ssh_host_ed25519_key': 'OLD HOST KEY',
                 'etc/machine-id': 'OLD ID', 'var/lib/dbus/machine-id': 'OLD ID'}
        for name in ['sshd.service', 'systemd-networkd.service', 'systemd-resolved.service', 'wpa_supplicant@.service']:
            files['usr/lib/systemd/system/' + name] = '[Service]\n'
        for name, content in files.items():
            target = root / name; target.parent.mkdir(parents=True, exist_ok=True); target.write_text(content)
        return root

    def test_generated_config_auth_network_and_real_runner_paths(self):
        root = self.make_root()
        report = {'commit': app.R6[0], 'tree': app.R6[1]}
        with patch.object(app.os, 'chown'):
            app.configure(root, self.args(), report, '12345678-02', '12345678-01')
        self.assertIn('alarm:$6$testsalt$', (root / 'etc/shadow').read_text())
        self.assertIn('root:!:', (root / 'etc/shadow').read_text())
        self.assertIn('PasswordAuthentication no', (root / 'etc/ssh/sshd_config').read_text())
        self.assertFalse((root / 'etc/ssh/ssh_host_ed25519_key').exists())
        self.assertFalse((root / 'etc/systemd/system/getty@tty1.service.d/autologin.conf').exists())
        self.assertIn('Name=en* eth*', (root / 'etc/systemd/network/20-gup-ethernet.network').read_text())
        self.assertEqual(os.readlink(root / 'etc/resolv.conf'), '/run/systemd/resolve/stub-resolv.conf')
        self.assertIn('tests/unit/run-golden-units.sh', (root / 'usr/local/bin/gup-validate-source').read_text())
        self.assertNotIn('pacman -S', (root / 'usr/local/lib/gup/firstboot.sh').read_text())
        self.assertEqual((root / 'etc/machine-id').read_text(), '')
        for name in ['usr/local/lib/gup/firstboot.sh', 'usr/local/sbin/gup-upgrade-base', 'usr/local/bin/gup-validate-source', 'usr/local/bin/gup-runtime-check']:
            result = subprocess.run(['bash', '-n', str(root / name)], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_safe_configuration_paths_reject_escape(self):
        root = self.make_root()
        (root / 'escape').symlink_to(self.root)
        with self.assertRaises(app.Refusal):
            app.write(root, 'escape/out', 'bad')
        with self.assertRaises(app.Refusal):
            app.write(root, '../out', 'bad')
        path = root / 'etc/trap'; path.symlink_to(self.root / 'outside')
        with self.assertRaises(app.Refusal):
            app.write(root, 'etc/trap', 'bad')

    def test_boot_argument_preservation_and_ambiguous_layout_refusal(self):
        root = self.make_root(); boot = root / 'boot'; boot.mkdir()
        (boot / 'cmdline.txt').write_text('console=tty1 root=/dev/mmcblk0p2 rw quiet\n')
        app.patch_boot(root, '12345678-02', [])
        self.assertEqual((boot / 'cmdline.txt').read_text(), 'console=tty1 root=PARTUUID=12345678-02 rw quiet\n')
        (boot / 'cmdline.txt').write_text('root=a root=b\n')
        with self.assertRaises(app.Refusal):
            app.patch_boot(root, '12345678-02', [])
        (boot / 'cmdline.txt').unlink()
        (boot / 'boot.txt').write_text('setenv bootargs console=tty1 root=/dev/mmcblk0p2 rw\n')
        with patch.object(app, 'executable_tools'), patch.object(app, 'run', return_value='') as run:
            app.patch_boot(root, '12345678-02', [])
            self.assertEqual(run.call_args.args[0][0], 'mkimage')

    def inventory(self):
        return {'blockdevices': [{'path': '/dev/test-card', 'type': 'disk', 'size': 16000000000,
                 'ro': False, 'mountpoints': [], 'children': [{'path': '/dev/test-card1', 'type': 'part', 'mountpoints': []}]}]}

    def test_disk_policy_mounted_swap_ro_partition_mapper_capacity(self):
        self.assertEqual(app.validate_target('/dev/test-card', 100, self.inventory(), set())['type'], 'disk')
        variants = []
        for field, value in [('ro', True), ('type', 'part'), ('type', 'loop'), ('size', 1)]:
            inv = self.inventory(); inv['blockdevices'][0][field] = value; variants.append((inv, set()))
        inv = self.inventory(); inv['blockdevices'][0]['children'][0]['mountpoints'] = ['/sto2']; variants.append((inv, set()))
        inv = self.inventory(); inv['blockdevices'][0]['children'][0]['type'] = 'crypt'; variants.append((inv, set()))
        variants.append((self.inventory(), {'/dev/test-card1'}))
        for inv, swaps in variants:
            with self.assertRaises(app.Refusal):
                app.validate_target('/dev/test-card', 100, inv, swaps)

    def test_build_failure_unwinds_mounts_and_retains_evidence(self):
        records = []
        def fake_run(argv, **kwargs):
            records.append([str(x) for x in argv])
            if argv[0] == 'losetup' and '--find' in argv:
                return '/dev/loop123'
            if argv[0] == 'bsdtar':
                raise app.Refusal('injected extraction failure')
            return ''
        report = {'output': str(self.root / 'new.img'), 'image_bytes': 1024 * 1024, 'rootfs': str(self.archive)}
        with patch.object(app.os, 'geteuid', return_value=0), patch.object(app, 'executable_tools'), \
             patch.object(app, 'plan', return_value=report), patch.object(app, 'run', side_effect=fake_run), \
             patch.object(Path, 'is_block_device', return_value=True), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(app.Refusal):
                app.build(self.args())
        unmounts = [x for x in records if x[0] == 'umount']
        self.assertEqual(len(unmounts), 2)
        self.assertTrue(unmounts[0][1].endswith('/boot'))
        self.assertIn(['losetup', '--detach', '/dev/loop123'], records)
        self.assertFalse((self.root / 'new.img').exists())
        journal = next(self.root.glob('.gup-pi4-build.*/build-commands.json'))
        self.assertFalse(json.loads(journal.read_text())['completed'])

    def test_timeouts_record_actual_failure(self):
        records = []
        with patch.object(app.subprocess, 'run', side_effect=subprocess.TimeoutExpired(['dummy'], 1)):
            with self.assertRaises(app.Refusal):
                app.run(['dummy'], records=records)
        self.assertEqual(records[0]['exit_status'], 124)

    def test_incomplete_or_plaintext_password_hashes_are_rejected(self):
        for value in ['alarm', '$6$salt$short', '$y$missing', '$6$rounds=0000$salt$' + 'A' * 86]:
            self.assertFalse(app.valid_password_hash(value))
        self.assertTrue(app.valid_password_hash('$6$salt$' + 'A' * 86))
        self.assertTrue(app.valid_password_hash('$y$j9T$salt$' + 'A' * 43))

    @contextlib.contextmanager
    def conventional_workspace(self):
        aliases = {'ArchLinuxARM-rpi-aarch64-latest.tar.gz': self.archive,
                   'gup-source-r6.bundle': self.bundle,
                   'alarm.pub': Path(str(self.key) + '.pub'),
                   'alarm.password.hash': self.pw}
        for name, source in aliases.items():
            destination = self.root / name
            destination.write_bytes(source.read_bytes())
            if name.endswith('.hash'):
                destination.chmod(0o600)
        (self.root / 'rootfs.sha256').write_text(app.digest(self.archive) + '  ArchLinuxARM-rpi-aarch64-latest.tar.gz\n')
        old = os.getcwd()
        os.chdir(self.root)
        try:
            yield
        finally:
            os.chdir(old)

    def test_simple_plan_discovers_workspace_inputs_without_writes(self):
        with self.conventional_workspace():
            before = set(self.root.rglob('*'))
            args = app.parse(['--plan'])
            report = app.plan(args)
            self.assertIsNone(report['commit'])
            self.assertIsNone(report['bundle'])
            self.assertEqual(Path(args.output).name, 'arch-pi-arch.img')
            self.assertEqual(args.ssh_key, 'alarm.pub')
            self.assertEqual(before, set(self.root.rglob('*')))

    def test_explicit_flags_override_discovery_and_sidecar_needs_matching_pin(self):
        with self.conventional_workspace():
            args = app.parse(['--plan', '--output', 'different.img', '--rootfs-sha256', '1' * 64])
            self.assertEqual(args.output, 'different.img')
            self.assertEqual(args.rootfs_sha256, '1' * 64)
            with self.assertRaises(app.Refusal):
                app.plan(args)
            Path('rootfs.sha256').write_text('0' * 64 + '  unrelated.tar.gz\n')
            with self.assertRaises(app.Refusal):
                app.parse(['--plan'])

    def test_help_lists_workflows_before_flags_and_never_checks_inputs(self):
        for flag in ['-h', '--help']:
            output = io.StringIO()
            with patch.object(app, 'discover_inputs', side_effect=AssertionError('help touched setup')), contextlib.redirect_stdout(output):
                with self.assertRaises(SystemExit) as status:
                    app.parse([flag])
            self.assertEqual(status.exception.code, 0)
            text = output.getvalue()
            self.assertLess(text.index('COMMON COMMANDS'), text.index('options:'))
            for phrase in ['--plan', '--build', '--flash', 'PROFILES AND SAVED WI-FI', 'WHAT THE MENU DOES']:
                self.assertIn(phrase, text)

    def test_plain_arch_needs_no_bundle_or_gup_helpers(self):
        args = self.args(baseline='arch', bundle=None)
        report = app.plan(args)
        self.assertIsNone(report['repo'])
        root = self.make_root()
        with patch.object(app.os, 'chown'):
            app.configure(root, args, report, '12345678-02', '12345678-01')
        self.assertEqual((root / 'etc/hostname').read_text(), 'archpi\n')
        self.assertFalse((root / 'usr/local/bin/gup-validate-source').exists())
        self.assertFalse((root / 'usr/local/sbin/gup-upgrade-base').exists())
        self.assertNotIn('python-gobject', (root / 'usr/local/sbin/arch-pi-upgrade-base').read_text())
        self.assertNotIn('libnm', (root / 'usr/local/sbin/arch-pi-upgrade-base').read_text())
        self.assertIn('/usr/local/lib/arch-pi/firstboot.sh',
                      (root / 'etc/systemd/system/arch-pi-firstboot.service').read_text())

    def test_legacy_settings_import_preserves_original(self):
        legacy = self.root / 'state/gup-pi4/session.json'
        legacy.parent.mkdir(parents=True)
        data = json.dumps({'baseline': 'r6', 'wifi_ssid': 'saved', 'wifi_password_file': str(self.pw)})
        legacy.write_text(data)
        ui = self.make_ui()
        self.assertEqual(ui.saved['wifi_ssid'], 'saved')
        self.assertEqual(legacy.read_text(), data)
        ui.saved['baseline'] = 'arch'; ui.save()
        self.assertEqual(legacy.read_text(), data)
        self.assertEqual(ui.profile.stat().st_mode & 0o777, 0o600)

    def test_wifi_saved_password_survives_settings_and_next_burn(self):
        ui = self.make_ui()
        secret = ui.private_file('wifi', 'remember-this-password')
        ui.saved = {'wifi_ssid': 'My Network', 'wifi_password_file': secret}
        ui.save()
        with patch.object(ui, 'choose', side_effect=['wifi', 'wifi']), \
             patch.object(ui, 'ask', return_value='My Network'), \
             patch.object(app.getpass, 'getpass', return_value=''):
            app.settings_menu(ui)
        self.assertEqual(app.private_text(ui.saved['wifi_password_file']), 'remember-this-password')
        self.assertEqual(ui.saved['wifi_password_file'], secret)
        self.assertEqual(Path(ui.saved['wifi_password_file']).stat().st_mode & 0o777, 0o600)
        self.assertNotIn('remember-this-password', ui.profile.read_text())

    def test_missing_setup_names_files_and_help_route(self):
        old = os.getcwd(); os.chdir(self.root)
        try:
            with self.assertRaises(app.Refusal) as error:
                app.parse(['--plan'])
            self.assertIn('Missing setup files:', str(error.exception))
            self.assertIn('alarm.pub', str(error.exception))
            self.assertIn('--help', str(error.exception))
        finally:
            os.chdir(old)

    def make_ui(self, answers=()):
        class FakeTTY:
            def __init__(self):
                self.output = io.StringIO(); self.answers = iter(answers)
            def write(self, text):
                return self.output.write(text)
            def flush(self):
                pass
            def readline(self):
                return next(self.answers, '')
        tty = FakeTTY()
        with patch.dict(os.environ, {'XDG_STATE_HOME': str(self.root / 'state'), 'SUDO_USER': ''}):
            ui = app.TerminalUI(tty)
        ui.home = self.root / 'home'; ui.home.mkdir(exist_ok=True)
        ui.use_fzf = False
        return ui

    def test_numeric_menu_and_saved_private_profile(self):
        ui = self.make_ui(['bad\n', '2\n'])
        self.assertEqual(ui.choose('Test', [('first', 'First'), ('second', 'Second')]), 'second')
        ui.saved = {'baseline': 'r6'}; ui.save()
        self.assertEqual(ui.profile.stat().st_mode & 0o777, 0o600)
        self.assertEqual(json.loads(ui.profile.read_text())['baseline'], 'r6')

    def test_fzf_execution_options_are_removed_and_selection_uses_ids(self):
        ui = self.make_ui(); ui.use_fzf = True
        with patch.dict(os.environ, {'FZF_DEFAULT_OPTS': '--bind=start:execute(bad)', 'FZF_DEFAULT_OPTS_FILE': '/tmp/evil'}), \
             patch.object(app.subprocess, 'run', return_value=types.SimpleNamespace(returncode=0, stdout='1\tLabel\n')) as run:
            self.assertEqual(ui.choose('Title', [('a', 'A'), ('b', 'B')]), 'b')
        env = run.call_args.kwargs['env']
        self.assertEqual(env['FZF_DEFAULT_OPTS'], '')
        self.assertEqual(env['FZF_DEFAULT_OPTS_FILE'], '/dev/null')
        self.assertFalse(any('execute' in argument for argument in run.call_args.args[0]))
        with patch.object(app.subprocess, 'run', return_value=types.SimpleNamespace(returncode=130, stdout='')):
            with self.assertRaises(app.Cancelled):
                ui.choose('Title', [('a', 'A')])
        with patch.object(app.subprocess, 'run', return_value=types.SimpleNamespace(returncode=0, stdout='999\tbad\n')):
            with self.assertRaises(app.Refusal):
                ui.choose('Title', [('a', 'A')])

    def test_fzf_error_falls_back_without_selecting_an_action(self):
        ui = self.make_ui(['1\n']); ui.use_fzf = True
        with patch.object(app.subprocess, 'run', return_value=types.SimpleNamespace(returncode=2, stdout='')):
            self.assertEqual(ui.choose('Title', [('a', 'A')]), 'a')
        self.assertFalse(ui.use_fzf)

    def test_gui_generates_password_hash_and_key_without_manual_files(self):
        ui = self.make_ui()
        with patch.object(app.getpass, 'getpass', side_effect=['a test password', 'a test password']):
            path = ui.password_hash('Test password')
        self.assertTrue(app.valid_password_hash(Path(path).read_text().strip()))
        self.assertNotIn('a test password', Path(path).read_text())
        self.assertEqual(Path(path).stat().st_mode & 0o777, 0o600)
        with patch.object(ui, 'find_files', return_value=[]):
            public = Path(app.choose_ssh_key(ui))
        self.assertTrue(public.read_text().startswith('ssh-ed25519 '))
        self.assertEqual(Path(str(public)[:-4]).stat().st_mode & 0o777, 0o600)

    def test_prepared_session_reuses_inputs_and_never_reprompts_password(self):
        ui = self.make_ui()
        ui.saved = {'rootfs': str(self.archive), 'rootfs_sha256': app.digest(self.archive),
                    'bundle': str(self.bundle), 'ssh_key': str(self.key) + '.pub',
                    'password_hash_file': str(self.pw), 'image_directory': str(self.root / 'images')}
        with patch.object(ui, 'password_hash', side_effect=AssertionError('asked again')), \
             patch.object(app, 'select_rootfs', side_effect=AssertionError('downloaded again')):
            args = app.prepared_args(ui)
        self.assertTrue(Path(args.output).parent.is_dir())
        self.assertEqual(args.rootfs, str(self.archive))
        self.assertNotIn('a test password', ' '.join(app.build_arguments(args)))

    def test_rootfs_download_enforces_https_and_records_a_first_use_pin(self):
        ui = self.make_ui()
        def fake_download(argv, **kwargs):
            Path(argv[argv.index('--output') + 1]).write_bytes(self.archive.read_bytes())
            return types.SimpleNamespace(returncode=0)
        with patch.object(app, 'executable_tools'), patch.object(app.subprocess, 'run', side_effect=fake_download) as run:
            path, pin, trust = app.download_rootfs(ui)
        self.assertEqual(app.digest(path), pin)
        self.assertIn('first-download pin', trust)
        argv = run.call_args.args[0]
        self.assertEqual(argv[argv.index('--proto') + 1], '=https')
        self.assertEqual(argv[argv.index('--proto-redir') + 1], '=https')
        self.assertTrue(argv[-1].startswith('https://'))

    def test_target_picker_excludes_host_disks_and_carries_no_erase_action(self):
        ui = self.make_ui()
        host = self.inventory()['blockdevices'][0]; host['path'] = '/dev/host'
        host['children'][0]['mountpoints'] = ['/']
        card = self.inventory()['blockdevices'][0]; card['path'] = '/dev/card'
        inventory = {'blockdevices': [host, card]}
        observed = []
        def choose(title, options):
            observed.extend(value for value, label in options)
            return '/dev/card'
        def fake_run(argv, **kwargs):
            self.assertIn(argv[0], ['lsblk', 'swapon'])
            return json.dumps(inventory) if argv[0] == 'lsblk' else ''
        with patch.object(ui, 'choose', side_effect=choose), patch.object(app, 'run', side_effect=fake_run):
            self.assertEqual(app.target_picker(ui, 100), '/dev/card')
        self.assertNotIn('/dev/host', observed)

    def test_guided_build_chain_saves_receipt_without_implicit_flash(self):
        ui = self.make_ui(); ui.choose = unittest.mock.Mock(side_effect=['build', 'build', 'done'])
        args = self.args(); args.interactive = True
        receipt = {'output': str(self.root / 'new.img'), 'image_sha256': 'a' * 64}
        tty = unittest.mock.MagicMock()
        with patch.object(app, 'ControlTerminal', return_value=tty), patch.object(app, 'TerminalUI', return_value=ui), \
             patch.object(app, 'prepared_args', return_value=args), patch.object(app, 'plan', return_value={}), \
             patch.object(app.os, 'geteuid', return_value=0), patch.object(app, 'build', return_value=receipt) as build, \
             patch.object(app, 'guided_flash', side_effect=AssertionError('flashed without selection')):
            self.assertEqual(app.interactive(), 0)
        build.assert_called_once_with(args, guided=True)
        self.assertEqual(ui.saved['last_image'], receipt)

    def test_real_terminal_default_menu_can_exit_without_jobs(self):
        master, slave = pty.openpty()
        def controlling_terminal():
            os.setsid(); fcntl.ioctl(0, termios.TIOCSCTTY, 0)
        env = dict(os.environ, XDG_STATE_HOME=str(self.root / 'pty-state'), TERM='dumb')
        for name in ['SUDO_USER', 'SUDO_UID', 'SUDO_GID']:
            env.pop(name, None)
        # The numbered fallback is exercised in this environment (fzf is absent).
        if app.shutil.which('fzf'):
            os.close(master); os.close(slave); self.skipTest('real numbered terminal test requires no fzf')
        child = subprocess.Popen(['bash', str(SCRIPT)], stdin=slave, stdout=slave, stderr=slave,
                                 env=env, preexec_fn=controlling_terminal)
        os.close(slave)
        output = b''
        try:
            deadline = time.monotonic() + 8
            while b'Choose a number' not in output and time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    output += os.read(master, 65536)
            self.assertIn(b'Choose a number', output)
            os.write(master, b'3\n')
            self.assertEqual(child.wait(timeout=5), 0)
            self.assertIn(b'Create a Pi image', output)
            self.assertFalse(list(self.root.rglob('*.img')))
        finally:
            if child.poll() is None:
                child.kill(); child.wait()
            os.close(master)

    def test_gui_download_failure_does_not_accept_partial_archive(self):
        ui = self.make_ui()
        with patch.object(app, 'executable_tools'), patch.object(app.subprocess, 'run', return_value=types.SimpleNamespace(returncode=22)):
            with self.assertRaises(app.Refusal):
                app.download_rootfs(ui)
        self.assertTrue(list(ui.folder.glob('*.partial')))
        self.assertFalse(list(ui.folder.glob('*.tar.gz')))
        self.assertNotIn('rootfs', ui.saved)
        evidence = json.loads(Path(ui.saved['last_download_evidence']).read_text())
        self.assertEqual(evidence['exit_status'], 22)

    def test_unreadable_managed_profile_is_preserved_and_recovered(self):
        ui = self.make_ui()
        ui.profile.write_text('{broken')
        with patch.dict(os.environ, {'XDG_STATE_HOME': str(self.root / 'state'), 'SUDO_USER': ''}):
            recovered = app.TerminalUI(ui.tty)
        self.assertEqual(recovered.saved, {})
        self.assertTrue(list(ui.folder.glob('session-unreadable.*.json')))

    def test_failed_build_does_not_create_flash_receipt_or_retry(self):
        ui = self.make_ui(); ui.choose = unittest.mock.Mock(side_effect=['build', 'build', 'quit'])
        args = self.args()
        tty = unittest.mock.MagicMock()
        with patch.object(app, 'ControlTerminal', return_value=tty), patch.object(app, 'TerminalUI', return_value=ui), \
             patch.object(app, 'prepared_args', return_value=args), patch.object(app, 'plan', return_value={}), \
             patch.object(app.os, 'geteuid', return_value=0), patch.object(app, 'build', side_effect=app.Refusal('failure')) as build, \
             patch.object(app, 'guided_flash', side_effect=AssertionError('flashed failure')):
            self.assertEqual(app.interactive(), 0)
        self.assertEqual(build.call_count, 1)
        self.assertNotIn('last_image', ui.saved)

    def test_optional_card_unmount_requires_menu_approval(self):
        ui = self.make_ui(); ui.choose = unittest.mock.Mock(side_effect=['/dev/card', 'yes'])
        disk = self.inventory()['blockdevices'][0]; disk['path'] = '/dev/card'
        disk['children'][0]['mountpoints'] = ['/run/media/alarm/CARD']
        calls = []
        def fake_run(argv, **kwargs):
            calls.append(argv)
            return json.dumps({'blockdevices': [disk]}) if argv[0] == 'lsblk' else ''
        with patch.object(app.os, 'geteuid', return_value=0), patch.object(app, 'run', side_effect=fake_run):
            self.assertEqual(app.target_picker(ui, 100), '/dev/card')
        self.assertIn(['umount', '--', '/dev/test-card1'], calls)
        self.assertFalse(any(command[0] == 'wipefs' for command in calls))

    def test_privileged_child_receipt_is_accepted_only_after_success(self):
        ui = self.make_ui()
        receipt = {'output': '/tmp/test-image.img', 'image_sha256': 'a' * 64}
        for status in [0, 1]:
            child = unittest.mock.MagicMock()
            child.stdout = io.StringIO('Building…\nGUP_IMAGE_RESULT=' + json.dumps(receipt) + '\n')
            child.wait.return_value = status
            with patch.object(app, 'executable_tools'), patch.object(app, 'SCRIPT_PATH', SCRIPT), \
                 patch.object(app.subprocess, 'Popen', return_value=child) as launch:
                if status == 0:
                    self.assertEqual(app.privileged_script(ui, ['--build']), receipt)
                else:
                    with self.assertRaises(app.Refusal):
                        app.privileged_script(ui, ['--build'])
            argv = launch.call_args.args[0]
            self.assertEqual(argv[:5], ['sudo', '--', 'env', 'GUP_INTERFACE=guided', 'bash'])
            self.assertNotIn('GUP_IMAGE_RESULT=', ui.tty.output.getvalue())

    def test_in_process_rootfs_scan_is_reused_but_invalidated_on_change(self):
        args = self.args()
        with patch.object(app, 'archive_inventory', wraps=app.archive_inventory) as inventory:
            app.checked_rootfs(args); app.checked_rootfs(args)
            self.assertEqual(inventory.call_count, 1)
            self.archive.write_bytes(b'changed')
            with self.assertRaises(app.Refusal):
                app.checked_rootfs(args)

    def test_certificate_failure_automatically_uses_next_verified_https_mirror(self):
        ui = self.make_ui(); calls = []
        def fake_download(argv, **kwargs):
            calls.append(argv)
            output = Path(argv[argv.index('--output') + 1])
            output.write_bytes(b'failed first attempt' if len(calls) == 1 else self.archive.read_bytes())
            return types.SimpleNamespace(returncode=60 if len(calls) == 1 else 0)
        with patch.object(app, 'executable_tools'), patch.object(app.subprocess, 'run', side_effect=fake_download):
            path, pin, trust = app.download_rootfs(ui)
        self.assertEqual(pin, app.digest(self.archive))
        self.assertEqual(Path(path).read_bytes(), self.archive.read_bytes())
        self.assertEqual(len(calls), 2)
        self.assertNotEqual(calls[0][-1], calls[1][-1])
        self.assertNotEqual(calls[0][calls[0].index('--output') + 1], calls[1][calls[1].index('--output') + 1])
        for argv in calls:
            self.assertNotIn('-k', argv); self.assertNotIn('--insecure', argv)
            self.assertNotIn('--resolve', argv); self.assertNotIn('--connect-to', argv)
            self.assertNotIn('os.archlinuxarm.org', argv[-1])
            self.assertEqual(argv[argv.index('--proto-redir') + 1], '=https')
        evidence = json.loads(Path(ui.saved['last_download_evidence']).read_text())
        self.assertEqual([row['exit_status'] for row in evidence['attempts']], [60, 0])
        self.assertTrue(evidence['archive_verified'])

    def test_all_mirror_certificates_failing_never_accepts_or_downgrades(self):
        ui = self.make_ui()
        with patch.object(app, 'executable_tools'), patch.object(app.subprocess, 'run', return_value=types.SimpleNamespace(returncode=60)) as run:
            with self.assertRaises(app.Refusal):
                app.download_rootfs(ui)
        self.assertEqual(run.call_count, len(app.ROOTFS_URLS))
        self.assertNotIn('rootfs', ui.saved)
        self.assertFalse(list(ui.folder.glob('*.tar.gz')))

    def test_local_download_write_error_stops_without_mirror_retry(self):
        ui = self.make_ui()
        with patch.object(app, 'executable_tools'), patch.object(app.subprocess, 'run', return_value=types.SimpleNamespace(returncode=23)) as run:
            with self.assertRaises(app.Refusal):
                app.download_rootfs(ui)
        self.assertEqual(run.call_count, 1)

    def test_http_success_with_invalid_archive_tries_next_mirror(self):
        ui = self.make_ui(); count = 0
        def fake_download(argv, **kwargs):
            nonlocal count
            count += 1
            Path(argv[argv.index('--output') + 1]).write_bytes(b'<html>not an archive</html>' if count == 1 else self.archive.read_bytes())
            return types.SimpleNamespace(returncode=0)
        with patch.object(app, 'executable_tools'), patch.object(app.subprocess, 'run', side_effect=fake_download):
            path, pin, _ = app.download_rootfs(ui)
        self.assertEqual(count, 2)
        self.assertEqual(pin, app.digest(self.archive))
        evidence = json.loads(Path(ui.saved['last_download_evidence']).read_text())
        self.assertEqual([row['archive_verified'] for row in evidence['attempts']], [False, True])

    def test_simulated_success_builds_pinned_private_image(self):
        report = dict(app.plan(self.args()), image_bytes=1024 * 1024)
        calls = []
        def fake_run(argv, **kwargs):
            calls.append([str(x) for x in argv])
            if argv[0] == 'losetup' and '--find' in argv:
                return '/dev/loop123'
            if argv[0] == 'bsdtar':
                root = Path(argv[-1]); self.make_root(root)
                (root / 'boot/cmdline.txt').write_text('console=tty1 root=/dev/mmcblk0p2 rw\n')
            if argv[0] == 'blkid':
                return '12345678-01' if str(argv[-1]).endswith('p1') else '12345678-02'
            if argv[0] == 'git' and 'clone' in argv:
                Path(argv[-1]).mkdir()
            if argv[0] == 'git' and 'rev-parse' in argv:
                return app.R6[0] if argv[-1] == 'HEAD' else app.R6[1]
            return ''
        with patch.object(app.os, 'geteuid', return_value=0), patch.object(app, 'executable_tools'), \
             patch.object(app, 'plan', return_value=report), patch.object(app, 'run', side_effect=fake_run), \
             patch.object(Path, 'is_block_device', return_value=True), patch.object(app.os, 'chown'), patch.object(app.os, 'lchown'), \
             contextlib.redirect_stdout(io.StringIO()):
            app.build(self.args())
        image = self.root / 'new.img'
        self.assertEqual(image.stat().st_size, 1024 * 1024)
        self.assertEqual(image.stat().st_mode & 0o777, 0o600)
        work = next(self.root.glob('.gup-pi4-build.*'))
        manifest = json.loads((work / 'image-manifest.json').read_text())
        self.assertEqual(manifest['commit'], app.R6[0])
        self.assertEqual(manifest['image_sha256'], app.digest(image))
        self.assertTrue(json.loads((work / 'build-commands.json').read_text())['completed'])
        self.assertTrue(any('fsck' in call for call in calls))

    def test_simulated_plain_arch_build_never_uses_source_git(self):
        args = self.args(baseline='arch', bundle=None)
        report = dict(app.plan(args), image_bytes=1024 * 1024)
        calls = []
        def fake_run(argv, **kwargs):
            calls.append([str(x) for x in argv])
            if argv[0] == 'git':
                raise AssertionError('plain Arch unexpectedly used Git')
            if argv[0] == 'losetup' and '--find' in argv:
                return '/dev/loop123'
            if argv[0] == 'bsdtar':
                root = Path(argv[-1]); self.make_root(root)
                (root / 'boot/cmdline.txt').write_text('root=/dev/mmcblk0p2 rw\n')
            if argv[0] == 'blkid':
                return '12345678-01' if str(argv[-1]).endswith('p1') else '12345678-02'
            return ''
        with patch.object(app.os, 'geteuid', return_value=0), patch.object(app, 'executable_tools'), \
             patch.object(app, 'plan', return_value=report), patch.object(app, 'run', side_effect=fake_run), \
             patch.object(Path, 'is_block_device', return_value=True), patch.object(app.os, 'chown'), \
             patch.object(app.os, 'lchown'), contextlib.redirect_stdout(io.StringIO()):
            app.build(args)
        self.assertEqual((self.root / 'new.img').stat().st_size, 1024 * 1024)
        work = next(self.root.glob('.gup-pi4-build.*'))
        manifest = json.loads((work / 'image-manifest.json').read_text())
        self.assertIsNone(manifest['commit'])
        self.assertEqual(manifest['hostname'], 'archpi')
        self.assertEqual(app.private_text(self.pw), '$6$testsalt$' + 'A' * 86)

    def test_cleanup_failure_preserves_loop_and_work_tree(self):
        calls = []
        def fake_run(argv, **kwargs):
            calls.append([str(x) for x in argv])
            if argv[0] == 'losetup' and '--find' in argv:
                return '/dev/loop123'
            if argv[0] in {'bsdtar', 'umount'}:
                raise app.Refusal('injected failure')
            return ''
        report = {'output': str(self.root / 'new.img'), 'image_bytes': 1024, 'rootfs': str(self.archive)}
        with patch.object(app.os, 'geteuid', return_value=0), patch.object(app, 'executable_tools'), \
             patch.object(app, 'plan', return_value=report), patch.object(app, 'run', side_effect=fake_run), \
             patch.object(Path, 'is_block_device', return_value=True), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(app.Refusal):
                app.build(self.args())
        self.assertNotIn(['losetup', '--detach', '/dev/loop123'], calls)
        journal = json.loads(next(self.root.glob('.gup-pi4-build.*/build-commands.json')).read_text())
        self.assertEqual(journal['remaining_loop'], '/dev/loop123')
        self.assertEqual(len(journal['remaining_mounts']), 2)

    def test_flash_confirmation_refusal_never_writes(self):
        image = self.root / 'flash.img'
        with image.open('wb') as f:
            f.truncate(2 * 1024**3)
        device = self.root / 'card'; device.touch()
        inv = self.inventory(); inv['blockdevices'][0]['path'] = str(device)
        inv['blockdevices'][0]['children'] = []
        a = argparse.Namespace(flash=str(image), device=str(device), image_sha256='0' * 64)
        def fake_run(argv, **kwargs):
            return json.dumps(inv) if argv[0] == 'lsblk' else ''
        with patch.object(app.os, 'geteuid', return_value=0), patch.object(app, 'executable_tools'), \
             patch.object(app, 'digest', return_value='0' * 64), patch.object(app.stat, 'S_ISBLK', return_value=True), \
             patch.object(app, 'run', side_effect=fake_run), patch('builtins.open', mock_open(read_data='NO\n')), \
             patch.object(app, 'flash_copy', side_effect=AssertionError('write attempted')), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(app.Refusal):
                app.flash(a)
        self.assertFalse(list(self.root.glob('.gup-flash.*')))
        self.assertEqual(device.read_bytes(), b'')


if __name__ == '__main__':
    unittest.main(verbosity=2)
