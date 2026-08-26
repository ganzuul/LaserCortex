# Lab Note 050 — Elasticity of the Certification Boundary

**Date**: 2026-08-26
**Follows**: 048_amm_phase_diagram_composable_logics.md, 049_loose_coupling_risk_window.md
**Status**: PROVEN + COMPUTED

## 1. Question

Curvature-and-perturbation language never stuck to this structure. Is that a
vocabulary failure, or does the structure genuinely lack the corresponding
notions — elasticity in particular?

**Answer**: the structure is not primarily geometric; it is
*thermomechanical*. And it supports a literal linear response law — we had
already proven it in 049 without naming it. This note names it.

## 2. Terminology: invented ↔ established

| Invented term | What it names | Nearest established concept |
|---|---|---|
| **heat of reason / defect altitude** | logic temperature T(logic), CD level | effective temperature; degree of nonassociativity |
| **grind (γ)** | frictionDensity — cost per unit route at a logic's algebra | dissipation coefficient |
| **spine tax / output-chain toll** | `rightSpine l · γ` cross-impact | interface energy; boundary term; coupling constant |
| **composition ledger** | `dcStep_node_compose` exact law | cocycle condition; telescoping valuation |
| **certification threshold** | reserveB: liquid/superheat yield point | yield strength |
| **damnation** | paradox phase, contagious (`paradox_dominance`) | percolation; systemic contagion |
| **forgiveness modulus / trust compliance** | λ = num/den discount on coupling | compliance (inverse stiffness) |
| **risk window** | boundary retreat under λ < 1 | elastic regime within Hookean limit |
| **deontic ratchet** | `closedMarket_monotone_in_reserve` | ratchet effect; monotone filtration |
| **isothermal institutions** | triad at CD 1: same heat, different geometry | degeneracy manifold; symmetry orbit |

## 3. The Hooke reading, formalized (SubdivisionClosure §10)

Two new axiom-clean declarations:

- **`boundary_retreat_linear_in_load`** — over ℚ, in the quantized elastic
  regime (`hdiv : den ∣ num · rightSpine l · γ`, i.e. trust denominated in
  whole cost units):

      retreat = (1 − λ) · S,     S = rightSpine l · γ(cd)

  **Retreat of the certification boundary is exactly proportional to the
  applied load.** Compliance = 1 − λ; load = spine tax; elastic limit =
  `AMM.rescue_envelope_bounded_by_coupling`; beyond the limit the route
  fails plastically into paradox. Stated over ℚ because over ℕ truncated
  division loses the remainder — quantization of trust into whole cost
  units is exactly what makes the discrete system Hookean.

- **`looseCost_mono_in_trust`** — compliance is a soft knob: increasing λ
  never increases the discounted cost. The response is monotone in both
  directions (more forgiveness ⇒ cheaper composites ⇒ smaller retreat).

## 4. Computed verification

Added to `run_loose_coupling_sweep()`:

```
    Hooke linearity retreat = (1−λ)·S: OK
```

Exact equality inside the quantized regime (`den ∣ num·S`); deviation < 1
cost unit outside it — the remainder loss, bounded by one grain of grind.

Full sweep still green: 1300 states, 64 rescues, 0 damnation violations,
0 envelope violations.

## 5. Interpretation

The certification boundary behaves like a **loaded diaphragm**:

| Mechanical notion | Formal object |
|---|---|
| Load | S = rightSpine l · γ (spine tax of the graft) |
| Compliance | 1 − λ (inverse trust) |
| Displacement | strict − loose cost |
| Hooke's law | `boundary_retreat_linear_in_load` |
| Elastic limit | `rescue_envelope_bounded_by_coupling` (≤ S) |
| Plastic failure | paradox phase (irreversible by `loose_never_damns`'s converse reading) |
| Ratchet | `closedMarket_monotone_in_reserve` |

What the structure still lacks for full mechanics language: a *metric on
tree space* (distance between routes). Prior art in-repo:
`ImpedanceMetric.lean` (041), `CoherenceMetric.lean`. Tamari rotations are
the natural neutral strain — reassociation changes shape without changing
yield, i.e. gauge freedom that does no net work.

## 6. Session mechanics / gotchas

1. Core ℕ lemma argument orders are treacherous: `Nat.mul_le_mul_left`
   multiplies on the LEFT (`k·m ≤ k·n`), so for right-multiplication use
   `Nat.mul_le_mul h le_rfl`; sums via `Nat.add_le_add le_rfl …` rather
   than `add_le_add_left` with metavariables.
2. Cast hygiene over ℚ: state the theorem with term-wise casts from the
   start; then `Nat.cast_sub` isn't needed. `push_cast` splits sum casts
   but leaves `↑(a/b)` alone (correctly — divisibility needed), so prove
   `hq` separately via `Nat.mul_div_cancel_left`.
3. Python mirror must respect the quantization hypothesis: exact Hooke
   check only when `den ∣ num·S`, remainder-bound `< 1` otherwise.

## 7. Next steps

- Metric on tree space: connect ImpedanceMetric to spine tax; strain =
  Tamari distance, stress = friction work.
- Earned trust: λ(state) as a function of accumulated blame-pool balance,
  making compliance history-dependent (viscoelasticity).
- Check how much of §9–§10 admits rfl-level reasoning (the triad theorem
  already needs zero axioms).
