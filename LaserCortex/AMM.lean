/-
# Module: AMM

## Intent

Formalizes a constant-product automated market maker with binary-tree swap
routes. The cost function is `SubdivisionClosure.weightedCost` — the Tamari
flip distance to right-comb normal form weighted by `frictionDensity(cd)`.
This replaces the earlier 98-parameter cost algebra (14 LogicTypes × 7
NodeCost parameters) with a single ℕ parameter (Cayley–Dickson step).

The AMM's price discovery IS the subdivision closure: the swap price minus the
weighted cost of the binary tree route equals the certified fair price. There
is no separate "market closure" step — the AMM IS the market closing.

**Grounding**: The swap route is a binary tree; `routeToTree` maps it to a
triangulation of the associahedron. The cost `weightedCost cd tree` is the
number of diagonal flips (`dcStep tree`) times the per-flip friction cost
(`frictionDensity cd`). The AMM discovers the price by contracting the
triangulation to its right-comb minimum, paying the friction cost along the
way. This is literally the "AMM finds a subdivision" claim — the Tamari
contraction path IS the price discovery trajectory.

**Phase change at cd 2→3**: For cd ≤ 2 (ℝ, ℂ, ℍ, Cl(1,1) — associative
regime), the per-flip cost is `cd`. For cd ≥ 3 (split octonion layer active),
the associator defect adds `strut_weight² = 16` per flip. The AMM's spread
widens accordingly.

## Contracts

`Pool.reserveA`, `Pool.reserveB`, `Pool.hApos`, `Pool.hBpos`,
`k(p : Pool) : Nat`, `swapOut(p : Pool)(dx : Nat) : Nat`,
`Route.leaf`, `Route.node`, `compose(r1 r2 : Route) : Route`,
`routeToTree(r : Route) : EMLTree`,
`crossImpactTree(cd : ℕ)(t1 t2 : EMLTree) : ℕ`,
`associatorCostTree(cd : ℕ)(t1 t2 t3 : EMLTree) : ℕ`,
`reserveGuard(cd : ℕ)(pool : Pool)(tree : EMLTree) : Bool`,
`certifiedClose(cd : ℕ)(pool : Pool)(tree : EMLTree)(dx : ℕ) : CloseResult`,
`MarketType`, `CertifiedPrice`, `decideMarketType`, `marketClosure`

## Cross-refs

`SubdivisionClosure → weightedCost, closure, dcStep, frictionDensity,
contracts_to_closure` | `staging/Tamari → contracts_to`

## Invariants

`hApos : 0 < reserveA`, `hBpos : 0 < reserveB` |
`(reserveA + dx) * (reserveB - swapOut p dx) ≥ k p` (floor division bound) |
`crossImpactTree cd t1 t2 ≥ 0` (truncated ℕ subtraction) |
`associatorCostTree cd t1 t2 t3 = frictionDensity cd` (constant associator cost) |
`weightedCost cd tree = 0 ↔ isRightComb tree` at positive friction density

## Tags

#lean4-theorem #invariant #proof-bound #subdivision
-/

import LaserCortex.SubdivisionClosure

open EMLTree
open SubdivisionClosure

namespace AMM

-- ============================================================================
-- Section 1: Constant-product liquidity pool
-- ============================================================================

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
theorem k_pos (p : Pool) : 0 < k p :=
  Nat.mul_pos p.hApos p.hBpos

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

-- ============================================================================
-- Section 2: Swap routes (binary trees)
-- ============================================================================

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

/-- Sequential composition of two routes: `compose r1 r2` executes `r1` then `r2`.
    The output of the first feeds into the input of the second, forming a binary
    tree node — the same structure as `Route.node r1 r2`. -/
def compose (r1 r2 : Route) : Route := .node r1 r2

/-- routeToTree is a homomorphism for compose:
    the tree of a composed route nests the two subtrees. -/
theorem routeToTree_compose (r1 r2 : Route) :
    routeToTree (compose r1 r2) = .Node (routeToTree r1) (routeToTree r2) := by
  simp [compose, routeToTree]

-- ============================================================================
-- Section 3: Absolute difference (ℕ utility)
-- ============================================================================

/-- Absolute difference of two natural numbers: |a - b| in ℕ.
    Computes `(a - b) + (b - a)` where subtraction is truncated. -/
def absDiff (a b : Nat) : Nat := (a - b) + (b - a)

-- ============================================================================
-- Section 4: Cross-impact and associator cost via weightedCost
-- ============================================================================

