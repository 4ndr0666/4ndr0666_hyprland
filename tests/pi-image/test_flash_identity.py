"""Descriptor-bound flash tests: all targets are ordinary temporary files."""
import contextlib
import hashlib
import io
import os
from pathlib import Path
import stat
import shutil
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / 'install_arch-pi4.sh'
SOURCE = SCRIPT.read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
app = types.ModuleType('flash_under_test')
exec(compile(SOURCE, str(SCRIPT), 'exec'), app.__dict__)


class FlashIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.image = self.root / 'image'
        self.image.write_bytes(b'new image bytes' * 101)
        self.device = self.root / 'ordinary-file-target'
        self.original = b'original user data' * 200
        self.device.write_bytes(self.original)
        self.expected = hashlib.sha256(self.image.read_bytes()).hexdigest()
        self.report = {'authorized_rdev': 1234, 'commands': []}

    def test_missing_authorization_never_opens_or_wipes(self):
        with patch.object(app.os, 'open') as opened, patch.object(app.subprocess, 'run') as command:
            with self.assertRaises(app.Refusal):
                app.flash_copy(self.image, str(self.device), self.expected, {'commands': []})
        opened.assert_not_called()
        command.assert_not_called()
        self.assertEqual(self.device.read_bytes(), self.original)

    def test_failed_exclusive_open_never_runs_destructive_command(self):
        with patch.object(app.os, 'open', side_effect=PermissionError('busy')) as opened, \
             patch.object(app.subprocess, 'run') as command:
            with self.assertRaises(PermissionError):
                app.flash_copy(self.image, str(self.device), self.expected, self.report)
        self.assertTrue(opened.call_args.args[1] & os.O_EXCL)
        command.assert_not_called()
        self.assertEqual(self.device.read_bytes(), self.original)

    def test_changed_open_device_is_rejected_before_wipe_and_descriptor_closes(self):
        original_open = os.open
        descriptors = []
        def target_open(path, flags):
            fd = original_open(path, flags)
            descriptors.append(fd)
            return fd
        with patch.object(app.os, 'open', side_effect=target_open), \
             patch.object(app.os, 'fstat', return_value=types.SimpleNamespace(st_mode=stat.S_IFBLK, st_rdev=9876)), \
             patch.object(app.subprocess, 'run') as command:
            with self.assertRaises(app.Refusal):
                app.flash_copy(self.image, str(self.device), self.expected, self.report)
        command.assert_not_called()
        self.assertEqual(self.device.read_bytes(), self.original)
        with self.assertRaises(OSError):
            os.fstat(descriptors[0])

    @contextlib.contextmanager
    def fake_block_target(self, subprocess_result):
        events = []
        original_open = os.open
        def target_open(path, flags):
            events.append('exclusive-open')
            self.assertTrue(flags & os.O_EXCL)
            return original_open(path, flags)
        def command(argv, **kwargs):
            events.append('wipefs')
            fd = kwargs['pass_fds'][0]
            self.assertEqual(argv[:3], [app.sys.executable, '-I', '-c'])
            self.assertEqual(argv[3], app.SIGNATURE_CLEANER)
            self.assertEqual(argv[4:], [str(fd), '1234'])
            self.assertNotIn('--force', argv)
            self.assertFalse(any('/proc/self/fd/' in argument for argument in argv))
            self.assertEqual(kwargs['timeout'], 120)
            self.assertIsNotNone(os.readlink('/proc/self/fd/' + str(fd)))
            if isinstance(subprocess_result, BaseException):
                raise subprocess_result
            return subprocess_result
        def ioctl(fd, request):
            self.assertTrue(os.readlink('/proc/self/fd/' + str(fd)).endswith('ordinary-file-target'))
            events.append(('ioctl', request))
        with patch.object(app.os, 'open', side_effect=target_open), \
             patch.object(app.os, 'fstat', return_value=types.SimpleNamespace(st_mode=stat.S_IFBLK, st_rdev=1234)), \
             patch.object(app.subprocess, 'run', side_effect=command), \
             patch.object(app.fcntl, 'ioctl', side_effect=ioctl), \
             patch.object(app, 'run', return_value=''), contextlib.redirect_stdout(io.StringIO()):
            yield events

    def test_same_descriptor_is_held_through_wipe_write_readback_and_reread(self):
        success = types.SimpleNamespace(returncode=0, stdout=b'', stderr=b'')
        with self.fake_block_target(success) as events:
            app.flash_copy(self.image, str(self.device), self.expected, self.report)
        self.assertEqual(events, ['exclusive-open', 'wipefs', ('ioctl', 0x1261), ('ioctl', 0x125f)])
        self.assertEqual(self.device.read_bytes()[:self.image.stat().st_size], self.image.read_bytes())
        self.assertEqual(self.report['readback_sha256'], self.expected)
        self.assertEqual(self.report['commands'][0]['exit_status'], 0)

    def test_wipe_failure_stops_before_image_write_and_records_status(self):
        failure = types.SimpleNamespace(returncode=16, stdout=b'', stderr=b'cannot clear signature')
        with self.fake_block_target(failure) as events:
            with self.assertRaises(app.Refusal):
                app.flash_copy(self.image, str(self.device), self.expected, self.report)
        self.assertEqual(events, ['exclusive-open', 'wipefs'])
        self.assertEqual(self.device.read_bytes(), self.original)
        self.assertEqual(self.report['commands'][0]['exit_status'], 16)

    def test_wipe_timeout_stops_before_image_write_and_records_status(self):
        timeout = subprocess.TimeoutExpired(['wipefs'], 120, stderr=b'timed out')
        with self.fake_block_target(timeout):
            with self.assertRaises(app.Refusal):
                app.flash_copy(self.image, str(self.device), self.expected, self.report)
        self.assertEqual(self.device.read_bytes(), self.original)
        self.assertEqual(self.report['commands'][0]['exit_status'], 124)

    @unittest.skipUnless(shutil.which('mkswap') and shutil.which('wipefs'), 'regular-file signature tools unavailable')
    def test_real_wipefs_accepts_inherited_descriptor_on_regular_file(self):
        # Keep wipefs as a real read-only reference scanner. Production cleanup
        # now uses libblkid's existing-fd API; no pathname is reopened.
        with self.device.open('wb') as stream:
            stream.truncate(2 * 1024**2)
        self.device.chmod(0o600)
        subprocess.run(['mkswap', '--', str(self.device)], capture_output=True, check=True, timeout=30)
        before = subprocess.run(['wipefs', '--no-act', '--', str(self.device)],
                                capture_output=True, check=True, timeout=30)
        self.assertIn(b'swap', before.stdout)
        self.report['authorized_rdev'] = 0  # Actual ordinary-file identity in child.
        with patch.object(app.os, 'fstat', return_value=types.SimpleNamespace(st_mode=stat.S_IFBLK, st_rdev=0)), \
             patch.object(app.fcntl, 'ioctl'), patch.object(app, 'run', return_value=''), \
             contextlib.redirect_stdout(io.StringIO()):
            app.flash_copy(self.image, str(self.device), self.expected, self.report)
        self.assertEqual(self.report['commands'][0]['exit_status'], 0)
        self.assertEqual(self.device.read_bytes()[:self.image.stat().st_size], self.image.read_bytes())
        after = subprocess.run(['wipefs', '--no-act', '--', str(self.device)],
                               capture_output=True, check=True, timeout=30)
        self.assertNotIn(b'swap', after.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
