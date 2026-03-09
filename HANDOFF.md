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
- Branch: automation/upstream-sync-2026-03-09
- Last commit: d1570bac5
- Working tree status: clean after merge + validation; branch ahead of `origin/main` by 2 commits
- Active feature(s): upstream sync + verification of Laplace Team Search 3T and Shared Teams integration hooks
- What is done: created sync branch from `origin/main`, merged cached `upstream/main` (delta: `lib/models/userdata/battle.dart`), verified Team Search hooks in `simulation_preview.dart` + `lib/custom/team_search/*`, ran `fvm flutter pub get` (pass), `fvm flutter analyze` (15 existing info lints), `fvm flutter test` (blocked by required `APP_PATH`)
- What is next: push `automation/upstream-sync-2026-03-09` and open PR into `main`, then rerun tests in an environment with `APP_PATH` and gamedata available
- Known blockers: this sandbox cannot resolve `github.com` (no fetch/push/PR), and `flutter test` needs `APP_PATH` bootstrap
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
