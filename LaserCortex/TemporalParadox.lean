
/-
# Module: TemporalParadox

## Intent

Formalizes the Grandfather causal loop as a tree contraction problem over indexed logical systems, computing resolution costs and proving normal-form transformation bounds.

## Contracts

grandfatherTree : EMLTree, grandfatherProblem : Problem, grandfatherWrapper : LogicType → WrappedProblem grandfatherProblem, grandfatherTower : Tower grandfatherProblem, grandfatherCost : LogicType → Nat, grandfatherCost_ge_cdStep : ∀ (lt : LogicType), grandfatherCost lt ≥ lt.cdStep, grandfatherFrictionLagrangian : Nat

## Cross-refs

LaserCortex.LogicTypes → LogicType, cdStep, LogicContraction; LaserCortex.EMLRegistry → EMLTree, contracts_to_rightComb; LaserCortex.Problem → Problem, Tower, WrappedProblem; LaserCortex.FrictionLagrangian → frictionLagrangian, layerCost, layerCost_ge_cdStep

## Invariants

Contraction from grandfatherTree to rightComb 4 is provable via EMLRegistry.contracts_to_rightComb; Resolution cost is lower-bounded by lt.cdStep (true Lagrangian cost includes associator barrier); Tower layer costs are summable as Nat; Normal form is strictly deterministic (rightComb tree.size); Proof construction relies on case analysis over LogicType followed by definitional reduction; grandfatherFrictionLagrangian delegates to FrictionLagrangian.frictionLagrangian.

## Tags

#lean4-theorem #invariant #proof-bound

-/

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes
import LaserCortex.Problem
import LaserCortex.FrictionLagrangian

open EMLRegistry
open ProblemTypes
open FrictionLagrangian

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

/-- Generic Grandfather wrapper for any logic type. Cost = FrictionLagrangian.layerCost lt.
  Uses the true Friction Lagrangian cost (accounts for the associator energy barrier at CD ≥ 3). -/
def grandfatherWrapper (lt : LogicTypes.LogicType) : WrappedProblem grandfatherProblem lt :=
  {
    tree   := grandfatherProblem.tree lt
    target := grandfatherProblem.normalForm lt
    cost   := FrictionLagrangian.layerCost lt
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

/-- Grandfather cost: true Lagrangian cost for the Grandfather (time-travel) paradox.
  Replaces the old flat cdStep cheat. -/
def grandfatherCost (lt : LogicTypes.LogicType) : Nat :=
  FrictionLagrangian.layerCost lt

/-- grandfatherCost ≥ cdStep — the true Lagrangian cost is at least the old flat cost. -/
theorem grandfatherCost_ge_cdStep (lt : LogicTypes.LogicType) : grandfatherCost lt ≥ lt.cdStep := by
  dsimp [grandfatherCost]
  exact FrictionLagrangian.layerCost_ge_cdStep lt

/-- The total Friction Lagrangian for the Grandfather paradox.
  Delegates to `FrictionLagrangian.frictionLagrangian` for the true associator-weighted cost. -/
def grandfatherFrictionLagrangian : Nat :=
  FrictionLagrangian.frictionLagrangian grandfatherTower

end TemporalParadox
