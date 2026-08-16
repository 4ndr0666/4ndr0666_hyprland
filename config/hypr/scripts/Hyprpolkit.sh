#!/usr/bin/env bash
# 4ndr0666
#                  #    === Hyprpolkitagent.sh === #
_ps=(polkit-gnome-authentication-agent-1 polkit-kde-authentication-agent-1 polkit-mate-authentication-agent-1 hyprpolkitagent)
for _prs in "${_ps[@]}"; do
	if [[ `pidof ${_prs}` ]]; then
		killall -9 ${_prs}
	fi
done

if [[ ! `hyprpolkitagent` ]]; then
	systemctl --user start hyprpolkitagent
fi
