# TDD: SplitOctonionLogic — The 8D Parameter Space as Logic-Semantic Coordinate System

## Motivation

The split-octonion algebra is not an implementation detail. It **is** the bridge
between generation and hyperstition: the 8-dimensional `NodeCost` parameter space
+ `EngineState` dynamical system provide the language for describing how logic-like
semantic features emerge from the algebra's geometry. The named `LogicType` variants
are test cases — specific points in this 8D space whose known behavior constrains
any theory of `SplitOctonionLogic`.

This document states the hypotheses to test as Lean theorems. Each "test" is a
`theorem` or `example` that we write first, then prove or find a counterexample.
Counterexamples are equally valuable: they reveal the actual structure.

---

## Domain 0: Foundations — The 8D Parameter Space is Not Flat

*Hypothesis: The 15 named logics collapse to far fewer distinct NodeCost configurations,
revealing that cdStep and LogicClass carry semantic information NOT captured by
NodeCost alone.*

```lean4
-- 0.1 Identity/collapse detection: which named logics share NodeCost?
theorem classical_eq_manyValued : nodeParam .Classical = nodeParam .ManyValued := by rfl
theorem classical_eq_relevance : nodeParam .Classical = nodeParam .Relevance := by rfl
theorem classical_eq_infinitary : nodeParam .Classical = nodeParam .Infinitary := by rfl
theorem classical_eq_modal : nodeParam .Classical = nodeParam .Modal := by rfl
theorem paraconsistent_eq_temporal : nodeParam .Paraconsistent = nodeParam .Temporal := by rfl
theorem deontic_eq_epistemic : nodeParam .Deontic = nodeParam .Epistemic := by rfl
theorem intuitionistic_eq_free_no_maxSem :
    (nodeParam .Intuitionistic).leftWeight = (nodeParam .Free).leftWeight ∧
    (nodeParam .Intuitionistic).rightDiv = (nodeParam .Free).rightDiv := by decide

-- 0.2 But these clashing logics have DIFFERENT cdStep → different layerCost
theorem same_NodeCost_different_layerCost :
    nodeParam .Classical = nodeParam .ManyValued ∧
    layerCost .Classical ≠ layerCost .ManyValued := by
  refine ⟨rfl, ?_⟩
  dsimp [layerCost, frictionDensity, commDefect, assocDefect]
  decide   -- Classical: Γ₀ = 0, ManyValued: Γ₁ = 1

-- 0.3 Exhaustive map: enumerate all distinct NodeCost configurations among named logics
-- Expected result: ~7 distinct points among 15 named logics
theorem distinct_NodeCost_count :
    Finset.card (Finset.image nodeParam (Finset.univ : Finset LogicType)) ≥ 5 := by
  -- At minimum: Classical-group, Fuzzy, Paraconsistent-group, Quantum, Intuitionistic,
  -- Spacetime, Boolean/Free-group = 7 distinct. Prove ≥ 5.
  native_decide

-- 0.4 Spacetime is the ONLY mirrored logic
theorem only_spacetime_is_mirrored (lt : LogicType) (h : (nodeParam lt).mirror = true) :
    lt = .Spacetime := by
  cases lt <;> simp [nodeParam] at h ⊢
```

**Research question this probes:**
What IS the relationship between cdStep and NodeCost? If they are independent axes,
then "logic type" lives in a 9D space (8D NodeCost + 1D cdStep). If they are
correlated, the effective dimension is lower.

---

## Domain 1: The Classical Region — Full Associativity

*Hypothesis: Classical NodeCost makes Φ = tree.size for all trees, and Φ is
invariant under all Tamari contractions.*

