# Session Handoff

Keep this file focused on durable maintenance context and genuine unfinished
work. It is not a PR, commit, build, or deployment log. Obtain those details
from Git, GitHub checks, and Xcode Cloud / App Store Connect when needed.

Update the snapshot when the methodology, a blocker, or an outstanding task
changes. Commit useful changes in the same intentional PR as the work they
support. A PR merging or a build finishing does not require another handoff
edit, follow-up PR, or documentation-only release.

## Current Purpose

Keep the personal Chaldea app up to date with original upstream changes while
preserving the fork's automation features:

- Laplace Auto 3T team identification/search
- Shared Teams "My Box" compatibility and batch simulation tools
- My Box Coverage overview

Upstream remains the source of truth for the core app. Keep custom logic under
`lib/custom/` and upstream integration hooks thin. Keep personal iOS identity
in the fork-only build overlay rather than the upstream Xcode project.

## Maintenance References

- [FORK_NOTES.md](FORK_NOTES.md): upstream sync, personal changes, validation,
  protected PR merge, and automatic TestFlight delivery.
- [TESTFLIGHT_RUNBOOK.md](TESTFLIGHT_RUNBOOK.md): signing, manual fallback,
  troubleshooting, and on-device verification.
- [ios/ci_scripts/README.md](ios/ci_scripts/README.md): hosted workflow
  configuration and fork identity checks.

## Quick Resume Checklist

1. Inspect `git status --short --branch`, `git worktree list`, and this snapshot.
   Preserve local changes, stashes, and nested worktrees before switching or pulling.
2. `git fetch --all --prune`
3. When safe: `git switch main` and `git pull --ff-only origin main`.
   Inspect divergence rather than resetting or overwriting unrelated work.
4. Run `./scripts/fork/check_upstream_updates.sh`:
   - Exit `0`: no incoming updates; no sync PR is needed.
   - Exit `10`: updates available; follow `FORK_NOTES.md`.
   - Exit `1`: investigate the failure; do not treat it as "up to date".
5. If building locally, use `fvm install` and `fvm flutter pub get`.
   Read toolchain versions from `.fvmrc` and `pubspec.yaml`, not old session notes.
6. Do not rerun branch preparation on an in-progress sync branch: it resets
   from `origin/main`. Resume conflict resolution, validation, or publication
   from the actual repository/PR state instead.

## Last Session Snapshot

- Focus: repeatable upstream maintenance, not release bookkeeping.
- The existing workflow supports detection, reviewed upstream merges, data-aware
  validation, protected PRs, and automatic internal TestFlight delivery.
- Full local tests need offline game data. Use the data-aware validation helper
  documented in `FORK_NOTES.md`, not an arbitrary checkout as `APP_PATH`.
- No known maintenance-pipeline blocker. Recheck live validation and delivery
  results for each update; past success is not proof of a new release.
- On-device verification remains the owner's step: back up app data, confirm
  TestFlight availability, then check Team Search/replay, My Box/coverage,
  settings migrations, account login, and supported widget shared data.
- Next maintenance action: check upstream for changes and run the existing
  workflow when updates are available. Do not update this snapshot merely to
  record which PR merged or which build completed.
