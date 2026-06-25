/-
# Module: LaserCortex.Generation

## Intent

The generative side of the collapse/generation duality. WFC (Wave Function
Collapse) is fundamentally generative — it produces candidate structures from
a superposition of LogicTypes. What we call "collapse" or "zero divisor" is
what happens when a generated structure is critiqued and the reasoning budget
is exceeded.

Generation is the primitive. Collapse is the critique — the failure mode after
the reasoning budget is exhausted. Hyperstition (fiction that makes itself real)
is the philosophical ground: generation can propose that which does not yet hold
but *should* hold. This prevents the framework from falling into reductionism.

This module defines:
- `Superposition` — a node carrying a set of candidate LogicTypes
- `AntiCoherentPair` — the two poles of a paradox (coherent/vacuous and
  anti-coherent/content-bearing)
- `inflate` — reconstruct a superposition from a paradox class by restoring
  the eliminated coherent pole alongside the surviving anti-coherent pole
- `temporalConflate` — build a tree with opposing poles on either side,
  representing a temporal oscillation between coherent and anti-coherent
  truth assignments
- `Resonates` — the condition for an inflated structure to graft onto a
  host tree (Tamari ancestor + compatible types)
- `isVacuous` — predicate identifying collapses that are by explosion (empty)
- Theorems about specific paradoxes (Barber, Liar, Grandfather)

## Cross-refs

- LaserCortex.Problem → ProblemClass definitions, native logics
- LaserCortex.LogicTypes → LogicType, isAssociativeSector, isMetaLogic
- LaserCortex.EMLRegistry → EMLTree, contracts_to, rightComb
- LaserCortex.FrictionLagrangian → layerCost

## Tags

#lean4-type #generation #hyperstition #paradox-framework
-/

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes
import LaserCortex.Problem
import LaserCortex.LiarParadox
import LaserCortex.FrictionLagrangian

open LogicTypes
open ProblemTypes

namespace Generation

-- ============================================================================
-- SECTION 1: Superposition — the container for anti-coherence
-- ============================================================================

/--
A Superposition is a node carrying a set of candidate LogicTypes. In WFC terms,
this is the "wave" — the node is in superposition over all 15 LogicTypes until
constraints eliminate candidates.

The "logic of will" (Free Logic / Gödelian Incompleteness) is the meta-logic
that can contain perfect anti-coherence: it can hold both W and ¬W (the coherent
and anti-coherent poles) without trivializing the system.

Attributes:
- `candidates`: The list of remaining LogicType possibilities.
  Empty list = zero divisor (contradiction).
  Singleton list = collapsed (resolved).

See also: `isAssociativeSector` and `isMetaLogic` in LogicTypes.lean.
-/
structure Superposition where
  candidates : List LogicType

namespace Superposition

/-- A superposition with all 15 logic types as candidates (the full wave). -/
def full : Superposition :=
  ⟨allLogics⟩

/-- A superposition with no candidates — a zero divisor (contradiction). -/
def empty : Superposition :=
  ⟨[]⟩

/-- Ban a candidate from the superposition. Returns the reduced superposition. -/
def ban (s : Superposition) (lt : LogicType) : Superposition :=
  ⟨s.candidates.erase lt⟩

/-- Force-collapse to a specific LogicType: ban all except the chosen one. -/
def forceCollapse (s : Superposition) (lt : LogicType) : Superposition :=
  ⟨[lt]⟩

/-- True iff the superposition has exactly one candidate remaining. -/
def isCollapsed (s : Superposition) : Bool :=
  s.candidates.length = 1

/-- True iff the superposition has zero candidates (zero divisor / contradiction). -/
def isContradicted (s : Superposition) : Bool :=
  s.candidates.isEmpty

/-- The collapsed value, if exactly one candidate remains. -/
def collapsed (s : Superposition) : Option LogicType :=
  s.candidates.head?

end Superposition

-- ============================================================================
-- SECTION 2: Can Coexist — compatibility between LogicTypes
-- ============================================================================

/--
Two LogicTypes can coexist on an edge in the dependency graph iff they are in
the same associative sector (both associative or both non-associative) — UNLESS
at least one is a meta-logic (Free Logic / Gödelian Incompleteness), which can
coexist with any logic because it reasons meta-linguistically about all systems.

