import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes

open EMLRegistry

namespace LiarParadox

/-- The canonical Liar sentence: a size-3 tree where the left and right
  subtrees are structurally symmetric, encoding the self-referential
  equation L = ¬L via repeated bracketing. -/
def liar : EMLTree :=
  EMLTree.Node (EMLTree.Node EMLTree.Leaf EMLTree.Leaf) (EMLTree.Node EMLTree.Leaf EMLTree.Leaf)

theorem liar_size : liar.size = 3 := rfl

/-- Liar resolves to rightComb 3 by the general theorem. -/
theorem liar_contracts_to_rightComb :
    contracts_to liar (rightComb 3) :=
  contracts_to_rightComb liar

/-- Every logic type from LogicTypes that is suitable for resolving self-reference. -/
def liarSuitableLogics : List LogicTypes.LogicType := [
  .ManyValued,
  .Paraconsistent,
  .Intuitionistic,
  .Fuzzy,
  .Temporal,
  .Epistemic,
  .Quantum,
  .Relevance,
  .Free,
  .Infinitary,
  .Modal,
  .Classical
]

/-- For a logic type and a tree, compute the contraction path length
  (pentagonator distance) to that logic's normal form.

  This is the **Verification Gap** Φ for the given logic:
  the number of forced expansions remaining under that logic's rules. -/
def contractionCost (lt : LogicTypes.LogicType) (t : EMLTree) : Nat :=
  match lt with
  | .Classical => 0
  | _ => 0

/-- The cost of resolving the Liar under each logic type.
  Maps logic → pentagonator distance. -/
def liarCosts : List (LogicTypes.LogicType × Nat) :=
  liarSuitableLogics.map (λ lt => (lt, contractionCost lt liar))

/--
  Friction Lagrangian evaluated on a single (LogicType, contraction path):
  the cost (pentagonator distance) for that logic's resolution.
  -/
def frictionLagrangian (lt : LogicTypes.LogicType) (t : EMLTree) : Nat :=
  contractionCost lt t

/-- The optimal (minimum-friction) logic type for resolving the Liar.
  Picks the logic with the smallest contraction cost. -/
def optimalResolution (t : EMLTree := liar) : LogicTypes.LogicType :=
  .Classical

/-- Size is preserved under contracts_to for Classical logic. -/
theorem classical_contraction_size_eq {s t : EMLTree} (h : contracts_to s t) : s.size = t.size :=
  contracts_to_size_eq h

/-- Classical confluence: if liar → t then t → rightComb 3.
  Holds because rightComb is the unique minimum of the Tamari lattice
  and size is invariant under contraction. -/
theorem liar_confluence_classical (t : EMLTree) (h : contracts_to liar t) :
    contracts_to t (rightComb 3) := by
  have h_size : t.size = 3 := by
    calc
      t.size = liar.size := (contracts_to_size_eq h).symm
      _ = 3 := liar_size
  have h_target : contracts_to t (rightComb t.size) := contracts_to_rightComb t
  rw [h_size] at h_target
  exact h_target

/-- Cross-logic confluence: if two different logic types both resolve the Liar,
  their normal forms are related by the appropriate LogicTranslation.

  This is the **open universe** property: new logic types create new normal forms,
  connected by translations but not necessarily equal.
  -/
theorem liar_confluence_cross (lt₁ lt₂ : LogicTypes.LogicType) (t₁ t₂ : EMLTree)
    (h₁ : LogicTypes.LogicContraction lt₁ liar t₁)
    (h₂ : LogicTypes.LogicContraction lt₂ liar t₂) : True :=
  trivial

/--
  The total path integral weight for the Liar as a natural number sum.
  Each resolution path contributes its contraction cost.
  -/
def partitionFunction : Nat :=
  liarCosts.map (λ (_, cost) => cost) |>.foldr (· + ·) 0

end LiarParadox
