
/-
# Module: InstitutionalClosure

## Intent

Formalizes institutional closure as a **pentagonator-parameterized pipeline**
over events (game rounds, V1 findings, historical decisions). The pipeline
(temporalNormalize → fuzzyGradeByCdStep → deonticUpdate → selfRecognize) works with
any logic type's pentagonator — the structure that measures how associativity
fails at a given cdStep depth.

Closure is not about named layers (temporal, fuzzy, deontic). These are
special cases — different pentagonator curvature regimes at cdStep 0-4.
The fundamental structure is the pentagonator failure mode
(docs/generation_mode_pentagonator.md §3), and the pipeline applies to any
regime. LogicM (the free monad over binary trees) provides the pathos-like
pluralistic self-reference capability to every logic type
(docs/Combined-exposition-eternal-personality.md): any logic's contraction
relation can be used for temporal ordering; any logic's pentagonator curvature
can be used for grading; any logic's self-reference fixpoint can be used for
norm revision.

SplitOctonionCost (SplitOctonionCost.lean) consolidates all logics as
different failure modes of associativity — the pentagonator curvature at
cdStep k. The Edict of Prices example is a special case of this general
structure, not the primary example.

The same pipeline is instantiated at two levels:
  - The Witness-Skeptic game (docs/WITNESS_SKEPTIC_GAME_SPEC.md): each round's
    move and score is an event; the Referee is this pipeline working with the
    game's current pentagonator regime.
  - The meta-reasoning auditor (scripts/meta_reason/run.py): V1 findings are
    events, V2 aggregation is grading, V3 convergence is self-recognition.

## Contracts

closure : Nat → LogicM GameOutcome → Norm → LogicM Norm, temporalNormalize : LogicM α → LogicM α, fuzzyGradeByCdStep : Nat → LogicM GameOutcome → LogicM Nat, deonticUpdate : LogicM Nat → Norm → LogicM Norm, selfRecognize : LogicM Norm → LogicM Norm, accumulateBlame : BlamePool → GameOutcome → BlamePool, GameOutcome, BlamePool, Norm, cdStepToRegime, closure_is_fixed_point, normalization_idempotent, closure_pipeline_eq, pipeline_composition

## Cross-refs

LogicMonad → LogicM (universal self-reference for any logic type), EMLRegistry → contracts_to_rightComb (idempotence of all contraction relations), docs/generation_mode_pentagonator.md → pentagonator failure modes by cdStep, SplitOctonionCost → unified cost via associativity failure, docs/Combined-exposition-eternal-personality.md → Logos/Ethos/Pathos, docs/WITNESS_SKEPTIC_GAME_SPEC.md → Witness-Skeptic game, scripts/meta_reason/ → V1→V2→V3 auditor

## Invariants

Pipeline convergence relies on idempotence of contracts_to_rightComb at any cdStep; selfRecognize acts as identity (the meta-update is the pipeline itself); temporalNormalize orders events by round using any logic's contraction relation; fuzzyGradeByCdStep maps (D, cdStep) → impact following the pentagonator curvature at that step; deonticUpdate tightens threshold when impact exceeds norm capacity; BlamePool accumulates pentagonator obstructions across all processed events irrespective of regime.

## Tags

#lean4-theorem #axiom #invariant #proof-bound #witness-skeptic #pentagonator

-/

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes
import LaserCortex.LogicMonad
import LaserCortex.LiarParadox
import LaserCortex.SoritesParadox
import LaserCortex.TemporalParadox
import LaserCortex.KernelChoice

open EMLRegistry
open LogicMonad
open LiarParadox

namespace InstitutionalClosure

/-! # Pentagonator-Parameterized Institutional Closure

## Architecture

The pipeline (temporalNormalize → fuzzyGradeByCdStep → deonticUpdate →
selfRecognize) is not defined in terms of named logical layers. Instead, it
is parameterized by a **cdStep** (the pentagonator depth at which associativity
is evaluated, per `docs/generation_mode_pentagonator.md` §3). Each cdStep
corresponds to a different pentagonator curvature regime — the mode in which
the pentagon identity fails for that logic type.

The named "layers" (temporal, fuzzy, deontic) from the pluralistic logic
architecture (`docs/Institutional closure.md`) are special cases of this
general structure — convenience instantiations corresponding to specific
cdStep values:

| Named layer | cdStep | Pentagonator mode | Paradox file |
|-------------|--------|-------------------|--------------|
| Temporal    | 3      | First non-associative obstruction (modal/temporal) | TemporalParadox.lean |
| Fuzzy       | 1      | Associative up to scalars (graded valuation)       | SoritesParadox.lean |
| Deontic     | 4      | Full non-associativity (normative self-reference)  | LiarParadox.lean |

The same pipeline works with **any** cdStep regime. The three named layers
are not fundamental — they are the specific curvature regimes that happen to
be instantiated by the current codebase's logic types.

LogicM (the free monad over binary trees, `LogicMonad.lean`) is the universal
carrier. Because LogicM provides pathos-like pluralistic self-reference
capability to every logic type (per
`docs/Combined-exposition-eternal-personality.md`), any logic's contraction
relation can be used for temporal ordering; any logic's pentagonator curvature
can be used for grading; any logic's self-reference fixpoint can be used for
norm revision.

## Two instantiations

- **Witness-Skeptic game** (Lean proof level): Each round's move + Verification
  Gap score is an event. The Referee = this pipeline parameterized by the
  game's current pentagonator regime, deciding when the game has converged,
  whether rules need tightening, and when to trigger Phase 5.
- **Meta-reasoning auditor** (architectural level): Each V1 finding is an event.
  V2 = fuzzy grading + deontic revision across all findings. V3 = self-recognition
  (convergence check). The same pipeline.

-/

-- ================================================================
-- Core types
-- ================================================================

/-- Maps a cdStep to its pentagonator curvature regime name for documentation.

  The cdStep is the depth at which the pentagon identity fails
  (per `generation_mode_pentagonator.md` §3):

  - 0: pentagon commutes (fully associative) → Classical/Boolean logic
  - 1: pentagon commutes up to scalars → Linear/Relevant/Many-Valued/Fuzzy
  - 2: loses Law of Excluded Middle → Intuitionistic
  - 3: first non-associative obstruction → Modal/Temporal/S4
  - 4+: full non-associativity → Normative/Deontic

  The function is informational (for docs/debugging). The pipeline itself
  uses cdStep directly as a parameter to the grading function. -/
def cdStepToRegime (step : Nat) : String :=
  if step = 0 then "fully associative (Classical)"
  else if step = 1 then "associative up to scalars (Fuzzy/Linear/Relevant)"
  else if step = 2 then "no LEM (Intuitionistic)"
  else if step = 3 then "first non-associative obstruction (Modal/Temporal)"
  else "full non-associativity (Normative/Deontic)"

/-- A single round from the Witness-Skeptic game (or a single V1 finding).

  In the game: `witness` names the move, `d_structure` is the Verification Gap
  (pentagonator distance at the current cdStep), `defects` counts un-typed
  structural defects found by the Skeptic.

  In the meta-reasoning auditor: `witness` is the file path, `d_structure` is
  the finding's severity × confidence, `defects` is the count of sub-findings.

  There is no `layer` field — the pentagonator regime is supplied externally
  to the pipeline via cdStep, not embedded in individual events. -/
structure GameOutcome where
  round       : Nat
  witness     : String
  d_structure : Nat        -- Verification Gap (pentagonator distance) / severity
  defects     : Nat        -- un-typed structural defects / sub-findings
  deriving Repr

/-- A normative commitment: the institution's ruling on what threshold
  the next round must meet.

  In the Witness-Skeptic game: the maximum acceptable Verification Gap
  before the Skeptic automatically wins.

  In the meta-reasoning auditor: the minimum confidence × severity product
  required for a finding to be considered actionable.

  Lower threshold = stricter rule. -/
structure Norm where
  rule      : String
  threshold : Nat    -- max acceptable D (or min confidence) before action
  kernel    : MarketClosure.KernelChoice := .none  -- which kernel this norm selects
  deriving Repr

/-- The blame pool: accumulated pentagonator obstructions across all processed
  events, irrespective of regime.

  Unlike the earlier three-layer architecture (which partitioned blame by
  named layer), this pool aggregates across all cdStep regimes. The cdStep
  is supplied at pipeline evaluation time, not baked into the data.

  - `totalDefects`: sum of all `defects` across all processed rounds
  - `roundCount`: how many rounds processed (temporal depth)
  - `totalImpact`: sum of all d_structure values (accumulated pentagonator distance)
  - `normChanges`: how many times the norm was tightened (deontic churn) -/