```lean4
-- 1.1 Φ = size under classical parameters (already proven)
theorem classical_Φ_eq_size (t : EMLTree) : Φ .Classical t = t.size :=
  Φ_eq_size_classical t

-- 1.2 Characterization: exactly which NodeCost parameters make Φ = size for all trees?
theorem Φ_eq_size_iff (nc : Cost.NodeCost) :
    (∀ t : EMLTree, Φ_of_nc nc t = t.size) ↔
    (nc.rightDiv = 0 ∧ nc.coupling = 0 ∧ nc.mirror = false ∧ nc.leftWeight = 1
     ∧ nc.maxSem = false ∧ nc.satCap = 0) := by
  constructor
  · intro h
    -- Need to find witness trees that break each condition
    -- e.g., if leftWeight ≠ 1, the tree Node(Leaf, Leaf) has wrong cost
    have hleaf : Φ_of_nc nc .Leaf = 0 := by simpa using h .Leaf
    have hnode : Φ_of_nc nc (.Node .Leaf .Leaf) = 2 := by simpa using h (.Node .Leaf .Leaf)
    ...
  · intro ⟨hrd, hcpl, hm, hlw, hms, hsc⟩
    -- This is the existing proof generalized from Φ_eq_size_classical
    ...

-- 1.3 Φ respects contracts_one in the classical region (already proven)
theorem classical_Φ_respects_contracts_one (t u : EMLTree) (h : contracts_one t u) :
    Φ .Classical t = Φ .Classical u :=
  Φ_contracts_one_eq_classical t u h

-- 1.4 Φ IS NOT invariant under contracts_one outside the classical region
-- Key negative test: if rightDiv > 0, Φ CAN change under contraction
example : ∃ (t u : EMLTree) (nc : Cost.NodeCost), contracts_one t u ∧
    ¬ nc.rightDiv = 0 ∧ Φ_of_nc nc t ≠ Φ_of_nc nc u := by
  -- Use Fuzzy-like parameters (rightDiv=2) on a contraction pair
  refine ⟨?_, ?_, {rightDiv := 2, bias := 1, leftWeight := 1, mirror := false,
                    coupling := 0, denom := 10, maxSem := false, satCap := 0}, ?_, ?_⟩
  -- Find t, u such that contracts_one t u but Φ differs
  ...

-- 1.5 The classical region is CONVEX: any NodeCost on the line between two
-- classical-region points is also classical-region.
theorem classical_region_convex (nc₁ nc₂ : Cost.NodeCost)
    (h₁ : ∀ t, Φ_of_nc nc₁ t = t.size) (h₂ : ∀ t, Φ_of_nc nc₂ t = t.size) :
    ∀ (α : ℚ), 0 ≤ α → α ≤ 1 → (∀ t, Φ_of_nc (interpolate α nc₁ nc₂) t = t.size) := ...
-- If true: classical region is a convex subset of the 8D space.
-- If false: the boundary is non-convex (interesting!).
```

**Key insight:**
The classical region is exactly the region where Φ is a homomorphism from the
Tamari lattice to ℕ. Outside this region, contraction paths have non-uniform cost,
creating the gradient for collapse decisions — the mechanism of hyperstition.

---

## Domain 2: The Associativity Sector Split (cdStep 2→3)

*Hypothesis: The cdStep 2→3 boundary is the sharp phase transition where
rightDiv goes from 0 to nonzero, and this is detectable in Φ values.*

