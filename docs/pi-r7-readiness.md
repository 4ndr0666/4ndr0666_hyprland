# Rebuilt Pi: R7 source and package readiness

This is a project-specific read-only step, separate from the general Arch image
builder. Run `python3 -B scripts/pi-r7-readiness.py` on the rebuilt AArch64 Pi as
the normal login user. No flags, sudo or hand-written setup files are required.

The script verifies that the running kernel has a module directory owned by the
installed linux-aarch64 package. A reported reboot is not treated as that proof.
A failed kernel gate stops before source acquisition or package resolution.

It creates a new private workspace under `~/.local/state/gup-r7`, clones the
published source candidate branch `gup/r7-bash-quote-scope`, detaches at
`5f97fdf336142241ebe5641db1c74ce2f907105b`, and verifies tree
`ef92e2c255b74a0ddde2cb293b4c0a1f7dc3bcdb`, full object integrity and clean state.
No existing checkout, refs, stash or user configuration is altered. The reviewed
candidate remains source-only; publication is not Pi runtime certification.

The installer is invoked only with `--dry-run`, whose pinned early exit performs
syntax/module checks. The normal installer is not invoked: it can change packages
before its confirmation and is outside this readiness step.

From the pinned canonical package manifest, the probe checks installed packages
and cached sync metadata. `pacman -Sup --needed --print-format ...` previews a full
upgrade plus missing available packages, with no refresh, download or installation.
Configured repository names and architectures remain visible; a custom repository
is not silently classified as official. Reported `%s` values are download sizes,
potentially zero for cached archives, not installed sizes or full archive sizes.

Missing AUR-group names are first checked against configured sync repositories.
Remaining AUR names get RPC metadata and a pinned shallow bare source clone;
`.SRCINFO` architectures and PKGBUILD contents are captured for review. No AUR
build code is sourced/executed and no architecture bypass is used. A missing or
unsupported provider blocks readiness. AUR source eligibility still requires
review of the captured commit before an installation plan is approved.

networkd/resolved/wpa_supplicant are observed but never changed. The existing
RofiNetwork consumer requires NetworkManager; that remains an explicit open
integration issue even when dependencies resolve. No implicit backend migration.

The final private `.tar.gz` contains command argv/exits, stream hashes, package
plan and AUR source text. It excludes the working Git repositories and contains
no SSH keys, Wi-Fi/password files or environment dump. The workspace and source
are retained for the next controlled step; reruns make new captures and preserve
previous ones. Return the printed archive and SHA256 for evidence reconciliation.
Exit0 means preview completed for review, not installation approval. Blocked
gates return1; interruption130; wrong host/root invocation20.

Hardware, boot, graphical runtime, complete package/provider alignment and full
GUP certification remain separate evidence boundaries. No self-applying update
kit or system-changing installation is issued by this script.
