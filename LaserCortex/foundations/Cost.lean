/-
# Module: Cost (rescued spine)

## Intent

The NodeCost cost geometry over EML trees: `NodeCost` parameters, the
`nodeParam` table for all 15 named logics, the recursive cost functional
Φ, and the classical / mirrored / max-semantics / saturation behaviour
theorems. Restored from `Cost.lean` (deleted `a8e3c57`, 2026-07-06) and
`SplitOctonionLogic.lean` (deleted `e212301`, 2026-07-07) per the
archaeology triage 062 §5.7(a) — the formal spine that notes 006/007 cite
(`nodeParam_bias_one`, `bias_invariant`, `distinctNodeCost_enumeration`)
while only the Python mirror (`infra/_cortex/_cost.py`) survived.

Re-homed onto the LIVE carrier `LaserCortex.foundations.Tamari.EMLTree`
(ctor-identical to the old `EMLRegistry.EMLTree`), and carrying two
corrections over the archived text:

1. The collapse is 15 logics → **8** distinct cost geometries, not 7.
   The archived `distinctNodeCosts` list omitted the Free/Boolean row
   (`rightDiv = 0`), while `apply` divides by `rightDiv + 1` ∈ {1, 2}; the
   archived `distinctNodeCost_count : 7 = 7 := rfl` was vacuous scaffolding.
   `Cost.nodeParam_collapse` below proves the true count by `decide`.
2. `Φ` takes the Tamari tree directly; contraction lemmas reuse the live
   `contracts_one` / `contracts_to` / `*_size_eq` from `foundations/Tamari`.

## Contracts

[NodeCost, NodeCost.applyUncapped, NodeCost.apply, nodeParam,
nodeParam_bias_one, nodeParam_leftWeight_ge_one_of_not_mirror,
nodeParam_mirror_iff_spacetime, nodeParam_spacetime, nodeParam_intuitionistic,
nodeParam_fuzzy, Φ, Φ_Leaf, Φ_Node, Φ_of_nc, Φ_eq_Φ_of_nc,
Φ_eq_size_classical, Φ_contracts_one_eq_classical, Φ_contracts_to_eq_classical,
Φ_spacetime_node, Φ_intuitionistic_eq_height, Φ_fuzzy_le_satCap,
distinctNodeCost_enumeration, nodeParam_collapse, only_spacetime_is_mirrored,
bias_invariant, denom_invariant_except_paraconsistent,
toSO, bool_if_inj, toSO_injective]

## Cross-refs

`LaserCortex.foundations.LogicTypes` (the 15-case enum),
`LaserCortex.foundations.Tamari` (carrier + contraction), notes 006/007
(7-Skeleton reading corrected to 8 geometries — see 062 §5.7(a)),
`TDD_SPLIT_OCTONION_LOGIC.md`

## Invariants

`(nodeParam L).bias = 1` for all 15 logics (amplitude-free commitment);
mirror = false except Spacetime; classical-depth logics
(rightDiv = 0, coupling = 0, ¬mirror, leftWeight = 1, ¬maxSem, satCap = 0)
measure raw tree size and are contraction-invariant; Intuitionistic Φ is
proof DEPTH (height), Fuzzy Φ saturates at satCap, Spacetime follows the
left spine only.

## Tags

#lean4-theorem #invariant #proof-bound #rescued
-/

import LaserCortex.foundations.Algebra
import LaserCortex.foundations.LogicTypes
import LaserCortex.foundations.Tamari

namespace Cost

open LogicTypes

/-- Node cost parameters for a logic type.
    Interprets the EML operator eml(x,y) = exp(x) - ln(y) in discrete ℕ
    arithmetic: leftWeight amplifies the left subtree cost (exp-like),
    rightDiv compresses the right subtree cost (ln-like), bias adds the
    distinguished constant 1 from the EML grammar.

    When mirror = true the left/right roles swap: leftWeight amplifies the
    right subtree (associator/space-dominant), rightDiv compresses the left
    subtree (commutator/time-suppressed). coupling·a·b/max(1,denom) is a
    symmetric cross-sector (non-distributivity) penalty.

    Depth-2 extensions: maxSem = true gives proof-depth semantics
    max(a,b) + bias (Intuitionistic); satCap > 0 caps the result (Fuzzy
    saturation); satCap = 0 means no cap. -/
