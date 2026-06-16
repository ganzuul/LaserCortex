
/-
# Module: Candidates

## Intent

Exhaustively enumerates binary trees of size n, computes minimum/maximum logical cost bounds under specified logic types, and verifies right-comb tree optimality.

## Contracts

`allTrees : Nat → List EMLTree`, `minCost : LogicType → Nat → EMLTree × Nat`, `maxCost : LogicType → Nat → EMLTree × Nat`, `rightCombIsMin : LogicType → Nat → Bool`, `report : Nat → List (String × String × Nat × Nat × Nat)`

## Cross-refs

`LaserCortex.EMLRegistry → EMLTree, rightComb`, `LaserCortex.Cost → Φ`, `LaserCortex.LogicTypes → LogicType, allLogics, name, toBits`

## Invariants

`allTrees n` strictly enumerates all binary trees with exactly `n` internal nodes via recursive decomposition; `minCost`/`maxCost` guarantee `Nat`-bounded cost returns with `0 ≤ Φ L t`; `rightCombIsMin` asserts `Φ L t ≥ Φ L (rightComb n)` for all `t ∈ allTrees n` iff it evaluates to `true`; `report` preserves tuple ordering `(logic, tree_bits, min_cost, max_cost, right_comb_cost)`.

## Tags

#invariant #proof-bound

-/

import LaserCortex.EMLRegistry
import LaserCortex.Cost
import LaserCortex.LogicTypes

open EMLRegistry
open Cost

namespace Candidates

/-- All binary trees with exactly n internal nodes (size = n). -/
partial def allTrees : Nat → List EMLTree
  | 0     => [.Leaf]
  | n + 1 =>
    List.flatten ((List.range (n + 1)).map λ i =>
      List.flatten ((allTrees i).map λ l =>
        (allTrees (n - i)).map λ r => .Node l r))

/-- The minimum Φ value among all trees of size n under logic L,
    and a tree achieving it.  Returns (tree, Φ). -/
def minCost (L : LogicTypes.LogicType) (n : Nat) : EMLTree × Nat :=
  let trees := allTrees n
  match trees with
  | []     => (.Leaf, 0)
  | t :: ts =>
    let init : EMLTree × Nat := (t, Φ L t)
    ts.foldl (λ (best : EMLTree × Nat) (t' : EMLTree) =>
      let c := Φ L t'
      if c < best.2 then (t', c) else best) init

/-- The maximum Φ value among all trees of size n under logic L,
    and a tree achieving it. -/
def maxCost (L : LogicTypes.LogicType) (n : Nat) : EMLTree × Nat :=
  let trees := allTrees n
  match trees with
  | []     => (.Leaf, 0)
  | t :: ts =>
    let init : EMLTree × Nat := (t, Φ L t)
    ts.foldl (λ (best : EMLTree × Nat) (t' : EMLTree) =>
      let c := Φ L t'
      if c > best.2 then (t', c) else best) init

/-- Check whether rightComb is the global minimum for a given logic and size. -/
def rightCombIsMin (L : LogicTypes.LogicType) (n : Nat) : Bool :=
  let rc := rightComb n
  let rcCost := Φ L rc
  List.all (allTrees n) (λ t => Φ L t ≥ rcCost)

/-- Report: for each logic type, print (logic, n, minTree bits, minCost, maxCost, rightCombCost). -/
def report (n : Nat) : List (String × String × Nat × Nat × Nat) :=
  LogicTypes.allLogics.map λ L =>
    let (minT, minC) := minCost L n
    let (_, maxC) := maxCost L n
    let rcC := Φ L (rightComb n)
    (LogicTypes.LogicType.name L, minT.toBits, minC, maxC, rcC)

end Candidates
