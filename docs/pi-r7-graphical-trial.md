# Native configuration accepted; local-console graphical trial

The received `config-1dgn8av2.tar.gz` is pinned by user SHA256
`566a7931d6d68b81805a2bb7cabe00ac34f7e5ec21438f6125c0791d4942bcc0`.
All 32 internal hashes and 14 command streams verify; every command returned
zero. The Pi rendered the corrected Wallust configuration, and its installed
Hyprland explicitly printed `config ok`. Existing Hyprland inventory hashes
match before/after/finally. Source refs and network unit state stayed unchanged.

The config-only verifier also emitted an ANSI-colored Socket2 bind error. The
previous broad error regex did not recognize that colored prefix. The classifier
now strips ANSI escapes and requires the explicit parse verdict; all other error
diagnostics block. This particular config-only Socket2 diagnostic is separately
recorded as an open runtime obligation. It is not silently converted to proof
that real compositor IPC works. Native parse/API acceptance is accepted; runtime
IPC, monitor/input and service integration remain OPEN.

Run `scripts/pi-r7-graphical-trial.py` from the Pi's local virtual console as
the normal login user, outside an existing desktop. There are no flags, sudo or
manual edits. It rejects SSH, non-VT terminals, root, existing user compositors,
and existing graphical runtime owners that the candidate initializer could
otherwise restart. A refused precondition preserves existing processes and
returns evidence when a private capture has already been created.

The runner locates the exact accepted profile by the independently pinned
manifest SHA256 `e66ab1ef51c1688e6f476659aef5bca669af82cea317e9c4b2ba94b4c872d51f`,
checks every staged configuration file/link/mode against it, and copies it into
a new private trial HOME/XDG profile. It does not execute the earlier bare
`launch-trial.sh`, modify the accepted staged profile, replace default dotfiles,
install packages or enable services. The source candidate stays at
`4aa7b09ef44af0a98b4772be9ff2625318241029`.

It snapshots only WAYLAND_DISPLAY and XDG_CURRENT_DESKTOP from the real systemd
user manager into a private recovery checkpoint. Unrelated environment values
are read only in memory for filtering and never dumped into files/evidence.
Command argv/exits and stream hashes are recorded; environment-property command
streams are deliberately not retained. The recovery checkpoint is not included
in the returned archive. Existing live Hyprland file/link/mode inventories are
compared before/after the trial.

The trial starts the actual compositor through a fresh D-Bus session and a
private HOME/XDG profile. It runs for approximately two minutes, then requests
exit through the identified private instance; bounded cleanup follows. Try
Super+Return for a terminal and Super+N for network status, and inspect monitor,
pointer/keyboard, panel and wallpaper. Do not select logout-menu power actions
during the smoke test. After automatic return to the console, one optional
free-text prompt records what worked or failed; it explicitly requests no
passwords. A blank observation is not treated as visual acceptance.

The collector matches compositor instance PID to a process with the private
profile HOME. All subsequent IPC uses that signature and Wayland socket. It
records actual monitor/config-error IPC, awww query, wpctl status, owned session
bus names, private-profile runtime process names and first-boot marker state.
It does not capture clipboard databases, window titles, process argv, SSIDs,
credentials or screenshots. Failed runtime probes remain visible rather than
causing automatic repair. Audio status is an observational client request;
existing user socket activation can occur, but no service is enabled/disabled
by the runner. A successful parse/import or a captured sample is not proof that
all components, audio output, menu controls or portals work correctly.

Cleanup selects only same-UID processes with the exact fresh private HOME and
new process birth identities. It never kills a shared foreground group or uses
killall. PID reuse cannot redirect a cleanup signal. The two managed session
variables are restored and independently reread, including removal of variables
that were originally absent. Restoration is attempted even when process cleanup
fails. A pending recovery checkpoint survives a hard kill; a subsequent run,
after existing compositor/runtime-owner guards pass, restores pending checkpoints
before starting a new trial. SIGINT/HUP/TERM enter normal cleanup; SIGKILL/power
loss cannot guarantee immediate restoration. Raw private profile/recovery data
stay on the Pi, outside the archive.

The candidate's startup is real user-session work, not container isolation.
Network state must match before/after; failures hold permanent deployment. On a
failed display or IPC test, let the automatic return/cleanup complete and keep
the printed archive. Existing default configuration remains available. Do not
set a display manager or automatic graphical boot based only on this trial.

Return the printed archive and SHA256 together with the operator's visual
observations. Cloud tests cover cleanup/selection/recovery/data-retention
contracts, not the Pi's live graphics. Configuration deployment, bidirectional
runtime integration and full GUP certification remain pending until actual
trial evidence supports them.