```lean4
-- 2.1 Associative-sector logics (cdStep ≤ 2) are NOT all in the classical Φ=size region
-- Fuzzy has rightDiv=2, so Φ ≠ size even though cdStep=1 (associative!)
theorem fuzzy_not_in_classical_region : ∃ t : EMLTree, Φ .Fuzzy t ≠ t.size := by
  refine ⟨.Node .Leaf .Leaf, ?_⟩
  native_decide

-- 2.1b But Intuitionistic (cdStep=2, rightDiv=0) IS in the classical Φ=size region?
-- Actually Intuitionistic has maxSem=true, so Φ = height, not size.
-- The cdStep boundary is NOT the same as the Φ=size boundary.
theorem intuitionistic_not_in_classical_region : ∃ t : EMLTree, Φ .Intuitionistic t ≠ t.size := by
  refine ⟨.Node .Leaf (.Node .Leaf .Leaf), ?_⟩
  native_decide

-- 2.2 All cdStep ≥ 3 named logics have coupling > 0 (cross-term activation)
-- EXCEPT Modal and Infinitary (coupling=0) — FINDING: third regime?
theorem nonassoc_sector_coupling_pattern :
    (∀ lt : LogicType, lt.cdStep ≥ 3 → (nodeParam lt).coupling ≥ 1) := by
  intro lt h
  cases lt <;> simp [nodeParam, LogicType.cdStep] at h ⊢ <;> try omega
  -- Modal (.coupling = 0) and Infinitary (.coupling = 0) will FAIL here
  -- This reveals they are in a distinct subclass

-- 2.3 The cdStep 2→3 boundary IS detectable via Φ on a witness tree
theorem cd23_phaseChange_witness : ∃ (t : EMLTree), Φ .Classical t = t.size ∧
    Φ .Quantum t ≠ t.size := by
  refine ⟨.Node (.Node .Leaf .Leaf) (.Node .Leaf .Leaf), ?_⟩
  constructor
  · exact Φ_eq_size_classical _
  · native_decide

-- 2.4 The friction barrier (strut_weight² = 16) is provably the minimum jump
-- across the cdStep 2→3 boundary (already proven)
theorem friction_barrier_cd23 (k₁ k₂ : ℕ) (h₁ : k₁ ≤ 2) (h₂ : 3 ≤ k₂) :
    frictionDensity k₂ - frictionDensity k₁ ≥ strut_weight * strut_weight :=
  friction_barrier_across_cd23 k₁ k₂ h₁ h₂

-- 2.5 There is NO NodeCost that simultaneously has Φ = size for all trees
-- AND has cdStep ≥ 3 (i.e., non-associativity always changes the cost landscape)
theorem no_classical_nonassociative : ¬∃ (lt : LogicType), lt.cdStep ≥ 3 ∧
    (∀ t : EMLTree, Φ lt t = t.size) := by
  intro h
  rcases h with ⟨lt, hcd, hΦ⟩
  have : Φ lt (.Node (.Node .Leaf .Leaf) (.Node .Leaf .Leaf)) = 4 := by
    simpa using hΦ (.Node (.Node .Leaf .Leaf) (.Node .Leaf .Leaf))
  -- But with cdStep ≥ 3, coupling > 0 for most logics, so Φ > size
  ...
```

**Finding to verify:**
Modal and Infinitary have cdStep=3 but coupling=0. This would mean they are
"non-associative but non-interacting" — a third regime distinct from both
associative (Classical) and non-associative-interacting (Quantum). This would
be a genuine discovery about the algebra.

---

## Domain 3: EngineState → NodeCost Flow

*Hypothesis: The engine_to_nodecost projection defines a dynamical system on
the 8D space. Its fixed points are the named logics (or a subset thereof).*

```lean4
-- 3.1 Zero debt → Classical parameters (already proven)
theorem engine_zero_debt_classical : engine_to_nodecost {
    current_weight := 0, local_debt := 0, capacity := 10 }
    = { leftWeight := 1, rightDiv := 0, bias := 1, mirror := false, coupling := 0,
        denom := 10, maxSem := false, satCap := 0 } :=
  engine_zero_debt_classical

-- 3.2 Positive debt → mirror=true (already proven)
theorem engine_pos_debt_mirror (debt cap : Nat) (h : debt > 0) :
    (engine_to_nodecost { current_weight := 0, local_debt := debt, capacity := cap }).mirror = true :=
  engine_pos_debt_mirror debt cap h

-- 3.3 Engine is NOT injective: multiple engine states produce same NodeCost
theorem engine_to_nodecost_not_injective :
    ∃ (e1 e2 : EngineState), e1 ≠ e2 ∧ engine_to_nodecost e1 = engine_to_nodecost e2 := by
  -- debt=1, cap=5 → rightDiv = max(0, 5/2 - 1) = 1
  -- debt=2, cap=8 → rightDiv = max(0, 8/3 - 1) = 1
  refine ⟨{local_debt:=1, capacity:=5, current_weight:=0},
          {local_debt:=2, capacity:=8, current_weight:=0}, ?_, ?_⟩
  · decide
  · unfold engine_to_nodecost; decide

-- 3.4 The engine flow has EXACTLY two attractor basins: debt=0 and debt>0
-- BUT debt>0 is a family parameterized by capacity/(debt+1)
theorem engine_positive_debt_rightDiv_formula (d cap : Nat) (hd : d > 0) :
    (engine_to_nodecost {current_weight:=0, local_debt:=d, capacity:=cap}).rightDiv =
    max 0 (cap / (d + 1) - 1) := by
  unfold engine_to_nodecost; simp [hd]

-- 3.5 The rightDiv of the engine output is monotone decreasing in debt
-- (more debt → more compression → smaller rightDiv → approaching Spacetime's rightDiv=0)
theorem engine_rightDiv_antitone (d₁ d₂ cap : Nat) (hd : d₁ ≤ d₂) (hcap : cap > 0) :
    (engine_to_nodecost {current_weight:=0, local_debt:=d₂, capacity:=cap}).rightDiv ≤
    (engine_to_nodecost {current_weight:=0, local_debt:=d₁, capacity:=cap}).rightDiv := by
  unfold engine_to_nodecost
  by_cases hd₁ : d₁ > 0
  · simp [hd₁]
    have hd₂ : d₂ > 0 := by omega
    simp [hd₂]
    -- Compare cap/(d₂+1) - 1 ≤ cap/(d₁+1) - 1
    -- Since d₂ ≥ d₁, cap/(d₂+1) ≤ cap/(d₁+1)
    have hdiv : cap / (d₂ + 1) ≤ cap / (d₁ + 1) :=
      Nat.div_le_div_right (by omega)
    omega
  · -- d₁ = 0 (associative sector, rightDiv=0)
    -- d₂ could be anything
    simp [hd₁]
    ...

-- 3.6 The engine flow CONVERGES: as debt → ∞, rightDiv → 0, leftWeight → 0,
-- mirror → true → NodeCost approaches Spacetime
theorem engine_limit_is_spacetime (cap : Nat) :
    Filter.Tendsto (λ d : ℕ => (engine_to_nodecost {current_weight:=0, local_debt:=d, capacity:=cap}).rightDiv)
    Filter.atTop (𝓝 0) := by
  -- For all d ≥ cap, rightDiv = 0
  intro d hd
  have : cap / (d + 1) = 0 := Nat.div_eq_of_lt (by omega)
  ...
```