structure NodeCost where
  leftWeight : Nat
  rightDiv : Nat
  bias : Nat
  mirror : Bool := false
  coupling : Nat := 0
  denom : Nat := 10
  maxSem : Bool := false
  satCap : Nat := 0
  deriving DecidableEq

/-- Uncapped application: the raw cost before saturation. Separating this
    from the satCap cap keeps proofs clean. -/
def NodeCost.applyUncapped (c : NodeCost) (a b : Nat) : Nat :=
  if c.maxSem then
    max a b + c.bias
  else if c.mirror then
    c.bias + (a / c.rightDiv.succ) + c.leftWeight * b +
      c.coupling * a * b / max 1 c.denom
  else
    c.bias + c.leftWeight * a + (b / c.rightDiv.succ) +
      c.coupling * a * b / max 1 c.denom

/-- Apply node cost parameters to combine left and right subtree costs.

    Depth-1 (sum mode): mirror = false gives
      bias + leftWeight·a + b/(rightDiv+1) + coupling·a·b/max(1,denom);
      mirror = true swaps a ↔ b roles.
    Depth-2: maxSem gives max(a,b) + bias; satCap > 0 caps at satCap. -/
def NodeCost.apply (c : NodeCost) (a b : Nat) : Nat :=
  let uncapped := c.applyUncapped a b
  if c.satCap = 0 then uncapped else min c.satCap uncapped

/-- Node cost parameters for each logic type: each named logic is a point
    in the friction-parameter space, i.e. its own rule for combining
    subtree costs. This is the table the Python `_cost.py::node_param`
    mirrors. -/
def nodeParam (L : LogicTypes.LogicType) : NodeCost :=
  match L with
  | .Classical      => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Fuzzy          => { leftWeight := 1, rightDiv := 2, bias := 1, satCap := 5 }
  | .ManyValued     => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Paraconsistent =>
    { leftWeight := 2, rightDiv := 1, bias := 1, coupling := 1, denom := 8 }
  | .Temporal       =>
    { leftWeight := 2, rightDiv := 1, bias := 1, coupling := 1, denom := 8 }
  | .Deontic        => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .Epistemic      => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .Quantum        =>
    { leftWeight := 1, rightDiv := 1, bias := 1, coupling := 1, denom := 10 }
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

/-- Every named logic pays exactly one atom of bias: the commitment unit
    is amplitude-free across the whole table (061 §2). -/
theorem nodeParam_bias_one (L : LogicTypes.LogicType) : (nodeParam L).bias = 1 := by
  cases L <;> rfl

/-- Unmirrored logics always amplify the left subtree (leftWeight ≥ 1);
    mirrored logics may go silent on the commutator channel. -/
theorem nodeParam_leftWeight_ge_one_of_not_mirror (L : LogicTypes.LogicType)
    (h : ¬(nodeParam L).mirror) : 1 ≤ (nodeParam L).leftWeight := by
  cases L <;> simp [nodeParam] at h ⊢ <;> decide

/-- Only Spacetime is mirrored. -/
theorem nodeParam_mirror_iff_spacetime (L : LogicTypes.LogicType) :
    (nodeParam L).mirror = true ↔ L = .Spacetime := by
  cases L <;> simp [nodeParam]

/-- Spacetime is mirrored with leftWeight = 0, rightDiv = 0. -/
theorem nodeParam_spacetime : nodeParam .Spacetime =
    { leftWeight := 0, rightDiv := 0, bias := 1, mirror := true,
      coupling := 0, denom := 10 } := by
  rfl

/-- Intuitionistic uses maxSem with bias = 1. -/
theorem nodeParam_intuitionistic : nodeParam .Intuitionistic =
    { leftWeight := 1, rightDiv := 0, bias := 1, maxSem := true } := by
  rfl

/-- Fuzzy has satCap = 5. -/
theorem nodeParam_fuzzy : nodeParam .Fuzzy =
    { leftWeight := 1, rightDiv := 2, bias := 1, satCap := 5 } := by
  rfl

