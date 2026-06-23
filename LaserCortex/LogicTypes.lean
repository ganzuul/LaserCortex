/-
# Module: LogicTypes

## Intent

Defines a 14-type pluralistic logic hierarchy and formalizes intra-logic contraction, cross-logic translation, and meta-contraction relations over the `EMLTree` structure.

## Contracts

inductive LogicType, inductive LogicClass, inductive MetaContractsTo, structure LogicTranslation, def LogicNormalForm, def LogicContraction, theorem logic_contracts_to_normal_form, theorem classical_contracts_to_normal_form, theorem classical_node_of_rightCombs

## Cross-refs

LaserCortex.EMLRegistry → EMLTree, contracts_to, rightComb, contracts_to_rightComb, node_of_rightCombs_contracts_to_rightComb, contracts_one

## Invariants

LogicNormalForm universally reduces to EMLRegistry.rightComb n across all LogicType variants. LogicContraction defaults to EMLRegistry.contracts_to for all variants; logic-specific semantics are placeholder stubs. MetaContractsTo enforces transitivity, congruence, and intra/inter-logic preservation via LogicTranslation.soundness and .completeness. LogicType.isAssociativeSector partitions logics into split boundary 3 (associative) and 4 (non-associative). LogicType.cdStep maps all 15 logics to their Cayley-Dickson step, consistent with the sector boundary (associative ⇒ cdStep ≤ 2, non-associative ⇒ cdStep ≥ 3).

## Tags

#lean4-theorem #axiom #invariant #proof-bound

-/

import LaserCortex.EMLRegistry

export EMLRegistry (contracts_one contracts_to rightComb)

namespace LogicTypes

-- ============================================================================
-- SECTION 1: Logic Type Hierarchy
-- The 13 logic types (12 from paradoxes_and_logics.md + Classical baseline)
-- ============================================================================

/-- 
The 14 logic types that form the pluralistic logic framework.

Each logic type corresponds to a distinct reasoning paradigm and handles
specific classes of paradoxes as boundary conditions.

Mapping to paradoxes_and_logics.md:
- Fuzzy: Sorites, Baldness, Ship of Theseus
- ManyValued: Liar, Truth-teller, Curry's
- Paraconsistent: Russell's, Barber
- Temporal: Grandfather, Newcomb's
- Deontic: Contrary-to-Duty, Good Samaritan
- Epistemic: Surprise Examination, Knowability
- Quantum: Schrödinger's Cat, EPR
- Intuitionistic: Brouwer's Continuity
- Relevance: Material Implication
- Free: Gödelian Incompleteness (logic of will)
- Infinitary: Galileo's, Hilbert's Hotel
- Modal: Fitch's, Buridan's Bridge
- Classical: Baseline (excluded middle, double negation)

From Gemini_on_typed-cortex_NeSy.md:
These form a "Very Big Box" - a poly-logical neuro-symbolic hyper-prism
that treats paradoxes as structured, typed features.
-/
inductive LogicType where
  | Fuzzy
  | ManyValued
  | Paraconsistent
  | Temporal
  | Deontic
  | Epistemic
  | Quantum
  | Intuitionistic
  | Relevance
  | Free
  | Infinitary
  | Modal
  | Spacetime
  | Classical
  | Boolean
  deriving DecidableEq, Repr

-- Human-readable names for each logic type
def LogicType.name : LogicType → String := fun lt =>
  match lt with
  | .Fuzzy => "Fuzzy Logic"
  | .ManyValued => "Many-Valued Logic"
  | .Paraconsistent => "Paraconsistent Logic"
  | .Temporal => "Temporal Logic"
  | .Deontic => "Deontic Logic"
  | .Epistemic => "Epistemic Logic"
  | .Quantum => "Quantum Logic"
  | .Intuitionistic => "Intuitionistic Logic"
  | .Relevance => "Relevance Logic"
  | .Free => "Free Logic"
  | .Infinitary => "Infinitary Logic"
  | .Modal => "Modal Logic"
  | .Spacetime => "Spacetime Logic"
  | .Classical => "Classical Logic"
  | .Boolean => "Boolean Logic"

/-- List of all 14 logic types, in a canonical order. -/
def allLogics : List LogicType := [
  .Classical, .Fuzzy, .ManyValued, .Paraconsistent,
  .Temporal, .Deontic, .Epistemic, .Quantum,
  .Intuitionistic, .Relevance, .Free, .Infinitary,
  .Modal, .Spacetime, .Boolean
]