/-- Generalized cross-impact: the cost difference between composing two trees
    vs treating them independently. Expressed in terms of `SubdivisionClosure.weightedCost`:
    
        crossImpactTree cd t1 t2 = weightedCost cd (Node t1 t2) - (weightedCost cd t1 + weightedCost cd t2)
    
    This measures the additional friction cost of routing a trade through a
    composed pool vs. two independent swaps. Because `weightedCost cd t =
    dcStep t × frictionDensity cd`, the cross-impact factorises to:
    
        (dcStep (Node t1 t2) - (dcStep t1 + dcStep t2)) × frictionDensity cd
    
    which is always non-negative (truncated subtraction in ℕ). -/
def crossImpactTree (cd : ℕ) (t1 t2 : EMLTree) : ℕ :=
  weightedCost cd (.Node t1 t2) - (weightedCost cd t1 + weightedCost cd t2)

/-- Generalized associator cost: the cost difference between the two bracketings
    of a triple composition. The discrete analogue of the pentagon defect norm.
    
        associatorCostTree cd t1 t2 t3 = |weightedCost cd (Node (Node t1 t2) t3) -
                                          weightedCost cd (Node t1 (Node t2 t3))|
    
    By the definition of `dcStep`:
    
        dcStep (Node (Node t1 t2) t3) = 1 + dcStep (Node t1 (Node t2 t3))
    
    so the associator cost is always exactly `frictionDensity cd`, regardless of
    the tree shapes. This is non-zero (split octonion sector) except at cd=0
    where `frictionDensity 0 = 0`. -/
def associatorCostTree (cd : ℕ) (t1 t2 t3 : EMLTree) : ℕ :=
  absDiff (weightedCost cd (.Node (.Node t1 t2) t3))
          (weightedCost cd (.Node t1 (.Node t2 t3)))

/-- crossImpactTree is always non-negative. In ℕ with truncated subtraction
    this is a tautology (`Nat.zero_le`), but the theorem is declared for
    consistency with the proof surface and as a hook for future migration
    to ℤ arithmetic. -/
theorem crossImpactTree_nonneg (cd : ℕ) (t1 t2 : EMLTree) :
    0 ≤ crossImpactTree cd t1 t2 :=
  Nat.zero_le _

/-- The associator cost is exactly `frictionDensity cd` for any trees.
    
    Proof: from the definition of `dcStep`,
    
        dcStep (Node (Node t1 t2) t3) = 1 + dcStep (Node t1 (Node t2 t3))
    
    Let `x := dcStep (Node t1 (Node t2 t3))` and `f := frictionDensity cd`.
    Then:
    
        weightedCost cd (Node (Node t1 t2) t3) = (1 + x) * f
        weightedCost cd (Node t1 (Node t2 t3))   = x * f
    
    Their absolute difference is |(1+x)*f - x*f| = |f| = f
    since (1+x)*f ≥ x*f in ℕ and (x*f) - ((1+x)*f) truncates to 0. -/
theorem associatorCostTree_eq_frictionDensity (cd : ℕ) (t1 t2 t3 : EMLTree) :
    associatorCostTree cd t1 t2 t3 = frictionDensity cd := by
  dsimp [associatorCostTree, weightedCost, absDiff]
  set x := dcStep (EMLTree.Node t1 (EMLTree.Node t2 t3)) with hx
  set f := frictionDensity cd with hf
  have h_dcStep : dcStep (EMLTree.Node (EMLTree.Node t1 t2) t3) = 1 + x := by
    simp [dcStep, x]
  have h_left : (1 + x) * f - x * f = f := by
    calc
      (1 + x) * f - x * f = (1 * f + x * f) - x * f := by rw [Nat.add_mul]
      _ = (f + x * f) - x * f := by simp
      _ = f := by rw [Nat.add_sub_cancel]
  have h_right : x * f - (1 + x) * f = 0 := by
    have h_le : x * f ≤ (1 + x) * f :=
      Nat.mul_le_mul_right f (by omega)
    omega
  rw [h_dcStep]
  rw [h_left, h_right]
  simp

-- ============================================================================
-- Section 5: Phase-dependent cross-impact and associator theorems
-- ============================================================================

/-- The cross-impact tree cost at cd=0 is always zero, since frictionDensity 0 = 0. -/
theorem crossImpactTree_zero (t1 t2 : EMLTree) : crossImpactTree 0 t1 t2 = 0 := by
  dsimp [crossImpactTree, weightedCost]
  have h0 : frictionDensity 0 = 0 := by
    rw [frictionDensity_eq_k_for_k_le_2 0 (by omega)]
  simp [h0]

