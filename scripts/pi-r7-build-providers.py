#!/usr/bin/env python3
"""Build three reviewed R7 providers on the Pi; retain packages without installing them.

No flags. Uses a fresh private workspace, pinned source hashes and a separate
GnuPG keyring. Pacman alone may upgrade/install build dependencies, with its
normal confirmation. No desktop deployment, service changes or AUR helper.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import threading

FINGERPRINT = 'F4FDB18A9937358364B276E9E25D679AF73C6D2F'
DEPENDENCIES = ['base-devel', 'cargo', 'rust', 'cmake', 'meson', 'ninja',
                'scdoc', 'gtk3', 'gtk-layer-shell', 'gobject-introspection']
SOURCES = {
    'wallust-3.5.2.tar.gz': ('https://codeberg.org/explosion-mental/wallust/archive/3.5.2.tar.gz',
        '8609d27162975777797f2f625d884a6475c766ed943393219d585577ac8bfcfe'),
    'wlogout-1.2.2.tar.gz': ('https://github.com/ArtsyMacaw/wlogout/releases/download/1.2.2/wlogout.tar.gz',
        '70742b32479ae34ed544ce1fe5b6d92845857d4c4dfe55fccd4eb993f0dd0d9e'),
    'wlogout-1.2.2.tar.gz.sig': ('https://github.com/ArtsyMacaw/wlogout/releases/download/1.2.2/wlogout.tar.gz.sig',
        '618dae73ec41372f5620d29c26a6d0c572eaaacafb9a1086251ce66c6ba157e2'),
    'victor-mono-1.5.6.zip': ('https://github.com/rubjo/victor-mono/archive/refs/tags/v1.5.6.zip',
        'e7502e2aeaaf579ea9c790bee4088454e86d8a3bd1d6757145fb18a33ae90608'),
    'wlogout-signing-key.asc': ('https://keys.openpgp.org/vks/v1/by-fingerprint/' + FINGERPRINT,
        'f675b48a46ac8094d6d5bb67ad38ed54c2e7cc4820e819f8f773c3d7dbec4f55'),
}

RECIPES = {
    'wallust': '''pkgname=wallust
pkgver=3.5.2
pkgrel=2.1
pkgdesc="Generate colors from an image (local R7 AArch64 build)"
arch=(aarch64)
url="https://codeberg.org/explosion-mental/wallust"
license=(MIT)
depends=(glibc libgcc)
makedepends=(cargo cmake)
optdepends=(imagemagick)
source=("wallust-3.5.2.tar.gz::https://codeberg.org/explosion-mental/wallust/archive/3.5.2.tar.gz")
sha256sums=(8609d27162975777797f2f625d884a6475c766ed943393219d585577ac8bfcfe)
options=(!lto)
prepare() {
    cd "$srcdir/wallust"
    export RUSTUP_TOOLCHAIN=stable
    cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
}
build() {
    cd "$srcdir/wallust"
    export RUSTUP_TOOLCHAIN=stable CARGO_TARGET_DIR=target
    export CARGO_BUILD_JOBS=1 CARGO_PROFILE_RELEASE_LTO=false
    cargo build --features themes,doc --frozen --release
}
package() {
    cd "$srcdir/wallust"
    install -Dm755 target/release/wallust "$pkgdir/usr/bin/wallust"
    install -Dm644 -t "$pkgdir/usr/share/man/man1" man/wallust.1 man/wallust-theme.1 man/wallust-cs.1 man/wallust-run.1
    install -Dm644 -t "$pkgdir/usr/share/man/man5" man/wallust.5
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/wallust/LICENSE"
}
''',
    'wlogout': '''pkgname=wlogout
pkgver=1.2.2
pkgrel=0.1
pkgdesc="Logout menu for Wayland (local R7 AArch64 build)"
arch=(aarch64)
license=(MIT)
url="https://github.com/ArtsyMacaw/wlogout"
depends=(gtk3 gobject-introspection gtk-layer-shell)
makedepends=(meson ninja scdoc)
source=("wlogout-1.2.2.tar.gz::https://github.com/ArtsyMacaw/wlogout/releases/download/1.2.2/wlogout.tar.gz"
        "wlogout-1.2.2.tar.gz.sig::https://github.com/ArtsyMacaw/wlogout/releases/download/1.2.2/wlogout.tar.gz.sig")
validpgpkeys=(F4FDB18A9937358364B276E9E25D679AF73C6D2F)
sha256sums=(70742b32479ae34ed544ce1fe5b6d92845857d4c4dfe55fccd4eb993f0dd0d9e
            618dae73ec41372f5620d29c26a6d0c572eaaacafb9a1086251ce66c6ba157e2)
build() {
    cd "$srcdir"
    arch-meson . build
    meson compile -C build -j 1
}
package() {
    cd "$srcdir"
    DESTDIR="$pkgdir" meson install -C build
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/wlogout/LICENSE"
}
''',
    'ttf-victor-mono': '''pkgname=ttf-victor-mono
pkgver=1.5.6
pkgrel=1.1
pkgdesc="Victor Mono fonts (local R7 package, with upstream license)"
arch=(any)
license=(OFL-1.1)
url="https://rubjo.github.io/victor-mono/"
source=("victor-mono-1.5.6.zip::https://github.com/rubjo/victor-mono/archive/refs/tags/v1.5.6.zip")
sha256sums=(e7502e2aeaaf579ea9c790bee4088454e86d8a3bd1d6757145fb18a33ae90608)
prepare() {
    mkdir "$srcdir/VictorMonoAll"
    bsdtar -xf "$srcdir/victor-mono-1.5.6/public/VictorMonoAll.zip" -C "$srcdir/VictorMonoAll"
}
package() {
    install -dm755 "$pkgdir/usr/share/fonts/TTF"
    install -m644 "$srcdir"/VictorMonoAll/TTF/*.ttf "$pkgdir/usr/share/fonts/TTF/"
    install -Dm644 "$srcdir/victor-mono-1.5.6/LICENSE" "$pkgdir/usr/share/licenses/ttf-victor-mono/LICENSE"
}
''',
}

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def build_environment(work):
    # Ignore inherited build destinations, shell startup code and compiler flags.
    # Preserve proxy/CA settings needed for normal authenticated HTTPS transport.
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(('GIT_', 'CARGO_', 'RUST', 'MAKE'))
           and k not in {'BASH_ENV', 'ENV', 'SHELLOPTS', 'BASHOPTS', 'PKGDEST',
                         'SRCDEST', 'SRCPKGDEST', 'BUILDDIR', 'PACKAGER', 'LOGDEST',
                         'PKGEXT', 'SRCEXT', 'GPGKEY', 'CARCH',
                         'CFLAGS', 'CXXFLAGS', 'CPPFLAGS', 'LDFLAGS', 'LD_PRELOAD'}}
    env = {k: v for k, v in env.items() if not k.startswith('BASH_FUNC_')}
    env.update(LC_ALL='C', PATH='/usr/bin:/bin', GNUPGHOME=str(work / 'gnupg'), CARGO_HOME=str(work / 'cargo'),
               CARGO_BUILD_JOBS='1', MAKEFLAGS='-j1', PYTHONDONTWRITEBYTECODE='1')
    return env

def makepkg_config(target):
    return 'source /etc/makepkg.conf\n' + ''.join(
        key + '=' + shlex.quote(str(target)) + '\n'
        for key in ['PKGDEST', 'SRCDEST', 'SRCPKGDEST', 'LOGDEST']) + (
        "unset BUILDDIR\nMAKEFLAGS='-j1'\nBUILDENV=(!distcc !color !ccache check !sign)\n")

class Runner:
    def __init__(self, work):
        self.work, self.commands = work, []
        self.env = build_environment(work)
        (work / 'logs').mkdir()

    def run(self, label, argv, cwd=None):
        print('\n' + shlex.join([str(x) for x in argv]), flush=True)
        log = self.work / 'logs' / (label + '.combined')
        code = 127
        try:
            with log.open('wb') as output:
                p = subprocess.Popen([str(x) for x in argv], cwd=cwd, env=self.env,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                def copy():
                    for chunk in iter(lambda: p.stdout.read1(65536), b''):
                        output.write(chunk)
                        output.flush()
                        sys.stdout.buffer.write(chunk)
                        sys.stdout.buffer.flush()
                thread = threading.Thread(target=copy)
                thread.start()
                try:
                    code = p.wait()
                except KeyboardInterrupt:
                    p.send_signal(signal.SIGINT)
                    code = p.wait()
                    raise
                finally:
                    thread.join()
        finally:
            if not log.exists():
                log.write_bytes(b'')
            self.commands.append(dict(label=label, argv=[str(x) for x in argv],
                                      cwd=str(cwd) if cwd else None, exit_code=code,
                                      combined_sha256=sha(log)))
            (self.work / 'commands.json').write_text(json.dumps(self.commands, indent=2) + '\n')
        require(code == 0, label + ' failed; retained logs identify the stopped gate.')
        return log.read_text(errors='replace')

def inspect_package(runner, name, path):
    text = runner.run(name + '-pkginfo', ['bsdtar', '-xOf', path, '.PKGINFO'])
    fields = {}
    for line in text.splitlines():
        key, sep, value = line.partition(' = ')
        if sep:
            if key in fields:
                fields[key] = [*fields[key], value] if isinstance(fields[key], list) else [fields[key], value]
            else:
                fields[key] = value
    require(fields.get('pkgname') == name, 'Unexpected package name.')
    require(fields.get('arch') == ('any' if name.startswith('ttf-') else 'aarch64'),
            'Unexpected package architecture.')
    # Check the actual ELF machine, rather than trusting package metadata alone.
    if not name.startswith('ttf-'):
        argv = ['bsdtar', '-xOf', str(path), 'usr/bin/' + name]
        proc = subprocess.run(argv, capture_output=True, env=runner.env)
        runner.commands.append(dict(label=name + '-elf', argv=argv, exit_code=proc.returncode,
                                    stdout_sha256=hashlib.sha256(proc.stdout).hexdigest(),
                                    stderr_sha256=hashlib.sha256(proc.stderr).hexdigest(),
                                    stdout_retention='first 20 bytes only; complete executable stays in package'))
        (runner.work / 'commands.json').write_text(json.dumps(runner.commands, indent=2) + '\n')
        (runner.work / 'logs' / (name + '.elf-stderr')).write_bytes(proc.stderr)
        require(proc.returncode == 0, 'Could not extract package executable.')
        raw = proc.stdout
        header = raw[:20]
        require(header[:6] == b'\x7fELF\x02\x01' and int.from_bytes(header[18:20], 'little') == 183,
                'Built executable is not little-endian AArch64 ELF64.')
        (runner.work / 'logs' / (name + '.elf-header')).write_bytes(header)
    return dict(path=str(path), sha256=sha(path), metadata=fields)

def collect(runner, report):
    work = runner.work
    require(shutil.disk_usage(work).free >= 6 * 1024**3, 'Need 6 GiB free for Rust sources/builds; no dependency transaction attempted.')
    memory = dict((k, int(v.split()[0])) for k, v in
                  (line.split(':', 1) for line in Path('/proc/meminfo').read_text().splitlines()))
    require(memory['MemAvailable'] + memory['SwapFree'] >= 2 * 1024**2,
            'Need 2 GiB available RAM plus swap for a bounded single-job build; no transaction attempted.')
    report['resources'] = dict(free_bytes=shutil.disk_usage(work).free,
                               available_memory_kib=memory['MemAvailable'], swap_free_kib=memory['SwapFree'])
    runner.run('packages-before', ['pacman', '-Q'])
    network_before = runner.run('network-before', ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState',
                                 'systemd-networkd', 'systemd-resolved', 'wpa_supplicant@wlan0', 'NetworkManager'])
    (work / 'sources').mkdir()
    (work / 'gnupg').mkdir(mode=0o700)
    for filename, (url, expected) in SOURCES.items():
        path = work / 'sources' / filename
        runner.run('fetch-' + filename, ['curl', '--proto', '=https', '--proto-redir', '=https',
                   '-fL', '--retry', '2', '--connect-timeout', '30', '--max-time', '900', url, '-o', path])
        require(sha(path) == expected, 'Source hash mismatch: ' + filename)
    runner.run('key-import', ['gpg', '--batch', '--import', work / 'sources/wlogout-signing-key.asc'])
    signature = runner.run('wlogout-signature', ['gpg', '--batch', '--status-fd', '1', '--verify',
                           work / 'sources/wlogout-1.2.2.tar.gz.sig', work / 'sources/wlogout-1.2.2.tar.gz'])
    require('[GNUPG:] VALIDSIG ' + FINGERPRINT + ' ' in signature, 'Unexpected release signing key.')
    print('\nSources verified. Pacman will now offer a full upgrade plus build dependencies.\n'
          'Review its normal confirmation. Provider packages will only be built, not installed.\n'
          'No installer, network service or boot configuration command will run.', flush=True)
    report['dependency_transaction'] = 'STARTED; inspect dependency-transaction log if interrupted'
    runner.run('dependency-transaction', ['sudo', 'pacman', '-Syu', '--needed', '--', *DEPENDENCIES])
    report['dependency_transaction'] = 'COMPLETED'
    runner.run('packages-after-dependencies', ['pacman', '-Q'])
    network_after_dependencies = runner.run('network-after-dependencies', ['systemctl', 'show',
        '--property=Id,ActiveState,UnitFileState', 'systemd-networkd', 'systemd-resolved',
        'wpa_supplicant@wlan0', 'NetworkManager'])
    require(network_before == network_after_dependencies,
            'Network unit state changed during dependency transaction; stop for review.')
    runner.run('kernel-after-dependencies', ['uname', '-r'])
    runner.run('kernel-package-after-dependencies', ['pacman', '-Q', 'linux-aarch64'])
    report['packages'] = {}
    for name, recipe in RECIPES.items():
        target = work / name
        target.mkdir()
        (target / 'PKGBUILD').write_text(recipe)
        # New per-package directories prevent user makepkg destinations/hooks
        # from redirecting outputs or rewriting an existing user build tree.
        config = target / 'makepkg.conf'
        config.write_text(makepkg_config(target))
        for filename in SOURCES:
            if filename.startswith(name + '-') or (name == 'ttf-victor-mono' and filename.startswith('victor-mono-')):
                shutil.copyfile(work / 'sources' / filename, target / filename)
        runner.run(name + '-build', ['makepkg', '--config', config, '--log'], cwd=target)
        packages = list(target.glob(name + '-*.pkg.tar.*'))
        packages = [p for p in packages if p.is_file() and not p.name.endswith('.sig') and '-debug-' not in p.name]
        require(len(packages) == 1, 'Expected one built package for ' + name)
        report['packages'][name] = inspect_package(runner, name, packages[0])
        if name == 'wallust':
            binary = target / 'pkg/wallust/usr/bin/wallust'
            runner.run('wallust-native-version', [binary, '--version'])
    network_after = runner.run('network-after', ['systemctl', 'show', '--property=Id,ActiveState,UnitFileState',
                                'systemd-networkd', 'systemd-resolved', 'wpa_supplicant@wlan0', 'NetworkManager'])
    require(network_before == network_after, 'Network unit state changed during build; stop for review.')
    report['status'] = 'NATIVE_PACKAGES_BUILT_REVIEW_REQUIRED'

def seal(work, report):
    (work / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    files = [work / 'report.json', *sorted((work / 'logs').glob('*'))]
    files += [p for p in [work / 'commands.json'] if p.exists()]
    files += sorted(work.glob('*/PKGBUILD')) + sorted(work.glob('*/makepkg.conf'))
    (work / 'SHA256SUMS').write_text(''.join(sha(p) + '  ' + str(p.relative_to(work)) + '\n' for p in files))
    archive = work.with_suffix('.tar.gz')
    with tarfile.open(archive, 'w:gz') as stream:
        for p in [*files, work / 'SHA256SUMS']:
            stream.add(p, arcname=str(p.relative_to(work)), recursive=False)
    print('\n' + report['status'] + '\nBuilds and packages retained: ' + str(work))
    print(sha(archive) + '  ' + str(archive))
    print('Return this evidence archive and SHA256; built packages stay on the Pi.\n'
          'No provider packages were installed and no desktop deployment was attempted.')

def main():
    if os.geteuid() == 0 or platform.machine() != 'aarch64':
        print('Run on the Pi as the normal login user, without sudo.', file=sys.stderr)
        return 20
    os.umask(0o077)
    state = Path.home() / '.local/state/gup-r7'
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    require(not state.is_symlink(), 'Invalid private state directory.')
    work = Path(tempfile.mkdtemp(prefix='providers-', dir=state))
    report = dict(status='BLOCKED', certification='NOT_CERTIFIED',
                  scope='Native provider build; dependency transaction permitted; no deployment',
                  script_sha256=sha(Path(__file__)), source_pins=SOURCES,
                  graphical_runtime='OPEN: wlogout needs a live display even for --version',
                  network_integration='OPEN: existing backend retained; RofiNetwork requires NetworkManager')
    code = 0
    try:
        collect(Runner(work), report)
    except KeyboardInterrupt:
        report.update(status='INTERRUPTED', error='Interrupted; inspect retained transaction/build logs.')
        code = 130
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        report.update(status='BLOCKED', error=str(exc))
        code = 1
    finally:
        seal(work, report)
    return code

if __name__ == '__main__':
    sys.exit(main())
