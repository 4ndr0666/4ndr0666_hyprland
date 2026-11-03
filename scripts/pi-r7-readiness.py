#!/usr/bin/env python3
"""Pinned R7 source and target transaction preview; no sudo/install/service writes.

Paradigm: synchronous read-only probes and new private Git/evidence workspace.
Run as the Pi login user. Returned archive excludes working Git repositories.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request

PIN = '5f97fdf336142241ebe5641db1c74ce2f907105b'
TREE = 'ef92e2c255b74a0ddde2cb293b4c0a1f7dc3bcdb'
URL = 'https://github.com/4ndr0666/4ndr0666_hyprland.git'
BRANCH = 'gup/r7-bash-quote-scope'
GROUPS = ['BASE_PACKAGES', 'INSTALLER_RUNTIME_PACKAGES', 'CORE_PACKAGES',
          'PIPEWIRE_PACKAGES', 'HYPRLAND_PACKAGES', 'FONT_PACKAGES',
          'AUR_PACKAGES', 'FONT_AUR_PACKAGES']
def probe_environment(values):
    # Public-source probes must not inherit GIT_DIR/WORK_TREE/INDEX/config
    # redirects that could make checkout act on the caller's existing work.
    # Preserve ordinary proxy and system-trust settings, including Git CA paths.
    env = {key: value for key, value in values.items()
           if not key.startswith('GIT_') or key in {'GIT_SSL_CAINFO', 'GIT_SSL_CAPATH'}}
    env.update(LC_ALL='C', GIT_OPTIONAL_LOCKS='0', GIT_NO_LAZY_FETCH='1',
               GIT_TERMINAL_PROMPT='0', GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null',
               GIT_NO_REPLACE_OBJECTS='1', PYTHONDONTWRITEBYTECODE='1')
    return env

ENV = probe_environment(os.environ)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def parse_manifest(source):
    arrays = dict(re.findall(r'(?ms)^(\w+)=\(\n(.*?)^\)', source))
    official, aur = [], []
    for group in GROUPS:
        require(group in arrays, 'Missing canonical package group: ' + group)
        entries = shlex.split(arrays[group], comments=True)
        require(all(re.fullmatch('[a-z0-9][a-z0-9+_.@-]*', value) for value in entries),
                'Non-literal package entry; manifest needs review: ' + group)
        (aur if group in {'AUR_PACKAGES', 'FONT_AUR_PACKAGES'} else official).extend(entries)
    return sorted(set(official)), sorted(set(aur))

def kernel_matches(release, owned_paths):
    root = '/usr/lib/modules/' + release + '/'
    return any(path.rstrip('/') == root.rstrip('/') or path.startswith(root)
               for path in owned_paths.splitlines())

def parse_sync_info(text):
    packages = {}
    for block in text.split('\n\n'):
        values = {}
        for line in block.splitlines():
            key, sep, value = line.partition(':')
            if sep and key.strip() in {'Repository', 'Name', 'Version', 'Architecture'}:
                values[key.strip()] = value.strip()
        if values.get('Name'):
            packages[values['Name']] = values
    return packages

def srcinfo_arches(text, package):
    common, selected = [], []
    current = None
    for line in text.splitlines():
        key, sep, value = line.strip().partition('=')
        if not sep:
            continue
        key, value = key.strip(), value.strip()
        if key == 'pkgbase':
            current = None
        elif key == 'pkgname':
            current = value
        elif key == 'arch':
            if current is None:
                common.append(value)
            elif current == package:
                selected.append(value)
    return sorted(set(selected or common))

class Probe:
    def __init__(self, work):
        self.work = work
        (work / 'logs').mkdir()
        self.commands = []

    def run(self, label, argv, timeout=60, required=True):
        print('Checking ' + label + '…', flush=True)
        try:
            p = subprocess.run([str(a) for a in argv], capture_output=True, timeout=timeout, env=ENV)
            code, stdout, stderr = p.returncode, p.stdout, p.stderr
        except subprocess.TimeoutExpired as exc:
            code, stdout, stderr = 124, exc.stdout or b'', exc.stderr or b''
        except OSError as exc:
            code, stdout, stderr = 127, b'', str(exc).encode()
        for stream, data in [('stdout', stdout), ('stderr', stderr)]:
            (self.work / 'logs' / (label + '.' + stream)).write_bytes(data)
        self.commands.append({'label': label, 'argv': [str(a) for a in argv], 'exit_code': code,
                              'timeout_seconds': timeout, 'stdout_sha256': digest(stdout),
                              'stderr_sha256': digest(stderr)})
        (self.work / 'commands.json').write_text(json.dumps(self.commands, indent=2) + '\n')
        if required:
            require(code == 0, label + ' failed (exit ' + str(code) + '); see retained logs.')
        return code, stdout.decode(errors='replace')

    def git(self, source, label, *args, timeout=120):
        return self.run(label, ['git', '-c', 'core.hooksPath=/dev/null', '-c', 'core.fsmonitor=false',
                               '-C', source, *args], timeout=timeout)[1].strip()

def collect(probe, report):
    _, release = probe.run('running-kernel', ['uname', '-r'])
    release = release.strip()
    _, owned = probe.run('kernel-owned-files', ['pacman', '-Qlq', 'linux-aarch64'])
    _, kernel_package = probe.run('kernel-package', ['pacman', '-Q', 'linux-aarch64'])
    report.update(kernel_running=release, kernel_package=kernel_package.strip())
    require(kernel_matches(release, owned) and (Path('/usr/lib/modules') / release).is_dir(),
            'Running kernel does not match installed package module ownership. No source/deployment attempted.')
    report['kernel_gate'] = 'PASS_INSTALLED_MODULE_OWNERSHIP'
    probe.run('services', ['systemctl', '--no-pager', 'is-active', 'systemd-networkd',
                          'systemd-resolved', 'wpa_supplicant@wlan0', 'NetworkManager'], required=False)
    _, package_text = probe.run('installed-packages', ['pacman', '-Q'])
    installed = dict(line.split(' ', 1) for line in package_text.splitlines())
    free = shutil.disk_usage(probe.work).free
    report['workspace_free_bytes'] = free
    require(free > 512 * 1024**2, 'Insufficient source/evidence workspace capacity.')
    source = probe.work / 'source'
    probe.run('clone-source', ['git', '-c', 'core.hooksPath=/dev/null', 'clone', '--quiet',
              '--no-checkout', '--single-branch', '--branch', BRANCH, '--', URL, source], timeout=900)
    probe.git(source, 'checkout-pin', 'checkout', '--detach', PIN)
    require(probe.git(source, 'source-head', 'rev-parse', 'HEAD') == PIN, 'Source commit mismatch.')
    require(probe.git(source, 'source-tree', 'rev-parse', 'HEAD^{tree}') == TREE, 'Source tree mismatch.')
    probe.git(source, 'source-fsck', 'fsck', '--full', '--strict', timeout=600)
    refs = probe.git(source, 'refs-before', 'show-ref', '--head')
    manifest = probe.git(source, 'canonical-manifest', 'show', 'HEAD:install-scripts/core/package-manifest.sh')
    official, aur = parse_manifest(manifest)
    report.update(source=str(source), source_commit=PIN, source_tree=TREE,
                  canonical_official=official, canonical_aur=aur,
                  missing_packages=sorted((set(official) | set(aur)) - set(installed)))
    probe.run('installer-dry-run', ['bash', str(source / 'install.sh'), '--dry-run'], timeout=120)
    _, metadata = probe.run('sync-metadata', ['pacman', '-Si', '--', *official, *aur,
                           'libnm', 'networkmanager'], required=False)
    sync = parse_sync_info(metadata)
    report['sync_providers'] = sync
    needed = set(report['missing_packages'])
    missing_official = sorted((set(official) & needed) - set(sync))
    report['missing_official_providers'] = missing_official
    wrong_arch = {name: sync[name].get('Architecture') for name in needed & set(sync)
                  if sync[name].get('Architecture') not in {'aarch64', 'any'}}
    report['unsupported_sync_architectures'] = wrong_arch
    preview = sorted(needed & set(sync))
    if preview:
        status, _ = probe.run('transaction-preview', ['pacman', '-Sup', '--needed', '--print-format',
                              '%r/%n %v %s', '--', *preview], timeout=180, required=False)
    else:
        status = 0
    report['transaction_preview_exit'] = status
    aur_needed = sorted((set(aur) & needed) - set(sync))
    findings = {}
    if aur_needed:
        url = 'https://aur.archlinux.org/rpc/v5/info?' + urllib.parse.urlencode([('arg[]', p) for p in aur_needed])
        report['aur_rpc_url'] = url
        with urllib.request.urlopen(url, timeout=30) as response:
            raw = response.read(2 * 1024**2)
        (probe.work / 'logs/aur-rpc.json').write_bytes(raw)
        payload = json.loads(raw)
        require(isinstance(payload, dict) and payload.get('type') == 'multiinfo' and
                isinstance(payload.get('results'), list), 'Unexpected AUR metadata response.')
        rows = payload['results']
        require(all(isinstance(row, dict) and row.get('Name') in aur_needed for row in rows),
                'Unexpected AUR package identities.')
        info = {row['Name']: row for row in rows}
        require(len(info) == len(rows), 'Duplicate AUR package identities.')
        for package in aur_needed:
            if package not in info:
                findings[package] = {'status': 'NO_PROVIDER_FOUND'}
                continue
            base = info[package].get('PackageBase')
            require(isinstance(base, str) and re.fullmatch('[a-z0-9][a-z0-9+_.@-]*', base), 'Invalid AUR base identity.')
            target = probe.work / ('aur-' + package)
            probe.run('aur-clone-' + package, ['git', '-c', 'core.hooksPath=/dev/null', 'clone',
                      '--quiet', '--bare', '--depth=1', '--', 'https://aur.archlinux.org/' + base + '.git', target], timeout=180)
            commit = probe.git(target, 'aur-pin-' + package, 'rev-parse', 'HEAD')
            srcinfo = probe.git(target, 'aur-srcinfo-' + package, 'show', commit + ':.SRCINFO')
            probe.git(target, 'aur-pkgbuild-' + package, 'show', commit + ':PKGBUILD')
            arches = srcinfo_arches(srcinfo, package)
            findings[package] = {'commit': commit, 'base': base, 'rpc': info[package], 'architectures': arches,
                                 'status': 'SOURCE_REVIEW_REQUIRED' if set(arches) & {'any', 'aarch64'} else 'UNSUPPORTED_ARCH'}
    report['aur_sources'] = findings
    require(not probe.git(source, 'source-status', 'status', '--porcelain=v1', '--untracked-files=all'),
            'Dry-run changed the new source checkout.')
    require(refs == probe.git(source, 'refs-after', 'show-ref', '--head'), 'Source refs changed during checks.')
    report['network_integration'] = 'OPEN: existing networkd backend retained; RofiNetwork consumes NetworkManager. No transition performed.'
    blocked = bool(missing_official or wrong_arch or status or
                   any(row['status'] in {'NO_PROVIDER_FOUND', 'UNSUPPORTED_ARCH'} for row in findings.values()))
    report['status'] = 'BLOCKED_PROVIDER_RECONCILIATION' if blocked else 'PREVIEW_COMPLETE_REVIEW_REQUIRED'

def seal(work, report):
    (work / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    files = [work / 'report.json', work / 'commands.json', *sorted((work / 'logs').iterdir())]
    files = [path for path in files if path.is_file()]
    (work / 'SHA256SUMS').write_text(''.join(digest(path.read_bytes()) + '  ' + str(path.relative_to(work)) + '\n' for path in files))
    archive = work.with_suffix('.tar.gz')
    with tarfile.open(archive, 'w:gz') as stream:
        for path in [*files, work / 'SHA256SUMS']:
            stream.add(path, arcname=str(path.relative_to(work)), recursive=False)
    print('\n' + report['status'])
    print('Source/evidence retained: ' + str(work))
    print(digest(archive.read_bytes()) + '  ' + str(archive))
    print('Return this archive and SHA256. No packages, existing source files, services or boot configuration were changed.')

def main():
    if os.geteuid() == 0 or platform.machine() != 'aarch64':
        print('Run on the rebuilt AArch64 Pi as the normal login user, without sudo.', file=sys.stderr)
        return 20
    os.umask(0o077)
    state = Path.home() / '.local/state/gup-r7'
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    require(state.is_dir() and not state.is_symlink(), 'Invalid private state directory.')
    work = Path(tempfile.mkdtemp(prefix='predeploy-', dir=state))
    report = {'status': 'BLOCKED', 'mode': 'SOURCE_AND_TRANSACTION_PREVIEW_ONLY',
              'certification': 'NOT_CERTIFIED; no installation, AUR build, network transition or graphical acceptance.',
              'provider_scope': 'Sync metadata describes configured repositories, not necessarily official or reviewed providers.'}
    code = 0
    try:
        collect(Probe(work), report)
        if report['status'].startswith('BLOCKED'):
            code = 1
    except KeyboardInterrupt:
        report.update(status='INTERRUPTED', error='Probe interrupted; partial evidence retained.')
        code = 130
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        report.update(status='BLOCKED', error=str(exc))
        code = 1
    finally:
        seal(work, report)
    return code

if __name__ == '__main__':
    sys.exit(main())
