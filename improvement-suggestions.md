# Auto 3T Search — Improvement Suggestions

This document lists potential extensions to reduce search time and improve hit rate for Auto 3T and Team Search strategies. It is a design backlog (no code changes implied) to be reviewed and prioritized.

## 1) Pre‑Ordering and Pruning by Encounter

- NP type vs wave pattern
  - while some strategies can use multiple attackers, we are going to cut our possibilities with focusing on a single-attacker solution (with 2 to 3 supports). As such, we can cut attacker choices as such: 
    - Only use AoE NP attackers if any wave has more then 1 enemy; 
    - Only use ST NP if all waves have a single enemy per wave; 

- Enemy trait alignment (optional)
  - If attacker’s NP/skills have SE (special effective) traits that match enemies (e.g., King, Threat to Humanity), promote such attackers.
    - this is an added ordering mechanism, to execute after we have chosen the classes we will experiment with. For example, if we have chosen Berserkers as our top attacking class, we can then order our attacker choices through a second prioritisation mechanism: higher NP level; special effective traits that can be taken advantage of in the fight;

## 2) CE Pre‑Selection Heuristics

- Event/Bond CEs
  - We currently allow user to force‑include via slot 0; a future improvement would be to be able to detect these CEs automatically for simplification.

## 3) Turn‑Level Feasibility Checks

- NP‑gauge feasibility (cheap prune)
  - Before expanding a skill prefix, estimate remaining battery potential this turn (from castable skills, MC, OC if available). If 100% NP is unreachable for the intended NP users, prune.

- Quick damage screen (cheap prune)
  - Before launching a full turn, do a coarse NP damage upper bound using known buffs and class/attribute advantage; if even the optimistic bound can’t clear the wave, prune. Needs to take into account OC, including the hardcoded fact that his S3 can only ever be used on turn 3.
  - Keep consistent with engine constants (use existing damage helpers) — this is a “screen”, not a final verdict.

## 4) Order Change (Plugsuit) Search Control

- OC timing priority (current: T3→T2→T1)
  - OC timing can be used in any turn. BUT the constraint NEEDS to be that his skill3 can never be used anywhere except turn 3, as it completely locks the attacker at the end of the turn, which makes it's usage 'only viable in turn 3. 

- Swap target policy (current: swap out owned Castoria)
  - Keep deterministic swap (slot 1 → Oberon from backup slot 0) to minimize branching.




-------------
## 11) Other/additional stuff

## 5) Skill Selection Tightening

- “Always‑deploy” expansion (still order‑insensitive)
  - Add more 3‑turn buffs that are damage‑relevant and do not grant NP (Atk Up, Arts Up, NP Damage Up, relevant trait buffs).
  - Exclude skills that solely grant stars or are otherwise irrelevant to damage/NP in this comp.


## 6) Deduplication Beyond Per‑Turn

- Coarse state memoization
  - Memoize visited states by (wave, turn, OC used flag, attacker NP charge bucket (e.g., number of battery steps to 100%), skill cooldown signature, and a hash of active long buffs).
  - If a state reappears via a different path, skip it. Note: this may actually be useful, because two units share the exact same skills (the artorias); But I'd still rather try to do at a later iteration...

-------------

