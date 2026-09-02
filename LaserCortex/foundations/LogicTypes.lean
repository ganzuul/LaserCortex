/-
# Module: LogicTypes (rescued enum)

## Intent

The 15 named logic types. Restored from `_archive/lean_old/LogicTypes.lean`
(deleted from the live tree June 25, `9d2b01d`-era; found alive only in the
Python mirror `infra/_cortex/_logic_types.py`) per the archaeology triage
062 §5.7(a). Only the `LogicType` enum is rescued — the archived file's
translation/normal-form machinery (`LogicClass`, `LogicTranslation`,
`MetaContractsTo`) stays archived; none of its cited lemmas depended on
them, and reviving unverified scaffolding is what the triage rule forbids.

## Contracts

[LogicType]

## Cross-refs

`LaserCortex.foundations.Cost` (the NodeCost table indexed by this enum),
notes 006/007, `TDD_SPLIT_OCTONION_LOGIC.md`

## Tags

#lean4-definition #invariant
-/

namespace LogicTypes

/-- The 15 named logics whose cost geometry is tabulated in `Cost.nodeParam`.
    Order is historical (archived LogicTypes.lean); the collapse count in
    `Cost` (8 classes, not the archived 7) supersedes note 006's headline. -/
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

end LogicTypes
