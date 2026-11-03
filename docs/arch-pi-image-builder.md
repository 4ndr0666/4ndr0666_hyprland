# Arch Pi image builder

Run the new standalone file from a terminal:

```bash
sudo bash ./install_arch-pi4.sh
```

Choose Create image. The menu finds or downloads the rootfs, prepares sign-in,
validates and creates a new image, then offers a separate card-write step.
It uses fzf when available and a numbered menu otherwise. `--help` lists common
commands before advanced flags. Renaming the script is supported.

Plain Arch Linux ARM is the default. No Git bundle, GUP checkout, GI provider
or NetworkManager transition is required for this profile. It creates a
customized OS foundation with SSH, local authentication and optional Wi-Fi.
It does not install the repository's desktop configuration. The supported
input envelope is compatible Raspberry Pi AArch64 rootfs and recognized
cmdline.txt/boot.txt layouts; each exact model/rootfs still needs a boot test.

## Settings and credentials

Settings saves Wi-Fi, storage, image size and source profile. Wi-Fi passwords
are private mode0600 files, reused on subsequent burns. Blank password entry
keeps the saved password only for the same SSID, without creating another copy.
The session JSON stores paths, not plaintext passwords. Ethernet-only clears
the active Wi-Fi selection; old credential files are retained privately and
are not silently deleted. Images also contain credentials and are mode0600.

The revised tool uses `~/.local/state/arch-pi` (XDG_STATE_HOME for a normal-user
launch). It imports a previous `gup-pi4/session.json` once by copying settings,
preserving the old tool's settings, credentials and selected profile. Choose
Settings → Image profile → Arch Linux ARM to switch an imported GUP profile.
The old tool/file is not overwritten or invoked by this file.

## Optional source recovery

Settings offers GUP R6/R7 as optional source-recovery profiles. A conventional
local bundle or complete known split pair is used when available. Otherwise
the tool fetches the exact pinned commit from the HTTPS GitHub repository,
verifies commit, tree and full object integrity, and makes an offline cache
automatically. A later run reuses its recorded cache hash. No moving branch
tip can substitute for a missing pin. A failed fetch offers a local bundle
picker or returns to the menu. `--plan` stays read-only and requires local
inputs rather than fetching or creating credentials.

R6 is commit `8dbe1e8219c45a4bd00c26425e4867da901e88eb`, tree
`ec8e797f4387db48c3c6669ed1d83f2d08b41a0b`. It was not published when this
candidate was prepared. Publishing the separate recovery/r6 ref requires owner
authorization. R7 remains an unpublished source-tested candidate, with runtime
and backend alignment still open. This utility's publication does not publish
R7. Offline bundles remain optional recovery media, not normal-user chores.

## Effects and rollback

The host does not install packages or execute rootfs binaries. Build creates a
new sparse image and temporary loop/mount resources; existing outputs are refused.
Failed cleanup retains evidence/resources and stops. TLS verification remains
enabled, mirror failures use separate partial files, and inputs are hash checked.
First-download hashing is a first-use pin, not an independent vendor signature.

Physical card writing is separate and requires the exact typed device name.
Mounted, swap, mapped, read-only and undersized targets are refused. The exclusive
descriptor and authorized identity must match before signature erasure; wipe,
write, flush, readback and partition reread use the held device. Refuse on any
identity/state change, signature failure, short write or readback mismatch.
No automatic retry, discard, force-unmount, resize or reboot occurs.

Signature cleanup uses the host's `libblkid.so.1` (Arch: `util-linux-libs`,
already a dependency of util-linux). A bounded Python child receives the held
descriptor and calls the library's existing-descriptor API. It does not run
`wipefs`, reopen the device path, release exclusivity, or use `--force`.
The copy position is reset to byte zero after cleanup. Earlier regular-file
tests did not model Linux block-device exclusive-open conflicts; they cannot
establish physical-device correctness. Native tests now cover GPT headers,
stale backup GPT, idempotency, replaced paths, write failures and timeouts.

Before build failure, retain the existing card and diagnose the saved evidence.
After flash failure, do not boot or accept the card; use the separately retained
recovery image/card if needed. Stop target acceptance on boot failure, lost SSH
or networking, missing administration access, or failed package/runtime checks.
Card erasure is inherently irreversible; local passing tests are not a rollback.

The explicit target upgrade helper is `arch-pi-upgrade-base --apply` for plain
Arch, `gup-upgrade-base --apply` for GUP. Neither runs automatically. Installing
a desktop and switching networking remain separate operator-authorized actions.

## Verification

```bash
bash -n install_arch-pi4.sh
python3 -B -m unittest discover -s tests/pi-image -p 'test_*.py' -v
```

CI invokes these exact non-destructive checks. Tests include actual local Git
fetch/bundle/clone/fsck, terminal startup, authentication generation and a real
wipefs inherited-descriptor test on an ordinary temporary file when tools exist.
Rootfs/build/device providers are fixtures. No physical block device is used.
Actual vendor-rootfs build, block-device exclusivity/ioctls, Pi boot, SSH/Wi-Fi
and desktop acceptance remain runtime gates. No full GUP or Pi certification is
claimed. Publication approval and successful wire retrieval remain delivery gates.
