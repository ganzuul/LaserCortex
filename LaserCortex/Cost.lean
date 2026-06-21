/-
# Module: Cost

## Intent

Defines a recursive cost function Φ over EML trees parameterized by logic-specific node cost structures, proving that for logics with zero right-division, Φ equals tree size and is invariant under Tamari rotations and contraction paths.

## Contracts

[NodeCost, NodeCost.apply, nodeParam, nodeParam_bias_one, nodeParam_leftWeight_ge_one_of_not_mirror, nodeParam_leftWeight_nonneg, nodeParam_mirror_iff_spacetime, nodeParam_spacetime, Φ, Φ_Leaf, Φ_Node, Φ_eq_size_classical, Φ_contracts_one_eq_classical, Φ_contracts_to_eq_classical, Φ_spacetime_node]

## Cross-refs

LaserCortex.EMLRegistry → EMLTree, rightComb, leftComb, contracts_one, contracts_to, contracts_one_size_eq; LaserCortex.LogicTypes → LogicType

## Invariants

(nodeParam L).bias = 1 for all L; (nodeParam L).leftWeight ≥ 0 (always, trivially for Nat); when ¬(nodeParam L).mirror, 1 ≤ (nodeParam L).leftWeight; divisor is (rightDiv + 1) preventing zero-division; Φ L t = t.size and Φ is invariant under contracts_one/contracts_to when (nodeParam L).rightDiv = 0, coupling = 0, mirror = false, and leftWeight = 1; Spacetime (mirrored, leftWeight=0, rightDiv=0) has Φ following the left spine: Φ(Node l r) = 1 + Φ(l).

## Tags

#lean4-theorem #axiom #invariant #proof-bound

-/

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes

namespace Cost

/-- Node cost parameters for a logic type.
    Interprets the EML operator eml(x,y) = exp(x) - ln(y) in discrete ℕ arithmetic:
    leftWeight amplifies the left subtree cost (exp-like),
    rightDiv compresses the right subtree cost (ln-like),
    bias adds the distinguished constant 1 from the EML grammar.

    When mirror = true, the left/right roles swap:
    leftWeight amplifies the right subtree (associator/space-dominant),
    rightDiv compresses the left subtree (commutator/time-suppressed).

    The coupling product term coupling·a·b/denom adds a cross-sector
    interaction (non-distributivity penalty), symmetric in a and b
    and thus mirror-invariant. -/
structure NodeCost where
  leftWeight : Nat
  rightDiv : Nat
  bias : Nat
  mirror : Bool := false
  coupling : Nat := 0
  denom : Nat := 10

/-- Apply node cost parameters to combine left and right subtree costs.
    When mirror = false (default): bias + leftWeight·a + b/(rightDiv+1) + coupling·a·b/max(1,denom)
    When mirror = true:            bias + a/(rightDiv+1) + leftWeight·b + coupling·a·b/max(1,denom)
    The product term is mirror-invariant because a·b = b·a. -/
def NodeCost.apply (c : NodeCost) (a b : Nat) : Nat :=
  let linear := if c.mirror then
    c.bias + (a / c.rightDiv.succ) + c.leftWeight * b
  else
    c.bias + c.leftWeight * a + (b / c.rightDiv.succ)
  let product := c.coupling * a * b / max 1 c.denom
  linear + product

/-- Node cost parameters for each logic type.
    Each logic type defines its own friction regime for combining subtrees,
    reflecting how cross-impact propagates through the lattice under that logic.
    The left-right asymmetry mirrors eml(x,y) = exp(x) - ln(y):
    leftWeight > 1 amplifies the left subtree (exp-like blowup),
    rightDiv > 1 compresses the right subtree (ln-like saturation).

    Spacetime uses mirror=true, leftWeight=0, rightDiv=0: the commutator
    channel is silent and the associator channel passes through unwighted,
    making this the only space-biased logic in the framework. -/