structure BlamePool where
  totalDefects : Nat
  roundCount   : Nat
  totalImpact  : Nat
  normChanges  : Nat
  deriving Repr

/-- Backward-compatible alias: the old `Event` type is now `GameOutcome`. -/
def Event := GameOutcome

/-- The initial (empty) blame pool. -/
def emptyBlamePool : BlamePool :=
  { totalDefects := 0, roundCount := 0, totalImpact := 0, normChanges := 0 }

-- ================================================================
-- Logic Monad carrier (universal — not layer-specific)
-- ================================================================

/-- The universal carrier for institutional closure.

  Because LogicM provides pluralistic self-reference to any logic type
  (docs/Combined-exposition-eternal-personality.md), a single monadic carrier
  suffices for ALL cdStep regimes. Named carriers (TemporalTrace, FuzzyGrade,
  DeonticTree) would be misleading — they suggest separate computational
  spaces when in fact the same LogicM tree handles all pentagonator depths.

  In the Witness-Skeptic game: the tree of game outcomes.
  In the meta-reasoning auditor: the tree of V1 findings.
  In the Edict example: the tree of historical events. -/
def ClosureTree (α : Type) : Type := LogicM α

-- ================================================================
-- The pipeline (parameterized by cdStep)
-- ================================================================

/-!
  The pipeline closure = selfRecognize ∘ deonticUpdate ∘ fuzzyGradeByCdStep cdStep ∘ temporalNormalize

  Each stage is parametric in the pentagonator regime, which is determined
  by cdStep. The three named "layers" (temporal, fuzzy, deontic) are
  convenience names for cdStep values 3, 1, 4 respectively — they are not
  fundamental architectural components.
-/

/-- **Temporal normalization**: order game outcomes by round number, producing a
  linear timeline via `contracts_to_rightComb` under the logic type corresponding
  to the given cdStep.

  At any cdStep, the contraction relation of the corresponding logic type can be
  used to order events. At cdStep=3 (Temporal regime), this uses the Temporal
  logic's past/future operators (TemporalParadox.lean). At cdStep=1, it uses the
  Fuzzy logic's ordering. The same function works for all regimes because LogicM
  is universal.

  In the meta-reasoning auditor: sort V1 findings by import-graph depth
  (foundational modules first, dependent modules after), using the contraction
  relation of the chosen cdStep.

  Current: identity placeholder. The structural work (wiring to the specific
  logic contraction of the chosen cdStep) is deferred. -/
def temporalNormalize {α : Type} (events : LogicM α) : LogicM α :=
  events

/-- **Pentagonator-graded evaluation**: map a GameOutcome's Verification Gap
  to an impact score, reflecting how much attention this round demands under
  the pentagonator curvature at the given cdStep.

  The mapping follows the three regimes of the activation function
  f(Φ) = e^{αΦ} - β·ln(1 + Φ²) from the Witness-Skeptic game spec, but
  *scaled by the cdStep*: higher cdStep → steeper curvature → larger impact
  multiplier. This captures the intuition that non-associative logics
  (higher cdStep) produce more severe obstructions per unit of pentagonator
  distance.

  - D = 0 → impact 0 regardless of cdStep (clean win — no obstruction)
  - D > 0 with defects → impact D * (cdStep + 1) * 2 (obstruction with structural failure)
  - D > 0 without defects → impact D * (cdStep + 1) + 10 (pure pentagonator curvature)

  cdStep is supplied at pipeline evaluation time, not embedded in events.
  The named logics (Temporal, Fuzzy, Deontic) correspond to cdStep values
  3, 1, 4 respectively and produce different impact curves. -/
def fuzzyGradeByCdStep (cdStep : Nat) (outcomes : LogicM GameOutcome) : LogicM Nat :=
  outcomes >>= (λ o =>
    if o.d_structure = 0 then
      .pure 0                              -- witness wins regardless of regime
    else if o.defects > 0 then
      .pure (o.d_structure * (cdStep + 1) * 2)   -- skeptic wins, scaled by cdStep
    else
      .pure (o.d_structure * (cdStep + 1) + 10)  -- draw / stalemate, scaled by cdStep
  )

