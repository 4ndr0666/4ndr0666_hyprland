# Install the reviewed R7 package set

The `providers-od74bnb2` evidence archive is pinned by user-supplied SHA256
`b613936ffbbd110e3db212051e08ae52922e1797c345cf49764305eac07d272e`.
Its 34 internal hashes and all retained command streams verify. All 24 commands
returned zero. Wallust and wlogout built as actual AArch64 ELF64 executables;
wallust ran natively as 3.5.2. Victor Mono built as architecture `any`.
Observed network unit state and kernel 7.3.1-2 remained unchanged.

The captured package-info streams contain all repeated dependency entries.
The build helper's initial report flattened repeated metadata keys to their
last value; that report formatting is now fixed. The built package contents
and dependency declarations are unaffected. The stream logs, rather than the
flattened report fields, remain the complete metadata evidence for this capture.

Run `scripts/pi-r7-install-packages.py` as the normal Pi login user, no flags.
It finds the existing exact R7 readiness checkout and the three locally built
archives by pinned names and SHA256 values. It verifies source/tree/manifest
identity, clean state, running kernel module ownership and the observed network
backend before any privileged action. It preserves all existing source refs,
stashes, user configuration and build archives.

The helper previews the cached sync transaction, then offers two ordinary pacman
transactions: a full upgrade plus the 59 canonical packages available from sync
repositories, followed by installation of the three reviewed local packages.
Both retain pacman's normal confirmation. Declining or failure stops the script.
There is no AUR helper, architecture bypass or signature policy override.
The script pins the locally built bytes; sync versions follow the configured
signed repositories at execution time. The cached preview can change when the
full upgrade refreshes repository metadata; review the actual pacman proposal.

NetworkManager may be installed as a dependency of network-manager-applet.
It must remain inactive and disabled; no service enable/start command is issued.
Existing networkd/resolved/wpa unit state must remain unchanged after each
transaction and after the headless probes. If package hooks change that state,
the helper stops for review instead of trying to take over connectivity.
GI/NM testing imports the typelib only; it does not construct NM.Client or
request D-Bus daemon activation. This is dependency evidence, not proof that
RofiNetwork works with the retained backend.

The helper checks all 62 canonical package names, installed CLI versions and
GI/NM import, then returns exact command/exits/stream hashes and package/service
inventories in a compact evidence archive. It never invokes the desktop
installer, copies dotfiles, enables a display manager, migrates networking or
launches a graphical session. Wlogout still requires live GTK/display acceptance.

Stop on any identity/hash mismatch, dirty checkout, kernel mismatch, transaction
failure, changed backend state or failed probe. Package transactions are separate
checkpoints: a failed second transaction does not undo the first. Keep the
printed logs and reviewed package archives. Do not launch/configure the desktop
after failure or blindly remove shared dependencies. Restore the known-good
image if boot/connectivity regresses, or review a coherent package rollback
against the before/after inventories and available cache. No automatic destructive
rollback is attempted. A kernel upgrade must be reconciled by normal reboot and
module-ownership verification before subsequent desktop deployment.

Package completion is not R7 deployment or GUP certification. The next milestone
requires this Pi installation evidence. Desktop configuration, the networkd /
NetworkManager consumer mismatch, bidirectional integration and live graphical
acceptance remain OPEN.
