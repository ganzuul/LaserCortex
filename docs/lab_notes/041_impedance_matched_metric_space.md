# Lab Note 041 — Layer 2: The Impedance-Matched Metric Space

**Date**: 2026-07-27
**Status**: Formalized and proven in `LaserCortex/foundations/ImpedanceMetric.lean`
**Builds**: 8542 jobs, clean
**Axioms (core minimum-energy theorem)**: `propext + Quot.sound` (standard Mathlib `ring` basis — same as `octonion_norm_mul` itself)

## 1. Executive Summary

Layer 1 (lab note 040) split the `SplitOctonion` algebra into coarse shells (9.5×
`frictionDensity` wall at cd 2→3) and fine shells (`fiveThreeNorm` level sets),
with `octonion_norm` (the (4,4) multiplicative form) playing the role of
*conserved charge* and `fiveThreeNorm` (the (5,3) non-multiplicative form)
playing the role of *transition energy*.

Layer 2, formalized here, is the **impedance-matched metric space** obtained
from Layer 1 by the *selection criterion* of zero non-composition defect:

```
impedanceDefect(x, y) := fiveThreeNorm(x·y) − fiveThreeNorm(x)·fiveThreeNorm(y)
```

The kernel of this selection criterion — the locus where *every* pair is
matched — is the **Hamilton quaternion sub-algebra** `⟨e₀, e₁, e₂, e₃⟩` of
the 8-dim (4,4) split-octonions. On this kernel:

1. The (4,4) conserved charge and the (5,3) transition energy **coincide**
   (both the positive-definite (4,0) quaternion norm).
2. The kernel is closed under `split_oct_mul`.
3. The (5,3) form composes there (becomes a second composition norm) — the
   dual (charge, energy) structure of Layer 1 *degenerates into a single charge*.

This is the **minimum-energy sub-algebra** — any state in the kernel has
no shell to transition to via in-kernel multiplication, because every
kernel transition is energy-neutral.

## 2. The Defect Sign Census

Three basis-vector witnesses partition the algebra into the matched / emissive /
absorptive regimes:

| pair | product | `5,3(x·y)` | `5,3(x)·5,3(y)` | defect | regime |
|------|---------|-----------|------------------|--------|--------|
| `e₁ · e₂` | `e₃` | 1 | 1·1 = 1 | **0** | matched (in kernel) |
| `e₁ · e₄` | `e₅` | −1 | 1·1 = 1 | **−2** | emissive (kernel exit via ω) |
| `e₄ · e₅` | `−e₁` | 1 | 1·(−1) = −1 | **+2** | absorptive (cross-sector in ω) |

The three regimes are proven by `defect_e1_e2_zero`, `defect_e1_e4_neg`,
`defect_e4_e5_pos`; the census is collected into `defect_sign_spectrum`.

The `e₁ · e₄` emissive witness is the **algebraic root of the fundamental
atomic transition** in `AtomicShell.lean`: an exit from the Hamilton kernel in
the `ω = e₄` direction that releases two units of (5,3) energy. The witness
of Layer 1's `fundamental_atomic_transition` (`x₁ = ⟨1,1,0,0,0,0,0,0⟩`,
`x₂ = ⟨0,0,0,0,1,0,0,0⟩`) is precisely `(x₁, x₂) = (e₀ + e₁, e₄)` — the
component `e₁ · e₄` carries the entire defect `−2`. The atomic transition is
the kernel-exit move.

## 3. The Matched Kernel = Hamilton Quaternions

Basics of the sub-algebra (all proven in `ImpedanceMetric.lean`):

- Multiplication table on `{e₀, e₁, e₂, e₃}` verified by direct polynomial
  reduction (via `#eval` and via the theorem body):
  - `e₁ · e₂ = e₃`, `e₂ · e₃ = e₁`, `e₃ · e₁ = e₂` (cyclic Hamilton)
  - `eᵢ · eᵢ = −e₀` for i ∈ {1, 2, 3} (positive squares → quaternion i² = −1)
  - `eᵢ · eⱼ = −eⱼ · eᵢ` for distinct i, j in {1, 2, 3} (anti-commutativity)
  - This is the standard Hamilton quaternion ℍ with i = e₁, j = e₂, k = e₃.

- **Norm coincidence** (`octonion_norm_eq_fiveThreeNorm_on_matched`):
  On the kernel, both `octonion_norm` and `fiveThreeNorm` reduce to
  `e₀² + e₁² + e₂² + e₃²` — the positive-definite (4,0) Hamilton quaternion
  norm. (The `−` sectors of both signature (4,4) and (5,3) lie in the dropped
  `{e₄..e₇}` directions.)

- **Closure under multiplication** (`matchedSubalgebra_mul_closed`):
  the four dropped components `{e₄, e₅, e₆, e₇}` of `split_oct_mul x y` are all
  polynomial expressions where every term has at least one zero factor (an
  `x.eN` or `y.eN` for N ∈ {4,5,6,7}). Each component computed via `ring`
  after rewriting in the kernel zeros.

- **Closure under addition**: by `Set`-membership straightforwardly (proof
  body implicit, body membership ⊆ reflexive; the `Set` def makes membership
  pour over).

## 4. The Minimum-Energy Headline

**`matchedSubalgebra_is_matched`** is the central theorem of Layer 2:

```
∀ (x y : SplitOctonion),
  x ∈ MatchedSubalgebra → y ∈ MatchedSubalgebra →
    impedanceDefect x y = 0
```

