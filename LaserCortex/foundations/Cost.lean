/-
# Module: Cost (anonymous cost geometry — foundations layer)

## Intent

The geometry of recursive cost on EML trees, WITHOUT any named logics:
the `NodeCost` parameter structure, its application semantics (amplify /
compress / couple / mirror / max / saturate), the generic cost functional
`Φ_of_nc`, the parameter-condition theorems (raw-size, height, left-spine,
saturation, contraction-invariance), and the carrier morphism
`toSO : NodeCost → SplitOctonion` with its injectivity.

Layering (owner ruling, 2026-09-02): the 15 named logics and the
`nodeParam` table are an INTERPRETATION layer, not foundations — the
Hopf 7-Skeleton (note 006) was originally meant to be an ANONYMOUS
derivation of realizable cost geometries from pentagonator constraints,
and the logic names were a reading aid for a hard-to-interpret result.
Names can be renamed, re-derived, or replaced by a characterization
theorem without touching this file. The named layer lives at
`LaserCortex/LogicTable.lean` (research layer) and reuses the qualified
namespace `Cost` so the historical doc citations
(`Cost.nodeParam_bias_one`, …) keep resolving.

Provenance: rescued per archaeology triage 062 §5.7(a) from `Cost.lean`
(deleted `a8e3c57`, 2026-07-06), `SplitOctonionLogic.lean` (deleted
`e212301`, 2026-07-07) and `SplitOctonionCost.lean`'s carrier (deleted
`a8e3c57`); the Python mirror `infra/_cortex/_cost.py` never died — the
restoration corrected it, see `LogicTable.lean`.

Correction carried: `apply` divides by `rightDiv + 1`, so rows differing
only there are distinct geometries — the archived "7 distinct points"
count omitted the raw-size row (`rightDiv = 0, leftWeight = 1`); the true
collapse of the archived table is **8** (proved in `LogicTable`).

## Contracts

[NodeCost, NodeCost.applyUncapped, NodeCost.apply,
NodeCost.applyUncapped_not_mirror, NodeCost.applyUncapped_mirror,
NodeCost.applyUncapped_maxSem, NodeCost.apply_not_mirror,
NodeCost.apply_mirror, NodeCost.apply_maxSem, NodeCost.apply_le_satCap,
Φ_of_nc, Φ_of_nc_Leaf, Φ_of_nc_Node,
Φ_of_nc_eq_size, Φ_of_nc_contracts_one_eq, Φ_of_nc_contracts_to_eq,
Φ_of_nc_mirror_left_spine, Φ_of_nc_maxSem_eq_height, Φ_of_nc_le_satCap,
toSO, bool_if_inj, toSO_injective
(nodeParam, the LogicType enum, Φ under named logics, the collapse count
and all named-logic statements live in `LaserCortex/LogicTable.lean`.)]

## Cross-refs

`LaserCortex.foundations.Tamari` (carrier + contraction),
`LaserCortex.foundations.Algebra` (SplitOctonion),
`LaserCortex.LogicTable` (the named interpretation), notes 006/007
(006 erratum 2026-09-02), 062 §5.7(a)

## Invariants

Parameter-condition theorems, not name-condition: a NodeCost with
rightDiv = 0, coupling = 0, ¬mirror, leftWeight = 1, bias = 1,
¬maxSem, satCap = 0 measures raw tree SIZE and is contraction-invariant;
maxSem = true (bias 1, no cap) measures HEIGHT; mirror with leftWeight =
rightDiv = coupling = 0 sees only the LEFT spine; satCap > 0 caps cost at
satCap; toSO embeds the 8-parameter space into the split-octonions
injectively (bias ↦ e₀ — the 0/1-Bool components e₆/e₇ via bool_if_inj).

## Tags

#lean4-theorem #invariant #proof-bound #rescued
-/

import LaserCortex.foundations.Algebra
import LaserCortex.foundations.Tamari

namespace Cost

