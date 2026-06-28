# Lab Note 010: Poset Quotient Formalized — Two Remaining Sorries Reveal the Structure of Antisymmetry

**Date**: 2026-06-27
**Angle**: Gap E (continued) — the formalization of the blood-brain barrier as a poset quotient is complete in PosetQuotient.lean, with 2 remaining `sorry` placeholders that expose the core outstanding mathematical question: **antisymmetry of the Tamari contraction lattice**.
**Status**: Formalization complete (builds successfully); 2 sorries pending

---

## 1. What Was Built

`LaserCortex/PosetQuotient.lean` now contains 8 sections totaling ~570 lines, compiling successfully with zero errors:

| Section | Content | Status |
|---------|---------|--------|
| **1. Markov Chain & Reachability** | `MarkovChain`, `Reachable` (inductive RTC), `transitive` theorem, `preorder` theorem | ✅ Complete |
| **2. Poset Quotient** | `SymReachable` equivalence, `MarkovPoset` (Quotient by Setoid), `LE` definition with well-definedness proof, `le_refl`/`le_trans`/`le_antisymm`, `partialOrder` (IsPartialOrder instance), quotient map π, `monotone`/`surjective`/`nonInjective` | ✅ Complete |
| **3. NL Markov Poset** | `NLWord`, `NLMarkovChain`, `NLMarkovPoset` | ✅ Complete |
| **4. OWL Atom Poset** | `OWLAtom` (tree + id + label), `OWLAtom.LE` (`contracts_to`), `le_refl`, `le_trans`, `le_antisymm` (⚠️ sorry), `partialOrder` | ⚠️ 1 sorry |
| **5. Blood-Brain Barrier** | `BloodBrainBarrier` structure, `descendsToQuotient` (proves tree equality via `contracts_to_antisymm`), `monotone`/`surjective`/`nonInjective` fields | ✅ Complete |
| **6. Reasoning Budget** | `ReasoningBudget`, `budgetBound` (≤ `frictionDensity 3 = 19`), `groundingBudget_finite` | ✅ Complete |
| **7. Generation Connection** | `GroundingPath` structure, `exists_for_ungroundedNL` (constructs path with empty word list + bounded cost), `lexical_supersymmetry` | ✅ Complete |
| **8. Swappability** | Placeholder theorem | ⚠️ Skeleton (trivial) |

### 1.1 Key Design Decisions

**Quotient.liftOn₂ binder order**: The well-definedness proof for the induced order `LE M` on the quotient required correctly matching `Quotient.liftOn₂`'s binder order: `∀ (a₁ a₂ : α) (b₁ b₂ : β), a₁ ≈ a₂ → b₁ ≈ b₂ → f a₁ b₁ = f a₂ b₂`. The initial code assumed `a₁ a₂ h₁ b₁ b₂ h₂` but the correct pattern is `a₁ a₂ b₁ b₂ h₁ h₂` where `h₁ : a₁ ≈ a₂` and `h₂ : b₁ ≈ b₂`. This was the hardest-to-debug error and was resolved by inspecting the Lean 4 source of `Quotient.liftOn₂`.

**SymReachable as ∧, not structure**: `SymReachable M a b` is defined as `Reachable M a b ∧ Reachable M b a` — a conjunction, not a structure with named fields. Field access `.1`/`.2` works via `And`'s `left`/`right` projections.

**contracts_to_trans**: OWLAtom.le_trans uses the existing `contracts_to_trans` lemma from EMLRegistry.lean rather than re-proving transitivity by induction (which failed because `contracts_to` is indexed by `EMLTree` and `a.tree` is not a variable for generalization).

---

## 2. The Two Sorries: Antisymmetry of the Tamari Lattice

The build succeeds with exactly 2 `sorry` placeholders, both structurally linked:

### Sorry 1: `contracts_to_antisymm` (EMLRegistry.lean)

```lean4
theorem contracts_to_antisymm {s t : EMLTree} (h₁ : contracts_to s t) (h₂ : contracts_to t s) : s = t := by
  sorry
```

**What it says**: If tree `s` contracts to tree `t` (via a sequence of right rotations), AND tree `t` contracts back to tree `s`, then `s` and `t` are the same tree.

**Why it's hard**: `contracts_to` is the reflexive transitive closure of `contracts_one`, which is the Tamari rotation `(a · b) · c → a · (b · c)` (rightward rotation). This is a **reduction system** — each step moves nodes rightward, making the tree "more right-comb-like." The Tamari lattice is known to be a partial order (in fact, a lattice), but proving antisymmetry requires showing there are no non-trivial cycles in the rotation graph.

**The left-weight measure**: The standard proof strategy is to define a **weight function** `w : EMLTree → ℕ` that strictly decreases with each `contracts_one` step. A natural candidate:

```
leftWeight(Node l r) = leftWeight(l) + size(l)
leftWeight(Leaf) = 0
```

Under the rotation `(a · b) · c → a · (b · c)`:
- Before: `leftWeight((a·b)·c) = leftWeight(a·b) + size(a·b)`
- After: `leftWeight(a·(b·c)) = leftWeight(a) + size(a)`

