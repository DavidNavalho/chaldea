#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/fork/prepare_upstream_sync_branch.sh

Environment:
  BASE_BRANCH     default: main
  UPSTREAM_BRANCH default: BASE_BRANCH
  ORIGIN_REMOTE   default: origin
  UPSTREAM_REMOTE default: upstream
  SYNC_BRANCH     default: automation/upstream-sync-YYYY-MM-DD
  UPSTREAM_URL    optional, used only when creating or updating upstream

Exit codes:
  0  success
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

require_clean_worktree() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    log "Working tree must be clean for automation-safe branch preparation."
    exit 1
  fi
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
require_clean_worktree

base_branch="${BASE_BRANCH:-main}"
upstream_branch="${UPSTREAM_BRANCH:-$base_branch}"
origin_remote="${ORIGIN_REMOTE:-origin}"
upstream_remote="${UPSTREAM_REMOTE:-upstream}"
sync_branch="${SYNC_BRANCH:-automation/upstream-sync-$(date -u +%F)}"
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

base_ref="${origin_remote}/${base_branch}"

log "Preparing sync branch '${sync_branch}' from ${base_ref}"
git checkout -B "$sync_branch" "$base_ref" >/dev/null

emit status "sync-branch-prepared"
emit sync_branch "$sync_branch"
emit base_ref "$base_ref"
