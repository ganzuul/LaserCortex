# Lab Note 042 — Layer 3: Emissive & Absorptive Sub-algebras; Supercompleteness Detection

**Date**: 2026-07-28
**Status**: Formalized and proven in `LaserCortex/foundations/EmissiveAbsorptive.lean`
**Builds**: 8543 jobs (single-module target), clean
**Axiom basis (headliners)**: `propext + Quot.sound + Classical.choice` (standard Mathlib);
the pure-arithmetic headliner `supercomplete_cycle_defect_zero` is on `propext` only.
No `sorry`, no custom axioms.

## 1. Executive Summary — the YM-vs-LC Dichotomy

Where Yang-Mills gauge theory has *completeness* — gauge loops close exactly at the
identity, like a Wilson loop wrapping a clean circle of circumference exactly π·diameter
— LaserCortex has **supercompleteness**: the octonion loop *does* close (the product
`x · x` lands back in the scalar sub-algebra `ℤ · e₀`), but did not stop at the
identity. We draw a circle whose line is a little longer than the diameter — the circle
still completes, but there is surplus length.

The detector of this dichotomy is **idempotency**:

- `IsIdempotent x := x · x = x` — the YM "perfect circle." The squaring map *fixes*
  `x`. Over the integral split-octonions, the only idempotents are the trivial scalars
  `0` and `e₀`.

- `IsSupercomplete x := x · x ∈ scalars ∧ ¬ IsIdempotent x` — the LC "circle plus more."
  The squaring map closes the loop (returns to scalars) but overshooting past where `x`
  sat. The excess length is the overshoot.

Every non-trivial basis element `e₁, e₂, e₃, e₄, e₅, e₆, e₇` is supercomplete (every
one of them squares into the scalar sub-algebra without being idempotent). They split
into two supercomplete sub-kinds by the **sign of the overshoot**:

| basis               | `x²`             | sub-kind                         |
|---------------------|------------------|----------------------------------|
| `e₁, e₂, e₃`        | `−e₀`            | spinor half-twist (4π return)    |
| `e₄, e₅, e₆, e₇`    | `+e₀`            | involution overshoot (CD pivot)  |

The kernel of Layer 2's `MatchedSubalgebra` is exactly the integral span of the first
three (Hamilton quaternion basis `⟨e₀,e₁,e₂,e₃⟩`); the four ω-complement basis vectors
are the second kind. The `ω = e₄` element is the CD construction pivot that links
the two kinds — it squares to `+e₀` itself and, multiplied with any kernel basis
element `e_i` (i ∈ {1,2,3}), produces the corresponding `ω`-paired complement
element `e_{i+4}` (which is in the `+e₀` overshot sub-kind).

## 2. Emissive vs Absorptive Sub-kinds (Layers 3a / 3b)

The (5,3) impedance defect of Layer 2 organizes the two supercomplete sub-kinds into
two energy-flow regimes:

- **Emissive (defect < 0)** — Layer 3a:
  A kernel supercomplete (`e_i² = -e₀`) multiplied by an ω-complement supercomplete
  (`e_j² = +e₀`) *egresses* the kernel into the complement; the (5,3) energy is
  *released* as a defect `−2`.

  Canonical witness: `(e₁, e₄)` → `e₁ · e₄ = e₅`, `impedanceDefect = -2`.

- **Absorptive (defect > 0)** — Layer 3b:
  Two ω-complement supercompletes pair to *produce a kernel supercomplete*. The
  (5,3) energy is *absorbed* back into the kernel boundary, with defect `+2`.

  Canonical witness: `(e₄, e₅)` → `e₄ · e₅ = -e₁`, `impedanceDefect = +2`.

The composition theorems `emissive_composition` and `absorptive_composition` record the
full local algebra of each regime: the squarings of the inputs, the squaring of the
output, and the defect sign — all verified by direct `rfl` reductions against the
`split_oct_mul` table.

## 3. The Supercomplete Cycle

The emission `(e₁, e₄) → e₅` followed by the absorption `(e₄, e₅) → -e₁` forms the
**closed supercomplete cycle**:

