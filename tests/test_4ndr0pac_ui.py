import contextlib,importlib.machinery,importlib.util,io,os,subprocess,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1];PROGRAM=ROOT/'config/4ndr0tools/4ndr0pac/4ndr0pac'
loader=importlib.machinery.SourceFileLoader('pac_ui',str(PROGRAM));spec=importlib.util.spec_from_loader(loader.name,loader);ui=importlib.util.module_from_spec(spec);loader.exec_module(ui)
class RestoredUITests(unittest.TestCase):
 def backend(self,root):
  path=root/'fake-backend';path.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$BACKEND_LOG"\nexit 7\n');path.chmod(0o700);return path
 def test_cli_confirmation_still_blocks_and_safe_status_propagates(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);backend=self.backend(root);log=root/'log';env=dict(os.environ,BACKEND_LOG=str(log))
   p=subprocess.run(['python3',str(PROGRAM),'--backend',str(backend),'Remove Packages','example'],input='n\n',capture_output=True,text=True,env=env)
   self.assertEqual(p.returncode,130);self.assertFalse(log.exists())
   p=subprocess.run(['python3',str(PROGRAM),'--backend',str(backend),'Package Info','example'],capture_output=True,text=True,env=env)
   self.assertEqual(p.returncode,7);self.assertEqual(log.read_text().strip(),'p example')
 def test_piped_interactive_dry_run_never_executes_backend(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t);backend=self.backend(root);log=root/'log'
   p=subprocess.run(['python3',str(PROGRAM),'--backend',str(backend),'--dry-run','--no-color'],input='Remove Packages\n\nq\n',capture_output=True,text=True,env=dict(os.environ,BACKEND_LOG=str(log)))
   self.assertEqual(p.returncode,0,p.stderr);self.assertIn('[dry-run]',p.stdout);self.assertNotIn('\x1b',p.stdout);self.assertFalse(log.exists())
 def test_rich_prompt_uses_completion_history_and_existing_confirmation(self):
  if not ui.HAVE_PTK:self.skipTest('Optional prompt_toolkit absent')
  session=type('Session',(),{'prompt':lambda self,*a,**kw:next(self.choices)})();session.choices=iter(['Remove Packages','Package Info','q'])
  with tempfile.TemporaryDirectory() as t,patch.object(ui.sys.stdin,'isatty',return_value=True),patch.object(ui,'history_file',return_value=Path(t)/'history'),patch.object(ui,'PromptSession',return_value=session) as factory,patch.object(ui,'confirm_danger',return_value=False) as confirmation,patch.object(ui,'run_backend',return_value=7) as backend,patch.object(ui,'pause'),patch.object(ui,'print_header'),contextlib.redirect_stdout(io.StringIO()):
   self.assertEqual(ui.interactive(Path('/fake/backend')),0)
   confirmation.assert_called_once_with('Remove Packages');backend.assert_called_once_with(Path('/fake/backend'),'p',[],False)
   self.assertIn('completer',factory.call_args.kwargs);self.assertIn('history',factory.call_args.kwargs)
if __name__=='__main__':unittest.main()
