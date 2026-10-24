# Mandatory graphical runtime deployment

The graphical runtime initializer is mandatory infrastructure, not an optional styling choice. The standard installer runs `install-scripts/graphical-runtime.sh` after optional installer selections so a user can decline the preconfigured visual dotfiles without silently losing the runtime startup connection.

The deployment step:

- installs or updates only the owned `UserScripts/4ndr0init.sh` file and ensures it is executable;
- preserves an existing `configs/Startup_Apps.lua` and adds only the initializer hook when missing;
- preserves the existing `hyprland.lua` and idempotently adds the `source("configs.Startup_Apps")` loader at a known module boundary;
- uses the canonical file-state backup manifest for replacements;
- fails closed when the current Hyprland entrypoint is missing or incompatible instead of claiming the runtime is deployed.

It does not start or repair services. After updating the repository, run the targeted deployment from the repository root:

```bash
bash install-scripts/graphical-runtime.sh
```

Start a fresh normal Hyprland session before running graphical certification. Certification remains read-only and must not be used to perform deployment or remediation.
