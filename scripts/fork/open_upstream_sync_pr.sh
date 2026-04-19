#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/fork/open_upstream_sync_pr.sh

Environment:
  GH_TOKEN       required
  PR_REPO        optional, defaults to repo inferred from origin remote
  BASE_BRANCH    default: main
  PR_HEAD_BRANCH optional, defaults to current branch
  PR_TITLE       optional
  PR_BODY        optional
  PR_LABELS      optional, comma-separated, default: codex,codex-automation

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

repo_slug_from_url() {
  local url="$1"
  if [[ "$url" =~ ^git@github\.com:(.+)\.git$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return
  fi
  if [[ "$url" =~ ^https://github\.com/(.+)\.git$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return
  fi
  if [[ "$url" =~ ^https://github\.com/(.+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return
  fi
  printf '\n'
}

apply_labels() {
  local repo_slug="$1"
  local pr_number="$2"
  local labels_csv="$3"

  [[ -n "$labels_csv" ]] || return 0

  local label
  local -a label_args=()
  IFS=',' read -r -a labels <<<"$labels_csv"
  for label in "${labels[@]}"; do
    label="${label#"${label%%[![:space:]]*}"}"
    label="${label%"${label##*[![:space:]]}"}"
    [[ -n "$label" ]] || continue
    label_args+=(-f "labels[]=${label}")
  done

  [[ "${#label_args[@]}" -gt 0 ]] || return 0
  gh api "repos/${repo_slug}/issues/${pr_number}/labels" -X POST "${label_args[@]}" >/dev/null
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
require_env GH_TOKEN
command -v gh >/dev/null 2>&1 || {
  log "Missing required command: gh"
  exit 1
}

repo_slug="${PR_REPO:-}"
if [[ -z "$repo_slug" ]]; then
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  repo_slug="$(repo_slug_from_url "$origin_url")"
fi

[[ -n "$repo_slug" ]] || {
  log "Unable to determine repository slug. Set PR_REPO explicitly."
  exit 1
}

base_branch="${BASE_BRANCH:-main}"
head_branch="${PR_HEAD_BRANCH:-$(git branch --show-current)}"
[[ -n "$head_branch" ]] || {
  log "Unable to determine head branch. Set PR_HEAD_BRANCH explicitly."
  exit 1
}

today_iso="$(date -u +%F)"
pr_title="${PR_TITLE:-Sync fork with upstream ${base_branch} (${today_iso})}"
pr_body="${PR_BODY:-Automated upstream sync branch prepared by repo-local fork automation.}"
pr_labels="${PR_LABELS:-codex,codex-automation}"
owner="${repo_slug%/*}"

existing_pr_number="$(gh api "repos/${repo_slug}/pulls" -f state=open -f head="${owner}:${head_branch}" -f base="${base_branch}" --jq '.[0].number // ""')"
existing_pr_url="$(gh api "repos/${repo_slug}/pulls" -f state=open -f head="${owner}:${head_branch}" -f base="${base_branch}" --jq '.[0].html_url // ""')"

if [[ -n "$existing_pr_number" ]]; then
  log "Using existing PR #${existing_pr_number}"
  apply_labels "$repo_slug" "$existing_pr_number" "$pr_labels"
  emit pr_status "existing"
  emit pr_number "$existing_pr_number"
  emit pr_url "$existing_pr_url"
  exit 0
fi

log "Creating PR from ${head_branch} to ${base_branch}"
pr_url="$(gh api "repos/${repo_slug}/pulls" -X POST -f title="$pr_title" -f head="$head_branch" -f base="$base_branch" -f body="$pr_body" --jq '.html_url')"
pr_number="$(gh api "repos/${repo_slug}/pulls" -f state=open -f head="${owner}:${head_branch}" -f base="${base_branch}" --jq '.[0].number // ""')"

[[ -n "$pr_number" ]] || {
  log "PR was created but could not be re-discovered."
  exit 1
}

apply_labels "$repo_slug" "$pr_number" "$pr_labels"

emit pr_status "created"
emit pr_number "$pr_number"
emit pr_url "$pr_url"
