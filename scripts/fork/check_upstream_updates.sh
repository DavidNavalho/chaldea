#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/fork/check_upstream_updates.sh

Environment:
  BASE_BRANCH     default: main
  UPSTREAM_BRANCH default: BASE_BRANCH
  ORIGIN_REMOTE   default: origin
  UPSTREAM_REMOTE default: upstream
  UPSTREAM_URL    optional, used only when creating or updating upstream

Exit codes:
  0  no upstream updates
 10  upstream updates are available
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

ensure_remote() {
  local remote_name="$1"
  local remote_url="$2"

  if git remote get-url "$remote_name" >/dev/null 2>&1; then
    if [[ -n "$remote_url" ]]; then
      git remote set-url "$remote_name" "$remote_url"
    fi
    return
  fi

  if [[ -z "$remote_url" ]]; then
    log "Missing '$remote_name' remote. Set UPSTREAM_URL or add the remote first."
    exit 1
  fi

  git remote add "$remote_name" "$remote_url"
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

base_branch="${BASE_BRANCH:-main}"
upstream_branch="${UPSTREAM_BRANCH:-$base_branch}"
origin_remote="${ORIGIN_REMOTE:-origin}"
upstream_remote="${UPSTREAM_REMOTE:-upstream}"
upstream_url="${UPSTREAM_URL:-}"

git remote get-url "$origin_remote" >/dev/null 2>&1 || {
  log "Missing '$origin_remote' remote."
  exit 1
}

ensure_remote "$upstream_remote" "$upstream_url"

log "Fetching ${origin_remote}/${base_branch}"
git fetch --prune "$origin_remote" "$base_branch"

log "Fetching ${upstream_remote}/${upstream_branch}"
git fetch --prune "$upstream_remote" "$upstream_branch"

origin_ref="${origin_remote}/${base_branch}"
upstream_ref="${upstream_remote}/${upstream_branch}"

origin_sha="$(git rev-parse "$origin_ref")"
upstream_sha="$(git rev-parse "$upstream_ref")"

read -r origin_only_count upstream_only_count < <(git rev-list --left-right --count "${origin_ref}...${upstream_ref}")

status="no-upstream-updates"
exit_code=0
if [[ "$upstream_only_count" -gt 0 ]]; then
  status="upstream-updates-available"
  exit_code=10
fi

emit status "$status"
emit origin_ref "$origin_ref"
emit upstream_ref "$upstream_ref"
emit origin_sha "$origin_sha"
emit upstream_sha "$upstream_sha"
emit origin_only_count "$origin_only_count"
emit upstream_only_count "$upstream_only_count"

exit "$exit_code"
