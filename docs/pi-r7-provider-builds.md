# R7 provider reconciliation on Arch Linux ARM

The verified `predeploy-uhpsixb2` capture establishes the running/installed
7.3.1-2 kernel match, exact R7 source and tree, clean refs, installer dry-run,
and a successful cached full package transaction preview. `awww` is available
from the Pi's configured `extra` repository as an AArch64 package. The metadata
query's exit 3 names exactly three absent sync packages: Victor Mono, wallust,
and wlogout. It does not invalidate the separate successful transaction preview.

Two upstream AUR recipes reject AArch64 in their declared architecture lists.
That is an eligibility failure, not evidence that the upstream programs cannot
build on ARM. It is also not permission to use makepkg's architecture bypass.

`scripts/pi-r7-build-providers.py` is the separate, single-file next step. Run
it on the Pi as the normal login user, with no flags or sudo prefix. It creates
a fresh private build workspace and preserves existing checkouts and settings.
It verifies all source hashes and the wlogout release signature before offering
any privileged transaction. Its sole privileged command is `sudo pacman -Syu
--needed -- ...` for declared build dependencies, with pacman's usual review and
confirmation. It can upgrade the base system; this step is **not read-only**.
It does not deploy desktop configuration, install the resulting three provider
packages, invoke yay, enable services, migrate networking or reboot.

The helper builds three local packages, with distinct decimal pkgrel suffixes:

| Package | Reviewed origin | Local changes |
| --- | --- | --- |
| wallust 3.5.2 | AUR `ba46ab88a1129565a6c13adca0455b1f43fffbad` | Explicit AArch64 target; single-job Rust build; release LTO disabled to reduce peak memory; original themes/doc features, lockfile and installed files retained |
| wlogout 1.2.2 | AUR `9904ef2a49026b70e5288965423ee503c95f09cd` | Explicit AArch64 target; SHA256 replaces MD5; original signing fingerprint retained and signature checked in a private keyring; standard Arch Meson build helpers and single job |
| Victor Mono 1.5.6 | AUR `633e9521fe99b748ebfc2d914f8351d3316c6faf` | Same source hash and font payload, quoted paths, install upstream license omitted by original recipe |

Wallust and Victor Mono source SHA256 values match the captured AUR recipes.
Wlogout's downloaded source also matches the original MD5, and its detached
signature verifies against the full fingerprint pinned by that AUR commit:
`F4FDB18A9937358364B276E9E25D679AF73C6D2F`.
The added SHA256 values pin those reviewed bytes. This provides integrity and
signer-key continuity; it is not an independent identity certification for the
maintainer. Wallust and the font have no independently verified vendor signature.

Builds use a private Cargo cache, a controlled makepkg configuration with
system compiler defaults, and fresh directories. No `--ignorearch`, `--skipinteg`,
`--skippgpcheck`, automatic provider installation, or AUR helper is used.
Cargo downloads locked dependencies, verifies their registry checksums and
builds frozen afterwards; upstream build scripts execute as the login user.
This is a normal native user build, not a container security boundary.
Minimum free disk is 6 GiB and available RAM plus swap 2 GiB. Failure stops
before the dependency transaction when those resource gates fail. No swap file
is created automatically. Logs remain visible while long builds run.

Package checks require the expected package names/architectures and actual
AArch64 ELF machine headers. Wallust's native version command runs from its
staged package. Wlogout initializes GTK before parsing even `--version`, so its
launch test remains a live graphical-session gate. Builds and metadata checks
cannot establish functional or semantic equivalence on the Pi.

The returned evidence archive contains exact commands/exits, captured stream
hashes, source/recipe pins, package SHA256 values and paths, and before/after
package and service state. It excludes source trees, Cargo cache, keyring and
built package archives. Executable extraction records its full hash and retains
only the ELF header in the evidence. Packages remain in the printed workspace.

Stop conditions are a source/signature mismatch, failed dependency transaction,
build failure, changed network unit state, unexpected package identity/architecture,
or invalid ELF header.
No deployment follows any failure. Do not disable checks to proceed. If pacman
updates the kernel, normal reboot and matching kernel/module evidence are
required before deployment. If connectivity or boot regresses, stop subsequent
work and use the known-good recovery image or a reviewed coherent package
rollback; do not blindly uninstall shared build dependencies or downgrade an
isolated library. Saved package inventories support that review; they do not
constitute an automatic system rollback facility.

The existing networkd/resolved/wpa_supplicant backend remains in use. RofiNetwork
still consumes NetworkManager and that integration remains OPEN. No complete
GUP certification is claimed. The next milestone is the native build evidence
archive, followed by provider installation/configuration and live runtime gates.
