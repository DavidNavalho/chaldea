# Personal Fork Maintenance

This is the end-to-end checklist for updating Chaldea, publishing personal
changes to GitHub, and delivering the altered app through internal TestFlight.

- **Upstream:** `https://github.com/chaldea-center/chaldea.git`
- **Personal fork / PR destination:** `https://github.com/DavidNavalho/chaldea.git`
- **Durable context and unfinished work:** [HANDOFF.md](HANDOFF.md)
- **Signing, manual upload, troubleshooting:** [TESTFLIGHT_RUNBOOK.md](TESTFLIGHT_RUNBOOK.md)
- **Hosted workflow configuration:** [ios/ci_scripts/README.md](ios/ci_scripts/README.md)

## 1. Resume Safely

Run from the intended checkout, not a hard-coded historical worktree:

```bash
git status --short --branch
git worktree list
git remote -v
git fetch --all --prune
gh auth status
```

Preserve outstanding work before switching branches. Commit intentional changes
on their own branch or make a narrowly scoped stash. Inspect untracked files
and nested worktrees separately; do not blindly stash/delete `.dev/`. Reconcile
an older local handoff with the newer remote copy rather than overwriting it.

Once safe to switch:

```bash
git switch main
git pull --ff-only origin main
```

If `main` is checked out elsewhere, use that checkout or a new worktree. If a
fast-forward is refused, inspect the divergence; do not reset or force-push.
Install the Flutter version in `.fvmrc` (it must agree with `pubspec.yaml`):

```bash
fvm install
fvm flutter pub get
```

## 2. Bring In Original Upstream Changes

For the usual interactive flow, start with a clean checkout and run:

```bash
./scripts/sync_fork_pr.sh --open-pr
```

The wrapper creates/resets `automation/upstream-sync-YYYY-MM-DD` from
`origin/main`, merges `upstream/main`, pushes to the personal fork, and tries
to open a PR. It does **not** merge that PR, run validation locally, or publish
to TestFlight directly. Confirm the PR URL: PR creation can fail without a
nonzero script exit.

Safety constraints:

- Unpublished local commits are not included: the branch starts at `origin/main`.
- Dirty tracked changes are auto-stashed, not committed or published. Untracked-only
  work is not detected by the wrapper's cleanliness check.
- Do not rerun the wrapper on an in-progress sync branch: `checkout -B` can reset
  conflict-resolution or follow-up commits. Use a fresh `-s <branch>` for a new run.
- With conflicts, resolve files preserving upstream behavior and thin fork hooks,
  then `git add <resolved-files>` and `git commit`. Continue with validation and
  push/PR creation below; do not restart branch preparation.

### Step-by-Step Flow (Validate Before Push)

The existing `scripts/fork/` helpers allow a bounded agent/human review between
preparation and publication. They do not form an unattended merge agent.

```bash
./scripts/fork/check_upstream_updates.sh
# Exit 10 = incoming updates; 0 = none; 1 = failure (not "no updates").

SYNC_BRANCH="automation/upstream-sync-$(date -u +%F)" \
  ./scripts/fork/prepare_upstream_sync_branch.sh
# Preparation only creates/resets the branch; it does NOT merge upstream.
git merge --no-edit upstream/main
# Resolve any conflicts, then validate before continuing.
```

After review and validation, publish using your authenticated Git/gh session:

```bash
git push -u origin HEAD
gh pr create --repo DavidNavalho/chaldea --base main \
  --head "$(git branch --show-current)" \
  --title "Sync upstream and preserve personal fork" --body-file /path/to/pr-body.md
```

For machine-driven publication, `push_upstream_sync_branch.sh` requires
`GITHUB_APP_TOKEN` and `PUSH_REPO`; `open_upstream_sync_pr.sh` requires
`GH_TOKEN` and accepts `PR_REPO`. Supply credentials securely through the
process environment, never in source, logs, or chat. Set
`PUSH_FORCE_WITH_LEASE=false` for ordinary forward pushes; the push helper
otherwise defaults to force-with-lease. Never use it to rewrite `main`.
Each helper documents its inputs and exit codes with `--help`.

## 3. Publish Personal Changes

Personal features use the same protected PR path, independently of upstream sync:

