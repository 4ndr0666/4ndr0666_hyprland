# Immutable bootstrap

The installer must not be executed from mutable `main` content.

`Distro-Hyprland.sh` is the sole bootstrap authority. It verifies the repository revision it installs, and `release.ref` records the approved release revision. The former `auto-install.sh` entrypoint was retired because it targeted the legacy `Arch-Hyprland` repository and represented a second, divergent bootstrap authority.

For a reproducible remote bootstrap, fetch the bootstrap script from an exact commit:

```bash
BOOTSTRAP_REF=f1468f500a14ef6ff25ff03ddee8a64044c96849
curl --fail --location --proto '=https' --tlsv1.2 \
  "https://raw.githubusercontent.com/4ndr0666/4ndr0666_hyprland/${BOOTSTRAP_REF}/Distro-Hyprland.sh" \
  -o /tmp/4ndr0666-hyprland-bootstrap.sh
bash /tmp/4ndr0666-hyprland-bootstrap.sh
rm -f -- /tmp/4ndr0666-hyprland-bootstrap.sh
```

The downloaded bootstrap then clones the repository at its pinned `release.ref` and verifies `HEAD` before executing `install.sh`.

Do not substitute `main`, a mutable tag, or an unreviewed commit for `BOOTSTRAP_REF` in unattended deployments.
