# Repository Guidelines

## Current Focus: Laplace Auto 3T Search (v1.7b)
- Goal: Automated 3-turn (3T) search in Laplace Battle Simulation that finds and replays a winning sequence (skills + Mystic Code + one-or-more NPs per turn) using the existing engine. Team Search orchestrates candidates and replays the first success.
- Status: Stable. Team Search is the primary entry; single‑team Auto 3T was removed. Logs available from the menu.

### Key Files
- UI entry: `lib/app/modules/battle/battle_simulation.dart` (Team Search button; menu → Team Search Log)
- Solver: `lib/app/modules/battle/simulation/auto_three_turn_solver.dart` (search + logging)
- Team Search: `lib/app/modules/battle/simulation/auto_three_turn_team_search.dart` (candidate generation + orchestration)

### Core Assumptions
- Attacker is ally index `0`. No face cards; each turn ends by NP(s); attacker NP, if present, goes last.
- Ally-targeted skills default to attacker; enemy-targeted skills default to single target (highest‑HP).
- Engine APIs only; found plans are replayed into the simulator UI.

### Implemented Solver Behavior
- Deterministic delegate (fixed actSet; ptRandom allies → attacker).
- Order‑insensitive skill combinations per turn; try NP at every prefix (at least one NP per turn). If a wave doesn’t clear after NP(s), prune.
- Targeting: enemy single‑target actions use the highest‑HP alive enemy.
- Static ignores: survival‑only; crit/star‑only; “enemy NP readiness” (hasten/delay); bypass‑invul unless any enemy currently has Evade/Invincible.
- Always‑deploy (content‑aware): auto‑apply only long‑duration add‑states that are damage/NP‑relevant; excludes Order Change and direct `gainNp`.
- Battery gating (conservative): prune branch if no ally can reach 100% NP this turn even with all remaining castable batteries.
- Battery cutoff at full: once attacker NP ≥ 100%, skip further skills that would add NP to the attacker (servant or MC).
- Logging includes summary stats (branches, npAttempts, turnsVisited, maxSkillDepth, alwaysDeploy used, prunes).

### Team Selection (v2)
- Baseline: 1 attacker + 2 Castoria; variant: Plugsuit + Oberon (Order Change) with OC turn tries T3 → T2 → T1.
- Attacker pool: owned SSR Arts NP filtered by top 3 classes (bucket scoring) and NP shape:
  - If every wave has exactly one initial on‑field enemy → single‑target only
  - Otherwise → AoE only
- CE candidates: equipped CE (slot 0 exact LB/level), Black Grail #48 (owned), Kaleidoscope #34 (owned).
- Success auto‑replays in a fresh simulation. Summary is available via menu → Team Search Log (copyable).

### How to Run (dev)
1) Open a quest in Battle Simulation.
2) Click “Team Search 3T”. On success the plan auto‑replays; use menu → Team Search Log to inspect/copy the summary.

## Team Search 3T (details)
- Goal: Explore attacker + CE candidates for a 1‑attacker + 2‑Castoria composition and run the solver to find the first winning plan.

### Implemented Behavior
- Supports: two Artoria Caster (Castoria)
  - Slot 1 = owned Castoria (required; search aborts if not owned)
  - Slot 2 = support Castoria (skills 10/10/10, NP1, max level)
- Attacker candidates: owned SSR Arts NP; filtered by class scores and NP shape (ST vs AoE per node waves)
- Attacker ordering: Berserkers first; higher NP level; higher ATK tie‑breaker
- Mystic Code: Summer Streetwear (#330) baseline; Decisive Battle (#210) when testing Plugsuit + Oberon
- CE candidates (owned only): equipped CE (exact LB/level), Black Grail #48, Kaleidoscope #34
- Execution: runs the solver per candidate; stops on first success; opens a fresh sim page and replays the actions

### How to Run (team search)
1) Open a quest in Battle Simulation
2) Click “Team Search 3T” (success auto‑replays; use the menu for the summary)

## Plugsuit + Oberon Extension (v2.1)
- Goal: Extend team search by adding a plugsuit strategy (Order Change) with Oberon to boost damage/NP, while keeping the same per‑turn solver rules.

### Implemented Behavior
- Mystic Code passes per attacker (in order):
  1) Double Castoria + Summer Streetwear (#330) — same CE candidates as v2
  2) Double Castoria + Chaldea Uniform – Decisive Battle (#210) + Oberon (#316) in backup slot
- Order Change (OC) policy (plugsuit pass only):
  - OC is tried at most once per run; priority of OC turn is T3 → T2 → T1
  - Swap choice is deterministic: swap out slot 1 (owned Castoria) with backup slot 0 (Oberon)
  - Oberon S3 is only considered on turn 3 (as it ends attacker actions afterward); S1/S2 are regular skills
- Solver constraints remain:
  - Skills per turn are combinations (unordered), with “always‑deploy” excluding NP‑granting skills
  - One or more NPs per turn; attacker NP last; prune if the wave didn’t clear
  - Per‑turn dedup; logging + 60s timeout preserved

### Notes
- CE selection remains “owned only” with exact LB/level for both equipped CE and candidates (Black Grail #48, Kaleidoscope #34).
- First success short‑circuits and opens a new sim page with the chosen formation, then replays the plan.


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