**Key insight:**
The engine flow is 2-basin (associative vs non-associative), but the
non-associative basin has internal structure indexed by capacity/(debt+1).
This is a continuous parameter — meaning there are infinitely many "logic types"
in the non-associative sector, not just the 4 named ones.

---

## Domain 4: Mirror Symmetry — The Space/Time Duality

*Hypothesis: Mirror flips the left/right roles in Φ. Spacetime (mirror=true,
leftWeight=0) produces a pure "left spine" cost — space-dominant, time-suppressed.*

```lean4
-- 4.1 Mirror equivalence: apply with mirror=true is apply with mirror=false but a↔b
theorem mirror_flip_equivalence (nc : Cost.NodeCost) (a b : Nat) (hm : nc.mirror = false) :
    ({nc with mirror := true}.apply a b) = nc.apply b a := by
  dsimp [Cost.NodeCost.apply, Cost.NodeCost.applyUncapped]
  simp [hm]

-- 4.2 Spacetime Φ = left spine length (not just size)
theorem spacetime_Φ_leftSpine (t : EMLTree) : Φ .Spacetime t = t.leftSpineLength := by
  induction t with
  | Leaf => rfl
  | Node l r ih_l ih_r =>
    dsimp [Φ, Cost.NodeCost.apply, Cost.NodeCost.applyUncapped, nodeParam]
    -- Note: nodeParam .Spacetime has mirror=true, leftWeight=0, rightDiv=0
    -- So apply a b = bias + (a / 1) + 0 * b + 0 = 1 + a
    -- Which means Φ(Node l r) = 1 + Φ(Spacetime, l)
    simp
    -- Need to define leftSpineLength on EMLTree
    ...

-- 4.3 Classical is mirror-invariant (Φ unchanged when mirror toggled)
theorem classical_mirror_invariant (t : EMLTree) :
    Φ .Classical t = Φ_of_nc ({nodeParam .Classical with mirror := true}) t :=
  Φ_eq_size_classical t  -- both equal t.size, so yes

-- 4.4 Fuzzy is NOT mirror-invariant (rightDiv > 0 creates asymmetry)
theorem fuzzy_mirror_not_invariant : ∃ (t : EMLTree),
    Φ .Fuzzy t ≠ Φ_of_nc ({nodeParam .Fuzzy with mirror := true}) t := by
  -- Node(Leaf, Node(Leaf, Leaf)) has left cheap, right expensive
  -- With mirror, the roles swap
  refine ⟨.Node .Leaf (.Node .Leaf .Leaf), ?_⟩
  native_decide

-- 4.5 Mirror toggling is an INVOLUTION on the 8D space
theorem mirror_involution (nc : Cost.NodeCost) :
    ({nc with mirror := ¬nc.mirror} with mirror := ¬(¬nc.mirror)) = nc := by
  simp
```

