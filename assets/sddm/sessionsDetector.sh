#!/bin/bash

# Directory paths
xsessions_dir="/usr/share/xsessions"
wayland_dir="/usr/share/wayland-sessions"

# Output file
output_file="sessions.txt"

# Retrieve .desktop filenames in xsessions directory
xsessions_files=$(find "$xsessions_dir" -name "*.desktop" -exec basename {} \;)

# Retrieve .desktop filenames in wayland-sessions directory
wayland_files=$(find "$wayland_dir" -name "*.desktop" -exec basename {} \;)

# Extract session names from filenames
xsessions_names=""
for file in $xsessions_files; do
  name="${file%.desktop}"
  xsessions_names+="$name "
done

wayland_names=""
for file in $wayland_files; do
  name="${file%.desktop}"
  wayland_names+="$name "
done

# Combine and save the session names to the output file
echo "$wayland_names$xsessions_names" > "$output_file"

echo "Session names saved to $output_file"

