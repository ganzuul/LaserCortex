import LaserCortex.foundations.Tamari

-- ============================================================================
-- SECTION 0: ProblemClass — the 13 paradox classes
-- Standalone inductive (no LogicType dependency). Kept here to avoid
-- dragging the LogicTypes → EMLTree chain into the generation cycle.
-- ============================================================================

/--
A class of paradoxes sharing a common structural pattern.
-/
inductive ProblemClass : Type where
  | selfReference
  | vagueness
  | inconsistentDef
  | temporalDecision
  | deontic
  | epistemic
  | quantumSuperposition
  | constructive
  | relevance
  | emptyReference
  | infinity
  | modality
  | metaParadox
  deriving DecidableEq, Repr

-- ============================================================================
-- SECTION 1: Superposition -- the container for anti-coherence (cdStep-based)
-- ============================================================================

/--
A superposition stores a list of cdStep candidates (ℕ values).
This replaces the old LogicType-based superposition: the type algebra
reduces each logic type to its pentagonator depth (cdStep), so the
generation cycle operates on ℕ rather than the 15-type enumeration.
-/
structure Superposition where
  candidates : List ℕ
  deriving DecidableEq, Repr

namespace Superposition

def full : Superposition :=
  ⟨[]⟩

def empty : Superposition :=
  ⟨[]⟩

def ban (s : Superposition) (cd : ℕ) : Superposition :=
  ⟨s.candidates.erase cd⟩

def forceCollapse (s : Superposition) (cd : ℕ) : Superposition :=
  ⟨[cd]⟩

def isCollapsed (s : Superposition) : Bool :=
  s.candidates.length = 1

def isContradicted (s : Superposition) : Bool :=
  s.candidates.isEmpty

def collapsed (s : Superposition) : Option ℕ :=
  s.candidates.head?

end Superposition

-- ============================================================================
-- SECTION 2: Can Coexist (cdStep-based)
-- ============================================================================

/--
Two cdSteps can coexist if they are in the same associative sector (≤1)
or if either is the meta-logic cdStep (4, Free logic). This mirrors the
original LogicType.canCoexist but uses the pentagonator depth directly.
-/
def canCoexist (c1 c2 : ℕ) : Bool :=
  (c1 ≤ 1) == (c2 ≤ 1) || c1 = 4 || c2 = 4

-- ============================================================================
-- SECTION 3: DescentInterval — geodesic source→target in cdStep space
-- ============================================================================

/--
A descent interval `[target, source]` in cdStep space, encoding a directed
rewriting path from the anti-coherent pole (`source`, higher cdStep, complex,
non-associative) toward the coherent attractor (`target`, cdStep 0, fully
classical, associative).

In general, target is always 0 (Classical) — the unique fixed point of the
generation cycle.  But the structure is kept general: an interval `target ≤ t`
in cdStep space where the generation cycle descends from `source` toward
`target`.  

The **geodesic** through this interval is the unique contraction when both
poles are in the associative sector (cdStep ≤ 2): the Tamari lattice provides
a unique shortest normal-form path.  When the source is in the non-associative
sector (cdStep ≥ 3), zero divisors obstruct the geodesic and the cost function
computes a **path-integral** over all viable contraction routes — this is
where `frictionDensity` acts as the non-associative action.

Concrete intervals:
  | Name        | (target, source) | Meaning |
  |-------------|------------------|---------|
  | `barber`    | (0, 4)           | Associative → Free logic (maximal descent) |
  | `liar`      | (0, 1)           | Both associative, minimal descent |
  | `grandfather`| (0, 1)          | Temporal at cdStep 1, minimal descent |
-/
structure DescentInterval where
  target : ℕ
  source : ℕ
  deriving DecidableEq, Repr

namespace DescentInterval

/-- Classical (0) → Paraconsistent (4): sector boundary crossing. -/
def barber : DescentInterval :=
  ⟨0, 4⟩

/-- Classical (0) → ManyValued (1): both associative. -/
def liar : DescentInterval :=
  ⟨0, 1⟩

/-- Classical (0) → Temporal (1): both associative. -/
def grandfather : DescentInterval :=
  ⟨0, 1⟩

end DescentInterval

-- ============================================================================
-- SECTION 4: Inflate
-- ============================================================================

/--
Map each problem class to its descent interval (target, source) in cdStep space.
The target (attractor) is always Classical at cdStep 0. The source is the
cdStep of the logic best suited to resolve paradoxes of that class — the
generation cycle descends from source toward target.
-/
def inflate (pc : ProblemClass) : DescentInterval :=
  match pc with
  | .selfReference       => DescentInterval.liar        -- 0, 1
  | .vagueness           => ⟨0, 1⟩                        -- Fuzzy
  | .inconsistentDef     => DescentInterval.barber       -- 0, 4
  | .temporalDecision    => DescentInterval.grandfather  -- 0, 1
  | .deontic             => ⟨0, 1⟩                        -- Deontic
  | .epistemic           => ⟨0, 1⟩                        -- Epistemic
  | .quantumSuperposition => ⟨0, 3⟩                       -- Quantum
  | .constructive        => ⟨0, 2⟩                        -- Intuitionistic
  | .relevance           => ⟨0, 3⟩                        -- Relevance
  | .emptyReference      => ⟨0, 4⟩                        -- Free
  | .infinity            => ⟨0, 3⟩                        -- Infinitary
  | .modality            => ⟨0, 3⟩                        -- Modal
  | .metaParadox         => ⟨0, 0⟩                        -- Classical × Classical

