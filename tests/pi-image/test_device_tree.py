"""lsblk omits hierarchy without NAME or --tree; no device is ever written."""
import argparse
import contextlib
import copy
import io
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch, MagicMock

SCRIPT = Path(__file__).resolve().parents[2] / 'install_arch-pi4.sh'
SOURCE = SCRIPT.read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
app = types.ModuleType('device_tree_under_test')
exec(compile(SOURCE, str(SCRIPT), 'exec'), app.__dict__)


class DeviceTreeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.device = self.root / 'card'; self.device.write_bytes(b'untouched card')
        self.image = self.root / 'image.img'
        with self.image.open('wb') as stream:
            stream.truncate(2 * 1024**3)
        self.disk = {'path': str(self.device), 'type': 'disk', 'size': 4 * 1024**3,
                     'ro': False, 'mountpoints': [], 'children': [
                         {'path': str(self.device) + '1', 'type': 'part',
                          'size': 4 * 1024**3, 'ro': False, 'mountpoints': []}]}
        self.args = argparse.Namespace(flash=str(self.image), device=str(self.device), image_sha256='0' * 64)
        self.commands = []

    def selected_provider(self, argv, **kwargs):
        self.commands.append(argv)
        if argv[0] != 'lsblk':
            return ''
        disk = copy.deepcopy(self.disk)
        if '--tree' in argv:
            return json.dumps({'blockdevices': [disk]})
        # The real PATH-only default is a flat list, not one root with children.
        children = disk.pop('children')
        return json.dumps({'blockdevices': [disk, *children]})

    @contextlib.contextmanager
    def flash_environment(self):
        with patch.object(app.os, 'geteuid', return_value=0), \
             patch.object(app, 'executable_tools'), patch.object(app, 'digest', return_value='0' * 64), \
             patch.object(app.stat, 'S_ISBLK', return_value=True), \
             patch.object(app, 'run', side_effect=self.selected_provider), \
             patch.object(app, 'flash_copy', side_effect=AssertionError('unexpected write')), \
             contextlib.redirect_stdout(io.StringIO()):
            yield

    def test_partitioned_card_reaches_confirmation_and_rejection_never_writes(self):
        terminal = MagicMock()
        terminal.__enter__.return_value.readline.return_value = 'NO\n'
        with self.flash_environment(), patch.object(app, 'ControlTerminal', return_value=terminal):
            with self.assertRaisesRegex(app.Refusal, 'Confirmation did not match'):
                app.flash(self.args)
        self.assertIn('--tree', next(argv for argv in self.commands if argv[0] == 'lsblk'))
        self.assertEqual(self.device.read_bytes(), b'untouched card')

    def test_mounted_child_is_rejected_before_confirmation(self):
        self.disk['children'][0]['mountpoints'] = ['/home']
        with self.flash_environment(), patch.object(app, 'ControlTerminal') as terminal:
            with self.assertRaisesRegex(app.Refusal, 'mounted filesystem'):
                app.flash(self.args)
        terminal.assert_not_called()
        self.assertEqual(self.device.read_bytes(), b'untouched card')

    def test_picker_requests_tree_and_excludes_disk_with_system_partition(self):
        host = copy.deepcopy(self.disk)
        host['path'] = '/dev/host'
        host['children'][0]['path'] = '/dev/host1'
        host['children'][0]['mountpoints'] = ['/']
        offered = []
        def provider(argv, **kwargs):
            if argv[0] != 'lsblk':
                return ''
            disks = [copy.deepcopy(host), copy.deepcopy(self.disk)]
            if '--tree' not in argv:
                disks = [item for disk in disks for item in [disk, *disk.pop('children')]]
            return json.dumps({'blockdevices': disks})
        def choose(title, options):
            offered.extend(value for value, _ in options)
            return str(self.device)
        ui = types.SimpleNamespace(choose=choose)
        with patch.object(app, 'run', side_effect=provider):
            self.assertEqual(app.target_picker(ui, 2 * 1024**3), str(self.device))
        self.assertNotIn('/dev/host', offered)
        self.assertIn(str(self.device), offered)

    def test_unexpected_multiple_roots_remain_rejected(self):
        inventory = {'blockdevices': [self.disk, copy.deepcopy(self.disk)]}
        with self.assertRaises(app.Refusal):
            app.validate_target(str(self.device), 1, inventory, set())


if __name__ == '__main__':
    unittest.main(verbosity=2)
