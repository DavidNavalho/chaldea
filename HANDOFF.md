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
- Date: 2026-03-08
- Branch: automation/upstream-sync-2026-03-08
- Last commit: 4cfee43b5 (merge upstream/main into sync branch)
- Working tree status: sync branch pushed to origin; local tree clean after validation
- Active feature(s): protected-main upstream sync + Team Search/Auto 3T integration verification
- What is done: merged upstream/main (`541f87b2f`) into new sync branch, verified only `lib/models/userdata/battle.dart` changed from upstream, and confirmed Team Search wiring remains in `lib/app/modules/battle/simulation_preview.dart` and `lib/custom/team_search/*`
- What is next: open and merge PR from `automation/upstream-sync-2026-03-08` into `main`, then rerun full tests in an environment with local gamedata
- Known blockers: `flutter test` requires `--dart-define=APP_PATH=...` and offline gamedata files; in this sandbox, suites fail with `No data found` from `GameDataLoader`
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
