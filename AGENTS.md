# Repository Guidelines

## Current Focus: Laplace Auto 3T Search (v1.1)
- Goal: Automated 3-turn (3T) search in Laplace Battle Simulation that finds and replays a winning sequence (skills + Mystic Code + one-or-more NPs per turn) using the existing engine.
- Status: v1.1 stable baseline implemented (fast on common 1 attacker + 2 supports). Further performance/features will be added incrementally (TBD) under explicit specs.

### Key Files
- UI entry: `lib/app/modules/battle/battle_simulation.dart` (adds an “Auto 3T” button and failure logs dialog)
- Solver: `lib/app/modules/battle/simulation/auto_three_turn_solver.dart` (search and logging)

### v1.1 Assumptions
- Fixed formation; attacker is ally index `0`. End each turn by casting attacker NP only (no face cards).
- Ally-targeted skills go to attacker; enemy-targeted skills go to the first alive enemy.
- Mystic Code skills are allowed. Order Change is forbidden.
- Uses engine APIs exclusively (no custom damage/NP logic). Always replays found plan into the simulator UI.

### v1.1 Implemented Behavior
- Team pattern: 1 attacker (index 0) + 2 supports (1, 2). Inputs (team/CE/MC) are user-provided.
- Hard constraints:
  - Exactly 3 turns.
  - Each turn ends with one or more NPs (from any ally); attacker NP, if present, goes last. If the wave is not cleared after the turn’s NP(s), prune.
- Skill selection per turn:
  - Skills are treated as combinations (unordered). Chosen skills are applied in a canonical order for determinism/dedup.
  - “Always-deploy” at the start of the turn (especially turn 1): auto-apply usable skills that do NOT grant NP (e.g., no `gainNp`), are not Order Change, and grant add-state buffs whose duration ≥ remaining turns; targeting is to attacker/self via rules below.
  - Any skill that grants NP is not “always-deploy” (kept for combinational search).
- Targeting rules:
  - Ally-targeted → attacker (index 0). Self-target stays self. Enemy-targeted → first alive enemy.
- NP combos per turn:
  - Try subsets of support NPs first (indices 1,2), then optionally attacker NP last (index 0). Requires at least one NP per turn.
- Early pruning:
  - After executing the selected NP set, if the wave didn’t clear, prune immediately (no face cards).
- Dedup:
  - Per-turn dedup by unordered set of used skills: tuples `(svtIndex, skillIndex)` and `(mcSkillIndex)` (order ignored), with targeting fixed by rules above.
- Timeout & logs:
  - Default timeout 60s. On completion (success/no-solution/timeout) logs include a summary (elapsed, branches, turns visited, skill apps, NP attempts, max skill depth).
  - On failure a dialog shows the summary + full logs with “Copy Logs”.

### Next Iterations (High-Level, Not Yet Implemented)
- Additional team archetypes (order change, double attacker, rotations) with tailored rules.
- Optional feasibility pruning (NP gauge / optimistic damage oracles) if specified.
- Broader state dedup / memoization if needed.

### How to Run (dev)
1) Setup the team and quest in Simulation Preview.
2) Press Start to enter Battle Simulation.
3) Click “Auto 3T” to run the search; on success the actions are replayed; on failure open the dialog to view/copy logs.

## Team Search 3T (v2)
- Goal: Don’t assume a fixed team. Explore attacker + CE candidates for a 1‑attacker + 2‑support (double Castoria) composition and run the v1.1 solver to find the first winning plan.

### Implemented Behavior
- Supports: two Artoria Caster (Castoria)
  - Slot 1 = owned Castoria (required; search aborts if not owned)
  - Slot 2 = support Castoria with max reasonable stats (skills 10/10/10, NP1, max level)
- Attacker candidates: all owned SSR servants with at least one Arts NP
- Attacker ordering heuristic (to reduce time):
  1) Berserkers first
  2) Higher NP level (owned) first
  3) Higher ATK as tie‑breaker
- Mystic Code: uses the current user‑selected MC
- Attacker CE candidates (owned only):
  - The CE currently equipped on attacker slot in Simulation Preview (exact LB and level)
  - The Black Grail (#48) — MLB if owned MLB, else best available LB and owned level
  - Kaleidoscope (#34) — MLB if owned MLB, else best available LB and owned level
  - Event CE: skipped unless the user equips it in slot 0 (then it’s included automatically)
- Execution: runs the v1.1 solver per candidate, stops on first success; opens a fresh sim page with the selected formation and replays the actions

### How to Run (team search)
1) Set quest and MC in Simulation Preview (leave attacker empty if you want the tool to search)
2) Start to enter Battle Simulation
3) Click “Team Search 3T”
   - On success: a new page opens with the chosen attacker + CE and two Castorias, then replays the run
   - On failure: simple dialog “No team found” (we can add aggregate logs later if needed)


## Project Structure & Module Organization
- Source code in `lib/` (feature modules under `lib/app/...`; models under `lib/models/...`).
- Generated files in `lib/generated/` — do not edit by hand; re‑generate via scripts.
- Tests in `test/` mirroring `lib/` structure (files end with `_test.dart`).
- Assets in `res/` (images, fonts, js); web shell in `web/`.
- Platform runners in `windows/`, `linux/`, `macos/`, `ios/`.
- Utility scripts in `scripts/`.

## Build, Test, and Development Commands
- Install deps: `flutter pub get`
- Generate code (json/intl): `sh scripts/build_runner.sh` and `dart run scripts/gen_l10n.dart`
- Format & sort imports: `sh scripts/format.sh`
- Static analysis: `flutter analyze`
- Run tests: `flutter test`
- Run locally (web): `flutter run -d chrome`
- Build web release: `flutter build web`

## Coding Style & Naming Conventions
- Dart/Flutter lints from `analysis_options.yaml` (page width 120). Use 2‑space indent.
- Prefer explicit types and `final`; avoid `var`/`dynamic` where possible.
- Keep imports sorted (script handles this). One export barrel per module when helpful (e.g., `lib/widgets/widgets.dart`).
- Files: `snake_case.dart`; Classes: `PascalCase`; members/functions: `lowerCamelCase`.
- Do not modify files under `lib/generated/`.

## Testing Guidelines
- Framework: `flutter_test`.
- Place tests under `test/` with `_test.dart` suffix (e.g., `test/app/battle/utils/battle_utils_test.dart`).
- Aim for fast, deterministic unit tests; prefer module‑mirrored layout.
- Run all tests: `flutter test` (optionally target a path for focused runs).

## Commit & Pull Request Guidelines
- Commits: concise, imperative summaries (e.g., "Fix gacha draw condition", "Update dependencies"). Group related changes.
- PRs: clear description, link issues, include screenshots/GIFs for UI changes.
- Before submitting: run generator scripts, `sh scripts/format.sh`, `flutter analyze`, and `flutter test`.

## Security & Configuration Tips
- Never commit secrets or platform credentials. Avoid editing build artifacts.
- If adding localization keys, run `dart run scripts/gen_l10n.dart` and keep ARB files consistent.
