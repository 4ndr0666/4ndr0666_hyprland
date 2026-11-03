#!/usr/bin/env python3
"""Read-only target gate for the retained Pi network backend; no flags or sudo."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile

PIN = 'f752274a78ff3dcd9482ee75704bfc6c2b8b3470'
TREE = '1d348e7ed4d98e29d661811315060824330ba70c'
BRANCH = 'gup/r7-pi-integration'
URL = 'https://github.com/4ndr0666/4ndr0666_hyprland.git'
UNITS = ['systemd-networkd', 'systemd-resolved', 'wpa_supplicant@wlan0', 'NetworkManager']
REQUIRED = ['Hyprland', 'hyprctl', 'wpa_cli', 'rofi', 'kitty', 'awww', 'awww-daemon',
            'waybar', 'hypridle', 'wl-paste', 'cliphist', 'wallust', 'wlogout',
            'dbus-send', 'dbus-update-activation-environment', 'systemctl']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def require(value, text):
    if not value:
        raise RuntimeError(text)

class Probe:
    def __init__(self, work):
        self.work, self.commands = work, []
        (work / 'logs').mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(('GIT_', 'BASH_FUNC_'))
                    and k not in {'PYTHONPATH', 'PYTHONHOME', 'BASH_ENV', 'ENV', 'LD_PRELOAD'}}
        self.env.update(LC_ALL='C', PATH='/usr/bin:/bin', GIT_OPTIONAL_LOCKS='0', GIT_NO_REPLACE_OBJECTS='1',
                        GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null', GIT_TERMINAL_PROMPT='0',
                        PYTHONDONTWRITEBYTECODE='1')

    def run(self, label, argv, timeout=60, required=True):
        print('Checking ' + label + '…', flush=True)
        argv = [str(x) for x in argv]
        try:
            proc = subprocess.run(argv, env=self.env, capture_output=True, timeout=timeout)
            code, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
        except subprocess.TimeoutExpired as exc:
            code, stdout, stderr = 124, exc.stdout or b'', exc.stderr or b''
        except OSError as exc:
            code, stdout, stderr = 127, b'', str(exc).encode()
        entry = dict(label=label, argv=argv, exit_code=code, timeout_seconds=timeout)
        for stream, data in [('stdout', stdout), ('stderr', stderr)]:
            path = self.work / 'logs' / (label + '.' + stream)
            path.write_bytes(data)
            entry[stream + '_sha256'] = sha(path)
        self.commands.append(entry)
        (self.work / 'commands.json').write_text(json.dumps(self.commands, indent=2) + '\n')
        if required:
            require(code == 0, label + ' failed; partial evidence retained.')
        return stdout.decode(errors='replace').strip()

    def git(self, source, label, *args, timeout=120):
        return self.run(label, ['git', '-c', 'core.hooksPath=/dev/null', '-c', 'core.fsmonitor=false',
                               '-C', source, *args], timeout=timeout)

def collect(probe, report):
    release = probe.run('running-kernel', ['uname', '-r'])
    owned = probe.run('kernel-ownership', ['pacman', '-Qlq', 'linux-aarch64'])
    prefix = '/usr/lib/modules/' + release + '/'
    require(any(p.rstrip('/') == prefix.rstrip('/') or p.startswith(prefix) for p in owned.splitlines())
            and (Path('/usr/lib/modules') / release).is_dir(), 'Running kernel does not match installed modules.')
    before = probe.run('network-before', ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState', *UNITS])
    required = {name: shutil.which(name, path=probe.env['PATH']) for name in REQUIRED}
    optional = {name: shutil.which(name, path=probe.env['PATH']) for name in ['nm-tray', 'nm-applet', 'mem-police', 'thunar', 'nvim']}
    report.update(kernel_running=release, required_binaries=required, optional_binaries=optional)
    require(all(required.values()), 'Required runtime binaries missing; see report. No installation attempted.')
    require(shutil.disk_usage(probe.work).free > 512 * 1024**2, 'Need 512 MiB free for isolated source verification.')
    source = probe.work / 'source'
    probe.run('clone', ['git', '-c', 'core.hooksPath=/dev/null', 'clone', '--quiet', '--no-checkout',
                       '--single-branch', '--branch', BRANCH, '--', URL, source], timeout=900)
    probe.git(source, 'checkout', 'checkout', '--detach', PIN)
    require(probe.git(source, 'source-commit', 'rev-parse', 'HEAD') == PIN, 'Candidate commit mismatch.')
    require(probe.git(source, 'source-tree', 'rev-parse', 'HEAD^{tree}') == TREE, 'Candidate tree mismatch.')
    probe.git(source, 'source-fsck', 'fsck', '--full', '--strict', timeout=600)
    refs = probe.git(source, 'refs-before', 'show-ref', '--head')
    raw = probe.run('backend-probe', ['python3', '-B', source / 'config/hypr/UserScripts/NetworkBackend.py', 'probe'])
    result = json.loads(raw)
    report.update(source=str(source), source_commit=PIN, source_tree=TREE, backend_probe=result)
    require(result.get('backend') == 'networkd', 'Target backend differs from retained Pi decision; no service changed.')
    require(result.get('persistent_changes') is False, 'Unexpected backend probe contract.')
    wireless = result.get('wireless')
    require(isinstance(wireless, list) and all(isinstance(row, dict) and row.get('control_access') for row in wireless), 'Wi-Fi control access not established.')
    # The accepted Pi baseline has wpa_supplicant@wlan0. An empty list does not
    # establish its native menu capability, even if Ethernet is working.
    require(bool(wireless), 'No wireless interface observed; Pi Wi-Fi menu gate remains open.')
    probe.run('hyprland-help', ['Hyprland', '--help'], required=False)
    report['drm_nodes'] = [dict(path=str(path), readable=os.access(path, os.R_OK), writable=os.access(path, os.W_OK))
                           for path in sorted(Path('/dev/dri').glob('*')) if not path.is_dir()]
    report['session'] = {key: os.environ.get(key) for key in ['XDG_SESSION_TYPE', 'XDG_SESSION_ID', 'XDG_CURRENT_DESKTOP']}
    report['existing_config_paths'] = {name: dict(exists=(Path.home() / '.config' / name).exists(),
                                              symlink=(Path.home() / '.config' / name).is_symlink())
                                       for name in ['hypr', 'waybar', 'rofi', 'swaync', 'wallust', 'kitty']}
    after = probe.run('network-after', ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState', *UNITS])
    require(before == after, 'Network unit state changed during read-only gate; hold deployment.')
    require(not probe.git(source, 'source-clean', 'status', '--porcelain=v1', '--untracked-files=all'), 'New source checkout changed.')
    require(refs == probe.git(source, 'refs-after', 'show-ref', '--head'), 'New source refs changed.')
    report['status'] = 'PI_BACKEND_CONTROL_ACCESS_VERIFIED_CONFIGURATION_PENDING'

def seal(work, report):
    (work / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    files = [work / 'report.json', *sorted((work / 'logs').glob('*'))]
    files += [p for p in [work / 'commands.json'] if p.exists()]
    (work / 'SHA256SUMS').write_text(''.join(sha(p) + '  ' + str(p.relative_to(work)) + '\n' for p in files))
    archive = work.with_suffix('.tar.gz')
    with tarfile.open(archive, 'w:gz') as stream:
        for path in [*files, work / 'SHA256SUMS']:
            stream.add(path, arcname=str(path.relative_to(work)), recursive=False)
    print('\n' + report['status'] + '\nSource retained: ' + str(work))
    print(sha(archive) + '  ' + str(archive))
    print('Return this archive and SHA256. No packages, user configuration, network services or Wi-Fi selection were changed.')

def main():
    if os.geteuid() == 0 or platform.machine() != 'aarch64':
        print('Run on the Pi as the normal login user, without sudo.', file=sys.stderr)
        return 20
    os.umask(0o077)
    state = Path.home() / '.local/state/gup-r7'
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    require(not state.is_symlink(), 'Invalid private state directory.')
    work = Path(tempfile.mkdtemp(prefix='integration-', dir=state))
    report = dict(status='BLOCKED', certification='NOT_CERTIFIED', script_sha256=sha(Path(__file__)),
                  mode='READ_ONLY_NATIVE_BACKEND_ACCESS', configuration='NOT_APPLIED', graphical_runtime='NOT_TESTED')
    code = 0
    try:
        collect(Probe(work), report)
    except KeyboardInterrupt:
        report.update(status='INTERRUPTED', error='Interrupted; partial evidence retained.')
        code = 130
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        report.update(status='BLOCKED', error=str(exc))
        code = 1
    finally:
        seal(work, report)
    return code

if __name__ == '__main__':
    sys.exit(main())
