"""Readiness checks cannot become an installer or bypass source/kernel pins."""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import tarfile
import unittest
from unittest.mock import patch

SCRIPT=Path(__file__).resolve().parents[2]/'scripts/pi-r7-readiness.py'
spec=importlib.util.spec_from_file_location('r7_readiness',SCRIPT)
app=importlib.util.module_from_spec(spec); spec.loader.exec_module(app)

def manifest(core='curl',aur=''):
    return ''.join(name+'=(\n'+(core if name=='CORE_PACKAGES' else aur if name=='AUR_PACKAGES' else '')+'\n)\n'
                   for name in app.GROUPS)

class ReadinessTests(unittest.TestCase):
    def test_inherited_git_context_cannot_redirect_private_checkout(self):
        original={'GIT_DIR':'/unrelated/repo.git','GIT_WORK_TREE':'/unrelated/work',
                  'GIT_INDEX_FILE':'/unrelated/index','GIT_CONFIG_COUNT':'1',
                  'GIT_CONFIG_KEY_0':'core.worktree','GIT_CONFIG_VALUE_0':'/unrelated/work',
                  'HTTPS_PROXY':'http://example.invalid:8080','GIT_SSL_CAINFO':'/trusted/ca.pem'}
        isolated=app.probe_environment(original)
        self.assertNotIn('GIT_DIR',isolated)
        self.assertNotIn('GIT_WORK_TREE',isolated)
        self.assertNotIn('GIT_INDEX_FILE',isolated)
        self.assertNotIn('GIT_CONFIG_COUNT',isolated)
        self.assertEqual(isolated['HTTPS_PROXY'],original['HTTPS_PROXY'])
        self.assertEqual(isolated['GIT_SSL_CAINFO'],original['GIT_SSL_CAINFO'])
        self.assertEqual(isolated['GIT_NO_REPLACE_OBJECTS'],'1')
        self.assertIn('GIT_DIR',original)

    def test_literal_manifest_and_injection_refusal(self):
        self.assertEqual(app.parse_manifest(manifest('curl curl dbus','wallust')),(['curl','dbus'],['wallust']))
        with self.assertRaises(RuntimeError): app.parse_manifest(manifest('"${UNKNOWN[@]}"'))

    def test_kernel_gate_uses_exact_package_owned_release(self):
        self.assertTrue(app.kernel_matches('7.3.1-2-aarch64-ARCH','/usr/lib/modules/7.3.1-2-aarch64-ARCH/kernel/'))
        self.assertFalse(app.kernel_matches('7.1.6-1-aarch64-ARCH','/usr/lib/modules/7.3.1-2-aarch64-ARCH/kernel/'))
        self.assertFalse(app.kernel_matches('7.3.1','/usr/lib/modules/7.3.1-other/'))

    def test_split_package_arch_overrides_only_selected_output(self):
        text='pkgbase = sample\n arch = x86_64\npkgname = fonts\n arch = any\npkgname = binary\n'
        self.assertEqual(app.srcinfo_arches(text,'fonts'),['any'])
        self.assertEqual(app.srcinfo_arches(text,'binary'),['x86_64'])

    def test_metadata_preserves_repository_and_arch_identity(self):
        text='Repository : extra\nName : curl\nVersion : 1-1\nArchitecture : aarch64\n\nRepository : custom\nName : another\nArchitecture : x86_64\n'
        data=app.parse_sync_info(text)
        self.assertEqual(data['curl']['Architecture'],'aarch64')
        self.assertEqual(data['another']['Repository'],'custom')

    def test_failed_probe_is_logged_without_losing_partial_streams(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            probe=app.Probe(Path(directory))
            code,_=probe.run('failure',[sys.executable,'-c','import sys; print("partial"); sys.exit(7)'],required=False)
            self.assertEqual(code,7)
            self.assertEqual((Path(directory)/'logs/failure.stdout').read_text(),'partial\n')
            self.assertEqual(probe.commands[-1]['exit_code'],7)
            with patch.object(app.subprocess,'run',side_effect=subprocess.TimeoutExpired(['fixture'],60,output=b'partial')):
                with self.assertRaises(RuntimeError): probe.run('timeout',['fixture'])
            self.assertEqual(probe.commands[-1]['exit_code'],124)

    def fake_probe(self,work,release='7.3.1-2-aarch64-ARCH',head=app.PIN,architecture='aarch64',preview_exit=0):
        class Fake:
            def __init__(self): self.work=work; self.calls=[]
            def run(self,label,argv,**kwargs):
                self.calls.append((label,list(argv)))
                if argv[0]=='sudo': raise AssertionError('privileged operation')
                if argv[0]=='pacman':
                    if argv[1] not in {'-Q','-Qlq','-Si','-Sup'}: raise AssertionError('package mutation')
                values={'running-kernel':release,'kernel-owned-files':'/usr/lib/modules/7.3.1-2-aarch64-ARCH/',
                        'kernel-package':'linux-aarch64 7.3.1-2','installed-packages':'base-devel 1-1\n',
                        'sync-metadata':'Repository : extra\nName : curl\nVersion : 1-1\nArchitecture : '+architecture+'\n'}
                return (preview_exit if label=='transaction-preview' else 0),values.get(label,'')
            def git(self,source,label,*args,**kwargs):
                self.calls.append((label,list(args)))
                return {'source-head':head,'source-tree':app.TREE,'canonical-manifest':manifest(),
                        'refs-before':'same refs','refs-after':'same refs'}.get(label,'')
        return Fake()

    def test_wrong_kernel_stops_before_clone_or_package_preview(self):
        with tempfile.TemporaryDirectory() as directory:
            probe=self.fake_probe(Path(directory),release='7.1.6-1-aarch64-ARCH')
            with self.assertRaisesRegex(RuntimeError,'Running kernel'): app.collect(probe,{})
            self.assertFalse(any(name=='clone-source' for name,_ in probe.calls))

    def test_source_mismatch_stops_before_dry_run_or_package_preview(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(app.Path,'is_dir',return_value=True):
            probe=self.fake_probe(Path(directory),head='0'*40)
            with self.assertRaisesRegex(RuntimeError,'Source commit mismatch'): app.collect(probe,{})
            self.assertFalse(any(name in {'installer-dry-run','transaction-preview'} for name,_ in probe.calls))

    def test_success_only_previews_transaction_and_keeps_integration_open(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(app.Path,'is_dir',return_value=True):
            probe=self.fake_probe(Path(directory)); report={}
            app.collect(probe,report)
            command=next(argv for name,argv in probe.calls if name=='transaction-preview')
            self.assertEqual(command,['pacman','-Sup','--needed','--print-format','%r/%n %v %s','--','curl'])
            self.assertEqual(report['status'],'PREVIEW_COMPLETE_REVIEW_REQUIRED')
            self.assertIn('OPEN',report['network_integration'])

    def test_wrong_provider_arch_and_failed_resolution_block_install_readiness(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(app.Path,'is_dir',return_value=True):
            probe=self.fake_probe(Path(directory),architecture='x86_64',preview_exit=1); report={}
            app.collect(probe,report)
            self.assertEqual(report['status'],'BLOCKED_PROVIDER_RECONCILIATION')
            self.assertEqual(report['unsupported_sync_architectures'],{'curl':'x86_64'})

    def test_return_archive_excludes_checkouts_and_verifies_every_stream(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            work=Path(directory)/'capture'; work.mkdir(); (work/'logs').mkdir()
            (work/'logs/sample.stdout').write_bytes(b'captured evidence')
            (work/'commands.json').write_text('[]\n')
            (work/'source').mkdir(); (work/'source/private-fixture').write_text('not part of evidence')
            app.seal(work,{'status':'PREVIEW_COMPLETE_REVIEW_REQUIRED'})
            with tarfile.open(work.with_suffix('.tar.gz'),'r:gz') as archive:
                data={member.name:archive.extractfile(member).read() for member in archive.getmembers()}
            self.assertNotIn('source/private-fixture',data)
            manifest=data['SHA256SUMS'].decode().splitlines()
            self.assertEqual(len(manifest),3)
            for line in manifest:
                checksum,name=line.split('  ',1)
                self.assertEqual(app.digest(data[name]),checksum)

if __name__=='__main__': unittest.main(verbosity=2)
