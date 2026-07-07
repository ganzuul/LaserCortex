import LaserCortex.LogicTypes
import LaserCortex.staging.Tamari
import LaserCortex.staging.Problem

open LogicTypes

-- ============================================================================
-- SECTION 1: Superposition -- the container for anti-coherence
-- ============================================================================

structure Superposition where
  candidates : List LogicType
  deriving DecidableEq, Repr

namespace Superposition

def full : Superposition :=
  ⟨LogicTypes.allLogics⟩

def empty : Superposition :=
  ⟨[]⟩

def ban (s : Superposition) (lt : LogicType) : Superposition :=
  ⟨s.candidates.erase lt⟩

def forceCollapse (s : Superposition) (lt : LogicType) : Superposition :=
  ⟨[lt]⟩

def isCollapsed (s : Superposition) : Bool :=
  s.candidates.length = 1

def isContradicted (s : Superposition) : Bool :=
  s.candidates.isEmpty

def collapsed (s : Superposition) : Option LogicType :=
  s.candidates.head?

end Superposition

-- ============================================================================
-- SECTION 2: Can Coexist
-- ============================================================================

def canCoexist (l1 l2 : LogicType) : Bool :=
  l1.isAssociativeSector == l2.isAssociativeSector || l1.isMetaLogic || l2.isMetaLogic

-- ============================================================================
-- SECTION 3: AntiCoherentPair
-- ============================================================================

structure AntiCoherentPair where
  coherent : LogicType
  antiCoherent : LogicType
  deriving DecidableEq, Repr

namespace AntiCoherentPair

def barber : AntiCoherentPair :=
  ⟨.Classical, .Paraconsistent⟩

def liar : AntiCoherentPair :=
  ⟨.Classical, .ManyValued⟩

def grandfather : AntiCoherentPair :=
  ⟨.Classical, .Temporal⟩

end AntiCoherentPair

-- ============================================================================
-- SECTION 4: Inflate
-- ============================================================================

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
-- SECTION 5: Temporal Conflate
-- ============================================================================

def temporalConflate (pair : AntiCoherentPair) : EMLTree :=
  EMLTree.Node
    (rightComb pair.coherent.cdStep)
    (rightComb pair.antiCoherent.cdStep)

-- ============================================================================
-- SECTION 6: Revise
-- ============================================================================

def isVacuousType (lt : LogicType) : Bool :=
  lt.cdStep = 0 && lt.isAssociativeSector

def revise (pair : AntiCoherentPair) : Superposition :=
  let candidates :=
    (if isVacuousType pair.coherent then [] else [pair.coherent]) ++
    (if isVacuousType pair.antiCoherent then [] else [pair.antiCoherent])
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
    let survivor := s.superposition.collapsed
    let nextPC : ProblemClass :=
      match survivor with
      | some lt =>
        match findProblemClass lt with
        | some pc => pc
        | none => s.problemClass
      | none => s.problemClass
    { s with
      problemClass := nextPC
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
    (revise AntiCoherentPair.grandfather).candidates = [.Temporal] := by
  native_decide

theorem revise_barber :
    (revise AntiCoherentPair.barber).candidates = [.Paraconsistent] := by
  native_decide

theorem emptiness_roundtrip_grandfather :
    let pair := inflate ProblemClass.temporalDecision
    let tree := temporalConflate pair
    let revised := revise pair
    revised.candidates = [.Temporal] ∧
    revised.isCollapsed ∧
    ¬revised.isContradicted ∧
    (pair.coherent.cdStep = 0 ∧ pair.coherent.isAssociativeSector) ∧
    (pair.antiCoherent.cdStep = 1 ∧ pair.antiCoherent.isAssociativeSector) ∧
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
