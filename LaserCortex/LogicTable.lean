/-
# Module: LogicTable (named interpretation layer)

## Intent

The `nodeParam` table: 15 named logics read as points of the anonymous
cost geometry of `LaserCortex.foundations.Cost`, plus the named corollaries
the literature cites (`Cost.nodeParam_bias_one`, `Cost.bias_invariant`,
`Cost.distinctNodeCost_enumeration`, the Φ-family under names) and the
CORRECTED collapse: the table's image has **8** distinct cost geometries,
not the archived 7 (the omitted row is Free/Boolean, `rightDiv = 0` — the
raw-size geometry; see note 006 erratum 2026-09-02).

Layering (owner ruling 2026-09-02): names live in the research layer. The
7-Skeleton was meant to be an anonymous derivation of realizable geometries
from pentagonator constraints; the names are a legacy reading. If the table
is ever superseded by a characterization theorem ("the geometries are
exactly the solutions of constraint set X"), this file is what changes —
`foundations/Cost.lean` does not.

Keeps namespace `Cost` (as `foundations/Cost.lean` does) so every historical
citation `Cost.<name>` continues to resolve.

Provenance: `Cost.lean` table section (deleted `a8e3c57`, 2026-07-06) and
`SplitOctonionLogic.lean` collapse section (deleted `e212301`, 2026-07-07);
Python mirror `infra/_cortex/_cost.py::node_param` (verify agreement — see
062 §5.7(a) rescue note).

## Contracts

[nodeParam, nodeParam_bias_one,
nodeParam_leftWeight_ge_one_of_not_mirror, nodeParam_mirror_iff_spacetime,
nodeParam_spacetime, nodeParam_intuitionistic, nodeParam_fuzzy, Φ, Φ_Leaf,
Φ_Node, Φ_eq_Φ_of_nc, Φ_eq_size_classical, Φ_contracts_one_eq_classical,
Φ_contracts_to_eq_classical, Φ_spacetime_node, Φ_intuitionistic_eq_height,
Φ_fuzzy_le_satCap, distinctNodeCosts, allLogics, nodeParam_collapse,
distinctNodeCost_enumeration, only_spacetime_is_mirrored, bias_invariant,
denom_invariant_except_paraconsistent, eight_points_distinct]

## Cross-refs

`LaserCortex.LogicTypes` (the enum), `LaserCortex.foundations.Cost`
(geometry + carrier), notes 006/007 (erratum 2026-09-02), 062 §5.7(a),
`research_questions.md` (anonymous-derivation programme)

## Invariants

The table rows satisfy the anonymous regime theorems: Free/Boolean =
raw-size geometry (Φ = node count, contraction-invariant); Spacetime =
mirrored left-spine; Intuitionistic = height; Fuzzy = saturated;
Paraconsistent/Temporal and Quantum = coupled cross-sector (denom 8/10);
Deontic/Epistemic = half-compressed right spine; Classical group =
rightDiv-1 null geometry. Every row pays bias 1 (amplitude-free commit,
061 §2). Image cardinality: 15 logics → 8 geometries → 8 split-octonion
points (`eight_points_distinct`).

## Tags

#lean4-theorem #invariant #proof-bound #rescued #interpretation-layer
-/

import LaserCortex.LogicTypes
import LaserCortex.foundations.Cost

namespace Cost

open LogicTypes

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
-- Φ under a named logic: the generic functional at a table row
-- ============================================================================

/-- Cross-impact cost of an EML tree under a named logic: `Φ_of_nc`
    evaluated at the logic's table row. -/
def Φ (L : LogicTypes.LogicType) : EMLTree → Nat := Φ_of_nc (nodeParam L)

theorem Φ_Leaf (L : LogicTypes.LogicType) : Φ L .Leaf = 0 := rfl

theorem Φ_Node (L : LogicTypes.LogicType) (l r : EMLTree) :
    Φ L (.Node l r) = (nodeParam L).apply (Φ L l) (Φ L r) := rfl

/-- The named and anonymous functionals agree. -/
theorem Φ_eq_Φ_of_nc (L : LogicTypes.LogicType) (t : EMLTree) :
    Φ L t = Φ_of_nc (nodeParam L) t := rfl

-- ============================================================================
-- Named instances of the anonymous regime theorems
-- ============================================================================

/-- Historical name retained (`classical` in the archived sense "no
    distortion channel"): any named logic whose row satisfies rightDiv = 0,
    coupling = 0, ¬mirror, leftWeight = 1, ¬maxSem, satCap = 0 measures raw
    tree size. In the table this is precisely the Free/Boolean row — NOT
    Classical itself (rightDiv = 1). See 006 erratum. -/
theorem Φ_eq_size_classical (L : LogicTypes.LogicType) (t : EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    Φ L t = t.size :=
  Φ_of_nc_eq_size (nodeParam L) t hD hC hM hW (nodeParam_bias_one L) hMS hSC

/-- Cost is preserved by a single Tamari rotation for raw-size logics. -/
theorem Φ_contracts_one_eq_classical (L : LogicTypes.LogicType) {s t : EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0)
    (h : contracts_one s t) : Φ L s = Φ L t :=
  Φ_of_nc_contracts_one_eq (nodeParam L) hD hC hM hW (nodeParam_bias_one L)
    hMS hSC h

/-- Cost is preserved by multi-step contraction paths. -/
theorem Φ_contracts_to_eq_classical (L : LogicTypes.LogicType) {s t : EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0)
    (h : contracts_to s t) : Φ L s = Φ L t :=
  Φ_of_nc_contracts_to_eq (nodeParam L) hD hC hM hW (nodeParam_bias_one L)
    hMS hSC h

/-- Spacetime cost at any node is 1 + cost of the LEFT child: mirrored
    semantics see only the time axis (the right spine is invisible). -/
theorem Φ_spacetime_node (l r : EMLTree) :
    Φ .Spacetime (.Node l r) = 1 + Φ .Spacetime l :=
  Φ_of_nc_mirror_left_spine (nodeParam .Spacetime) l r (by decide) (by decide)
    (by decide) (by decide) (by decide) (by decide) (by decide)

/-- Intuitionistic Φ equals tree height: proof cost is DEPTH, not size. -/
theorem Φ_intuitionistic_eq_height (t : EMLTree) :
    Φ .Intuitionistic t = t.height :=
  Φ_of_nc_maxSem_eq_height (nodeParam .Intuitionistic) t (by decide)
    (by decide) (by decide)

/-- Fuzzy Φ is bounded by the saturation cap: truth saturates at 1, and in
    ℕ-arithmetic that is a hard ceiling at satCap. -/
theorem Φ_fuzzy_le_satCap (t : EMLTree) :
    Φ .Fuzzy t ≤ (nodeParam .Fuzzy).satCap :=
  Φ_of_nc_le_satCap (nodeParam .Fuzzy) t (by decide)

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
    group, and `apply` divides by rightDiv + 1, so the rows differ already
    on trees whose right subtree costs 1). Note 006's "7-skeleton" pun
    survives as prose about the feature axes, but the cost-geometry count
    is 8. -/
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

/-- The 8 table geometries land on 8 DISTINCT split-octonion points
    (007's carrier reading, corrected to the true count): the cost skeleton
    is faithfully represented in the algebra, so no two named groups are
    identified by the embedding.

    Axiom note: the statement is a closed finite computation; the `decide`
    machinery through the `equivVec`-backed equality instances pulls in
    Lean's standard three foundations (propext, Classical.choice,
    Quot.sound) — no `sorry`, no `native_decide` oracle axiom. -/
theorem eight_points_distinct :
    ((distinctNodeCosts.map toSO).eraseDups).length = 8 := by
  unfold distinctNodeCosts nodeParam
  decide

end Cost
