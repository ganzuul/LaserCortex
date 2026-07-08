# Extracted Bi-Directional Translation Claims

Source documents and their claims about cross-logic translation guarantees.

## Source: PLURALISTIC_LOGIC_FRAMEWORK.md

### MetaContractsTo (transitive, cross-logic contraction)

```
MetaContractsTo lt1 s lt2 t — "s in lt1 contracts to t in lt2"
  | intra : LogicContraction lt s t → MetaContractsTo lt s lt t
  | inter : LogicTranslation lt1 lt2 s t → MetaContractsTo lt1 s lt2 t
  | trans : MetaContractsTo lt1 s lt2 t → MetaContractsTo lt2 t lt3 u → MetaContractsTo lt1 s lt3 u
  | congr_left : MetaContractsTo lt1 s lt1 s' → MetaContractsTo lt1 s' lt2 t → MetaContractsTo lt1 s lt2 t
  | congr_right : MetaContractsTo lt1 s lt2 t → MetaContractsTo lt2 t lt2 t' → MetaContractsTo lt1 s lt2 t'
```

### LogicTranslation (soundness + completeness)

```
structure LogicTranslation (lt1 lt2 : LogicType) (s : EMLTree) (t : EMLTree) where
  forward : EMLTree → EMLTree
  backward : EMLTree → EMLTree
  soundness : ∀ x, LogicContraction lt1 x (forward x)
  completeness : ∀ y, LogicContraction lt2 (backward y) y
  roundTrip : ∀ x, forward (backward (forward x)) = forward x
```

### cdStep mapping (from LogicTypes.lean)

```
LogicType.cdStep : LogicType → Nat
  Classical, Boolean → 0
  Fuzzy, ManyValued, Temporal, Deontic, Epistemic → 1
  Intuitionistic → 2
  Quantum, Relevance, Infinitary, Modal, Spacetime → 3
  Paraconsistent, Free → 4
```

### Associative sector partition

```
isAssociativeSector : LogicType → Bool
  Sector 3 (associative): Classical, Fuzzy, ManyValued, Temporal, Deontic, Epistemic, Boolean
  Boundary: Intuitionistic (cdStep=2, non-associative)
  Sector 4 (non-associative): Quantum, Relevance, Infinitary, Modal, Spacetime,
    Paraconsistent, Free
```

## Source: Leanstral_to_mathlib.md

### Assessment of LogicTranslation soundness/completeness

> LogicTranslation.soundness / .completeness — axioms stated but never exercised
> by a theorem. These are the cross-logic translation guarantees. One theorem:
> ∀ lt1 lt2 s t, LogicTranslation lt1 lt2 s t → (contracts_to s t ↔ ...) would
> close the gap.

> MetaContractsTo — transitivity, congruence, intra/inter-logic preservation
> axioms. No theorem proves these hold for any LogicType.

### TubeCoord cd_diff claim

> tubeCoord_cd_diff — the docstring makes a substantive claim ("only on
> components, not on the CD step") that could be a formal theorem:
> tubeCoord cd t = tubeCoord cd' t when assocDefect cd = assocDefect cd'
> and leftWeight t = rightWeight t (or similar).

## Source: LogicTypes.lean (Scaffolding)

### LogicFactorization (replaces LogicTranslation)

```
def LogicFactorization (lt1 lt2 : LogicType) : Prop :=
  ∀ s t, LogicContraction lt1 s t → LogicContraction lt2 (rightComb s.size) (rightComb t.size)
```

> "When cdStep(lt2) ≤ cdStep(lt1), any contraction in lt1 factors through
> the rightComb normal form in lt2. This is the KKT multiplier analogue:
> the normal form is the optimality condition (equilibrium), and the factor-
> ization is the stationarity proof that the embedding preserves contraction."

### Pentagonal weakening mode classification

```
inductive PentagonWeakening : Type where
  | strict      -- Depth 0: identity holds (Classical, Boolean)
  | capped      -- Depth 1: failure by cap/bound/truncation (Fuzzy, Temporal, etc.)
  | lattice     -- Depth 2: failure by lattice meet/join (Intuitionistic)
  | phase       -- Depth 3: failure by non-distributive phase (Quantum, Modal, etc.)
  | explosive   -- Depth 4: failure by contradiction tolerance/undecidability (Paraconsistent, Free)
```

> "THEOREM: cdStep is derived from the pentagon weakening mode.
>  cdStep(lt) = pentagonWeakening(lt).depth"

## Source: LiarCost_Boundary.md

### Meta-logic exemption claim

> "The Very Big Box contains problems about its own incompleteness. This means:
>  Free Logic (cdStep=4) is the only logic that can host contradictions without
>  trivializing — it is the meta-logic of will."

## Source: recovery_session_transcript.jsonl (Session ses_0f6e)

### Round-trip property claim

> LogicTranslation has roundTrip: forward(backward(forward x)) = forward x
> This is the "faithful translation" guarantee — the forward image is
> invariant under the backward-then-forward cycle.

## Source: arXiv-2512.10563v3 (NormCode paper)

### Compiler completeness claim

> "Compilation ensures ... reference structure (all concepts have declared
> axes and types), resource grounding (all perceptual signs are linked), and
> working interpretation completeness (every inference has full configuration)."

> "However, compilation does not ensure ... logical soundness (dependency
> cycles are detected by the orchestrator, not the compiler)"

## Claims Matrix

| Claim | Source | Status in Scaffolding | Status in mathlib-contrib |
|-------|--------|----------------------|--------------------------|
| MetaContractsTo.trans | PLURALISTIC_LOGIC_FRAMEWORK.md | Axiom (never exercised) | Not ported |
| MetaContractsTo.congr_left | PLURALISTIC_LOGIC_FRAMEWORK.md | Axiom (never exercised) | Not ported |
| MetaContractsTo.congr_right | PLURALISTIC_LOGIC_FRAMEWORK.md | Axiom (never exercised) | Not ported |
| LogicTranslation.soundness | PLURALISTIC_LOGIC_FRAMEWORK.md | Axiom (never exercised) | Not ported |
| LogicTranslation.completeness | PLURALISTIC_LOGIC_FRAMEWORK.md | Axiom (never exercised) | Not ported |
| LogicTranslation.roundTrip | PLURALISTIC_LOGIC_FRAMEWORK.md | Axiom (never exercised) | Not ported |
| LogicFactorization | LogicTypes.lean | Theorem (proved with rfl) | Not ported |
| cdStep_eq_pentagonatorDepth | LogicTypes.lean | Theorem (native_decide) | Not ported |
| associative_sector_implies_cdStep_le_2 | LogicTypes.lean | Theorem (native_decide) | Not ported |
| cdStep_ge_3_implies_non_associative | LogicTypes.lean | Theorem (native_decide) | Not ported |
| pentagon_weakening_is_surjective | LogicTypes.lean | Theorem (native_decide) | Not ported |
| tubeCoord_cd_diff | TropicalCovector.lean | Substantive docstring claim | Not formalized as theorem |
| exists_quantized_type_of_cdStep_ne_four | Composition.lean | Opaque axiom | Opaque axiom |
| free_not_quantized | Composition.lean | Theorem (counterexample) | Theorem (counterexample) |