-- ============================================================================
-- Φ: the recursive cost functional on Tamari trees
-- ============================================================================

/-- Cross-impact cost of an EML tree under a named logic. -/
def Φ (L : LogicTypes.LogicType) : EMLTree → Nat
  | .Leaf => 0
  | .Node l r => (nodeParam L).apply (Φ L l) (Φ L r)

theorem Φ_Leaf (L : LogicTypes.LogicType) : Φ L .Leaf = 0 := rfl

theorem Φ_Node (L : LogicTypes.LogicType) (l r : EMLTree) :
    Φ L (.Node l r) = (nodeParam L).apply (Φ L l) (Φ L r) := rfl

/-- Same recursion under an arbitrary point of parameter space rather than a
    named logic: what the archived SplitOctonionLogic tests used to probe
    the 8-dimensional cost space off the 15 landmarks. -/
def Φ_of_nc (nc : NodeCost) : EMLTree → Nat
  | .Leaf => 0
  | .Node l r => nc.apply (Φ_of_nc nc l) (Φ_of_nc nc r)

theorem Φ_of_nc_Leaf (nc : NodeCost) : Φ_of_nc nc .Leaf = 0 := rfl

theorem Φ_of_nc_Node (nc : NodeCost) (l r : EMLTree) :
    Φ_of_nc nc (.Node l r) = nc.apply (Φ_of_nc nc l) (Φ_of_nc nc r) := rfl

/-- The two Φ definitions agree on named logics. -/
theorem Φ_eq_Φ_of_nc (L : LogicTypes.LogicType) (t : EMLTree) :
    Φ L t = Φ_of_nc (nodeParam L) t := by
  induction t with
  | Leaf => rfl
  | Node l r ih_l ih_r =>
    rw [Φ_Node, Φ_of_nc_Node, ih_l, ih_r]

-- ============================================================================
-- apply-mode helpers
-- ============================================================================

theorem NodeCost.applyUncapped_not_mirror (c : NodeCost) (a b : Nat)
    (hMS : ¬c.maxSem) (hMi : ¬c.mirror) :
    c.applyUncapped a b = c.bias + c.leftWeight * a + (b / c.rightDiv.succ) +
      c.coupling * a * b / max 1 c.denom := by
  simp [NodeCost.applyUncapped, hMS, hMi]

theorem NodeCost.applyUncapped_mirror (c : NodeCost) (a b : Nat)
    (hMS : ¬c.maxSem) (hMi : c.mirror = true) :
    c.applyUncapped a b = c.bias + (a / c.rightDiv.succ) + c.leftWeight * b +
      c.coupling * a * b / max 1 c.denom := by
  simp [NodeCost.applyUncapped, hMS, hMi]

theorem NodeCost.applyUncapped_maxSem (c : NodeCost) (a b : Nat)
    (hMS : c.maxSem = true) :
    c.applyUncapped a b = max a b + c.bias := by
  simp [NodeCost.applyUncapped, hMS]

theorem NodeCost.apply_not_mirror (c : NodeCost) (a b : Nat)
    (hMS : ¬c.maxSem) (hMi : ¬c.mirror) (hSC : c.satCap = 0) :
    c.apply a b = c.bias + c.leftWeight * a + (b / c.rightDiv.succ) +
      c.coupling * a * b / max 1 c.denom := by
  show (let uncapped := c.applyUncapped a b;
        if c.satCap = 0 then uncapped else min c.satCap uncapped) = _
  rw [NodeCost.applyUncapped_not_mirror c a b hMS hMi]
  simp only [hSC, if_true]

theorem NodeCost.apply_mirror (c : NodeCost) (a b : Nat)
    (hMS : ¬c.maxSem) (hMi : c.mirror = true) (hSC : c.satCap = 0) :
    c.apply a b = c.bias + (a / c.rightDiv.succ) + c.leftWeight * b +
      c.coupling * a * b / max 1 c.denom := by
  show (let uncapped := c.applyUncapped a b;
        if c.satCap = 0 then uncapped else min c.satCap uncapped) = _
  rw [NodeCost.applyUncapped_mirror c a b hMS hMi]
  simp only [hSC, if_true]

