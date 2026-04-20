#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/fork/validate_upstream_sync.sh

Environment:
  VALIDATION_CMD optional; if unset, runs:
    flutter analyze --no-fatal-infos
    flutter test -d linux --dart-define=APP_PATH=<cache-backed app path>
  VALIDATION_CACHE_DIR      optional; default: ${XDG_CACHE_HOME:-$HOME/.cache}/jaf/chaldea-validation
  VALIDATION_DATA_REPO_URL  optional; default: https://github.com/chaldea-center/chaldea-data.git
  VALIDATION_DATA_REF       optional; default: main

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

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log "Missing required command: $1"
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

ensure_validation_data() {
  local cache_dir="$1"
  local repo_url="$2"
  local data_ref="$3"
  local repo_dir="${cache_dir}/repo"
  local app_root="${cache_dir}/app"

  mkdir -p "$cache_dir"

  if [[ ! -d "${repo_dir}/.git" ]]; then
    log "Cloning validation data repository"
    git clone --depth 1 --branch "$data_ref" "$repo_url" "$repo_dir"
  else
    log "Refreshing validation data repository"
    git -C "$repo_dir" fetch --prune origin "$data_ref"
    git -C "$repo_dir" checkout -B "$data_ref" "origin/$data_ref" >/dev/null
  fi

  mkdir -p "$app_root"
  if [[ -e "${app_root}/game" && ! -L "${app_root}/game" ]]; then
    log "Validation app path contains a non-symlink game directory: ${app_root}/game"
    exit 1
  fi

  ln -sfn "${repo_dir}/dist" "${app_root}/game"
  printf '%s\n' "$app_root"
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

require_cmd git
require_cmd flutter

validation_cache_dir="${VALIDATION_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/jaf/chaldea-validation}"
validation_data_repo_url="${VALIDATION_DATA_REPO_URL:-https://github.com/chaldea-center/chaldea-data.git}"
validation_data_ref="${VALIDATION_DATA_REF:-main}"
validation_app_path="$(
  ensure_validation_data \
    "$validation_cache_dir" \
    "$validation_data_repo_url" \
    "$validation_data_ref"
)"

run_validation_command "flutter-analyze" flutter analyze --no-fatal-infos
run_validation_command \
  "flutter-test" \
  flutter test -d linux "--dart-define=APP_PATH=${validation_app_path}"

emit status "validation-passed"
