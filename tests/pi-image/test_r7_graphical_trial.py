import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('graphical_trial',
    Path(__file__).resolve().parents[2] / 'scripts/pi-r7-graphical-trial.py')
gui = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gui)

class TrialSafetyTests(unittest.TestCase):
    def test_config_errors_ignore_empty_strings_but_reject_unknown_shapes(self):
        self.assertEqual(gui.config_error_count(b'["", "  "]'), 0)
        self.assertEqual(gui.config_error_count(b'["", "real error"]'), 1)
        for raw in [b'{}', b'null', b'[1]', b'invalid']:
            with self.assertRaises(ValueError):
                gui.config_error_count(raw)

    def test_manager_decoding_preserves_values_and_discards_unrelated_environment(self):
        for values in [['WAYLAND_DISPLAY=wayland-1', 'XDG_CURRENT_DESKTOP=Hyprland:Other', 'TOKEN=secret'],
                       [['WAYLAND_DISPLAY=wayland-1', 'XDG_CURRENT_DESKTOP=Hyprland:Other', 'TOKEN=secret']]]:
            self.assertEqual(gui.parse_manager({'type': 'as', 'data': values}),
                             {'WAYLAND_DISPLAY': 'wayland-1', 'XDG_CURRENT_DESKTOP': 'Hyprland:Other'})

    def test_restore_unsets_previously_absent_keys_and_verifies_exact_selected_values(self):
        class Probe:
            def __init__(self): self.calls = []
            def run(self, label, args, **kwargs): self.calls.append(args)
            def manager(self, label): return {'WAYLAND_DISPLAY': 'old-value'}
        probe = Probe()
        gui.restore_manager(probe, {'WAYLAND_DISPLAY': 'old-value'})
        self.assertIn(['systemctl', '--user', 'unset-environment', '--', 'XDG_CURRENT_DESKTOP'], probe.calls)
        self.assertIn(['systemctl', '--user', 'set-environment', '--', 'WAYLAND_DISPLAY=old-value'], probe.calls)
        with self.assertRaisesRegex(RuntimeError, 'Invalid managed'):
            gui.restore_manager(probe, {'TOKEN': 'not permitted'})

    def test_private_manager_command_does_not_persist_environment_dump(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            probe = gui.Probe(work)
            result = subprocess.CompletedProcess([], 0, b'{"TOKEN":"private-secret"}', b'')
            with patch.object(gui.subprocess, 'run', return_value=result):
                probe.run('private', ['busctl', 'get-property'], private=True)
            for file in work.rglob('*'):
                if file.is_file():
                    self.assertNotIn(b'private-secret', file.read_bytes())
            self.assertIn('not retained', probe.commands[0]['stream_retention'])

    def test_repeated_probe_labels_keep_both_exact_streams(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            probe = gui.Probe(work)
            outputs = [subprocess.CompletedProcess([], 0, b'first', b''), subprocess.CompletedProcess([], 0, b'second', b'')]
            with patch.object(gui.subprocess, 'run', side_effect=outputs):
                probe.run('instances', ['hyprctl', 'instances'])
                probe.run('instances', ['hyprctl', 'instances'])
            self.assertNotEqual(probe.commands[0]['label'], probe.commands[1]['label'])
            for row in probe.commands:
                self.assertEqual(gui.sha(work / 'logs' / (row['label'] + '.stdout')), row['stdout_sha256'])

    def test_pid_reuse_cannot_signal_an_unrelated_new_process(self):
        old = dict(pid=123, birth='old', selected={'HOME': '/trial'})
        new = dict(pid=123, birth='new', selected={'HOME': '/trial'})
        with patch.object(gui, 'process', return_value=new), patch.object(gui.os, 'kill') as kill:
            gui.safe_signal(old, gui.signal.SIGTERM)
            kill.assert_not_called()

    def test_cleanup_selection_requires_both_new_birth_and_exact_trial_home(self):
        rows = [dict(pid=1, birth='same', selected={'HOME': '/trial'}),
                dict(pid=2, birth='new', selected={'HOME': '/trial'}),
                dict(pid=3, birth='new', selected={'HOME': '/real'}),
                dict(pid=4, birth='new', selected={})]
        with patch.object(gui, 'processes', return_value=rows):
            self.assertEqual([p['pid'] for p in gui.owned_processes(Path('/trial'), {'1': 'same'})], [2])

    def test_modified_accepted_profile_blocks_before_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'config-test'
            config = root / 'profile-home/.config'
            config.mkdir(parents=True)
            (config / 'file').write_text('accepted')
            manifest = root / 'profile-manifest.json'
            manifest.write_text(json.dumps(gui.inventory(config)))
            (root / 'report.json').write_text(json.dumps({'source_commit': gui.SOURCE_PIN}))
            pin = gui.sha(manifest)
            (config / 'file').write_text('changed')
            with patch.object(gui, 'MANIFEST_PIN', pin):
                with self.assertRaisesRegex(RuntimeError, 'changed'):
                    gui.locate_profile(Path(directory))

    def test_existing_compositor_blocks_before_any_profile_or_manager_operation(self):
        with tempfile.TemporaryDirectory() as directory:
            probe = gui.Probe(Path(directory))
            with patch.object(gui, 'processes', return_value=[{'executable': 'Hyprland'}]), patch.object(gui, 'locate_profile') as locate:
                with self.assertRaisesRegex(RuntimeError, 'existing compositor'):
                    gui.trial(probe, Path(directory), {})
                locate.assert_not_called()
            self.assertFalse(probe.commands)

    def test_existing_portal_owner_is_preserved_before_initializer_can_restart_it(self):
        with tempfile.TemporaryDirectory() as directory:
            probe = gui.Probe(Path(directory))
            with patch.object(gui, 'processes', return_value=[{'executable': 'xdg-desktop-portal'}]), patch.object(gui, 'locate_profile') as locate:
                with self.assertRaisesRegex(RuntimeError, 'runtime owners'):
                    gui.trial(probe, Path(directory), {})
                locate.assert_not_called()
            self.assertFalse(probe.commands)

    def test_cleanup_wait_failure_still_restores_manager_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source'
            source.mkdir()
            (source / 'fixture').write_text('profile')
            work = root / 'trial-fixture'
            work.mkdir()
            probe = gui.Probe(work)
            probe.manager = lambda label: {}
            probe.run = lambda *args, **kwargs: subprocess.CompletedProcess([], 0, b'', b'')
            child = type('Child', (), {'poll': lambda self: 0,
                         'wait': lambda self, **kw: (_ for _ in ()).throw(subprocess.TimeoutExpired('trial', 10))})()
            with patch.object(gui, 'repair_wallpaper'), patch.object(gui, 'processes', return_value=[]), patch.object(gui, 'owned_processes', return_value=[]), patch.object(gui, 'locate_profile', return_value=source), patch.object(gui.subprocess, 'Popen', return_value=child), patch.object(gui.time, 'sleep'), patch.object(gui, 'restore_manager') as restore, contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError, 'cleanup failed'):
                    gui.trial(probe, root, {})
                restore.assert_called_once()
            row = json.loads((work / 'commands.json').read_text())[-1]
            self.assertEqual(row['label'], 'compositor-session')
            self.assertEqual(row['combined_sha256'], gui.sha(work / 'logs/compositor.combined'))

    def test_recovery_rejects_checkpoint_for_another_uid(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'trial-test/restore-manager.json'
            path.parent.mkdir()
            path.write_text(json.dumps({'uid': os.getuid() + 1, 'managed': {}}))
            with self.assertRaisesRegex(RuntimeError, 'Invalid private recovery'):
                gui.recover_manager(None, root)
            self.assertTrue(path.exists())

    def test_archive_excludes_profile_and_private_restore_checkpoint(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory) / 'trial-fixture'
            work.mkdir()
            (work / 'logs').mkdir()
            (work / 'restore-manager.json').write_text('PRIVATE SNAPSHOT')
            (work / 'profile-home').mkdir()
            (work / 'profile-home/private').write_text('PRIVATE PROFILE')
            with contextlib.redirect_stdout(io.StringIO()):
                gui.seal(work, {'status': 'BLOCKED'})
            with gui.tarfile.open(work.with_suffix('.tar.gz')) as archive:
                self.assertEqual(set(archive.getnames()), {'report.json', 'SHA256SUMS'})

if __name__ == '__main__':
    unittest.main()
