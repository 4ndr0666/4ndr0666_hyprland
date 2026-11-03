"""Real libblkid signature erasure through inherited, already-open file FDs."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch
import zlib

SCRIPT = Path(__file__).resolve().parents[2] / 'install_arch-pi4.sh'
SOURCE = SCRIPT.read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
app = types.ModuleType('native_signature_test')
exec(compile(SOURCE, str(SCRIPT), 'exec'), app.__dict__)


class SignatureCleanerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'ordinary-test-file'
        with self.path.open('wb') as stream:
            stream.truncate(4 * 1024**2)
        self.report = {'commands': []}

    def make_gpt(self, stale_primary=False):
        sectors = self.path.stat().st_size // 512
        entries = bytes(128 * 128)
        entry_crc = zlib.crc32(entries)
        def header(current, alternate, table):
            raw = bytearray(struct.pack('<8sIIIIQQQQ16sQIII', b'EFI PART', 0x10000, 92, 0, 0,
                    current, alternate, 34, sectors - 34, b'1' * 16, table, 128, 128, entry_crc))
            struct.pack_into('<I', raw, 16, zlib.crc32(raw))
            return raw
        with self.path.open('r+b') as stream:
            stream.seek(446)
            stream.write(struct.pack('<B3sB3sII', 0, b'\x00\x02\x00', 0xee, b'\xff'*3, 1, sectors - 1))
            stream.seek(510); stream.write(b'\x55\xaa')
            stream.seek(512); stream.write(header(1, sectors - 1, 2))
            stream.seek(1024); stream.write(entries)
            stream.seek((sectors - 33) * 512); stream.write(entries)
            stream.seek((sectors - 1) * 512); stream.write(header(sectors - 1, 1, sectors - 33))
            if stale_primary:
                stream.seek(512); stream.write(b'BROKEN!!')

    def scan(self):
        if not shutil.which('wipefs'):
            self.skipTest('read-only reference scanner not installed')
        return subprocess.run(['wipefs', '--no-act', '--output', 'OFFSET,TYPE', '--', str(self.path)],
                              capture_output=True, check=True, timeout=30).stdout.decode()

    def clean(self, fd, identity=None):
        app.erase_signatures(fd, os.fstat(fd).st_rdev if identity is None else identity, self.report)
        return json.loads(self.report['commands'][-1]['stdout'])

    def test_real_gpt_primary_backup_and_protective_mbr_are_cleared(self):
        self.make_gpt()
        self.assertIn('gpt', self.scan())
        self.assertEqual(self.path.read_bytes()[-512:-504], b'EFI PART')
        with self.path.open('r+b', buffering=0) as target:
            result = self.clean(target.fileno())
            self.assertGreaterEqual(result['erased_signatures'], 3)
            self.assertGreaterEqual(os.fstat(target.fileno()).st_size, 4 * 1024**2)
        self.assertNotIn('gpt', self.scan())
        self.assertNotEqual(self.path.read_bytes()[-512:-504], b'EFI PART')

    def test_stale_backup_gpt_is_removed_even_with_broken_primary(self):
        self.make_gpt(stale_primary=True)
        self.assertIn('gpt', self.scan())
        with self.path.open('r+b', buffering=0) as target:
            self.clean(target.fileno())
        self.assertNotEqual(self.path.read_bytes()[-512:-504], b'EFI PART')
        self.assertNotIn('gpt', self.scan())

    def test_repeat_cleanup_is_idempotent_and_keeps_parent_fd_open(self):
        self.make_gpt()
        with self.path.open('r+b', buffering=0) as target:
            self.clean(target.fileno())
            first = hashlib.sha256(self.path.read_bytes()).hexdigest()
            second = self.clean(target.fileno())
            self.assertEqual(second['erased_signatures'], 0)
            self.assertEqual(first, hashlib.sha256(self.path.read_bytes()).hexdigest())
            os.fstat(target.fileno())

    def test_replaced_path_is_not_opened_or_modified(self):
        self.make_gpt()
        with self.path.open('r+b', buffering=0) as target:
            old = self.path.with_name('held-old-file')
            self.path.rename(old)
            self.path.write_bytes(b'new unrelated file')
            self.clean(target.fileno())
            self.assertNotEqual(old.read_bytes()[-512:-504], b'EFI PART')
            self.assertEqual(self.path.read_bytes(), b'new unrelated file')
            command = self.report['commands'][-1]['argv']
            self.assertNotIn(str(self.path), command)
            self.assertNotIn(str(old), command)
            self.assertNotIn('--force', command)

    def test_wrong_inherited_identity_fails_without_erasure(self):
        self.make_gpt()
        before = hashlib.sha256(self.path.read_bytes()).hexdigest()
        with self.path.open('r+b', buffering=0) as target:
            with self.assertRaises(app.Refusal):
                self.clean(target.fileno(), identity=9999)
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), before)
        self.assertIn('identity mismatch', self.report['commands'][-1]['stderr'])

    def test_read_only_descriptor_reports_native_wipe_error(self):
        self.make_gpt()
        before = hashlib.sha256(self.path.read_bytes()).hexdigest()
        with self.path.open('rb', buffering=0) as target:
            with self.assertRaises(app.Refusal):
                self.clean(target.fileno())
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), before)
        self.assertIn('erase signature', self.report['commands'][-1]['stderr'])

    def test_timeout_kills_actual_helper_before_any_image_write(self):
        real_run = subprocess.run
        def short_watchdog(argv, **kwargs):
            self.assertEqual(kwargs['timeout'], 120)
            kwargs['timeout'] = 0.1
            return real_run(argv, **kwargs)
        before = hashlib.sha256(self.path.read_bytes()).hexdigest()
        with self.path.open('r+b', buffering=0) as target, \
             patch.object(app, 'SIGNATURE_CLEANER', 'import time; time.sleep(60)'), \
             patch.object(app.subprocess, 'run', side_effect=short_watchdog):
            with self.assertRaises(app.Refusal):
                self.clean(target.fileno())
            os.fstat(target.fileno())
        self.assertEqual(self.report['commands'][-1]['exit_status'], 124)
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), before)


if __name__ == '__main__':
    unittest.main(verbosity=2)
