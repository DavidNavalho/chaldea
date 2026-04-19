# Session Handoff

Use this file to resume work from another computer after `git pull`.
Update it at the end of each working session.

## Current Purpose
- This fork tracks upstream `chaldea` and adds automation-focused features:
  - Laplace Auto 3T team identification/search
  - Shared Teams "My Box" compatibility and batch simulation tools
  - My Box Coverage overview page
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
- Date: 2026-04-19
- Branch: codex/box-coverage-mvp
- Last commit: 84ad103d1
- Working tree status: dirty with local MVP implementation changes under `lib/custom/box_coverage/`, route wiring, gallery entry, tests, and this handoff update
- Active feature(s): My Box Coverage MVP page integrated into the app home gallery
- What is done:
  - synced local `main` with `upstream/main`
  - created feature branch `codex/box-coverage-mvp`
  - implemented isolated models/service/page under `lib/custom/box_coverage/`
  - added route `/my-box-coverage` and home gallery entry
  - added focused service tests under `test/custom/box_coverage/`
  - validated with `flutter test` and `flutter build macos --debug`
- What is next:
  - manually review the new page UX in the running macOS app
  - decide whether to tighten the table presentation further before commit/PR
  - optionally add widget tests once the UI structure settles
- Known blockers:
  - `flutter analyze` still exits non-zero because of pre-existing info-level lints elsewhere in the fork; the new feature compiles cleanly
## Files Touched In Current Workstream
- `lib/custom/box_coverage/...`
- `test/custom/box_coverage/...`
- `lib/custom/team_search/...`
- `lib/custom/shared_teams/...`
- Thin integration points in:
  - `lib/app/modules/home/elements/gallery_item.dart`
  - `lib/app/routes/routes.dart`

## Validation Commands
- `fvm flutter analyze`
- `fvm flutter test`
- `fvm flutter build macos --debug`

## Notes For Safe Upstream Updates
- Prefer `./scripts/sync_fork_pr.sh --open-pr` for protected-main syncs; use `./scripts/sync_fork.sh` only for manual/non-protected flows.
- Resolve conflicts by preserving upstream behavior first, then re-apply custom
  integration hooks.
- Re-check custom module wiring after any upstream UI changes in battle modules.
