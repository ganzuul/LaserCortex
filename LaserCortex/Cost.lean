/-
# Module: Cost

## Intent

Defines a recursive cost function Φ over EML trees parameterized by logic-specific node cost structures, proving that for logics with zero right-division, Φ equals tree size and is invariant under Tamari rotations and contraction paths.

Depth-2 extensions:
- maxSem (Intuitionistic): Φ equals tree height (proof depth, not proof size)
- satCap (Fuzzy): Φ is bounded above by the saturation cap

## Contracts

[NodeCost, NodeCost.apply, nodeParam, nodeParam_bias_one, nodeParam_leftWeight_ge_one_of_not_mirror, nodeParam_leftWeight_nonneg, nodeParam_mirror_iff_spacetime, nodeParam_spacetime, nodeParam_intuitionistic, nodeParam_fuzzy, Φ, Φ_Leaf, Φ_Node, Φ_eq_size_classical, Φ_contracts_one_eq_classical, Φ_contracts_to_eq_classical, Φ_spacetime_node, Φ_intuitionistic_eq_height, Φ_fuzzy_le_satCap]

## Cross-refs

LaserCortex.EMLRegistry → EMLTree, rightComb, leftComb, contracts_one, contracts_to, contracts_one_size_eq; LaserCortex.LogicTypes → LogicType

## Invariants

(nodeParam L).bias = 1 for all L; (nodeParam L).leftWeight ≥ 0 (always, trivially for Nat); when ¬(nodeParam L).mirror, 1 ≤ (nodeParam L).leftWeight; divisor is (rightDiv + 1) preventing zero-division; Φ L t = t.size and Φ is invariant under contracts_one/contracts_to when (nodeParam L).rightDiv = 0, coupling = 0, mirror = false, leftWeight = 1, maxSem = false, satCap = 0; Spacetime (mirrored, leftWeight=0, rightDiv=0) has Φ following the left spine: Φ(Node l r) = 1 + Φ(l); Intuitionistic (maxSem=true) has Φ = tree height; Fuzzy (satCap>0) has Φ bounded by satCap.

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
    and thus mirror-invariant.

    Depth-2 extensions:
    maxSem = true: use max(Φ(l), Φ(r)) + bias (proof-depth semantics).
      Intuitionistic logic uses this: the cost of a proof is its depth,
      not its size. Ignoring left/right asymmetry captures the constructive
      insight that verification depends on the deepest assumption chain.
    satCap > 0: cap the result at satCap (saturation semantics).
      Fuzzy logic uses this: truth values saturate at 1. In ℕ-arithmetic,
      a positive satCap prevents Φ from growing beyond a bound, modeling
      the way fuzzy boundaries collapse distinctions above a threshold.
      satCap = 0 means no cap (depth-1 behavior). -/
structure NodeCost where
  leftWeight : Nat
  rightDiv : Nat
  bias : Nat
  mirror : Bool := false
  coupling : Nat := 0
  denom : Nat := 10
  maxSem : Bool := false
  satCap : Nat := 0

/-- Uncapped application: computes the raw cost before saturation.
    Separating this from the satCap cap makes proofs cleaner. -/
def NodeCost.applyUncapped (c : NodeCost) (a b : Nat) : Nat :=
  if c.maxSem then
    max a b + c.bias
  else if c.mirror then
    c.bias + (a / c.rightDiv.succ) + c.leftWeight * b + c.coupling * a * b / max 1 c.denom
  else
    c.bias + c.leftWeight * a + (b / c.rightDiv.succ) + c.coupling * a * b / max 1 c.denom

/-- Apply node cost parameters to combine left and right subtree costs.

    Depth-1 (sum mode, maxSem = false, satCap = 0):
      When mirror = false: bias + leftWeight·a + b/(rightDiv+1) + coupling·a·b/max(1,denom)
      When mirror = true:  bias + a/(rightDiv+1) + leftWeight·b + coupling·a·b/max(1,denom)

    Depth-2 max-semantics (maxSem = true):
      max(a, b) + bias (coupling is zero in this mode)

    Depth-2 saturation (satCap > 0):
      min(satCap, uncapped result); satCap = 0 means no cap. -/
def NodeCost.apply (c : NodeCost) (a b : Nat) : Nat :=
  let uncapped := c.applyUncapped a b
  if c.satCap = 0 then uncapped else min c.satCap uncapped

/-- Node cost parameters for each logic type.
    Each logic type defines its own friction regime for combining subtrees,
    reflecting how cross-impact propagates through the lattice under that logic.

    Depth-2:
    - Intuitionistic: maxSem=true → Φ = tree height (proof depth)
    - Fuzzy: satCap=5 → Φ saturates at 5 (boundary collapse)
    - All other logics: depth-1 (sum mode, no cap) -/