theorem NodeCost.apply_maxSem (c : NodeCost) (a b : Nat)
    (hMS : c.maxSem = true) (hSC : c.satCap = 0) :
    c.apply a b = max a b + c.bias := by
  show (let uncapped := c.applyUncapped a b;
        if c.satCap = 0 then uncapped else min c.satCap uncapped) = _
  rw [NodeCost.applyUncapped_maxSem c a b hMS]
  simp only [hSC, if_true]

/-- satCap bounds the result. -/
theorem NodeCost.apply_le_satCap (c : NodeCost) (a b : Nat) (h : c.satCap > 0) :
    c.apply a b ≤ c.satCap := by
  show (let uncapped := c.applyUncapped a b;
        if c.satCap = 0 then uncapped else min c.satCap uncapped) ≤ _
  rw [if_neg (Nat.ne_of_gt h)]
  exact min_le_left _ _

-- ============================================================================
-- Classical-depth logics: Φ measures raw tree size, contraction-invariant
-- (rotation size-preservation is the live `contracts_one_size_eq` /
-- `contracts_to_size_eq` from foundations/Tamari)
-- ============================================================================

/-- For logics with rightDiv = 0, coupling = 0, mirror = false,
    leftWeight = 1, maxSem = false, satCap = 0 (the Free/Boolean row):
    Φ is exactly the node count of the tree. -/