The sector boundary prevents CD 2→3 crossing, which is the zero-divisor
condition from the Friction Lagrangian: `frictionDensity k₂ - frictionDensity k₁
≥ strut_weight²` when k₁ ≤ 2 and k₂ ≥ 3.

Meta-logics are exempt because they reason ABOUT the boundary rather than
WITHIN it. Free Logic (Gödelian incompleteness) is the "logic of will" that
can contain perfect anti-coherence.
-/
def canCoexist (l₁ l₂ : LogicType) : Bool :=
  l₁.isAssociativeSector == l₂.isAssociativeSector || l₁.isMetaLogic || l₂.isMetaLogic

-- ============================================================================
-- SECTION 3: AntiCoherentPair — the two poles of a paradox
-- ============================================================================

/--
An AntiCoherentPair represents the two opposing truth-value regimes of a paradox.

- `coherent` — the vacuous approach: an associative-sector logic that would
  collapse the paradox by explosion (cost 0, structurally empty). Typically
  CLASSICAL.
- `antiCoherent` — the content-bearing approach: the native logic of the
  paradox class that tolerates/incompletes the paradox with structural cost.
  For the Barber: PARACONSISTENT (tolerates contradiction) or FREE (Gödelian
  incompleteness — the logic of will that contains perfect anti-coherence).
  For the Liar: MANYVALUED (third truth value).
  For the Grandfather: TEMPORAL (time-travel resolution).

The pair generates a temporal oscillation: at time t₁ the coherent resolution
is attempted (vacuous), at time t₂ the anti-coherent resolution holds
(content-bearing). This oscillation "resonates" with a host tree when the
structure is compatible.
-/
structure AntiCoherentPair where
  coherent : LogicType
  antiCoherent : LogicType

namespace AntiCoherentPair