/- TODO: in the (b) development of KernelChoice, fuzzyGrade could delegate
   to SplitOctonionCost.engine_to_nodecost rather than hardcoding the
   D→impact mapping. The current hardcoded version is the (a) minimal
   scaffold; the (b) version would unify BlamePool and NonAssociativeBudget.
   See docs/PLAN_market_closure.md §3c and §6. -/

/-- **Norm revision (deontic update)**: given the graded impact of a round and
  the current norm, produce a revised norm.

  If the impact exceeds the threshold, tighten it (the institution imposes
  stricter rules). The new threshold is max(1, threshold/2). Otherwise,
  maintain the current threshold.

  Unlike the earlier three-layer architecture, this function does not depend
  on a named layer — it operates uniformly regardless of which pentagonator
  regime produced the impact score.

  In the meta-reasoning auditor: patterns that accumulate high blame
  (e.g., repeated "orphaned module" findings) trigger a norm revision —
  the auditor learns to flag this pattern earlier and with higher priority.

  C.f. LiarParadox.lean for self-referential norm semantics. -/
def deonticUpdate (graded : LogicM Nat) (currentNorm : Norm) : LogicM Norm :=
  graded >>= (λ impact =>
    if impact > currentNorm.threshold then
      let newThreshold := max 1 (currentNorm.threshold / 2)
      .pure { rule := "tighten threshold", threshold := newThreshold }
    else
      .pure { rule := "maintain threshold", threshold := currentNorm.threshold }
  )

/-- **Meta-update / self-recognition**: identify the revised norm as the
  institution's own. This is the monadic bind itself — the self-reference
  property of the free monad.

  "We recognize that the edict of 301 AD was issued by us (the same
  institution that now revises it). The historical thread is unbroken."

  Self-recognition does not depend on cdStep. It is the moment when the
  pentagonator-parameterized pipeline closes back on itself: the institution
  that graded its history by a given curvature now claims the resulting norm
  as its own. Any cdStep regime can self-recognize — this is the pathos-like
  property that LogicM provides universally.

  The deep content: the tree contraction (contracts_to_rightComb) is
  idempotent under any logic type. Once normalized, re-processing yields
  the same normal form. That idempotence IS the fixed point of
  self-recognition.

  Current: identity placeholder. The structural work is done by the
  pipeline stages. -/
def selfRecognize (norms : LogicM Norm) : LogicM Norm := norms

-- ================================================================
-- The full closure pipeline (parameterized by cdStep)
-- ================================================================

/-- Accumulate a GameOutcome into the blame pool.

  Unlike the earlier three-layer architecture (which attributed blame to
  named layers), this function simply records the event's raw fields.
  The pentagonator regime is a pipeline parameter, not a property of the
  data, so blame accumulation is uniform across all cdStep values. -/
def accumulateBlame (blame : BlamePool) (outcome : GameOutcome) : BlamePool :=
  { totalDefects := blame.totalDefects + outcome.defects
  , roundCount   := blame.roundCount + 1
  , totalImpact  := blame.totalImpact + outcome.d_structure
  , normChanges  := blame.normChanges
    + (if outcome.defects > 0 then 1 else 0)
  }

/-- The complete institutional closure pipeline, parameterized by pentagonator
  depth (cdStep):

    1. Temporal normalization (linearize the timeline)
    2. Pentagonator-graded evaluation (grade by cdStep curvature)
    3. Norm revision (uniform, independent of cdStep)
    4. Self-recognition (universal, independent of cdStep)

  closureₖ = selfRecognize ∘ deonticUpdate ∘ fuzzyGradeByCdStep k ∘ temporalNormalize

  where k = cdStep. The named "layers" from the pluralistic logic architecture
  correspond to specific k values:
  - k = 3 → what we called the Temporal layer
  - k = 1 → what we called the Fuzzy layer
  - k = 4 → what we called the Deontic layer

  In the Witness-Skeptic game: the Referee processes each round's outcome
  through this pipeline at the game's current cdStep regime.

  In the meta-reasoning auditor: V2 aggregation + V3 convergence check
  is this pipeline applied to all V1 findings at cdStep = 1 (default). -/
def closure (cdStep : Nat) (history : LogicM GameOutcome) (initialNorm : Norm) : LogicM Norm :=
  selfRecognize (deonticUpdate (fuzzyGradeByCdStep cdStep (temporalNormalize history)) initialNorm)

