import contextlib,hashlib,importlib.util,io,os,subprocess,tarfile,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[2]
s=importlib.util.spec_from_file_location('cursor',ROOT/'scripts/pi-r7-cursor.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class CursorTests(unittest.TestCase):
 def test_install_uses_user_files_and_keeps_backup(self):
  with tempfile.TemporaryDirectory() as t:
   home=Path(t);overlay=home/'.config/hypr/UserConfigs/ENVariables.lua';overlay.parent.mkdir(parents=True);original=(ROOT/'config/hypr/UserConfigs/ENVariables.lua').read_bytes();overlay.write_bytes(original)
   archive=home/'theme.tar.xz'
   with tarfile.open(archive,'w:xz') as stream:
    for name in ['Bibata-Modern-Ice/index.theme','Bibata-Modern-Ice/cursors/left_ptr']:
     info=tarfile.TarInfo(name);info.size=4;stream.addfile(info,io.BytesIO(b'data'))
   values={'cursor-theme':"'default'",'cursor-size':'24'}
   def run(args):
    if args[1]=='get':return values[args[-1]]
    values[args[-2]]=repr(args[-1]) if args[-2]=='cursor-theme' else args[-1];return ''
   with patch.object(m.Path,'home',return_value=home),patch.object(m.os,'geteuid',return_value=1000),patch.dict(os.environ,{'XDG_CONFIG_HOME':str(home/'.config')}),patch.object(m,'PIN',hashlib.sha256(archive.read_bytes()).hexdigest()),patch.object(m.urllib.request,'urlopen',side_effect=lambda *a,**k:archive.open('rb')),patch.object(m,'run',side_effect=run),patch.object(m.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'ok','')),contextlib.redirect_stdout(io.StringIO()):
    self.assertEqual(m.main(),0)
   self.assertTrue((home/'.local/share/icons/Bibata-Modern-Ice/cursors/left_ptr').is_file())
   self.assertIn('XCURSOR_THEME',overlay.read_text())
   self.assertEqual(next((home/'.local/state/gup-r7').glob('cursor-*/ENVariables.lua.before')).read_bytes(),original)
 def test_existing_personal_overlay_blocks_before_download(self):
  with tempfile.TemporaryDirectory() as t:
   home=Path(t);p=home/'.config/hypr/UserConfigs/ENVariables.lua';p.parent.mkdir(parents=True);p.write_text('personal')
   with patch.object(m.Path,'home',return_value=home),patch.object(m.os,'geteuid',return_value=1000),patch.dict(os.environ,{'XDG_CONFIG_HOME':str(home/'.config')}),patch.object(m.urllib.request,'urlopen') as download:
    with self.assertRaisesRegex(RuntimeError,'overlay changed'):m.main()
    download.assert_not_called()
