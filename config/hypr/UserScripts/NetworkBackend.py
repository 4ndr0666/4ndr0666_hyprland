#!/usr/bin/env python3
"""Backend-aware network menu. Never starts a network service or requests sudo.

NetworkManager retains the existing RofiNetwork implementation (exit 75 is the
dispatch contract). networkd uses the existing wpa_supplicant control socket;
new profiles are explicitly session-only and no save_config command is issued.
Secrets are sent on stdin, never on process argv or in diagnostics.
"""
import codecs
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

DELEGATE_NM = 75

def command(argv, *, data=None, timeout=8):
    result = subprocess.run(argv, input=data, text=True, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError('Network command failed: ' + Path(argv[0]).name)
    return result.stdout.strip()

def active(unit):
    result = subprocess.run(['systemctl', 'is-active', '--quiet', unit], timeout=5)
    if result.returncode not in {0, 3, 4}:
        raise RuntimeError('Cannot determine network service state.')
    return result.returncode == 0

def backend():
    # An active NM backend continues through the unchanged legacy menu. Merely
    # installing its typelib is never taken as permission to activate it.
    if active('NetworkManager.service'):
        return 'NetworkManager'
    if active('systemd-networkd.service'):
        return 'networkd'
    raise RuntimeError('No supported active network backend; no service was changed.')

def interfaces():
    return sorted(p.name for p in Path('/sys/class/net').iterdir()
                  if (p / 'wireless').exists() and re.fullmatch(r'[A-Za-z0-9_.:-]+', p.name))

def control(interface, *args):
    require_interface(interface)
    text = command(['wpa_cli', '-i', interface, *args])
    if text == 'FAIL' or 'Could not connect to wpa_supplicant' in text:
        raise RuntimeError('Wi-Fi control unavailable. Existing connection was preserved; check control-socket permissions.')
    return text

def require_interface(value):
    if not re.fullmatch(r'[A-Za-z0-9_.:-]+', value):
        raise RuntimeError('Invalid wireless interface identity.')

def status(interface):
    text = control(interface, 'status')
    values = dict(line.split('=', 1) for line in text.splitlines() if '=' in line)
    if 'wpa_state' not in values:
        raise RuntimeError('No valid supplicant status; connection unchanged.')
    return values

def choose(title, values, *, password=False):
    if not values and not password:
        return None
    args = ['rofi', '-dmenu', '-p', title]
    if password:
        args.append('-password')
    else:
        args.append('-no-custom')
    result = subprocess.run(args, input='\n'.join(values), text=True, capture_output=True)
    if result.returncode:
        return None
    value = result.stdout.rstrip('\n')
    return value if password or value in values else None

def message(text):
    subprocess.run(['rofi', '-e', text], check=False)

def decode_ssid(text):
    # wpa_cli uses printf-style escapes; never evaluate SSID text as shell code.
    try:
        return codecs.escape_decode(text.replace('\\e', '\\x1b').encode())[0]
    except (ValueError, UnicodeError):
        raise RuntimeError('Unsupported SSID encoding; connection unchanged.') from None

def saved(interface):
    rows = []
    for line in control(interface, 'list_networks').splitlines()[1:]:
        fields = line.split('\t')
        if len(fields) == 4 and fields[0].isdigit():
            rows.append(dict(id=fields[0], ssid=fields[1], flags=fields[3]))
    return rows

def secret_psk(interface, identity, key):
    if not identity.isdigit() or not re.fullmatch('[0-9a-f]{64}', key):
        raise RuntimeError('Invalid private network setting.')
    # wpa_cli interactive output may echo its input; capture and discard it.
    # Neither its output nor the key is used in a diagnostic or evidence log.
    output = command(['wpa_cli', '-i', interface],
                     data='set_network ' + identity + ' psk ' + key + '\nquit\n')
    if not any(line.strip() == 'OK' for line in output.splitlines()):
        raise RuntimeError('Could not set private network key; new profile will be removed.')

def restore_profiles(interface, rows):
    for row in rows:
        control(interface, 'disable_network' if '[DISABLED]' in row['flags'] else 'enable_network', row['id'])
    current = next((r['id'] for r in rows if '[CURRENT]' in r['flags']), None)
    if current:
        # reconnect to the previously current ID, without disabling other IDs
        control(interface, 'select_network', current)
        for row in rows:
            if row['id'] != current and '[DISABLED]' not in row['flags']:
                control(interface, 'enable_network', row['id'])

def temporary_connection(interface, ssid, flags, password=None):
    if not 1 <= len(ssid) <= 32:
        raise RuntimeError('SSID must contain 1–32 bytes.')
    secure = 'PSK' in flags
    if any(mode in flags for mode in ['EAP', 'SAE', 'OWE']) or ('WEP' in flags):
        raise RuntimeError('This Pi menu supports open/WPA2-PSK session profiles. Existing profiles and desktop NM features are unchanged.')
    if not secure and any(tag not in {'ESS', 'WPS'} for tag in re.findall(r'\[([^]]+)\]', flags)):
        raise RuntimeError('Unsupported network security; no profile was created.')
    if secure and (password is None or not 8 <= len(password.encode()) <= 63):
        raise RuntimeError('WPA passphrase must contain 8–63 bytes.')
    rows = saved(interface)
    identity = control(interface, 'add_network')
    if not identity.isdigit():
        raise RuntimeError('Could not create a temporary network profile.')
    try:
        if control(interface, 'set_network', identity, 'ssid', ssid.hex()) != 'OK':
            raise RuntimeError('Could not set network identity.')
        if secure:
            secret_psk(interface, identity, hashlib.pbkdf2_hmac('sha1', password.encode(), ssid, 4096, 32).hex())
        elif control(interface, 'set_network', identity, 'key_mgmt', 'NONE') != 'OK':
            raise RuntimeError('Could not configure open network.')
        if control(interface, 'select_network', identity) != 'OK':
            raise RuntimeError('Could not select new network.')
        for _ in range(40):
            values = status(interface)
            if values.get('id') == identity and values.get('wpa_state') == 'COMPLETED':
                return
            time.sleep(0.25)
        raise RuntimeError('Connection did not complete; restoring previous selection.')
    except BaseException:
        try:
            control(interface, 'remove_network', identity)
            restore_profiles(interface, rows)
        except (OSError, RuntimeError, subprocess.SubprocessError):
            raise RuntimeError('Connection failed and rollback needs review; original on-disk Wi-Fi configuration is unchanged.') from None
        raise

def native_menu():
    choices = interfaces()
    if not choices:
        message('networkd is active. No Wi-Fi interface found.\n' + command(['networkctl', '--no-pager', '--no-legend', 'list']))
        return 0
    interface = choices[0] if len(choices) == 1 else choose('Wi-Fi interface', choices)
    if not interface:
        return 0
    values = status(interface)  # prove socket access before offering controls
    action = choose('Pi Wi-Fi · ' + values.get('wpa_state', 'unknown'),
                    ['Status', 'Use saved Wi-Fi', 'Connect temporary Wi-Fi', 'Reconnect', 'Disconnect'])
    if action == 'Status':
        message('\n'.join(k + ': ' + values[k] for k in ['wpa_state', 'ssid', 'ip_address'] if k in values))
    elif action == 'Use saved Wi-Fi':
        rows = saved(interface)
        labels = {r['id'] + ' · ' + r['ssid'] + ' ' + r['flags']: r['id'] for r in rows}
        selection = choose('Saved Wi-Fi', list(labels))
        if selection and control(interface, 'select_network', labels[selection]) != 'OK':
            raise RuntimeError('Could not select saved profile.')
    elif action == 'Connect temporary Wi-Fi':
        if control(interface, 'scan') != 'OK':
            raise RuntimeError('Wi-Fi scan was not accepted.')
        time.sleep(2)
        rows = []
        for line in control(interface, 'scan_results').splitlines()[1:]:
            fields = line.split('\t', 4)
            if len(fields) == 5 and fields[4]:
                rows.append(fields)
        labels = {r[4] + ' · ' + r[2] + ' dBm · ' + r[0]: r for r in rows}
        selection = choose('Temporary connection · original saved Wi-Fi retained', list(labels))
        if selection:
            row = labels[selection]
            password = choose('Wi-Fi password · session only', [], password=True) if 'PSK' in row[3] else None
            if 'PSK' in row[3] and password is None:
                return 0
            if not row[3].replace('[ESS]', '').replace('[WPS]', ''):
                if choose('Open network: connect without encryption?', ['Cancel', 'Connect']) != 'Connect':
                    return 0
            temporary_connection(interface, decode_ssid(row[4]), row[3], password)
            message('Connected for this supplicant session. Original saved Wi-Fi is unchanged on disk.')
    elif action in {'Reconnect', 'Disconnect'}:
        if control(interface, action.lower()) != 'OK':
            raise RuntimeError('Wi-Fi operation was not accepted.')
    return 0

def main(mode='menu'):
    selected = backend()
    if mode == 'probe':
        results = []
        if selected == 'networkd':
            for interface in interfaces():
                values = status(interface)
                results.append(dict(interface=interface, control_access=True, wpa_state=values['wpa_state']))
        print(json.dumps(dict(backend=selected, wireless=results, persistent_changes=False)))
        return 0
    if mode == 'applets':
        if selected == 'NetworkManager':
            for argv in [['nm-applet', '--indicator'], ['nm-tray']]:
                if shutil.which(argv[0]):
                    subprocess.Popen(argv)
        return 0
    if mode != 'menu':
        raise RuntimeError('Unknown network menu mode.')
    return DELEGATE_NM if selected == 'NetworkManager' else native_menu()

if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1] if len(sys.argv) == 2 else 'menu'))
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        if len(sys.argv) == 2 and sys.argv[1] == 'probe':
            print(json.dumps(dict(error=str(error), persistent_changes=False)))
        else:
            message(str(error))
        sys.exit(1)
