# R7 graphical deployment: accepted package evidence and remaining gates

The Pi's `packages-u7toq_s8.tar.gz` has the separately supplied SHA256
`a8250de62afafe911d2b193b6fd42de1b1e15c049decf3afcd39e797f89b36de`.
All 27 internal hashes and all 25 recorded command stream hashes verify, with
every command exiting zero. The exact R7 commit/tree/manifest remain pinned,
the checkout is clean, and refs match before/after the package transactions.
All 62 canonical names are installed. Hyprland reports 0.57.0 with matching
reported runtime library versions, wallust 3.5.2 and awww 0.12.1. The GI/NM
typelib import passed without constructing NM.Client. Kernel package remains
7.3.1-2; the running kernel ownership check passed before installation.

The package gate is accepted. This does not establish desktop configuration,
compositor launch, display/input, portals, audio, wallpaper, panel, logout UI,
or networking-control correctness. No graphical configuration has been applied
by these staging helpers. Source publication and package installation are not
full GUP certification.

## Networking decision before applying startup configuration

Observed state: networkd/resolved/wpa_supplicant@wlan0 are active/enabled,
NetworkManager is installed but inactive/disabled. Existing state stayed
unchanged through package installation and import probes.

The frozen candidate's `config/hypr/configs/Startup_Apps.lua` launches both
`nm-applet --indicator` and `nm-tray`. The key binding and Waybar network action
lead to `UserScripts/RofiNetwork.sh`, which constructs an NM.Client and consumes
NetworkManager connection objects. The read-only GI import test does not prove
this consumer works with networkd. Starting applets may request D-Bus activation;
do not use their launch as an incidental backend migration procedure.

Two coherent integration paths need a deliberate selection:

| Path | Required work | Acceptance and rollback boundary |
| --- | --- | --- |
| Retain networkd/wpa | Add an explicit backend dispatch; retain the existing NM path for NM systems; implement and test appropriate status/control behavior for the retained backend; avoid automatic NM applets on that backend | Demonstrate backend selection, status and intended control operations on Pi without changing active Wi-Fi ownership. Roll back only newly deployed files through their recorded backups; leave network services/configuration intact |
| Migrate to NetworkManager | Prepare an equivalent connection profile without exposing secrets, retain original network configuration privately, record interface/address/routes/DNS and enabled states, and prepare a bounded rollback before switching ownership | Perform the transition with local-console recovery available; never have two managers deliberately own wlan0. Require matching connectivity/DNS checks and working graphical consumer. On failed checks restore original service ownership and private configuration; verify connectivity before continuing |

The working backend is retained until this decision is resolved. Neither path
is represented as completed, and no transition command has been issued.
Do not transfer Wi-Fi passwords or private connection profiles in evidence.

## Other configuration work that can be prepared independently

1. Keep the original R7 checkout and all Pi refs/stashes unchanged. Use a new
   committed candidate or isolated deployment stage for integration changes;
   name the original R6/R7 rollback points and rerun the relevant semantic and
   integration gates after each change.
2. Inventory actual target binaries and user-owned configuration paths before
   deployment. Default startup includes `nm-tray` and `/usr/bin/mem-police`,
   which are not accounted for by the canonical package inventory or repository
   executable inventory. Actual target binary availability is not yet measured.
   User defaults also reference optional applications; distinguish an installed
   capability from an unresolved consumer rather than silently dropping it.
3. Reconcile first-start ordering. The entrypoint launches `initial-boot.sh`
   asynchronously; the Startup_Apps hook separately launches `4ndr0init.sh`.
   With a current wallpaper present and no daemon already running, first-boot's
   one-second delay can reach `awww query` before the initializer's portal sleeps
   and daemon startup complete. Its error path leaves the marker absent. Replace
   timing assumptions with explicit ownership/readiness while retaining retry
   and marker semantics; verify with adversarial ordering fixtures and live Pi
   evidence. This is a source-observed conditional race, not an observed Pi GUI
   failure.
4. Make a private, metadata-preserving manifest and backup of every destination
   before writing it. Stage the exact candidate configuration and validate Lua
   syntax/module graph and the installed compositor's actual configuration API.
   Avoid invoking the broad interactive installer as an implicit shortcut: it
   can change packages and run optional setup independently of this audit.
5. Apply only reviewed destinations, preserving user-owned additions and an
   exact restore map. Do not delete user backups or reset/clean any user repo.
   Configuration validation failure restores only files owned by the new
   deployment transaction and leaves the known-good network/backend untouched.

## Live graphical gate

Launch acceptance must run from the Pi's local graphical/console context and
record the exact candidate configuration, compositor version and commands.
Require no compositor configuration errors, usable monitor and input, terminal,
Waybar, queryable awww daemon and wallpaper, portals, PipeWire/WirePlumber,
working chosen network controls, and an interactive wlogout test without invoking
its power actions during smoke validation. Check desktop-to-service consumers
and service-to-desktop results, rather than inferring integration from imports.

Stop and restore the configuration transaction on a failed parse/module load,
unusable display/input, failed mandatory initializer, absent required runtime
owner, or changed network ownership/connectivity. Keep the TTY recovery path;
do not enable a display manager or make automatic GUI boot a prerequisite for
the first successful manual launch. Return command exits, logs and evidence
hashes plus the operator's explicit visual acceptance. Full certification stays
OPEN until these runtime and integration obligations have supporting evidence.
