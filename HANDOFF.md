# Session Handoff

Use this file to resume work from another computer after `git pull`.
Update it at the end of each working session.

## Current Purpose
- This fork tracks upstream `chaldea` and adds automation-focused features:
  - Laplace Auto 3T team identification/search
  - Shared Teams "My Box" compatibility and batch simulation tools
- Design constraint: keep upstream-core changes minimal and keep custom logic in
  `lib/custom/...` whenever possible.

## Quick Resume Checklist
1. `git fetch --all --prune`
2. `git checkout main`
3. `git pull origin main`
4. If needed, sync with upstream:
   - `./scripts/sync_fork_pr.sh --open-pr`
   - legacy (if needed): `./scripts/sync_fork.sh`
5. Install deps if needed:
   - `flutter pub get` (or `fvm flutter pub get`)
6. Launch app:
   - `fvm flutter run -d macos`

## Last Session Snapshot
- Date: 2026-03-09
- Branch: automation/upstream-sync-2026-03-09-r2
- Last commit: 795ab6fe0
- Working tree status: clean
- Active feature(s): upstream sync + validation for Laplace Auto 3T Team Search fork
- What is done: created branch from `origin/main`, merged `upstream/main` (`541f87b2f`) cleanly, verified Team Search 3T integration hooks, ran `fvm flutter pub get`, ran `fvm flutter analyze` (15 existing info-level issues), ran `fvm flutter test` (fails in this env without `APP_PATH`), and pushed branch to origin
- What is next: open PR from `automation/upstream-sync-2026-03-09-r2` into `main`, then rerun tests in a fully provisioned local environment with `APP_PATH` and test data
- Known blockers: `gh` token is invalid and API calls to `api.github.com` fail in this environment, so PR creation could not be completed programmatically; Flutter test rerun with `APP_PATH` also hit sandbox denial writing FVM `engine.stamp`
## Files Touched In Current Workstream
- `lib/custom/team_search/...`
- `lib/custom/shared_teams/...`
- Thin integration points in:
  - `lib/app/modules/battle/...`

## Validation Commands
- `fvm flutter analyze`
- `fvm flutter test`
- `fvm flutter build macos --debug`

## Notes For Safe Upstream Updates
- Prefer `./scripts/sync_fork_pr.sh --open-pr` for protected-main syncs; use `./scripts/sync_fork.sh` only for manual/non-protected flows.
- Resolve conflicts by preserving upstream behavior first, then re-apply custom
  integration hooks.
- Re-check custom module wiring after any upstream UI changes in battle modules.