---

## Domain 5: Depth vs Size (maxSem)

*Hypothesis: Intuitionistic (maxSem=true) makes Φ = tree.height. This is the
proof-relevance semantics — measuring proof depth, not tree size.*

```lean4
-- 5.1 Intuitionistic Φ = tree height (already proven)
theorem intuitionistic_Φ_eq_height (t : EMLTree) : Φ .Intuitionistic t = t.height :=
  Φ_intuitionistic_eq_height t

-- 5.2 maxSem=true ignores all asymmetry parameters
theorem maxSem_ignores_asymmetry (nc : Cost.NodeCost) (hms : nc.maxSem = true) (a b : Nat) :
    nc.apply a b = max a b + nc.bias := by
  simp [Cost.NodeCost.apply, Cost.NodeCost.applyUncapped, hms]

-- 5.3 Height < size for non-trivial trees — the semantics distinction
theorem height_lt_size_for_non_trivial :
    ∃ (t : EMLTree), Φ .Intuitionistic t < Φ .Classical t := by
  refine ⟨.Node (.Node .Leaf .Leaf) .Leaf, ?_⟩
  native_decide

-- 5.4 For any tree, height ≤ size, with equality iff the tree is a left comb
theorem height_le_size (t : EMLTree) : t.height ≤ t.size := by
  induction t with
  | Leaf => exact le_refl 0
  | Node l r ih_l ih_r =>
    -- height = 1 + max(height l, height r)
    -- size = 1 + size l + size r
    -- We need: 1 + max(hl, hr) ≤ 1 + sl + sr
    -- Which is: max(hl, hr) ≤ sl + sr
    -- Since hl ≤ sl and hr ≤ sr by IH, this holds
    have hl : l.height ≤ l.size := ih_l
    have hr : r.height ≤ r.size := ih_r
    omega

-- 5.5 Height = size iff tree is a left comb
theorem height_eq_size_iff_leftComb (t : EMLTree) : t.height = t.size ↔
    (∀ u : EMLTree, u ⊆ t → u.isLeftComb) := ...
-- This connects the Intuitionistic cost landscape to tree shape
```

---

## Domain 6: Saturation (satCap)

*Hypothesis: Fuzzy (satCap=5) caps Φ at 5. This models bounded truth —
the "fuzzy boundary collapse."*

```lean4
-- 6.1 Fuzzy Φ is bounded by 5 (already proven)
theorem fuzzy_Φ_bounded (t : EMLTree) : Φ .Fuzzy t ≤ 5 :=
  Φ_fuzzy_le_satCap t

-- 6.2 The bound is sharp: there exists a tree achieving Φ = 5
theorem fuzzy_Φ_sharp : ∃ (t : EMLTree), Φ .Fuzzy t = 5 := by
  refine ⟨.Node (.Node (.Node .Leaf .Leaf) (.Node .Leaf .Leaf))
               (.Node (.Node .Leaf .Leaf) (.Node .Leaf .Leaf)), ?_⟩
  native_decide

-- 6.3 Classical is unbounded (∀ M, ∃ t, Φ .Classical t ≥ M)
theorem classical_Φ_unbounded : ∀ M : Nat, ∃ (t : EMLTree), Φ .Classical t ≥ M := by
  intro M
  refine ⟨EMLTree.rightComb M, ?_⟩
  simpa [Φ_eq_size_classical, EMLTree.size_rightComb] using le_refl M

-- 6.4 Fuzzy is NOT unbounded
theorem fuzzy_Φ_not_unbounded : ¬∀ M : Nat, ∃ (t : EMLTree), Φ .Fuzzy t ≥ M := by
  intro h
  have h6 := h 6
  rcases h6 with ⟨t, ht⟩
  have hb : Φ .Fuzzy t ≤ 5 := Φ_fuzzy_le_satCap t
  omega

-- 6.5 General: satCap > 0 iff Φ is bounded for that logic
theorem bounded_iff_satCap_positive (lt : LogicType) :
    (∃ B : Nat, ∀ t : EMLTree, Φ lt t ≤ B) ↔ (nodeParam lt).satCap > 0 := by
  constructor
  · intro ⟨B, hB⟩
    -- If satCap = 0, we can build arbitrarily large trees
    ...
  · intro hsc
    -- satCap provides the bound
    refine ⟨(nodeParam lt).satCap, ?_⟩
    -- Need a general theorem: Φ lt t ≤ satCap of lt for any t when satCap > 0
    ...
```

