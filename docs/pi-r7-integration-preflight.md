# Retained Pi backend: native access gate

The user selected retaining networkd/wpa_supplicant on the Pi while preserving
NetworkManager behavior on desktops. The integration candidate is separately
published on `gup/r7-pi-integration`, descending from frozen R7 5f97fdf. Original
R6/R7 recovery refs, Pi refs and main remain unchanged.

Candidate commit `f752274a78ff3dcd9482ee75704bfc6c2b8b3470`, tree
`1d348e7ed4d98e29d661811315060824330ba70c`, adds backend dispatch before GI/NM
imports, native wpa control-socket menu behavior, backend-aware startup applets,
an optional mem-police guard, mandatory helper deployment and a bounded wallpaper
daemon readiness wait. All 103 Golden Units pass, including 15 new behavioral
tests. The old NetworkManager implementation after imports is byte-identical;
all 52 named units are unchanged. This is evidence for the preserved code path,
not proof of all environmental runtime behavior.

Run `scripts/pi-r7-integration-preflight.py` as the normal Pi user, without
flags or sudo. It creates a fresh private source/evidence directory, verifies
the exact candidate commit/tree and strict Git object integrity, checks the
kernel module ownership and required binary availability, and runs the native
backend helper's read-only `probe`. It requires observed networkd and actual
wireless control-socket access, without scanning or selecting any network.
The native report excludes SSIDs, keys and IP addresses. Source, package,
service and user configuration state remain unchanged apart from the new private
checkout and evidence. Returned archive excludes the Git working tree.

It also records the installed compositor's actual help output, DRM node access,
session type, optional helper availability and existence of relevant user config
paths. DRM permissions from SSH do not establish local-seat access or failure;
no graphical launch is attempted. NM applets are not launched as a test.
Existing source directories/refs and all prior evidence are retained.

This gate is necessary because mocked menu tests cannot prove target socket
permissions or compositor configuration API support. A permission failure stops;
the script never requests sudo, changes socket groups or rewrites saved Wi-Fi.
After accepting the returned archive and SHA256, stage reviewed configuration
with private backups and a restore map, validate it against the actual installed
API, then proceed to local-console graphical acceptance. No full GUP or runtime
certification is claimed by this source or native-access gate.
