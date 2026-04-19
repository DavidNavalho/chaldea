#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/fork/validate_upstream_sync.sh

Environment:
  VALIDATION_CMD optional; if unset, runs:
    flutter analyze
    flutter test

Exit codes:
  0  validation passed
 20  validation failed and needs review
  1  hard failure
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

emit() {
  printf '%s=%s\n' "$1" "$2"
}

require_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    log "Not inside a Git repo"
    exit 1
  }
}

run_validation_command() {
  local label="$1"
  shift

  log "Running ${label}"
  if "$@"; then
    return 0
  fi

  emit status "validation-failed"
  emit failed_step "$label"
  exit 20
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

[[ $# -eq 0 ]] || {
  usage
  exit 1
}

require_repo

if [[ -n "${VALIDATION_CMD:-}" ]]; then
  log "Running custom validation command"
  if bash -lc "$VALIDATION_CMD"; then
    emit status "validation-passed"
    exit 0
  fi

  emit status "validation-failed"
  emit failed_step "custom-validation-cmd"
  exit 20
fi

command -v flutter >/dev/null 2>&1 || {
  log "Missing required command: flutter"
  exit 1
}

run_validation_command "flutter-analyze" flutter analyze
run_validation_command "flutter-test" flutter test

emit status "validation-passed"
