# AlphaProof Nexus Procedure for Typed Cortex

**Status**: Skill - Active  
**Date**: 2026-06-06  
**Author**: Mistral Vibe  
**Pattern**: parse → extract → formalize → validate → integrate  

---

## Executive Summary

This skill encodes the **AlphaProof Nexus procedure** adapted for the Typed Cortex bootstrap process. AlphaProof Nexus successfully formalized 500+ theorems across OEIS, Erdős problems, Stacks Project, and human-AI collaborations using a consistent workflow pattern.

**Key Insight**: The procedure is a **universal formalization workflow** that can be applied to any mathematical domain, including our EML Registry + Cayley-Dickson + Nuclear Isomer framework.

---

## Core Pattern: parse → extract → formalize → validate → integrate

| Phase | AlphaProof Activity | Our Application to Typed Cortex |
|-------|---------------------|--------------------------------|
| **parse** | Ingest problem statements from OEIS, Erdős, Stacks | Parse topological_isomer_hypothesis.md, Cayley-Dickson notes, NeSy framework |
| **extract** | Identify definitions, lemmas, theorem structure | Extract EMLTree, contracts_to, rightComb, Tamari lattice concepts |
| **formalize** | Create Lean 4 formalizations with helper lemmas | Formalize contracts_to_rightComb with secondary lemmas (node_of_rightCombs) |
| **validate** | Prove using automation + human-guided steps | Prove node_of_rightCombs_contracts_to_rightComb, then contracts_to_rightComb |
| **integrate** | Package results for portability (registry, certificates) | Create TamariTime.lean, APNRegistry.lean, NuclearRegistry.lean |

---

## Phase 1: PARSE

### Purpose
Transform raw knowledge sources into structured, formalizable problem statements.

### Input
- Domain-specific documentation (`topological_isomer_hypothesis.md`)
- Existing Lean files (`unified_spacetime_engine_explicit.lean`)
- Research notes (`/tensegrity mechanism fusion/notes/`, `/devcom/docs/NeSy/`)
- AlphaProof Nexus theorem collection (`alphaproof-nexus-results/`)

### Output
- Formal problem statements in Lean-compatible form
- Concept-to-algebra mappings
- Domain relationships

### Actions
1. **Identify mathematical objects**: Extract concrete mathematical structures from prose
   - Example: "¹⁸⁰ᵐTa isomer" → "specific EMLTree configuration"
   - Example: "split-octonion associator" → "Tamari lattice contraction path"

2. **Map domain concepts to algebraic structures**:
   ```
   Nuclear Physics → Cayley-Dickson Algebra → EML Trees → Tamari Lattice
   ¹⁸⁰ᵐTa         → Split-Octonions        → EMLTree    → contracts_to
   ```

3. **Create formal problem statements**:
   ```lean
   -- From: "The isomeric state cannot contract to ground state without energy"
   -- To:    theorem topological_barrier : ¬ contracts_to isomer_tree ground_tree
   
   -- From: "Every configuration evolves to equilibrium"
   -- To:    theorem contracts_to_rightComb (t : EMLTree) : contracts_to t (rightComb t.size)
   ```

### Tools
- Natural language parsing (manual or LLM-assisted)
- Domain-specific knowledge extraction
- Pattern matching to known mathematical structures

### Heuristics (from AlphaProof)
- Look for **quantitative statements** (formulas, equations)
- Identify **conditional relationships** (if-then, equivalence)
- Extract **universal statements** (for all, there exists)
- Note **exceptions and edge cases**

---

## Phase 2: EXTRACT

### Purpose
Transform parsed problem statements into formal Lean 4 definitions, types, and lemma candidates.

### Input
- Structured problem statements from Phase 1
- Existing formalizations (EMLRegistry.lean, unified_spacetime_engine_explicit.lean)

### Output
- Core type definitions
- Auxiliary definitions
- Lemma candidates (with or without proofs)
- Theorem statements

### Actions

