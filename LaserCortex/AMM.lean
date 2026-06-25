
/-
# Module: AMM

## Intent

Formalizes a constant-product automated market maker with binary-tree swap routes, computing compositional cross-impact costs and associator defects within a logic-parametrized cost algebra.

## Contracts

`Pool.reserveA`, `Pool.reserveB`, `Pool.hApos`, `Pool.hBpos`, `k(p : Pool) : Nat`, `swapOut(p : Pool)(dx : Nat) : Nat`, `Route.leaf`, `Route.node`, `compose(r1 r2 : Route) : Route`, `routeToTree(r : Route) : EMLTree`, `crossImpact(L : LogicTypes.LogicType)(r1 r2 : Route) : Nat`, `associatorCost(L : LogicTypes.LogicType)(r1 r2 r3 : Route) : Nat`

## Cross-refs

`LaserCortex.EMLRegistry → EMLTree, contracts_one.rotate` | `LaserCortex.Cost → Φ, nodeParam, LogicTypes.LogicType, Cost.NodeCost.apply, Cost.nodeParam_bias_one L`

## Invariants

`hApos : 0 < reserveA`, `hBpos : 0 < reserveB` | `(reserveA + dx) * (reserveB - swapOut p dx) ≥ k p` (floor division bound) | `crossImpact L r1 r2 ≥ 0` (truncated ℕ subtraction) | `crossImpact_classical L r1 r2 = 1` when `(nodeParam L).rightDiv = 0 ∧ (nodeParam L).leftWeight = 1` | `associatorCost L r1 r2 r3 = 0` when `(nodeParam L).rightDiv = 0` (pentagon coherence) | `compose` lacks structural associativity; rotational equivalence holds via `EMLTree` Tamari decomposition.

## Tags

#lean4-theorem #invariant #proof-bound

-/

import LaserCortex.EMLRegistry
import LaserCortex.Cost

open EMLRegistry
open Cost

namespace AMM

/-- A constant-product liquidity pool for two tokens.
    Reserves are natural numbers (e.g. wei). Invariant: x * y = k. -/
structure Pool where
  reserveA : Nat
  reserveB : Nat
  hApos : 0 < reserveA
  hBpos : 0 < reserveB
  deriving Repr

/-- The constant product invariant. -/
def k (p : Pool) : Nat := p.reserveA * p.reserveB

/-- k is positive. -/
theorem k_pos (p : Pool) : 0 < k p := by
  dsimp [k]; exact Nat.mul_pos p.hApos p.hBpos

/-- Output of swapping `dx` token A for token B.
    Formula: dy = (reserveB * dx) / (reserveA + dx) (floor division). -/
def swapOut (p : Pool) (dx : Nat) : Nat :=
  (p.reserveB * dx) / (p.reserveA + dx)

/-- After a swap the product never decreases (floor division rounds down,
    so the remainder stays in the pool). -/
