#!/usr/bin/env python3
"""Install the reviewed Pi profile; preserve prior directories and record recovery."""
import hashlib,json,os,platform,shutil,subprocess,sys,tempfile,tarfile
from pathlib import Path
EXPECTED = {'Kvantum': {'exists': False}, 'btop': {'exists': False}, 'cava': {'exists': False}, 'fastfetch': {'exists': False}, 'ghostty': {'exists': False}, 'hypr': {'exists': True, 'entries': 2, 'inventory_sha256': '116899f093cfa427af098c60716c19903cd37158bd08823b2cff492cd0f02410'}, 'kitty': {'exists': True, 'entries': 1, 'inventory_sha256': '8616971ac35e5fcd04e326cc4d3bf3fd0c0db36473d20b6dea22cf0ed1758691'}, 'qt5ct': {'exists': False}, 'qt6ct': {'exists': False}, 'quickshell': {'exists': False}, 'rofi': {'exists': False}, 'swappy': {'exists': False}, 'swaync': {'exists': False}, 'wallust': {'exists': False}, 'waybar': {'exists': False}, 'wezterm': {'exists': False}, 'wlogout': {'exists': False}}
MANIFEST_PIN = 'acc275f9127ee54289298f40ed2ac320328af3574e1f79793a74e3996f676eba'
ROOTS=sorted(EXPECTED)

def require(ok,msg):
    if not ok:raise RuntimeError(msg)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory(root):
    rows=[]
    for p in [root,*sorted(root.rglob('*'))]:
        rel=str(p.relative_to(root))
        if p.is_symlink():rows.append([rel,'link',str(p.readlink())])
        elif p.is_file():rows.append([rel,'file',p.stat().st_mode & 0o7777,sha(p)])
        elif p.is_dir():rows.append([rel,'directory',p.stat().st_mode & 0o7777])
        else:raise RuntimeError('Special file: '+str(p))
    return rows

def snap(p):
    require(not p.is_symlink(),'Destination symlink: '+str(p))
    if not p.exists():return {'exists':False}
    rows=inventory(p)
    return {'exists':True,'entries':len(rows),'inventory_sha256':hashlib.sha256(json.dumps(rows,sort_keys=True).encode()).hexdigest()}