/-- The associator cost in the associative regime (cd ≤ 2) reduces to `cd`. -/
theorem associatorCostTree_assoc_regime (cd : ℕ) (t1 t2 t3 : EMLTree) (hcd : cd ≤ 2) :
    associatorCostTree cd t1 t2 t3 = cd := by
  rw [associatorCostTree_eq_frictionDensity, frictionDensity_eq_k_for_k_le_2 cd hcd]

/-- The associator cost in the non-associative regime (cd ≥ 3) is `cd + 16`,
    reflecting the split octonion associator defect. -/
theorem associatorCostTree_nonassoc_regime (cd : ℕ) (t1 t2 t3 : EMLTree) (hcd : 3 ≤ cd) :
    associatorCostTree cd t1 t2 t3 = cd + 16 := by
  rw [associatorCostTree_eq_frictionDensity, frictionDensity_eq_k_plus_16_for_k_ge_3 cd hcd,
    strut_weight_eq_four]

-- ============================================================================
-- Section 6: Reserve guard and certified close
-- ============================================================================

/-- The reserve-vs-FL guard. Returns true if the weighted cost `weightedCost cd tree`
    meets or exceeds the entire pool reserve (`reserveB`), meaning the attempt
    would annihilate the pool's liquidity (zero-divisor territory).
    
    Cases:
    1. `weightedCost cd tree ≥ pool.reserveB` → true (reserve annihilated → paradox market).
    2. `weightedCost cd tree < pool.reserveB` → false (safe to compute the price —
       the pool survives the computation). -/
def reserveGuard (cd : ℕ) (pool : Pool) (tree : EMLTree) : Bool :=
  weightedCost cd tree ≥ pool.reserveB

/-- The result of an AMM close operation: the fair price, the friction cost
    deduction, and the net residue.
    
    INVARIANT NOTE: the field `h_nonnegative : residue ≥ 0` is intentionally
    VACUOUS in ℕ arithmetic (truncated subtraction means residue is always
    ≥ 0). The *operational* guarantee that price ≥ costDeduction is enforced
    by the caller-side `reserveGuard` returning false, which ensures
    `weightedCost cd tree < pool.reserveB` (the pool survives the computation). -/
structure CloseResult where
  price         : Nat
  costDeduction : Nat
  residue       : Nat
  h_nonnegative : residue ≥ 0    -- vacuous in ℕ; real invariant is caller-side reserveGuard

/-- The certified close step: AMM computes fair price; subdivision closure
    provides the weighted cost.
    
    Precondition (caller responsibility): `¬ reserveGuard cd pool tree`
    (i.e., `weightedCost cd tree < pool.reserveB`).
    
    Returns a CloseResult with price, costDeduction, and residue (net value). -/
def certifiedClose (cd : ℕ) (pool : Pool) (tree : EMLTree) (dx : Nat) : CloseResult :=
  let price := swapOut pool dx
  let costDeduction := weightedCost cd tree
  let residue := price - costDeduction
  {
    price := price
    costDeduction := costDeduction
    residue := residue
    h_nonnegative := Nat.zero_le (price - costDeduction)
  }

-- ============================================================================
-- Section 7: Market type and closure (absorbed from MarketClosure.lean)
-- ============================================================================

/-- The three possible outcomes of routing a swap through the AMM.
    
    | Variant          | Meaning                                                |
    |------------------|--------------------------------------------------------|
    | `.openMarket`    | Weighted cost is zero (tree already in right-comb form |
    |                   | or friction density is zero at cd=0). No cost deducted. |
    | `.closedMarket`  | Reserved guard passes: cost < reserveB, so a certified  |
    |                   | price is emitted with cost deduction.                   |
    | `.paradoxMarket` | Reserve guard fails: cost ≥ reserveB, the pool would    |
    |                   | be annihilated. No certificate emitted.                 |
    
    The halting case (cost = reserveB exactly) is lumped into `.paradoxMarket`
    because the guard returns `true` for `cost ≥ reserveB`. -/
inductive MarketType where
  | openMarket
  | closedMarket
  | paradoxMarket
  deriving DecidableEq, Repr

/-- The certified close receipt: wraps the tree, its contraction proof, and
    the AMM pricing fields. The `contracts_to source (rightComb source.size)`
    condition is the formal guarantee that the route's tree contracts to its
    right-comb normal form (the "subdivision" is found). -/
structure CertifiedPrice where
  source : EMLTree
  target : EMLTree
  proof  : contracts_to source target
  close  : CloseResult

