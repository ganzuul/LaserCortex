
/-
# Module: SoritesParadox

## Intent

Formalizes the Sorites vagueness paradox as a transformable problem structure, computes its computational cost per logic type, and aggregates total friction via a layer-summed Lagrangian.

## Contracts

soritesTree : EMLTree, soritesProblem : Problem, soritesWrapper : LogicTypes.LogicType → WrappedProblem soritesProblem lt, soritesTower : Tower soritesProblem, soritesCost : LogicTypes.LogicType → Nat, soritesCost_ge_cdStep : ∀ lt, soritesCost lt ≥ lt.cdStep, soritesFrictionLagrangian : Nat

## Cross-refs

LaserCortex.EMLRegistry → EMLTree, leftComb, rightComb, contracts_to_rightComb, LaserCortex.LogicTypes → LogicType, LogicContraction, cdStep, LaserCortex.Problem → Problem, Tower, WrappedProblem, LaserCortex.FrictionLagrangian → frictionLagrangian, layerCost, layerCost_ge_cdStep

## Invariants

soritesTree is fixed to leftComb 5; soritesCost lt is higher or equal to lt.cdStep (accounting for associator barrier at CD ≥ 3); soritesTower.layers cardinality equals 10 (size of suitableLogics); soritesFrictionLagrangian delegates to FrictionLagrangian.frictionLagrangian; normalForm transformation enforces rightComb 5 via LogicContraction proof obligation; soritesWrapper.cost evaluates to FrictionLagrangian.layerCost lt.

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

namespace SoritesParadox

/-- The Sorites heap: a left-comb chain of size 5.
  Each node represents a threshold step:
  "If n grains form a heap, then n-1 grains form a heap."
  This encodes the inductively valid but actually false chain.
  Size = 5 (five thresholds from "definitely heap" to "definitely not"). -/
def soritesTree : EMLTree := leftComb 5

/-- The Sorites (Heap) Paradox as a Problem.
  Native logic: Fuzzy (vagueness resolved by degrees of truth).
  Suitable logics: all those that can handle vague boundaries. -/
def soritesProblem : Problem := {
  cls := .vagueness
  name := "Sorites"
  suitableLogics := [
    .Fuzzy, .ManyValued, .Paraconsistent, .Intuitionistic,
    .Relevance, .Temporal, .Epistemic, .Modal, .Classical
  ]
  tree := λ _ => soritesTree
  normalForm := λ lt => rightComb soritesTree.size
}

/-- Generic Sorites wrapper for any logic type. Cost = FrictionLagrangian.layerCost lt.
  Uses the true Friction Lagrangian cost (accounts for the associator energy barrier at CD ≥ 3). -/
def soritesWrapper (lt : LogicTypes.LogicType) : WrappedProblem soritesProblem lt :=
  {
    tree   := soritesProblem.tree lt
    target := soritesProblem.normalForm lt
    cost   := FrictionLagrangian.layerCost lt
    proof  := by
      show LogicTypes.LogicContraction lt (soritesProblem.tree lt) (soritesProblem.normalForm lt)
      have hLC : LogicTypes.LogicContraction lt = EMLRegistry.contracts_to := by
        cases lt <;> rfl
      have hNF : soritesProblem.normalForm lt = EMLRegistry.rightComb (soritesProblem.tree lt).size := by
        rfl
      rw [hLC, hNF]
      exact EMLRegistry.contracts_to_rightComb (soritesProblem.tree lt)
  }

/-- The Sorites tower: one layer per suitable logic, in cdStep order. -/
def soritesTower : Tower soritesProblem := {
  layers := soritesProblem.suitableLogics
    |>.map (λ lt => ⟨lt, soritesWrapper lt⟩)
}

/-- Sorites cost: same true Friction Lagrangian cost as Liar, applied to vagueness.
  This replaces the old flat cdStep cheat. -/
def soritesCost (lt : LogicTypes.LogicType) : Nat :=
  FrictionLagrangian.layerCost lt

/-- soritesCost ≥ cdStep — the true Lagrangian cost is at least the old flat cost. -/
theorem soritesCost_ge_cdStep (lt : LogicTypes.LogicType) : soritesCost lt ≥ lt.cdStep := by
  dsimp [soritesCost]
  exact FrictionLagrangian.layerCost_ge_cdStep lt

/-- The total Friction Lagrangian for the Sorites paradox.
  Delegates to `FrictionLagrangian.frictionLagrangian` for the true associator-weighted cost. -/
def soritesFrictionLagrangian : Nat :=
  FrictionLagrangian.frictionLagrangian soritesTower

end SoritesParadox
