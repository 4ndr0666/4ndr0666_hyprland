#!/usr/bin/env python3
"""Two-minute local-console trial with private configuration and owned cleanup.

No flags, sudo, package installation, permanent deployment or service enablement.
Only the two user-manager variables changed by the candidate are snapshotted.
"""
import hashlib
import ast
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time

SOURCE_PIN = '4aa7b09ef44af0a98b4772be9ff2625318241029'
MANIFEST_PIN = 'e66ab1ef51c1688e6f476659aef5bca669af82cea317e9c4b2ba94b4c872d51f'
MANAGED = ['WAYLAND_DISPLAY', 'XDG_CURRENT_DESKTOP']
UNITS = ['systemd-networkd', 'systemd-resolved', 'wpa_supplicant@wlan0', 'NetworkManager']
COMPOSITORS = {'Hyprland', 'sway', 'niri', 'kwin_wayland', 'gnome-shell', 'weston'}
RUNTIME_OWNERS = {'waybar', 'awww-daemon', 'xdg-desktop-portal', 'xdg-desktop-portal-hyprland',
                  'xdg-desktop-portal-wlr', 'xdg-desktop-portal-gnome'}

def require(value, message):
    if not value:
        raise RuntimeError(message)

def config_error_count(raw):
    errors = json.loads(raw)
    if not isinstance(errors, list) or any(not isinstance(x, str) for x in errors):
        raise ValueError('Unexpected configerrors response')
    return sum(bool(x.strip()) for x in errors)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inventory(root):
    rows = []
    for path in [root, *sorted(root.rglob('*'))]:
        rel = str(path.relative_to(root))
        if path.is_symlink():
            rows.append([rel, 'link', str(path.readlink())])
        elif path.is_file():
            rows.append([rel, 'file', path.stat().st_mode & 0o7777, sha(path)])
        elif path.is_dir():
            rows.append([rel, 'directory', path.stat().st_mode & 0o7777])
        else:
            raise RuntimeError('Unexpected profile file type.')
    return rows

def process(pid):
    root = Path('/proc') / str(pid)
    try:
        require(root.stat().st_uid == os.getuid(), 'Different process owner.')
        text = (root / 'stat').read_text()
        fields = text[text.rfind(')') + 2:].split()
        argv = (root / 'cmdline').read_bytes().split(b'\0')
        # Read only to select the owned profile; never persist an environment dump.
        try:
            values = (root / 'environ').read_bytes().split(b'\0')
        except OSError:
            values = []
        selected = {}
        for value in values:
            key, sep, data = value.partition(b'=')
            if sep and key in {b'HOME', b'DBUS_SESSION_BUS_ADDRESS'}:
                selected[key.decode()] = data.decode(errors='replace')
        return dict(pid=int(pid), birth=fields[19], ppid=int(fields[1]),
                    executable=Path(os.fsdecode(argv[0])).name, selected=selected)
    except (OSError, ValueError, RuntimeError, IndexError):
        return None

def processes():
    return [value for path in Path('/proc').iterdir() if path.name.isdigit()
            for value in [process(path.name)] if value]

def owned_processes(home, baseline):
    return [p for p in processes() if p['selected'].get('HOME') == str(home)
            and baseline.get(str(p['pid'])) != p['birth']]

def safe_signal(item, sig):
    current = process(item['pid'])
    if current and current['birth'] == item['birth'] and current['selected'].get('HOME') == item['selected'].get('HOME'):
        try:
            os.kill(item['pid'], sig)
        except ProcessLookupError:
            pass

def parse_manager(payload):
    require(payload.get('type') == 'as', 'Unexpected systemd environment type.')
    values = payload.get('data')
    if isinstance(values, list) and len(values) == 1 and isinstance(values[0], list):
        values = values[0]
    require(isinstance(values, list) and all(isinstance(v, str) for v in values), 'Unexpected systemd environment data.')
    fields = dict(v.split('=', 1) for v in values if '=' in v)
    return {k: fields[k] for k in MANAGED if k in fields}

