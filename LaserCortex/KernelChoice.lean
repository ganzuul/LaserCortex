/-
# Module: KernelChoice

## Intent

Defines the kernel norm: which pre-computed intelligent kernel is appropriate
for the kind of intelligence being certified. InstitutionalClosure.Norm selects
a KernelChoice; MarketClosure uses it to decide which market type the closure
instantiated.

This file exists as a minimal shared import to break the circular dependency
between InstitutionalClosure (which needs KernelChoice as a Norm field) and
MarketClosure (which needs KernelChoice + Norm to decide the market type).

## Contracts

KernelChoice : inductive (none | arbitrary | fairPrice)

## Cross-refs

LaserCortex.InstitutionalClosure → Norm.kernel field; LaserCortex.MarketClosure → decideMarketType

## Tags

#lean4-type #kernel-choice
-/

namespace MarketClosure

/-- The kernel norm tells IC what kind of intelligence is being certified.

    This is the (a) tag-only design. The (b) tag-plus-carrier design
    (embedding pool/request/ProblemClass in the inductive) is the natural
    extension and is tracked as a TODO.

    | Variant     | Meaning                                              |
    |-------------|------------------------------------------------------|
    | `.none`     | No kernel selected (Sorites default: raw need for FL)|
    | `.arbitrary`| Arbitrary threshold by decree (Edict default)        |
    | `.fairPrice`| AMM kernel: Generation.reduce ∘ AMM.map              |

    TODO (scaffold for (b)): KernelChoice.none could carry the Sorites
    heap-size; KernelChoice.arbitrary could carry `decree : String → Nat`
    (the arbitrary threshold function); KernelChoice.fairPrice could carry
    `pool : AMM.Pool` and `request : Nat`. See AMM.lean and Generation.lean
    for the relevant types. -/
inductive KernelChoice where
  | none        -- no kernel selected (Sorites default)
  | arbitrary   -- arbitrary threshold by decree (Edict default)
  | fairPrice   -- AMM kernel: Generation.reduce ∘ AMM.map
  deriving DecidableEq, Repr

end MarketClosure