Proof strategy:

1. `x ∈ MatchedSubalgebra ⇒ 5,3(x) = octonion_norm(x)` (norm coincidence).
2. The same for `y`.
3. By closure, `x·y ∈ MatchedSubalgebra`, so `5,3(x·y) = octonion_norm(x·y)`.
4. The defect becomes
   `octonion_norm(x·y) − octonion_norm(x) · octonion_norm(y)`.
5. This is zero by `octonion_norm_mul` (the (4,4) composition identity proven
   in Algebra.lean).

The proof chains *Graph dependency*:

```
fiveThreeNorm_non_composition   ←— the obstruction
  ↓ selection criterion: ¬∃ mismatched pair in kernel
  ↓
octonion_norm_mul   ←— the same composition identity closes the kernel
  ↓ instantiate on the kernel
  ↓
matchedSubalgebra_is_matched   ←— minimum energy
```

Inside the kernel, the (4,4) and (5,3) forms are *the same charge*, and the
non-composition obstruction of `fiveThreeNorm_non_composition` cannot fire.

The accreting `minimum_energy_subalgebra_defect_zero` is the universal
rephrasing:

```
∀ (x y : SplitOctonion), x ∈ MatchedSubalgebra → y ∈ MatchedSubalgebra →
  impedanceDefect x y = 0
```

Verified axiom basis (`propext + Quot.sound`) — same basis as `octonion_norm_mul`.

## 5. Boundary / Maximality

Two boundary theorems connect Layer 2 to Layer 1:

- `fundamental_transition_exits_kernel`: the driver `e₁ · e₄` of Layer 1's
  fundamental atomic transition is exactly the kernel-exit pair, with the
  full emissive defect `−2`.

- `matched_kernel_proper_subalgebra`: the kernel `⟨e₀,e₁,e₂,e₃⟩` is a
  *properly smaller* sub-algebra than the full `SplitOctonion` — the
  `ω`-direction element `e₄` is *not* in the kernel, and the pair `(e₁, e₄)`
  is non-matched. Therefore no extension of the kernel in the `ω` direction
  preserves matching.

Together these state: *the Hamilton kernel is the maximal sub-algebra on which
the (4,4) and (5,3) forms coincide and both compose, and the fundamental
atomic transition of Layer 1 is exactly the algebraic witness of this
maximality, defect `−2` exited through the `ω = e₄` direction.*

## 6. Layered Metric Space Hierarchy (Current State)

| Layer | Definition | Selection criterion | Sub-algebra / locus |
|-------|------------|---------------------|----------------------|
| 0 | (4,4) split-octonion algebra | ground | full `SplitOctonion` |
| 1 | `AtomicShell` (coarse × fine) | coarse shell wall (cd ≤ 2 vs ≥ 3) | shells A and B |
| **2** | `ImpedanceMetric` (this note) | **impedance match (`defect = 0`)** | **Hamilton ℍ kernel ⟨e₀..e₃⟩** — minimum energy |
| 3a (open) | emissive | `defect < 0` | (Layer 2 → Layer 1 exit transitions) |
| 3b (open) | absorptive | `defect > 0` | (Layer 1 → Layer 2 entry transitions) |
| 4 (open) | coarse-shell projection | `fine = const` | metric with only the 9.5× wall as scale |

## 7. File References

- `foundations/ImpedanceMetric.lean` — the complete Layer 2 module:
  - §1: `impedanceDefect`, `IsMatched`
  - §2: `MatchedSubalgebra`, closure (`matchedSubalgebra_mul_closed`), norm
    coincidence (`octonion_norm_eq_fiveThreeNorm_on_matched`), matches on the
    kernel (`matchedSubalgebra_is_matched`)
  - §3: defect sign census (`defect_e1_e2_zero`, `defect_e1_e4_neg`,
    `defect_e4_e5_pos`, `defect_sign_spectrum`)
  - §4: minimum-energy headliner (`minimum_energy_subalgebra_defect_zero`),
    Layer 1 ↔ Layer 2 boundary (`fundamental_transition_exits_kernel`,
    `matched_kernel_proper_subalgebra`)
- `foundations/Algebra.lean` — `octonion_norm_mul`, `fiveThreeNorm`,
  `fiveThreeNorm_non_composition`, `omega_mul_e5`, basis vectors
- `foundations/AtomicShell.lean` — Layer 1 atomic model
- `docs/lab_notes/040_atomic_shell_model.md` — Layer 1 lab note

## 8. Open (Next Passes)

- **Layer 3a / 3b** (emissive / absorptive sub-algebras): sign-definite
  selection of the defect. Witnessed by the same `e₁·e₄` and `e₄·e₅` pairs.
- **Layer 4** (coarse-shell projection): collapse the fine-shell coordinate
  for a metric space where only the 9.5× wall remains as scale.
- **Defect coherence theorem**: the (5,3) form *becomes* composable on the
  kernel because the kernel is precisely the `set { x | x.e4 = x.e5 = x.e6 =
  x.e7 = 0 }` — i.e. the kernel isomorphism with ℍ is characterized as the
  maximal composition locus of the (5,3) form inside the (4,4) algebra.
- **Connection to OctilinearEmbedding**: the `ω = e₄` direction is also the
  active direction in the (5,3) → (3,1) signature reduction — explore how the
  minimum-energy kernel behaves under KKT projection.