/-- Node cost parameters for a logic type.
    Interprets the EML operator eml(x, y) = exp(x) - ln(y) in discrete ℕ
    arithmetic: leftWeight amplifies the left subtree cost (exp-like),
    rightDiv compresses the right subtree cost (ln-like), bias adds the
    distinguished constant 1 from the EML grammar.

    When mirror = true the left/right roles swap: leftWeight amplifies the
    right subtree (associator/space-dominant), rightDiv compresses the left
    subtree (commutator/time-suppressed). coupling·a·b/max(1,denom) is a
    symmetric cross-sector (non-distributivity) penalty.

    Depth-2 extensions: maxSem = true gives proof-depth semantics
    max(a, b) + bias; satCap > 0 caps the result (saturation);
    satCap = 0 means no cap. -/
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
      mirror = true swaps the a ↔ b roles.
    Depth-2: maxSem gives max(a, b) + bias; satCap > 0 caps at satCap. -/
def NodeCost.apply (c : NodeCost) (a b : Nat) : Nat :=
  let uncapped := c.applyUncapped a b
  if c.satCap = 0 then uncapped else min c.satCap uncapped

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
-- Φ_of_nc: the generic recursive cost functional on Tamari trees
-- ============================================================================

/-- Cross-impact cost of an EML tree under an arbitrary point of the
    parameter space. The named-logic functional is a special case
    (`LogicTable.Φ`); the theorems below are all stated for conditions on
    the parameters, never for a name. -/
def Φ_of_nc (nc : NodeCost) : EMLTree → Nat
  | .Leaf => 0
  | .Node l r => nc.apply (Φ_of_nc nc l) (Φ_of_nc nc r)

theorem Φ_of_nc_Leaf (nc : NodeCost) : Φ_of_nc nc .Leaf = 0 := rfl

theorem Φ_of_nc_Node (nc : NodeCost) (l r : EMLTree) :
    Φ_of_nc nc (.Node l r) = nc.apply (Φ_of_nc nc l) (Φ_of_nc nc r) := rfl

-- ============================================================================
-- Raw-size geometry: contraction-invariant, Φ = node count
-- ============================================================================

/-- A NodeCost with rightDiv = 0 (no compression), coupling = 0 (no
    cross-sector penalty), mirror = false, leftWeight = 1 (no
    amplification), bias = 1, maxSem = false, satCap = 0 measures exactly
    the node count of the tree: the geometry of RAW SIZE — no distortion
    channel open. (The archived table's Free/Boolean row is a named
    instance of this; the theorem itself is anonymous.) -/
theorem Φ_of_nc_eq_size (nc : NodeCost) (t : EMLTree)
    (hD : nc.rightDiv = 0) (hC : nc.coupling = 0) (hM : ¬nc.mirror)
    (hW : nc.leftWeight = 1) (hB : nc.bias = 1) (hMS : ¬nc.maxSem)
    (hSC : nc.satCap = 0) : Φ_of_nc nc t = t.size := by
  induction t with
  | Leaf => simp [Φ_of_nc, EMLTree.size]
  | Node l r ih_l ih_r =>
    rw [Φ_of_nc_Node, NodeCost.apply_not_mirror _ _ _ hMS hM hSC]
    simp only [hC, Nat.zero_mul, Nat.add_zero, Nat.zero_div]
    rw [hW, hB, hD, ih_l, ih_r, EMLTree.size]
    simp [Nat.one_mul, Nat.succ_eq_add_one]

/-- Raw-size geometries are invariant under a single Tamari rotation. -/
theorem Φ_of_nc_contracts_one_eq (nc : NodeCost) {s t : EMLTree}
    (hD : nc.rightDiv = 0) (hC : nc.coupling = 0) (hM : ¬nc.mirror)
    (hW : nc.leftWeight = 1) (hB : nc.bias = 1) (hMS : ¬nc.maxSem)
    (hSC : nc.satCap = 0) (h : contracts_one s t) :
    Φ_of_nc nc s = Φ_of_nc nc t := by
  have hΦs : Φ_of_nc nc s = s.size := Φ_of_nc_eq_size nc s hD hC hM hW hB hMS hSC
  have hΦt : Φ_of_nc nc t = t.size := Φ_of_nc_eq_size nc t hD hC hM hW hB hMS hSC
  rw [hΦs, hΦt, contracts_one_size_eq h]

