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
- Date: 2026-04-20
- Branch: automation/agent-remediation-smoke
- Last commit: 85cc36f9d
- Working tree status: dirty with smoke-test remediation docs only (`AUTOMATION_REMEDIATION_SMOKE.md`, `HANDOFF.md`)
- Active feature(s): bounded upstream-sync remediation smoke validation on the prepared automation branch
- What is done:
  - resumed the prepared remediation worktree on `automation/agent-remediation-smoke`
  - ran `./scripts/fork/validate_upstream_sync.sh` successfully against current `origin/main` + upstream state
  - confirmed the branch is mechanically clean relative to `origin/main` aside from the smoke-test branch docs
- What is next:
  - if this smoke branch is meant to persist, commit the smoke-test docs, push the branch, and open/update the PR
  - otherwise delete the disposable smoke branch after automation verification is complete
- Known blockers:
  - none at snapshot time; publish steps depend on GitHub credentials and remote availability
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