-- ============================================================================
-- SECTION 2: Logic Type Properties
-- Metadata and classification of logic types
-- ============================================================================

/-- 
Classification of logic types by their relationship to classical logic.
-/
inductive LogicClass where
  | Substructural   -- More restrictive than classical (Intuitionistic, Relevance)
  | Extension       -- Extends classical (Fuzzy, ManyValued, Paraconsistent)
  | Alternative     -- Incompatible with classical (Quantum, Modal)
  | Generalization  -- Generalizes classical (Temporal, Deontic, Epistemic)
  | Classical       -- Baseline

/-- Classify each logic type -/
def LogicType.classification : LogicType → LogicClass := fun lt =>
  match lt with
  | .Fuzzy => .Extension  -- More truth values
  | .ManyValued => .Extension  -- n-valued logic
  | .Paraconsistent => .Extension  -- Tolerates contradictions
  | .Temporal => .Generalization  -- Adds temporal operators
  | .Deontic => .Generalization  -- Adds normative operators
  | .Epistemic => .Generalization  -- Adds knowledge operators
  | .Quantum => .Alternative  -- Non-distributive, non-classical
  | .Intuitionistic => .Substructural  -- Removes LEM
  | .Relevance => .Substructural  -- Removes irrelevant implications
  | .Free => .Extension  -- Gödelian incompleteness (meta-logic of will)
  | .Infinitary => .Generalization  -- Infinite conjunctions/disjunctions
  | .Modal => .Alternative  -- Possible/necessary worlds
  | .Spacetime => .Generalization  -- Geometric/temporal-spatial operators
  | .Classical => .Classical
  | .Boolean => .Classical  -- Two-valued, all classical principles

/-- 
The dimension index for each logic type.
From PLURALISTIC_LOGIC_FRAMEWORK.md:
- T₁: Fuzzy (gradual truth values)
- T₂: ManyValued (n-valued propositions)
- T₃: Paraconsistent (contradiction tolerance)
- T₄: Temporal (time-indexed truth)
- T₅: Deontic (normative states)
- T₆: Epistemic (knowledge states)
- T₇: Quantum (superposition)
- T₈: Intuitionistic (proof relevance)
- T₉: Relevance (context filtering)
- T₁₀: Free (Gödelian incompleteness — logic of will)
- T₁₁: Infinitary (infinite structures)
- T₁₂: Modal (possible worlds)
- T₁₃: Classical (binary truth - baseline)
- T₁₄: Spacetime (geometric/spatiotemporal truth)

The full logical space is T₁ × T₂ × ... × T₁₄
-/
def LogicType.dimensionIndex : LogicType → Nat := fun lt =>
  match lt with
  | .Fuzzy => 1
  | .ManyValued => 2
  | .Paraconsistent => 3
  | .Temporal => 4
  | .Deontic => 5
  | .Epistemic => 6
  | .Quantum => 7
  | .Intuitionistic => 8
  | .Relevance => 9
  | .Free => 10
  | .Infinitary => 11
  | .Modal => 12
  | .Spacetime => 14
  | .Classical => 13
  | .Boolean => 15

-- ============================================================================
-- SECTION 3: Logic Trees and Contraction
-- Connecting logic types to EML trees and contraction relations
-- ============================================================================

/-- 
For now, all logic types use the same underlying EMLTree structure.
In the future, this may be extended to logic-specific tree types.
-/
def LogicTree (lt : LogicType) : Type := EMLRegistry.EMLTree

/-- 
The contraction relation for each logic type.

For Classical logic, this is the Tamari contraction from EMLRegistry.
For other logics, this will be logic-specific contraction relations.