/-- …and under arbitrary contraction paths. -/
theorem Φ_of_nc_contracts_to_eq (nc : NodeCost) {s t : EMLTree}
    (hD : nc.rightDiv = 0) (hC : nc.coupling = 0) (hM : ¬nc.mirror)
    (hW : nc.leftWeight = 1) (hB : nc.bias = 1) (hMS : ¬nc.maxSem)
    (hSC : nc.satCap = 0) (h : contracts_to s t) :
    Φ_of_nc nc s = Φ_of_nc nc t := by
  have hΦs : Φ_of_nc nc s = s.size := Φ_of_nc_eq_size nc s hD hC hM hW hB hMS hSC
  have hΦt : Φ_of_nc nc t = t.size := Φ_of_nc_eq_size nc t hD hC hM hW hB hMS hSC
  rw [hΦs, hΦt, contracts_to_size_eq h]

-- ============================================================================
-- Other parameter-condition regimes
-- ============================================================================

/-- The mirrored silent geometry (mirror = true, leftWeight = rightDiv =
    coupling = 0, bias = 1) sees only the left spine: the right subtree is
    invisible to the cost. -/
theorem Φ_of_nc_mirror_left_spine (nc : NodeCost) (l r : EMLTree)
    (hMS : ¬nc.maxSem) (hMi : nc.mirror = true) (hSC : nc.satCap = 0)
    (hB : nc.bias = 1) (hW : nc.leftWeight = 0) (hD : nc.rightDiv = 0)
    (hC : nc.coupling = 0) :
    Φ_of_nc nc (.Node l r) = 1 + Φ_of_nc nc l := by
  rw [Φ_of_nc_Node, NodeCost.apply_mirror _ _ _ hMS hMi hSC, hB, hW, hD, hC]
  simp only [Nat.mul_zero, Nat.zero_mul, Nat.add_zero, Nat.div_one,
    Nat.zero_div]

/-- maxSem with bias 1 and no cap measures proof DEPTH (tree height),
    not proof size. -/
theorem Φ_of_nc_maxSem_eq_height (nc : NodeCost) (t : EMLTree)
    (hMS : nc.maxSem = true) (hB : nc.bias = 1) (hSC : nc.satCap = 0) :
    Φ_of_nc nc t = t.height := by
  induction t with
  | Leaf => simp [Φ_of_nc, EMLTree.height]
  | Node l r ih_l ih_r =>
    rw [Φ_of_nc_Node, NodeCost.apply_maxSem _ _ _ hMS hSC, hB, ih_l, ih_r]
    simp [EMLTree.height]
    omega

/-- Any satCap > 0 puts a hard ceiling on the cost functional. -/
theorem Φ_of_nc_le_satCap (nc : NodeCost) (t : EMLTree)
    (h : nc.satCap > 0) : Φ_of_nc nc t ≤ nc.satCap := by
  induction t with
  | Leaf => exact Nat.zero_le _
  | Node l r ih_l ih_r =>
    rw [Φ_of_nc_Node]
    exact NodeCost.apply_le_satCap nc _ _ h

-- ============================================================================
-- Carrier morphism: NodeCost ↪ SplitOctonion (note 007, rescued)
-- ============================================================================

/-- The carrier morphism `toSO` (note 007, from `SplitOctonionCost.lean`,
    deleted `a8e3c57`): the 8 cost parameters become the 8 algebra
    components — bias ↦ e₀, leftWeight ↦ e₁, rightDiv ↦ e₂, denom ↦ e₃,
    satCap ↦ e₄, coupling ↦ e₅, mirror ↦ e₆, maxSem ↦ e₇ (fields cast to ℤ;
    booleans as 0/1). The component assignment order follows the archived
    file, which differs from note 007's table in e₄/e₅ — the algebraic
    claim (injective embedding of cost geometry) is order-independent.

    Anonymous by construction: this embeds the PARAMETER SPACE, not a
    named-logic list; which points of it are realized is the interpretation
    layer's question (`LogicTable`), and which points are FORCED by the
    pentagonator constraints is the open derivation (research_questions). -/
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

/-- `toSO` is injective: cost geometry embeds faithfully in the algebra.
    Distinct parameter points (hence the 8 table geometries of `LogicTable`,
    whatever they are eventually named or derived to be) are distinct
    split-octonion points. -/
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