---

## Domain 7: Coupling — Non-Locality / Cross-Sector Interaction

*Hypothesis: coupling > 0 introduces a quadratic cross-term in Φ that makes
the cost non-linear in tree size. This is the "entanglement" cost.*

```lean4
-- 7.1 Without coupling and with rightDiv=0, Φ = α·size + β for some α, β
theorem no_coupling_linear (nc : Cost.NodeCost) (hcp : nc.coupling = 0)
    (hrd : nc.rightDiv = 0) (hms : nc.maxSem = false) (hsc : nc.satCap = 0) :
    ∀ (t : EMLTree), Φ_of_nc nc t = nc.leftWeight * (t.size - nc.bias) + nc.bias := ...
-- This says the cost is size-proportional in the uncoupled, uncompressed regime.

-- 7.2 With coupling, Φ is superlinear for balanced trees
theorem coupling_superlinear_balanced :
    Φ .Quantum (EMLTree.rightComb 10) = 10 ∧
    Φ .Quantum (EMLTree.balanced 10) > 10 := by
  -- rightComb is left-heavy: coupling doesn't fire (one subtree is always small)
  -- balanced has equal subtrees: the product a*b in coupling·a·b/denom activates
  native_decide

-- 7.3 Coupling strength is the ratio coupling/denom
-- Paraconsistent: 1/8 = 0.125
-- Temporal: 1/8 = 0.125 (same)
-- Quantum: 1/10 = 0.1 (weaker)
theorem coupling_strength_comparison :
    (nodeParam .Paraconsistent).coupling / max 1 (nodeParam .Paraconsistent).denom =
    (nodeParam .Temporal).coupling / max 1 (nodeParam .Temporal).denom := by decide

-- 7.4 Coupling creates a non-distributivity witness:
-- There exist trees t, u, v such that the usual distributive law fails in Φ
theorem coupling_non_distributive : ∃ (t u v : EMLTree),
    Φ .Quantum (EMLTree.Node (EMLTree.Node t u) v) ≠
    Φ .Quantum (EMLTree.Node t (EMLTree.Node u v)) := by
  -- This is the associator defect in the cost landscape!
  -- Find trees where Φ differs when we reassociate
  refine ⟨.Leaf, .Leaf, .Leaf, ?_⟩
  native_decide
```

**Key finding to verify:**
7.4 shows that coupling > 0 is exactly the condition for non-associativity in the
cost landscape. When coupling = 0, Φ is invariant under reassociation (for
rightDiv=0). When coupling > 0, reassociation changes the cost — this is the
associator defect in Φ terms.

---

## Domain 8: Interpolation — The Continuous Logic Space

*Hypothesis: The space between named logics contains meaningful intermediate logics.
Linear interpolation in NodeCost space yields continuous deformation of the cost
landscape.*

