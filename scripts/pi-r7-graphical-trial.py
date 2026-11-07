#!/usr/bin/env python3
"""Two-minute local-console trial with private configuration and owned cleanup.

No flags, sudo, package installation, permanent deployment or service enablement.
Only the two user-manager variables changed by the candidate are snapshotted.
"""
import hashlib
import base64
import zlib
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

def repair_wallpaper(home, report):
    wallpaper_script = home / '.config/hypr/scripts/WallustAwww.sh'
    require(sha(wallpaper_script) == 'aea3c186fe0719c336bbc998a513a754158f119be910f9a95ee0162c07d57597', 'Wallpaper source hash mismatch')
    wallpaper_text = wallpaper_script.read_text()
    old_copy = 'cp -f -- "$wallpaper_path" "$wallpaper_current"'
    require(wallpaper_text.count(old_copy) == 1, 'Unexpected wallpaper script')
    wallpaper_script.write_text(wallpaper_text.replace(old_copy, 'if [[ ! "$wallpaper_path" -ef "$wallpaper_current" ]]; then\n    ' + old_copy + '\nfi', 1))
    report['trial_patch'] = {'base_commit': SOURCE_PIN, 'wallpaper_before': 'aea3c186fe0719c336bbc998a513a754158f119be910f9a95ee0162c07d57597', 'wallpaper_after': sha(wallpaper_script), 'scope': 'fresh private trial only'}
    # Apply independently pinned reviewed fixes only in the fresh trial copy.
    reviewed = [
        ('hypr/initial-boot.sh', '2fe373968c46d4c12c5a363c43f8755888e63721340520e88bfccfb5d34fcade', '322f73168c8ef5c19bcfd21ff22b9f3ac85874c4194a5c327c40e5ad838f7008', 'eNqtV21v2zYQ/q5fcVW6uAUiyXY7FF3QYFnSdsHWFQjWdUAWGLR0kgnLpEpSdtw0++07kpJtae62rvEHRSKPzx3v5bnLwYOk1iqZcpGgWMKU6VlwAKfuBXSqeGUgQ80LgRkYCaoWIEW5pkeKwHKDCjJpcl6iBi60YWXJDJciDg4I6NcZtih4ww2JLBaYcWaQIPzpVCEdEAX8mcSpFDkvktm6UknMBTeclRPCVKauJpkUSKhwYYBbXQaFVUQK16DQMG5NzKUCQ0pJNjJ8gdCg8I/OKshLubIg7zSqSK7skQqV5tqigddfKy87xVKKwqrq22ZPn7lvncRBoNFA9BJrCRWvMGe8DEjFb0xxNiW/BN4D+pyrF+HDH9++edlFa7bDYEV3qRjZs1dsszvBPMfUkOrtUlorRTewGOspU+S0dYl9GL+XuL3k6kyWUuV1eQ3ayBJF5NbjVJMl8yUTpl5MyJULgmlFo3Om5tFPfvMgDFK7PtGpl6oU5uTVjGTCoDDzvafDgJM1n9miW2gCbDZ/4FNmWPRGZqhEdJFiGARstVpN0kX24pF9o3QqHgfeHS8eRZFRTGhugxdN8SOn7IqfPjkaxaPnR6Oj+Cl0JPJKw5Nhd82sK4RCyVV3uZIahvHz8bdH9Hz2rLuZtfkyfmzDfjbDdA48BwYLuhTZYIvDpr82Og5o4+oKHkCUw74g7836EK6vj21aiwDop0vECkaB+6B6aDMcXeZvcgIyhgsyi4kMChRIVnqJipVojDWJpaYp5diBeeOcaRuYnnKv09Z1yoQUPGXltsZIKdWUbjU3d7AFxEBjxZwJMynn8Q7We8aNq1uypiY04oOMalnrY1vF5L0bKlJ/Z8VSSzPEI5VURDWthi2cxZlYhbejOB4Nh3fHRE+bXftzefOhRrWGkyTDZSLqsoTxyeEIDg9hStrnHXmveRiPNqs2JMF/gPv0CW47UJUi1sph8I3+QwxgcPXy8vLt5bWDiBqXEbMJaZwP1sf0J6+15UZiXndV50fKl8z6GVU8gJPDcUeHpVnY2nq3eQsf3rbFc/X99V3YjTHt+jJyezuHttyVvCfxWptTQon1rAvgTuTc52RBhGgpXYNlRqmKuBBygTE1krmRVWy5W+UUS3AEEnkCIbxdPgn/Hp4vBCcKikyDvKGjr4e1/LXB3ZLZ1wN79ttA75LhvYFrSxPDPWht/ReKsj36wEHwG2K9BE2aSB0pLJFp7BHB/w30oBPpwedu54rNsiOsFCfmSEhD4jQkjYZkoyHZifZgG+77wd4N+WAn5veD3o37oBP4e9Xggh+On34Os61fz+8ZVqVcE/c2/b6ZjoCVjp0o5KWdQigjuH2QsTGcLiUnbqpQUFY0WLblvH534SkeFlx7RrMHjv0s6ZGoUbUTpJ01HaCDaIeRzM1Pt7+fv56cvf3l1cXrie2f30WdNnqXNOaG/Y62A5M87Aw4vc94vvRYtvVRU2j9/aApjlc3HyD0M0r3YNjT0rzv4I13HL8FTuViYbt0tGzvSp+soG7ai1Ov/HrCUWSrMOzb9M+xbhz0M+yfFbeO6OnudIZLzBXqmesK/5ZaZ3bex950RP2Ni4yGCTeiMOOSpvnHYcY0jeIoqLVhWhvMfFYYWaezL5ihvH7XHocBmfMXQyI8Dg=='),
        ('hypr/UserScripts/RainbowBorders.sh', '591654299df962a673a7fbc6717992c0cafbf5898b9af1cac0e3e02bb6c95cab', '514b5bd354c24c7b2f6461cfebd4cea903a4b00977df32d8ae00fe4d83ef6d47', 'eNq1VW1v2zYQ/q5fcWOUWEpqyzGabI2jdFnroAWSZmsyFIPtGrREWUQZShAlx4br/vYdRVmR3QB7webAiHy6l+eee3jc+8ErVOZNufSYnMOUqtjaA+8Q2viBOM9TdeZ5M57HxbQTJA/eSxlm3dPTU+Nw6KH326WkDzyAaZKFLIMgEUkGLIpYkCuI8PndMs0ElSF0OycnR3BdUHSSEZ8VGc15IjuY5IZKOmMhTJewKTH5reDBl8kdy3MuZ6qjYtBJ8phBxqKM4W/BscoyEKxjWYrl0B6wIoGUpyyiXFjWp8vr69/v7idvbj9c+cRevbu9Gay9jqnuxYjLe6RCFCrf/G/HFdjSiViDq6vBm/vJ/R+/DnxS+UwyfJ88EMsyD5OYLSbZbEodF1YW4CfNuMwjaJXG/W5vsflGkdsCYjvOx8sPb29vYB96J6euS/6uzVpbFk1TsZwYtiezjIacybwuLZKACjMEhS0fk4aVyplgaOwhdG3FgT5oSttz0G0HuYALL2RzTxZCQO/i4Bi+fq3yNtvaVyPZgtZHyuU0efylRKLO6hxcQSHpHCdApziaFlwc9OocGcuLTMJx78fStDZI9uASK86pKJiClCqFUohZxoDid8YkQ6WUpkXVGqCuUpppP8UX7ZCjRqtMn8yUKse+6VqDUkygJjEikWKplaalFPEFWh6SkEGu4cKUieSxs8sliIJONqwS7EIVIm84tamGkyvL9EiR1Kw2wvn5OU7ThJuBDIdoKJER8L/B52G3/Wp8FLKZDQcHYK/2ysDhz+M1tGc5dGE81rOo2DN06rNlwHGJ2VZ1COlDmNSMl6VKP1NKi3LkDIdni5K1s/F49dN65NrPlSgbrDs/8smoSjUiL0wjYSJZ1bSmBNXlbHTAcJ5AYlGdN2dVTVKADysYjghm6tAg53NWyXlExuW7asb4aD9VX7+oRukjP+XTPvK1hvLPJXhgntDbr59YXhlknme3ULbeGlnwIflStbuqVb0rZ6NyYptwolXcr+XbR+XWZ3GzF0wTaucslioQuMWY77gNO4rZiJ9HGijqhdjNhUUQYV9rVNajeIw59v/+6s6vNYZZtqZdt40vKmk1J3263swZh4J7tWBbkRXQI98h5e6yV5hmjVuLuLWfnjicw7mjD19bDqClvM8jIwsjY6yoUhowLHjoN39gzpHjaKfL9hVtRxqPO3I7h97o2EtbuwSYmhGvaXKc8mSUGMuzceFDz3V3WDL0RjxTWo6rjX+9Srdz4HHZiVQMuQn/YeizWxkbKmGAbXISaL08QdG2yjAmFPvLeGfnjnHhe9N2WuQLlRlQxTC8cX8RXBOlw/Y15u5A2BFz/bbfN8fcnBL3PwEO/6K9BpZNtUkk/kdEWP5V97nyh+53N+PuDimkKtI0yfSt0xjF03LZmk/znmQLnjeWMJZkigbWn6xr7bs='),
        ('swaync/style.css', 'a93f0b84a9afe12a95732f84344b4a119954adcc2accbadd50907220ee473094', 'b40bce3956ec9023d571e16914ab00a8073a7719b578643ff43d1473606fe8f3', 'eNrFWNtu2zgQfY6/gmgf2gShL2ltBwpgBPuwDwvs/gMlUTIRihRIKo436L8vqZtJi5TlNtgahi/ScObMmeHMUIs7AE8vsFeqlNFikRO1r+J5wovFd5aK5Waz6eXA3WK2uAPygI4sAQmnXEgAwQFRWkkFMsEL/ecYIzFPpDTSs2dSlFwo8GU+X5h3wllG8kUjtWhXLhpV8LT2y5NemuKMMAzrm4BxRWDMRYpFe+W5/lo9PHklcyDyGH1d3oP2PX+8DUhCRBV4jlHykgtesdT8D4nu+SsWtvC5oMJvqgOYcYE7qdkdeJ8B/co4UzBDBaHHCHz6C6s/BCJMgr854+AfLFLwp5b49HQSPmCS71UEYk5T67Ik/+IIrAQunmY/ZjNDrRKcwgQzpTHODeSMJEgRzqDghyjjSSXvJwg2TjZweYkSojTUVWP65HkEnltW2jtNcARKSSW1/LJ8a4Cd6+80V4pq3iLNLcNDSS11s7irmdSWTrQ+6bQaB1KiNCUsj8C38q2GUf/YGDhBnKcbEXjQ0pJTknZ6razzeKTDjyqqIEpa2EZXgUROWASWZ5CWF7hKKJcYxpVSvSrb0c/Zdrt5xI2SjhvH+ZoouUepjmPL7GQAJ+BQ8TIC67OLosnDtQ+skzQxf/NgCDqiBGKSGPYioCsCmK/WEmCkdWujOk3c8PTpchYHh/9OeDUaS4uJ2mELayBAo7FvOLj34nL48WT1SE5fMuu4HAypFbcxF/S9rxFn9AiTPaHpras85jrWBaQ4U72h7dnGamXqZHGFfvhDFmVESNXYu2zO2q8htrxGKBq14cIdN9I0CGOIMFPCoMAlPTo7v8mnx85rWw7qsiuOns3tbuRQjiRI4PaCL4OuzfthCXKw9pXoxuo5y/m67jqWuyZEEfg+HpoPABhiJgA8SolEMcWph27CdMlBdJztIdy6WJU6CEyFzTrF0JdBtUCzPubpEZIC5diTQZsxp0fDKKtCKzraU4c9MYxMFzZgx9sxHJ6+Y1AoUuDfCGHYvFb9njS8/2Z2ziax9w/ZOzdXp4oLA1Kih/n3cWcDy2BJUYL3mqzhAKmrRrMuo1xXZpZDu0zLKRZjitgLPBCW9lOkLY9ouUdftVDyYgb+1W2z6kDSXJdMRRTFP9GAm2o/GCw33vYazKYg+Ta6nTP4ORV3eyq5V8X3JkjoTZdOOjCXJl596ksoRgK0APUM7gMernuDLtb4IHDqsJCydKxqXhuJYAsJNDN3oh6M/SeQO3kgKtlfmryGG/bzFqGHbBvMtss2o2SPkxdvR3OGao/t7rbfF6llJhehcCJ7kH6QZopiTM/OV2ufzM6W9O7G0AjRailKQeRPzeq/mpwDEDtzmDKfzpFwylJTi4897RNADRTYFdPphqvlcuRBhKNDVvFAzVlNs9Y0XkqYC5IOV1CNFlsNLjA49q4+XF8Yxsd9D8qd7mYHHaLuuz5huHW8s76aOh1Pn3l1XdbNkLyStEK0zRFpV+epUK+u3L5Jtgs8ZlWMxM6Ymps/LQpYXxzmcegZwaD964lYq+h8+iVVLdRXTqt+QJ3YcgZZVT9iqj/W7Y/p3ecNtkk9oSo1YGtagw+Ixg9T9uxZagFUliEKoPfpUk+CPumZ021zwnUeeLmX/TPJBUcNCmoqzXWBWf/PgfkPOHB42w=='),
    ]
    report['trial_patch']['reviewed_files'] = []
    for name, before, after, encoded in reviewed:
        path = home / '.config' / name
        require(not path.is_symlink() and path.is_file() and sha(path) == before,
                'Reviewed trial input mismatch: ' + name)
        replacement = zlib.decompress(base64.b64decode(encoded, validate=True))
        require(hashlib.sha256(replacement).hexdigest() == after, 'Reviewed trial payload mismatch: ' + name)
        path.write_bytes(replacement)
        report['trial_patch']['reviewed_files'].append({'path': name, 'before': before, 'after': sha(path)})

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
    repair_wallpaper(home, report)
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
                report['runtime_samples'].append(runtime_sample(probe, sample_env, home, baseline, 'runtime-final'))
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
