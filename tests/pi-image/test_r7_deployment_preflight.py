import importlib.util
import tempfile
import unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('deploy_preflight',Path(__file__).resolve().parents[2]/'scripts/pi-r7-deployment-preflight.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class DeploymentPreparationTests(unittest.TestCase):
    def test_embedded_engine_is_pinned(self):
        self.assertEqual(m.engine()['SOURCE_PIN'],'4aa7b09ef44af0a98b4772be9ff2625318241029')
    def test_preserves_existing_destinations_and_seeds_defaults_privately(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);home=root/'home';source=root/'source';work=root/'work'
            work.mkdir();(source/'hypr').mkdir(parents=True);(source/'hypr/hyprland.lua').write_text('candidate')
            (source/'kitty').mkdir();(source/'kitty/config').write_text('new')
            (home/'.config/hypr').mkdir(parents=True);(home/'.config/hypr/hyprland.lua').write_text('personal')
            e=m.engine();e['locate_profile']=lambda state:source;e['repair_wallpaper']=lambda home,report:None
            report=m.prepare(work,root,home,e)
            self.assertTrue(report['destination_snapshots_unchanged'])
            self.assertEqual((home/'.config/hypr/hyprland.lua').read_text(),'personal')
            self.assertFalse((home/'.config/kitty').exists())
            self.assertEqual((work/'candidate-home/.config/kitty/config').read_text(),'new')
    def test_symlink_destination_blocks_before_stage(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);home=root/'home';source=root/'source';work=root/'work';work.mkdir()
            (source/'hypr').mkdir(parents=True);(home/'.config').mkdir(parents=True)
            (home/'.config/hypr').symlink_to(source/'hypr')
            e=m.engine();e['locate_profile']=lambda state:source
            with self.assertRaisesRegex(RuntimeError,'symlink'):m.prepare(work,root,home,e)
            self.assertFalse((work/'candidate-home').exists())
if __name__=='__main__':unittest.main()
