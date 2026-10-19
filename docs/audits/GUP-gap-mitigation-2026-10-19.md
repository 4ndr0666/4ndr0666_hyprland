# GUP gap-mitigation evidence — 2026-10-19

## Scope and baseline

- Repository: `4ndr0666/4ndr0666_hyprland`
- Base branch: `main`
- Baseline commit: `ffde2352d331f6cbbda460fd241882b13dc1b335`
- Work branch: `gup/gap-mitigation-rainbow-lua-autodispatch`
- Pull request: [#120](https://github.com/4ndr0666/4ndr0666_hyprland/pull/120)
- Baseline commit message: `feat(hypr-lua-strict): enforce Hyprland 0.55+ Lua IPC, universal monitor defaults, and authorized path retirements`

This record is append-only evidence for this remediation pass. It is not a full historical-continuity certification or a claim of live compositor validation.

## Findings and dispositions

### HYPR-001 — P1: Rainbow Borders advertised capability was not operational

**Observed:** the active `config/hypr/UserScripts/RainbowBorders.sh` path was absent. The remaining `RainbowBorders.bak.sh` file was an inert template, while Quick Settings treated it as a restorable implementation.

**Mitigation:** restored an executable active implementation for the existing `wallust_random`, `rainbow`, and `gradient_flow` modes. Border changes use the Hyprland 0.55+ `hl.config(...)` Lua IPC dispatcher; no legacy `hyprctl keyword` fallback is used. Unsupported modes fail closed. Quick Settings no longer promotes or deletes the archival `.bak.sh` template.

**Regression evidence:** `tests/unit/test-rainbow-borders-runtime-contract.sh` runs all three modes against a stub `hyprctl`, verifies exactly one Lua IPC update per mode, rejects deprecated keyword IPC, and verifies an unsupported mode makes no compositor call.

### HYPR-002 — P2: Autodispatch cleanup was only statically asserted

**Observed:** the previous lifecycle unit checked source strings but did not execute a failure path.

**Mitigation:** expanded `tests/unit/test-autodispatch-lifecycle.sh` with a mocked compositor that accepts readiness and the global temporary rule, then deliberately rejects the first narrow capture rule.

**Regression evidence:** the test asserts the script exits non-zero and issues `set_enabled(false)` cleanup dispatches for both the global and named narrow temporary rules.

### HYPR-003 — P2: Lua parser could be absent without failing the test

**Observed:** the previous test skipped Lua syntax parsing when neither `luac` nor `texluac` was installed.

**Mitigation:** parser absence is now a hard failure. The test prints the selected parser version and parses every required Lua module. Both Golden Unit workflows install `lua5.4` before running the suite.

## Verification evidence

At work-branch commit `7ba63845c4ed98fca1f990522994169f482e4490`:

- [Golden Unit Protocol run #1451](https://github.com/4ndr0666/4ndr0666_hyprland/actions/runs/39206850014): **99 total, 0 failed**.
- [Core Shell Contracts run #94](https://github.com/4ndr0666/4ndr0666_hyprland/actions/runs/39206849965): ShellCheck and the registered Golden Unit suite passed; **99 total, 0 failed**.
- Lua syntax parser reported **Lua 5.4.6**.
- Rainbow Borders runtime-contract unit passed.
- Autodispatch injected-failure cleanup unit passed.
- Full Golden Unit runner reported `All Golden Units passed.`

The workflows use mocked compositor boundaries for the new behavior tests. They do not launch a live Hyprland session.

## Remaining limitations / gate status

- Universal monitor fallback remains runtime-unverified against a live Hyprland 0.55+ compositor.
- Full GUP historical path/blob continuity certification remains blocked until a complete canonical Git object database is available to the continuity tool. Remote commit/CI evidence is not substituted for that requirement.
- The PR is not merged. No changes were made to `main`.
- No claim is made that the remediation is a self-verifying update kit or that an Engineering-skill release certification has been completed.

## Change inventory

- `.github/workflows/golden-units.yml` — provision Lua parser.
- `.github/workflows/core-shell-contracts.yml` — provision Lua parser for the second workflow that invokes Golden Units.
- `config/hypr/UserScripts/RainbowBorders.sh` — restore executable active behavior.
- `config/hypr/scripts/4ndr0666_Quick_Settings.sh` — reject inert backup fallback and preserve the archive.
- `tests/unit/test-rainbow-borders-runtime-contract.sh` — new behavior regression unit, registered in the Golden Unit runner.
- `tests/unit/test-autodispatch-lifecycle.sh` — add deterministic injected-failure cleanup coverage.
- `tests/unit/test-lua-config-superset-integrity.sh` — require and report Lua parser.
