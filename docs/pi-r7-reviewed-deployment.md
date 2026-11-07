# Reviewed Pi configuration deployment

This helper installs the profile prepared by deployment-preflight-1onofnfg,
manifest SHA256 acc275f9127ee54289298f40ed2ac320328af3574e1f79793a74e3996f676eba.
The separate graphical trial trial-optsx6t9 exercised its pinned runtime patches,
reported first-boot completion and empty configuration errors, and returned a
clean compositor exit. The user reported a clean screen without a Kvantum popup.

Run pi-r7-deploy-config.py as the normal Pi user from a local console after
logging out of the desktop. No repository checkout, sudo, package transaction,
service changes, or automatic graphical boot configuration is involved.
The helper validates the complete prepared profile and all 17 current destination
snapshots before installing. It stops if the original Hyprland files changed,
the formerly empty Kitty directory gained files, another destination appeared,
or a destination root is a symlink. It does not merge or guess about changed files.

Directories are prepared under a private .config/.gup-deployment-* transaction.
The original hypr and kitty directories are retained as backups there; other
roots were absent at accepted preflight. Intent is durably recorded before each
rename. Installation failure attempts restoration. Unchanged destinations can
be restored using the printed --rollback command. All destinations and backups
are checked before rollback; later user edits cause a stop preserving that state.
Failure or interruption evidence and transaction directories are retained.
A prior transaction blocks a second installation until recovery is reviewed.
Interrupted recovery can require manual review if the recorded state and disk
state differ; no unconditional crash-recovery guarantee is asserted.

The helper prints a configuration-installation evidence archive and SHA256,
recovery location, the manual Hyprland launch command, and exact rollback command.
Keep the helper and transaction until the persistent desktop is accepted.
On config errors, unusable display/input, failed startup ownership, or network
ownership/connectivity changes, log out to the console and restore the recorded
configuration transaction. Never remove shared packages or reset the user's repo
as rollback. Backups are never automatically deleted.

Tests cover exact restoration, injected failure after each of 17 replacements,
changed destinations, and later user edits. Cloud tests do not establish Pi
installation success or permanent-session runtime acceptance. Full GUP
certification remains open; notification MPRIS/backlight warnings, interactive
network controls, actual sound output and logout UI require bounded evidence.
