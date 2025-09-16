# Auto 3T Search — Improvement Suggestions

This document lists potential extensions to reduce search time and improve hit rate for Auto 3T and Team Search strategies. It is a design backlog (no code changes implied) to be reviewed and prioritized.

## 1) Pre‑Ordering and Pruning by Encounter

- Class relation scoring (done for class; candidate: add attribute)
  - Current: weighted per‑wave class relation (1.0, 1.2, 1.5) to pick top attacker classes.
  - Next: include attribute relation (Man/Sky/Earth/Star/Beast) with the same wave weighting.
  - Optional: weight waves by total enemy HP or boss/break bars (harder waves more impactful than mobs).

- NP type vs wave pattern
  - Prefer AoE NP attackers if most waves have 2–3 enemies; prefer ST NP if single/boss waves dominate.
  - Demote or skip attackers whose NP type mismatches the dominant wave pattern (unless Plugsuit+Oberon can compensate).

- Enemy trait alignment (optional)
  - If attacker’s NP/skills have SE (special effective) traits that match enemies (e.g., King, Threat to Humanity), promote such attackers.
  - Otherwise demote or skip when time budget is tight.

## 2) CE Pre‑Selection Heuristics

- Kscope vs Black Grail ordering
  - If T1 NP gauge shortfall is large, try Kaleidoscope first; if T1 charge path is easy and boss wave has high HP, try Black Grail first.
  - In Plugsuit runs with OC on T3, default to Black Grail first (BG synergizes with late damage burst and Oberon S3).

- Event/Bond CEs
  - Allow user to force‑include via slot 0; otherwise ignored unless reliable event detection exists.

## 3) Turn‑Level Feasibility Checks

- NP‑gauge feasibility (cheap prune)
  - Before expanding a skill prefix, estimate remaining battery potential this turn (from castable skills, MC, OC if allowed this turn). If 100% NP is unreachable for the intended NP users, prune.

- Quick damage screen (cheap prune)
  - Before launching a full turn, do a coarse NP damage upper bound using known buffs and class/attribute advantage; if even the optimistic bound can’t clear the wave, prune.
  - Keep consistent with engine constants (use existing damage helpers) — this is a “screen”, not a final verdict.

## 4) Order Change (Plugsuit) Search Control

- OC timing priority (current: T3→T2→T1)
  - Keep trying T3 first, then T2, then T1. If any T3 succeeds with a CE, skip earlier OC turns for the same CE.

- Swap target policy (current: swap out owned Castoria)
  - Keep deterministic swap (slot 1 → Oberon from backup slot 0) to minimize branching.
  - Optional: allow swap out slot 2 if slot 1 has a long‑tailed buff that should remain (only if needed).

## 5) Skill Selection Tightening

- “Always‑deploy” expansion (still order‑insensitive)
  - Add more 3‑turn buffs that are damage‑relevant and do not grant NP (Atk Up, Arts Up, NP Damage Up, relevant trait buffs).
  - Exclude skills that solely grant stars or are otherwise irrelevant to damage/NP in this comp.

- Combinational depth bounds
  - Bound maximum number of non‑always skills per turn from a heuristic (e.g., useful buff count + battery steps required), not a raw cap.

## 6) Deduplication Beyond Per‑Turn

- Coarse state memoization
  - Memoize visited states by (wave, turn, OC used flag, attacker NP charge bucket (e.g., number of battery steps to 100%), skill cooldown signature, and a hash of active long buffs).
  - If a state reappears via a different path, skip it.

## 7) Search Budgeting

- Per‑candidate time budget
  - Cap solver time per attacker×CE×mode; move on if exceeded.
  - Revisit budget only for top‑scored classes/CEs if nothing succeeded.

- Iterative skill‑depth widening
  - Maintain the current NP‑at‑each‑prefix approach, but widen depth progressively and stop once a success is found.

## 8) Attacker Subset Curation

- Loopers vs bursters
  - For 3× mob nodes: prioritize loopers (AoE, good NP refund, batteries).
  - For boss nodes: prioritize ST bursters (strong ST NP, power/SE mods).

- Demote/skip low‑synergy attackers
  - E.g., off‑card color NPs when double Castoria is assumed; attackers with poor batteries for T1; etc.

## 9) Parallelization Considerations

- Isolates (true parallelism)
  - Feasible but high overhead: would require isolate‑safe data, avoid UI/context, and replicate immutable game state per worker. Consider only if single‑threaded pruning isn’t sufficient.

- Futures (same isolate)
  - Not real parallelism; limited benefit for CPU‑bound work.

- External worker processes
  - Heavy orchestration and IPC; likely overkill for an in‑app solver.

Recommendation: focus first on smarter pruning/ordering (Sections 1–8). Consider isolates only after the above improvements, if wall‑clock remains an issue on desktop.

## 10) Prioritization (Suggested)

1) Add attribute relation to class scoring; weight waves by HP/boss presence (low effort, high ROI).
2) CE ordering heuristic (Kscope vs BG) based on T1 battery and boss wave dominance.
3) NP type vs wave pattern demotion.
4) Expand “always‑deploy” to relevant 3‑turn buffs and skip irrelevant skills.
5) NP‑gauge feasibility prune and quick damage screen.
6) OC timing “stop early” rule; keep deterministic swap.
7) Coarse state memoization.
8) Optional: attacker subset curation by trait synergy.
9) Only if needed: isolate‑based parallelism with a trimmed, isolate‑safe sim core.

