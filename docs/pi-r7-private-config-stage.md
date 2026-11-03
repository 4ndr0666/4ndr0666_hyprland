# Private Pi configuration staging

`integration-raiih15h.tar.gz`, SHA256
`4536496266d9c9252e734f5e0e9dab5ff5e03d1e2d12280ff08c78cd105849f6`,
verifies all 30 internal hashes and 14 successful commands. It establishes the
exact integration source/tree and object integrity, clean refs, running kernel
7.3.1-2, required binaries and actual unprivileged wlan0 control-socket access
with state COMPLETED. networkd remained active and unchanged; NM remained
inactive. DRM nodes are accessible in this capture, and the session type is tty.
Those facts do not establish a working graphical session or safe deployment of
the full configuration. The existing Hyprland directory is preserved.

The installed Hyprland help explicitly supports `--verify-config --config FILE`.
`scripts/pi-r7-stage-config.py` therefore creates a fresh private profile under
the existing GUP state directory, copies the pinned candidate configuration,
renders Wallust colors using the installed native binary, and invokes the
installed compositor's real verifier. It does not mock hl APIs or treat a Lua
syntax check as proof of API compatibility.

The first Pi stage `config-yttaccup` stopped at the real renderer: Wallust 3.5.2
rejects the legacy palette name `salience`. Hyprland verification was not reached;
the original Hyprland inventory stayed identical. The corrected source candidate
is `4aa7b09ef44af0a98b4772be9ff2625318241029`, tree
`15d0d36d295aeffab8f6e3f271bfca225616a329`. It selects the supported dark salience
palette `saliencedark` without changing templates. A real host Wallust 3.5.2 test
now renders all seven outputs and rejects the old palette as a negative control.
That host evidence does not substitute for the Pi's native rerun.

The revised stager automatically clones the corrected candidate into its new
private workspace when previous captures contain the earlier source. It verifies
commit/tree and strict object integrity; it never resets or checks out over a
previous capture. No manual Git checkout, file edit, bundle or reinstallation is
required. Previous failed profile/evidence remain intact.

HOME and all XDG configuration/cache/data/state locations point into that private
profile for renderer/verifier commands. Absolute, dangling and escaping source
symlinks are refused. Wallust targets must stay under the profile's `.config`.
User Hyprland file/link/mode inventories are hashed before/after; only inventory
hashes enter the report. No user settings are copied into the trial profile,
replaced or deleted. Original source refs and network unit state must remain
unchanged. Existing profile, source and build directories are retained.

A failed renderer/native verifier stops without preparing a launch command.
Recognized error diagnostics also block a zero-exit verifier. Logs, exact
commands/exits and stream hashes remain available in the returned archive.
The archive excludes profile contents and source trees; a successful stage adds
a profile manifest and a local-console launcher. No sudo, package transaction,
network operation, broad desktop installer or graphical launch runs at staging.

After accepting the native verification evidence, the prepared launcher can be
used from a local Pi virtual console for an isolated-profile graphical trial.
It refuses SSH/nested terminal use, root, or an existing detected compositor.
It supplies the private HOME/XDG profile and a fresh D-Bus session, while retaining
the real user's seat/runtime context. The candidate's normal startup hooks then
run: the initializer publishes Wayland environment to the user manager and owns
portal, wallpaper and panel startup. A trial is real runtime work; private HOME
does not make it a separate UID/container or isolate shared user-manager state.
No persistent network ownership or system boot/display-manager policy changes
are requested. That launcher is prepared, not automatically executed.

On staging failure retain the archive/profile and review the actual API or
template diagnostics; no live-dotfile rollback is needed because no replacement
occurred. Do not bypass errors or invoke the broad installer. A graphical trial
failure returns to the local TTY without making the trial profile the default;
preserve its logs and restore any shared user-manager session environment as
part of runtime cleanup before resuming another graphical session. Permanent
deployment remains a separate metadata-preserving backup/restore transaction
after graphical acceptance. No full runtime/GUP certification is claimed.