theorem Φ_eq_size_classical (L : LogicTypes.LogicType) (t : EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    Φ L t = t.size := by
  induction t with
  | Leaf => simp [Φ, EMLTree.size]
  | Node l r ih_l ih_r =>
    rw [Φ_Node, NodeCost.apply_not_mirror _ _ _ hMS hM hSC]
    simp only [hC, Nat.zero_mul, Nat.add_zero, Nat.zero_div]
    rw [nodeParam_bias_one L, hW, hD, ih_l, ih_r, EMLTree.size]
    simp [Nat.succ_eq_add_one]

/-- Cost is preserved by a single Tamari rotation for classical-depth
    logics (both sides just count nodes). -/
theorem Φ_contracts_one_eq_classical (L : LogicTypes.LogicType) {s t : EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0)
    (h : contracts_one s t) : Φ L s = Φ L t := by
  have hΦs : Φ L s = s.size := Φ_eq_size_classical L s hD hC hM hW hMS hSC
  have hΦt : Φ L t = t.size := Φ_eq_size_classical L t hD hC hM hW hMS hSC
  rw [hΦs, hΦt, contracts_one_size_eq h]

/-- Cost is preserved by multi-step contraction paths. -/
theorem Φ_contracts_to_eq_classical (L : LogicTypes.LogicType) {s t : EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0)
    (h : contracts_to s t) : Φ L s = Φ L t := by
  have hΦs : Φ L s = s.size := Φ_eq_size_classical L s hD hC hM hW hMS hSC
  have hΦt : Φ L t = t.size := Φ_eq_size_classical L t hD hC hM hW hMS hSC
  rw [hΦs, hΦt, contracts_to_size_eq h]

-- ============================================================================
-- Per-logic behaviour: mirror, max-semantics, saturation
-- ============================================================================

/-- Spacetime cost at any node is 1 + cost of the LEFT child: mirrored
    semantics see only the time axis (the right spine is invisible). -/
theorem Φ_spacetime_node (l r : EMLTree) :
    Φ .Spacetime (.Node l r) = 1 + Φ .Spacetime l := by
  have hMS : ¬(nodeParam .Spacetime).maxSem := by decide
  have hSC : (nodeParam .Spacetime).satCap = 0 := by decide
  rw [Φ_Node, NodeCost.apply_mirror _ _ _ hMS rfl hSC]
  rw [nodeParam_bias_one]
  simp only [nodeParam, Nat.zero_mul, Nat.add_zero, Nat.zero_div,
    Nat.div_one]

/-- Intuitionistic Φ equals tree height: proof cost is DEPTH, not size. -/
theorem Φ_intuitionistic_eq_height (t : EMLTree) :
    Φ .Intuitionistic t = t.height := by
  induction t with
  | Leaf => simp [Φ, EMLTree.height]
  | Node l r ih_l ih_r =>
    rw [Φ_Node]
    have hMS : (nodeParam .Intuitionistic).maxSem = true := by rfl
    have hSC : (nodeParam .Intuitionistic).satCap = 0 := by rfl
    rw [NodeCost.apply_maxSem _ _ _ hMS hSC, nodeParam_bias_one, ih_l, ih_r]
    simp [EMLTree.height]
    omega

/-- Fuzzy Φ is bounded by the saturation cap: truth saturates at 1, and in
    ℕ-arithmetic that is a hard ceiling at satCap. -/
theorem Φ_fuzzy_le_satCap (t : EMLTree) :
    Φ .Fuzzy t ≤ (nodeParam .Fuzzy).satCap := by
  induction t with
  | Leaf => decide
  | Node l r ih_l ih_r =>
    rw [Φ_Node]
    exact NodeCost.apply_le_satCap (nodeParam .Fuzzy) (Φ .Fuzzy l) (Φ .Fuzzy r)
      (by decide)

-- ============================================================================
-- The collapse: 15 named logics, 8 cost geometries
-- ============================================================================

/-- The eight distinct NodeCost rows among the 15 named logics, with their
    member groups: Classical {Classical, ManyValued, Relevance, Infinitary,
    Modal}, Fuzzy, Para {Paraconsistent, Temporal}, Quantum,
    Intuitionistic, Spacetime, Deontic {Deontic, Epistemic},
    Free {Free, Boolean}. -/
def distinctNodeCosts : List NodeCost :=
  [ nodeParam .Classical, nodeParam .Fuzzy, nodeParam .Paraconsistent,
    nodeParam .Quantum, nodeParam .Intuitionistic, nodeParam .Spacetime,
    nodeParam .Deontic, nodeParam .Free ]

/-- All 15 logics, as a list, for counting. -/
def allLogics : List LogicTypes.LogicType :=
  [ .Fuzzy, .ManyValued, .Paraconsistent, .Temporal, .Deontic, .Epistemic,
    .Quantum, .Intuitionistic, .Relevance, .Free, .Infinitary, .Modal,
    .Spacetime, .Classical, .Boolean ]

/-- THE COLLAPSE (corrected): the nodeParam table has exactly **8** distinct
    rows over the 15 named logics. The archived claim was 7; the missing
    geometry is the Free/Boolean row (rightDiv = 0 ≠ 1 of the Classical
    group, and `apply` divides by rightDiv + 1, so the rows differ
    already on trees whose right subtree costs 1). Note 006's "7-skeleton"
    pun survives as prose about the Hopf cells, but the cost-geometry
    count is 8. -/
theorem nodeParam_collapse :
    ((allLogics.map nodeParam).eraseDups).length = 8 ∧
    (distinctNodeCosts.eraseDups).length = 8 := by
  constructor <;> decide

/-- The canonical partition, as equalities of table rows. -/
theorem distinctNodeCost_enumeration :
    (nodeParam .Classical = nodeParam .ManyValued ∧
     nodeParam .Classical = nodeParam .Relevance ∧
     nodeParam .Classical = nodeParam .Infinitary ∧
     nodeParam .Classical = nodeParam .Modal) ∧
    (nodeParam .Fuzzy).satCap = 5 ∧
    nodeParam .Paraconsistent = nodeParam .Temporal ∧
    (nodeParam .Quantum).coupling = 1 ∧ (nodeParam .Quantum).denom = 10 ∧
    (nodeParam .Intuitionistic).maxSem = true ∧
    (nodeParam .Spacetime).mirror = true ∧
    (nodeParam .Spacetime).leftWeight = 0 ∧
    nodeParam .Deontic = nodeParam .Epistemic ∧
    (nodeParam .Deontic).rightDiv = 2 ∧
    nodeParam .Free = nodeParam .Boolean ∧
    (nodeParam .Free).rightDiv = 0 := by
  simp [nodeParam]

/-- Spacetime is the ONLY mirrored named logic. -/
theorem only_spacetime_is_mirrored (L : LogicTypes.LogicType)
    (h : (nodeParam L).mirror = true) : L = .Spacetime := by
  cases L <;> simp [nodeParam] at h ⊢

/-- The bias is invariant across all named logics: one atom per commit,
    whatever the logic. -/
theorem bias_invariant (L : LogicTypes.LogicType) : (nodeParam L).bias = 1 :=
  nodeParam_bias_one L

/-- The denom is 10 everywhere except the Paraconsistent/Temporal pair (8). -/
theorem denom_invariant_except_paraconsistent (L : LogicTypes.LogicType) :
    (nodeParam L).denom = 10 ∨ (nodeParam L).denom = 8 := by
  cases L <;> simp [nodeParam]

-- ============================================================================
-- Carrier morphism: NodeCost ↪ SplitOctonion (note 007, rescued)
-- ============================================================================

/-- The carrier morphism `toSO` (note 007, from `SplitOctonionCost.lean`,
    deleted `a8e3c57`): the 8 cost parameters become the 8 algebra
    components — bias ↦ e₀, leftWeight ↦ e₁, rightDiv ↦ e₂, denom ↦ e₃,
    satCap ↦ e₄, coupling ↦ e₅, mirror ↦ e₆, maxSem ↦ e₇ (fields cast to ℤ;
    booleans as 0/1). The component assignment order follows the archived
    file, which differs from note 007's table in e₄/e₅ — the algebraic
    claim (injective embedding of cost geometry) is order-independent. -/
def toSO (c : NodeCost) : SplitOctonion :=
  { e0 := c.bias,
    e1 := c.leftWeight,
    e2 := c.rightDiv,
    e3 := c.denom,
    e4 := c.satCap,
    e5 := c.coupling,
    e6 := if c.mirror then 1 else 0,
    e7 := if c.maxSem then 1 else 0 }

/-- A 0/1 ℤ-embedding of `Bool` is injective (used for the mirror/maxSem
    components of the carrier morphism). -/
theorem bool_if_inj {b₁ b₂ : Bool}
    (h : (if b₁ then (1 : ℤ) else 0) = if b₂ then 1 else 0) : b₁ = b₂ := by
  cases b₁ <;> cases b₂ <;> simp_all (config := {decide := true})

/-- `toSO` is injective: cost geometry embeds faithfully in the algebra,
    so the corrected **8** distinct table rows are 8 distinct split-octonion
    points (this is what makes the 006/007 erratum a theorem, not prose). -/
theorem toSO_injective (c₁ c₂ : NodeCost) (h : toSO c₁ = toSO c₂) : c₁ = c₂ := by
  cases c₁ with
  | mk lw1 rd1 b1 m1 co1 d1 ms1 sc1 =>
    cases c₂ with
    | mk lw2 rd2 b2 m2 co2 d2 ms2 sc2 =>
      have hb : b1 = b2 := by
        simpa [toSO, Int.natCast_inj] using congr_arg SplitOctonion.e0 h
      have hlw : lw1 = lw2 := by
        simpa [toSO, Int.natCast_inj] using congr_arg SplitOctonion.e1 h
      have hrd : rd1 = rd2 := by
        simpa [toSO, Int.natCast_inj] using congr_arg SplitOctonion.e2 h
      have hd : d1 = d2 := by
        simpa [toSO, Int.natCast_inj] using congr_arg SplitOctonion.e3 h
      have hsc : sc1 = sc2 := by
        simpa [toSO, Int.natCast_inj] using congr_arg SplitOctonion.e4 h
      have hco : co1 = co2 := by
        simpa [toSO, Int.natCast_inj] using congr_arg SplitOctonion.e5 h
      have hm : m1 = m2 :=
        bool_if_inj (by simpa [toSO] using congr_arg SplitOctonion.e6 h)
      have hms : ms1 = ms2 :=
        bool_if_inj (by simpa [toSO] using congr_arg SplitOctonion.e7 h)
      simp [NodeCost.mk.injEq, hb, hlw, hrd, hd, hco, hsc, hm, hms]

end Cost