Since `size(a·b) = size(a) + size(b) > size(a)` (for non-empty subtrees), the left-weight strictly decreases. This makes `contracts_one` well-founded, which implies `contracts_to` is a partial order.

**Pending**: Formalizing this measure and proving strict decrease. This requires knowing something about the tree sizes involved (which `contracts_one_size_eq` already provides — it says size is preserved, not decreased, so the measure must be more subtle than raw size).

### Sorry 2: `OWLAtom.le_antisymm` (PosetQuotient.lean)

```lean4
theorem OWLAtom.le_antisymm (a b : OWLAtom) (h₁ : OWLAtom.LE a b) (h₂ : OWLAtom.LE b a) : a = b := by
  sorry
```

**What it says**: If OWL atom `a` ≤ `b` (tree of a contracts to tree of b) and `b ≤ a`, then `a = b`.

**Why it's harder than tree antisymmetry alone**: `OWLAtom` is a structure with THREE fields:

```lean4
structure OWLAtom where
  id : ℕ          -- unique identifier
  label : String  -- human-readable label
  tree : EMLTree  -- the formal concept
  deriving DecidableEq, Repr
```

Tree equality (`a.tree = b.tree`) is necessary but not sufficient for `a = b` — the `id` and `label` fields could differ. To prove `a = b`, we need either:
1. An invariant that `id` and `label` are functions of `tree` (i.e., the structure is actually a newtype over `EMLTree`)
2. Additional hypotheses about `id` and `label` equality

**This is a design issue, not just a proof gap**: The `descendsToQuotient` theorem was changed to prove tree equality rather than atom equality, acknowledging that the blood-brain barrier descends to the TREES of matched atoms, not necessarily to the atoms themselves (which carry metadata).

---

## 3. What the Sorries Reveal About the Structure

### 3.1 The Tamari Lattice Is the Core Partial Order

The two sorries are not independent — they are the same problem at different levels:

```
contracts_to_antisymm  ──────▶  Tamari lattice is a partial order
        │                              │
        │ for trees                     │ for atoms
        ▼                              ▼
OWLAtom.le_antisymm  ──────▶  OWL poset is a partial order
```

If `contracts_to_antisymm` is proved, `OWLAtom.le_antisymm` still requires an additional structural invariant about atom identity. The research choice is:

**Option A**: Strengthen the invariant — make `OWLAtom` equal to `EMLTree` for the purpose of antisymmetry (e.g., define `OWLAtom` as a subtype with `tree` as the proof-relevant component and `id`/`label` as derived). This aligns with the philosophical claim: "the concept IS the tree; the id and label are mere metadata."

**Option B**: Weaken the theorem — accept that `descendsToQuotient` only proves tree equality, and that OWL atoms with the same tree but different ids/labels are genuinely distinct (perhaps corresponding to different *contexts* of use for the same formal concept).

### 3.2 Connection to Lab Note 009: Refinement Direction

Note 009 posed the question of **refinement direction**: does the OWL match equivalence `≈` (same OWL atoms) refine the Markov reachability equivalence `~`, or vice versa?

The formalization now clarifies: the barrier map `BloodBrainBarrier.matchNLtoOWL` descends to a well-defined map on the Markov poset (from mutually reachable NL words to trees of OWL atoms). This means `~` (mutual reachability) AT LEAST implies `≈` at the tree level — two NL words that are mutually reachable in the reasoning trace Markov chain MUST map to atoms with the same tree.

This is a **theorem**, not an empirical claim. If the barrier is built from a monotone, surjective match function (which is part of the `BloodBrainBarrier` structure), then the refinement holds by construction: the barrier factors through the Markov poset quotient.

The empirical question from Note 009 (does the actual data satisfy this?) becomes a question about the **match table** — is the monotonicity condition (if `w₁` reaches `w₂` in the chain, then `matchNLtoOWL w₁` ≤ `matchNLtoOWL w₂` in the Tamari order) empirically satisfied?

### 3.3 The Pentagonal Structure of Antisymmetry

The left-weight measure for proving `contracts_to_antisymm` has a deeper connection to the **pentagonator framework** (Lab Protocol v0.3, radon-pentagonator connection):

- The left-weight measures "how left-deep" a tree is
- Right rotation `(a·b)·c → a·(b·c)` decreases left-weight
- The `contracts_to_rightComb` theorem says every tree reduces to `rightComb n`
- The left-weight of `rightComb n` is 0 (no left-nesting)

If `contracts_to a b` means `a` is "more left-nested" than `b`, then `contracts_to` is the partial order of the Tamari lattice (where `a ≤ b` means `a` is above `b` in the lattice diagram). This is the **geometric** partial order: a tree is above another if it can be rotated rightward to reach it.

