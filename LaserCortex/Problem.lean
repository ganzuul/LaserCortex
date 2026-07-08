import LaserCortex.LogicTypes
import LaserCortex.foundations.Tamari

/-!
# Problem Types (Staging Port)

Minimal port of `Problem.lean` using `Tamari.EMLTree` instead of
`EMLRegistry.EMLTree`. Only the types actually needed by the staging
`Generation.lean` are ported here.

## Key definitions
- `ProblemClass` — 13 paradox classes, each with a native logic type
- `Problem` — a problem with tree/normalForm over Tamari.EMLTree
- `WrappedProblem` — logic-specific resolution of a problem
- `Tower` — layered sequence of wrapped problems

## Cross-refs
- `LogicTypes` → LogicType (standalone inductive, no EMLTree dependency)
- `staging/Tamari` → EMLTree, rightComb, contracts_to
-/

open LogicTypes

-- ============================================================================
-- SECTION 1: ProblemClass — the 13 paradox classes
-- ============================================================================

/--
A class of paradoxes sharing a common structural pattern.
Each maps to a native logic type (the one best suited to resolve it),
but can be addressed by multiple logics.

This is an exact port of `ProblemTypes.ProblemClass` from the old core,
using only `LogicType` (which has no EMLTree dependency).
-/
inductive ProblemClass : Type where
  | selfReference       -- Liar, Truth-teller, Curry's (native: ManyValued)
  | vagueness           -- Sorites, Ship of Theseus (native: Fuzzy)
  | inconsistentDef     -- Russell's, Barber (native: Paraconsistent)
  | temporalDecision    -- Grandfather, Newcomb's (native: Temporal)
  | deontic             -- Contrary-to-Duty (native: Deontic)
  | epistemic           -- Surprise Examination (native: Epistemic)
  | quantumSuperposition -- Schrödinger's Cat (native: Quantum)
  | constructive        -- Brouwer's Continuity (native: Intuitionistic)
  | relevance           -- Material Implication (native: Relevance)
  | emptyReference      -- Free Logic / Gödelian (native: Free)
  | infinity            -- Galileo's, Hilbert's Hotel (native: Infinitary)
  | modality            -- Fitch's Knowability (native: Modal)
  | metaParadox         -- missing proof / incomplete framework (native: Classical)
  deriving DecidableEq, Repr

/--
The native logic type for each problem class: the logic best suited to
resolve paradoxes of that class (the anti-coherent pole in Generation.lean).
-/
def nativeLogicOf (pc : ProblemClass) : LogicType :=
  match pc with
  | .selfReference       => .ManyValued
  | .vagueness           => .Fuzzy
  | .inconsistentDef     => .Paraconsistent
  | .temporalDecision    => .Temporal
  | .deontic             => .Deontic
  | .epistemic           => .Epistemic
  | .quantumSuperposition => .Quantum
  | .constructive        => .Intuitionistic
  | .relevance           => .Relevance
  | .emptyReference      => .Free
  | .infinity            => .Infinitary
  | .modality            => .Modal
  | .metaParadox         => .Classical

/--
Inverse: find the problem class (if any) whose native logic is the given one.
For non-native logics (e.g., Classical, which is the coherent pole for many),
returns `none`.
-/
def findProblemClass (lt : LogicType) : Option ProblemClass :=
  match lt with
  | .ManyValued     => some .selfReference
  | .Fuzzy          => some .vagueness
  | .Paraconsistent => some .inconsistentDef
  | .Temporal       => some .temporalDecision
  | .Deontic        => some .deontic
  | .Epistemic      => some .epistemic
  | .Quantum        => some .quantumSuperposition
  | .Intuitionistic => some .constructive
  | .Relevance      => some .relevance
  | .Free           => some .emptyReference
  | .Infinitary     => some .infinity
  | .Modal          => some .modality
  | _               => none

/-- The list of suitable logics for each problem class (from old Problem.lean). -/
def suitableLogicsOf (pc : ProblemClass) : List LogicType :=
  match pc with
  | .selfReference       => [.ManyValued, .Classical, .Paraconsistent]
  | .vagueness           => [.Fuzzy, .Classical, .ManyValued]
  | .inconsistentDef     => [.Paraconsistent, .Classical, .Free]
  | .temporalDecision    => [.Temporal, .Classical, .Paraconsistent, .Intuitionistic, .Quantum, .ManyValued, .Modal]
  | .deontic             => [.Deontic, .Classical, .Modal]
  | .epistemic           => [.Epistemic, .Classical, .Modal]
  | .quantumSuperposition => [.Quantum, .Classical, .Intuitionistic]
  | .constructive        => [.Intuitionistic, .Classical]
  | .relevance           => [.Relevance, .Classical]
  | .emptyReference      => [.Free, .Classical]
  | .infinity            => [.Infinitary, .Classical]
  | .modality            => [.Modal, .Classical]
  | .metaParadox         => [.Classical]

-- ============================================================================
-- SECTION 2: Problem — tree + normal form over Tamari.EMLTree
-- ============================================================================

/--
A problem is defined by its class, a name, a list of suitable logics,
a tree function (logic → EMLTree), and a normal form function.
This is a port of `ProblemTypes.Problem` using `Tamari.EMLTree`.

Note: `name` and `suitableLogics` are for display/metadata; the core
structure is the tree and its normal form.
-/
structure Problem where
  cls : ProblemClass
  name : String
  suitableLogics : List LogicType
  tree : LogicType → EMLTree
  normalForm : LogicType → EMLTree

/--
A logic-specific resolution of a problem.
- `tree`: the problem's tree for this logic type
- `target`: the normal form for this logic type
- `cost`: the Lagrangian cost (friction density at cdStep)
- `proof`: proof that the tree contracts to target

Note: The proof uses `Tamari.contracts_to` rather than the old core's
`LogicContraction` (which was just an alias for `contracts_to` anyway).
-/
structure WrappedProblem (p : Problem) (lt : LogicType) where
  tree : EMLTree
  target : EMLTree
  cost : ℕ
  proof : contracts_to tree target

/--
A tower of wrapped problems: one layer per suitable logic type.
-/
structure Tower (p : Problem) where
  layers : List (Σ lt : LogicType, WrappedProblem p lt)