#### 1. Define Core Types
Identify the fundamental types that represent domain concepts.

**Pattern from AlphaProof**:
```lean
-- OEIS example: A258667 uses these core types
private def A258667_inner_sum (n k : ℕ) : ℤ := ...
def A258667 (n : ℕ) : ℕ := ...
noncomputable def A258667_asymptotic_term (n : ℕ) : ℝ := ...
```

**Our Application**:
```lean
-- EML Registry types (already defined)
inductive EMLTree : Type where
  | Leaf : EMLTree
  | Node : EMLTree → EMLTree → EMLTree

def rightComb : Nat → EMLTree
  | 0     => .Leaf
  | n + 1 => .Node .Leaf (rightComb n)

-- Tamari contraction (already defined)
inductive contracts_one : EMLTree → EMLTree → Prop where
  | rotate : ∀ (a b c : EMLTree), contracts_one (.Node (.Node a b) c) (.Node a (.Node b c))
  | left   : ∀ (l l' r : EMLTree), contracts_one l l' → contracts_one (.Node l r) (.Node l' r)
  | right  : ∀ (l r r' : EMLTree), contracts_one r r' → contracts_one (.Node l r) (.Node l r')

-- Temporal metrics (to be defined in TamariTime.lean)
def computationalAge (t : EMLTree) : Nat
def timeDimension (t : EMLTree) : Nat
```

#### 2. Identify Required Lemmas
Find the intermediate results needed to prove main theorems.

**Heuristics** (from AlphaProof analysis):
- **Invariant lemmas**: Properties preserved by operations
  - Example: `size_invariant` - contracts_to preserves tree size
- **Base case lemmas**: Simple instances that serve as induction anchors
  - Example: `rightComb 0 = Leaf`
- **Composition lemmas**: How operations interact with combinations
  - Example: `node_of_rightCombs_contracts_to_rightComb`
- **Normalization lemmas**: Properties of normal forms
  - Example: `rightComb` is the minimum element

**Our Application - Lemma Candidates**:
```lean
-- Invariants (already proven)
lemma size_invariant {s t : EMLTree} (h : contracts_to s t) : s.size = t.size

-- Normal form properties
lemma rightComb_size (n : Nat) : (rightComb n).size = n
lemma rightComb_depth (n : Nat) : (rightComb n).depth = n

-- Composition lemmas (CRITICAL - currently missing)
lemma node_of_rightCombs_contracts_to_rightComb (a b : Nat) :
    contracts_to (Node (rightComb a) (rightComb b)) (rightComb (1 + a + b))

-- Step lemmas
lemma single_rotation_preserves_size (a b c : EMLTree) :
    (Node (Node a b) c).size = (Node a (Node b c)).size
```

#### 3. Extract Auxiliary Definitions
Create helper functions and definitions that simplify proofs.

**Pattern from AlphaProof**:
```lean
-- From oeis_A258667_conjecture_0.lean
noncomputable def nat_fac_to_real (n : ℕ) : ℝ := (Nat.factorial n : ℝ)
noncomputable def menage_denom_term (n k : ℕ) : ℝ := ...
noncomputable def A258667_asymptotic_sum_part (n : ℕ) : ℝ := ...
```

**Our Application**:
```lean
-- Temporal distance
def temporalDistance (s t : EMLTree) : Nat

-- Tamari neighborhood
def tamariNeighborhood (t : EMLTree) : Finset EMLTree

-- Contraction path
def contractionPath (s t : EMLTree) (h : contracts_to s t) : List EMLTree
```

