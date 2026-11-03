import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('stage_config',
    Path(__file__).resolve().parents[2] / 'scripts/pi-r7-stage-config.py')
stage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stage)

class Fixture:
    def __init__(self, root):
        self.user_home = root / 'user'
        self.state = self.user_home / '.local/state/gup-r7'
        self.source = self.state / 'integration-fixture/source'
        (self.source / '.git').mkdir(parents=True)
        self.work = self.state / 'config-fixture'
        self.work.mkdir()
        (self.work / 'logs').mkdir()
        config = self.source / 'config'
        for name, content in {'hypr/hyprland.lua': '-- candidate', 'hypr/initial-boot.sh': '#!/bin/sh\nexit 0',
                              'hypr/wallpaper_effects/.wallpaper_current': 'image fixture',
                              'hypr/UserScripts/helper.py': '# fixture', 'hypr/scripts/helper.sh': '# fixture',
                              'wallust/wallust.toml': "[templates]\ncolors.template='input'\ncolors.target='~/.config/hypr/colors'\n"}.items():
            path = config / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        original = self.user_home / '.config/hypr/user-owned.txt'
        original.parent.mkdir(parents=True)
        original.write_text('retain my settings')
        self.env = stage.profile_environment(self.work)
        self.calls, self.fail, self.validator_output = [], None, ''
        self.responses = {}

    def run(self, label, argv, **kwargs):
        self.calls.append((label, [str(a) for a in argv]))
        if label == self.fail:
            raise RuntimeError(label + ' failed')
        if label == 'clone-corrected-source':
            shutil.copytree(self.source, Path(argv[-1]))
        value = self.validator_output if label == 'hyprland-verify-config' else ''
        (self.work / 'logs' / (label + '.stdout')).write_text(value)
        (self.work / 'logs' / (label + '.stderr')).write_text('')
        return value

    def git(self, source, label, *args):
        self.calls.append((label, ['git', *args]))
        return self.responses.get(label, {'source-head-0': stage.PIN, 'corrected-source-commit': stage.PIN,
            'source-tree': stage.TREE, 'refs-before': 'stable', 'refs-after': 'stable'}.get(label, ''))

class ConfigStageTests(unittest.TestCase):
    def test_corrected_source_is_acquired_without_checking_out_over_old_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Fixture(Path(directory))
            fixture.responses['source-head-0'] = 'old-source-commit'
            original = stage.inventory_hash(fixture.source)
            self.collect(fixture, {})
            self.assertEqual(original, stage.inventory_hash(fixture.source))
            checkout = [(label, argv) for label, argv in fixture.calls if label == 'checkout-corrected-source']
            self.assertEqual(len(checkout), 1)
            self.assertEqual(checkout[0][1][-3:], ['checkout', '--detach', stage.PIN])
            self.assertTrue((fixture.work / 'source').is_dir())

    def collect(self, fixture, report):
        with patch.object(stage.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 2 * 1024**3})()):
            stage.collect(fixture, fixture.state, fixture.user_home, report)

    def test_success_stages_without_overwriting_user_configuration_or_launching_gui(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture, report = Fixture(Path(directory)), {}
            before = stage.inventory_hash(fixture.user_home / '.config/hypr')
            self.collect(fixture, report)
            self.assertEqual(before, stage.inventory_hash(fixture.user_home / '.config/hypr'))
            self.assertEqual(report['status'], 'PRIVATE_PROFILE_NATIVE_VALIDATION_PASSED_REVIEW_REQUIRED')
            self.assertTrue((fixture.work / 'launch-trial.sh').exists())
            verify = next(args for label, args in fixture.calls if label == 'hyprland-verify-config')
            self.assertEqual(verify[:3], ['Hyprland', '--verify-config', '--config'])
            for _, args in fixture.calls:
                self.assertFalse(set(args) & {'sudo', 'enable', 'start', 'stop', 'select_network', 'scan'})
            subprocess.run(['bash', '-n', str(fixture.work / 'launch-trial.sh')], check=True)

    def test_render_failure_never_invokes_native_config_or_prepares_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Fixture(Path(directory))
            fixture.fail = 'wallust-render'
            with self.assertRaisesRegex(RuntimeError, 'wallust-render'):
                self.collect(fixture, {})
            self.assertFalse(any(label == 'hyprland-verify-config' for label, _ in fixture.calls))
            self.assertFalse((fixture.work / 'launch-trial.sh').exists())
            self.assertEqual((fixture.user_home / '.config/hypr/user-owned.txt').read_text(), 'retain my settings')

    def test_native_failure_does_not_write_launch_or_replace_user_files(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Fixture(Path(directory))
            fixture.fail = 'hyprland-verify-config'
            before = stage.inventory_hash(fixture.user_home / '.config/hypr')
            with self.assertRaisesRegex(RuntimeError, 'verify-config'):
                self.collect(fixture, {})
            self.assertEqual(before, stage.inventory_hash(fixture.user_home / '.config/hypr'))
            self.assertFalse((fixture.work / 'launch-trial.sh').exists())

    def test_printed_config_error_blocks_even_with_zero_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Fixture(Path(directory))
            fixture.validator_output = '[ERR] Lua error: unsupported API'
            with self.assertRaisesRegex(RuntimeError, 'reported errors'):
                self.collect(fixture, {})
            self.assertFalse((fixture.work / 'launch-trial.sh').exists())

    def test_template_escape_is_rejected_before_renderer(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Fixture(Path(directory))
            (fixture.source / 'config/wallust/wallust.toml').write_text("[templates]\ncolors.target='~/.config/../../outside'\n")
            with self.assertRaisesRegex(RuntimeError, 'escapes'):
                self.collect(fixture, {})
            self.assertFalse(any(label == 'wallust-render' for label, _ in fixture.calls))

    def test_absolute_or_escaping_symlink_is_rejected_before_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Fixture(Path(directory))
            (fixture.source / 'config/escape').symlink_to('/etc')
            with self.assertRaisesRegex(RuntimeError, 'escaping'):
                self.collect(fixture, {})
            self.assertFalse(Path(fixture.env['HOME']).exists())

    def test_private_environment_is_complete_and_drops_inherited_compositor_target(self):
        with patch.dict(stage.os.environ, {'HOME': '/real-home', 'HYPRLAND_INSTANCE_SIGNATURE': 'live', 'XDG_CONFIG_HOME': '/real-config'}, clear=True):
            env = stage.profile_environment(Path('/private'))
        self.assertEqual(env['HOME'], '/private/profile-home')
        self.assertEqual(env['XDG_CONFIG_HOME'], '/private/profile-home/.config')
        self.assertNotIn('HYPRLAND_INSTANCE_SIGNATURE', env)

    def test_launcher_refuses_remote_or_nested_execution_before_compositor(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'launch.sh'
            path.write_text(stage.make_launcher(Path(directory)))
            result = subprocess.run(['bash', str(path)], env=dict(os.environ, SSH_CONNECTION='remote'), capture_output=True)
            self.assertEqual(result.returncode, 20)

if __name__ == '__main__':
    unittest.main()
