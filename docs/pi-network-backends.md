# Network controls on Pi and desktop

This integration candidate descends from frozen R7
`5f97fdf336142241ebe5641db1c74ce2f907105b`. The frozen source, R6 recovery ref,
original Pi refs and main branch remain unchanged. Package acceptance is already
recorded separately; this change addresses configuration integration, not a
new package transaction or an automatic backend migration.

The Pi retains networkd/resolved/wpa_supplicant. Desktop systems with an active
NetworkManager retain the original NetworkManager menu implementation byte for
byte after its imports. `RofiNetwork.sh` dispatches before importing GI/NM:
an already active NM backend continues into that implementation; networkd uses
the new adjacent `NetworkBackend.py`; unknown or failed service observations
stop instead of activating a service. If NM and networkd are active for different
links, the original NM menu remains available. This is backend selection, not a
claim that the menu resolves conflicting ownership of the same interface.

Startup applets use the same backend selection and run only when NM is already
active. Available NM applets retain their original commands. The optional local
`/usr/bin/mem-police` starts only when installed/executable; this project does
not install an unknown third-party daemon or treat it as mandatory infrastructure.
The graphical-runtime deployment module backs up/replaces the new helper through
the existing canonical file-state transaction. New config staging must include
the dispatcher and helper together; a partial script-only deployment is invalid.

The Pi menu uses the existing unprivileged wpa control socket. The image builder
configured its group as wheel; actual access must be proven on the target before
deployment. No sudo, pkexec, service command, socket permission change or persistent
Wi-Fi file rewrite occurs. Read-only `probe` prints only backend, interface name,
socket access and connection state; it omits SSIDs, addresses and keys.

The menu provides status, saved-profile selection, scan/temporary connection,
reconnect and disconnect. A temporary connection supports open and WPA2-PSK
networks, never issues save_config, and is clearly labelled session-only.
Existing on-disk credentials remain available after restart. Enterprise, WEP,
SAE and OWE temporary provisioning are explicitly unsupported; saved profiles
remain selectable. This is a new bounded Pi capability, not a parity claim with
the retained desktop NM features. Password entry uses rofi password mode. A
derived PSK goes through stdin, never process argv or error/evidence output.
On failure/cancellation after adding a profile, remove that profile and restore
the prior current profile and enabled states; rollback failure stops with a
generic diagnostic and preserves the on-disk configuration. Connection commands
run only following a deliberate menu selection, never from startup/probe mode.

First-boot wallpaper setup now polls actual awww readiness for up to ten seconds
after its existing initial delay. The canonical initializer remains the only
daemon owner. A timeout skips wallpaper/palette work and retains the absent
startup marker so a later attempt can retry. Delayed readiness succeeds without
starting a second daemon. This closes the source-observed fixed-delay race;
live portal/wallpaper behavior still requires Pi graphical evidence.

Validation covers NM byte preservation and delegation, networkd avoiding GI and
NM applets, redacted read-only probe output, failed service/socket observation,
secret stdin handling, temporary profile success/timeout/cancellation rollback,
unsupported security rejection, SSID bytes, and delayed/absent wallpaper owner
readiness. The full pre-existing Golden Unit suite remains required. No mock
test establishes actual target socket permissions, radio operations, display,
portal/audio/panel correctness or full semantic equivalence across all runtime
environments. Those remain explicit target and graphical gates.