def nodeParam (L : LogicTypes.LogicType) : NodeCost :=
  match L with
  | .Classical      => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Fuzzy          => { leftWeight := 1, rightDiv := 2, bias := 1, satCap := 5 }
  | .ManyValued     => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Paraconsistent => { leftWeight := 2, rightDiv := 1, bias := 1, coupling := 1, denom := 8 }
  | .Temporal       => { leftWeight := 2, rightDiv := 1, bias := 1, coupling := 1, denom := 8 }
  | .Deontic        => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .Epistemic      => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .Quantum        => { leftWeight := 1, rightDiv := 1, bias := 1, coupling := 1, denom := 10 }
  | .Intuitionistic => { leftWeight := 1, rightDiv := 0, bias := 1, maxSem := true }
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

/-- Spacetime is mirrored with leftWeight=0, rightDiv=0. -/
theorem nodeParam_spacetime : nodeParam .Spacetime =
    { leftWeight := 0, rightDiv := 0, bias := 1, mirror := true, coupling := 0, denom := 10 } := by
  rfl

/-- Intuitionistic uses maxSem with bias=1. -/
theorem nodeParam_intuitionistic : nodeParam .Intuitionistic =
    { leftWeight := 1, rightDiv := 0, bias := 1, maxSem := true } := by
  rfl

/-- Fuzzy has satCap=5. -/
theorem nodeParam_fuzzy : nodeParam .Fuzzy =
    { leftWeight := 1, rightDiv := 2, bias := 1, satCap := 5 } := by
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
-- Helper theorems for NodeCost.apply
-- ============================================================================

/-- Helper: applyUncapped when maxSem = false, mirror = false (standard sum mode). -/
theorem NodeCost.applyUncapped_not_mirror (c : NodeCost) (a b : Nat)
    (hMS : ¬c.maxSem) (hMi : ¬c.mirror) :
    c.applyUncapped a b = c.bias + c.leftWeight * a + (b / c.rightDiv.succ) +
      c.coupling * a * b / max 1 c.denom := by
  simp [NodeCost.applyUncapped, hMS, hMi]

/-- Helper: applyUncapped when maxSem = false, mirror = true. -/
theorem NodeCost.applyUncapped_mirror (c : NodeCost) (a b : Nat)
    (hMS : ¬c.maxSem) (hMi : c.mirror = true) :
    c.applyUncapped a b = c.bias + (a / c.rightDiv.succ) + c.leftWeight * b +
      c.coupling * a * b / max 1 c.denom := by
  simp [NodeCost.applyUncapped, hMS, hMi]

/-- Helper: applyUncapped when maxSem = true (max-semantics). -/
theorem NodeCost.applyUncapped_maxSem (c : NodeCost) (a b : Nat)
    (hMS : c.maxSem = true) :
    c.applyUncapped a b = max a b + c.bias := by
  simp [NodeCost.applyUncapped, hMS]

/-- Helper: apply in sum mode (no max, no cap) when mirror = false. -/
theorem NodeCost.apply_not_mirror (c : NodeCost) (a b : Nat)
    (hMS : ¬c.maxSem) (hMi : ¬c.mirror) (hSC : c.satCap = 0) :
    c.apply a b = c.bias + c.leftWeight * a + (b / c.rightDiv.succ) +
      c.coupling * a * b / max 1 c.denom := by
  show (let uncapped := c.applyUncapped a b;
        if c.satCap = 0 then uncapped else min c.satCap uncapped) = _
  rw [NodeCost.applyUncapped_not_mirror c a b hMS hMi]
  simp only [hSC, if_true]

/-- Helper: apply in sum mode (no max, no cap) when mirror = true. -/
theorem NodeCost.apply_mirror (c : NodeCost) (a b : Nat)
    (hMS : ¬c.maxSem) (hMi : c.mirror = true) (hSC : c.satCap = 0) :
    c.apply a b = c.bias + (a / c.rightDiv.succ) + c.leftWeight * b +
      c.coupling * a * b / max 1 c.denom := by
  show (let uncapped := c.applyUncapped a b;
        if c.satCap = 0 then uncapped else min c.satCap uncapped) = _
  rw [NodeCost.applyUncapped_mirror c a b hMS hMi]
  simp only [hSC, if_true]

/-- Helper: apply when maxSem = true and satCap = 0. -/
theorem NodeCost.apply_maxSem (c : NodeCost) (a b : Nat)
    (hMS : c.maxSem = true) (hSC : c.satCap = 0) :
    c.apply a b = max a b + c.bias := by
  show (let uncapped := c.applyUncapped a b;
        if c.satCap = 0 then uncapped else min c.satCap uncapped) = _
  rw [NodeCost.applyUncapped_maxSem c a b hMS]
  simp only [hSC, if_true]

/-- Helper: coupling term is zero when coupling = 0. -/
theorem NodeCost.apply_zero_coupling (c : NodeCost) (a b : Nat) (h : c.coupling = 0) :
    c.coupling * a * b / max 1 c.denom = 0 := by
  simp [h]

/-- Helper: satCap bounds the result. -/
theorem NodeCost.apply_le_satCap (c : NodeCost) (a b : Nat) (h : c.satCap > 0) :
    c.apply a b ≤ c.satCap := by
  by_cases h0 : c.satCap = 0
  · -- satCap = 0 contradicts h > 0
    omega
  · -- satCap > 0: min satCap uncapped ≤ satCap
    simp only [NodeCost.apply, h0, if_false, Nat.min_le_left]

