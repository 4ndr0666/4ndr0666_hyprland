#!/usr/bin/env python3
"""Install reviewed Bibata Xcursor assets and align the existing user overlay."""
import hashlib,json,os,shutil,subprocess,sys,tarfile,tempfile,urllib.request
from pathlib import Path
URL='https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz'
PIN='a68cae60c4dc706350e194ebc91c5fe48bc7bc9d59e119555834a2a7ee5078ef'
OVERLAY='d8bd08c67ac62bfea5b982aa3ba6068c87e9c70be43b2271068c0bffbb9e61f4'
THEME='Bibata-Modern-Ice'
def require(ok,msg):
 if not ok:raise RuntimeError(msg)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args):
 p=subprocess.run(args,capture_output=True,text=True,timeout=20)
 require(p.returncode==0,'Command failed: '+repr(args)+' '+p.stderr.strip())
 return p.stdout.strip()
def unpack(archive,dest):
 with tarfile.open(archive) as t:t.extractall(dest,filter='data')
 root=dest/THEME
 require(root.is_dir() and not root.is_symlink(),'Theme root missing')
 for p in root.rglob('*'):
  if p.is_symlink():require(p.exists() and p.resolve().is_relative_to(root.resolve()),'Unsafe cursor link')
 require((root/'cursors/left_ptr').exists(),'Pointer asset missing')
 return root

def main():
 require(os.geteuid()!=0,'Run as your normal graphical-session user')
 home=Path.home();config=home/'.config'
 require(os.environ.get('XDG_CONFIG_HOME',str(config))==str(config),'Custom config location requires reconciliation')
 overlay=config/'hypr/UserConfigs/ENVariables.lua'
 require(overlay.is_file() and not overlay.is_symlink() and sha(overlay)==OVERLAY,'User environment overlay changed; preserved')
 icons=home/'.local/share/icons';require(not icons.is_symlink(),'Icons root is a symlink')
 target=icons/THEME;require(not target.exists() and not target.is_symlink(),'Existing cursor theme preserved')
 os.umask(0o077)
 state=home/'.local/state/gup-r7';state.mkdir(parents=True,exist_ok=True)
 work=Path(tempfile.mkdtemp(prefix='cursor-',dir=state));archive=work/'theme.tar.xz'
 print('Downloading pinned Bibata cursor assets…',flush=True)
 with urllib.request.urlopen(URL,timeout=30) as response,archive.open('wb') as out:shutil.copyfileobj(response,out)
 require(sha(archive)==PIN,'Cursor archive hash mismatch')
 theme=unpack(archive,work/'unpacked')
 old={key:run(['gsettings','get','org.gnome.desktop.interface',key]) for key in ['cursor-theme','cursor-size']}
 shutil.copy2(overlay,work/'ENVariables.lua.before')
 (work/'settings-before.json').write_text(json.dumps(old,indent=2)+'\n')
 # The overlay is known to contain only comments and return true.
 text=overlay.read_text();require(text.count('return true')==1,'Unexpected overlay structure')
 lines='\n'.join('hl.env('+json.dumps(k)+', '+json.dumps(v)+')' for k,v in [('HYPRCURSOR_THEME',THEME),('HYPRCURSOR_SIZE','24'),('XCURSOR_THEME',THEME),('XCURSOR_SIZE','24')])
 new=text.replace('return true',lines+'\n\nreturn true',1)
 icons.mkdir(parents=True,exist_ok=True)
 # Cursor assets must be readable by graphical applications.
 for p in [theme,*theme.rglob('*')]:
  if not p.is_symlink():p.chmod(0o755 if p.is_dir() else 0o644)
 theme.rename(target)
 try:
  temp=overlay.with_name('.ENVariables.cursor.tmp');require(not temp.exists() and not temp.is_symlink(),'Overlay temporary path exists')
  temp.write_text(new);temp.chmod(overlay.stat().st_mode & 0o777);temp.replace(overlay)
  for key,value in [('cursor-theme',THEME),('cursor-size','24')]:run(['gsettings','set','org.gnome.desktop.interface',key,value])
  require(run(['gsettings','get','org.gnome.desktop.interface','cursor-theme'])==repr(THEME),'GTK theme selection did not persist')
 except BaseException:
  shutil.copy2(work/'ENVariables.lua.before',overlay)
  for key,value in old.items():subprocess.run(['gsettings','set','org.gnome.desktop.interface',key,value],capture_output=True)
  raise
 result=subprocess.run(['hyprctl','setcursor',THEME,'24'],capture_output=True,text=True,timeout=15)
 report={'theme':THEME,'archive_sha256':PIN,'overlay_sha256':sha(overlay),'live_cursor_exit':result.returncode,'live_cursor_reply':result.stdout.strip(),'backup':str(work),'certification':'NOT_CERTIFIED'}
 (work/'report.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
 print('GTK and persistent cursor settings applied. If the compositor cursor has not changed, log out normally and use start-hyprland again.')
 return 0
if __name__=='__main__':
 try:sys.exit(main())
 except (OSError,ValueError,RuntimeError,tarfile.TarError) as e:print('Stopped: '+str(e),file=sys.stderr);sys.exit(1)
