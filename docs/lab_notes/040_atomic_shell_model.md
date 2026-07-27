# Lab Note 040 — Atomic Shell Model From the Metric Space

**Date**: 2026-07-27
**Status**: Formalized and proven in `LaserCortex/foundations/AtomicShell.lean`
**Builds**: 8541 jobs, clean

## 1. Executive Summary

The two-shell atomic spectrum — a coarse shell separated by the 9.5×
`frictionDensity` wall at cd 2→3 and a fine shell given by the (5,3)
antipode-copairing form — has been derived as a *theorem* in
`foundations/AtomicShell.lean`. The model assembles three previously-proven
ingredients into a single predictive structure, and a witness-based
existence theorem (`fundamental_atomic_transition`) shows that octonion
multiplication produces a concrete, certified state transition: fine shell
2 → 0 within coarse shell A, with conserved (4,4) charge.

The result formalises the splitting of the (4,4) "conserved charge" and
the (5,3) "transition energy" — the dual charge/energy structure that an
atomic model needs.

## 2. Three Proven Ingredients (Recap)

| Ingredient | Source | Role in model |
|------------|--------|---------------|
| `octonion_norm_mul`: `N(x·y) = N(x)·N(y)` | `Algebra.lean` | **Conserved charge** (4,4 signature) |
| `fiveThreeNorm_non_composition`: `¬∀ x y, N₅,₃(x·y) = N₅,₃(x)·N₅,₃(y)` | `Algebra.lean` | **Transition mechanism** (5,3 signature) |
| `lightcone_ratio`: `2 · frictionDensity 3 = 19 · frictionDensity 2` | `CoherenceMetric.lean` | **Coarse-shell separation** at cd 2→3 |

The 9.5× ratio reduces to `frictionDensity(3) / frictionDensity(2) = 19/2`,
where `frictionDensity(cd) = cd` for `cd ≤ 2` and `cd + 16` for `cd ≥ 3`
(the +16 comes from the strut weight `w = 4` whose square appears at the
associator barrier).

## 3. The Atomic Model (Plain English)

The metric space `coherenceInterval = dcStep² − frictionDensity²` measures
distances inside the (1,1) split-complex plane — the observable shadow of
the underlying (4,4) split-octonion algebra. Layered onto this:

- **Coarse shells (Section 1).** cd values partition into two families by
  `frictionDensity`:
  - **Shell A** (associative regime, `cd ≤ 2`): `frictionDensity ∈ {0,1,2}`.
  - **Shell B** (non-associative regime, `cd ≥ 3`): `frictionDensity ∈ {19,20,...}`.

  The 9.5× jump at cd 2→3 is the *principal quantum number* gap — the
  activation barrier between families. Theorem `coarse_shell_spectrum_split`
  certifies that **no** cd value lives in the open gap (2, 19):

  ```
  ∀ cd : ℕ, frictionDensity cd ≤ 2 ∨ frictionDensity cd ≥ 19
  ```

- **Fine shells (Section 2).** Inside *each* coarse shell, the (5,3)
  antipode-copairing form `fiveThreeNorm(x) = (x · S(x)).e₀` gives a
  spectrum of integers. These are the subshell labels. The spectrum is
  proven nonempty and to contain both signs (`fineShell_unit_nonempty`):
  `+1` is realised by `e₀`, `−1` is realised by `e₅`. The eight basis
  elements split cleanly into the positive sector `{0,1,2,3,4}` (shell +1)
  and the negative sector `{5,6,7}` (shell −1).

- **Transitions (Section 3).** An octonion multiplication `x ↦ x · y`
  conserves the (4,4) charge (`octonion_norm_mul`) but slides `x` along
  the (5,3) spectrum (`fiveThreeNorm_non_composition`). The same
  mechanism that conserves the charge permits transitions between
  energies — exactly the dual charge/energy structure an atomic model
  needs.

## 4. The Fundamental Transition (Witness)

The strongest stated counterexample in
`fiveThreeNorm_non_composition` is elevated to a positive existence
theorem:

```
x₁ = ⟨1, 1, 0, 0, 0, 0, 0, 0⟩     -- fiveThreeNorm = 2, octonion_norm = 2
x₂ = ⟨0, 0, 0, 0, 1, 0, 0, 0⟩     -- fiveThreeNorm = 1, octonion_norm = -1
x₁ · x₂ = ⟨0, 0, 0, 0, 1, 1, 0, 0⟩  -- fiveThreeNorm = 0, octonion_norm = -2
```

- `exists_shell_transition`: ∃ x y, `atomicTransition x y 2 0`
  (a product moving from fine shell 2 to fine shell 0).

- `fundamental_transition_conserves_charge`:
  `N(x₁ · x₂) = N(x₁) · N(x₂) = 2 · (−1) = −2`  — charge scales via the
  multiplier `x₂` only, independent of `x₁`.

- `fundamental_transition_charges_eval`:
  `N(x₁) = 2 ∧ N(x₂) = −1 ∧ N(x₁ · x₂) = −2`.

