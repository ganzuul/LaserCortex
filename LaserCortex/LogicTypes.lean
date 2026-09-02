/-
# Module: LogicTypes (named interpretation layer)

## Intent

The 15 named logic types. Restored from `_archive/lean_old/LogicTypes.lean`
(deleted from the live tree June 25, `9d2b01d`-era; found alive only in the
Python mirror `infra/_cortex/_logic_types.py`) per the archaeology triage
062 §5.7(a), at the ORIGINAL module path `LaserCortex/LogicTypes.lean`.

Research layer, NOT foundations (owner ruling 2026-09-02): the names are a
reading aid for a result that was meant to be an anonymous derivation of
realizable cost geometries from pentagonator constraints (note 006
history). Only the `LogicType` enum is rescued — the archived file's
translation/normal-form machinery (`LogicClass`, `LogicTranslation`,
`MetaContractsTo`) stays archived; none of its cited lemmas depended on
them, and reviving unverified scaffolding is what the triage rule forbids.

## Contracts

[LogicType]

## Cross-refs

`LaserCortex.LogicTable` (the NodeCost table indexed by this enum),
`LaserCortex.foundations.Cost` (the anonymous geometry it interprets),
notes 006/007, `TDD_SPLIT_OCTONION_LOGIC.md`

## Tags

#lean4-definition #invariant #rescued
-/

namespace LogicTypes

/-- The 15 named logics whose cost geometry is tabulated in
    `Cost.nodeParam` (`LaserCortex/LogicTable.lean`). Order is historical
    (archived LogicTypes.lean); the collapse count in `Cost` (8 geometries,
    not the archived 7) supersedes note 006's headline — see its erratum. -/
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
