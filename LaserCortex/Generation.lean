import LaserCortex.foundations.Tamari
import LaserCortex.Problem

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
-- SECTION 3: AntiCoherentPair (ℕ × ℕ, replacing LogicType × LogicType)
-- ============================================================================

/--
An anti-coherent pair stores the cdSteps of the coherent (Classical, cdStep 0)
and anti-coherent logic. The concrete pairs are defined as ℕ × ℕ literals
derived from the cdStep mapping.
-/
structure AntiCoherentPair where
  coherent : ℕ
  antiCoherent : ℕ
  deriving DecidableEq, Repr

namespace AntiCoherentPair

/-- Classical (0) vs Paraconsistent (4): sector boundary crossing. -/
def barber : AntiCoherentPair :=
  ⟨0, 4⟩

/-- Classical (0) vs ManyValued (1): both associative, coexisting. -/
def liar : AntiCoherentPair :=
  ⟨0, 1⟩

/-- Classical (0) vs Temporal (1): both associative, coexisting. -/
def grandfather : AntiCoherentPair :=
  ⟨0, 1⟩

end AntiCoherentPair

-- ============================================================================
-- SECTION 4: Inflate
-- ============================================================================

/--
Map each problem class to its anti-coherent pair (coherent cdStep, anti-coherent cdStep).
The coherent pole is always Classical at cdStep 0. The anti-coherent pole is the
cdStep of the logic best suited to resolve paradoxes of that class.
-/
def inflate (pc : ProblemClass) : AntiCoherentPair :=
  match pc with
  | .selfReference       => AntiCoherentPair.liar        -- 0, 1
  | .vagueness           => ⟨0, 1⟩                        -- Fuzzy
  | .inconsistentDef     => AntiCoherentPair.barber       -- 0, 4
  | .temporalDecision    => AntiCoherentPair.grandfather  -- 0, 1
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

def temporalConflate (pair : AntiCoherentPair) : EMLTree :=
  EMLTree.Node
    (rightComb pair.coherent)
    (rightComb pair.antiCoherent)

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
def revise (pair : AntiCoherentPair) : Superposition :=
  let candidates :=
    (if isVacuousCd pair.coherent then [] else [pair.coherent]) ++
    (if isVacuousCd pair.antiCoherent then [] else [pair.antiCoherent])
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
  pair : AntiCoherentPair
  tree : EMLTree
  superposition : Superposition
  phase : CyclePhase
  deriving DecidableEq, Repr

def initialGenerationState : GenerationState :=
  { problemClass := .temporalDecision
  , pair := AntiCoherentPair.grandfather
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
    -- The generation cycle operates at a fixed problem class: the anti-coherent
    -- pole's cdStep is defined by inflate(pc) and the superposition never
    -- introduces a different pc. No findProblemClass lookup needed.
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

def swapPoles (pair : AntiCoherentPair) : AntiCoherentPair :=
  ⟨pair.antiCoherent, pair.coherent⟩

def treeSwapStep (t : EMLTree) : EMLTree :=
  match t with
  | .Node l r => .Node r l
  | .Leaf => .Leaf

-- ============================================================================
-- SECTION 9: Theorems
-- ============================================================================

theorem inflate_barber : inflate ProblemClass.inconsistentDef = AntiCoherentPair.barber :=
  rfl

theorem inflate_liar : inflate ProblemClass.selfReference = AntiCoherentPair.liar :=
  rfl

theorem inflate_grandfather : inflate ProblemClass.temporalDecision = AntiCoherentPair.grandfather :=
  rfl

theorem temporalConflate_grandfather_is_oscillation :
    temporalConflate AntiCoherentPair.grandfather =
      EMLTree.Node (rightComb 0) (rightComb 1) := by
  native_decide

theorem temporalConflate_barber_is_oscillation :
    temporalConflate AntiCoherentPair.barber =
      EMLTree.Node (rightComb 0) (rightComb 4) := by
  native_decide

theorem revise_grandfather :
    (revise AntiCoherentPair.grandfather).candidates = [1] := by
  native_decide

theorem revise_barber :
    (revise AntiCoherentPair.barber).candidates = [4] := by
  native_decide

theorem emptiness_roundtrip_grandfather :
    let pair := inflate ProblemClass.temporalDecision
    let tree := temporalConflate pair
    let revised := revise pair
    revised.candidates = [1] ∧
    revised.isCollapsed ∧
    ¬revised.isContradicted ∧
    pair.coherent = 0 ∧ pair.coherent ≤ 1 ∧
    pair.antiCoherent = 1 ∧ pair.antiCoherent ≤ 1 ∧
    canCoexist pair.antiCoherent pair.coherent = true := by
  native_decide

theorem grandfather_pair_coexist :
    canCoexist AntiCoherentPair.grandfather.coherent
              AntiCoherentPair.grandfather.antiCoherent = true := by
  native_decide

theorem barber_pair_not_coexist :
    canCoexist AntiCoherentPair.barber.coherent
              AntiCoherentPair.barber.antiCoherent = false := by
  native_decide
