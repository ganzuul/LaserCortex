
/-
# Module: LaserCortex.LiarParadox

## Intent

Formalizes self-referential logical paradoxes as indexed tree structures, computes per-logic resolution costs via Cayley-Dickson contraction steps, and aggregates resistance metrics into a fractal friction Lagrangian.

## Contracts

ProblemClass, Problem, WrappedProblem, Tower, liarProblem, liarTower, frictionLagrangian, liarCost, missingProofParadox, liarWrapper, liarCost_ge_cdStep, liarCost_matches_classical, liarCost_matches_fuzzy

## Cross-refs

LaserCortex.EMLRegistry → EMLTree, contracts_to, contracts_to_rightComb, rightComb | LaserCortex.LogicTypes → LogicType, LogicContraction, cdStep | LaserCortex.Problem → ProblemTypes.Problem, Tower, WrappedProblem, ProblemClass | LaserCortex.FrictionLagrangian → frictionLagrangian, layerCost, layerCost_ge_cdStep

## Invariants

liarCost lt = FrictionLagrangian.layerCost lt (true Lagrangian cost, higher than cdStep for k ≥ 3); liarTower.layers cardinality matches liarProblem.suitableLogics.length; frictionLagrangian delegates to FrictionLagrangian.frictionLagrangian liarTower; liarWrapper proof obligation reduces to EMLRegistry.contracts_to_rightComb via structural case analysis on LogicType; normal form mapping enforces rightComb 2 for .ManyValued and rightComb 3 for all other logics; Tower layers store dependent pairs Σ lt, WrappedProblem p lt ensuring type-safe logic-problem alignment.

## Tags

#lean4-theorem #invariant #proof-bound #axiom

-/

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes
import LaserCortex.Problem
import LaserCortex.FrictionLagrangian

open EMLRegistry
open ProblemTypes

namespace LiarParadox

/-- The canonical size-3 symmetric tree used by most Liar encodings:
  Node (Node Leaf Leaf) (Node Leaf Leaf). -/
def symmetricTree : EMLTree :=
  EMLTree.Node (EMLTree.Node EMLTree.Leaf EMLTree.Leaf) (EMLTree.Node EMLTree.Leaf EMLTree.Leaf)

/-- The size-2 left-comb tree used for three-valued encodings:
  Node (Node Leaf Leaf) Leaf encodes (True ∨ False) ∨ Undefined. -/
def leftComb2 : EMLTree :=
  EMLTree.Node (EMLTree.Node EMLTree.Leaf EMLTree.Leaf) EMLTree.Leaf

/-- The Liar Paradox as a Problem. -/
def liarProblem : Problem := {
  cls := .selfReference
  name := "Liar"
  suitableLogics := [
    .ManyValued, .Paraconsistent, .Intuitionistic, .Fuzzy,
    .Temporal, .Epistemic, .Quantum, .Relevance, .Free,
    .Infinitary, .Modal, .Classical
  ]
  tree := λ lt => match lt with
    | .ManyValued => leftComb2
    | _ => symmetricTree
  normalForm := λ lt => match lt with
    | .ManyValued => rightComb 2
    | _ => rightComb 3
}

-- ================================================================
-- Meta-Paradox: The Sorry as a First-Class Problem
-- ================================================================

/-- A meta-paradox: a WrappedProblem whose proof cannot be filled
  is itself a logical problem.

  The Liar says "this sentence is false" — a truth-value it cannot supply.
  The missing resolution says "this contraction is missing" — a proof it cannot supply.
  Both are self-referential gaps: the framework refers to its own incompleteness.

  The `sorry` in `fuzzyLiar.proof` IS the evidence of this meta-paradox.
  It is not a placeholder to be filled later — it is the manifestation of
  the framework's current incompleteness, stated as a first-class Problem. -/
def missingProofParadox (p : Problem) (lt : LogicTypes.LogicType) : Problem := {
  cls := .metaParadox
  name := "Missing " ++ lt.name ++ " proof for " ++ p.name
  suitableLogics := [lt]
  tree := λ _ => p.tree lt
  normalForm := λ _ => p.normalForm lt
}



-- ================================================================
-- Liar Wrappers (All Mail Slots Filled)
-- ================================================================

/-- Generic Liar wrapper for any logic type. Cost = FrictionLagrangian.layerCost lt.
  Each CD property-loss adds exactly one contraction step to
  resolve the Liar (perfect anti-coherence).
  
  Uses the true Friction Lagrangian cost instead of the flat cdStep,
  accounting for the associator energy barrier at CD ≥ 3. -/