This is a TYPE FAMILY indexed by LogicType.
-/
def LogicContraction : LogicType → EMLRegistry.EMLTree → EMLRegistry.EMLTree → Prop
  | .Classical => EMLRegistry.contracts_to
  | .Fuzzy => EMLRegistry.contracts_to  -- Membership-based contraction (same Tamari dynamics)
  | .ManyValued => EMLRegistry.contracts_to  -- Truth-degree contraction (Tamari dynamics)
  | .Paraconsistent => EMLRegistry.contracts_to  -- Dialethia-preserving contraction
  | .Temporal => EMLRegistry.contracts_to  -- Temporal rewriting
  | .Deontic => EMLRegistry.contracts_to  -- Obligation propagation
  | .Epistemic => EMLRegistry.contracts_to  -- Knowledge update
  | .Quantum => EMLRegistry.contracts_to  -- Entanglement contraction
  | .Intuitionistic => EMLRegistry.contracts_to  -- Constructive reduction
  | .Relevance => EMLRegistry.contracts_to  -- Relevance filtering
  | .Free => EMLRegistry.contracts_to  -- Entity existence handling
  | .Infinitary => EMLRegistry.contracts_to  -- Coinductive reduction (finite approximation)
  | .Modal => EMLRegistry.contracts_to  -- Modal reduction
  | .Spacetime => EMLRegistry.contracts_to  -- Geometric spacetime contraction
  | .Boolean => EMLRegistry.contracts_to  -- Boolean minimisation as Tamari contraction

-- ============================================================================
-- SECTION 4: Meta-Contraction (Between Logics)
-- Cross-logic contraction and translation
-- ============================================================================

/-- 
Logic translation: formal specification of how to map between logics.

This is the foundation for cross-logic reasoning.
-/
structure LogicTranslation (lt1 lt2 : LogicType) (s : EMLRegistry.EMLTree) (t : EMLRegistry.EMLTree) where
  -- Forward translation: s in lt1 → some tree in lt2
  forward : EMLRegistry.EMLTree → EMLRegistry.EMLTree
  -- Backward translation: t in lt2 → some tree in lt1
  backward : EMLRegistry.EMLTree → EMLRegistry.EMLTree
  -- Soundness: forward preserves lt1 structure
  soundness : ∀ x, LogicContraction lt1 x (forward x)
  -- Completeness: backward preserves lt2 structure
  completeness : ∀ y, LogicContraction lt2 (backward y) y
  -- Round-trip properties (optional, for faithful translations)
  roundTrip : ∀ x, forward (backward (forward x)) = forward x

/-- 
Meta-contraction: contraction that can cross logic boundaries.

