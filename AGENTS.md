# Repository Guidelines

## Current Focus: Laplace Auto 3T Search (v1)
- Goal: Add an automated 3-turn (3T) strategy search to Laplace Battle Simulation that finds and replays a winning sequence (skills + Mystic Code + NP each turn) using the existing battle engine.
- Status: v1 implemented with full backtracking + logging; performance optimizations and additional features will be added incrementally (TBD) as directed.

### Key Files
- UI entry: `lib/app/modules/battle/battle_simulation.dart` (adds an “Auto 3T” button and failure logs dialog)
- Solver: `lib/app/modules/battle/simulation/auto_three_turn_solver.dart` (search and logging)

### v1 Assumptions
- Fixed formation; attacker is ally index `0`. End each turn by casting attacker NP only (no face cards).
- Ally-targeted skills go to attacker; enemy-targeted skills go to the first alive enemy.
- Mystic Code skills are allowed. Order Change is forbidden.
- Uses engine APIs exclusively (no custom damage/NP logic). Always replays found plan into the simulator UI.

### v1 Search Behavior
- Depth-first search over permutations of usable skills per turn; attempts NP at every prefix; strict 3-turn bound.
- Stops on first success; otherwise times out after 60 seconds (default) or exhausts the space.
- Detailed logs captured in-memory; on failure a dialog shows summary + full logs with “Copy Logs”.

### Next Iterations (High-Level, Not Yet Implemented)
- Constrain choices per turn (provided externally), prune with feasibility checks (NP gauge/damage), deduplicate states, or switch to guided/iterative strategies. Implementation will follow explicit specs before changes.

### How to Run (dev)
1) Setup the team and quest in Simulation Preview.
2) Press Start to enter Battle Simulation.
3) Click “Auto 3T” to run the search; on success the actions are replayed; on failure open the dialog to view/copy logs.


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
