# Wallust 3.5 native renderer compatibility

The Pi's private configuration stage `config-yttaccup` stopped at Wallust with
exit 1: `palette = "salience"` is not a valid Wallust 3.5.2 enum value.
The native Hyprland verifier was not invoked. The original Hyprland inventory
hash is identical before/finally, network state was observed after failure, and
no graphical session or live configuration replacement occurred.

The corrected value `saliencedark` is the canonical explicit dark salience
palette in the exact 3.5.2 upstream source. It retains the intended salience-based
dark palette behavior rather than changing palette families or migrating saved
user settings. No templates or installed package versions are changed.

The archived Pi failure was independently reproduced on the cloud host using
the upstream 3.5.2 x86_64-musl release. Its archive is pinned by SHA256
`92e11a841827ea6c2af28290d2cf4908db07dff4aee8dec1b7f1133cbf72c6e2`;
executable SHA256 is
`fc7de8a7082a918213e734226042be45f3e61a3e24879a37a3b5bb7f46fd4e77`.
These pins identify the HTTPS-delivered host test artifact; no independent
vendor signature or maintainer identity certification is inferred.

`tests/integration/test-wallust-native-render.py` executes that actual renderer,
first proving the invalid legacy name fails without generating output, then
rendering all seven active templates into a fresh private HOME/XDG profile.
Committed sample colors are removed from that disposable profile first, so
existing files cannot masquerade as generated output. Every output must be
nonempty, inside the private profile, and free of unresolved template markers.
A dedicated CI job downloads the checksum-pinned host renderer and runs this
gate when the rendering configuration changes.

This closes a missing native renderer/config/template gate in the previous
mock/syntax-heavy coverage. It does not prove ARM rendering, consumer-specific
syntax/behavior, the installed Hyprland Lua API, or GUI acceptance. The revised
Pi stager must acquire the exact corrected source into a new private checkout,
leave the previous source/profile/evidence intact, rerender on ARM, and continue
to the actual compositor verifier. Any failure remains fail-closed with no live
configuration replacement. Full GUP/runtime certification stays OPEN.
