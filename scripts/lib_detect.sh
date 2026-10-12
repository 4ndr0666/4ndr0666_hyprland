#!/usr/bin/env bash
# === 4ndr0666 === #
# Detection and environment adjustment helpers shared by copy.sh.

# Nvidia tweaks: uncomments envs and adjusts hardware cursor setting.
detect_nvidia_adjust() {
  local log="$1"
  local hardware_info

  if hardware_info="$(lspci -k)"; then
    :
  else
    local rc=$?
    printf '%s\n' "${ERROR:-[ERROR]} Unable to inspect PCI hardware (lspci status $rc)." >&2
    return "$rc"
  fi

  if grep -A 2 -E '(VGA|3D)' <<<"$hardware_info" | grep -iq nvidia; then
    printf '%s\n' "${INFO:-[INFO]} Nvidia GPU detected. Setting up proper env's and configs" | tee -a "$log"
    append_lua_env "LIBVA_DRIVER_NAME" "nvidia"
    append_lua_env "__GLX_VENDOR_LIBRARY_NAME" "nvidia"
    append_lua_env "NVD_BACKEND" "direct"
    append_lua_env "GSK_RENDERER" "ngl"
    set_lua_assignment "config/hypr/configs/SystemSettings.lua" "no_hardware_cursors" "1"
  fi
}

# VM tweaks: enable software renderer envs and virtual monitor defaults.
detect_vm_adjust() {
  local log="$1"
  local host_info

  if host_info="$(hostnamectl)"; then
    :
  else
    local rc=$?
    printf '%s\n' "${ERROR:-[ERROR]} Unable to inspect host environment (hostnamectl status $rc)." >&2
    return "$rc"
  fi

  if grep -q 'Chassis: vm' <<<"$host_info"; then
    printf '%s\n' "${INFO:-[INFO]} System is running in a virtual machine. Setting up proper env's and configs" | tee -a "$log"
    set_lua_assignment "config/hypr/configs/SystemSettings.lua" "no_hardware_cursors" "1"
    append_lua_env "WLR_RENDERER_ALLOW_SOFTWARE" "1"
    append_lua_module_line \
      "config/hypr/monitors.lua" \
      'output = "Virtual-1"' \
      $'hl.monitor({\n    output = "Virtual-1",\n    mode = "1920x1080@60.0",\n    position = "0x0",\n    scale = 1.0\n})'
  fi
}

# NixOS tweaks: ensure polkit overlay is enabled and default disabled.
detect_nixos_adjust() {
  local log="$1"
  local host_info

  if host_info="$(hostnamectl)"; then
    :
  else
    local rc=$?
    printf '%s\n' "${ERROR:-[ERROR]} Unable to inspect host environment (hostnamectl status $rc)." >&2
    return "$rc"
  fi

  if grep -q 'Operating System: NixOS' <<<"$host_info"; then
    printf '%s\n' "${INFO:-[INFO]} NixOS Distro Detected. Setting up proper env's and configs." | tee -a "$log"
    [[ -f "config/hypr/scripts/Polkit-NixOS.sh" ]] || {
      printf '%s\n' '[ERROR] NixOS Polkit helper is missing from the staged configuration.' >&2
      return 1
    }
    append_startup_expression \
      "Polkit-NixOS.sh" \
      'os.getenv("HOME") .. "/.config/hypr/scripts/Polkit-NixOS.sh"'
  fi
}

# Decide waybar config/style based on chassis type. Echoes chosen config path.
detect_waybar_config() {
  local host_info

  if host_info="$(hostnamectl)"; then
    :
  else
    local rc=$?
    printf '%s\n' "${ERROR:-[ERROR]} Unable to inspect host environment (hostnamectl status $rc)." >&2
    return "$rc"
  fi

  if grep -q 'Chassis: desktop' <<<"$host_info"; then
    echo "desktop"
  else
    echo "laptop"
  fi
}
