# Theorem Statement Sheet — LaserCortex, core results

*Machine-checked in Lean 4 (mathlib), no `sorry`, no axioms beyond `propext`,
`Classical.choice`, `Quot.sound`. Lean names in `monospace` refer to the
buildable modules `LaserCortex.SubdivisionClosure`, `LaserCortex.AMM`,
`LaserCortex.LogicalTemperature`, `LaserCortex.Friction`, and
`LaserCortex.TamariMetric`.*

---

## 0. Objects

- `EMLTree`: binary trees `Leaf | Node l r` — the syntax of composition in
  non-associative algebra (the Cayley–Dickson tower's nesting structure).
- `dcStep t : ℕ` — minimal number of associativity rotations
  (`contracts_one`: `Node (Node a b) c ↦ Node a (Node b c)`) to reach the
  right comb; equivalently the number of "inversions" of `t`.
- `frictionDensity k : ℕ` — the per-rotation grind at Cayley–Dickson level `k`:

  Γ₀..Γ₇ = 0, 1, 2, 19, 20, 21, 22, 23  (Γ_k = k for k ≤ 2; k+16 for k ≥ 3)

  with a **unique jump** Γ₂ = 2 → Γ₃ = 19 at the split-octonion transition.
- `weightedCost cd t = frictionDensity cd * dcStep t` — total cost.

## 1. The composition law (SubdivisionClosure)

**Thm** `dcStep_node_compose`
```
dcStep (Node l r) = dcStep l + dcStep r + rightSpine l
```
Grafting is additive in the parts **plus a coupling term** equal to the
right-spine depth of the left subsystem.

**Cor** `dcStep_node_superadditive` — `dcStep l + dcStep r ≤ dcStep (Node l r)`,
with equality `dcStep_node_eq_iff_left_leaf` iff the left side is a leaf.

**Thm** `weightedCost_mixed_dominance`
```
weightedCost c₁ t₁ + weightedCost c₂ t₂ ≤ weightedCost (max c₁ c₂) (Node t₁ t₂)
```
Mixing two regimes evaluates at the hotter (more non-associative) one.

## 2. Regime collapse

**Thm** `weightedCost_assoc_regime` — `cd ≤ 2 ⇒ weightedCost cd t = cd * dcStep t`.
**Thm** `weightedCost_nonassoc_regime` — `3 ≤ cd ⇒ weightedCost cd t = (cd + 16) * dcStep t`.
**Thm** `weightedCost_monotone` — cost is monotone in `cd`.
**Thm** `weightedCost_eq_zero_iff` — for `cd > 0`, zero cost ⇔ right comb
(the unique closure / normal form). `closure` is idempotent
(`closure_idempotent`) and is the `contracts_to` target (`contracts_to_closure`).

## 3. Temperature (Landauer anchor)

`LandauerCalibration` fixes `T = Γ · T_op · ln 2`, `T_op = 300 K`, giving unit
**207.944 K**. Consequences (`LogicalTemperature`):
- `classical_absolute_zero`, `boolean_absolute_zero` — CD 0 at 0 K.
- `paraconsistent_barrier_temperature` — CD 4 at **4159 K** (paraconsistency
  is thermodynamically "free" only above this barrier).
- `modal_at_critical_point` — the modal logic sits exactly at CD 3 (the jump).
- `gamma_increment`, `gamma_only_jump_at_cd2_3` — the friction sequence has a
  single jump, at 2 → 3.

## 4. Loose coupling — the risk window (SubdivisionClosure §10)

**Def** `looseCost cd num den l r = (dcStep l + dcStep r)·γ + num·rightSpine l·γ / den`
with trust compliance `λ = num/den ≤ 1`.

- **Thm** `looseCost_le_weightedCost` — loosening never exceeds the strict cost.
- **Thm** `looseCost_discount_exact` — strict − loose = `S − num·S/den` exactly,
  where `S = rightSpine l · γ` (the coupling/interface contribution).
- **Thm** `boundary_retreat_linear_in_load` (Hooke, over ℚ) —
  `Δ = (1 − λ) · (rightSpine l · γ)` : the certification boundary retreats
  **linearly** in the load, with slope set by the trust compliance.
- **Thm** `looseCost_zero_coupling_free` — zero coupling (λ=0) is free between
  already-closed systems.
- **Thm** `looseCost_mono_in_trust` — cost is monotone in the trust parameter.

## 5. Market invariants (AMM)

- **Thm** `associatorCostTree_eq_frictionDensity` — the associator cost is
  exactly Γ (the jump at CD 3 is the associator switching on).
- **Thm** `crossImpactTree_eq_rightSpine_mul` — cross-impact = right spine × Γ.
- **Thm** `classical_logic_market_always_open` — classical logic admits no
  paradox market (cost 0 ⇒ never insolvent).
- **Thm** `looseMarketType_paradox_iff` — a loosened market is a paradox
  market iff the loose cost still reaches the reserve.
- **Thm** `loose_never_damns` — loosening rescues without converting a safe
  closure into a damnation.
- **Thm** `rescue_envelope_bounded_by_coupling` — the rescue envelope is
  bounded unconditionally by the coupling term `S`.
- **Thm** `institutional_triad_friction` — temporal = fuzzy = deontic at CD 1
  (zero axioms), the institutional triad collapses to one friction.
- **Thm** `closedMarket_monotone_in_reserve` — the deontic ratchet: a closed
  market stays closed as reserve tightens.

## 6. The metric (C2 potentiality) — now a theorem

**Thm** `TamariMetric.dcStep_eq_geodesic`
```
dcStep t = the minimal number of contracts_one rotations to reach rightComb t.size
```
i.e. the greedy rotation count is the **geodesic** count in the flip graph.
Proven in `LaserCortex.TamariMetric` (no `sorry`, no axioms) via:
- `dcStep_contracts_one_le` — each rotation drops `dcStep` by at most 1
  (the crux; a left-subtree rotation can leave `dcStep` unchanged).
- `dcStep_le_contracts_to_steps` — lower bound (any path has length ≥ `dcStep`).
- `contracts_to_steps_of_dcStep` — achievability (greedy reaches in `dcStep` steps).

Exhaustive computational check (196 trees, sizes ≤ 6) now *confirms* rather
than substitutes for the proof. Since `weightedCost cd t = γ · dcStep t`, the
γ-weighted cost is γ times the geodesic distance.

**Open** (C5): minimality/uniqueness — any C2-satisfying metric is dominated
by `d`.

---

*Build:* `scripts/lake-wrap.sh -- lake build LaserCortex.TamariMetric LaserCortex.SubdivisionClosure LaserCortex.AMM`
*Formalization:* Lean 4, toolchain v4.31.0-rc1. Axiom audit clean.
