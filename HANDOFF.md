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
- Date: 2026-03-07
- Branch: automation/upstream-sync-2026-03-07
- Last commit: c56e757d4
- Working tree status: clean on sync branch (ahead by handoff/memory updates pending commit)
- Active feature(s): upstream sync verification + Team Search/Auto 3T regression guard
- What is done: merged `upstream/main` into fresh branch from `origin/main`; upstream delta is only `lib/models/userdata/battle.dart`; validated `fvm flutter pub get` and `fvm flutter analyze` (info-level lints only); verified Team Search/Auto 3T integration paths remain wired and untouched; pushed sync branch
- What is next: open/complete PR from `automation/upstream-sync-2026-03-07` into `main`; run full tests in an unrestricted local shell with `--dart-define=APP_PATH=<local_chaldea_app_path>`
- Known blockers: `gh` token invalid in automation environment; Flutter/Dart sandbox write restrictions block a full reproducible `flutter test` rerun
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