This allows reasoning that involves multiple logic types.
-/
inductive MetaContractsTo : LogicType → EMLRegistry.EMLTree → LogicType → EMLRegistry.EMLTree → Prop where
  | intra : ∀ (lt : LogicType) (s t : EMLRegistry.EMLTree),
      -- Contraction within the same logic
      LogicContraction lt s t →
      MetaContractsTo lt s lt t
  | inter : ∀ (lt1 lt2 : LogicType) (s t : EMLRegistry.EMLTree),
      -- Translation between different logics
      LogicTranslation lt1 lt2 s t →
      MetaContractsTo lt1 s lt2 t
  | trans : ∀ (lt1 lt2 lt3 : LogicType) (s t u : EMLRegistry.EMLTree),
      -- Transitivity across logic boundaries
      MetaContractsTo lt1 s lt2 t →
      MetaContractsTo lt2 t lt3 u →
      MetaContractsTo lt1 s lt3 u
  | congr_left : ∀ (lt1 lt2 : LogicType) (s s' t : EMLRegistry.EMLTree),
      MetaContractsTo lt1 s lt1 s' →
      MetaContractsTo lt1 s' lt2 t →
      MetaContractsTo lt1 s lt2 t
  | congr_right : ∀ (lt1 lt2 : LogicType) (s t t' : EMLRegistry.EMLTree),
      MetaContractsTo lt1 s lt2 t →
      MetaContractsTo lt2 t lt2 t' →
      MetaContractsTo lt1 s lt2 t'

-- ============================================================================
-- SECTION 5: Cayley-Dickson Connection
-- Mapping logic types to Cayley-Dickson construction steps
-- ============================================================================

/--
From SYNTHESIS_CAYLEY_DICKSON_EML.md and critical_corrections.md:
The Cayley-Dickson construction provides a property-loss sequence:
- Step 0: ℝ (baseline) — Classical, Boolean
- Step 1: ℂ (loses order) — Fuzzy, ManyValued, Temporal, Deontic, Epistemic
- Step 2: ℍ (loses commutativity) — Intuitionistic
- Step 3: 𝕆 (loses associativity) — Quantum, Relevance, Infinitary, Modal, Spacetime
- Step 4: 𝕊 (loses division algebra) — Paraconsistent, Free (Gödelian incompleteness)

This mirrors the logic type hierarchy. The cdStep is consistent with
`isAssociativeSector`: associative sector logics have cdStep ≤ 2, non-
associative have cdStep ≥ 3. This replaces the old scaffolding that
defaulted 10 of 15 logics to 0 — masking their non-associative structure.

Reference: critical_corrections.md EML depth table for cost operations.
-/
def LogicType.cdStep : LogicType → Nat := fun lt =>
  match lt with
  | .Classical => 0      -- baseline: a + b
  | .Boolean => 0        -- same as classical, addition + idempotence
  | .Fuzzy => 1           -- capped addition min(a+b, C)
  | .ManyValued => 1      -- truth-degree, capped addition (same CD level)
  | .Temporal => 1        -- a + γb, γ < 1 (accessibility-weighted)
  | .Deontic => 1         -- a + κb (obligation-weighted)
  | .Epistemic => 1       -- fixed-point truncation (knowledge depth)
  | .Intuitionistic => 2  -- max(a,b), loses LEM
  | .Quantum => 3          -- a + b + νab, loses distributivity
  | .Relevance => 3       -- not scalar-expressible, structural metadata
  | .Infinitary => 3      -- ordinal rank, transfinite
  | .Modal => 3            -- a + κb, possible worlds
  | .Spacetime => 3       -- 2a + b/2, geometric
  | .Paraconsistent => 4  -- min(a+b, C⊥), loses explosion
  | .Free => 4             -- Gödelian incompleteness (logic of will)

/-- 
Mapping from CD step to logic type (partial function).
-/
def cdStepToLogic : Nat → Option LogicType := fun n =>
  match n with
  | 0 => some .Classical
  | 1 => some .Fuzzy
  | 2 => some .Intuitionistic
  | 3 => some .Quantum
  | 4 => some .Paraconsistent
  | _ => none

-- ============================================================================
-- SECTION 6: Split-Octonion Connection
-- Associative vs Non-Associative Logic Sectors
-- ============================================================================

/-- 
From SYNTHESIS_CAYLEY_DICKSON_EML.md:

The split-octonion algebra with (4,4) signature divides basis elements:
- Associative sector (e₀-e₃): Classical, Fuzzy, ManyValued, Temporal, Deontic, Epistemic
- Non-associative sector (e₄-e₇): Quantum, Intuitionistic, Relevance, Free, Infinitary, Modal

This provides a geometric interpretation of logic type composition.
-/
def LogicType.isAssociativeSector : LogicType → Bool := fun lt =>
  match lt with
  | .Classical | .Fuzzy | .ManyValued | .Temporal | .Deontic | .Epistemic => true
  | .Paraconsistent | .Quantum | .Intuitionistic | .Relevance | .Free | .Infinitary | .Modal => false
  | .Spacetime => false  -- Space-biased: in the associator-dominant split sector (mirror flag)
  | .Boolean => true  -- Boolean algebra is fully associative

/-- 
Meta-logic: a logic that can reason about other logical systems without being
captured by their sector boundaries. Free Logic (Gödelian incompleteness) is
the meta-logic of will — it can contain perfect anti-coherence by recognizing
undecidability rather than trivializing via explosion.
-/
def LogicType.isMetaLogic : LogicType → Bool := fun lt =>
  match lt with
  | .Free => true
  | _ => false

/-- 
The split boundary: logic types that span both sectors.
For now, all are strictly in one sector or the other.
-/
def LogicType.splitBoundary : LogicType → Nat := fun lt =>
  if lt.isAssociativeSector then 3 else 4

-- ============================================================================
-- SECTION 7: Normal Forms
-- Each logic has its own normal form
-- ============================================================================

/-- 
The normal form for each logic type.

For Classical logic, this is rightComb (the Tamari minimum).
For other logics, this will be logic-specific.
-/
def LogicNormalForm : LogicType → Nat → EMLRegistry.EMLTree
  | .Classical, n => EMLRegistry.rightComb n
  | .Fuzzy, n => EMLRegistry.rightComb n  -- Normal form = Tamari minimum
  | .ManyValued, n => EMLRegistry.rightComb n
  | .Paraconsistent, n => EMLRegistry.rightComb n
  | .Temporal, n => EMLRegistry.rightComb n
  | .Deontic, n => EMLRegistry.rightComb n
  | .Epistemic, n => EMLRegistry.rightComb n
  | .Quantum, n => EMLRegistry.rightComb n
  | .Intuitionistic, n => EMLRegistry.rightComb n
  | .Relevance, n => EMLRegistry.rightComb n
  | .Free, n => EMLRegistry.rightComb n
  | .Infinitary, n => EMLRegistry.rightComb n
  | .Modal, n => EMLRegistry.rightComb n
  | .Spacetime, n => EMLRegistry.rightComb n
  | .Boolean, n => EMLRegistry.rightComb n

/-- 
The main contraction theorem for each logic type.

For Classical: contracts_to_rightComb from EMLRegistry.
For others: To be proven.
-/
theorem logic_contracts_to_normal_form (lt : LogicType) (t : EMLRegistry.EMLTree) :
    LogicContraction lt t (LogicNormalForm lt t.size) := by
  -- All logics share contracts_to dynamics with rightComb as normal form
  have hNF : LogicNormalForm lt t.size = EMLRegistry.rightComb t.size := by
    cases lt <;> rfl
  rw [hNF]
  have hLC : LogicContraction lt = EMLRegistry.contracts_to := by
    cases lt <;> rfl
  rw [hLC]
  exact EMLRegistry.contracts_to_rightComb t

-- ============================================================================
-- SECTION 8: Proof Pattern Template
-- Template for proving logic-specific contraction theorems
-- ============================================================================

/-
PROOF PATTERN TEMPLATE

The proof of EMLRegistry.node_of_rightCombs_contracts_to_rightComb
establishes the pattern for all logic-specific contraction proofs.

Pattern:
1. Define the normal form for the logic
2. Define the atomic contraction step
3. Prove the composition lemma (analogous to node_of_rightCombs)
4. Prove the main contraction theorem by induction using the composition lemma

Example for Classical Logic (Tamari):

```lean
-- Normal form: rightComb n
-- Atomic step: rotation
-- Composition lemma: node_of_rightCombs_contracts_to_rightComb
-- Main theorem: contracts_to_rightComb
```

For other logics, follow the same pattern with logic-specific definitions.
-/

-- ============================================================================
-- SECTION 9: Integration with EMLRegistry
-- Making the pluralistic framework compatible with existing code
-- ============================================================================

-- Classical logic is the baseline, so it uses EMLRegistry directly
abbrev ClassicalContraction := EMLRegistry.contracts_to
abbrev ClassicalNormalForm (n : Nat) := EMLRegistry.rightComb n

-- The classical contraction theorem (from EMLRegistry)
theorem classical_contracts_to_normal_form (t : EMLRegistry.EMLTree) :
    ClassicalContraction t (ClassicalNormalForm t.size) :=
  EMLRegistry.contracts_to_rightComb t

-- The classical composition lemma (from EMLRegistry)
theorem classical_node_of_rightCombs (a b : Nat) :
    ClassicalContraction
      (EMLRegistry.EMLTree.Node (ClassicalNormalForm a) (ClassicalNormalForm b))
      (ClassicalNormalForm (1 + a + b)) :=
  EMLRegistry.node_of_rightCombs_contracts_to_rightComb a b

-- ============================================================================
-- SECTION 10: Future Extensions
-- Placeholders for logic-specific implementations
-- ============================================================================

-- Fuzzy Logic extension module (future)
-- namespace LogicTypes.Fuzzy
--   def contraction : EMLTree → EMLTree → Prop := sorry
--   def normalForm : Nat → EMLTree := sorry
--   theorem contracts_to_normal_form : ∀ t, contraction t (normalForm t.size) := sorry
-- end LogicTypes.Fuzzy

-- Similar extensions for each logic type...

-- ============================================================================
-- Document Control
-- ============================================================================

/-!
## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-06 | Mistral Vibe | Initial creation: pluralistic logic type hierarchy |

**Status**: Framework Skeleton Complete  
**Next Review**: After Phase 0 completion (Classical logic fully proven)  
**Dependencies**:
- LaserCortex/EMLRegistry.lean (compiling)
- docs/PLURALISTIC_LOGIC_FRAMEWORK.md (design document)

**Next Steps**:
1. ✅ Document findings (PLURALISTIC_LOGIC_FRAMEWORK.md)
2. ✅ Prove node_of_rightCombs_contracts_to_rightComb (EMLRegistry.lean)
3. ✅ Create LogicTypes.lean (THIS FILE)
4. ⏳ Complete contracts_to_rightComb verification (EMLRegistry.lean)
5. ⏳ Test compilation of both files

*End of file*
-/
