# Configuration-owned user tools

This directory is the canonical home selected by the user for these tools.
4ndr0pac frontend and sibling backend must be deployed together. The uploaded
pair and installer exactly match scr commit fa7320319676dbc690e89f25b8bae0dbb0afae5a:

- 4ndr0pac SHA256 81dc702b7d661f42cac3e123e64151b33cb28fa53d61cd79bdf6dcccbf4ded1f
- 4ndr0pac.sh SHA256 54107c7224f259f0124d735c4c2fabfcceb21866492f2f45a3e8e3a70edc8474
- install.sh SHA256 bb368a4207089d7d74a06ac4d318abe67ff8fb2d56ef39d707ac435d2ae36a54

The supplied install.sh targets /opt and /usr/local/bin, requires root and
references validation files not supplied in this import. It is preserved as
supplied installation-source material, not invoked by the Hyprland workflow.
The configuration-owned payload needs a separate user-local deployment path.

wl-media is the supplied Wofi media selector. wofi_media.sh is the requested
launch name; deployment must explicitly provide that alias rather than silently
invent another implementation. Its menu uses desktop-specific media directories
only when mounted and offers manual directory entry on other machines.
Dependencies: bash, wofi, socat, jq, mpv, notify-send, find, grep, sort and shuf.
Backend actions in 4ndr0pac require their own package-manager dependencies and
permissions. Frontend tests with a fake backend do not certify those actions.

Importing these sources does not install them or execute their system actions.
