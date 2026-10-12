# GUP Candidate Configuration Comparison — 2026-10-12

## Scope and evidence identity

This comparison is deliberately non-destructive. The uploaded machine archive is a candidate baseline, not a canonical source for wholesale adoption. No installed configuration was changed.

- Remote comparison baseline: `e7361adb47c462d7978e9c45a393942302acd1f1`
- Remediation branch: `fix/gup-core-script-contracts-2026-10`
- Uploaded archive: `4ndr0666_hyprland-config.tar.gz` (GNU tar archive; 857 members)
- Comparison rule: Git blob SHA-1 is computed over the exact file bytes using Git's `blob <length>\0<content>` framing.
- The branch's current PR #115 source files below match the stated remote baseline; the audit documentation itself was later added to the branch.

## Three-way blob ledger

| Path (archive-relative / repository-relative) | Uploaded machine blob | Remote baseline blob | Result |
|---|---|---|---|
| `hypr/hyprland.lua` | `775175b9c1fa0b15f68d9f3c0d58498ef2b155d1` | `775175b9c1fa0b15f68d9f3c0d58498ef2b155d1` | Exact match |
| `hypr/UserConfigs/UserSettings.lua` | `e04644c6ac99396dc5063db9a83d410cb83a543c` | `e04644c6ac99396dc5063db9a83d410cb83a543c` | Exact match |
| `hypr/UserConfigs/UserKeybinds.lua` | `575f77f612ab86809b07160b0d12b9dcaa208ecb` | `5157d2ffeec77e0b02b15dcd83efd952e0a77311` | Divergent |
| `hypr/UserConfigs/UserAnimations.lua` | `05446320202335a5c596f0d69fd4b2ce53b5529b` | `261b9338cfe4f510819222679572ab56a4217deb` | Divergent; same effective setting |
| `hypr/UserConfigs/UserDecorations.lua` | `886770977496a933ec8b82da1252bc22bd0a460a` | `27344fa0fab8d70ef2fcc6db6680406e384a17b2` | Divergent; machine candidate supplies fallback colors |
| `hypr/UserConfigs/WorkSpaceRules.lua` | `05442ebeea06fe7cd745389262d61fe30a0450f1` | `dc76db35e9ff7a42b1a653f54005684486b762be` | Divergent; machine-specific monitor assignments |
| `hypr/Monitor_Profiles/default.lua` | `f549e8ff2238496703e4deaf8880edccec143e65` | `071d2c1cb3342616d56d80ba9a479f3d051dc598` | Divergent; machine candidate has three empty-output monitor declarations |
| `hypr/UserScripts/4ndr0init.sh` | `9b79f4a47fe15ea2bbf54b182e85d2bd3109d850` | `cd4c6b86f499e2068cc306f5b3cc9dc4a367f297` | Divergent; lifecycle behavior changes materially |

## File-level findings and dispositions

### 1. UserKeybinds.lua — preserve behavior pending an explicit selection

Both versions use the same general Lua binding style and both contain the workspace/layout control section. The changed application actions are not merely formatting:

- F2: machine candidate launches `lf`; remote launches `yazi`.
- F6: machine candidate launches `~/.local/bin/vidcut`; remote launches `/sbin/vidcut` and adds Shift+F6 for LosslessCut.
- F7: machine candidate runs `bash jdownloader`; remote invokes `jdownloader` directly.
- Shift+F8: machine candidate runs `4ndr0pac`; remote runs `/usr/local/bin/trigger_oom.sh`.
- Shift+F9: machine candidate has a Dorkmaster binding; remote has no corresponding binding.
- F10: machine candidate invokes `~/.local/bin/mpvplay`; remote invokes `mpv`.

The remote variant therefore removes Dorkmaster and changes the package/path contract for several bindings. No automatic adoption is justified by the word “trivial”; keep this file unchanged until the per-binding disposition is approved.

### 2. UserDecorations.lua — machine behavior is preferred, but its color-provider path is stale