def nodeParam (L : LogicTypes.LogicType) : NodeCost :=
  match L with
  | .Classical      => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Fuzzy          => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .ManyValued     => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Paraconsistent => { leftWeight := 2, rightDiv := 1, bias := 1, coupling := 1, denom := 8 }
  | .Temporal       => { leftWeight := 2, rightDiv := 1, bias := 1, coupling := 1, denom := 8 }
  | .Deontic        => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .Epistemic      => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .Quantum        => { leftWeight := 1, rightDiv := 1, bias := 1, coupling := 1, denom := 10 }
  | .Intuitionistic => { leftWeight := 1, rightDiv := 0, bias := 1 }
  | .Relevance      => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Free           => { leftWeight := 1, rightDiv := 0, bias := 1 }
  | .Infinitary     => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Modal          => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Spacetime      => { leftWeight := 0, rightDiv := 0, bias := 1, mirror := true }
  | .Boolean        => { leftWeight := 1, rightDiv := 0, bias := 1 }

-- ============================================================================
-- Node parameter lemmas
-- ============================================================================

theorem nodeParam_bias_one (L : LogicTypes.LogicType) : (nodeParam L).bias = 1 := by
  cases L <;> rfl

/-- Unmirrored logics always amplify the left subtree (leftWeight ≥ 1).
    Mirrored logics may have leftWeight = 0 (commutator channel silent). -/
theorem nodeParam_leftWeight_ge_one_of_not_mirror (L : LogicTypes.LogicType)
    (h : ¬(nodeParam L).mirror) : 1 ≤ (nodeParam L).leftWeight := by
  cases L <;> simp [nodeParam] at h ⊢ <;> decide

/-- All logics have non-negative leftWeight (trivially true for Nat). -/
theorem nodeParam_leftWeight_nonneg (L : LogicTypes.LogicType) :
    0 ≤ (nodeParam L).leftWeight := Nat.zero_le _

/-- Only Spacetime is mirrored. -/
theorem nodeParam_mirror_iff_spacetime (L : LogicTypes.LogicType) :
    (nodeParam L).mirror = true ↔ L = .Spacetime := by
  cases L <;> simp [nodeParam] <;> try rfl

/-- Spacetime has zero coupling. -/
theorem nodeParam_spacetime_coupling : (nodeParam .Spacetime).coupling = 0 := by
  rfl

/-- Spacetime is mirrored with leftWeight=0 and rightDiv=0. -/
theorem nodeParam_spacetime : nodeParam .Spacetime =
    { leftWeight := 0, rightDiv := 0, bias := 1, mirror := true, coupling := 0, denom := 10 } := by
  rfl

-- ============================================================================
-- Φ definition
-- ============================================================================

/-- Cross-impact cost of an EML tree under a given logic type. -/
def Φ (L : LogicTypes.LogicType) : EMLRegistry.EMLTree → Nat
  | .Leaf => 0
  | .Node l r => (nodeParam L).apply (Φ L l) (Φ L r)

theorem Φ_Leaf (L : LogicTypes.LogicType) : Φ L .Leaf = 0 := rfl

theorem Φ_Node (L : LogicTypes.LogicType) (l r : EMLRegistry.EMLTree) :
    Φ L (.Node l r) = (nodeParam L).apply (Φ L l) (Φ L r) := rfl

-- ============================================================================
-- Decidable instance for Bool needed for if-simplification
-- ============================================================================

/-- Helper: unfold NodeCost.apply when mirror is false (the common case). -/
theorem NodeCost.apply_not_mirror (c : NodeCost) (a b : Nat) (h : ¬c.mirror) :
    c.apply a b = c.bias + c.leftWeight * a + (b / c.rightDiv.succ) +
      c.coupling * a * b / max 1 c.denom := by
  simp [NodeCost.apply, h]

/-- Helper: unfold NodeCost.apply when mirror is true. -/
theorem NodeCost.apply_mirror (c : NodeCost) (a b : Nat) (h : c.mirror = true) :
    c.apply a b = c.bias + (a / c.rightDiv.succ) + c.leftWeight * b +
      c.coupling * a * b / max 1 c.denom := by
  simp [NodeCost.apply, h]

