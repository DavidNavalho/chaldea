#!/usr/bin/env bash
set -euo pipefail

# Sync fork with upstream using a PR branch (safe for protected main).
#
# Flow:
# 1) fetch origin + upstream
# 2) create/reset sync branch from origin/<base>
# 3) merge upstream/<base> into sync branch
# 4) push sync branch (SSH first, HTTPS fallback for GitHub remotes)
# 5) optionally open/update PR via gh CLI
#
# Usage:
#   scripts/sync_fork_pr.sh [-b base] [-s sync_branch] [--open-pr] [--pop-stash]
#
# Examples:
#   scripts/sync_fork_pr.sh
#   scripts/sync_fork_pr.sh --open-pr
#   scripts/sync_fork_pr.sh -s automation/upstream-sync-2026-03-05 --open-pr

base_branch="main"
sync_branch="automation/upstream-sync-$(date -u +%F)"
open_pr=0
pop_stash=0

usage() {
  echo "Usage: $0 [-b base] [-s sync_branch] [--open-pr] [--pop-stash]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--branch)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; usage; exit 2; }
      base_branch="$2"; shift 2;;
    -s|--sync-branch)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; usage; exit 2; }
      sync_branch="$2"; shift 2;;
    --open-pr)
      open_pr=1; shift;;
    --pop-stash)
      pop_stash=1; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown argument: $1" >&2; usage; exit 2;;
  esac
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not inside a Git repo" >&2; exit 1; }

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Missing 'upstream' remote. Add it first." >&2
  exit 1
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Missing 'origin' remote. Add it first." >&2
  exit 1
fi

origin_url="$(git remote get-url origin)"

repo_slug_from_url() {
  local url="$1"
  if [[ "$url" =~ ^git@github\.com:(.+)\.git$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  if [[ "$url" =~ ^https://github\.com/(.+)\.git$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  if [[ "$url" =~ ^https://github\.com/(.+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  echo ""
}

repo_slug="$(repo_slug_from_url "$origin_url")"

stash_ref=""
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "==> Working tree not clean; stashing changes"
  stash_ref="$(git stash push -u -m "sync_fork_pr auto-stash on $(date -u +%FT%TZ)" || true)"
fi

echo "==> Fetching remotes"
git fetch --prune upstream
git fetch --prune origin

echo "==> Preparing sync branch '$sync_branch' from origin/$base_branch"
git checkout -B "$sync_branch" "origin/$base_branch"

echo "==> Merging upstream/$base_branch"
set +e
git merge --no-edit "upstream/$base_branch"
merge_status=$?
set -e
if [[ $merge_status -ne 0 ]]; then
  echo "!! Merge has conflicts. Resolve them, then run:"
  echo "   git add <files>"
  echo "   git commit"
  echo "   git push -u origin $sync_branch"
  exit $merge_status
fi

push_ok=0
echo "==> Pushing sync branch to origin/$sync_branch"
if git push -u origin "$sync_branch"; then
  push_ok=1
else
  echo "==> Push via origin URL failed; trying HTTPS fallback"
  if [[ -n "$repo_slug" ]]; then
    https_origin="https://github.com/${repo_slug}.git"
    git push -u "$https_origin" "$sync_branch"
    push_ok=1
  fi
fi

if [[ $push_ok -ne 1 ]]; then
  echo "!! Push failed; unable to continue" >&2
  exit 1
fi

compare_url=""
if [[ -n "$repo_slug" ]]; then
  compare_url="https://github.com/${repo_slug}/compare/${base_branch}...${sync_branch}?expand=1"
  echo "==> Compare URL: $compare_url"
fi

if [[ $open_pr -eq 1 ]]; then
  if [[ -z "$repo_slug" ]]; then
    echo "==> Could not infer GitHub repository slug; skipping PR creation"
  elif ! command -v gh >/dev/null 2>&1; then
    echo "==> gh CLI not found; skipping PR creation"
  else
    owner="${repo_slug%/*}"
    existing_pr_url="$(gh api "repos/${repo_slug}/pulls" -f state=open -f head="${owner}:${sync_branch}" -f base="$base_branch" --jq '.[0].html_url' 2>/dev/null || true)"
    if [[ -n "$existing_pr_url" && "$existing_pr_url" != "null" ]]; then
      echo "==> Existing PR: $existing_pr_url"
    else
      title="Sync fork with upstream ${base_branch} ($(date -u +%F))"
      body="Automated upstream sync branch prepared by scripts/sync_fork_pr.sh."
      pr_url="$(gh api "repos/${repo_slug}/pulls" -X POST -f title="$title" -f head="$sync_branch" -f base="$base_branch" -f body="$body" --jq '.html_url' 2>/dev/null || true)"
      if [[ -n "$pr_url" && "$pr_url" != "null" ]]; then
        echo "==> Created PR: $pr_url"
        pr_number="$(gh api "repos/${repo_slug}/pulls" -f state=open -f head="${owner}:${sync_branch}" -f base="$base_branch" --jq '.[0].number' 2>/dev/null || true)"
        if [[ -n "$pr_number" && "$pr_number" != "null" ]]; then
          gh api "repos/${repo_slug}/issues/${pr_number}/labels" -X POST -f labels[]="codex" -f labels[]="codex-automation" >/dev/null 2>&1 || true
        fi
      else
        echo "==> Could not create PR via gh API."
        if [[ -n "$compare_url" ]]; then
          echo "   Open manually: $compare_url"
        fi
      fi
    fi
  fi
fi

if [[ -n "$stash_ref" ]]; then
  echo "==> Stash saved: $stash_ref"
  if [[ $pop_stash -eq 1 ]]; then
    echo "==> Re-applying stashed changes"
    set +e
    git stash pop
    pop_status=$?
    set -e
    if [[ $pop_status -ne 0 ]]; then
      echo "!! Stash pop resulted in conflicts. Resolve and commit."
    fi
  else
    echo "   To re-apply: git stash pop"
  fi
fi

echo "==> Done"
