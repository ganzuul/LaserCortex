import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes
import LaserCortex.LiarParadox

open EMLRegistry
open LiarParadox

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

/-- Generic Sorites wrapper for any logic type. Cost = cdStep. -/
def soritesWrapper (lt : LogicTypes.LogicType) : WrappedProblem soritesProblem lt :=
  {
    tree   := soritesProblem.tree lt
    target := soritesProblem.normalForm lt
    cost   := lt.cdStep
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

/-- Sorites cost: same metric as Liar, but now applied to vagueness. -/
def soritesCost (lt : LogicTypes.LogicType) : Nat := lt.cdStep

theorem soritesCost_le_cdStep (lt : LogicTypes.LogicType) : soritesCost lt ≤ lt.cdStep := by
  simp [soritesCost]

/-- The total Friction Lagrangian for the Sorites paradox. -/
def soritesFrictionLagrangian : Nat :=
  soritesTower.layers.map (λ (x : Σ lt, WrappedProblem soritesProblem lt) => x.2.cost) |>.sum

end SoritesParadox