-- ============================================================================
-- Classical theorems (rightDiv = 0, coupling = 0, mirror = false, leftWeight = 1)
-- These apply to Boolean and Free.
-- NOTE: Intuitionistic now uses maxSem=true, so it has Φ = height, not Φ = size.
-- ============================================================================

/-- For logics with rightDiv = 0, coupling = 0, mirror = false, leftWeight = 1,
    maxSem = false, satCap = 0: Φ equals tree size. This is the flat landscape. -/
theorem Φ_eq_size_classical (L : LogicTypes.LogicType) (t : EMLRegistry.EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    Φ L t = t.size := by
  induction t with
  | Leaf => simp [Φ, EMLRegistry.EMLTree.size]
  | Node l r ih_l ih_r =>
    rw [Φ_Node, NodeCost.apply_not_mirror _ _ _ hMS hM hSC]
    -- coupling = 0 kills the product term
    simp only [hC, Nat.zero_mul, Nat.add_zero, Nat.zero_div]
    -- rightDiv = 0 means denominator = 1, leftWeight = 1 means amplification is identity
    rw [nodeParam_bias_one L, hW, hD]
    rw [ih_l, ih_r, EMLRegistry.EMLTree.size]
    simp [Nat.one_mul, Nat.succ_eq_add_one]

/-- Cost is preserved by Tamari rotation for classical-depth logics. -/
theorem Φ_contracts_one_eq_classical (L : LogicTypes.LogicType) {s t : EMLRegistry.EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0)
    (h : EMLRegistry.contracts_one s t) : Φ L s = Φ L t := by
  have hΦs : Φ L s = s.size := Φ_eq_size_classical L s hD hC hM hW hMS hSC
  have hΦt : Φ L t = t.size := Φ_eq_size_classical L t hD hC hM hW hMS hSC
  have hsize : s.size = t.size := EMLRegistry.contracts_one_size_eq h
  calc
    Φ L s = s.size := hΦs
    _ = t.size := hsize
    _ = Φ L t := Eq.symm hΦt

/-- Cost is preserved by multi-step paths for classical-depth logics. -/
theorem Φ_contracts_to_eq_classical (L : LogicTypes.LogicType) {s t : EMLRegistry.EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0)
    (h : EMLRegistry.contracts_to s t) : Φ L s = Φ L t := by
  have hΦs : Φ L s = s.size := Φ_eq_size_classical L s hD hC hM hW hMS hSC
  have hΦt : Φ L t = t.size := Φ_eq_size_classical L t hD hC hM hW hMS hSC
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
  have hMS : ¬(nodeParam .Spacetime).maxSem := by simp [nodeParam]
  have hSC : (nodeParam .Spacetime).satCap = 0 := by simp [nodeParam]
  rw [Φ_Node, NodeCost.apply_mirror _ _ _ hMS rfl hSC]
  simp [nodeParam_spacetime, Nat.zero_mul, Nat.add_zero]

-- ============================================================================
-- Intuitionistic-specific theorems (depth-2, max-semantics)
-- ============================================================================

/-- Intuitionistic Φ equals tree height.
    In intuitionistic logic, the cost of a proof is its depth (longest
    assumption chain), not its size (total number of steps).
    maxSem=true: Φ(Node l r) = max(Φ(l), Φ(r)) + bias = max(Φ(l), Φ(r)) + 1 = height. -/
theorem Φ_intuitionistic_eq_height (t : EMLRegistry.EMLTree) :
    Φ .Intuitionistic t = t.height := by
  induction t with
  | Leaf => simp [Φ, EMLRegistry.EMLTree.height]
  | Node l r ih_l ih_r =>
    rw [Φ_Node]
    have hMS : (nodeParam .Intuitionistic).maxSem = true := by rfl
    have hSC : (nodeParam .Intuitionistic).satCap = 0 := by rfl
    rw [NodeCost.apply_maxSem _ _ _ hMS hSC]
    rw [nodeParam_bias_one]
    rw [ih_l, ih_r]
    simp [EMLRegistry.EMLTree.height]
    omega

-- ============================================================================
-- Fuzzy-specific theorems (depth-2, saturation cap)
-- ============================================================================

/-- Fuzzy Φ is bounded by the saturation cap.
    In fuzzy logic, truth values saturate: Φ never exceeds satCap.
    This models the way fuzzy boundaries collapse distinctions above a threshold. -/
theorem Φ_fuzzy_le_satCap (t : EMLRegistry.EMLTree) :
    Φ .Fuzzy t ≤ (nodeParam .Fuzzy).satCap := by
  induction t with
  | Leaf => decide
  | Node l r ih_l ih_r =>
    rw [Φ_Node]
    exact NodeCost.apply_le_satCap (nodeParam .Fuzzy) (Φ .Fuzzy l) (Φ .Fuzzy r) (by decide)

end Cost