The machine candidate preserves the same decoration values as the remote version and adds two resilience behaviors: it ignores values that still contain an unrendered template marker and supplies fallback colors when color keys are missing. The remote version fails loudly if the provider file is absent or any of four required colors are missing.

However, the machine candidate reads `~/.config/hypr/wallust/wallust-hyprland.lua`, while the uploaded `wallust/wallust.toml` explicitly generates `~/.config/hypr/wallust/wallust-hyprland.conf`. The archive also contains a Lua-named color file, but it is not the configured Wallust target. Blindly adopting the local file unchanged would preserve fallback behavior while risking stale colors. Recommended reconciliation: retain the machine candidate's template filtering and fallback semantics, but read the configured `.conf` target; add a test proving generated `rgb(...)` values are parsed and template placeholders are ignored.

### 3. WorkSpaceRules.lua — do not promote hardware identifiers to universal defaults

The candidate adds odd/even workspace assignments tied to two exact monitor descriptions and a scratchpad gap rule. The monitor assignments are machine-specific and are not needed for universal behavior. The repository's generated `monitors.lua` and `workspaces.lua` already configure those same two monitor descriptions and workspace 1–10 placement.

The call shape `hl.workspace_rule({ workspace = ..., monitor = ..., default = ... })` is consistent with the existing generated `workspaces.lua` usage. Preserve the generic API contract, omit the two-device policy from the universal baseline, and separately decide whether the scratchpad gap rule is a generally desired default. No machine-specific monitor IDs should be promoted without evidence they are intended for all hosts.

### 4. Monitor_Profiles/default.lua — API call shape is recognizable; selectors are not valid evidence

The candidate contains three calls of the same shape used by repository `monitors.lua`: `hl.monitor({ output = ..., mode = ..., position = ..., scale = ... })`. This confirms the argument structure is consistent with repository usage, but does not prove undocumented API semantics beyond that usage.

All three candidate declarations set `output = ""`, with modes `preferred`, `highrr`, and `highres`. These declarations do not identify a physical output, and the three competing records are not a deterministic universal monitor profile. The profile README says profiles are selected by the profile menu and recommends unique names rather than `default.lua`; the main config independently loads generated `monitors.lua`. Recommendation: do not adopt these three declarations. Keep a neutral/no-op profile or make profiles explicit per output, and test profile selection/reload end-to-end before changing the monitor API contract.

### 5. UserScripts/4ndr0init.sh — remote variant is the intended candidate, not yet deployable

The machine candidate stops Waybar and Mako, then launches portals. It also contains the standalone command `DBUS_SESSION_BUS_ADDRESS`; under `set -e`, that attempts to execute a command of that name and can terminate the script before environment import.

The remote candidate removes that command and adds managed startup of `awww-daemon` and Waybar, readiness polling for `awww query`, and rollback of child processes on a non-zero exit. Startup order is: D-Bus validation/repair → environment import → stop existing portal implementations → Hyprland portal → generic portal → awww daemon/readiness → Waybar. The repository's `configs/Startup_Apps.lua` calls `4ndr0init.sh` from `hyprland.start`, so this is an active runtime path.

Remaining validation before deployment:
- Confirm required executables/packages exist on the target (D-Bus utilities, portal implementations, `systemctl --user`, `awww-daemon`, `awww`, Waybar).
- Confirm `WAYLAND_DISPLAY` and `XDG_CURRENT_DESKTOP` are populated at hook time.
- Exercise failure injection at each startup stage and verify rollback leaves no newly started child behind.
- Verify the readiness contract for portals and Waybar; the script currently checks process survival after a short delay, while only awww has an explicit query check.
- Run O.M.A.-1 after installation; do not run O.M.A.-2 until O.M.A.-1 passes.

No deployment or runtime claim is made by this source comparison.

## Current gate

PR #115 remains open and draft. The host's last recorded O.M.A.-1 evidence has wallpaper and Waybar runtime failures; O.M.A.-2 remains blocked. This comparison adds source-level evidence only and does not resolve those runtime gates.