/-- Decide the market type from the CD step, pool, and tree.
    
    - If `weightedCost cd tree = 0` (tree is already in right-comb form,
      or cd = 0 makes cost zero): `.openMarket` — no friction to pay.
    - Else if `¬ reserveGuard cd pool tree` (cost < reserveB): `.closedMarket` —
      the pool survives, a certified price can be emitted.
    - Else (cost ≥ reserveB): `.paradoxMarket` — the swap would annihilate
      the pool. -/
def decideMarketType (cd : ℕ) (pool : Pool) (tree : EMLTree) : MarketType :=
  if weightedCost cd tree = 0 then
    .openMarket
  else if ¬ reserveGuard cd pool tree then
    .closedMarket
  else
    .paradoxMarket

/-- The complete market closure: given a Cayley–Dickson step, pool, tree, and
    swap amount, decides the market type and (if closed) emits a CertifiedPrice.
    
    Pipeline:
    1. Compute `weightedCost cd tree` — the friction cost.
    2. Decide the market type via `decideMarketType`.
    3. If closedMarket: compute `swapOut`, deduct cost, emit CertifiedPrice
       with `contracts_to_closure` as the proof.
    4. If openMarket or paradoxMarket: no certificate emitted.
    
    This replaces the earlier `MarketClosure.marketClosure` which depended on
    `InstitutionalClosure`, `KernelChoice`, and `SplitOctonionCost`. The new
    version is purely combinatorial — the subdivision algebra IS the market
    closure. -/
def marketClosure (cd : ℕ) (pool : Pool) (tree : EMLTree) (dx : Nat) :
    MarketType × Option CertifiedPrice :=
  let mkt := decideMarketType cd pool tree
  let priceOpt : Option CertifiedPrice :=
    match mkt with
    | .closedMarket =>
      let target := SubdivisionClosure.closure cd tree
      let h_proof : contracts_to tree target := SubdivisionClosure.contracts_to_closure tree
      let closeRes := certifiedClose cd pool tree dx
      some {
        source := tree
        target := target
        proof := h_proof
        close := closeRes
      }
    | _ => none
  (mkt, priceOpt)

/-- In the open market case, the weighted cost is zero, meaning the tree
    is already in right-comb normal form (or cd=0). -/
theorem openMarket_iff_cost_zero (cd : ℕ) (pool : Pool) (tree : EMLTree) :
    decideMarketType cd pool tree = .openMarket ↔ weightedCost cd tree = 0 := by
  dsimp [decideMarketType]
  by_cases hzero : weightedCost cd tree = 0
  · simp [hzero]
  · have h_not_open : decideMarketType cd pool tree ≠ .openMarket := by
      dsimp [decideMarketType, reserveGuard]
      split
      · exfalso; exact hzero (by assumption)
      · split <;> decide
    constructor
    · intro h; exfalso; exact h_not_open h
    · intro h; exfalso; exact hzero h

/-- In the closed market case, the weighted cost is positive but less than
    the reserve: `0 < weightedCost cd tree < pool.reserveB`. -/
theorem closedMarket_iff_cost_positive_and_reserve_ok (cd : ℕ) (pool : Pool) (tree : EMLTree) :
    decideMarketType cd pool tree = .closedMarket ↔
    0 < weightedCost cd tree ∧ weightedCost cd tree < pool.reserveB := by
  dsimp [decideMarketType, reserveGuard]
  by_cases hzero : weightedCost cd tree = 0
  · simp [hzero]
  · have hpos : 0 < weightedCost cd tree := Nat.pos_of_ne_zero hzero
    by_cases hge : weightedCost cd tree ≥ pool.reserveB
    · simp [hzero, hpos, hge]
    · have hlt : weightedCost cd tree < pool.reserveB := Nat.lt_of_not_ge hge
      simp [hzero, hpos, hlt]

/-- In the paradox market case, the weighted cost exceeds or equals the
    reserve (and is non-zero). -/
theorem paradoxMarket_iff_cost_ge_reserve (cd : ℕ) (pool : Pool) (tree : EMLTree) :
    decideMarketType cd pool tree = .paradoxMarket ↔
    weightedCost cd tree ≥ pool.reserveB ∧ weightedCost cd tree ≠ 0 := by
  dsimp [decideMarketType, reserveGuard]
  by_cases hzero : weightedCost cd tree = 0
  · simp [hzero]
  · by_cases hge : weightedCost cd tree ≥ pool.reserveB
    · simp [hzero, hge]
    · simp [hzero, hge]

end AMM
