# Lab Note 046 — The Logic Temperature Map: All 15 Logics, One Thermometer

**Date**: 2026-08-26 (overnight session)
**Follows**: 045_logical_temperature.md, 006_the_hopf_7_skeleton_of_logic_space.md
**Status**: PROVEN + MIRRORED

## 1. Question

Lab note 038/045 established the temperature of *paraconsistent* logic
(T ≈ 4 159 K under the Landauer anchor). This note answers the natural
follow-up: **what is the temperature of every named logic**, and **how many
critical points does the algebra actually contain?**

## 2. Method

Temperature lives on the **tower-height axis** (cdStep), not the cost-geometry
axes. Lab note 006 separated these: seven NodeCost configurations P₀–P₆ map
onto split-octonion axes e₁–e₇ (direction of Φ), while cdStep measures how far
up the Cayley-Dickson tower a logic sits (height of Γ). Two logics sharing a
cost geometry can sit at different heights — Classical and Modal both have the
null configuration P₀, yet their temperatures differ by Γ = 19 units.

The authoritative height assignment is `LogicType.cd_step()` in
`infra/_cortex/_logic_types.py` (all 15 logics; consistent with sector
membership). It is mirrored exactly as `logicCd : LogicName → ℕ` in
`LaserCortex/LogicalTemperature.lean` §7, and re-mirrored as `LOGIC_CD` in
`scripts/logical_temperature.py`.

## 3. The map (Landauer anchor, T_op = 300 K, T = Γ · T_op · ln 2)

| T (K) | Γ | CD | Logics | Sector |
|---|---|---|---|---|
| 0 | 0 | 0 | classical, boolean | associative (vacuum) |
| 207.94 | 1 | 1 | fuzzy, many_valued, temporal, deontic, epistemic | associative |
| 415.89 | 2 | 2 | intuitionistic | associative |
| **3 950.94** | 19 | **3** | quantum, relevance, infinitary, **modal**, spacetime | **split — critical point** |
| 4 158.88 | 20 | 4 | paraconsistent, free | split (deep) |

Reading:

- The five "hot personality" logics {fuzzy, many-valued, temporal, deontic,
  epistemic} collapse onto ONE thermal rung: ≈ 208 K, barely above room
  temperature. Five distinct logical characters, one thermodynamic address.
- Intuitionistic logic is alone at 416 K.
- **Modal logic sits exactly AT the critical point** (`modal_at_critical_point`
  proves `logicCd .modal = criticalCd`). Modal reasoning — possible worlds,
  necessity, possibility — lives on the associativity-loss boundary itself.
  Its temperature is 19 · T_op · ln 2 ≈ 3 951 K, one commutator unit below
  paraconsistent.
- Quantum, relevance, infinitary and spacetime logics are *thermally
  indistinguishable* from modal logic: same rung, same heat.
- The hottest named rung is shared by contradiction (paraconsistent) and will
  (free): `logicTemp_le_paraconsistent` proves nothing named is hotter.

## 4. Critical-point census (Lean §8)

Theorem `gamma_increment`: for every k,

    Γ(k+1) − Γ(k) = 17 if k = 2, else 1.

So the ladder has **exactly one discontinuity** — the associator onset at
CD 2→3 (commutator contributes +1, strut² contributes +16; ratio 9.5×).
Corollaries proven:

- `gamma_only_jump_at_cd2_3` — away from k=2 every step costs exactly one
  commutator unit (T_op·ln 2 ≈ 207.94 K at room anchor).
- `barrierTemp_mono` / `gamma_le_gamma4` / `logicTemp_le_paraconsistent` —
  barrier temperature is monotone in energy; named logics are bounded above
  by the paraconsistent/free rung.

## 5. What this does NOT say (open question carried from lab note 006 §Q4)

Current Γ has a single critical point because `assocDefect` activates once
(at CD 3). Whether the sedenion level (CD 4+) hosts a *second* defect class
(loss of alternativity → `alternDefect`) is an open structural question. If
found, the census would gain a second jump and CD 5 would become a second
critical point. Nothing currently formalized requires or forbids this.

## 6. Artifacts

- `LaserCortex/LogicalTemperature.lean` §7–8 — 13 new theorems, all
  axiom-checked ([propext, Classical.choice, Quot.sound] only;
  `modal_at_critical_point` axiom-free).
- `scripts/logical_temperature.py` — `LOGIC_CD`, `logic_temperature`,
  `critical_point_census`; full map + census printed by main().
- Cross-checks pass: Lean `logicCd` ≡ Python `cd_step()` ≡ script `LOGIC_CD`.

## 7. Follow-ups

1. Alternativity defect at CD ≥ 4 (would add a second critical point).
2. Reconcile `_wfc.py::friction_density`'s dimension_index proxy with the
   authoritative CD-step Γ (flagged divergence, unchanged).
3. Thermal interpretation of cost geometry: do the P₀–P₆ axes behave like
   *phases* coexisting at fixed temperature?
