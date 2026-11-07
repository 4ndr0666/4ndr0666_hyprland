#!/usr/bin/env python3
"""Install user-selected Colorful assets and reconcile existing toolkit settings."""
import hashlib,json,os,re,shutil,subprocess,sys,tarfile,tempfile,urllib.request
from pathlib import Path
REV='67fe0058dc44c3b86898fee1c930d718fcc834dc'
PIN='2fff0489d098848006858be0642c540e9c6a4bafdae558296c5ebe6a3eaf901d'
URL='https://codeload.github.com/L4ki/Colorful-Plasma-Themes/tar.gz/'+REV
PREFIX='Colorful-Plasma-Themes-'+REV
ASSETS=['Colorful GTK Themes','Colorful Icons Themes/Colorful-Dark-Icons','Colorful Kvantum Themes/Colorful-Dark-Kvantum']
def require(ok,msg):
 if not ok:raise RuntimeError(msg)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def command(args):
 p=subprocess.run(args,capture_output=True,text=True,timeout=20)
 require(p.returncode==0,'Command failed: '+repr(args)+' '+p.stderr.strip())
 return p.stdout.strip()
def unpack(archive,dest):
 with tarfile.open(archive) as t:
  members=[m for m in t.getmembers() if any(m.name==PREFIX+'/'+s or m.name.startswith(PREFIX+'/'+s+'/') for s in ASSETS)]
  require(bool(members),'Theme archive layout mismatch');t.extractall(dest,members=members,filter='data')
 root=dest/PREFIX
 for rel in ASSETS:
  theme=root/rel;require(theme.is_dir() and not theme.is_symlink(),'Theme asset missing')
  for p in theme.rglob('*'):
   if p.is_symlink():require(p.exists() and p.resolve().is_relative_to(theme.resolve()),'Escaping or missing theme link: '+str(p))
 return root

def qt_config(text):
 require(text.count('custom_palette=true')==1,'Qt palette differs; preserved')
 require('style=kvantum' in text and 'icon_theme=Colorful-Dark-Icons' in text,'Qt appearance differs; preserved')
 return re.sub(r'^color_scheme_path=.*\n','',text.replace('custom_palette=true','custom_palette=false',1),flags=re.M)

def main():
 require(os.geteuid()!=0,'Run as the normal desktop user')
 home=Path.home();config=home/'.config'
 require(os.environ.get('XDG_CONFIG_HOME',str(config))==str(config),'Custom config path needs reconciliation')
 targets=[home/'.local/share/themes/Colorful-Dark',home/'.local/share/icons/Colorful-Dark-Icons',config/'Kvantum/Colorful-Dark-Kvantum']
 for path in targets:
  require(not path.exists() and not path.is_symlink(),'Existing theme preserved: '+str(path))
  require(not any(p.is_symlink() for p in path.parents),'Symlink destination ancestor: '+str(path))
 qt=[config/'qt5ct/qt5ct.conf',config/'qt6ct/qt6ct.conf'];replacements=[]
 for p in qt:
  require(p.is_file() and not p.is_symlink(),'Qt configuration missing or symlink')
  replacements.append(qt_config(p.read_text()))
 state=home/'.local/state/gup-r7';state.mkdir(parents=True,exist_ok=True);os.umask(0o077)
 work=Path(tempfile.mkdtemp(prefix='appearance-',dir=state));archive=work/'colorful.tar.gz'
 print('Downloading pinned Colorful GTK, icon and Kvantum assets…',flush=True)
 with urllib.request.urlopen(URL,timeout=60) as response,archive.open('wb') as out:shutil.copyfileobj(response,out)
 require(sha(archive)==PIN,'Archive hash mismatch')
 source=unpack(archive,work/'unpacked')
 old={key:command(['gsettings','get','org.gnome.desktop.interface',key]) for key in ['gtk-theme','icon-theme','font-name']}
 (work/'settings-before.json').write_text(json.dumps(old,indent=2)+'\n')
 for p in qt:shutil.copy2(p,work/(p.parent.name+'.conf.before'))
 installed=[]
 try:
  for rel,target in zip(ASSETS,targets):
   target.parent.mkdir(parents=True,exist_ok=True)
   stage=Path(tempfile.mkdtemp(prefix='.colorful-',dir=target.parent))
   shutil.copytree(source/rel,stage,dirs_exist_ok=True,symlinks=True)
   for p in [stage,*stage.rglob('*')]:
    if not p.is_symlink():p.chmod(0o755 if p.is_dir() else 0o644)
   stage.rename(target);installed.append(target)
  for p,text in zip(qt,replacements):
   temp=work/(p.parent.name+'.new');temp.write_text(text);temp.chmod(p.stat().st_mode & 0o777)
   # Backup is retained; replace the file after the candidate is fully prepared.
   shutil.copy2(temp,p)
  for key,value in [('gtk-theme','Colorful-Dark'),('icon-theme','Colorful-Dark-Icons'),('font-name','Fira Code Semi-Bold 14')]:command(['gsettings','set','org.gnome.desktop.interface',key,value])
 except BaseException:
  for p in qt:shutil.copy2(work/(p.parent.name+'.conf.before'),p)
  for key,value in old.items():subprocess.run(['gsettings','set','org.gnome.desktop.interface',key,value],capture_output=True)
  # Retain downloaded assets and any installed themes, never delete user files.
  raise
 report={'status':'APPLIED','revision':REV,'archive_sha256':PIN,'installed_assets':[str(p) for p in installed],'settings':{key:command(['gsettings','get','org.gnome.desktop.interface',key]) for key in old},'qt_config_hashes':{str(p):sha(p) for p in qt},'backup':str(work),'certification':'NOT_CERTIFIED'}
 (work/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));print('Reopen applications to inspect their themes. The custom Kvantum # configuration and cursor were preserved.')
 return 0
if __name__=='__main__':
 try:sys.exit(main())
 except (OSError,ValueError,RuntimeError,tarfile.TarError) as error:print('Stopped: '+str(error),file=sys.stderr);sys.exit(1)