theorem swap_preserves_k_bound (p : Pool) (dx : Nat) :
    (p.reserveA + dx) * (p.reserveB - swapOut p dx) ≥ k p := by
  match p with
  | ⟨x, y, hxApos, hxBpos⟩ =>
    have hxpos : 0 < x + dx :=
      Nat.lt_of_lt_of_le hxApos (Nat.le_add_right x dx)
    let q := (y * dx) / (x + dx)
    let r := (y * dx) % (x + dx)
    have hdiv_add_mod : (x + dx) * q + r = y * dx := by
      simpa [q, r] using Nat.div_add_mod (y * dx) (x + dx)
    have h_mul_div : q * (x + dx) ≤ y * dx := by
      simpa [q, Nat.mul_comm] using Nat.mul_div_le (y * dx) (x + dx)
    have hqy : q ≤ y := by
      apply Nat.le_of_not_gt
      intro H
      have h_lt_mul : y * (x + dx) < q * (x + dx) :=
        Nat.mul_lt_mul_of_pos_right H hxpos
      have h_ge : y * dx ≤ y * (x + dx) :=
        Nat.mul_le_mul_left y (Nat.le_add_left dx x)
      have h_contra : y * dx < q * (x + dx) :=
        Nat.lt_of_le_of_lt h_ge h_lt_mul
      exact (Nat.not_lt.mpr h_mul_div) h_contra
    have h_mul_div' : q * (x + dx) = y * dx - r := by
      calc
        q * (x + dx) = (x + dx) * q := by rw [Nat.mul_comm]
        _ = ((x + dx) * q + r) - r := by rw [Nat.add_sub_cancel]
        _ = y * dx - r := by rw [hdiv_add_mod]
    calc
      (x + dx) * (y - swapOut ⟨x, y, hxApos, hxBpos⟩ dx) = (x + dx) * (y - q) := rfl
      _ = (x + dx) * y - (x + dx) * q := by rw [Nat.mul_sub_left_distrib]
      _ = (x + dx) * y - (q * (x + dx)) := by rw [Nat.mul_comm (x + dx) q]
      _ = (x + dx) * y - (y * dx - r) := by rw [h_mul_div']
      _ = (x * y + y * dx) - (y * dx - r) := by
        have h_mul_eq : (x + dx) * y = x * y + y * dx := by
          calc
            (x + dx) * y = x * y + dx * y := by rw [Nat.add_mul]
            _ = x * y + y * dx := by rw [Nat.mul_comm dx y]
        rw [h_mul_eq]
      _ = x * y + (y * dx - (y * dx - r)) := by
        rw [Nat.add_sub_assoc (Nat.sub_le (y * dx) r) (x * y)]
      _ = x * y + r := by
        rw [Nat.sub_sub_self (Nat.mod_le (y * dx) (x + dx))]
      _ ≥ x * y := Nat.le_add_right (x * y) r
      _ = k ⟨x, y, hxApos, hxBpos⟩ := rfl

/-- A swap route is a binary tree of pools.
    Leaf = terminal token, Node = sequential composition of two sub-routes. -/
inductive Route : Type where
  | leaf : Route
  | node : Route → Route → Route
  deriving DecidableEq, Repr

/-- Map a route to an EMLTree (the Tamari decomposition of the swap). -/
def routeToTree : Route → EMLTree
  | .leaf => .Leaf
  | .node l r => .Node (routeToTree l) (routeToTree r)

/-- The depth of a route as a path in the Tamari lattice. -/
def routeDepth : Route → Nat
  | .leaf => 0
  | .node l r => 1 + routeDepth l + routeDepth r

/-- A priced route: a route with its total cross-impact cost. -/
structure PricedRoute where
  route : Route
  totalCost : Nat

/-! ### Route Composition and Cross-Impact -/

/-- Sequential composition of two routes: `compose r1 r2` executes `r1` then `r2`.
    The output of the first feeds into the input of the second, forming a binary
    tree node — the same structure as `Route.node r1 r2`. -/
def compose (r1 r2 : Route) : Route := .node r1 r2

/-- routeToTree is a homomorphism for compose:
    the tree of a composed route nests the two subtrees. -/
theorem routeToTree_compose (r1 r2 : Route) :
    routeToTree (compose r1 r2) = .Node (routeToTree r1) (routeToTree r2) := by
  simp [compose, routeToTree]

/-- Unit laws for compose: wrapping with leaf adds a no-op step. -/
theorem compose_leaf_left (r : Route) : compose .leaf r = .node .leaf r := rfl

theorem compose_leaf_right (r : Route) : compose r .leaf = .node r .leaf := rfl

/-- Compose is not structurally associative (just like the binary tree node).
    Instead, `compose (compose r1 r2) r3` and `compose r1 (compose r2 r3)`
    are related by Tamari rotation. -/
theorem compose_not_assoc (r1 r2 r3 : Route) :
    compose (compose r1 r2) r3 ≠ compose r1 (compose r2 r3) := by
  intro h
  have htree : EMLTree.Node (EMLTree.Node (routeToTree r1) (routeToTree r2)) (routeToTree r3) =
    EMLTree.Node (routeToTree r1) (EMLTree.Node (routeToTree r2) (routeToTree r3)) := by
    simpa [compose, routeToTree] using congrArg routeToTree h
  have h_nodes : EMLTree.Node (routeToTree r1) (routeToTree r2) ≠ routeToTree r1 := by
    intro h_contra
    have hsize : (EMLTree.Node (routeToTree r1) (routeToTree r2)).size = (routeToTree r1).size := by
      rw [h_contra]
    simp [EMLTree.size] at hsize
    omega
  have h_left : EMLTree.Node (routeToTree r1) (routeToTree r2) = routeToTree r1 := by
    have := congrArg (fun t : EMLTree => match t with
      | .Node l _ => l
      | .Leaf => .Leaf) htree
    simpa using this
  exact h_nodes h_left

/-! ### Cross-Impact Cost

The cost of a composed route is not simply additive:
Φ(compose r1 r2) ≠ Φ(r1) + Φ(r2) in general.
The difference measures the cross-impact — how executing r1 changes the
reserves that r2 sees, amplifying or compressing the total cost.
-/

/-! ### Route-typed cross-impact (preserved for design wisdom)

    The following `crossImpact` and `associatorCost` definitions (Route-typed)
    are commented out, NOT deleted. They carry design information about AMM's
    concept of binary-tree swap routes that should be assimilated before removal.
    Once the EMLTree generalizations below are fully verified, these can be
    removed or their design wisdom documented separately.

    Generalized to EMLTree below — these Route-typed versions are preserved here
    for design wisdom until the assimilation is verified. Once EMLTree version is
    fully tested, these can be removed.
-/

/-- Absolute difference of two natural numbers: |a - b| in ℕ. -/
def absDiff (a b : Nat) : Nat := (a - b) + (b - a)

-- [Original crossImpact definition, commented out]
-- def crossImpact (L : LogicTypes.LogicType) (r1 r2 : Route) : Nat :=
--   Φ L (routeToTree (compose r1 r2)) - (Φ L (routeToTree r1) + Φ L (routeToTree r2))

-- [Original crossImpact_nonneg theorem, commented out]
-- theorem crossImpact_nonneg (L : LogicTypes.LogicType) (r1 r2 : Route) :
--     0 ≤ crossImpact L r1 r2 :=
--   Nat.zero_le _

-- [Original crossImpact_classical theorem, commented out]
-- theorem crossImpact_classical (L : LogicTypes.LogicType) (r1 r2 : Route)
--     (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
--     (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
--     (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
--     crossImpact L r1 r2 = 1 := by
--   dsimp [crossImpact]
--   rw [routeToTree_compose, Φ_Node, NodeCost.apply_not_mirror _ _ _ hMS hM hSC]
--   simp only [hC, Nat.zero_mul, Nat.add_zero, Nat.zero_div]
--   rw [nodeParam_bias_one L, hW, hD]
--   simp [Nat.div_one, Nat.one_mul, Nat.succ_eq_add_one]
--   omega

-- [Original associatorCost definition, commented out]
-- def associatorCost (L : LogicTypes.LogicType) (r1 r2 r3 : Route) : Nat :=
--   absDiff (Φ L (routeToTree (compose (compose r1 r2) r3)))
--           (Φ L (routeToTree (compose r1 (compose r2 r3))))

-- [Original associatorCost_zero_classical theorem, commented out]
-- theorem associatorCost_zero_classical (L : LogicTypes.LogicType) (r1 r2 r3 : Route)
--     (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
--     (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
--     (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
--     associatorCost L r1 r2 r3 = 0 := by
--   dsimp [associatorCost, absDiff]
--   have h_eq : Φ L (routeToTree (compose (compose r1 r2) r3)) = Φ L (routeToTree (compose r1 (compose r2 r3))) := by
--     rw [routeToTree_compose, routeToTree_compose]
--     have hΦeq : Φ L (EMLTree.Node (EMLTree.Node (routeToTree r1) (routeToTree r2)) (routeToTree r3)) =
--                Φ L (EMLTree.Node (routeToTree r1) (EMLTree.Node (routeToTree r2) (routeToTree r3))) :=
--       Φ_contracts_one_eq_classical L hD hC hM hW hMS hSC (by
--         apply EMLRegistry.contracts_one.rotate)
--     exact hΦeq
--   simp [h_eq]

/-! ### EMLTree-typed cross-impact (generalized from Route)

    The following generalizations replace the Route-specific versions above.
    EMLTree is the natural habitat because Generation.temporalConflate produces
    EMLTrees directly; Route was an intermediate form that lost information.
-/

/-- Generalized cross-impact: the cost difference between composing two trees
    vs treating them independently. EMLTree is the natural habitat (tree size
    is the canonical cost parameter). Replaces the Route-specific version
    above, which is preserved for design reference. -/
def crossImpactTree (L : LogicTypes.LogicType) (t1 t2 : EMLTree) : Nat :=
  Φ L (.Node t1 t2) - (Φ L t1 + Φ L t2)

/-- Generalized associator cost: the cost difference between the two bracketings
    of a triple composition. The discrete analogue of the pentagon defect norm. -/
def associatorCostTree (L : LogicTypes.LogicType) (t1 t2 t3 : EMLTree) : Nat :=
  absDiff (Φ L (.Node (.Node t1 t2) t3))
          (Φ L (.Node t1 (.Node t2 t3)))

/-- crossImpactTree is always non-negative. In ℕ with truncated subtraction
    this is a tautology (`Nat.zero_le`), but the theorem is declared to match
    the proof surface of the original Route-typed `crossImpact_nonneg` and
    as a hook for a future migration to Int arithmetic. -/
theorem crossImpactTree_nonneg (L : LogicTypes.LogicType) (t1 t2 : EMLTree) :
    0 ≤ crossImpactTree L t1 t2 :=
  Nat.zero_le _

/-- For classical logics (rightDiv=0, coupling=0, not mirror, leftWeight=1,
    not maxSem, satCap=0), crossImpactTree = 1 for any pair of trees.

    Under classical Φ = t.size (the tree-size cost), composing two trees adds
    one internal node: size(EMLTree.Node t1 t2) = 1 + t1.size + t2.size.
    So crossImpactTree = (1 + t1.size + t2.size) - (t1.size + t2.size) = 1. -/
theorem crossImpactTree_classical (L : LogicTypes.LogicType) (t1 t2 : EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    crossImpactTree L t1 t2 = 1 := by
  dsimp [crossImpactTree]
  have hΦnode : Φ L (EMLTree.Node t1 t2) = (EMLTree.Node t1 t2).size :=
    Φ_eq_size_classical L (EMLTree.Node t1 t2) hD hC hM hW hMS hSC
  have hΦt1 : Φ L t1 = t1.size :=
    Φ_eq_size_classical L t1 hD hC hM hW hMS hSC
  have hΦt2 : Φ L t2 = t2.size :=
    Φ_eq_size_classical L t2 hD hC hM hW hMS hSC
  rw [hΦnode, hΦt1, hΦt2]
  have hsize : (EMLTree.Node t1 t2).size = 1 + t1.size + t2.size := rfl
  rw [hsize]
  omega

/-- For classical logics, the associator cost is zero (pentagon coherence):
    both bracketings of a triple composition have the same Φ cost.

    Proof: Tamari rotation relates the two bracketings, and
    Φ_contracts_one_eq_classical says cost is preserved by Tamari rotation
    for classical logics. -/
theorem associatorCostTree_zero_classical (L : LogicTypes.LogicType) (t1 t2 t3 : EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    associatorCostTree L t1 t2 t3 = 0 := by
  dsimp [associatorCostTree, absDiff]
  have h_eq : Φ L (EMLTree.Node (EMLTree.Node t1 t2) t3) = Φ L (EMLTree.Node t1 (EMLTree.Node t2 t3)) :=
    Φ_contracts_one_eq_classical L hD hC hM hW hMS hSC (by
      apply EMLRegistry.contracts_one.rotate)
  simp [h_eq]

-- ============================================================================
-- CloseResult: the AMM side of the IC↔AMM bridge
-- ============================================================================

/-- The result of an AMM close operation: the fair price, the friction cost
    deduction, and the net residue. This is the AMM-local structure that
    MarketClosure.CertifiedPrice wraps with a CortexCertificate.

    INVARIANT NOTE: the field `h_nonnegative : residue ≥ 0` is intentionally
    VACUOUS in ℕ arithmetic (truncated subtraction means residue is always
    ≥ 0). The *operational* guarantee that price ≥ costDeduction is enforced
    by the caller-side `reserveGuard` returning false, which ensures
    Φ L tree < pool.reserveB (the pool survives the computation).
    A future migration to Int arithmetic would make h_nonnegative
    a non-trivial proof obligation (see also docs/PLAN_market_closure.md §6).

    See MarketClosure.lean for the full CertifiedPrice structure. -/
structure CloseResult where
  price         : Nat
  costDeduction : Nat
  residue       : Nat
  h_nonnegative : residue ≥ 0    -- vacuous in ℕ; real invariant is caller-side reserveGuard

/-- The reserve-vs-FL guard. Returns true if the computation cost Φ L tree
    meets or exceeds the entire pool reserve (reserveB), meaning the attempt
    would annihilate the pool's liquidity (zero-divisor territory).

    Cases:
    1. Φ L tree ≥ pool.reserveB → true (reserve annihilated → paradox market).
    2. Φ L tree < pool.reserveB → false (safe to compute the price — the
       pool survives the computation).

    NOTE: ZD detection via Generation.revise (WFC zero-divisor when both
    poles are vacuous) is NOT yet wired into this guard. That would catch
    the vacuous case even before the cost check, and is tracked as a TODO
    once the WFC engine integration stabilizes.

    TODO (amortization): in a realistic system this guard would consult a
    cached library of precomputed costs rather than calling Φ directly.
    The pool reserves are externally supplied; this function does not derive
    them from ProblemClass or BlamePool. -/
def reserveGuard (pool : Pool) (L : LogicTypes.LogicType) (tree : EMLTree) : Bool :=
  let cost := Φ L tree
  -- Compare against pool.reserveB (total liquidity), NOT swapOut (trade proceeds).
  -- plan: "would annihilate the reserve / ZD caught"
  cost ≥ pool.reserveB

/-- The certified close step: AMM computes fair price; FL provides cost;
    EMLRegistry.certify produces a proof-carrying certificate.

    Precondition (caller responsibility): not reserveGuard (cost < reserve).
    The pool reserves are externally supplied; this function does not derive
    them from ProblemClass or BlamePool.

    Returns a CloseResult with price, costDeduction, and residue (net value).
    MarketClosure.certifiedClose wraps this with a CortexCertificate.

    TODO (amortization): cached lookup of precomputed Φ costs. -/
def certifiedClose (pool : Pool) (L : LogicTypes.LogicType) (tree : EMLTree) (dx : Nat) : CloseResult :=
  let price := swapOut pool dx
  let costDeduction := Φ L tree
  let residue := price - costDeduction
  {
    price := price
    costDeduction := costDeduction
    residue := residue
    h_nonnegative := Nat.zero_le (price - costDeduction)
  }

end AMM
