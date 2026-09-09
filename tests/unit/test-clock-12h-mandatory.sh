#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROMPTS="$ROOT/scripts/lib_prompts.sh"
COPY="$ROOT/copy.sh"

# The installer must no longer ask whether to use 12H formatting.
! grep -Fq 'prompt_clock_12h' "$PROMPTS"
! grep -Fq 'Do you want to change to 12H' "$PROMPTS"
grep -Fq 'apply_clock_12h "$LOG"' "$COPY"

# 12H formatting is mandatory in every workflow, including express mode.
grep -Fq 'apply_sddm_12h_format "/usr/share/sddm/themes/simple-sddm" "$log"' "$PROMPTS"
grep -Fq 'apply_sddm_12h_format "/usr/share/sddm/themes/simple_sddm_2" "$log"' "$PROMPTS"
grep -Fq 'apply_sddm_12h_format_sequoia "/usr/share/sddm/themes/sequoia_2" "$log"' "$PROMPTS"
! grep -Fq 'Express mode: skipping SDDM 12H edits' "$PROMPTS"

# Privileged SDDM mutations must fail loudly; no successful partial edit may be
# silently accepted through a generic `|| true` fallback.
! grep -Fq 'sudo -n sed -i' "$PROMPTS" | grep -Fq '|| true'
! grep -Fq 'sudo -n sed -i' "$PROMPTS" | grep -Fq '|| true'

# The active 24H formats are explicitly commented while their 12H variants are
# enabled by the mandatory transformation.
apply_section="$(awk '/^apply_clock_12h\(\)/,/^apply_sddm_12h_format\(\)/' "$PROMPTS")"
grep -Fq '%H:%M:%S' <<<"$apply_section"
grep -Fq '%H:%M' <<<"$apply_section"
grep -Fq '%I:%M %p' <<<"$apply_section"
grep -Fq 'HourFormat="HH:mm"' "$PROMPTS"
grep -Fq 'clockFormat="hh:mm AP"' "$PROMPTS"

echo 'mandatory 12H clock invariant: PASS'
