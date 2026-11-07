import importlib.util,tempfile,unittest
from pathlib import Path
s=importlib.util.spec_from_file_location('deployment',Path(__file__).resolve().parents[2]/'scripts/pi-r7-deploy-config.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class DeploymentTests(unittest.TestCase):
 def setup_tree(self,tmp):
  root=Path(tmp);source=root/'source';config=root/'config';config.mkdir()
  for name in m.ROOTS:
   (source/name).mkdir(parents=True);(source/name/'file').write_text('candidate '+name)
  for name in ('hypr','kitty'):
   (config/name).mkdir();(config/name/'old').write_text('personal '+name)
  before={n:m.snap(config/n) for n in m.ROOTS}
  return source,config,before
 def test_install_and_exact_rollback(self):
  with tempfile.TemporaryDirectory() as t:
   source,config,before=self.setup_tree(t);work,data=m.install(config,source,before)
   self.assertEqual(data['status'],'INSTALLED')
   for n in m.ROOTS:self.assertEqual(m.snap(source/n),m.snap(config/n))
   m.rollback(config,work)
   self.assertEqual({n:m.snap(config/n) for n in m.ROOTS},before)
 def test_each_interrupted_step_restores_original(self):
  for step in range(len(m.ROOTS)):
   with self.subTest(step=step),tempfile.TemporaryDirectory() as t:
    source,config,before=self.setup_tree(t)
    with self.assertRaisesRegex(RuntimeError,'Injected'):m.install(config,source,before,step)
    self.assertEqual({n:m.snap(config/n) for n in m.ROOTS},before)
 def test_later_user_edit_blocks_whole_rollback(self):
  with tempfile.TemporaryDirectory() as t:
   source,config,before=self.setup_tree(t);work,data=m.install(config,source,before)
   (config/'hypr/file').write_text('later edit')
   installed={n:m.snap(config/n) for n in m.ROOTS}
   with self.assertRaisesRegex(RuntimeError,'changed'):m.rollback(config,work)
   self.assertEqual({n:m.snap(config/n) for n in m.ROOTS},installed)
 def test_changed_destination_blocks_before_transaction(self):
  with tempfile.TemporaryDirectory() as t:
   source,config,before=self.setup_tree(t);(config/'hypr/new').write_text('personal')
   with self.assertRaisesRegex(RuntimeError,'changed'):m.install(config,source,before)
   self.assertFalse(list(config.glob('.gup-deployment-*')))
