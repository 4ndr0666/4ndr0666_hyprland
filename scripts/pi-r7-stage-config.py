#!/usr/bin/env python3
"""Stage and natively verify R7 in a private profile; never replace live dotfiles."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import platform
import tomllib

PIN = '4aa7b09ef44af0a98b4772be9ff2625318241029'
TREE = '15d0d36d295aeffab8f6e3f271bfca225616a329'
SOURCE_URL = 'https://github.com/4ndr0666/4ndr0666_hyprland.git'
UNITS = ['systemd-networkd', 'systemd-resolved', 'wpa_supplicant@wlan0', 'NetworkManager']

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inventory(root):
    records = []
    if not root.exists() and not root.is_symlink():
        return records
    paths = [root] if root.is_symlink() or not root.is_dir() else [root, *sorted(root.rglob('*'))]
    for path in paths:
        rel = str(path.relative_to(root))
        if path.is_symlink():
            records.append([rel, 'link', str(path.readlink())])
        elif path.is_file():
            records.append([rel, 'file', path.stat().st_mode & 0o7777, sha(path)])
        elif path.is_dir():
            records.append([rel, 'directory', path.stat().st_mode & 0o7777])
        else:
            raise RuntimeError('Unexpected special file in configuration inventory.')
    return records

def inventory_hash(root):
    return hashlib.sha256(json.dumps(inventory(root), sort_keys=True).encode()).hexdigest()

def check_links(root):
    for path in root.rglob('*'):
        if path.is_symlink():
            require(not path.readlink().is_absolute() and path.resolve().is_relative_to(root.resolve())
                    and path.exists(), 'Configuration contains an escaping or dangling symlink.')

def check_templates(config):
    parsed = tomllib.loads((config / 'wallust/wallust.toml').read_text())
    for entry in parsed.get('templates', {}).values():
        target = entry.get('target')
        require(isinstance(target, str) and target.startswith('~/.config/') and
                '..' not in PurePosixPath(target).parts, 'Wallust target escapes the private configuration profile.')

def profile_environment(work):
    home = work / 'profile-home'
    env = {k: v for k, v in os.environ.items() if not k.startswith(('GIT_', 'BASH_FUNC_', 'HYPRLAND_'))
           and k not in {'PYTHONPATH', 'PYTHONHOME', 'BASH_ENV', 'ENV', 'LD_PRELOAD'}}
    env.update(LC_ALL='C', PATH='/usr/bin:/bin', PYTHONDONTWRITEBYTECODE='1',
               GIT_OPTIONAL_LOCKS='0', GIT_NO_REPLACE_OBJECTS='1', GIT_CONFIG_NOSYSTEM='1',
               GIT_CONFIG_GLOBAL='/dev/null', GIT_TERMINAL_PROMPT='0', HOME=str(home),
               XDG_CONFIG_HOME=str(home / '.config'), XDG_CACHE_HOME=str(home / '.cache'),
               XDG_DATA_HOME=str(home / '.local/share'), XDG_STATE_HOME=str(home / '.local/state'))
    return env

class Probe:
    def __init__(self, work):
        self.work, self.commands = work, []
        self.env = profile_environment(work)
        (work / 'logs').mkdir()

    def run(self, label, argv, timeout=120):
        print('Checking ' + label + '…', flush=True)
        argv = [str(x) for x in argv]
        try:
            proc = subprocess.run(argv, capture_output=True, timeout=timeout, env=self.env)
            code, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
        except subprocess.TimeoutExpired as error:
            code, stdout, stderr = 124, error.stdout or b'', error.stderr or b''
        except OSError as error:
            code, stdout, stderr = 127, b'', str(error).encode()
        row = dict(label=label, argv=argv, exit_code=code, timeout_seconds=timeout,
                   profile_environment={k: self.env[k] for k in ['HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME']})
        for stream, data in [('stdout', stdout), ('stderr', stderr)]:
            path = self.work / 'logs' / (label + '.' + stream)
            path.write_bytes(data)
            row[stream + '_sha256'] = sha(path)
        self.commands.append(row)
        (self.work / 'commands.json').write_text(json.dumps(self.commands, indent=2) + '\n')
        require(code == 0, label + ' failed; live dotfiles were not replaced.')
        return stdout.decode(errors='replace').strip()

    def git(self, source, label, *args):
        return self.run(label, ['git', '-c', 'core.hooksPath=/dev/null', '-c', 'core.fsmonitor=false', '-C', source, *args])

def make_launcher(work):
    env = profile_environment(work)
    keys = ['HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME']
    assignments = [key + '=' + env[key] for key in keys]
    config = Path(env['XDG_CONFIG_HOME']) / 'hypr/hyprland.lua'
    return '''#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$EUID" -ne 0 && -z "${SSH_CONNECTION:-}" ]] || { echo 'Use the normal Pi user on a local virtual console.' >&2; exit 20; }
console="$(tty)"
[[ "$console" =~ ^/dev/tty[0-9]+$ ]] || { echo 'Launch from a local Pi virtual console, not SSH or a terminal inside another desktop.' >&2; exit 20; }
if pgrep -u "$UID" -x 'Hyprland|sway|niri|kwin_wayland|gnome-shell|weston' >/dev/null; then
    echo 'An existing compositor is running; leave it intact and review before starting the trial.' >&2
    exit 20
fi
''' + 'exec env ' + shlex.join(assignments) + ' dbus-run-session -- Hyprland --config ' + shlex.quote(str(config)) + '\n'

def verifier_diagnostics(output):
    plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
    runtime = []
    errors = []
    for line in plain.splitlines():
        if re.search(r'(?i)(?:\bERR(?:OR)?\b\s*\]|(?:config(?:uration)?|lua) (?:has errors|error)|failed to (?:load|parse))', line):
            if "Couldn't bind the Hyprland Socket 2" in line:
                runtime.append(line.strip())
            else:
                errors.append(line.strip())
    return plain, errors, runtime

def collect(probe, state, user_home, report):
    original = user_home / '.config/hypr'
    original_hash = inventory_hash(original)
    report['original_hypr_inventory_sha256_before'] = original_hash
    candidates = sorted(p for p in state.glob('integration-*/source') if (p / '.git').is_dir())
    source = None
    for index, candidate in enumerate(candidates):
        if probe.git(candidate, 'source-head-' + str(index), 'rev-parse', 'HEAD') == PIN:
            source = candidate
            break
    if source is None:
        # A corrected candidate never checks out over the previous capture's
        # source. Acquire it in this new owned staging workspace instead.
        source = probe.work / 'source'
        probe.run('clone-corrected-source', ['git', '-c', 'core.hooksPath=/dev/null', 'clone', '--quiet',
                  '--no-checkout', '--single-branch', '--branch', 'gup/r7-pi-integration', '--', SOURCE_URL, source], timeout=900)
        probe.git(source, 'checkout-corrected-source', 'checkout', '--detach', PIN)
        require(probe.git(source, 'corrected-source-commit', 'rev-parse', 'HEAD') == PIN, 'Corrected source commit mismatch.')
    require(probe.git(source, 'source-tree', 'rev-parse', 'HEAD^{tree}') == TREE, 'Source tree mismatch.')
    probe.git(source, 'source-fsck', 'fsck', '--full', '--strict')
    require(not probe.git(source, 'source-clean-before', 'status', '--porcelain=v1', '--untracked-files=all'), 'Source has changes; preserved and held.')
    refs = probe.git(source, 'refs-before', 'show-ref', '--head')
    before = probe.run('network-before', ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState', *UNITS])
    require(shutil.disk_usage(probe.work).free > 1024**3, 'Need 1 GiB free for private profile and validation.')
    check_links(source / 'config')
    home = Path(probe.env['HOME'])
    home.mkdir(mode=0o700)
    config = home / '.config'
    shutil.copytree(source / 'config', config, symlinks=True)
    check_links(config)
    check_templates(config)
    for folder in [config / 'hypr/scripts', config / 'hypr/UserScripts']:
        for path in folder.iterdir():
            if path.is_file() and not path.is_symlink() and path.suffix in {'.sh', '.py'}:
                path.chmod(path.stat().st_mode | 0o100)
    entry = config / 'hypr/hyprland.lua'
    (config / 'hypr/initial-boot.sh').chmod(0o700)
    image = config / 'hypr/wallpaper_effects/.wallpaper_current'
    require(image.is_file() and not image.is_symlink(), 'Pinned default wallpaper unavailable.')
    report.update(source=str(source), source_commit=PIN, source_tree=TREE, profile_home=str(home), entrypoint=str(entry))
    probe.run('wallust-render', ['wallust', 'run', '-s', image], timeout=600)
    probe.run('hyprland-verify-config', ['Hyprland', '--verify-config', '--config', entry], timeout=120)
    output = ''.join((probe.work / 'logs' / ('hyprland-verify-config.' + s)).read_text(errors='replace') for s in ['stdout', 'stderr'])
    plain, config_errors, runtime_diagnostics = verifier_diagnostics(output)
    report['config_only_runtime_diagnostics'] = runtime_diagnostics
    require(not config_errors,
            'Native validator reported errors despite its exit code; profile held for review.')
    require(re.search(r'(?m)^config ok\s*$', plain), 'Native verifier did not report the expected explicit config verdict.')
    after = probe.run('network-after', ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState', *UNITS])
    require(before == after, 'Network unit state changed; hold graphical trial.')
    require(not probe.git(source, 'source-clean-after', 'status', '--porcelain=v1', '--untracked-files=all'), 'Source changed during staging.')
    require(refs == probe.git(source, 'refs-after', 'show-ref', '--head'), 'Source refs changed during staging.')
    report['original_hypr_inventory_sha256_after'] = inventory_hash(original)
    require(original_hash == report['original_hypr_inventory_sha256_after'], 'Existing Hyprland files changed; hold trial for review.')
    profile_records = inventory(config)
    (probe.work / 'profile-manifest.json').write_text(json.dumps(profile_records, indent=2) + '\n')
    report['profile_manifest_sha256'] = sha(probe.work / 'profile-manifest.json')
    launch = probe.work / 'launch-trial.sh'
    launch.write_text(make_launcher(probe.work))
    launch.chmod(0o700)
    report.update(status='PRIVATE_PROFILE_NATIVE_VALIDATION_PASSED_REVIEW_REQUIRED',
                  launch_command='bash ' + shlex.quote(str(launch)), launch_script_sha256=sha(launch))

def seal(work, report):
    (work / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    files = [work / 'report.json', *sorted((work / 'logs').glob('*'))]
    files += [p for p in [work / 'commands.json', work / 'profile-manifest.json', work / 'launch-trial.sh'] if p.exists()]
    (work / 'SHA256SUMS').write_text(''.join(sha(p) + '  ' + str(p.relative_to(work)) + '\n' for p in files))
    archive = work.with_suffix('.tar.gz')
    with tarfile.open(archive, 'w:gz') as stream:
        for path in [*files, work / 'SHA256SUMS']:
            stream.add(path, arcname=str(path.relative_to(work)), recursive=False)
    print('\n' + report['status'] + '\nPrivate profile retained: ' + str(work))
    print(sha(archive) + '  ' + str(archive))
    print('Return this archive and SHA256. No live configuration was replaced and no graphical session was started.')

def main():
    if os.geteuid() == 0 or platform.machine() != 'aarch64':
        print('Run on the Pi as the normal login user, without sudo.', file=sys.stderr)
        return 20
    os.umask(0o077)
    user_home = Path.home()
    state = user_home / '.local/state/gup-r7'
    require(state.is_dir() and not state.is_symlink(), 'Existing private GUP workspace not found.')
    work = Path(tempfile.mkdtemp(prefix='config-', dir=state))
    report = dict(status='BLOCKED', certification='NOT_CERTIFIED', script_sha256=sha(Path(__file__)),
                  mode='PRIVATE_PROFILE_STAGING_AND_NATIVE_VALIDATION', live_configuration='NOT_REPLACED', graphical_runtime='NOT_STARTED')
    code = 0
    probe = None
    try:
        probe = Probe(work)
        collect(probe, state, user_home, report)
    except KeyboardInterrupt:
        report.update(status='INTERRUPTED', error='Interrupted; private staging and logs retained.')
        code = 130
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        report.update(status='BLOCKED', error=str(error))
        code = 1
    finally:
        try:
            report['original_hypr_inventory_sha256_final'] = inventory_hash(user_home / '.config/hypr')
            previous = report.get('original_hypr_inventory_sha256_before')
            if previous and previous != report['original_hypr_inventory_sha256_final']:
                report.update(status='BLOCKED', error='Existing Hyprland inventory changed; review before trial.')
                code = 1
            if probe and (work / 'logs/network-before.stdout').exists() and not (work / 'logs/network-after.stdout').exists():
                probe.run('network-after-failure', ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState', *UNITS])
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            report['status'] = 'BLOCKED'
            report['final_observation_error'] = str(error)
            code = 1
        seal(work, report)
    return code

if __name__ == '__main__':
    sys.exit(main())