What We Can Read

  - Skill effects: NiceFunction.funcType, funcTargetType, buffs, svals (Turn, Count, trait gates, conditions).
  - Buff semantics: BuffType and BuffAction mapping via ConstData.buffActions and buff_utils helpers.
  - Damage/NP math: Damage.damage(...) pulls exactly which BuffActions affect NP damage and refund.
  - Enemy context: wave dispClassId, traits, field traits; trait matchers exist (checkSignedIndividualities2, etc.).

  Damage/NP Awareness

  - Damage up (attacker side): BuffAction.atk, commandAtk (card color), npdamage, damage, damageIndividuality(_Activeonly),
  damageSpecial, givenDamage (flat).
  - Damage up (enemy side): commandDef (card resist), defence, damageDef, criticalDamageDef, npdamageDef, specialdefence — we
  want the “down” versions via debuffs/end-state.
  - NP refund: commandNpAtk, dropNp, dropNpDamage, per-turn turnendNp.
  - NP gauge now: gainNp, gainMultiplyNp, gainNpTargetSum, gainNpIndividualSum, etc.
  - Non-damage/non-NP categories: invincible, guts, avoidance, upDefence, gainHp, criticalPoint, starweight, criticalDamage,
  grantState for survival, etc.

  Hard “Ignore” (Safe Prune)

  - Survival-only: guts, invincible, avoidance, upDefence, damageCut variants, heal/regen only, debuff resist/cleanse, death
  resist.
  - Crit-only and star-only when we don’t use face cards: criticalDamage, criticalPoint, starweight, commandStarAtk,
  commandStarDef.
  - Command card buffs for colors not matching attacker’s NP color (e.g., commandAtk Quick on an Arts NP attacker).
  - Field/trait manipulation with no downstream damage/NP effect in our team (e.g., trait add with no matching powermod
  consumer; field changes with no field-dependent buffs).
  - Sure-hit/Invul-pierce unless any enemy spawns with Evasion/Invincible at start (pre-check spawn buffs; otherwise ignore).
  - Ally-target effects that cannot target the attacker and don’t apply enemy debuffs.

  Always-Early (Safe To Auto-Use)

  - 3T damage buffs: atk, NP-color commandAtk, npdamage, damageSpecial, relevant powermod (if any target trait present in
  waves).
  - 3T enemy side debuffs: defence down, commandDef down (NP color), npdamageDef down, specialdefence down (if they exist).
  - 2–3T NP refund/generation over time: dropNp (attack-side), turnendNp (regen), commandNpAtk (card NP rate) that last ≥2T.
  - 2–3T trait application that unlocks damage (only if a matching powermod exists on attacker’s NP/skills).

  NP-Related Timing

  - 1T damage buffs (any of: atk, NP-color commandAtk, npdamage, powermod): NP-turn only.
  - 1T enemy debuffs that increase damage: NP-turn only, on the wave being cleared.
  - NP refund 1T (dropNp 1T): use on or before a turn where NP is used to actually affect refund; prefer earliest viable turn.
  - Batteries:
      - For pure batteries: only consider use when needed to make the next NP threshold (no “spray and pray” timing variants).
      - Composite (battery + 3T buff): two safe modes only — “early” (T1) if the non-battery parts are ≥2T and no overflow-
  badness is provable, else “pre-NP”.
      - Team/targeted batteries: restrict to target = attacker, unless we explicitly allow a specific support NP plan.

  Trait/Enemy-Aware Pruning

  - Powermod vs trait: include only if any target across waves matches the trait; otherwise ignore.
  - Trait-apply (to self/enemy) + powermod synergy: only include the apply if a consumer buff is present on the attacker/NP;
  ignore otherwise.
  - Field buffs: only if the quest provides that field or our team can enable it and a consumer exists.

  Target Canonicalization

  - Ally buffs: constrain single-target to the attacker only.
  - Enemy debuffs (single-target): constrain to the NP’s main target for that wave (e.g., highest HP or the target that decides
  clear).
  - Support NPs: allow only if they convey damage/NP gain effects that persist (e.g., Castoria NP for Arts up/NP gain) and
  restrict to early waves (T1/T2); attacker NP always last in a turn.

  Duration Windows (Cast Windows)

  - 3T: T1 only.
  - 2T: T1 if NP is planned T1 or T2; otherwise T2.
  - 1T: NP-turn only.
  - This alone collapses many setups without needing to “guess” order.

  Effect-Level Dedup (State Fingerprint)

  - For the attacker per turn, hash a damage/NP “fingerprint” from only relevant buffs/debuffs:
      - atk, NP-color commandAtk, npdamage, special/powermod sum, enemy defence/commandDef/npdamageDef downs relevant to NP,
  dropNp and commandNpAtk, NP gauge.
  - If a skill subset leads to an identical fingerprint and identical remaining durations for 1T/2T effects, prune duplicates.

  Micro-Sim “No-Effect” Screens (Optional, Cheap)

  - On a snapshot, apply a candidate skill, then query just the attacker’s NP damage parameters for the current wave or the
  next wave; if all damage/NP-relevant aggregates remain identical, mark the skill as “no-op” in this context and prune.
  - Use only on single skills or very small bundles to avoid spending the budget.

  Batteries: Safe Reduction Without Guessing

  - Disallow using batteries that do not change whether the next NP is achievable (i.e., if current + known regen + refund ≥
  threshold without it, don’t try the battery).
  - For party batteries, consider only the minimal set needed to reach threshold; do not explore “extra” battery stacks unless
  OC scheduling (e.g., v2.1 OC plan) explicitly uses them.

  Edge Cases To Keep

  - Ignore-invincible/sure-hit when enemies start with Evasion/Invincible or scripts apply it at spawn.
  - Enemy forced survival mechanics or fixed damage gimmicks (rare) — if detected in node scripts, skip pruning for those
  toggles.

  How This Shrinks The Space

  - Drops pure survival and crit/star skills outright.
  - Restricts all 1T damage/1T debuffs to NP-turn only.
  - Forces 3T into T1, 2T into T1/T2 only.
  - Limits batteries to “needed-to-hit-NP” moments and attacker-target only.
  - Canonicalizes targets and removes same-state duplicates.
  - Skips trait/field effects with no consumer or no matching enemies.

  Low-Risk Next Steps

  - Add a skill intent classifier that tags each function/buff into:
      - damage-now, damage-later (duration ≥2T), enemy-debuff-damage, np-gain-now, np-refund, survival-only, crit/star-only,
  trait/field-only.
  - Precompute an EnemyContext per wave: traits, classes, attributes, spawn buffs (evasion/invincible), field traits.
  - Enforce cast windows + target canonicalization + trait gating in the solver’s skill collection (no new sim logic; just
  filtering).
  - Optional: add a cheap “fingerprint” dedup layer per turn to cut redundant combos.


------------------
Notes:       

Med prio
- Enemy-target skills target the first alive enemy. -> target highest HP enemy instead
- nothing based on aoe vs single target, definitely should do that to remove attacker's pool;
High prio: reduce combinations

So here's the buckets I see:
- anything that gains immediate NP (let's reffer to it as NP battery), goes into the NP bucket. Regardless of other skills it may have;
- after this, any skill that contains at least a state that increases attack in any way OR NP-gain per turn, should go into the immediate activation IF it is within the 3-turn math we already do (i.e. if it lasts 3 turns, apply immediately, if it lasts 2 turns, apply either on turn 3 or 2, but always apply on turn 2, etc); Attack skills are skills that directly impact damage, which includes Atak up, NP damage up, Arts up, .
- Remaining skills do not need to be activated, if they don't impact NP damage in any way (i believe this can be checked through the engine?). 

does this sound like a plan that can further cut skills? can you evaluate? And suggest additional item s that can potentially cut skills, but i will want to go one step at a time...don't do any implementations yet.
