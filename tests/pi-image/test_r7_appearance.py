import contextlib,hashlib,importlib.util,io,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[2]
s=importlib.util.spec_from_file_location('appearance',ROOT/'scripts/pi-r7-appearance.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class AppearanceTests(unittest.TestCase):
 def test_qt_reconciliation_preserves_fonts_and_style(self):
  for v in ('qt5ct','qt6ct'):
   raw=(ROOT/'config'/v/(v+'.conf')).read_text();text=m.qt_config(raw)
   self.assertNotIn('color_scheme_path=',text);self.assertIn('custom_palette=false',text)
   self.assertEqual(raw.split('[Fonts]')[1],text.split('[Fonts]')[1])
   self.assertIn('style=kvantum',text)
 def test_personal_qt_palette_stops_without_changes(self):
  with self.assertRaisesRegex(RuntimeError,'preserved'):m.qt_config('custom_palette=false\nstyle=custom\n')
 def test_install_preserves_custom_kvantum_and_cursor(self):
  with tempfile.TemporaryDirectory() as t:
   home=Path(t);config=home/'.config';src=home/'source';archive=home/'archive';archive.write_bytes(b'fixture')
   for rel in m.ASSETS:
    (src/rel).mkdir(parents=True);(src/rel/'asset').write_text('asset')
   for v in ('qt5ct','qt6ct'):
    (config/v).mkdir(parents=True);(config/v/(v+'.conf')).write_bytes((ROOT/'config'/v/(v+'.conf')).read_bytes())
   custom=config/'Kvantum/Colorful-Dark-Kvantum#/custom';custom.parent.mkdir(parents=True);custom.write_text('personal')
   settings={'gtk-theme':"'Colorful-Dark'",'icon-theme':"'Colorful-Dark'",'font-name':"'Adwaita Sans 11'"}
   def command(args):
    if args[1]=='get':return settings[args[-1]]
    settings[args[-2]]=repr(args[-1]);return ''
   with patch.object(m.Path,'home',return_value=home),patch.object(m.os,'geteuid',return_value=1000),patch.dict(os.environ,{'XDG_CONFIG_HOME':str(config)}),patch.object(m,'PIN',hashlib.sha256(b'fixture').hexdigest()),patch.object(m.urllib.request,'urlopen',side_effect=lambda *a,**k:archive.open('rb')),patch.object(m,'unpack',return_value=src),patch.object(m,'command',side_effect=command),contextlib.redirect_stdout(io.StringIO()):
    self.assertEqual(m.main(),0)
   self.assertEqual(custom.read_text(),'personal')
   self.assertEqual(settings['icon-theme'],"'Colorful-Dark-Icons'")
   self.assertEqual(len(list((home/'.local/state/gup-r7').glob('appearance-*/*.conf.before'))),2)
