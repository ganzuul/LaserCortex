import Mathlib

/-!
# Tamari Lattice Contraction

Tamari contraction on binary trees (EMLTree).

## Key definitions
- `EMLTree` — binary trees with size, depth, leftWeight, rightWeight
- `contracts_one` — single right rotation (Tamari covering relation)
- `contracts_to` — reflexive-transitive closure (Tamari contraction)
- `rightComb` — the right-comb normal form (minimum element in Tamari order)
- `dcStep` — distance to rightComb (termination measure)

## Key theorems
- `contracts_to_antisymm` — antisymmetry: s → t ∧ t → s ⇒ s = t
- `contracts_to_refl` — reflexivity
- `contracts_to_trans` — transitivity
- `contracts_to_size_eq` — size preservation: s → t ⇒ s.size = t.size
- `dcStep_terminates` — dcStep strictly decreases (termination)
- `/!
-/