```
                                 (e₁, e₄)        ←— emissive pair, defect = -2
   e₁ ─────────────────►  e₁ · e₄  =  e₅
   (kernel, e₁²=-e₀)            (complement, e₅²=+e₀)
                                       │
                                       │  (e₄, e₅)  ←— absorptive pair, defect = +2
                                       ▼
                                  e₄ · e₅ = -e₁
                                       (kernel, (-e₁)²=-e₀)
```

`supercomplete_cycle` proves that *every link* of this cycle is supercomplete:
- `e₁` (kernel supercomplete, `-e₀`),
- `e₅` (complement supercomplete, `+e₀`),
- `-e₁` (kernel supercomplete — the sign squares off, sign of overshoot unchanged).

At **no point** in the cycle does the loop close to a fixed point of `x ↦ x · x`. The
"circle plus more" picture carries through the entire move.

`supercomplete_cycle_defect_zero` proves the net defect of the closed cycle is zero
(the absorbed energy equals the emitted energy: `-2 + 2 = 0`). Axiom basis for this
particular theorem: `propext` only — pure integer arithmetic, no Choice.

## 4. Connection to Layer 1's Fundamental Atomic Transition

Layer 1's `fundamental_atomic_transition` from `AtomicShell.lean` is built on the
witnesses

```
  x₁ = ⟨1, 1, 0, 0, 0, 0, 0, 0⟩ = e₀ + e₁    (kernel supercomplete, N₅,₃ = 2)
  x₂ = ⟨0, 0, 0, 0, 1, 0, 0, 0⟩ = e₄          (complement supercomplete, N₅,₃ = 1)
  x₁ · x₂ = ⟨0, 0, 0, 0, 1, 1, 0, 0⟩ = e₄ + e₅ (complement supercomplete, N₅,₃ = 0)
```

The Layer 3 picture decomposes this move:

- The **scalar part** `e₀` of `x₁` is the idle spectator: `e₀` is the unit idempotent
  (`e₀² = e₀`), so it carries no `(5,3)` defect — its `e₀ · x₂` action alone gives
  `x₂`, with zero defect (kernel-idempotent pairing).

- The **kernel-exit part** `e₁ · e₄` carries the entire `(5,3)` defect `−2`. This
  is exactly the emissive egress `e₁ · e₄ = e₅`.

Theorem `fundamental_transition_is_emissive_egress` packages this: the Layer 1 atomic
transition is, up to an additive scalar idempotent spectator, the Layer 3 emissive
egress move. The whole `x₁ · x₂ = (e₀ + e₁) · e₄ = e₄ + e₅` decomposes as
"idempotent part + egress":
  product = scalar spectator (e₄, no defect) + supercomplete egress (e₅,
  with defect -2 on the `(e₁, e₄)` part).

## 5. Idempotency Detection — the YM-vs-LC Mathematical Map

Layer 3 makes the user's intuition precise:

|                                        | **Yang-Mills**                         | **LaserCortex**                            |
|----------------------------------------|----------------------------------------|--------------------------------------------|
| Loop action                            | `x ↦ x` (return to origin)             | `x ↦ x · x` (squaring)                     |
| Perfect closure                        | idempotent: `x · x = x`                 | supercomplete: `x · x ∈ scalars, ≠ x`      |
| Where the loop closes to               | identity trace `x`                     | scalar sub-algebra `ℤ · e₀`                |
| Loop length                            | `π · diameter` exactly                  | `π · diameter + ε` — excess length         |
| Idempotents found                      | gauge-group identity, the unit `e`     | `0` and `e₀` (the only scalar idempotents over ℤ) |
| Active transition base                  | group-indexed loops                    | supercomplete basis elements                |
| Energy dynamics                        | completeness is automatic              | energy emission / absorption = defect signs |

The YM perfect circle has no excess length — the squaring map fixes the gauge element.
The LC supercomplete has excess — the squaring map knocks the element off into the
scalar sub-algebra but at a different point. This `−e₁ → -e₀ → -e₁` cycle (or in our
case the `e₁ → e₅ → -e₁` cycle through the ω-complement) is one full loop, completing
via the scalar closure, spending one emissive credit and one absorptive credit. The
total is zero, conserving the (4,4) charge of Layer 1 — exactly what the
`stateTransition_charge_scaling` theorem predicts.

## 6. File References