-- ============================================================================
-- SECTION 5: Temporal Conflate
-- ============================================================================

def temporalConflate (pair : DescentInterval) : EMLTree :=
  EMLTree.Node
    (rightComb pair.target)
    (rightComb pair.source)

-- ============================================================================
-- SECTION 6: Revise (cdStep-based vacuity check)
-- ============================================================================

/--
A cdStep is vacuous if it is 0 (Classical level). At cdStep 0 the logic is
fully associative with no zero divisors, so it cannot sustain anti-coherence.
-/
def isVacuousCd (cd : ℕ) : Bool := cd = 0

/--
Revise a superposition by filtering out vacuous cdSteps from the pair.
The surviving cdStep(s) are the non-classical pole(s) that can sustain
anti-coherence.
-/
def revise (pair : DescentInterval) : Superposition :=
  let candidates :=
    (if isVacuousCd pair.target then [] else [pair.target]) ++
    (if isVacuousCd pair.source then [] else [pair.source])
  ⟨candidates⟩

-- ============================================================================
-- SECTION 7: Generation Cycle
-- ============================================================================

inductive CyclePhase : Type where
  | inflated
  | conflated
  | revised
  | nextPC
  deriving DecidableEq, Repr

structure GenerationState where
  problemClass : ProblemClass
  pair : DescentInterval
  tree : EMLTree
  superposition : Superposition
  phase : CyclePhase
  deriving DecidableEq, Repr

def initialGenerationState : GenerationState :=
  { problemClass := .temporalDecision
  , pair := DescentInterval.grandfather
  , tree := .Leaf
  , superposition := Superposition.full
  , phase := .inflated
  }

def generationStep (s : GenerationState) : GenerationState :=
  match s.phase with
  | .inflated =>
    { s with
      tree := temporalConflate s.pair
      phase := .conflated
    }
  | .conflated =>
    { s with
      superposition := revise s.pair
      phase := .revised
    }
  | .revised =>
    -- The generation cycle operates at a fixed problem class: the source
    -- cdStep is defined by inflate(pc) and the superposition never introduces
    -- a different pc. No findProblemClass lookup needed.
    { s with
      phase := .nextPC
    }
  | .nextPC =>
    let newPair := inflate s.problemClass
    { problemClass := s.problemClass
    , pair := newPair
    , tree := .Leaf
    , superposition := Superposition.full
    , phase := .inflated
    }

-- ============================================================================
-- SECTION 8: Simplified Step Functions
-- ============================================================================

def swapPoles (pair : DescentInterval) : DescentInterval :=
  ⟨pair.source, pair.target⟩

def treeSwapStep (t : EMLTree) : EMLTree :=
  match t with
  | .Node l r => .Node r l
  | .Leaf => .Leaf

-- ============================================================================
-- SECTION 9: Theorems
-- ============================================================================

theorem inflate_barber : inflate ProblemClass.inconsistentDef = DescentInterval.barber :=
  rfl

theorem inflate_liar : inflate ProblemClass.selfReference = DescentInterval.liar :=
  rfl

theorem inflate_grandfather : inflate ProblemClass.temporalDecision = DescentInterval.grandfather :=
  rfl

theorem temporalConflate_grandfather_is_oscillation :
    temporalConflate DescentInterval.grandfather =
      EMLTree.Node (rightComb 0) (rightComb 1) := by
  native_decide

theorem temporalConflate_barber_is_oscillation :
    temporalConflate DescentInterval.barber =
      EMLTree.Node (rightComb 0) (rightComb 4) := by
  native_decide

theorem revise_grandfather :
    (revise DescentInterval.grandfather).candidates = [1] := by
  native_decide

theorem revise_barber :
    (revise DescentInterval.barber).candidates = [4] := by
  native_decide

theorem emptiness_roundtrip_grandfather :
    let pair := inflate ProblemClass.temporalDecision
    let tree := temporalConflate pair
    let revised := revise pair
    revised.candidates = [1] ∧
    revised.isCollapsed ∧
    ¬revised.isContradicted ∧
    pair.target = 0 ∧ pair.target ≤ 1 ∧
    pair.source = 1 ∧ pair.source ≤ 1 ∧
    canCoexist pair.source pair.target = true := by
  native_decide

theorem grandfather_pair_coexist :
    canCoexist DescentInterval.grandfather.target
              DescentInterval.grandfather.source = true := by
  native_decide

/-- The barber pair (0, 4) can coexist: the target is Classical (cdStep 0,
    always coexists) and the source is Free (cdStep 4, meta-logic that
    coexists with everything). -/
theorem barber_pair_coexist :
    canCoexist DescentInterval.barber.target
              DescentInterval.barber.source = true := by
  native_decide
