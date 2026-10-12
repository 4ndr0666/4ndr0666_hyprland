#!/bin/bash
# Minimal installer UI primitives shared by non-package modules.

# shellcheck disable=SC2034 # UI constants are consumed by installer modules that source this file.
RESET=$'\033[0m'
SKY_BLUE=$'\033[96m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'
NOTE='[INFO]'
INFO='[INFO]'
OK='[OK]'
ERROR='[ERROR]'
WARN='[WARN]'