- `foundations/EmissiveAbsorptive.lean` (this note) — the Layer 3 module:
  - §1: `IsIdempotent`, `ScalarSubalgebra`, `IsSupercomplete`; idempotency witnesses
    (`split_zero_idempotent`, `split_one_idempotent`); squaring witnesses (`e1_sq`
    through `e7_sq`); the seven supercomplete witnesses (`e1_supercomplete` through
    `e7_supercomplete`); headliners `basis_idempotent_dichotomy` and
    `all_nontrivial_basis_supercomplete`.
  - §2: `EmissivePair`, `e1_e4_emissive`, `e1_e4_emission`, `emissive_composition`.
  - §3: `AbsorptivePair`, `e4_e5_absorptive`, `e4_e5_absorption`,
    `absorptive_composition`.
  - §4: `supercomplete_cycle`, `supercomplete_cycle_defect_zero`.
  - §5: `fundamental_transition_is_emissive_egress`.
- `foundations/Algebra.lean` — `split_oct_mul` (l.79–89), `omega_sq` (l.326),
  `omega_mul_e5` (l.342), basis vectors `e0_vec ... e7_vec` (l.205–212),
  `split_neg` (l.97), `split_one` (l.48).
- `foundations/AtomicShell.lean` — Layer 1 atomic model, `stateTransition`,
  `fundamental_atomic_transition`, private witnesses `x1 = ⟨1,1,0,0,0,0,0,0⟩`,
  `x2 = ⟨0,0,0,0,1,0,0,0⟩`, `xxy`.
- `foundations/ImpedanceMetric.lean` — Layer 2 impedance matching:
  `impedanceDefect`, `IsMatched`, `MatchedSubalgebra`,
  `defect_e1_e2_zero`, `defect_e1_e4_neg`, `defect_e4_e5_pos`.

## 7. Updated Layer Hierarchy

| Layer | Status | Definition                              | Selection criterion                  | Locus                            |
|-------|--------|-----------------------------------------|--------------------------------------|----------------------------------|
| 0     | ✓      | (4,4) split-octonion algebra            | ground                               | full `SplitOctonion`             |
| 1     | ✓      | `AtomicShell`                            | coarse shell wall (cd ≤ 2 vs ≥ 3)    | shells A and B                   |
| 2     | ✓      | `ImpedanceMetric`                        | impedance match (`defect = 0`)       | Hamilton ℍ kernel ⟨e₀..e₃⟩       |
| 3a    | ✓ now  | `EmissiveAbsorptive.lean` §2             | `defect < 0`                         | egress pairs + ω-complement       |
| 3b    | ✓ now  | `EmissiveAbsorptive.lean` §3             | `defect > 0`                         | ingress pairs from ω-complement   |
| —     | ✓ now  | `EmissiveAbsorptive.lean` §1, §4, §5     | supercompleteness detector           | idempotent vs supercomplete basis |
| 4     | open   | coarse-shell projection                  | `fine = const`                        | wall-only metric                 |

## 8. Open / Next

- **Layer 4** (coarse-shell projection): collapse the fine-shell coordinate for a
  metric space where the 9.5× `frictionDensity` wall is the only scale. Independent
  of the algebraic lineage of Layers 2–3.
- **Quotient meaning of `supercomplete_cycle_defect_zero`**: the closed cycle has zero
  defect but happens entirely in the non-matched sub-algebra (everything supercomplete
  ≠ Layer 2 kernel members). The total `(5,3)` defect being zero relates this to a
  gauge-theoretic conservation law at Layer 3 level (energy released equals energy
  absorbed, even though we are *outside* Layer 2's matched kernel).
- **YM–LC bridge**: characterize the formal transform from `IsIdempotent x` to
  `IsSupercomplete x` as the kernel of a section of the squaring map
  `sq : SplitOctonion → ScalarSubalgebra`. Squaring is not a homomorphism everywhere;
  on the idempotents it is trivially so, on the supercompletes it loses sign
  information (`-e₀` and `+e₀` both arise).
- **Spinor interpretation of `e₁, e₂, e₃`**: their `eᵢ² = -e₀` corresponds to a half
  twist (4π periodicity); their `eᵢ⁴ = e₀ = id` is exactly the spinor's `4π` closure.
  The ω-complement's `x² = +e₀` instead shows 2π periodicity — involution. The two
  supercomplete sub-kinds are characterized by *different* spin-statistics relations.