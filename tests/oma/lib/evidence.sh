#!/usr/bin/env bash
set -Eeuo pipefail

oma2_evidence_finalize() {
  local failures="$1"
  local reason="${2:-}"
  local hash_tmp

  if [[ "${OMA2_EVIDENCE_FINALIZED:-0}" == 1 ]]; then
    return 0
  fi
  OMA2_EVIDENCE_FINALIZED=1

  if [[ -n "$reason" ]]; then
    printf 'fatal_error=%s\n' "$reason" >> "$OMA2_EVIDENCE"
  fi
  printf '\nsummary_failures=%s\n' "$failures" >> "$OMA2_EVIDENCE"

  hash_tmp="${OMA2_EVIDENCE}.sha256.tmp"
  if sha256sum "$OMA2_EVIDENCE" > "$hash_tmp"; then
    mv -- "$hash_tmp" "$OMA2_EVIDENCE.sha256"
  else
    rm -f -- "$hash_tmp"
    return 1
  fi

  printf 'O.M.A.-2 evidence written to %s\n' "$OMA2_EVIDENCE"
  printf 'O.M.A.-2 evidence SHA-256 written to %s\n' "$OMA2_EVIDENCE.sha256"
}

oma2_evidence_exit() {
  local status="$1"
  if (( status != 0 )) && [[ "${OMA2_EVIDENCE_FINALIZED:-0}" != 1 ]] && [[ -n "${OMA2_EVIDENCE:-}" ]]; then
    oma2_evidence_finalize 1 "O.M.A.-2 exited unexpectedly while executing: ${BASH_COMMAND:-unknown}"
  fi
  rm -f -- "${OMA2_TMP:-}"
  return "$status"
}

oma2_evidence_init() {
  : "${OMA2_EVIDENCE_DIR:?OMA2_EVIDENCE_DIR must be set}"
  mkdir -p "$OMA2_EVIDENCE_DIR"
  OMA2_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  OMA2_EVIDENCE="$(mktemp "$OMA2_EVIDENCE_DIR/oma2-$OMA2_TIMESTAMP-XXXXXX.txt")"
  OMA2_TMP="$(mktemp)"
  OMA2_EVIDENCE_FINALIZED=0
  trap 'oma2_evidence_exit "$?"' EXIT
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
  oma2_evidence_finalize "$failures"
  (( failures == 0 ))
}