The (5,3) shell jump 2 → 0 is *not* explained by a multiplicative law of
`fiveThreeNorm` (which is precisely the failure `fiveThreeNorm_non_composition`
asserts). The (4,4) charge moves with perfect predictability.

## 5. Atomic State and Within-Shell Transition

Section 4 wraps the model into a state structure:

```
structure AtomicState where
  cd       : ℕ
  x        : SplitOctonion
  fine     : ℤ
  fine_eq  : fiveThreeNorm x = fine
```

A within-shell transition is a multiplication that preserves `cd` but
changes `fine`:

```
def stateTransition (s y s') : Prop :=
  s.cd = s'.cd ∧ s'.x = s.x · y ∧ s.fine ≠ s'.fine
```

`stateTransition_charge_scaling` generalises the conservation law to all
states: under any `stateTransition`, the (4,4) charge scales by `N(y)`.

`fundamental_atomic_transition` is the headlining result — a concrete,
witness-based existence theorem that the fundamental transition *is* a
`stateTransition`:

```
∃ s s' y,
    s.cd = 2 ∧ s.fine = 2 ∧ s'.fine = 0 ∧ stateTransition s y s'
```

This is a within-shell-A transition (cd stays at 2): the cheapest transition
the model permits. It crosses no coarse-shell wall; it slides down the fine
subshell ladder from 2 to 0, with the (4,4) charge scaling multiplicatively
from 2 to −2.

## 6. Predictions of the Model

| Transition type | Cost | Charge | Energy (fine shell) |
|-----------------|------|--------|---------------------|
| **Within shell A** (cd ≤ 2) | `dcStep² − frictionDensity²` (small, smooth) | Scaled by `N(y)` | Slides via `fiveThreeNorm` |
| **Within shell B** (cd ≥ 3) | `dcStep² − frictionDensity²` (large, ≥ 19² base) | Scaled by `N(y)` | Slides via `fiveThreeNorm` |
| **Cross shell A → B** | +9.5× `frictionDensity` wall (≥ 2 → ≥ 19) | Scaled by `N(y)` | Free to slide, but inertial cost is high |
| **Cross shell B → A** | Forbidden in the B→A direction (relaxation only via. energy loss) | Conserved | Energy is shed |

- The (4,4) charge is **always conserved** (multiplicatively) — by
  `octonion_norm_mul` directly, and via `stateTransition_charge_scaling`
  at the state level.
- The (5,3) fine-shell coordinate is **not conserved** and is the channels
  through which a transition absorbs or releases energy.
- The 9.5× `frictionDensity` wall is the principal-quantum-number gap
  in the metric-space picture.

## 7. File References

- `foundations/AtomicShell.lean` — full module: coarse shells (Section 1),
  fine shells (Section 2), the fundamental transition (Section 3), atomic
  state and `fundamental_atomic_transition` (Section 4).
- `foundations/Algebra.lean` — `octonion_norm_mul` (~l.1071), `fiveThreeNorm`
  (~l.1095), `fiveThreeNorm_non_composition` (~l.1115).
- `CoherenceMetric.lean` — `lightcone_ratio`, `frictionDensity`,
  `coherenceInterval`.
- `Friction.lean` — `frictionDensity_eq_k_for_k_le_2`,
  `frictionDensity_eq_k_plus_16_for_k_ge_3`, `heightMap_discontinuity_at_cd2_3`,
  `strut_weight_eq_four`.

## 8. Two Distinct Quadratic Forms (Recap)

The reader should keep the two norms distinct:

1. **`octonion_norm` (4,4)** — `+,+,+,+,-,-,-,-` — composition-compatible
   ( proven in `octonion_norm_mul`). Charges live here.

2. **`fiveThreeNorm` (5,3)** — `+,+,+,+,+,-,-,-` — equal to `(x · S(x)).e₀`
   (proven in `fiveThreeNorm_eq_antipode_copairing`). Non-composition
   (proven in `fiveThreeNorm_non_composition`). Transition energies live
   here.

The atomic model cleanly separates them: one is the conserved charge, the
other is the transition energy. The proven composition identity on (4,4)
combined with the proven non-composition failure on (5,3) is what makes
this separation — and hence the atomic model — derivable rather than
assumed.

## 9. Next Steps (Open)

- (P-open) Cross-shell transitions (A → B) — no witness yet. The 9.5×
  wall is the inertial cliff; the model predicts the existence of A → B
  transitions but does not yet provide a concrete `stateTransition`
  crossing the cd 2→3 boundary.
- (P-open) Cross-shell transitions (B → A) — relaxation moves. The model
  predicts these are the "ground-state decay" channels.
- (P-open) Generalised transition-counting: enumerate the cardinality of
  `∃ transitions s s'` between given subshells over the integral basis.
- (P-open) Lift the atomic model to the (5,3) → (3,1) signature reduction
  via the octilinear embedding / KKT projection (OctilinearEmbedding.lean).