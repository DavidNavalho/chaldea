#!/usr/bin/env bash
set -euo pipefail

# Sync a personal fork with upstream.
# - Defaults to rebasing local <branch> onto upstream/<branch> then pushing to origin.
# - Stashes dirty changes before sync and leaves the stash for you to pop later
#   unless you pass --pop-stash.
#
# Usage:
#   scripts/sync_fork.sh [-b branch] [--merge|--rebase] [--no-push] [--pop-stash]
#
# Examples:
#   scripts/sync_fork.sh                 # rebase main onto upstream/main and push
#   scripts/sync_fork.sh -b develop      # rebase develop onto upstream/develop and push
#   scripts/sync_fork.sh --merge         # merge upstream/main into main and push
#   scripts/sync_fork.sh --no-push       # sync locally only (no push)
#   scripts/sync_fork.sh --pop-stash     # re-apply any auto-stashed changes

branch="main"
mode="rebase"      # or "merge"
do_push=1
pop_stash=0

usage() {
  echo "Usage: $0 [-b branch] [--merge|--rebase] [--no-push] [--pop-stash]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--branch)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; usage; exit 2; }
      branch="$2"; shift 2;;
    --merge)
      mode="merge"; shift;;
    --rebase)
      mode="rebase"; shift;;
    --no-push)
      do_push=0; shift;;
    --pop-stash)
      pop_stash=1; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown argument: $1" >&2; usage; exit 2;;
  esac
done

# Pre-flight checks
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not inside a Git repo" >&2; exit 1; }

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Missing 'upstream' remote. Add it, e.g.: git remote add upstream https://github.com/chaldea-center/chaldea.git" >&2
  exit 1
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Missing 'origin' remote. Add your fork, e.g.: git remote add origin git@github.com:YOURUSER/chaldea.git" >&2
  exit 1
fi

current_branch="$(git branch --show-current || true)"

echo "==> Syncing branch '$branch' (mode: $mode)"

# Ensure local branch exists (create from origin if absent)
if ! git show-ref --verify --quiet "refs/heads/$branch"; then
  echo "==> Local '$branch' not found; creating from origin/$branch"
  git fetch origin "$branch:refs/heads/$branch"
fi

# Stash any dirty state to avoid conflicts with rebase/merge
stash_ref=""
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "==> Working tree not clean; stashing changes"
  stash_ref="$(git stash push -u -m "sync_fork auto-stash on $(date -u +%FT%TZ)" || true)"
fi

echo "==> Fetching remotes"
git fetch --prune upstream
git fetch --prune origin

echo "==> Checking out '$branch'"
git checkout "$branch"

set +e
if [[ "$mode" == "rebase" ]]; then
  echo "==> Rebasing onto upstream/$branch"
  git rebase "upstream/$branch"
  rebase_status=$?
  if [[ $rebase_status -ne 0 ]]; then
    echo "!! Rebase paused due to conflicts. Resolve them, then run:"
    echo "   git rebase --continue"
    echo "   # or abort: git rebase --abort"
    exit $rebase_status
  fi
else
  echo "==> Merging upstream/$branch"
  git merge --no-edit "upstream/$branch"
  merge_status=$?
  if [[ $merge_status -ne 0 ]]; then
    echo "!! Merge has conflicts. Resolve them, then run:"
    echo "   git commit"
    exit $merge_status
  fi
fi
set -e

if [[ $do_push -eq 1 ]]; then
  if [[ "$mode" == "rebase" ]]; then
    echo "==> Pushing with --force-with-lease to origin/$branch"
    git push --force-with-lease origin "$branch"
  else
    echo "==> Pushing to origin/$branch"
    git push origin "$branch"
  fi
else
  echo "==> Skipping push (--no-push)"
fi

if [[ -n "${stash_ref}" ]]; then
  echo "==> Stash saved: ${stash_ref}"
  if [[ $pop_stash -eq 1 ]]; then
    echo "==> Re-applying stashed changes"
    set +e
    git stash pop
    pop_status=$?
    set -e
    if [[ $pop_status -ne 0 ]]; then
      echo "!! Stash pop resulted in conflicts. Resolve them and commit."
    fi
  else
    echo "   To re-apply: git stash pop"
  fi
fi

echo "==> Done"

