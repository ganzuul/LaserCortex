
/-
# Module: TemporalParadox

## Intent

Formalizes the Grandfather causal loop as a tree contraction problem over indexed logical systems, computing resolution costs and proving normal-form transformation bounds.

## Contracts

grandfatherTree : EMLTree, grandfatherProblem : Problem, grandfatherWrapper : LogicType → WrappedProblem grandfatherProblem, grandfatherTower : Tower grandfatherProblem, grandfatherCost : LogicType → Nat, grandfatherCost_le_cdStep : ∀ (lt : LogicType), grandfatherCost lt ≤ lt.cdStep, grandfatherFrictionLagrangian : Nat

## Cross-refs

LaserCortex.LogicTypes → LogicType, cdStep, LogicContraction; LaserCortex.EMLRegistry → EMLTree, contracts_to_rightComb; LaserCortex.LiarParadox → leftComb, rightComb

## Invariants

Contraction from grandfatherTree to rightComb 4 is provable via EMLRegistry.contracts_to_rightComb; Resolution cost is upper-bounded by lt.cdStep; Tower layer costs are summable as Nat; Normal form is strictly deterministic (rightComb tree.size); Proof construction relies on case analysis over LogicType followed by definitional reduction.

## Tags

#lean4-theorem #invariant #proof-bound

-/

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes
import LaserCortex.LiarParadox

open EMLRegistry
open LiarParadox

namespace TemporalParadox

/-- The Grandfather causal loop: a left-comb chain of size 4.
  Each node represents a step in the time-travel causal loop:
  1. Traveler exists in the present
  2. Traveler travels back in time
  3. Grandfather is killed (intervention)
  4. Traveler is never born (contradiction)
  The contraction to rightComb resolves the loop into a linear timeline. -/
def grandfatherTree : EMLTree := leftComb 4

/-- The Grandfather Paradox as a Problem.
  Native logic: Temporal (time-indexed truth resolves causal loops).
  Suitable logics: those that can handle temporal/causal contradictions. -/
def grandfatherProblem : Problem := {
  cls := .temporalDecision
  name := "Grandfather"
  suitableLogics := [
    .Temporal, .Classical, .Paraconsistent, .Intuitionistic,
    .Quantum, .ManyValued, .Modal
  ]
  tree := λ _ => grandfatherTree
  normalForm := λ lt => rightComb grandfatherTree.size
}

/-- Generic Grandfather wrapper for any logic type. Cost = cdStep. -/
def grandfatherWrapper (lt : LogicTypes.LogicType) : WrappedProblem grandfatherProblem lt :=
  {
    tree   := grandfatherProblem.tree lt
    target := grandfatherProblem.normalForm lt
    cost   := lt.cdStep
    proof  := by
      show LogicTypes.LogicContraction lt (grandfatherProblem.tree lt) (grandfatherProblem.normalForm lt)
      have hLC : LogicTypes.LogicContraction lt = EMLRegistry.contracts_to := by
        cases lt <;> rfl
      have hNF : grandfatherProblem.normalForm lt = EMLRegistry.rightComb (grandfatherProblem.tree lt).size := by
        rfl
      rw [hLC, hNF]
      exact EMLRegistry.contracts_to_rightComb (grandfatherProblem.tree lt)
  }

/-- The Grandfather tower: one layer per suitable logic. -/
def grandfatherTower : Tower grandfatherProblem := {
  layers := grandfatherProblem.suitableLogics
    |>.map (λ lt => ⟨lt, grandfatherWrapper lt⟩)
}

def grandfatherCost (lt : LogicTypes.LogicType) : Nat := lt.cdStep

theorem grandfatherCost_le_cdStep (lt : LogicTypes.LogicType) : grandfatherCost lt ≤ lt.cdStep := by
  simp [grandfatherCost]

def grandfatherFrictionLagrangian : Nat :=
  grandfatherTower.layers.map (λ (x : Σ lt, WrappedProblem grandfatherProblem lt) => x.2.cost) |>.sum

end TemporalParadox