/-- Helper: unfold NodeCost.apply when coupling is zero. -/
theorem NodeConst.apply_zero_coupling (c : NodeCost) (a b : Nat) (h : c.coupling = 0) :
    c.coupling * a * b / max 1 c.denom = 0 := by
  simp [h]

-- ============================================================================
-- Classical theorems (rightDiv = 0, coupling = 0, mirror = false, leftWeight = 1)
-- These apply to Boolean, Intuitionistic, and Free.
-- ============================================================================

/-- For logics with rightDiv = 0, coupling = 0, mirror = false, leftWeight = 1,
    Φ equals tree size. This is the key theorem: the flat landscape. -/
theorem Φ_eq_size_classical (L : LogicTypes.LogicType) (t : EMLRegistry.EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1) :
    Φ L t = t.size := by
  induction t with
  | Leaf => simp [Φ, EMLRegistry.EMLTree.size]
  | Node l r ih_l ih_r =>
    rw [Φ_Node, NodeCost.apply_not_mirror _ _ _ hM]
    -- coupling = 0 kills the product term
    simp only [hC, Nat.zero_mul, Nat.add_zero, Nat.zero_div, Nat.div_one]
    -- rightDiv = 0 means denom = 1, leftWeight = 1 means amplification is identity
    rw [nodeParam_bias_one L, hW, hD]
    rw [ih_l, ih_r, EMLRegistry.EMLTree.size]
    simp [Nat.one_mul, Nat.succ_eq_add_one]

/-- Cost is preserved by Tamari rotation for logics with rightDiv = 0, coupling = 0,
    mirror = false, leftWeight = 1. -/
theorem Φ_contracts_one_eq_classical (L : LogicTypes.LogicType) {s t : EMLRegistry.EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (h : EMLRegistry.contracts_one s t) : Φ L s = Φ L t := by
  have hΦs : Φ L s = s.size := Φ_eq_size_classical L s hD hC hM hW
  have hΦt : Φ L t = t.size := Φ_eq_size_classical L t hD hC hM hW
  have hsize : s.size = t.size := EMLRegistry.contracts_one_size_eq h
  calc
    Φ L s = s.size := hΦs
    _ = t.size := hsize
    _ = Φ L t := Eq.symm hΦt

/-- Cost is preserved by multi-step paths for logics with rightDiv = 0, coupling = 0,
    mirror = false, leftWeight = 1. -/
theorem Φ_contracts_to_eq_classical (L : LogicTypes.LogicType) {s t : EMLRegistry.EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (h : EMLRegistry.contracts_to s t) : Φ L s = Φ L t := by
  have hΦs : Φ L s = s.size := Φ_eq_size_classical L s hD hC hM hW
  have hΦt : Φ L t = t.size := Φ_eq_size_classical L t hD hC hM hW
  have hsize : s.size = t.size := EMLRegistry.contracts_to_size_eq h
  calc
    Φ L s = s.size := hΦs
    _ = t.size := hsize
    _ = Φ L t := Eq.symm hΦt

-- ============================================================================
-- Spacetime-specific theorems
-- ============================================================================

/-- Spacetime cost at any node is 1 + cost of left child.
    mirror=true swaps: bias + a/(rightDiv+1) + leftWeight*b + product.
    With leftWeight=0, rightDiv=0, coupling=0: 1 + a/1 + 0 + 0 = 1 + a. -/
theorem Φ_spacetime_node (l r : EMLRegistry.EMLTree) :
    Φ .Spacetime (.Node l r) = 1 + Φ .Spacetime l := by
  rw [Φ_Node, NodeCost.apply_mirror _ _ _ rfl]
  simp [nodeParam_spacetime, nodeParam_spacetime_coupling,
        Nat.div_one, Nat.zero_mul, Nat.add_zero]

end Cost