def liarWrapper (lt : LogicTypes.LogicType) : WrappedProblem liarProblem lt :=
  {
    tree   := liarProblem.tree lt
    target := liarProblem.normalForm lt
    cost   := FrictionLagrangian.layerCost lt
    proof  := by
      show LogicTypes.LogicContraction lt (liarProblem.tree lt) (liarProblem.normalForm lt)
      have hLC : LogicTypes.LogicContraction lt = EMLRegistry.contracts_to := by
        cases lt <;> rfl
      have hNF : liarProblem.normalForm lt = EMLRegistry.rightComb (liarProblem.tree lt).size := by
        cases lt <;> rfl
      rw [hLC, hNF]
      exact EMLRegistry.contracts_to_rightComb (liarProblem.tree lt)
  }

/-- The Classical Liar: CD step 0, cost 0. -/
def classicalLiar : WrappedProblem liarProblem (.Classical) :=
  liarWrapper .Classical

/-- The Fuzzy Liar: CD step 1, cost 1. -/
def fuzzyLiar : WrappedProblem liarProblem (.Fuzzy) :=
  liarWrapper .Fuzzy

-- ================================================================
-- Nested Wrappers (WfCA stacked collapse)
-- ================================================================

-- A Tower is a sequence of logic-wrapped problems, each collapsing the
-- output of the previous.  From Lumo section B:
--   Layer 3 (Quantum):       liar_superposition
--        ↓ wrapper
--   Layer 2 (Intuitionistic): proof_of_quantum_state
--        ↓ wrapper
--   Layer 1 (Fuzzy):         confidence_in_proof
--        ↓ wrapper
--   Layer 0 (Classical):     assertion_value
-- Each wrapper converts the previous layer's normal form into the
-- next layer's tree, then contracts it.  The total cost is the sum.
-- The dependent pair Σ lt, WrappedProblem p lt stores each layer's
-- logic type alongside its wrapped problem.
-- NOTE: The `Tower` structure itself is now defined in `Problem.lean`
-- under `ProblemTypes.Tower`.  This docstring is preserved for context.

/-- The full Liar tower: one layer per suitable logic, in CD step order.
  Each layer wraps the Liar in that logic's structural language.
  Total cost = Σ liarCost lt = Σ cdStep lt. -/
def liarTower : Tower liarProblem := {
  layers := liarProblem.suitableLogics
    |>.map (λ lt => ⟨lt, liarWrapper lt⟩)
}

/-- The total Friction Lagrangian: sum of costs across the full tower.
  This measures the total resistance of the logical ecosystem to
  the Liar paradox.
  
  Delegates to `FrictionLagrangian.frictionLagrangian` for the
  true associator-weighted cost. -/
def frictionLagrangian : Nat :=
  FrictionLagrangian.frictionLagrangian liarTower

-- ================================================================
-- Liar Cost: hardness measure for each logic against the Liar
-- ================================================================

/-- The cost Φ for resolving the Liar in each logic.
  By definition: liarCost lt = FrictionLagrangian.layerCost lt (the true
  Friction Lagrangian layer cost, which includes the associator energy
  barrier at CD ≥ 3).
  Measures resistance to perfect anti-coherence (X = ¬X).
  Each CD property-loss adds exactly one contraction step.
  
  This is a strict increase over the old flat cdStep for non-associative
  logics (CD ≥ 3): liarCost lt = lt.cdStep + strut_weight * assocDefect(lt.cdStep). -/
def liarCost (lt : LogicTypes.LogicType) : Nat :=
  FrictionLagrangian.layerCost lt

/-- liarCost ≥ cdStep — the true Lagrangian cost is at least the old flat cost.
  The direction reverses from the old liarCost_le_cdStep because the true cost
  is HIGHER (accounts for the associator barrier), not lower. -/
theorem liarCost_ge_cdStep (lt : LogicTypes.LogicType) : liarCost lt ≥ lt.cdStep := by
  dsimp [liarCost]
  exact FrictionLagrangian.layerCost_ge_cdStep lt

/-- liarCost matches the actual WrappedProblem cost for Classical. -/
theorem liarCost_matches_classical : liarCost (.Classical) = classicalLiar.cost := by
  rfl

/-- liarCost matches the actual WrappedProblem cost for Fuzzy. -/
theorem liarCost_matches_fuzzy : liarCost (.Fuzzy) = fuzzyLiar.cost := by
  rfl

end LiarParadox
