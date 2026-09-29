#!/usr/bin/env bash
set -Eeuo pipefail

oma2_evidence_init() {
  : "${OMA2_EVIDENCE_DIR:?OMA2_EVIDENCE_DIR must be set}"
  mkdir -p "$OMA2_EVIDENCE_DIR"
  OMA2_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  OMA2_EVIDENCE="$OMA2_EVIDENCE_DIR/oma2-$OMA2_TIMESTAMP.txt"
  OMA2_TMP="$(mktemp)"
  trap 'rm -f "$OMA2_TMP"' EXIT
  : > "$OMA2_EVIDENCE"
}

oma2_emit() {
  printf '%s\n' "$*" >> "$OMA2_EVIDENCE"
}

oma2_section() {
  printf '\n[%s]\n' "$1" >> "$OMA2_EVIDENCE"
}

oma2_probe() {
  local name="$1"
  shift
  if "$@" >"$OMA2_TMP" 2>&1; then
    printf '%s=PASS\n' "$name" >> "$OMA2_EVIDENCE"
    sed 's/[[:space:]]\+$//' "$OMA2_TMP" | sed 's/^/  /' >> "$OMA2_EVIDENCE"
    return 0
  fi
  printf '%s=FAIL\n' "$name" >> "$OMA2_EVIDENCE"
  sed 's/[[:space:]]\+$//' "$OMA2_TMP" | sed 's/^/  /' >> "$OMA2_EVIDENCE"
  return 1
}

oma2_finish() {
  local failures="$1"
  printf '\nsummary_failures=%s\n' "$failures" >> "$OMA2_EVIDENCE"
  sha256sum "$OMA2_EVIDENCE" > "$OMA2_EVIDENCE.sha256"
  printf 'O.M.A.-2 evidence written to %s\n' "$OMA2_EVIDENCE"
  printf 'O.M.A.-2 evidence SHA-256 written to %s\n' "$OMA2_EVIDENCE.sha256"
  (( failures == 0 ))
}
