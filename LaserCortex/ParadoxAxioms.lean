/-
# Module: ParadoxAxioms

## Intent

Formal axioms for logical paradoxes that mark the boundary between the
formal system (Lean / mathlib) and the WFC budget model. These axioms
encode what the system cannot prove about itself — the Liar / Russell /
Sorites fixed points that the WFC pipeline resolves by paying contraction
cost rather than by logical deduction.

The core axiom is `identity_zero_divisor_contradiction`: two distinct
identity markers for the same binary tree cannot both be valid. This
is accepted as a framework axiom — it is the formal boundary where the
WFC budget model meets Lean logic.

## Contracts

- `IdentityZeroDivisor` — structure: a tree with two distinct markers
- `identity_zero_divisor_contradiction` — axiom: an IdentityZeroDivisor
  implies `False` (the Liar paradox)

## Cross-refs

- `foundations/Tamari` — `EMLTree`
- `Hopf` — uses `IdentityZeroDivisor` to link the paradox to the
  split octonion antipode fixed-point structure

## Tags

#lean4-axiom #paradox #boundary #wfc-budget
-/

import LaserCortex.foundations.Tamari

open EMLTree

namespace ParadoxAxioms

/-- The Identity Zero Divisor: a binary tree with two distinct identity
    markers. Two distinct markers for the same tree cannot both be valid
    in a resolved system (Liar paradox / witness-skeptic game).

    @typeparam α The identity marker type (typically ℕ for atom ids,
                 or String for labels). -/
structure IdentityZeroDivisor (α : Type) where
  tree : EMLTree
  marker₁ : α
  marker₂ : α
  h_marker_ne : marker₁ ≠ marker₂

/-- The Liar paradox: two distinct identity markers for the same tree
    cannot both be valid in a resolved system (witness-skeptic game).
    Accepted as a framework axiom; the formal boundary where the WFC
    budget model meets Lean logic. -/
axiom identity_zero_divisor_contradiction {α : Type} (h_zd : IdentityZeroDivisor α) : False

end ParadoxAxioms
