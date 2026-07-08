/-
# Module: LaserCortex.Problem

## Intent

Shared base types for the paradox framework: problem classes, problem
structures, wrapped problems (logic-specific resolutions), and towers
(layered sequences of wrapped problems).

Extracted from LiarParadox.lean to break the circular dependency with
FrictionLagrangian.lean — both need these types, and FrictionLagrangian
also needs to be imported by the paradox files during migration.

## Contracts

ProblemClass (13 constructors — one per logic framework family)
Problem (cls, name, suitableLogics, tree, normalForm)
WrappedProblem (tree, target, cost, proof — logic-specific resolution)
Tower (layers — sequence of logic-specific WrappedProblems)

## Cross-refs

LaserCortex.EMLRegistry → EMLTree
LaserCortex.LogicTypes → LogicType, LogicContraction

## Tags

#lean4-type #foundation #paradox-framework
-/

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes

open EMLRegistry

namespace ProblemTypes

/-- A class of paradoxes sharing a common structural pattern.
  Each maps to a native logic type (the one best suited to resolve it),
  but can be addressed by multiple logics. -/
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
  | emptyReference      -- Non-existent objects (native: Free)
  | infinity            -- Galileo's, Hilbert's Hotel (native: Infinitary)
  | modality            -- Fitch's Knowability (native: Modal)
  | metaParadox         -- Missing proof / incomplete framework (native: Classical)
  deriving DecidableEq, Repr

/-- A problem: a logical puzzle encoded as a family of trees,
  one per logic type that can resolve it.
  
  `cls` — the problem class
  `suitableLogics` — which logics can resolve this
  `tree` — the encoding in each logic (a family indexed by LogicType)
  `normalForm` — the target tree for each logic -/
structure Problem where
  cls : ProblemClass
  name : String
  suitableLogics : List LogicTypes.LogicType
  tree : LogicTypes.LogicType → EMLTree
  normalForm : LogicTypes.LogicType → EMLTree

/-- A WrappedProblem pairs a Problem with a LogicType.
  This is the WfCA collapse rule: the logic's contraction relation
  resolves the problem's superposition to a definite outcome.
  
  `tree`    — the problem as interpreted in this logic
  `target`  — the normal form under this logic
  `cost`    — pentagonator distance (Verification Gap Φ)
  `proof`   — the contraction path (placeholder until LogicContraction is defined) -/
structure WrappedProblem (p : Problem) (lt : LogicTypes.LogicType) where
  tree   : EMLTree
  target : EMLTree
  cost   : Nat
  proof  : LogicTypes.LogicContraction lt tree target

/-- A Tower is a sequence of logic-wrapped problems, each collapsing the
  output of the previous.

  The dependent pair Σ lt, WrappedProblem p lt stores each layer's
  logic type alongside its wrapped problem. -/
structure Tower (p : Problem) where
  layers : List (Σ lt : LogicTypes.LogicType, WrappedProblem p lt)

end ProblemTypes
