import importlib.util,os,subprocess,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('pac_repair',Path(__file__).resolve().parents[2]/'scripts/repair-4ndr0pac.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class RepairTests(unittest.TestCase):
 def test_installs_pair_alias_and_repeats_without_mutation(self):
  with tempfile.TemporaryDirectory() as t:
   home=Path(t);config=home/'.config';r=m.install(home,config,m.files())
   self.assertEqual(r['status'],'INSTALLED');alias=home/'.local/bin/4ndr0pac'
   self.assertEqual(subprocess.run([str(alias),'--version'],capture_output=True).returncode,0)
   self.assertEqual(m.install(home,config,m.files())['status'],'ALREADY_INSTALLED')
 def test_old_installation_and_launcher_are_preserved(self):
  with tempfile.TemporaryDirectory() as t:
   home=Path(t);config=home/'.config';root=config/'4ndr0tools/4ndr0pac';root.mkdir(parents=True);(root/'personal').write_text('keep')
   alias=home/'.local/bin/4ndr0pac';alias.parent.mkdir(parents=True);alias.write_text('old launcher')
   r=m.install(home,config,m.files())
   self.assertEqual(Path(r['previous_launcher']).read_text(),'old launcher')
   self.assertEqual((Path(r['previous'])/'personal').read_text(),'keep')
   self.assertEqual((root/'personal').read_text(),'keep')
 def test_failed_final_check_restores_existing_installation(self):
  with tempfile.TemporaryDirectory() as t:
   home=Path(t);config=home/'.config';root=config/'4ndr0tools/4ndr0pac';root.mkdir(parents=True);(root/'personal').write_text('keep')
   alias=home/'.local/bin/4ndr0pac';alias.parent.mkdir(parents=True);alias.write_text('old launcher')
   replies=[subprocess.CompletedProcess([],0,'syntax',''),subprocess.CompletedProcess([],0,'version',''),subprocess.CompletedProcess([],0,'dry-run',''),subprocess.CompletedProcess([],1,'','injected failure')]
   with patch.object(m.subprocess,'run',side_effect=replies):
    with self.assertRaisesRegex(RuntimeError,'Installed frontend'):m.install(home,config,m.files())
   self.assertEqual(alias.read_text(),'old launcher');self.assertEqual((root/'personal').read_text(),'keep')
   self.assertFalse((root/'4ndr0pac').exists())