class Probe:
    def __init__(self, work):
        self.work, self.commands = work, []
        (work / 'logs').mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(('HYPRLAND_', 'BASH_FUNC_'))
                    and k not in {'BASH_ENV', 'ENV', 'LD_PRELOAD', 'PYTHONPATH', 'PYTHONHOME', 'WAYLAND_DISPLAY'}}
        self.env.update(LC_ALL='C', PATH='/usr/bin:/bin')

    def record(self, label, argv, result, private=False):
        unique = str(len(self.commands)).zfill(3) + '-' + label
        row = dict(label=unique, step=label, argv=[str(x) for x in argv], exit_code=result.returncode)
        for name, data in [('stdout', result.stdout), ('stderr', result.stderr)]:
            row[name + '_sha256'] = hashlib.sha256(data).hexdigest()
            if not private:
                (self.work / 'logs' / (unique + '.' + name)).write_bytes(data)
        if private:
            row['stream_retention'] = 'not retained; only selected managed variables held in private recovery checkpoint'
        self.commands.append(row)
        (self.work / 'commands.json').write_text(json.dumps(self.commands, indent=2) + '\n')

    def run(self, label, argv, env=None, required=True, private=False, timeout=20):
        argv = [str(x) for x in argv]
        try:
            result = subprocess.run(argv, env=env or self.env, capture_output=True, timeout=timeout)
        except subprocess.TimeoutExpired as error:
            result = subprocess.CompletedProcess(argv, 124, error.stdout or b'', error.stderr or b'')
        except OSError as error:
            result = subprocess.CompletedProcess(argv, 127, b'', str(error).encode())
        self.record(label, argv, result, private)
        if required:
            require(result.returncode == 0, label + ' failed; review retained evidence.')
        return result

    def manager(self, label):
        result = self.run(label, ['busctl', '--user', '--json=short', 'get-property',
            'org.freedesktop.systemd1', '/org/freedesktop/systemd1', 'org.freedesktop.systemd1.Manager', 'Environment'], private=True)
        return parse_manager(json.loads(result.stdout))

def restore_manager(probe, before):
    require(set(before) <= set(MANAGED) and all(isinstance(v, str) for v in before.values()), 'Invalid managed environment checkpoint.')
    missing = [key for key in MANAGED if key not in before]
    if missing:
        probe.run('restore-manager-unset', ['systemctl', '--user', 'unset-environment', '--', *missing], private=True)
    if before:
        probe.run('restore-manager-set', ['systemctl', '--user', 'set-environment', '--',
                  *[key + '=' + value for key, value in before.items()]], private=True)
    require(probe.manager('manager-after-restore') == before, 'Managed session environment restoration did not verify.')

def recover_manager(probe, state):
    pending = sorted(state.glob('trial-*/restore-manager.json'), key=lambda p: p.stat().st_mtime_ns, reverse=True)
    for path in pending:
        saved = json.loads(path.read_text())
        require(saved.get('uid') == os.getuid() and isinstance(saved.get('managed'), dict), 'Invalid private recovery checkpoint.')
        restore_manager(probe, saved['managed'])
        path.rename(path.with_name('restored-manager.json'))

def locate_profile(state):
    for path in sorted(state.glob('config-*/report.json')):
        try:
            data = json.loads(path.read_text())
            manifest = path.parent / 'profile-manifest.json'
            if data.get('source_commit') == SOURCE_PIN and manifest.is_file() and sha(manifest) == MANIFEST_PIN:
                root = path.parent / 'profile-home/.config'
                require(inventory(root) == json.loads(manifest.read_text()), 'Accepted staged configuration changed; preserved and held.')
                return root
        except (OSError, ValueError):
            continue
    raise RuntimeError('Exact accepted private profile not found; no configuration was changed.')

def runtime_sample(probe, env, home, baseline, label):
    checks = {}
    for name, argv in [
        ('monitors', ['hyprctl', '-j', 'monitors']),
        ('configerrors', ['hyprctl', '-j', 'configerrors']),
        ('wallpaper', ['awww', 'query']),
        ('backend', ['python3', '-B', str(home / '.config/hypr/UserScripts/NetworkBackend.py'), 'probe']),
        ('audio', ['wpctl', 'status']),
        ('session-bus', ['gdbus', 'call', '--session', '--dest', 'org.freedesktop.DBus',
                         '--object-path', '/org/freedesktop/DBus', '--method', 'org.freedesktop.DBus.ListNames'])]:
        result = probe.run(label + '-' + name, argv, env=env, required=False, timeout=5)
        checks[name] = result.returncode
        if name == 'monitors' and result.returncode == 0:
            try:
                checks['monitor_count'] = len(json.loads(result.stdout))
            except (ValueError, TypeError):
                checks['monitor_count'] = 0
        if name == 'configerrors' and result.returncode == 0:
            try:
                checks['config_error_count'] = config_error_count(result.stdout)
            except (ValueError, TypeError):
                checks['config_error_count'] = 'unparsed; review raw capture'
        if name == 'session-bus' and result.returncode == 0:
            try:
                names = ast.literal_eval(result.stdout.decode())[0]
                checks['portal_bus_owners'] = sorted(name for name in names if isinstance(name, str) and
                    name.startswith(('org.freedesktop.portal.', 'org.freedesktop.impl.portal.')))
            except (ValueError, SyntaxError, TypeError, IndexError):
                checks['portal_bus_owners'] = 'unparsed; review raw capture'
    # Do not retain process argv, window titles, unrelated environments or SSIDs.
    checks['profile_processes'] = sorted(set(p['executable'] for p in owned_processes(home, baseline)))
    checks['first_boot_marker'] = (home / '.config/hypr/.initial_startup_done').is_file()
    return checks

