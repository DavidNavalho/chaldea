#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/fork/push_upstream_sync_branch.sh

Environment:
  GITHUB_APP_TOKEN required
  PUSH_REPO        required, e.g. DavidNavalho/chaldea
  PUSH_BRANCH      optional, defaults to current branch
  PUSH_REMOTE_URL  optional, defaults to https://github.com/${PUSH_REPO}.git
  PUSH_FORCE_WITH_LEASE optional, default: true

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

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || {
    log "Missing required environment variable: ${name}"
    exit 1
  }
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
require_env GITHUB_APP_TOKEN
require_env PUSH_REPO

push_branch="${PUSH_BRANCH:-$(git branch --show-current)}"
[[ -n "$push_branch" ]] || {
  log "Unable to determine current branch. Set PUSH_BRANCH explicitly."
  exit 1
}

push_remote_url="${PUSH_REMOTE_URL:-https://github.com/${PUSH_REPO}.git}"
push_force_with_lease="${PUSH_FORCE_WITH_LEASE:-true}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

askpass_file="${tmp_dir}/askpass.sh"
cat >"$askpass_file" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  *Username*)
    printf '%s\n' 'x-access-token'
    ;;
  *Password*)
    printf '%s\n' "$GITHUB_APP_TOKEN"
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod 700 "$askpass_file"

push_args=(--set-upstream)
if [[ "$push_force_with_lease" == "true" ]]; then
  remote_branch_ref="refs/heads/${push_branch}"
  remote_branch_sha="$(
    git ls-remote "$push_remote_url" "$remote_branch_ref" 2>/dev/null | awk 'NR == 1 { print $1 }'
  )"
  push_args+=("--force-with-lease=${remote_branch_ref}:${remote_branch_sha}")
fi

log "Pushing ${push_branch} to ${push_remote_url}"
GIT_TERMINAL_PROMPT=0 \
GIT_ASKPASS="$askpass_file" \
git push "${push_args[@]}" "$push_remote_url" "HEAD:refs/heads/${push_branch}"

emit status "branch-pushed"
emit push_branch "$push_branch"
emit push_remote_url "$push_remote_url"
