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
- Branch: main
- Last commit: 7b3d4fc9d
- Working tree status: dirty with new repo-local upstream automation scripts under `scripts/fork/`, plus updates to `AGENTS.md` and this handoff file
- Active feature(s): repo-local machine-friendly upstream sync script surface for sandbox automation
- What is done:
  - added `scripts/fork/check_upstream_updates.sh`
  - added `scripts/fork/prepare_upstream_sync_branch.sh`
  - added `scripts/fork/validate_upstream_sync.sh`
  - added `scripts/fork/push_upstream_sync_branch.sh`
  - added `scripts/fork/open_upstream_sync_pr.sh`
  - documented the machine-friendly fork automation surface in `AGENTS.md`
  - validated the new shell scripts with `bash -n`
  - smoke-tested upstream detection, branch preparation, validation exit behavior, and local push against temporary repos
- What is next:
  - decide whether `scripts/sync_fork_pr.sh` should start delegating to the new `scripts/fork/` helpers
  - wire the bounded agent apply step between branch preparation and push/PR creation
  - decide whether `.fvmrc` should be removed after any human-facing docs are updated
- Known blockers:
  - no repo-local agent apply script exists yet by design; merge/apply remains the judgment-heavy step
## Files Touched In Current Workstream
- `scripts/fork/check_upstream_updates.sh`
- `scripts/fork/prepare_upstream_sync_branch.sh`
- `scripts/fork/validate_upstream_sync.sh`
- `scripts/fork/push_upstream_sync_branch.sh`
- `scripts/fork/open_upstream_sync_pr.sh`
- `AGENTS.md`
- `HANDOFF.md`

## Validation Commands
- `fvm flutter analyze`
- `fvm flutter test`
- `fvm flutter build macos --debug`

## Notes For Safe Upstream Updates
- Prefer `./scripts/sync_fork_pr.sh --open-pr` for protected-main syncs; use `./scripts/sync_fork.sh` only for manual/non-protected flows.
- For machine-driven automation, prefer the new `scripts/fork/` entrypoints over the human wrapper when finer control is needed.
- Resolve conflicts by preserving upstream behavior first, then re-apply custom
  integration hooks.
- Re-check custom module wiring after any upstream UI changes in battle modules.
