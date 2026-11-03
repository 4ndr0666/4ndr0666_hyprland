import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'config/hypr/UserScripts/NetworkBackend.py'
SPEC = importlib.util.spec_from_file_location('network_backend', SCRIPT)
net = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(net)

class BackendTests(unittest.TestCase):
    def test_startup_helper_path_keeps_spaces_quotes_and_shell_metacharacters_literal(self):
        lua = next((shutil.which(name) for name in ['lua', 'lua5.4', 'texlua'] if shutil.which(name)), None)
        self.assertIsNotNone(lua, 'Lua parser/interpreter is required by the Golden Unit gate')
        with tempfile.TemporaryDirectory() as directory:
            home = str(Path(directory) / "user ' $HOME $(unwanted)")
            script = Path(directory) / 'startup.lua'
            source = ROOT / 'config/hypr/configs/Startup_Apps.lua'
            script.write_text('hl = {on=function(_, fn) fn() end, exec_cmd=function(cmd) print(cmd) end}\ndofile(' + json.dumps(str(source)) + ')\n')
            result = subprocess.run([lua, str(script)], env=dict(os.environ, HOME=home), text=True, capture_output=True, check=True)
            cmd = next(line for line in result.stdout.splitlines() if line.startswith('python3 '))
            self.assertEqual(shlex.split(cmd), ['python3', home + '/.config/hypr/UserScripts/NetworkBackend.py', 'applets'])
            self.assertTrue(cmd.startswith("python3 '"))

    def test_desktop_nm_menu_is_delegated_without_editing_legacy_implementation(self):
        with patch.object(net, 'active', side_effect=lambda unit: unit.startswith('NetworkManager')), patch.object(net, 'native_menu') as native:
            self.assertEqual(net.main(), 75)
            native.assert_not_called()
        text = (SCRIPT.parent / 'RofiNetwork.sh').read_bytes()
        legacy = text[text.index(b'import pathlib\n'):]
        self.assertEqual(hashlib.sha256(legacy).hexdigest(), '1aaecca1a373e15781f0a0fd0cabdbe7b5f813704997e17cf2f7f559b1a332c7')

    def test_networkd_dispatch_precedes_gi_import_even_when_gi_is_unavailable(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / 'RofiNetwork.sh').write_bytes((SCRIPT.parent / 'RofiNetwork.sh').read_bytes())
            (path / 'NetworkBackend.py').write_text('raise SystemExit(0)\n')
            result = subprocess.run(['python3', '-B', str(path / 'RofiNetwork.sh')], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_networkd_never_spawns_nm_applets(self):
        with patch.object(net, 'active', side_effect=lambda unit: unit.startswith('systemd-networkd')), patch.object(net.subprocess, 'Popen') as spawn:
            self.assertEqual(net.main('applets'), 0)
            spawn.assert_not_called()

    def test_probe_is_read_only_and_redacts_connection_identity(self):
        with patch.object(net, 'backend', return_value='networkd'), patch.object(net, 'interfaces', return_value=['wlan0']), patch.object(net, 'status', return_value={'ssid': 'PRIVATE-SSID', 'psk': 'PRIVATE-KEY', 'wpa_state': 'COMPLETED'}), contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(net.main('probe'), 0)
        self.assertNotIn('PRIVATE', output.getvalue())
        self.assertEqual(json.loads(output.getvalue())['wireless'][0]['control_access'], True)

    def test_unknown_service_error_does_not_fall_through_to_nm(self):
        with patch.object(net.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)):
            with self.assertRaisesRegex(RuntimeError, 'Cannot determine'):
                net.backend()

    def test_socket_failure_never_requests_privilege_or_reconfiguration(self):
        with patch.object(net, 'command', return_value='Could not connect to wpa_supplicant') as command:
            with self.assertRaisesRegex(RuntimeError, 'control unavailable'):
                net.control('wlan0', 'status')
        self.assertEqual(command.call_args.args[0], ['wpa_cli', '-i', 'wlan0', 'status'])

    def test_private_key_is_stdin_only_and_not_in_process_arguments(self):
        key = 'a' * 64
        with patch.object(net, 'command', return_value='> set_network\nOK\n> quit') as command:
            net.secret_psk('wlan0', '7', key)
        self.assertNotIn(key, repr(command.call_args.args))
        self.assertIn(key, command.call_args.kwargs['data'])

    def test_temporary_success_keeps_original_disk_configuration(self):
        calls = []
        def control(interface, *args):
            calls.append(args)
            return '9' if args[0] == 'add_network' else 'OK'
        with patch.object(net, 'saved', return_value=[]), patch.object(net, 'control', side_effect=control), patch.object(net, 'secret_psk') as key, patch.object(net, 'status', return_value={'id': '9', 'wpa_state': 'COMPLETED'}):
            net.temporary_connection('wlan0', b'WiFi$(unsafe)"', '[WPA2-PSK-CCMP][ESS]', 'private passphrase')
        self.assertIn(('set_network', '9', 'ssid', b'WiFi$(unsafe)"'.hex()), calls)
        self.assertFalse(any(c[0] == 'save_config' for c in calls))
        self.assertEqual(key.call_args.args[-1], hashlib.pbkdf2_hmac('sha1', b'private passphrase', b'WiFi$(unsafe)"', 4096, 32).hex())

    def test_connect_timeout_removes_new_profile_and_restores_previous_states(self):
        calls = []
        rows = [{'id': '0', 'flags': '[CURRENT]'}, {'id': '2', 'flags': '[DISABLED]'}, {'id': '3', 'flags': ''}]
        def control(interface, *args):
            calls.append(args)
            return '9' if args[0] == 'add_network' else 'OK'
        with patch.object(net, 'saved', return_value=rows), patch.object(net, 'control', side_effect=control), patch.object(net, 'status', return_value={'wpa_state': 'SCANNING'}), patch.object(net.time, 'sleep'):
            with self.assertRaisesRegex(RuntimeError, 'did not complete'):
                net.temporary_connection('wlan0', b'open', '[ESS]')
        self.assertIn(('remove_network', '9'), calls)
        self.assertIn(('select_network', '0'), calls)
        self.assertIn(('disable_network', '2'), calls)
        self.assertIn(('enable_network', '3'), calls)
        self.assertFalse(any(c[0] == 'save_config' for c in calls))

    def test_interruption_rolls_back_new_profile(self):
        calls = []
        def control(interface, *args):
            calls.append(args)
            return '9' if args[0] == 'add_network' else 'OK'
        with patch.object(net, 'saved', return_value=[]), patch.object(net, 'control', side_effect=control), patch.object(net, 'status', side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                net.temporary_connection('wlan0', b'open', '[ESS]')
        self.assertIn(('remove_network', '9'), calls)

    def test_unsupported_security_never_adds_a_profile(self):
        for flags in ['[WPA2-EAP-CCMP][ESS]', '[SAE][ESS]', '[DPP][ESS]', '[WEP][ESS]']:
            with self.subTest(flags=flags), patch.object(net, 'control') as control:
                with self.assertRaises(RuntimeError):
                    net.temporary_connection('wlan0', b'name', flags)
                control.assert_not_called()

    def test_ssid_escapes_decode_to_original_bytes(self):
        self.assertEqual(net.decode_ssid(r'a\x20b\x00c'), b'a b\0c')
        self.assertEqual(net.decode_ssid('café'), 'café'.encode())

class FirstBootReadinessTests(unittest.TestCase):
    def run_first_boot(self, ready_after):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        home, bin_dir = root / 'home with spaces', root / 'bin'
        scripts = home / '.config/hypr/scripts'
        scripts.mkdir(parents=True)
        state = home / '.config/hypr/wallpaper_effects'
        state.mkdir()
        (state / '.wallpaper_current').write_text('wallpaper fixture')
        bin_dir.mkdir()
        for name in ['sleep', 'gsettings', 'kvantummanager']:
            path = bin_dir / name
            path.write_text('#!/bin/sh\nexit 0\n')
            path.chmod(0o755)
        generator = scripts / 'WallustAwww.sh'
        generator.write_text('#!/bin/sh\nprintf generated > "$HOME/generated"\n')
        generator.chmod(0o755)
        awww = bin_dir / 'awww'
        awww.write_text('''#!/bin/sh
if [ "$1" = query ]; then
    n=0
    if [ -f "$HOME/queries" ]; then read -r n < "$HOME/queries"; fi
    n=$((n + 1))
    printf '%s\\n' "$n" > "$HOME/queries"
    [ "$n" -ge "$READY_AFTER" ]
else
    printf image > "$HOME/image"
fi
''')
        awww.chmod(0o755)
        env = dict(os.environ, HOME=str(home), PATH=str(bin_dir) + ':/usr/bin:/bin', READY_AFTER=str(ready_after))
        result = subprocess.run(['bash', str(ROOT / 'config/hypr/initial-boot.sh')], env=env, capture_output=True)
        return result, home

    def test_delayed_owner_readiness_succeeds_without_starting_another_daemon(self):
        result, home = self.run_first_boot(8)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((home / 'generated').exists())
        self.assertTrue((home / '.config/hypr/.initial_startup_done').exists())
        self.assertGreaterEqual(int((home / 'queries').read_text()), 8)

    def test_never_ready_keeps_retry_marker_absent_and_skips_palette(self):
        result, home = self.run_first_boot(1000)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((home / '.config/hypr/.initial_startup_done').exists())
        self.assertFalse((home / 'generated').exists())
        self.assertFalse((home / 'image').exists())

if __name__ == '__main__':
    unittest.main()