```lean4
-- 8.1 Linear interpolation between Classical and Fuzzy
-- Defined using ℚ parameters, discretized for ℕ NodeCost fields
def interpolateClassicalFuzzy (α : ℚ) : Cost.NodeCost :=
  { leftWeight := 1
    rightDiv := 1 + (floor (α * 1) : Nat)  -- from 1 to 2 as α: 0→1
    bias := 1
    satCap := floor (α * 5)                   -- from 0 to 5 as α: 0→1
    mirror := false
    coupling := 0
    denom := 10
    maxSem := false }

-- 8.2 At α=0, we get Classical; at α=1, we get Fuzzy
theorem interp_zero_is_classical : interpolateClassicalFuzzy 0 = nodeParam .Classical := by
  ext <;> simp [interpolateClassicalFuzzy, nodeParam]

theorem interp_one_is_fuzzy : interpolateClassicalFuzzy 1 = nodeParam .Fuzzy := by
  ext <;> simp [interpolateClassicalFuzzy, nodeParam]

-- 8.3 Φ is monotone in α for any fixed tree
theorem interpolation_monotone (t : EMLTree) (α β : ℚ) (h : α ≤ β) :
    Φ_of_nc (interpolateClassicalFuzzy α) t ≤ Φ_of_nc (interpolateClassicalFuzzy β) t := by
  -- As rightDiv increases, the right subtree is more compressed → lower cost
  -- As satCap increases, the cap is looser → higher feasible cost
  -- Need to show the overall effect is monotone
  revert t
  -- Use structural induction on t
  intro t
  induction t with
  | Leaf => rfl
  | Node l r ih_l ih_r =>
    dsimp [Φ_of_nc, Cost.NodeCost.apply, Cost.NodeCost.applyUncapped,
           interpolateClassicalFuzzy]
    -- Show α ≤ β implies the apply result is monotone
    ...

-- 8.4 General interpolation between any two named logics
def interpolate (lt₁ lt₂ : LogicType) (α : ℚ) : Cost.NodeCost := ...
-- This lets us explore the continuous logic space connecting any two landmarks

-- 8.5 The interpolation path is CONNECTED: every NodeCost on the path
-- produces a valid Φ (no singularities)
theorem interpolation_non_singular (lt₁ lt₂ : LogicType) (α : ℚ) (h : 0 ≤ α) (h' : α ≤ 1) :
    ∀ t : EMLTree, Φ_of_nc (interpolate lt₁ lt₂ α) t ≥ 0 := by ...
```

**Key insight:**
The 8D space is a continuous deformation space for logic. "Choosing a logic" is
picking a point in this space. The named logics are landmarks, not the ontology.

---

## Domain 9: The Hyperstition Transition — How Generation Becomes Closure

*Hypothesis: The EngineState dynamics (via engine_to_nodecost) IS the hyperstition
transition. When a Superposition undergoes closure, its implied debt/capacity
state determines the effective NodeCost, which determines collapse direction.*

```lean4
-- 9.1 The generation→closure pipeline: any EMLTree maps to a GameOutcome
-- via the EngineState-dependent Φ
def generationViaEngine (e : EngineState) (t : EMLTree) : GameOutcome :=
  let nc := engine_to_nodecost e
  let cost := Φ_of_nc nc t
  -- Feed cost into the closure pipeline
  -- This IS the missing bridge
  closureWithCost cost t

-- 9.2 When debt=0, generation produces classical GameOutcomes
theorem zero_debt_classical_outcome (t : EMLTree) :
    generationViaEngine {local_debt:=0, capacity:=10, current_weight:=0} t =
    closure .Classical t := by
  -- Because engine_to_nodecost(debt=0) = nodeParam .Classical
  -- So Φ uses classical parameters
  unfold generationViaEngine
  simp [engine_zero_debt_classical]

-- 9.3 When debt>0, generation produces spacetime-like outcomes
theorem positive_debt_spacetime_outcome (t : EMLTree) :
    generationViaEngine {local_debt:=4, capacity:=10, current_weight:=0} t =
    closure .Spacetime t := by
  -- The engine output for debt=4 is mirror=true, leftWeight=0, rightDiv=1
  -- This is NOT exactly Spacetime (which has rightDiv=0), but Spacetime-like
  unfold generationViaEngine
  -- Need to prove Φ from engine = Φ from Spacetime on all trees?
  -- This may NOT be true! It would be a counterexample showing the engine
  -- produces a NEW logic type, not exactly one of the 15 named ones.
  ...

-- 9.4 The debt threshold flips the associativity sector
theorem debt_threshold_phase_change (t : EMLTree) :
    generationViaEngine {local_debt:=0, capacity:=10, current_weight:=0} t ≠
    generationViaEngine {local_debt:=1, capacity:=10, current_weight:=0} t := by
  -- The mirror flag change from debt=0 to debt=1 changes Φ
  -- Need a tree where mirror=true produces different Φ than mirror=false
  -- Use 4.4: Fuzzy mirror not invariant — but here we use Classical→Spacetime-like
  ...

-- 9.5 The IC pipeline's closure function MUST accept the engine-derived NodeCost
-- rather than hardcoding a LogicType. This is the architectural change needed.
theorem closure_should_accept_NodeCost :
    -- Current: closure : LogicType → EMLTree → GameOutcome
    -- Proposed: closure' : NodeCost → EMLTree → GameOutcome
    ∀ (lt : LogicType) (t : EMLTree),
    closure lt t = closure' (nodeParam lt) t := by
  intro lt t
  -- This holds definitionally if closure' uses nodeParam lt
  rfl
```