def trial(probe, state, report):
    existing = processes()
    require(not any(p['executable'] in COMPOSITORS for p in existing), 'An existing compositor is running; leave it intact.')
    require(not any(p['executable'] in RUNTIME_OWNERS for p in existing),
            'Existing graphical runtime owners are running; preserve them and review before the trial.')
    recover_manager(probe, state)
    source = locate_profile(state)
    original = Path.home() / '.config/hypr'
    original_rows = inventory(original) if original.exists() else []
    report['original_hypr_inventory_sha256_before'] = hashlib.sha256(json.dumps(original_rows, sort_keys=True).encode()).hexdigest()
    home = probe.work / 'profile-home'
    home.mkdir(mode=0o700)
    shutil.copytree(source, home / '.config', symlinks=True)
    env = dict(probe.env, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
               XDG_CACHE_HOME=str(home / '.cache'), XDG_DATA_HOME=str(home / '.local/share'),
               XDG_STATE_HOME=str(home / '.local/state'))
    before_network = probe.run('network-before', ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState', *UNITS]).stdout
    manager = probe.manager('manager-before')
    recovery = probe.work / 'restore-manager.json'
    recovery.write_text(json.dumps(dict(uid=os.getuid(), managed=manager)) + '\n')
    baseline = {str(p['pid']): p['birth'] for p in processes()}
    process_log = probe.work / 'logs/compositor.combined'
    launched = None
    report.update(private_profile=str(home), duration_limit_seconds=120, runtime_samples=[])
    print('\nStarting a two-minute private-profile trial.\n'
          'Try Super+Return (terminal), Super+N (network status), and inspect the panel/wallpaper.\n'
          'The trial ends automatically and returns to this console.\n'
          'Do not test logout-menu power actions during this smoke trial.', flush=True)
    try:
        with process_log.open('wb') as output:
            argv = ['dbus-run-session', '--', 'Hyprland', '--config', str(home / '.config/hypr/hyprland.lua')]
            launched = subprocess.Popen(argv, env=env, stdout=output, stderr=subprocess.STDOUT)
            session_row = dict(label='compositor-session', argv=argv, exit_code=None, running=True,
                               stream_retention='logs/compositor.combined')
            probe.commands.append(session_row)
            (probe.work / 'commands.json').write_text(json.dumps(probe.commands, indent=2) + '\n')
            start = time.monotonic()
            sample_env = None
            sampled = False
            while launched.poll() is None and time.monotonic() - start < 120:
                candidates = [p for p in owned_processes(home, baseline) if p['executable'] == 'Hyprland']
                if candidates and sample_env is None:
                    result = probe.run('discover-instances', ['hyprctl', '-j', 'instances'], env=env, required=False, timeout=2)
                    if result.returncode == 0:
                        try:
                            instances = json.loads(result.stdout)
                            instance = next((i for i in instances if i.get('pid') == candidates[0]['pid']), None)
                            if instance and instance.get('instance') and instance.get('wl_socket'):
                                sample_env = dict(env, HYPRLAND_INSTANCE_SIGNATURE=instance['instance'],
                                    WAYLAND_DISPLAY=instance['wl_socket'], XDG_CURRENT_DESKTOP='Hyprland',
                                    DBUS_SESSION_BUS_ADDRESS=candidates[0]['selected']['DBUS_SESSION_BUS_ADDRESS'])
                                report['instance'] = dict(pid=instance['pid'], signature=instance['instance'], socket=instance['wl_socket'])
                        except (ValueError, TypeError, KeyError):
                            pass
                if sample_env and not sampled and 15 <= time.monotonic() - start < 90:
                    report['runtime_samples'].append(runtime_sample(probe, sample_env, home, baseline, 'runtime'))
                    sampled = True
                time.sleep(1)
            if launched.poll() is None and sample_env:
                probe.run('request-trial-exit', ['hyprctl', 'dispatch', 'hl.dsp.exit()'], env=sample_env, required=False)
                try:
                    launched.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    pass
    finally:
        # Scope cleanup by UID, private HOME and process birth identity, never
        # killall or a shared foreground process group.
        cleanup_error = None
        try:
            for item in owned_processes(home, baseline):
                safe_signal(item, signal.SIGTERM)
            time.sleep(1)
            for item in owned_processes(home, baseline):
                safe_signal(item, signal.SIGKILL)
            if launched:
                launched.wait(timeout=10)
        except (OSError, subprocess.SubprocessError) as error:
            cleanup_error = str(error)
        finally:
            try:
                restore_manager(probe, manager)
                report['managed_session_environment_restored'] = True
                recovery.rename(probe.work / 'restored-manager.json')
            finally:
                if launched:
                    report['compositor_exit_code'] = launched.poll()
                    session_row.update(exit_code=launched.poll(), running=launched.poll() is None,
                                       combined_sha256=sha(process_log))
                    (probe.work / 'commands.json').write_text(json.dumps(probe.commands, indent=2) + '\n')
        require(cleanup_error is None, 'Owned process cleanup failed; review retained recovery evidence.')
        report['owned_processes_remaining'] = len(owned_processes(home, baseline))
        require(report['owned_processes_remaining'] == 0, 'Owned trial processes remain; hold further work.')
        final_rows = inventory(original) if original.exists() else []
        report['original_hypr_inventory_sha256_after'] = hashlib.sha256(json.dumps(final_rows, sort_keys=True).encode()).hexdigest()
        require(original_rows == final_rows, 'Existing Hyprland inventory changed; hold deployment for review.')
    after = probe.run('network-after', ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState', *UNITS]).stdout
    require(before_network == after, 'Network unit state changed during trial; hold deployment.')
    report['status'] = 'GRAPHICAL_TRIAL_CAPTURED_VISUAL_REVIEW_REQUIRED' if report['runtime_samples'] else 'GRAPHICAL_TRIAL_NO_RUNTIME_SAMPLE_REVIEW_REQUIRED'
    report['operator_observation'] = input('\nBack at the console. Describe display/input/panel/terminal/network results (no passwords; Enter skips): ').strip()

def seal(work, report):
    (work / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    files = [work / 'report.json', *sorted((work / 'logs').glob('*'))]
    files += [p for p in [work / 'commands.json'] if p.exists()]
    (work / 'SHA256SUMS').write_text(''.join(sha(p) + '  ' + str(p.relative_to(work)) + '\n' for p in files))
    archive = work.with_suffix('.tar.gz')
    with tarfile.open(archive, 'w:gz') as stream:
        for path in [*files, work / 'SHA256SUMS']:
            stream.add(path, arcname=str(path.relative_to(work)), recursive=False)
    print('\n' + report['status'] + '\nTrial evidence: ' + str(work))
    print(sha(archive) + '  ' + str(archive))
    print('Return this archive and SHA256. Permanent deployment and full certification remain pending.')

def main():
    if os.geteuid() == 0 or platform.machine() != 'aarch64' or os.environ.get('SSH_CONNECTION'):
        print('Run on the Pi local virtual console as the normal login user, without sudo or SSH.', file=sys.stderr)
        return 20
    try:
        console = os.ttyname(0)
    except OSError:
        console = ''
    if not re.fullmatch(r'/dev/tty[0-9]+', console):
        print('Use a local Pi virtual console, outside an existing desktop.', file=sys.stderr)
        return 20
    os.umask(0o077)
    def interrupted(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    state = Path.home() / '.local/state/gup-r7'
    require(state.is_dir() and not state.is_symlink(), 'Private GUP state directory missing.')
    work = Path(tempfile.mkdtemp(prefix='trial-', dir=state))
    report = dict(status='BLOCKED', certification='NOT_CERTIFIED', script_sha256=sha(Path(__file__)),
                  live_configuration='NOT_REPLACED', operator_observation='NOT_REPORTED')
    code = 0
    try:
        trial(Probe(work), state, report)
    except (KeyboardInterrupt, EOFError):
        report.update(status='INTERRUPTED', error='Interrupted; inspect cleanup and recovery evidence.')
        code = 130
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        report.update(status='BLOCKED', error=str(error))
        code = 1
    finally:
        seal(work, report)
    return code

if __name__ == '__main__':
    sys.exit(main())
