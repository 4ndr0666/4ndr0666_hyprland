"""Real local Git acquisition with only the fixed HTTPS transport substituted.

No network, privileged operation, target code execution or physical disk access.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[2] / 'install_arch-pi4.sh'
SOURCE = SCRIPT.read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
app = types.ModuleType('source_fetch_under_test')
exec(compile(SOURCE, str(SCRIPT), 'exec'), app.__dict__)


class SourceFetchTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / 'fixture'
        self.git('init', '--quiet', self.repo)
        self.git('-C', self.repo, 'config', 'user.name', 'Fixture')
        self.git('-C', self.repo, 'config', 'user.email', 'fixture@localhost')
        (self.repo / 'source.txt').write_text('baseline\n')
        self.git('-C', self.repo, 'add', 'source.txt')
        self.git('-C', self.repo, 'commit', '--quiet', '-m', 'baseline')
        (self.repo / 'source.txt').write_text('pinned candidate\n')
        self.git('-C', self.repo, 'commit', '--quiet', '-am', 'pinned candidate')
        self.pin = (self.git('-C', self.repo, 'rev-parse', 'HEAD'),
                    self.git('-C', self.repo, 'rev-parse', 'HEAD^{tree}'))
        self.remote = self.root / 'remote.git'
        self.git('clone', '--quiet', '--bare', self.repo, self.remote)
        self.cache = self.root / 'cache'
        self.cache.mkdir()
        self.profile = self.cache / 'session.json'
        self.ui = types.SimpleNamespace(folder=self.cache, saved={}, uid=os.getuid(),
                                        gid=os.getgid(), say=lambda message: None)
        self.ui.save = lambda: self.profile.write_text(json.dumps(self.ui.saved))
        self.ui.private_file = self.private_file
        self.original_run = subprocess.run
        self.fetches = []

    def git(self, *args):
        result = subprocess.run(['git', *map(str, args)], capture_output=True,
                                text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def private_file(self, label, text):
        descriptor, name = tempfile.mkstemp(prefix=label + '.', suffix='.json', dir=self.cache)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(text)
        return name

    def substitute_transport(self, args, *positional, **kwargs):
        original = list(map(str, args))
        if 'fetch' in original:
            self.fetches.append(original)
            self.assertEqual(original[-2:], [app.SOURCE_URL, self.pin[0]])
            self.assertIn('protocol.allow=never', original)
            self.assertIn('protocol.https.allow=always', original)
            self.assertIn('core.hooksPath=/dev/null', original)
            self.assertIn('--no-tags', original)
            self.assertIn('--no-recurse-submodules', original)
            # Test-only transport replacement; production argv is still recorded
            # by app.run and its HTTPS restriction is asserted above.
            actual = original[:-2] + [str(self.remote), self.pin[0]]
            at = actual.index('fetch')
            actual[at:at] = ['-c', 'protocol.file.allow=always']
            return self.original_run(actual, *positional, **kwargs)
        return self.original_run(args, *positional, **kwargs)

    def acquire(self, expected=None, transport=None):
        with patch.object(app, 'R6', expected or self.pin), \
             patch.object(app.subprocess, 'run', side_effect=transport or self.substitute_transport):
            return Path(app.fetch_source_bundle(self.ui, 'r6'))

    def evidence(self):
        return json.loads(Path(self.ui.saved['last_source_fetch_evidence']).read_text())

    def test_exact_fetch_creates_full_cloneable_verified_bundle(self):
        bundle = self.acquire()
        self.assertEqual(len(self.fetches), 1)
        self.assertEqual(app.digest(bundle), self.ui.saved['source_cache_hashes'][self.pin[0]])
        self.assertEqual(self.git('bundle', 'list-heads', bundle),
                         self.pin[0] + ' refs/heads/recovery-r6')
        with bundle.open('rb') as stream:
            self.assertEqual(stream.readline().strip(), b'# v2 git bundle')
            while True:
                line = stream.readline()
                self.assertTrue(line, 'bundle header was truncated')
                if line == b'\n':
                    break
                self.assertFalse(line.startswith(b'-'), 'full recovery bundle has a prerequisite')
        clone = self.root / 'independent-clone'
        self.git('clone', '--quiet', '--no-checkout', bundle, clone)
        self.git('-C', clone, 'checkout', '--quiet', '--detach', self.pin[0])
        self.assertEqual(self.git('-C', clone, 'rev-parse', 'HEAD^{tree}'), self.pin[1])
        self.git('-C', clone, 'fsck', '--full', '--strict')
        self.assertEqual((clone / 'source.txt').read_text(), 'pinned candidate\n')
        self.assertFalse(list(self.cache.glob('source-fetch.*/')))
        evidence = self.evidence()
        self.assertEqual((evidence['commit'], evidence['tree']), self.pin)
        self.assertTrue(all(record['exit_status'] == 0 for record in evidence['commands']))
        self.assertEqual([record['argv'][-2:] for record in evidence['commands']
                          if 'fetch' in record['argv']], [[app.SOURCE_URL, self.pin[0]]])

    def test_verified_cache_reuses_without_fetch(self):
        bundle = self.acquire()
        saved_hash = app.digest(bundle)
        with patch.object(app, 'R6', self.pin), \
             patch.object(app, 'run', side_effect=AssertionError('cache attempted a command')):
            self.assertEqual(Path(app.fetch_source_bundle(self.ui, 'r6')), bundle)
        self.assertEqual(app.digest(bundle), saved_hash)
        self.assertEqual(len(self.fetches), 1)

    def test_tampered_cache_is_preserved_and_refused_without_fetch(self):
        bundle = self.acquire()
        bundle.write_bytes(b'corrupted cache')
        with patch.object(app, 'R6', self.pin), \
             patch.object(app, 'run', side_effect=AssertionError('tampered cache attempted fetch')):
            with self.assertRaisesRegex(app.Refusal, 'integrity mismatch'):
                app.fetch_source_bundle(self.ui, 'r6')
        self.assertEqual(bundle.read_bytes(), b'corrupted cache')

    def test_fetch_failure_records_exit_and_never_substitutes_moving_head(self):
        def failure(args, *positional, **kwargs):
            if 'fetch' in args:
                self.fetches.append(list(args))
                return subprocess.CompletedProcess(args, 128, b'', b'fixture: commit unavailable')
            return self.original_run(args, *positional, **kwargs)
        with self.assertRaisesRegex(app.Refusal, 'No branch-tip fallback occurred'):
            self.acquire(transport=failure)
        self.assertEqual(len(self.fetches), 1)
        self.assertEqual(self.fetches[0][-2:], [app.SOURCE_URL, self.pin[0]])
        self.assertFalse(list(self.cache.glob('*.bundle')))
        self.assertFalse(list(self.cache.glob('source-fetch.*/')))
        failed = [record for record in self.evidence()['commands'] if record['exit_status']]
        self.assertEqual([record['exit_status'] for record in failed], [128])

    def test_wrong_tree_refuses_publication_and_cleans_temporary_repository(self):
        with self.assertRaisesRegex(app.Refusal, 'tree mismatch'):
            self.acquire(expected=(self.pin[0], '0' * 40))
        self.assertFalse(list(self.cache.glob('*.bundle')))
        self.assertFalse(list(self.cache.glob('source-fetch.*/')))
        self.assertNotIn('source_cache_hashes', self.ui.saved)
        evidence = self.evidence()
        tree_record = evidence['commands'][-1]
        self.assertEqual(tree_record['argv'][-1], self.pin[0] + '^{tree}')
        self.assertEqual(tree_record['stdout'].strip(), self.pin[1])
        self.assertTrue(all('bundle' not in record['argv'] for record in evidence['commands']))

    def test_unrecorded_cache_is_refused_without_overwrite(self):
        destination = self.cache / ('source-' + self.pin[0] + '.bundle')
        destination.write_bytes(b'user-owned unrecorded file')
        with patch.object(app, 'R6', self.pin), \
             patch.object(app, 'run', side_effect=AssertionError('unrecorded cache attempted fetch')):
            with self.assertRaisesRegex(app.Refusal, 'Unrecorded source cache preserved'):
                app.fetch_source_bundle(self.ui, 'r6')
        self.assertEqual(destination.read_bytes(), b'user-owned unrecorded file')


if __name__ == '__main__':
    unittest.main(verbosity=2)
