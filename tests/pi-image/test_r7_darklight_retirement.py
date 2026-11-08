import hashlib,importlib.util,tempfile,unittest,base64
from pathlib import Path
s=importlib.util.spec_from_file_location('retirement',Path(__file__).resolve().parents[2]/'scripts/pi-r7-retire-darklight.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
def row(path,old,new):return {'path':path,'before':hashlib.sha256(old).hexdigest(),'after':hashlib.sha256(new).hexdigest() if new is not None else None,'data':base64.b64encode(new).decode() if new is not None else None}
class RetirementTests(unittest.TestCase):
 def test_update_backup_removal_and_repeat(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);config=root/'config';config.mkdir();(config/'file').write_bytes(b'old');(config/'script').write_bytes(b'retired');work=root/'work';work.mkdir()
   rows=[row('file',b'old',b'new'),row('script',b'retired',None)]
   self.assertEqual(m.apply(config,rows,work),['file','script'])
   self.assertEqual((config/'file').read_bytes(),b'new');self.assertFalse((config/'script').exists())
   self.assertEqual((work/'backup/file').read_bytes(),b'old');self.assertEqual((work/'retired/script').read_bytes(),b'retired')
   self.assertEqual(m.apply(config,rows,work),[])
 def test_user_edit_blocks_all_updates(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);config=root/'config';config.mkdir();(config/'file').write_bytes(b'personal');(config/'script').write_bytes(b'old');work=root/'work';work.mkdir()
   with self.assertRaisesRegex(RuntimeError,'preserved'):m.apply(config,[row('file',b'old',b'new'),row('script',b'old',None)],work)
   self.assertEqual((config/'script').read_bytes(),b'old');self.assertFalse((work/'backup').exists())