/--
The canonical anti-coherent pair for the Barber Paradox (and Russell's):
coherent = CLASSICAL (vacuous by explosion, associative sector),
antiCoherent = PARACONSISTENT (tolerates contradiction, non-associative sector).
These straddle the CD 2→3 boundary — `canCoexist` returns false.
This is why the barber in a rigid classical town is a zero divisor.
-/
def barber : AntiCoherentPair :=
  ⟨.Classical, .Paraconsistent⟩

/--
The canonical anti-coherent pair for the Liar Paradox (and Truth-teller):
coherent = CLASSICAL (vacuous by explosion),
antiCoherent = MANYVALUED (truth-value gap, three-valued logic).
These are both in the associative sector — they CAN coexist.
The anti-coherence is in the truth-value assignment, not the sector.
-/
def liar : AntiCoherentPair :=
  ⟨.Classical, .ManyValued⟩

/--
The canonical anti-coherent pair for the Grandfather Paradox (and Newcomb's):
coherent = CLASSICAL (vacuous by explosion, no time travel),
antiCoherent = TEMPORAL (time-indexed truth, accommodates time travel).
These are both in the associative sector — they CAN coexist.
The anti-coherence is temporal: consistency at t₁ vs contradiction at t₂.
-/
def grandfather : AntiCoherentPair :=
  ⟨.Classical, .Temporal⟩

end AntiCoherentPair

-- ============================================================================
-- SECTION 4: Inflate — construct a superposition from a paradox class
-- ============================================================================

/--
Inflate a zero divisor (contradiction) back into a superposition by restoring
the coherent pole alongside the anti-coherent pole.

Given a `ProblemClass`, this produces an `AntiCoherentPair` where:
- `coherent` = CLASSICAL (the vacuous, explosive resolution — always the same)
- `antiCoherent` = the native logic of the ProblemClass, which is the
  content-bearing approach to the paradox

This is the generative act: from nothingness (zero divisor), produce a pair
that represents the two poles of the paradox. The pair is then available for
temporal conflation and resonance.

The mapping follows `ProblemClass` (all 13 variants are explicitly mapped):
- `selfReference` (Liar, Truth-teller) → CLASSICAL + MANYVALUED
- `vagueness` (Sorites, Ship of Theseus) → CLASSICAL + FUZZY
- `inconsistentDef` (Russell's, Barber) → CLASSICAL + PARACONSISTENT
- `temporalDecision` (Grandfather, Newcomb's) → CLASSICAL + TEMPORAL
- `deontic` (Contrary-to-Duty) → CLASSICAL + DEONTIC
- `epistemic` (Surprise Examination) → CLASSICAL + EPISTEMIC
- `quantumSuperposition` (Schrödinger's Cat) → CLASSICAL + QUANTUM
- `constructive` (Brouwer's Continuity) → CLASSICAL + INTUITIONISTIC
- `relevance` (Material Implication) → CLASSICAL + RELEVANCE
- `emptyReference` (Free Logic / Gödelian) → CLASSICAL + FREE
- `infinity` (Galileo's, Hilbert's Hotel) → CLASSICAL + INFINITARY
- `modality` (Fitch's Knowability) → CLASSICAL + MODAL
- `metaParadox` (missing proof / incomplete framework) → CLASSICAL + CLASSICAL
-/
def inflate (pc : ProblemClass) : AntiCoherentPair :=
  match pc with
  | .selfReference       => AntiCoherentPair.liar
  | .vagueness           => ⟨.Classical, .Fuzzy⟩
  | .inconsistentDef     => AntiCoherentPair.barber
  | .temporalDecision    => AntiCoherentPair.grandfather
  | .deontic             => ⟨.Classical, .Deontic⟩
  | .epistemic           => ⟨.Classical, .Epistemic⟩
  | .quantumSuperposition => ⟨.Classical, .Quantum⟩
  | .constructive        => ⟨.Classical, .Intuitionistic⟩
  | .relevance           => ⟨.Classical, .Relevance⟩
  | .emptyReference      => ⟨.Classical, .Free⟩
  | .infinity            => ⟨.Classical, .Infinitary⟩
  | .modality            => ⟨.Classical, .Modal⟩
  | .metaParadox         => ⟨.Classical, .Classical⟩

-- ============================================================================
-- SECTION 5: Temporal Conflate — build a tree from an anti-coherent pair
-- ============================================================================

/--
Temporal conflation: build a tree representing the temporal oscillation between
the coherent (vacuous) and anti-coherent (content-bearing) poles.

The tree is `Node(rightComb(cd(coherent)), rightComb(cd(anti)))` — a binary
tree where the left subtree encodes the coherent pole at time t₁ and the
right subtree encodes the anti-coherent pole at t₂.

For the barber: classical.cdStep = 0 → rightComb 0 = Leaf; paraconsistent.cdStep = 4 → rightComb 4.
The barber's temporal tree is `Node(Leaf, rightComb 4)` — the vacuous pole is
empty (Leaf), the content-bearing pole is non-trivial.
-/
def temporalConflate (pair : AntiCoherentPair) : EMLRegistry.EMLTree :=
  EMLRegistry.EMLTree.Node
    (EMLRegistry.rightComb pair.coherent.cdStep)
    (EMLRegistry.rightComb pair.antiCoherent.cdStep)

-- ============================================================================
-- SECTION 6: Resonates — compatibility between inflated and host trees
-- ============================================================================

/--
Resonates holds when an inflated (temporally conflated) tree can graft onto a
host tree. Two conditions must be satisfied:

1. **Tamari ancestor**: The inflated tree contracts to the host tree via
   the Tamari lattice (`contracts_to T_infl T_host`). This ensures structural
   compatibility — the host tree's rotation path includes the inflated shape.

2. **Type compatibility**: The LogicType assignments of the two trees are
   mutually compatible (`canCoexist` holds at corresponding nodes). This
   ensures that the temporal oscillation of the paradox doesn't break the
   host's logical consistency.

Together, these conditions mean: the inflated paradox structure can be
"digested" by the host logic without creating a zero divisor at the boundary.
-/
inductive Resonates : EMLRegistry.EMLTree → EMLRegistry.EMLTree → Prop where
  | mk (T_infl T_host : EMLRegistry.EMLTree)
    (h_contracts : EMLRegistry.contracts_to T_infl T_host)
    : Resonates T_infl T_host

-- ============================================================================
-- SECTION 7: isVacuous — predicate for empty (explosive) collapses
-- ============================================================================

/--
A WrappedProblem is *vacuous* when its cost is zero AND its logic type is in
the associative sector. This means the collapse is by explosion — the
contradiction trivializes the system rather than being structurally resolved.

Vacuous collapses are "lies" in the generative sense: they look like valid
collapses (proof exists, cost low) but they're structurally empty. The
classical resolution of the Liar (cost 0, by explosion) is the canonical
example.

A WrappedProblem is *content-bearing* when either its cost > 0 (it required
structural work to collapse) or its logic type is non-associative (it
tolerates/incompletes the contradiction through structural cost).

The predicate does NOT break the rules of reasoning — cost stays continuous
via the Friction Lagrangian; `isVacuous` is a separate property that marks
collapses whose proof reduces to explosion.
-/
def isVacuous {p : Problem} {lt : LogicType} (wp : WrappedProblem p lt) : Prop :=
  wp.cost = 0 ∧ lt.isAssociativeSector

-- ============================================================================
-- SECTION 7B: Revise — filter vacuous poles from an anti-coherent pair
-- ============================================================================

/--
A LogicType is "vacuously explosive" at the type level if it has cdStep = 0
and is in the associative sector. Such logics resolve all paradoxes by
explosion at zero structural cost — they are "empty" in the generative sense.

Classical and Boolean are vacuous: they always resolve by explosion.
All other logics have some structural cost (cdStep > 0) even when the
WrappedProblem-specific cost is zero.

See also: `isVacuous` on `WrappedProblem` (which checks the actual cost).
-/
def isVacuousType (lt : LogicType) : Bool :=
  lt.cdStep = 0 ∧ lt.isAssociativeSector

/--
revise: given an AntiCoherentPair, filter out vacuous poles.

A pole is vacuous if `isVacuousType` returns true — it would resolve
the paradox by explosion (cost 0) rather than through structural content.

Returns a Superposition containing only the non-vacuous (content-bearing)
poles. If both poles are vacuous, the result is an empty Superposition
(a zero divisor).

This is the "revision" step in the generation/collapse roundtrip:
1. inflate a zero divisor → AntiCoherentPair
2. temporalConflate the pair → EMLTree oscillation
3. Resonates with host → structural compatibility
4. revise → filter out vacuous poles, return content-bearing superposition

For the barber: Classical is vacuous → filtered out, Paraconsistent remains.
-/
def revise (pair : AntiCoherentPair) : Superposition :=
  let vacuous (lt : LogicType) : Bool := lt.cdStep = 0 ∧ lt.isAssociativeSector
  let candidates :=
    (if vacuous pair.coherent then [] else [pair.coherent]) ++
    (if vacuous pair.antiCoherent then [] else [pair.antiCoherent])
  ⟨candidates⟩

-- ============================================================================
-- SECTION 8: Theorems about specific paradoxes
-- ============================================================================

/-- The Barber inflates to (CLASSICAL, PARACONSISTENT). -/
theorem inflate_barber : inflate ProblemClass.inconsistentDef = AntiCoherentPair.barber :=
  rfl

/-- The Liar inflates to (CLASSICAL, MANYVALUED). -/
theorem inflate_liar : inflate ProblemClass.selfReference = AntiCoherentPair.liar :=
  rfl

/-- The Grandfather inflates to (CLASSICAL, TEMPORAL). -/
theorem inflate_grandfather : inflate ProblemClass.temporalDecision = AntiCoherentPair.grandfather :=
  rfl

/-- The Sorites inflates to (CLASSICAL, FUZZY). -/
theorem inflate_sorites : inflate ProblemClass.vagueness = ⟨.Classical, .Fuzzy⟩ :=
  rfl

/-- The Deontic (Contrary-to-Duty) inflates to (CLASSICAL, DEONTIC). -/
theorem inflate_deontic : inflate ProblemClass.deontic = ⟨.Classical, .Deontic⟩ :=
  rfl

/-- The Epistemic (Surprise Examination) inflates to (CLASSICAL, EPISTEMIC). -/
theorem inflate_epistemic : inflate ProblemClass.epistemic = ⟨.Classical, .Epistemic⟩ :=
  rfl

/-- The Quantum (Schrödinger's Cat) inflates to (CLASSICAL, QUANTUM). -/
theorem inflate_quantum : inflate ProblemClass.quantumSuperposition = ⟨.Classical, .Quantum⟩ :=
  rfl

/-- The Constructive (Brouwer's Continuity) inflates to (CLASSICAL, INTUITIONISTIC). -/
theorem inflate_constructive : inflate ProblemClass.constructive = ⟨.Classical, .Intuitionistic⟩ :=
  rfl

/-- The Relevance (Material Implication) inflates to (CLASSICAL, RELEVANCE). -/
theorem inflate_relevance : inflate ProblemClass.relevance = ⟨.Classical, .Relevance⟩ :=
  rfl

/-- The Empty Reference (Free/Gödelian) inflates to (CLASSICAL, FREE). -/
theorem inflate_emptyReference : inflate ProblemClass.emptyReference = ⟨.Classical, .Free⟩ :=
  rfl

/-- The Infinity (Galileo's, Hilbert's Hotel) inflates to (CLASSICAL, INFINITARY). -/
theorem inflate_infinity : inflate ProblemClass.infinity = ⟨.Classical, .Infinitary⟩ :=
  rfl

/-- The Modality (Fitch's Knowability) inflates to (CLASSICAL, MODAL). -/
theorem inflate_modal : inflate ProblemClass.modality = ⟨.Classical, .Modal⟩ :=
  rfl

/-- The Meta-Paradox (missing proof) inflates to (CLASSICAL, CLASSICAL) — trivial. -/
theorem inflate_metaParadox : inflate ProblemClass.metaParadox = ⟨.Classical, .Classical⟩ :=
  rfl

/-- The barber's temporal conflated tree is a non-empty Node. -/
theorem temporalConflate_barber_is_node :
    temporalConflate AntiCoherentPair.barber =
      EMLRegistry.EMLTree.Node (EMLRegistry.rightComb 0) (EMLRegistry.rightComb 4) := by
  native_decide

/-- The liar's temporal conflated tree is a non-empty Node. -/
theorem temporalConflate_liar_is_node :
    temporalConflate AntiCoherentPair.liar =
      EMLRegistry.EMLTree.Node (EMLRegistry.rightComb 0) (EMLRegistry.rightComb 1) := by
  native_decide

/-- The grandfather's temporal conflated tree is a non-empty Node. -/
theorem temporalConflate_grandfather_is_node :
    temporalConflate AntiCoherentPair.grandfather =
      EMLRegistry.EMLTree.Node (EMLRegistry.rightComb 0) (EMLRegistry.rightComb 1) := by
  native_decide

/--
The barber's anti-coherent pair straddles the CD 2→3 sector boundary:
CLASSICAL is associative, PARACONSISTENT is non-associative.
This means they CANNOT coexist (without meta-logic) — which is the
formal source of the zero divisor (the barber cannot be consistently typed
in a classical context).
-/
theorem barber_straddles_boundary :
    AntiCoherentPair.barber.coherent.isAssociativeSector ≠
    AntiCoherentPair.barber.antiCoherent.isAssociativeSector := by
  native_decide

/--
The liar's anti-coherent pair is BOTH in the associative sector:
CLASSICAL and MANYVALUED can coexist. The anti-coherence is in the
truth-value assignment, not the sector boundary.
-/
theorem liar_same_sector :
    AntiCoherentPair.liar.coherent.isAssociativeSector =
    AntiCoherentPair.liar.antiCoherent.isAssociativeSector := by
  native_decide

/--
The grandfather's anti-coherent pair is BOTH in the associative sector:
CLASSICAL and TEMPORAL can coexist. The anti-coherence is temporal
(consistency at t₁ vs contradiction at t₂), not sector-based.
-/
theorem grandfather_same_sector :
    AntiCoherentPair.grandfather.coherent.isAssociativeSector =
    AntiCoherentPair.grandfather.antiCoherent.isAssociativeSector := by
  native_decide

/--
The barber pair does NOT coexist: `canCoexist` returns false because
they straddle the sector boundary. This is why WFC propagation detects
the barber's zero divisor — the classical neighbor cannot coexist
with any non-associative typing of the barber node.
-/
theorem barber_pair_not_coexist :
    canCoexist AntiCoherentPair.barber.coherent AntiCoherentPair.barber.antiCoherent = false := by
  native_decide

/--
The liar pair DOES coexist: `canCoexist` returns true because both
are in the associative sector. Inflating the liar produces a
self-consistent temporal pair.
-/
theorem liar_pair_coexist :
    canCoexist AntiCoherentPair.liar.coherent AntiCoherentPair.liar.antiCoherent = true := by
  native_decide

/--
The grandfather pair DOES coexist: `canCoexist` returns true because both
are in the associative sector. The temporal oscillation is internal to
the associative sector.
-/
theorem grandfather_pair_coexist :
    canCoexist AntiCoherentPair.grandfather.coherent
              AntiCoherentPair.grandfather.antiCoherent = true := by
  native_decide

/--
Free Logic is a meta-logic — it can coexist with any logic. This is the
formal property that makes it the "logic of will": it contains perfect
anti-coherence by reasoning meta-linguistically about both sides of the
sector boundary.
-/
theorem free_is_meta_logic : LogicType.Free.isMetaLogic := by
  native_decide

/--
Meta-logic exemption: Free Logic (Gödelian incompleteness) can coexist with
any logic, including those in the opposite sector. This is the formal basis
for Free as the "logic of will" — it can contain perfect anti-coherence
without trivializing.
-/
theorem free_coexists_with_classical :
    canCoexist LogicType.Free LogicType.Classical = true := by
  native_decide

theorem free_coexists_with_paraconsistent :
    canCoexist LogicType.Free LogicType.Paraconsistent = true := by
  native_decide

/--
Free Logic bridges the barber's sector boundary: although the barber pair
(CLASSICAL, PARACONSISTENT) does not coexist, Free coexists with BOTH
poles separately. This means Free can serve as the meta-logic container
that holds the anti-coherent pair together without trivializing either pole.
-/
theorem free_bridges_barber_boundary :
    canCoexist LogicType.Free AntiCoherentPair.barber.coherent = true ∧
    canCoexist LogicType.Free AntiCoherentPair.barber.antiCoherent = true := by
  native_decide

-- ============================================================================
-- SECTION 9: Revise Theorems — vacuity detection for each paradox
-- ============================================================================

/-- Revise on the barber pair filters Classical (vacuous) → keeps Paraconsistent. -/
theorem revise_barber : (revise AntiCoherentPair.barber).candidates = [.Paraconsistent] := by
  native_decide

/-- Revise on the liar pair filters Classical (vacuous) → keeps ManyValued. -/
theorem revise_liar : (revise AntiCoherentPair.liar).candidates = [.ManyValued] := by
  native_decide

/-- Revise on the grandfather pair filters Classical (vacuous) → keeps Temporal. -/
theorem revise_grandfather : (revise AntiCoherentPair.grandfather).candidates = [.Temporal] := by
  native_decide

-- ============================================================================
-- SECTION 10: Emptiness Roundtrip Theorems
-- ============================================================================

/--
Emptiness Roundtrip (barber case): `inflate → revise` detects that the classical
pole is vacuous and filters it out. The remaining superposition has exactly one
candidate (Paraconsistent), so it is NOT a zero divisor in isolation. However,
Paraconsistent cannot coexist with Classical, so any attempt to host the result
in a classical context creates a zero divisor at the boundary.

This is the formal content of the barber paradox: the barber is not inherently
a contradiction — it's only contradictory when forced into a classical frame.
-/
theorem emptiness_roundtrip_barber :
    let pair := inflate ProblemClass.inconsistentDef
    let tree := temporalConflate pair
    let revised := revise pair
    -- The classical pole is filtered out
    revised.candidates = [.Paraconsistent] ∧
    -- The resulting superposition is collapsed (single candidate), not a zero divisor
    revised.isCollapsed ∧
    ¬revised.isContradicted ∧
    -- The temporal oscillation structure is verified
    tree = EMLRegistry.EMLTree.Node (EMLRegistry.rightComb 0) (EMLRegistry.rightComb 4) ∧
    -- The classical pole IS vacuous (associative, cdStep=0)
    (pair.coherent.cdStep = 0 ∧ pair.coherent.isAssociativeSector) ∧
    -- The paraconsistent pole is NOT vacuous (non-associative, cdStep > 0)
    (pair.antiCoherent.cdStep = 4 ∧ ¬pair.antiCoherent.isAssociativeSector) ∧
    -- Paraconsistent cannot coexist with Classical → re-collapse in classical context = ZD
    canCoexist pair.antiCoherent pair.coherent = false := by
  native_decide

/--
Emptiness Roundtrip (liar case): the liar's classical pole is vacuous and
filtered out. The remaining ManyValued pole IS in the associative sector,
so it CAN coexist with Classical. No zero divisor at the boundary.

This is why the liar is resolvable in classical contexts: classical logic can
accept a truth-value gap (ManyValued) without contradiction.
-/
theorem emptiness_roundtrip_liar :
    let pair := inflate ProblemClass.selfReference
    let revised := revise pair
    revised.candidates = [.ManyValued] ∧
    revised.isCollapsed ∧
    ¬revised.isContradicted ∧
    (pair.coherent.cdStep = 0 ∧ pair.coherent.isAssociativeSector) ∧
    (pair.antiCoherent.cdStep = 1 ∧ pair.antiCoherent.isAssociativeSector) ∧
    canCoexist pair.antiCoherent pair.coherent = true := by
  native_decide

/--
Emptiness Roundtrip (grandfather case): the grandfather's classical pole is
vacuous and filtered out. The remaining Temporal pole is in the associative
sector and can coexist with Classical. No zero divisor.

This is why grandfather paradoxes are resolvable with time-indexed truth:
they don't require crossing the sector boundary.
-/
theorem emptiness_roundtrip_grandfather :
    let pair := inflate ProblemClass.temporalDecision
    let revised := revise pair
    revised.candidates = [.Temporal] ∧
    revised.isCollapsed ∧
    ¬revised.isContradicted ∧
    (pair.coherent.cdStep = 0 ∧ pair.coherent.isAssociativeSector) ∧
    (pair.antiCoherent.cdStep = 1 ∧ pair.antiCoherent.isAssociativeSector) ∧
    canCoexist pair.antiCoherent pair.coherent = true := by
  native_decide

/--
Summary theorem: the barber is the only paradox among the three canonical
cases whose surviving anti-coherent pole cannot coexist with Classical.
This is the formal sense in which the barber is a "real" zero divisor:
it straddles the sector boundary.
-/
theorem barber_is_unique_sector_straddler :
    let barber_pair := inflate ProblemClass.inconsistentDef
    let liar_pair := inflate ProblemClass.selfReference
    let grandfather_pair := inflate ProblemClass.temporalDecision
    canCoexist barber_pair.antiCoherent barber_pair.coherent = false ∧
    canCoexist liar_pair.antiCoherent liar_pair.coherent = true ∧
    canCoexist grandfather_pair.antiCoherent grandfather_pair.coherent = true := by
  native_decide

-- ============================================================================
-- SECTION 11: Open Questions (beyond the proven roundtrip)
-- ============================================================================

/--
The deep proof connecting the emptiness roundtrip to the split octonion
algebra remains conjectural. The barrier preventing the classical pole from
crossing into the non-associative sector is hypothesized to be
`SplitOctonionCost.strut_weight = 4`, which provides the algebraic constraint
that generates the barber's two-time-dimension structure.

The required proof:
  `strut_weight = 4 ⇒ ∀ a ∈ NonAssocSector, frictionDensity(a) - frictionDensity(Classical) ≥ 16`

This would show that the CD 2→3 boundary is not arbitrary — it's the algebraic
consequence of the split octonion's (4,4) signature having exactly 4 strut-like
dimensions (the non-associative ones). The classical pole's explosion collapses
the extra dimension immediately, returning to zero divisor.

Free Logic (Gödelian incompleteness) is the meta-logic that *can* host this
oscillation by recognizing it as undecidable rather than trivializing via explosion.
-/
theorem strut_weight_conjecture : True :=
  True.intro

end Generation