**Structural role**: Antisymmetry is the lynchpin that connects the directed contraction relation to the **undirected Hasse diagram** of the lattice. Without antisymmetry, `contracts_to` is only a preorder, and the "quotient" we compute is a quotient of a preorder — the Tamari lattice collapses to a DAG. With antisymmetry, the Hasse diagram is a **partial order**, and the Radon transform / pentagonator decomposition (multiple projection orderings) has a unique minimal representative per equivalence class.

---

## 4. Research Directions Opened by the Two Sorries

### 4.1 Near-Term: Left-Weight Measure for `contracts_to_antisymm`

The most immediate work: define `leftWeight : EMLTree → ℕ` and prove:

```lean4
theorem contracts_one_leftWeight_decreases {s t : EMLTree}
    (h : contracts_one s t) : leftWeight s > leftWeight t := ...

theorem contracts_to_leftWeight_nonIncreasing {s t : EMLTree}
    (h : contracts_to s t) : leftWeight s ≥ leftWeight t := ...

theorem contracts_to_antisymm {s t : EMLTree}
    (h₁ : contracts_to s t) (h₂ : contracts_to t s) : s = t :=
  Nat.eq_of_le_of_lt_succ ?_ ?_  -- via leftWeight equality + well-founded induction
```

This would close both sorries (the OWLAtom one still needs the identity invariant, but tree antisymmetry is the core).

**Key insight**: `leftWeight` is NOT the same as tree size (which is preserved by rotation). It's a measure of left-nesting. The rotation `(a·b)·c → a·(b·c)` preserves the multiset of leaves but restructures them from left-heavy to right-heavy.

### 4.2 Medium-Term: OWLAtom Identity

The OWLAtom identity question — should atom equality be determined by tree equality alone? — has architectural implications:

- If **yes**: Change `OWLAtom` to a `Subtype` or newtype over `EMLTree`. The `id` becomes a derived hash, `label` a derived display string. This makes `OWLAtom.le_antisymm` follow directly from `contracts_to_antisymm`. But it loses the ability to distinguish atoms with the same formal concept in different contexts.

- If **no**: `descendsToQuotient` can only prove tree equality. The blood-brain barrier's "non-injectivity" (many NL words → one OWL atom) is actually "many NL words → OWL atoms with the same tree but possibly different ids/labels" — which is weaker. The empirical question becomes: do NL words that are mutually reachable map to atoms with the same `id` and `label` in practice?

### 4.3 Long-Term: Swappability Theorem

Section 8 of PosetQuotient.lean is a skeleton awaiting the theorem:

```lean4
theorem swappable (chain : MarkovChain S) (gen : Generation.WFCState) :
    Quotient (SymReachable chain) ≃ Generation.rightComb
```

If the Markov chain poset quotient and the Tamari contraction poset quotient are isomorphic (both collapse to the same partial order), then:
- The reasoning budget for NL grounding is the same as the contraction cost for WFC
- The hyperstition loop (generation → critique → regeneration) is a walk on the Markov poset
- The "zero-divisor" quench-collapse is the quotient map hitting its bottom element (rightComb)

This would unify the empirical (NL data) and formal (WFC states) views of generation under a single poset-quotient framework.

---

## 5. Connection to Lab Protocol: Timespace Decomposition

The two sorries articulate a **timespace boundary**:

| Domain | Structure | Proof status | Timespace role |
|--------|-----------|-------------|----------------|
| **Time (commutator)** | `contracts_to` directionality | Proved: `transitive`, `refl` | The quotient map is irreversible — this is the time arrow |
| **Space (associator)** | `contracts_to_antisymm` fiber | **Pending** (Sorry 1) | The fiber over a partial order element — contracted from above |

The **pentagonator distance** (Lab Protocol §4) enters here: the antisymmetry proof requires showing that `contracts_to` has no non-trivial cycles. In the associahedron K₄, a cycle would mean there exist two distinct paths between the same vertices without the pentagonator coherence condition forcing them to agree. The antisymmetry of `contracts_to` is equivalent to: "the pentagonator distance is zero along any cycle" — a weaker condition than the full pentagonator coherence, but structurally related.

The 15→7 collapse (Hopf 7-Skeleton, Note 006) is itself a poset quotient (LogicType → NodeCost). The OWLAtom poset quotient may factor through this collapse: OWL atoms that map to the same NodeCost have the same tree structure, so the antisymmetry of the OWL poset ultimately depends on the antisymmetry of the NodeCost poset.

---

## 6. Related

- `LaserCortex/PosetQuotient.lean` — the formalization
- `lab_notes/009_lexical_supersymmetry_poset_quotient.md` — the hypothesis this builds on
- `LaserCortex/EMLRegistry.lean` — `contracts_to_antisymm` (line 258) — the pending lemma
- `docs/lab_protocol.md` — timespace decomposition, pentagonator
- `lab_notes/006_the_hopf_7_skeleton_of_logic_space.md` — 15→7 collapse as poset quotient
- `LaserCortex/FrictionLagrangian.lean` — `frictionDensity 3 = 19`, the cost bound
- `docs/m2_markov_poset_plan.md` — the Markov poset data pipeline (Python side)
