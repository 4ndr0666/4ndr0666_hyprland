#!/usr/bin/env python3
"""Install the reviewed R7 package set on the Pi; leave configuration untouched.

Uses the existing pinned readiness checkout and locally built provider packages.
Pacman retains its normal confirmation. No installer, AUR helper, service start,
network migration, dotfile copy or reboot is invoked.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import signal
import subprocess
import sys
import tarfile
import tempfile
import threading

COMMIT = '5f97fdf336142241ebe5641db1c74ce2f907105b'
TREE = 'ef92e2c255b74a0ddde2cb293b4c0a1f7dc3bcdb'
MANIFEST = '49e3cd00b08f055d4df6e821da0d6ccd11390a0420614c662454cf6c7b5bc536'
PACKAGES = {
    'wallust': ('wallust-3.5.2-2.1-aarch64.pkg.tar.xz', 'b0616a31d843677dad986106d2c12232cea0c2b80727fc344d8ee195b8cbd488'),
    'wlogout': ('wlogout-1.2.2-0.1-aarch64.pkg.tar.xz', 'ecd54fd759014b38bbb1a19abcd121308d36b32234931bbfdbe7db96000781cc'),
    'ttf-victor-mono': ('ttf-victor-mono-1.5.6-1.1-any.pkg.tar.xz', '6fe6a5139242660823e4d84fc544d9fb6d26f45b74f4ae267f670d49c634e005'),
}
GROUPS = ['BASE_PACKAGES', 'INSTALLER_RUNTIME_PACKAGES', 'CORE_PACKAGES',
          'PIPEWIRE_PACKAGES', 'HYPRLAND_PACKAGES', 'FONT_PACKAGES',
          'AUR_PACKAGES', 'FONT_AUR_PACKAGES']
UNITS = ['systemd-networkd.service', 'systemd-resolved.service',
         'wpa_supplicant@wlan0.service', 'NetworkManager.service']

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def environment():
    env = {k: v for k, v in os.environ.items() if not k.startswith(('GIT_', 'BASH_FUNC_'))
           and k not in {'BASH_ENV', 'ENV', 'LD_PRELOAD', 'PYTHONPATH', 'PYTHONHOME'}}
    env.update(LC_ALL='C', PATH='/usr/bin:/bin', GIT_OPTIONAL_LOCKS='0',
               GIT_NO_REPLACE_OBJECTS='1', GIT_CONFIG_NOSYSTEM='1',
               GIT_CONFIG_GLOBAL='/dev/null', GIT_TERMINAL_PROMPT='0')
    return env

class Runner:
    def __init__(self, work):
        self.work, self.commands, self.env = work, [], environment()
        (work / 'logs').mkdir()

    def run(self, label, argv):
        argv = [str(x) for x in argv]
        print('\n' + shlex.join(argv), flush=True)
        path = self.work / 'logs' / (label + '.combined')
        code = 127
        try:
            with path.open('wb') as log:
                proc = subprocess.Popen(argv, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                def copy():
                    for data in iter(lambda: proc.stdout.read1(65536), b''):
                        log.write(data)
                        log.flush()
                        sys.stdout.buffer.write(data)
                        sys.stdout.buffer.flush()
                thread = threading.Thread(target=copy)
                thread.start()
                try:
                    code = proc.wait()
                except KeyboardInterrupt:
                    proc.send_signal(signal.SIGINT)
                    code = proc.wait()
                    raise
                finally:
                    thread.join()
        finally:
            self.commands.append(dict(label=label, argv=argv, exit_code=code, combined_sha256=sha(path)))
            (self.work / 'commands.json').write_text(json.dumps(self.commands, indent=2) + '\n')
        require(code == 0, label + ' failed; stop and review retained logs.')
        return path.read_text(errors='replace').strip()

    def git(self, source, label, *args):
        return self.run(label, ['git', '-c', 'core.hooksPath=/dev/null', '-c',
                               'core.fsmonitor=false', '-C', source, *args])

def parse_manifest(text):
    arrays = dict(re.findall(r'(?ms)^(\w+)=\(\n(.*?)^\)', text))
    names = []
    for group in GROUPS:
        require(group in arrays, 'Missing canonical group: ' + group)
        entries = shlex.split(arrays[group], comments=True)
        require(all(re.fullmatch('[a-z0-9][a-z0-9+_.@-]*', n) for n in entries),
                'Nonliteral manifest entry.')
        names.extend(entries)
    return sorted(set(names))

def network_state(text):
    units = {}
    for block in text.split('\n\n'):
        fields = dict(line.split('=', 1) for line in block.splitlines() if '=' in line)
        if fields.get('Id'):
            units[fields['Id']] = fields
    require(all(u in units for u in UNITS), 'Incomplete network unit observation.')
    return units

def preserve_network(before, after):
    for unit in UNITS[:-1]:
        require(before[unit] == after[unit], 'Existing network backend unit changed: ' + unit)
    require(after[UNITS[-1]].get('ActiveState') == 'inactive', 'NetworkManager became active; stop for review.')
    require(after[UNITS[-1]].get('UnitFileState', '') in {'', 'disabled', 'not-found'},
            'NetworkManager enabled/masked state needs review.')

def observe_network(runner, label):
    return network_state(runner.run(label, ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState', *UNITS]))

def find_providers(state):
    found = {}
    for name, (filename, expected) in PACKAGES.items():
        matches = []
        for path in sorted(state.glob('providers-*/' + name + '/' + filename)):
            if path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(state.resolve()):
                if sha(path) == expected:
                    matches.append(path)
        require(bool(matches), 'Missing or modified reviewed local package: ' + name + '. Retain existing builds; do not bypass the hash.')
        found[name] = matches[0]
    return found

def collect(runner, state, report):
    # Fixed source identity, literal manifest, and provider bytes are checked
    # before any privileged operation. Existing source refs are read-only.
    candidates = sorted(p for p in state.glob('predeploy-*/source') if (p / '.git').is_dir())
    require(bool(candidates), 'Pinned readiness checkout not found.')
    source = None
    for index, candidate in enumerate(candidates):
        if runner.git(candidate, 'source-head-' + str(index), 'rev-parse', 'HEAD') == COMMIT:
            source = candidate
            break
    require(source is not None, 'Exact R7 source checkout not found.')
    require(runner.git(source, 'source-tree', 'rev-parse', 'HEAD^{tree}') == TREE, 'R7 tree mismatch.')
    require(not runner.git(source, 'source-clean-before', 'status', '--porcelain=v1', '--untracked-files=all'), 'R7 checkout has user changes; preserved and held.')
    refs = runner.git(source, 'refs-before', 'show-ref', '--head')
    # Git-show stdout includes its final newline; Runner strips it for display
    # callers, so hash the actual captured bytes to compare the recorded pin.
    text = runner.git(source, 'canonical-manifest', 'show', 'HEAD:install-scripts/core/package-manifest.sh')
    require(sha(runner.work / 'logs/canonical-manifest.combined') == MANIFEST, 'Manifest pin mismatch.')
    names = parse_manifest(text)
    require(len(names) == 62 and set(PACKAGES) <= set(names), 'Unexpected canonical package inventory.')
    providers = find_providers(state)
    report.update(source=str(source), source_commit=COMMIT, source_tree=TREE,
                  canonical_packages=names, local_packages={n: dict(path=str(p), sha256=sha(p)) for n, p in providers.items()})
    release = runner.run('kernel-before', ['uname', '-r'])
    owned = runner.run('kernel-ownership-before', ['pacman', '-Qlq', 'linux-aarch64'])
    prefix = '/usr/lib/modules/' + release + '/'
    require(any(p.rstrip('/') == prefix.rstrip('/') or p.startswith(prefix) for p in owned.splitlines())
            and (Path('/usr/lib/modules') / release).is_dir(), 'Kernel/module ownership mismatch; reboot/review before package installation.')
    before = observe_network(runner, 'network-before')
    require(all(before[u].get('ActiveState') == 'active' for u in UNITS[:-1]) and
            before[UNITS[-1]].get('ActiveState') == 'inactive', 'Network backend differs from reviewed baseline; no transaction attempted.')
    preserve_network(before, before)
    runner.run('packages-before', ['pacman', '-Q'])
    runner.run('space-before', ['df', '-B1', '--', str(state), '/'])
    sync = sorted(set(names) - set(PACKAGES))
    runner.run('transaction-preview', ['pacman', '-Sup', '--needed', '--print-format', '%r/%n %v %s', '--', *sync])
    print('\nInstall the reviewed package set; review each normal pacman confirmation.\n'
          'No dotfiles, desktop installer, service enablement or networking migration follows.', flush=True)
    report['sync_transaction'] = 'STARTED'
    runner.run('install-sync', ['sudo', 'pacman', '-Syu', '--needed', '--', *sync])
    report['sync_transaction'] = 'COMPLETED'
    preserve_network(before, observe_network(runner, 'network-after-sync'))
    # Recheck local bytes immediately before handing them to pacman.
    for name, path in providers.items():
        require(sha(path) == PACKAGES[name][1], 'Local package changed before install: ' + name)
    report['local_transaction'] = 'STARTED'
    runner.run('install-local', ['sudo', 'pacman', '-U', '--needed', '--', *[providers[n] for n in sorted(providers)]])
    report['local_transaction'] = 'COMPLETED'
    preserve_network(before, observe_network(runner, 'network-after-local'))
    runner.run('canonical-installed', ['pacman', '-Q', '--', *names])
    runner.run('packages-after', ['pacman', '-Q'])
    runner.run('kernel-package-after', ['pacman', '-Q', 'linux-aarch64'])
    runner.run('wallust-version', ['wallust', '--version'])
    runner.run('hyprland-version', ['Hyprland', '--version'])
    runner.run('awww-version', ['awww', '--version'])
    runner.run('gi-nm-import', ['python3', '-c',
        "import gi; gi.require_version('NM', '1.0'); from gi.repository import NM; print('GI NM typelib import OK; no NM.Client or daemon activation requested')"])
    preserve_network(before, observe_network(runner, 'network-after-probes'))
    require(not runner.git(source, 'source-clean-after', 'status', '--porcelain=v1', '--untracked-files=all'), 'Source checkout changed; hold configuration work.')
    require(refs == runner.git(source, 'refs-after', 'show-ref', '--head'), 'Source refs changed; hold configuration work.')
    report['status'] = 'PACKAGES_INSTALLED_CONFIGURATION_PENDING'

def seal(work, report):
    (work / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    files = [work / 'report.json', *sorted((work / 'logs').glob('*'))]
    files += [p for p in [work / 'commands.json'] if p.exists()]
    (work / 'SHA256SUMS').write_text(''.join(sha(p) + '  ' + str(p.relative_to(work)) + '\n' for p in files))
    archive = work.with_suffix('.tar.gz')
    with tarfile.open(archive, 'w:gz') as stream:
        for path in [*files, work / 'SHA256SUMS']:
            stream.add(path, arcname=str(path.relative_to(work)), recursive=False)
    print('\n' + report['status'] + '\nEvidence retained: ' + str(work))
    print(sha(archive) + '  ' + str(archive))
    print('Return this archive and SHA256. Configuration, networking integration and live graphical acceptance remain pending.')

def main():
    if os.geteuid() == 0 or platform.machine() != 'aarch64':
        print('Run on the Pi as the normal login user, without sudo.', file=sys.stderr)
        return 20
    os.umask(0o077)
    state = Path.home() / '.local/state/gup-r7'
    require(state.is_dir() and not state.is_symlink(), 'Existing private GUP workspace not found.')
    work = Path(tempfile.mkdtemp(prefix='packages-', dir=state))
    report = dict(status='BLOCKED', certification='NOT_CERTIFIED', script_sha256=sha(Path(__file__)),
                  configuration='NOT_APPLIED', networking='NO_BACKEND_MIGRATION; integration OPEN', graphical_runtime='NOT_TESTED')
    code = 0
    try:
        collect(Runner(work), state, report)
    except KeyboardInterrupt:
        report.update(status='INTERRUPTED', error='Interrupted; inspect transaction logs before resuming.')
        code = 130
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        report.update(status='BLOCKED', error=str(exc))
        code = 1
    finally:
        seal(work, report)
    return code

if __name__ == '__main__':
    sys.exit(main())