```bash
git switch -c personal/my-change origin/main
# Edit, inspect the diff, and validate.
git add <intended-files>
git commit -m "Describe the personal change"
git push -u origin HEAD
gh pr create --repo DavidNavalho/chaldea --base main \
  --head "$(git branch --show-current)"
```

Keep custom logic under `lib/custom/` and platform identity in the fork-only
build overlay. Do not mix unrelated local work, credentials, or generated
build artifacts into a sync. Upstream-generated source arrives through the
merge; do not hand-edit `lib/generated/`.

## 4. Validate and Merge the PR

Before pushing, inspect `git diff --check` and the complete diff against
`origin/main`. After upstream changes, re-check Team Search/My Box wiring and
the fork's iOS identity adapters. Keep upstream platform lockfiles unless an
intentional dependency change requires otherwise.

For local validation using the same data-aware suite as Xcode Cloud:

```bash
fvm flutter pub get
CHALDEA_FLUTTER_BIN="$PWD/.fvm/flutter_sdk/bin/flutter" \
  ios/ci_scripts/ci_validate_pull_request.sh
```

This downloads a temporary public offline game-data payload, runs analysis
(with informational lints non-fatal), and runs the full Flutter suite. It does
not use your personal account data. `scripts/fork/validate_upstream_sync.sh`
can also wrap it via `VALIDATION_CMD`; that helper's default tests target Linux,
so use the override on macOS.

On GitHub:

```bash
gh pr checks <PR-number> --repo DavidNavalho/chaldea --watch
```

The required check is **`Chaldea | PR Validation`**: Flutter analysis, full tests,
then an iOS build. The active ruleset requires an up-to-date branch and has no
bypass actors. Inspect failures; never disable the gate to complete a release.
Inherited GitHub Actions are separate from Xcode Cloud and are not the iOS
publication mechanism. Review their failures too, rather than assuming every
red check is harmless.

After the required check succeeds and the diff is reviewed:

```bash
gh pr merge <PR-number> --repo DavidNavalho/chaldea --merge \
  --match-head-commit <reviewed-head-SHA>
```

Use a merge commit for upstream syncs to preserve ancestry. If `main` advanced,
merge `origin/main` into the PR branch and rerun checks before merging.

## 5. Confirm TestFlight Delivery

Merging into personal `main` triggers Xcode Cloud **Main TestFlight Delivery**:

1. Confirm the Cloud run uses the exact merge SHA and the delivery workflow,
   not the PR-only validation workflow.
2. Confirm archive, identity/signature validation, upload, and internal
   TestFlight distribution all succeed.
3. In App Store Connect, open **Chaldea Personal** (app ID `6801619927`). Verify
   the version/build is processed and assigned to **Chaldea Internal**.
4. Install that build in TestFlight. Smoke-test launch, Team Search 3T/replay,
   My Box/coverage, account login as appropriate, and widget shared data on a
   supported device. Back up existing app data before testing migrations.
5. Keep run-specific evidence in GitHub checks/PR comments and Cloud/App Store
   Connect. Update `HANDOFF.md` only for a methodology change, unresolved blocker,
   or genuine unfinished work—not to record which PR or build succeeded.

Commit relevant handoff changes with the intentional work. Do not create a
follow-up handoff commit merely because a merge or delivery finished; that
creates another release without advancing the upstream-maintenance objective.

A successful PR check is **not** evidence of delivery; a pushed feature branch
is **not** automatically a release. Cloud configuration lives in App Store
Connect, not GitHub Actions YAML; see the linked Cloud README to verify or
restore it. Do not claim a release is available without checking processing.

If automatic delivery fails, fix the cause and rerun the delivery workflow for
the reviewed commit. The manual fallback is `scripts/fork/build_ios_testflight.sh`
with the fork overlay, followed by Xcode Organizer upload; follow the TestFlight
runbook and choose an unused, increasing build number for that version. Do not
use a plain `flutter build ipa`, disable signing checks, or enable external
TestFlight distribution as a shortcut.

## Legacy Workflow

`./scripts/sync_fork.sh` is for explicitly approved, unprotected/manual history
rewrite scenarios only. It defaults to rebase and force-with-lease and is **not**
the recommended path for this protected fork. Both sync wrappers require Bash;
invoke them directly (or with `bash`), not `sh`.
