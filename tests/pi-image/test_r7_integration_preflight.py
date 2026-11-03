import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('integration_preflight',
    Path(__file__).resolve().parents[2] / 'scripts/pi-r7-integration-preflight.py')
gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gate)

class FakeProbe:
    def __init__(self, work, result=None):
        self.work, self.env, self.calls = work, {'PATH': '/usr/bin:/bin'}, []
        self.result = result if result is not None else {'backend': 'networkd', 'wireless': [{'interface': 'wlan0', 'control_access': True, 'wpa_state': 'COMPLETED'}], 'persistent_changes': False}

    def run(self, label, argv, **kwargs):
        self.calls.append([str(x) for x in argv])
        return {'running-kernel': 'release', 'kernel-ownership': '/usr/lib/modules/release/kernel/',
                'backend-probe': json.dumps(self.result)}.get(label, '')

    def git(self, source, label, *args, **kwargs):
        self.calls.append(['git', '-C', str(source), *args])
        return {'source-commit': gate.PIN, 'source-tree': gate.TREE, 'refs-before': 'stable', 'refs-after': 'stable'}.get(label, '')

class IntegrationPreflightTests(unittest.TestCase):
    def collect(self, probe, report):
        original = Path.is_dir
        with patch.object(Path, 'is_dir', lambda p: str(p) == '/usr/lib/modules/release' or original(p)), patch.object(gate.shutil, 'which', side_effect=lambda name, **kw: '/usr/bin/' + name), patch.object(gate.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 1024**3})()):
            gate.collect(probe, report)

    def test_success_only_checks_native_access_and_never_applies_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            probe, report = FakeProbe(Path(directory)), {}
            self.collect(probe, report)
            self.assertEqual(report['status'], 'PI_BACKEND_CONTROL_ACCESS_VERIFIED_CONFIGURATION_PENDING')
            for args in probe.calls:
                self.assertFalse(set(args) & {'sudo', 'pkexec', 'pacman -S', 'enable', 'start', 'stop', 'scan', 'select_network', 'save_config'})
            native = next(args for args in probe.calls if args[:2] == ['python3', '-B'])
            self.assertEqual(native[-1], 'probe')
            self.assertFalse(any('install.sh' in ' '.join(args) for args in probe.calls))

    def test_different_backend_blocks_configuration_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            probe = FakeProbe(Path(directory), {'backend': 'NetworkManager', 'wireless': [], 'persistent_changes': False})
            with self.assertRaisesRegex(RuntimeError, 'backend differs'):
                self.collect(probe, {})
            self.assertFalse(any(args == ['Hyprland', '--help'] for args in probe.calls))

    def test_no_wireless_observation_cannot_pass_pi_wifi_capability(self):
        with tempfile.TemporaryDirectory() as directory:
            probe = FakeProbe(Path(directory), {'backend': 'networkd', 'wireless': [], 'persistent_changes': False})
            with self.assertRaisesRegex(RuntimeError, 'No wireless interface'):
                self.collect(probe, {})

    def test_missing_binary_stops_before_source_clone(self):
        with tempfile.TemporaryDirectory() as directory:
            probe = FakeProbe(Path(directory))
            original = Path.is_dir
            with patch.object(Path, 'is_dir', lambda p: str(p) == '/usr/lib/modules/release' or original(p)), patch.object(gate.shutil, 'which', return_value=None):
                with self.assertRaisesRegex(RuntimeError, 'binaries missing'):
                    gate.collect(probe, {})
            self.assertFalse(any('clone' in args for args in probe.calls))

    def test_real_failed_probe_retains_exact_exit_and_stream_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            probe = gate.Probe(work)
            with self.assertRaisesRegex(RuntimeError, 'failed'):
                probe.run('failed', ['/usr/bin/python3', '-c', "import sys; print('proof'); sys.exit(7)"])
            self.assertEqual(probe.commands[0]['exit_code'], 7)
            self.assertEqual(probe.commands[0]['stdout_sha256'], gate.sha(work / 'logs/failed.stdout'))
            self.assertEqual((work / 'logs/failed.stdout').read_text(), 'proof\n')

if __name__ == '__main__':
    unittest.main()