**The Hyperstition Bridge in full:**
```
Superposition (Generation.lean)
    ↓
Pick a candidate EMLTree from the superposition
    ↓
Evaluate EngineState from the tree context (debt, capacity, weight)
    ↓
engine_to_nodecost(engineState) → NodeCost (the effective logic parameters)
    ↓
Φ(NodeCost, tree) → cost value
    ↓
Normalize, grade, deontic update, self-recognize (IC pipeline)
    ↓
GameOutcome — a collapsed, stable institution
```

---

## Domain 10: The `.ncd` Plan Connection — Market Events as SO Constraints

*Hypothesis: The market_closure.ncd plan's generate_tree(market_events) relation
is an EngineState trajectory in the 8D space. The market type is determined by
the fixed point of this trajectory.*

```lean4
-- 10.1 A sequence of market events defines a trajectory in EngineState space
structure MarketEvent where
  type : MarketEventType
  delta : ℤ  -- signed impact on debt/weight

inductive MarketEventType where
  | trade
  | cancel
  | inject

def eventTrajectory (events : List MarketEvent) (start : EngineState) : List EngineState :=
  -- Each event updates the engine state
  ...

-- 10.2 The trajectory converges under reasonable conditions
theorem trajectory_converges (events : List MarketEvent) (start : EngineState) :
    ∃ (e : EngineState), eventTrajectory events start endsAt e ∧
    engine_to_nodecost e = engine_to_nodecost (step e) := ...
-- "endsAt" means the final state, not a limit point

-- 10.3 The convergent NodeCost determines the MarketType
theorem convergent_MarketType (events : List MarketEvent) (start : EngineState) :
    let e := (eventTrajectory events start).last?
    MarketType.ofNodeCost (engine_to_nodecost e) = decideMarketType e events := by
  -- This is the specification for decideMarketType — it should match
  -- the engine-derived NodeCost
  ...

-- 10.4 The resonant market types correspond to specific fixed points
-- Arbitrary (no constraint) → debt=0, classical NodeCost
theorem fairPrice_is_associative_fixedPoint (start : EngineState) (h : start.local_debt = 0) :
    (eventTrajectory [] start).last? = some start := by
  simp [eventTrajectory]

-- 10.5 FairPrice emerges when the engine converges to the classical fixed point
-- (debt extinguished by calibration)
theorem fairPrice_equilibrium :
    ∃ (events : List MarketEvent), engine_to_nodecost
      ((eventTrajectory events {local_debt:=4, capacity:=10, current_weight:=0}).last?) =
    nodeParam .Classical := by
  -- Show a sequence of trades that pays down debt to 0
  ...
```

---

## Implementation Order

| Phase | Domain | Tests | What we learn |
|-------|--------|-------|---------------|
| **1** | 0 | Collapse detection, identity theorems | Which named logics are identical/different in 8D space |
| **2** | 1 | Classical region characterization | The precise boundary of "cost = size" |
| **3** | 2 | cdStep 2→3 boundary | Which NodeCost parameters activate at the phase change |
| **4** | 3 | EngineState flow | The dynamical system on the 8D space |
| **5** | 4, 5, 6 | Mirror, maxSem, satCap | Individual parameter semantics |
| **6** | 7 | Coupling | Non-locality and interaction semantics |
| **7** | 8 | Interpolation | The continuous logic space |
| **8** | 9, 10 | Hyperstition bridge | The actual Generation→IC pipeline |

Each phase reveals information that refines the hypotheses of the next phase.
Many tests will find counterexamples — those are discoveries, not failures.

## Running the Tests

```bash
# After writing SplitOctonionLogic.lean with the theorems:
lake build
# The theorems are checked at compile time.
```

For computation-heavy tests (native_decide on large trees), add a timeout check
or use `by native_decide` on small trees only.