def save(p,data):
    temp=p.with_suffix('.tmp')
    with temp.open('w') as f:json.dump(data,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
    temp.replace(p)
    fd=os.open(p.parent,os.O_RDONLY|os.O_DIRECTORY)
    try:os.fsync(fd)
    finally:os.close(fd)

def locate(state):
    for p in sorted(state.glob('deployment-preflight-*/candidate-manifest.json'),reverse=True):
        if sha(p)==MANIFEST_PIN:
            source=p.parent/'candidate-home/.config'
            require(inventory(source)==json.loads(p.read_text()),'Prepared profile changed')
            require(sorted(x.name for x in source.iterdir())==ROOTS,'Unexpected profile roots')
            for path in source.rglob('*'):
                if path.is_symlink():require(path.exists() and path.resolve().is_relative_to(source.resolve()),'Unsafe profile link')
            return source
    raise RuntimeError('Reviewed prepared profile missing')

def rollback(config,work):
    require(work.parent==config and work.name.startswith('.gup-deployment-'),'Invalid recovery location')
    data=json.loads((work/'transaction.json').read_text())
    require(data['uid']==os.getuid(),'Recovery owner mismatch')
    require(set(data['entries'])<=set(ROOTS),'Unexpected recovery destination')
    for name,row in data['entries'].items():
        target=config/name;backup=work/'backups'/name
        # Intent records survive interrupted renames. Require observed state to
        # match either the original or installed identity, otherwise preserve it.
        current=snap(target)
        require(current in (row['before'],row['after']) or (not current['exists'] and backup.exists() and snap(backup)==row['before']), 'Destination changed; preserved: '+name)
        if backup.exists():require(snap(backup)==row['before'],'Backup changed: '+name)
        elif row['before']['exists']:
            require(current==row['before'],'Required backup missing: '+name)
    for name,row in reversed(list(data['entries'].items())):
        target=config/name;backup=work/'backups'/name
        if snap(target)==row['after']:
            target.rename(work/'removed'/name)
        if backup.exists():backup.rename(target)
    data['status']='ROLLED_BACK';save(work/'transaction.json',data)
    return data

def install(config,source,expected,fail_after=None):
    require(not config.is_symlink(),'Config root is a symlink')
    config.mkdir(parents=True,exist_ok=True)
    require({name:snap(config/name) for name in ROOTS}==expected,'Destination changed since preflight; preserved')
    work=Path(tempfile.mkdtemp(prefix='.gup-deployment-',dir=config));work.chmod(0o700)
    for sub in ('backups','removed','new'): (work/sub).mkdir()
    data={'uid':os.getuid(),'status':'PREPARING','entries':{},'manifest_pin':MANIFEST_PIN}
    save(work/'transaction.json',data)
    try:
        for name in ROOTS:
            shutil.copytree(source/name,work/'new'/name,symlinks=True)
        for i,name in enumerate(ROOTS):
            target=config/name
            require(snap(target)==expected[name],'Destination changed during installation: '+name)
            row={'before':expected[name],'after':snap(work/'new'/name)}
            data['entries'][name]=row;data['status']='INSTALLING';save(work/'transaction.json',data)
            if target.exists():target.rename(work/'backups'/name)
            (work/'new'/name).rename(target)
            require(snap(target)==row['after'],'Installed destination mismatch: '+name)
            if fail_after==i:raise RuntimeError('Injected installation failure')
        data['status']='INSTALLED';save(work/'transaction.json',data)
        return work,data
    except BaseException:
        rollback(config,work)
        raise

def compositors():
    names={'Hyprland','sway','niri','kwin_wayland','gnome-shell','weston'}
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            if p.stat().st_uid==os.getuid():
                name=Path(os.fsdecode((p/'cmdline').read_bytes().split(b'\0')[0])).name
                if name in names:return True
        except OSError:continue
    return False

def main():
    require(platform.machine() in ('aarch64','arm64') and os.geteuid()!=0,'Run as the normal Pi user')
    require(not compositors(),'Log out of the desktop normally before configuration installation')
    home=Path.home();config=home/'.config'
    require(os.environ.get('XDG_CONFIG_HOME',str(config))==str(config),'Custom config root needs review')
    os.umask(0o077)
    if len(sys.argv)>1:
        require(len(sys.argv)==3 and sys.argv[1]=='--rollback','Usage: helper.py [--rollback RECOVERY_DIRECTORY]')
        work=Path(sys.argv[2]);rollback(config,work);print('Prior configuration restored.');return 0
    require(len(sys.argv)==1,'Unexpected arguments')
    state=home/'.local/state/gup-r7';require(state.is_dir() and not state.is_symlink(),'GUP state missing')
    require(not list(config.glob('.gup-deployment-*')),'Prior deployment exists; inspect its recovery record first')
    source=locate(state)
    work,data=install(config,source,EXPECTED)
    report=state/('installation-'+work.name.removeprefix('.gup-deployment-')+'.json')
    save(report,{'status':'INSTALLED','certification':'NOT_CERTIFIED','recovery_directory':str(work),'manifest_pin':MANIFEST_PIN,'script_sha256':sha(Path(__file__)),'destinations':data['entries']})
    archive=report.with_suffix('.tar.gz')
    with tarfile.open(archive,'w:gz') as t:t.add(report,arcname='installation.json')
    print('Installation evidence: '+str(archive))
    print('SHA256: '+sha(archive))
    print('Installed the reviewed configuration. Prior directories retained at: '+str(work/'backups'))
    print('Recovery directory: '+str(work))
    print('Start the desktop from this console with: Hyprland')
    print('Rollback after logging out: python3 '+str(Path(__file__).resolve())+' --rollback '+str(work))
    print('Permanent-session runtime verification and full certification remain pending.')
    return 0
if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError,RuntimeError) as error:print('Stopped: '+str(error),file=sys.stderr);sys.exit(1)