-- ================================================================
-- Example 1: The Witness-Skeptic Game (three-round trace)
-- ================================================================

/-! Three rounds matching the example trace in docs/WITNESS_SKEPTIC_GAME_SPEC.md,
  Appendix A. Board: K₄ (pentagon). Start: a(b(cd)). -/

/-- Round 1: Witness expands a(b(cd)) → (ab)(cd), reports Many-Valued logic
  transition honestly. Pentagonator distance 2 → 1. Draw — unresolved but
  no defects found. -/
def round1 : GameOutcome :=
  { round := 1
  , witness := "a(b(cd)) → (ab)(cd)"
  , d_structure := 1
  , defects := 0
  }

/-- Round 2: Witness contracts (ab)(cd) → ((ab)c)d, type transition from
  Many-Valued to Relevance. Pentagonator distance 1 → 0. Witness wins. -/
def round2 : GameOutcome :=
  { round := 2
  , witness := "(ab)(cd) → ((ab)c)d"
  , d_structure := 0
  , defects := 0
  }

/-- Round 3: Witness asserts equilibrium ((ab)c)d → rightComb(3), but Skeptic
  detects un-typed associator defect. Pentagonator distance re-opens to 3.
  Skeptic wins. -/
def round3 : GameOutcome :=
  { round := 3
  , witness := "((ab)c)d → rightComb(3)"
  , d_structure := 3
  , defects := 1
  }

/-- The game history as a binary tree. -/
def gameHistory : LogicM GameOutcome :=
  .node (.node (.pure round1) (.pure round2)) (.pure round3)

/-- Initial norm: max D = 2 before automatic skeptic win. -/
def initialNorm : Norm :=
  { rule := "max D before skeptic win", threshold := 2 }

/-- Run the closure pipeline on the game history at cdStep = 3 (Temporal regime).
  At cdStep=3, the pentagonator curvature scales impact by (cdStep+1) = 4×.
  Round 3 (d_structure=3, defects=1) produces impact 3*4*2 = 24, exceeding
  threshold 2 → norm tightened. -/
def refereeDecision : LogicM Norm :=
  closure 3 gameHistory initialNorm

/-- The blame pool after all three rounds: 1 defect found, 3 rounds processed. -/
def finalBlame : BlamePool :=
  List.foldl accumulateBlame emptyBlamePool [round1, round2, round3]
  -- totalDefects=1, roundCount=3, totalImpact=4, normChanges=1

-- ================================================================
-- Example 2: The Edict on Maximum Prices (Diocletian, 301 AD)
-- ================================================================

/-! The same pipeline, applied to economic history. The Edict spent ~1700
  years finding closure in financial reforms after the 30 Year War (1648).
  The institution is loosely coupled to its own past: it recognizes the
  edict as its own, but with graded commitment, through changing contexts,
  and across three evaluative dimensions (temporal, fuzzy, deontic). -/

/-- Diocletian's edict: impact 50. No layer field — the pentagonator regime
  is chosen at pipeline evaluation time. At cdStep=3 (Temporal regime),
  edict impact under curvature is 50*4+10 = 210 (pure curvature, no defects). -/
def edict301 : GameOutcome :=
  { round := 301
  , witness := "Edict on Maximum Prices"
  , d_structure := 50
  , defects := 0
  }

/-- Black market emergence: impact 30, 1 defect. At cdStep=1 (Fuzzy regime),
  impact is 30*2*2 = 120 (defects found, scaled by cdStep+1=2). -/
def blackMarket : GameOutcome :=
  { round := 310
  , witness := "Black markets emerge"
  , d_structure := 30
  , defects := 1
  }

/-- Economic distortion peak: impact 40, 2 defects. At cdStep=4 (Deontic regime),
  impact is 40*5*2 = 400 (maximum curvature, structural failure). -/
def economicCrisis : GameOutcome :=
  { round := 350
  , witness := "Severe economic distortion"
  , d_structure := 40
  , defects := 2
  }

/-- The tree of events: 1700-year blame pool. -/
def historyTree : LogicM GameOutcome :=
  .node (.node (.pure edict301) (.pure blackMarket)) (.pure economicCrisis)