### Tools
- Type system exploration (Lean's type checker)
- Pattern matching on problem structure
- Inductive reasoning for recursive definitions

### Validation
- Ensure all extracted definitions compile
- Verify type correctness
- Check that definitions capture intended semantics

---

## Phase 3: FORMALIZE

### Purpose
Create complete Lean 4 formalizations with theorem statements, helper lemmas, and proof structure.

### Input
- Extracted definitions and lemma candidates from Phase 2

### Output
- Complete Lean files with:
  - Imports and namespace declarations
  - Type definitions
  - Lemma statements
  - Theorem statements
  - Proof structure (possibly with sorries)

### Pattern from AlphaProof Nexus

All 500+ formalized theorems follow this consistent structure:

```lean
/- Copyright notice -/

import FormalConjectures.Util.ProblemImports

-- Resource options (CRITICAL for complex proofs)
set_option maxHeartbeats 0
set_option maxRecDepth 4000
set_option synthInstance.maxHeartbeats 20000
set_option synthInstance.maxSize 128
set_option maxHeartbeats 200000

-- Open namespaces for convenience
open BigOperators Nat Int Real Asymptotics Filter
open Polynomial
open scoped BigOperators Classical ENNReal ...

-- Problem-specific definitions
private def helper_def (n : ℕ) : Type := ...
noncomputable def asymptotic_term (n : ℕ) : ℝ := ...

-- EVOLVE-BLOCK-START: Generated helper lemmas
lemma helper_lemma_1 : ... := by
  delta helper_def
  norm_num[...]
  simp [...]
  aesop

lemma helper_lemma_2 : ... := by
  push_cast[...]
  rw [...]
  omega

-- EVOLVE-BLOCK-END

-- Main theorem (often very concise)
theorem target_theorem : ... := by
  have h1 := helper_lemma_1
  have h2 := helper_lemma_2
  exact h1.trans h2
```

### Key Observations

1. **Resource Management**: AlphaProof sets aggressive resource limits to handle complex proofs
   - `maxHeartbeats 200000` - allows deep computation
   - `maxRecDepth 4000` - handles deep recursion
   - `synthInstance` options - controls type class synthesis

2. **Namespace Strategy**: Opens many namespaces at the top for brevity
   - `open BigOperators Nat Int Real Asymptotics Filter`
   - `open scoped` for local notations

3. **Lemma Structure**:
   - **Private definitions**: `private def` for internal use
   - **Helper lemmas**: Proven first, used in main theorem
   - **Dense proofs**: Heavy use of automation

4. **Proof Tactics** (by frequency in AlphaProof corpus):
   | Tactic | Frequency | Purpose |
   |--------|-----------|---------|
   | `simp` | Very High | Simplification with lemmas |
   | `norm_num` | Very High | Normalize numeric expressions |
   | `delta` | High | Unfold definitions |
   | `push_cast` | High | Push casts through operations |
   | `aesop` | High | Automated proof search |
   | `rw` | High | Rewrite using equalities |
   | `omega` | Medium | Linear arithmetic |
   | `nlinarith` | Medium | Nonlinear arithmetic |
   | `ring` | Medium | Ring equalities |
   | `grind` | Medium | SMT-style automation |
   | `exact` | Medium | Direct proof term |
   | `apply` | Medium | Apply implication |
   | `have` | Medium | Introduce intermediate result |

### Our Application: EMLRegistry.lean Formalization

Current state already follows this pattern well:

```lean
-- Imports
import Mathlib.Data.Fin.Basic
import Mathlib.Data.Finset.Basic
import Mathlib.Logic.Equiv.Basic

namespace EMLRegistry

-- Type definitions (Phase 2 output)
inductive EMLTree : Type where
  | Leaf : EMLTree
  | Node : EMLTree → EMLTree → EMLTree

def rightComb : Nat → EMLTree
  | 0     => .Leaf
  | n + 1 => .Node .Leaf (rightComb n)

inductive contracts_one : EMLTree → EMLTree → Prop where
  | rotate : ∀ (a b c : EMLTree),
      contracts_one (.Node (.Node a b) c) (.Node a (.Node b c))
  | left   : ∀ (l l' r : EMLTree),
      contracts_one l l' → contracts_one (.Node l r) (.Node l' r)
  | right  : ∀ (l r r' : EMLTree),
      contracts_one r r' → contracts_one (.Node l r) (.Node l r')

-- Helper lemmas
lemma size_invariant {s t : EMLTree} (h : contracts_to s t) : s.size = t.size := by ...

-- Main theorem (CURRENT BLOCKER)
theorem contracts_to_rightComb (t : EMLTree) :
    contracts_to t (rightComb t.size) := by
  sorry  -- Needs: node_of_rightCombs_contracts_to_rightComb
```

### Template for New Files

**TamariTime.lean Template**:
```lean
/- TamariTime.lean - Temporal metrics for Tamari lattice -/

import LaserCortex.EMLRegistry

namespace TamariTime

-- Resource options
set_option maxHeartbeats 200000
set_option maxRecDepth 4000

open Nat

-- Elementary time step
def TimeStep : EMLTree → EMLTree → Prop := EMLRegistry.contracts_one

-- Temporal distance
def temporalDistance (s t : EMLTree) : Nat := sorry

-- Computational age
def computationalAge (t : EMLTree) : Nat :=
  temporalDistance t (EMLRegistry.rightComb t.size)

-- Time dimension
def timeDimension (t : EMLTree) : Nat := t.depth

-- Theorems

theorem finite_computational_age (t : EMLTree) :
    computationalAge t < ∞ := by
  -- Follows from contracts_to_rightComb
  exact EMLRegistry.contracts_to_rightComb t

theorem time_additivity (l r : EMLTree) :
    computationalAge (.Node l r) ≤ computationalAge l + computationalAge r + 1 := by
  sorry

theorem ground_state_zero_age (n : Nat) :
    computationalAge (EMLRegistry.rightComb n) = 0 := by
  sorry

end TamariTime
```

### Validation
- All definitions must type-check
- All stated lemmas must be well-formed
- Proof structure should be clear (even with sorries)

---

## Phase 4: VALIDATE

### Purpose
Transform formalized code with sorries into complete, proven theorems.

### Input
- Lean files with theorem statements and helper lemmas (possibly with sorries)

### Output
- Complete proofs with no sorries
- Validated theorems that compile with `lake build`

### Strategy from AlphaProof Nexus

#### 1. Proof Order: Bottom-Up
AlphaProof proves lemmas in dependency order:
```
Base lemmas (no dependencies) → Intermediate lemmas → Main theorem
```

**Example from oeis_A258667**:
```lean
-- Base lemmas first
lemma inner_sum_zero (n : ℕ) (h : 5 ≤ n) : A258667_inner_sum n 0 = 1 := by ...
lemma inner_sum_one (n : ℕ) (h : 6 ≤ n) : A258667_inner_sum n 1 = 2 * n - 4 := by ...

-- Intermediate lemmas
lemma asymp_sum_limit : Tendsto (fun n => A258667_asymptotic_sum_part n) atTop (𝓝 0) := by ...
lemma prefactor_equiv : IsEquivalent atTop ... := by ...

-- Main theorem last
theorem target_theorem_0 : IsEquivalent atTop ... := by
  have h1 := seq_equiv
  have h2 := asymp_term_equiv
  exact Asymptotics.IsEquivalent.trans h1 (Asymptotics.IsEquivalent.symm h2)
```

#### 2. Automation Cascade
AlphaProof uses this tactic order (stop on first success):
```
rfl → simp → ring → linarith → nlinarith → omega → exact? → apply? → grind → aesop
```

**Automation Patterns**:
```lean
-- Pattern 1: Unfold + Normalize + Simplify
lemma helper : ... := by
  delta definition
  norm_num[...]
  simp [...]

-- Pattern 2: Unfold + Push casts + Rewrite
lemma helper : ... := by
  delta definition
  push_cast[...]
  rw [...]
  omega

-- Pattern 3: Heavy automation
lemma helper : ... := by
  aesop

-- Pattern 4: Combined
lemma helper : ... := by
  delta definition
  norm_num[mul_comm, ...]
  push_cast[nat_fac_to_real, ...]
  simp [Finset.sum_range_succ', ...]
  aesop
```

#### 3. Human Guidance for Complex Steps
When automation fails, AlphaProof provides guidance:
```lean
-- Example: Manual rewrite before automation
lemma complex_helper : ... := by
  -- Human step: identify the key transformation
  rw [key_equality]
  -- Automation: handle the rest
  simp [...]
  aesop

-- Example: Induction with guidance
lemma inductive_helper : ... := by
  induction n with
  | zero => simp [...]
  | succ n ih =>
      -- Human: apply IH at the right place
      have := ih transformed_argument
      -- Automation: finish
      simp [*]
      aesop
```

### Our Application: Proving contracts_to_rightComb

#### Current Blocker Analysis

```lean
theorem contracts_to_rightComb (t : EMLTree) :
    contracts_to t (rightComb t.size) := by
  induction t with
  | Leaf => exact .refl .Leaf
  | Node l r ihl ihr =>
    have hl : contracts_to l (rightComb l.size) := ihl
    have hr : contracts_to r (rightComb r.size) := ihr
    -- BLOCKER: Need this lemma
    have key : contracts_to
        (Node (rightComb l.size) (rightComb r.size))
        (rightComb (1 + l.size + r.size)) := by
      sorry  -- ← THIS IS THE BLOCKER
    exact .step l (rightComb l.size) (Node (rightComb l.size) r)
      hl (.step (rightComb l.size) r (rightComb (1 + l.size + r.size))
        hr key)
```

#### The Blocker Lemma: node_of_rightCombs_contracts_to_rightComb

**Why it's needed**: The inductive step requires showing that when you compose two right-combs (equilibrium states), the result contracts to the right-comb of the combined size.

**Physical interpretation**: When two systems at equilibrium (right-comb states) are combined, the composite system evolves to a new equilibrium in `a + b + 1` steps (the +1 is for the composition operation itself).

**Proof Strategy**:
```lean
lemma node_of_rightCombs_contracts_to_rightComb (a b : Nat) :
    contracts_to
      (Node (rightComb a) (rightComb b))
      (rightComb (1 + a + b)) := by
  -- Induction on a (or b, symmetric)
  induction a with
  | zero =>
    -- Base case: a = 0, rightComb 0 = Leaf
    -- Goal: Node Leaf (rightComb b) → rightComb (1 + 0 + b)
    -- But rightComb (1 + b) = Node Leaf (rightComb b) by definition
    simp [rightComb]
    exact .refl _
    
  | succ a ih =>
    -- Inductive case: a = a' + 1
    -- rightComb (a' + 1) = Node Leaf (rightComb a')
    -- Goal: Node (Node Leaf (rightComb a')) (rightComb b) 
    --       → Node Leaf (rightComb (1 + (a' + 1) + b))
    --       = Node Leaf (rightComb (a' + b + 2))
    
    -- Step 1: Apply rotation
    -- Node (Node Leaf X) Y → Node Leaf (Node X Y)
    have rot : contracts_one
        (Node (Node Leaf (rightComb a)) (rightComb b))
        (Node Leaf (Node (rightComb a) (rightComb b))) :=
      .rotate Leaf (rightComb a) (rightComb b)
    
    -- Step 2: Apply IH to Node (rightComb a) (rightComb b)
    have step1 : contracts_to
        (Node (rightComb a) (rightComb b))
        (rightComb (1 + a + b)) := ih b
    
    -- Step 3: Apply congruence to get Node Leaf (...) → Node Leaf (...)
    have step2 : contracts_to
        (Node Leaf (Node (rightComb a) (rightComb b)))
        (Node Leaf (rightComb (1 + a + b))) :=
      .right Leaf (Node (rightComb a) (rightComb b)) (rightComb (1 + a + b)) step1
    
    -- Step 4: Show rightComb (1 + a + b) = rightComb ((a+1) + b + 1 - 1)??
    -- Need to verify: 1 + (a+1) + b = 1 + a + b + 1
    -- And: rightComb (1 + a + b + 1) = Node Leaf (rightComb (1 + a + b))
    -- This is true by definition of rightComb
    
    have target_eq : rightComb (1 + (a + 1) + b) = Node Leaf (rightComb (1 + a + b)) := by
      simp [rightComb]
      rfl
    
    -- Combine all steps
    have combined : contracts_to
        (Node Leaf (Node (rightComb a) (rightComb b)))
        (rightComb (1 + (a + 1) + b)) := by
      rw [target_eq]
      exact step2
    
    exact .step _ _ _ rot combined
```

#### Validation Steps

1. **Prove node_of_rightCombs_contracts_to_rightComb** (current blocker)
2. **Update contracts_to_rightComb** to use the proven lemma
3. **Verify compilation**: `lake env lean LaserCortex/EMLRegistry.lean`
4. **Test with examples**: Verify specific tree contractions

### Tools
- Lean LSP for live goal inspection
- `lean_goal` to see proof state at specific lines
- `lean_multi_attempt` to test multiple tactic combinations
- `lean_diagnostic_messages` for error checking

### Success Criteria
- No sorries in target scope
- All proofs use standard axioms only (propext, Classical.choice, Quot.sound)
- `lake build` passes for the file

---

## Phase 5: INTEGRATE

### Purpose
Package proven results into portable, reusable components for the Typed Cortex framework.

### Input
- Proven theorems from Phase 4
- External theorem collections (AlphaProof Nexus 500+ theorems)

### Output
- Type registries
- Proof certificates
- Cross-domain mappings
- Portable proof representations

### Actions

#### 1. Create Domain-Specific Registries

**Pattern**: Each domain gets its own TypeRegistry that maps domain concepts to EML trees.

```lean
-- Example: CayleyDickson.lean
namespace CayleyDickson

def cdRegistry : TypeRegistry 5 := {
  toTree := ![  -- 5 dimensions: Real, Complex, Quaternion, Octonion, Sedenion
    .Leaf,  -- Real (n=0: 2^0 = 1 dimension)
    .Node .Leaf .Leaf,  -- Complex (n=1: 2^1 = 2 dimensions)
    .Node (.Node .Leaf .Leaf) (.Node .Leaf .Leaf),  -- Quaternions (n=2)
    -- ... Octonions, Sedenions
  ]
  injective := by decide
}

lemma cdRegistry_size_doubles (n : Nat) (h : n < 5) :
    (cdRegistry.toTree ⟨n, h⟩).size = 2^n - 1 := by
  fin_cases n <;> rfl

end CayleyDickson
```

#### 2. Extract Proof Trees from AlphaProof Nexus

**Pattern**: Parse AlphaProof Lean files and convert proof structure to EML trees.

```lean
namespace AlphaProofIntegration

-- Proof construction operations
inductive ProofTree (α : Type) where
  | Goal : α → ProofTree α
  | Apply : ProofTree α → String → ProofTree α
  | Exact : α → ProofTree α
  | Assume : String → ProofTree α
  | Sequence : ProofTree α → ProofTree α → ProofTree α
  | Branch : ProofTree α → ProofTree α → ProofTree α
  | Case : String → ProofTree α → ProofTree α
  | Induction : String → ProofTree α → ProofTree α

-- Convert to EMLTree (forgets types, keeps structure)
def proofTreeToEML : ProofTree α → EMLTree
  | .Goal _ => .Leaf
  | .Apply t _ => .Node .Leaf (proofTreeToEML t)
  | .Exact _ => .Leaf
  | .Assume _ => .Leaf
  | .Sequence l r => .Node (proofTreeToEML l) (proofTreeToEML r)
  | .Branch l r => .Node (proofTreeToEML l) (proofTreeToEML r)
  | .Case _ t => .Node .Leaf (proofTreeToEML t)
  | .Induction _ t => .Node .Leaf (proofTreeToEML t)

end AlphaProofIntegration
```

#### 3. Build Theorem Registry

```lean
namespace AlphaProofIntegration

structure IndexedTheorem where
  id : String
  name : String
  statement : Prop
  proofFile : String
  proofTree : ProofTree Prop
  emlTree : EMLTree
  source : String  -- "OEIS", "Erdos", "Stacks", "AICollaborator"

def buildAPNRegistry (theorems : List IndexedTheorem) : TypeRegistry theorems.length where
  toTree i := (theorems.get ⟨i, by omega⟩).emlTree
  injective := by
    intro i j h
    -- Prove that equal EML trees imply equal proof structures
    sorry

end AlphaProofIntegration
```

#### 4. Generate Cortex Certificates

```lean
namespace AlphaProofIntegration

def generateCertificate
    (reg : TypeRegistry N)
    (theorem : IndexedTheorem)
    (observed : EMLTree) :
    Option (CortexCertificate reg i observed) :=
  reg.fromTree observed |>.map fun i => {
    registeredType := reg.toTree i
    quenchWitness := by
      -- The observed tree contracts to the registered type
      -- This uses contracts_to_rightComb and transitivity
      sorry
  }

end AlphaProofIntegration
```

#### 5. Establish Cross-Domain Mappings

**Pattern**: Prove that EML trees from different domains are in the same Tamari equivalence class.

```lean
namespace CrossDomain

-- Example: Number theory proof maps to nuclear configuration
example : contracts_to oeis_A258667_tree nuclear_configuration_tree := by
  -- Both trees contract to the same right-comb normal form
  have h1 : contracts_to oeis_A258667_tree (rightComb oeis_A258667_tree.size) :=
    contracts_to_rightComb _
  have h2 : contracts_to nuclear_configuration_tree (rightComb nuclear_configuration_tree.size) :=
    contracts_to_rightComb _
  -- If they have the same size and both contract to right-comb, they're in the same component
  sorry

end CrossDomain
```

### Tools
- Finset operations for registry construction
- Pattern matching for proof tree extraction
- Tamari lattice properties for equivalence proofs

### Success Criteria
- Registries compile and are injective
- Certificates can be generated for observed types
- Cross-domain mappings are proven
- Results are portable (can be used in new contexts)

---

## Complete Workflow Example

### Goal: Prove contracts_to_rightComb and integrate with AlphaProof Nexus

```
Phase 1: PARSE
├── Input: topological_isomer_hypothesis.md
├── Input: docs/TIME_LIKE_DIMENSIONS.md
└── Output: Problem statement - "Prove every tree contracts to right-comb"

Phase 2: EXTRACT
├── Core types: EMLTree, contracts_to, rightComb
├── Invariants: size_invariant
├── Composition lemma: node_of_rightCombs_contracts_to_rightComb (IDENTIFIED)
└── Main theorem: contracts_to_rightComb

Phase 3: FORMALIZE
├── File: EMLRegistry.lean (already exists)
├── Add: node_of_rightCombs_contracts_to_rightComb lemma
├── Update: contracts_to_rightComb proof to use the lemma
└── Create: TamariTime.lean with temporal metrics

Phase 4: VALIDATE
├── Prove: node_of_rightCombs_contracts_to_rightComb (induction on a)
├── Prove: contracts_to_rightComb (using the lemma)
├── Remove: Classical.decidable dependency (optional, use BFS)
└── Verify: lake build passes

Phase 5: INTEGRATE
├── Create: TamariTime.lean with proven temporal properties
├── Create: APNRegistry.lean with AlphaProof theorem extraction
├── Create: CayleyDickson.lean with CD hierarchy
├── Create: NuclearRegistry.lean with isomer mappings
└── Create: PORTABILITY.md documenting cross-domain equivalences
```

---

## Quality Gates (from AlphaProof Nexus)

### Gate 1: Compilation
- File compiles with `lake env lean <file>`
- No type errors
- All imports resolved

### Gate 2: Proof Completeness
- Zero sorries in target scope
- Only standard axioms used
- All theorem statements preserved

### Gate 3: Proof Quality
- Prefer direct proofs over automation where clarity improves
- Use appropriate automation level
- Document non-trivial proof steps

### Gate 4: Integration
- Results are reusable
- Registries are injective
- Certificates are generatable

---

## Automation Tactics Reference

| Tactic | When to Use | Example |
|--------|-------------|---------|
| `rfl` | Definitional equality | `exact rfl` |
| `simp` | Simplify with lemmas | `simp [Nat.add_comm]` |
| `ring` | Ring equalities | `ring` |
| `linarith` | Linear arithmetic | `linarith` |
| `nlinarith` | Nonlinear arithmetic | `nlinarith` |
| `omega` | Nat arithmetic | `omega` |
| `exact?` | Find exact proof | `exact?` |
| `apply?` | Find applicable lemma | `apply?` |
| `grind` | SMT-style automation | `grind` |
| `aesop` | Automated search | `aesop` |
| `delta` | Unfold definition | `delta helper` |
| `norm_num` | Normalize numbers | `norm_num` |
| `push_cast` | Push casts | `push_cast` |
| `rw` | Rewrite | `rw [lemma]` |

---

## Common Patterns in AlphaProof Proofs

### Pattern 1: Unfold + Normalize + Simplify
```lean
lemma helper : ... := by
  delta definition
  norm_num[...]
  simp [...]
```

### Pattern 2: Induction with Automation
```lean
lemma helper : ... := by
  induction n with
  | zero => simp [...]
  | succ n ih =>
      simp [*]
      aesop
```

### Pattern 3: Rewrite + Arithmetic
```lean
lemma helper : ... := by
  rw [key_equality]
  ring
```

### Pattern 4: Heavy Automation
```lean
lemma helper : ... := by
  aesop
```

### Pattern 5: Congruence + Transitivity
```lean
lemma helper : ... := by
  have h1 : ... := lemma1
  have h2 : ... := lemma2
  exact h1.trans h2
```

---

## Resource Management

From AlphaProof Nexus, use these settings for complex proofs:

```lean
set_option maxHeartbeats 200000
set_option maxRecDepth 4000
set_option synthInstance.maxHeartbeats 20000
set_option synthInstance.maxSize 128
```

For very complex proofs, consider:
- Breaking into smaller lemmas
- Using `set_option maxHeartbeats 0` (unlimited)
- Increasing `maxRecDepth` further

---

## Template Files

### Template: New Theorem File
```lean
/- Copyright notice -/

import LaserCortex.EMLRegistry

set_option maxHeartbeats 200000
set_option maxRecDepth 4000

open Nat

namespace NewDomain

-- Definitions

-- Helper lemmas

-- Main theorems

end NewDomain
```

### Template: Registry File
```lean
import LaserCortex.EMLRegistry

namespace DomainRegistry

def registry : TypeRegistry N := {
  toTree := ![
    -- List of EML trees
  ]
  injective := by decide
}

-- Properties of the registry

end DomainRegistry
```

---

## Success Metrics

| Metric | Target | Current (EMLRegistry) |
|--------|--------|----------------------|
| Sorries | 0 | 1 (contracts_to_rightComb) |
| Compilation | Pass | Needs Mathlib |
| Integration | Full | Partial |
| Portability | 500+ theorems | 0 |

---

## Next Steps (Immediate)

1. **Apply this skill to prove `node_of_rightCombs_contracts_to_rightComb`**
2. **Complete `contracts_to_rightComb`**
3. **Remove Classical.decidable dependency** (implement BFS for decidable_contracts_to)
4. **Create TamariTime.lean** with temporal metrics
5. **Begin AlphaProof Nexus integration**

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-06 | Mistral Vibe | Initial creation from AlphaProof Nexus analysis |

**Status**: Active Skill  
**Next Review**: After Phase 4 completion (contracts_to_rightComb proven)  
**Dependencies**: AlphaProof Nexus corpus analysis
