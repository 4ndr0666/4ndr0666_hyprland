# GUP Semantic Capability Connectivity Contracts

**Date:** 2026-09-06  
**Baseline:** `09077d0eb9fd1eb3be1ebd0b1202f634b3b3c1b1`  
**Purpose:** close the semantic/architectural coverage gaps identified by the capability-to-observable audit.

This artifact records the concrete integration edges protected by the new Golden Units. It does not infer runtime equivalence from filenames or file counts.

## Rofi

**Authoritative implementation:** `config/rofi/config.rasi` and `config/rofi/themes/saint-rofi.rasi`.  
**Integration edge:** authoritative Hyprland Lua launcher binding → Rofi invocation → deployed Rofi root configuration → authoritative theme.  
**Observable:** the application launcher invocation remains connected to a valid Rofi configuration and theme graph.

**Golden Unit:** `tests/unit/test-rofi-runtime-connectivity.sh`.

## SwayNC

**Authoritative implementation:** `config/swaync/config.json` and `config/swaync/style.css`.  
**Integration edge:** session notification configuration → SwayNC styling → refresh path → notification-producing runtime scripts.  
**Observable:** notification and control-center behavior remains connected to the deployed SwayNC configuration.

**Golden Unit:** `tests/unit/test-swaync-runtime-connectivity.sh`.

## Kitty / Ghostty

**Authoritative implementation:** `config/kitty/kitty.conf` and `config/ghostty/ghostty.config`.  
**Integration edge:** terminal selection/keybind → transactional Kitty deployment and terminal-specific Ghostty deployment → user configuration destination.  
**Observable:** terminal configuration remains reachable through the supported deployment and launch paths.

**Golden Unit:** `tests/unit/test-terminal-config-connectivity.sh`.

## Monitor profiles / user configuration

**Authoritative implementation:** `config/hypr/Monitor_Profiles`, `config/hypr/UserConfigs`, and the corresponding copy reconciliation helpers.  
**Integration edge:** installed-state detection → transactional deployment → backup overlay/reconciliation → restored user/profile state.  
**Observable:** user-selected monitor profiles and configuration overlays remain connected across update operations.

**Golden Unit:** `tests/unit/test-monitor-user-config-connectivity.sh`.

## Assets / wallpapers

**Authoritative implementation:** repository `assets/` and `wallpapers/` trees plus the copy/deployment transaction.  
**Integration edge:** repository assets → destination resolution → deployment/preservation path → runtime consumer state.  
**Observable:** wallpapers and preserved wallpaper-effect state remain reachable after deployment.

**Golden Unit:** `tests/unit/test-asset-deployment-connectivity.sh`.

## Architectural constraint

These contracts are deliberately edge-oriented. A capability is considered protected only when the source, integration path, and externally meaningful destination/result are identifiable. A test that merely counts files, checks directory existence, or matches an implementation name is not sufficient.

The contracts supplement C30/C31/C37/C38/C44/C45 rather than replacing them. C45 remains the superset invariant: the supported capability set after deployment must contain the supported capability set of the previous stable baseline unless an intentional retirement is explicitly recorded.