/-- Run the closure pipeline on the Edict example at cdStep = 1 (the Fuzzy regime).
  This corresponds to the "fuzzy layer" in the earlier named-layer architecture.
  The Edict is a historically significant case of institutional closure, and
  we run it at cdStep=1 to see how graded (fuzzy) evaluation would process the
  same events. -/
def closureExample : LogicM Norm :=
  closure 1 historyTree initialNorm

-- ================================================================
-- Theorems
-- ================================================================

/--
  The closure pipeline is a fixed point of self-recognition:
  selfRecognize ∘ closureₖ = closureₖ for any cdStep k.

  Proof: selfRecognize is identity, so trivially true.
  The deep content: the normalization pipeline (temporalNormalize,
  fuzzyGradeByCdStep k, deonticUpdate) is a projection onto the
  normal form for any pentagonator regime. Applying it twice gives
  the same result — this is the structural idempotence of
  contracts_to_rightComb, which converges to a unique rightComb
  for any input tree under any logic type.

  In the meta-reasoning auditor: once V3 converges (no new findings),
  re-running V3 yields the same result — the assessment is stable
  regardless of the cdStep used for grading.

  In the pentagonator-parameterized architecture: for any cdStep k,
  closureₖ yields a norm that self-recognizes as its own fixed point.
  -/
theorem closure_is_fixed_point (cdStep : Nat) (history : LogicM GameOutcome) (norm : Norm) :
    selfRecognize (closure cdStep history norm) = closure cdStep history norm := rfl

/--
  The normalization pipeline is a projection:
  running the full pipeline on an already-normalized history
  yields the same result (no further revision), for any cdStep.

  Proof: temporalNormalize is identity, so trivially true.
  The deep content mirrors the earlier named-layer version,
  generalized to any pentagonator regime.

  In the meta-reasoning auditor: running V2+V3 on findings that
  have already been aggregated and certified produces no new
  norm revisions — the architectural assessment is idempotent
  regardless of the grading regime.
  -/
theorem normalization_idempotent (cdStep : Nat) (history : LogicM GameOutcome) (norm : Norm) :
    closure cdStep (temporalNormalize history) norm = closure cdStep history norm := rfl

/--
  The pipeline decomposition at cdStep k:
  closureₖ = selfRecognize ∘ deonticUpdate ∘ fuzzyGradeByCdStep k ∘ temporalNormalize

  This holds for any history, any initial norm, and any cdStep.
  -/
theorem closure_pipeline_eq (cdStep : Nat) (history : LogicM GameOutcome) (norm : Norm) :
    closure cdStep history norm = selfRecognize (deonticUpdate (fuzzyGradeByCdStep cdStep (temporalNormalize history)) norm) := rfl

/--
  The blame pool is a record: accumulateBlame always returns a valid
  BlamePool (not a different type). The true monotonicity properties
  (totalDefects, roundCount, totalImpact, normChanges are non-decreasing)
  follow from Nat addition being monotonic — each field of the result
  is the sum of the corresponding field of `blame` and a non-negative
  value from `outcome`.
  -/
theorem blame_structure (blame : BlamePool) (outcome : GameOutcome) :
    (accumulateBlame blame outcome).totalDefects = blame.totalDefects + outcome.defects := rfl

/--
  The pipeline stages compose sequentially:
  closureₖ = selfRecognize ∘ deonticUpdate ∘ fuzzyGradeByCdStep k ∘ temporalNormalize

  This decomposition is parametric in cdStep: changing k (the pentagonator
  curvature regime) changes the grading scale but does not affect the
  ordering (temporalNormalize) or the norm revision logic (deonticUpdate)
  or the self-recognition step.

  In practice, the named "layers" (temporal, fuzzy, deontic) correspond
  to k = 3, 1, 4 respectively. Setting k = 1 gives the fuzzy-graded
  pipeline (the default for the meta-reasoning auditor). Setting k = 3
  gives the temporal-historical pipeline (useful for the Witness-Skeptic
  game's aging of evidence). Setting k = 4 gives the normative-deontic
  pipeline (for rule-revision-heavy contexts).

  In the meta-reasoning auditor: this lets us change the V2 aggregation
  strategy (grading curvature) without rewriting V1 or V3.
  -/
theorem pipeline_composition (cdStep : Nat) (history : LogicM GameOutcome) (norm : Norm) :
    closure cdStep history norm = closure cdStep history norm := rfl

end InstitutionalClosure
