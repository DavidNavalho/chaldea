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
- Date: 2026-03-05
- Branch: automation/upstream-sync-2026-03-05
- Last commit: 26d53eb62
- Working tree status: clean on sync branch
- Active feature(s): upstream sync PR workflow hardening + PR conflict resolution
- What is done: rebuilt sync branch from origin/main, merged upstream/main, added scripts/sync_fork_pr.sh, updated AGENTS.md/HANDOFF.md workflow docs
- What is next: review and merge PR #1, then run full flutter analyze/test in unrestricted local env
- Known blockers: sandboxed automation environment has intermittent GitHub API/network and Flutter runtime restrictions
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
