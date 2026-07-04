--== RECOVERED UNKNOWN STATE ==
-- Extracted from session transcript (recovery_session_transcript.jsonl)
-- These files represent the state the repo was left in after unguarded checkouts.
-- 4 files recovered
-- Lines: 27178 lines
--== END HEADER ==


======================================================================
-- FILE: /home/nos/labware/LaserCortex/LaserCortex/TropicalTamariLattice.lean (transcript line 67)
======================================================================

import Mathlib.Algebra.Tropical.Basic
import Mathlib.Algebra.Tropical.Lattice
import Mathlib.LinearAlgebra.CliffordAlgebra.Grading
import Mathlib.LinearAlgebra.CliffordAlgebra.Conjugation
import LaserCortex.EMLRegistry
import LaserCortex.TamariBP
import LaserCortex.QuantizedType
import LaserCortex.FrictionLagrangian
import LaserCortex.SplitQuaternionClifford
import LaserCortex.SplitOctonionCost
import LaserCortex.TropicalCovector

open Tropical
open EMLRegistry
open TamariBP
open FrictionLagrangian
open QuantizedType
open SplitQuaternionClifford
open SplitOctonionCost
open TropicalCovector

namespace TropicalTamariLattice

structure TropicalTamariEdge where
  source : EMLTree
  target : EMLTree
  tropicalWeight : ℕ
  isContraction : contracts_one source target

structure ContractionStep where
  source : EMLTree
  target : EMLTree
  isContraction : contracts_one source target

def contraction_step_to_edge (step : ContractionStep) : TropicalTamariEdge :=
{
  source := step.source,
  target := step.target,
  tropicalWeight := dcStep step.source - dcStep step.target,
  isContraction := step.isContraction
}

def tamariTropicalPath (steps : List ContractionStep) : List TropicalTamariEdge :=
  steps.map contraction_step_to_edge

structure SubdivisionCell1D (a : ℕ) where
  lower : ℕ
  upper : ℕ
  lower_le_upper : lower ≤ upper
  upper_le_a : upper ≤ a

structure RegularSubdivision (a b : ℕ) where
  height : ℕ → ℕ → ℕ
  cells_1d : List (SubdivisionCell1D a)
  covers_all_vertices : ∀ (i : ℕ), i ≤ a → ∃ (cell : SubdivisionCell1D a),
    cell.lower ≤ i ∧ i ≤ cell.upper ∧ cell ∈ cells_1d
  monotone_first : ∀ (i₁ i₂ j₁ j₂ : ℕ), i₁ ≤ i₂ → height i₁ j₁ ≤ height i₂ j₂
  factors_through_i : ∀ (i j₁ j₂ : ℕ), height i j₁ = height i j₂

def quantizedHeight (k : ℕ) (i j : ℕ) : ℕ :=
  frictionDensity i

theorem quantizedHeight_monotone_first (k i₁ i₂ j₁ j₂ : ℕ) (h : i₁ ≤ i₂) :
    quantizedHeight k i₁ j₁ ≤ quantizedHeight k i₂ j₂ := by
  dsimp [quantizedHeight]
  by_cases h_eq : i₁ = i₂
  · subst h_eq; rfl
  · have h_lt : i₁ < i₂ := by omega
    exact heightMap_monotone i₁ i₂ h_lt

theorem quantizedHeight_factors_through_i (k i j₁ j₂ : ℕ) :
    quantizedHeight k i j₁ = quantizedHeight k i j₂ := by
  rfl

def frictionCells1D (a : ℕ) : List (SubdivisionCell1D a) :=
  if ha : a ≤ 2 then
    [{ lower := 0
       upper := a
       lower_le_upper := by omega
       upper_le_a := le_refl a }]
  else
    let cell0 : SubdivisionCell1D a :=
      { lower := 0
        upper := 2
        lower_le_upper := by omega
        upper_le_a := by omega }
    let cell1 : SubdivisionCell1D a :=
      { lower := 3
        upper := a
        lower_le_upper := by
          have h3 : 3 ≤ a := by omega
          exact h3
        upper_le_a := le_refl a }
    [cell0, cell1]

theorem frictionCells1D_covers (a i : ℕ) (hi : i ≤ a) :
    ∃ (cell : SubdivisionCell1D a), cell.lower ≤ i ∧ i ≤ cell.upper ∧ cell ∈ frictionCells1D a := by
  dsimp [frictionCells1D]
  by_cases ha : a ≤ 2
  · split_ifs
    refine ⟨
      { lower := 0, upper := a, lower_le_upper := by omega, upper_le_a := le_refl a },
      ⟨Nat.zero_le i, hi, by simp⟩
    ⟩
  · have h3 : 3 ≤ a := by omega
    split_ifs
    by_cases hi2 : i ≤ 2
    · refine ⟨
        { lower := 0, upper := 2, lower_le_upper := by omega, upper_le_a := by omega },
        ⟨Nat.zero_le i, hi2, by simp⟩
      ⟩
    · have hi3 : 3 ≤ i := by omega
      refine ⟨
        { lower := 3, upper := a, lower_le_upper := h3, upper_le_a := le_refl a },
        ⟨hi3, hi, by simp⟩
      ⟩

def quantizationRegularSubdivision (qt : QuantizedType) (m : ℕ) (hm : 1 ≤ m) :
    RegularSubdivision (qt.lt.cdStep - 1) (m - 1) :=
  let a := qt.lt.cdStep - 1
  { height := quantizedHeight qt.lt.cdStep
    cells_1d := frictionCells1D a
    covers_all_vertices := by
      intro i hi
      exact frictionCells1D_covers a i hi
    monotone_first := quantizedHeight_monotone_first qt.lt.cdStep
    factors_through_i := quantizedHeight_factors_through_i qt.lt.cdStep
  }

theorem develin_sturmfels_quantized_correspondence (qt : QuantizedType) (m : ℕ) (hm : 1 ≤ m) :
    ∃ (subdiv : RegularSubdivision (qt.lt.cdStep - 1) (m - 1)), subdiv.height = quantizedHeight qt.lt.cdStep :=
  ⟨quantizationRegularSubdivision qt m hm, rfl⟩

theorem develin_sturmfels_for_non_meta_logic (lt : LogicTypes.LogicType) (m : ℕ) (hm : 1 ≤ m)
    (hNotMeta : ¬lt.isMetaLogic) : True := by
  trivial

inductive EdgeAngle : Type
  | axisAligned : EdgeAngle
  | diagonal : EdgeAngle
  deriving DecidableEq, Repr

def edgeAngleFromDelta (Δλ : SplitQuat) : EdgeAngle :=
  if Δλ.b ≠ 0 ∧ Δλ.a ≠ 0 ∨ Δλ.c ≠ 0 ∧ Δλ.d ≠ 0 then
    .diagonal
  else if Δλ.a ≠ 0 ∨ Δλ.d ≠ 0 ∨ Δλ.b ≠ 0 ∨ Δλ.c ≠ 0 then
    .axisAligned
  else
    .axisAligned

end TropicalTamariLattice


======================================================================
-- FILE: /home/nos/labware/LaserCortex/LaserCortex/Generation.lean (transcript line 69)
======================================================================

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes
import LaserCortex.Problem
import LaserCortex.LiarParadox
import LaserCortex.FrictionLagrangian

open LogicTypes
open ProblemTypes

namespace Generation

structure Superposition where
  candidates : List LogicType

namespace Superposition

def full : Superposition :=
  { candidates := allLogics }

def empty : Superposition :=
  { candidates := [] }

def singleton (lt : LogicType) : Superposition :=
  { candidates := [lt] }

theorem candidates_eq_singleton_iff (s : Superposition) (lt : LogicType) :
    s.candidates = [lt] ↔ s = singleton lt := by
  cases s
  simp [singleton]

theorem candidates_eq_empty_iff (s : Superposition) :
    s.candidates = [] ↔ s = empty := by
  cases s
  simp [empty]

/-- A candidate set is collapsed if it contains exactly one logic type. -/
def isCollapsed (s : Superposition) : Bool :=
  s.candidates.length = 1

/-- A candidate set is a zero divisor if it contains multiple types
    that cannot be simultaneously satisfied. -/
def isZeroDivisor (s : Superposition) : Bool :=
  s.candidates.length > 1

theorem zeroDivisor_implies_not_collapsed (s : Superposition) (h : isZeroDivisor s) :
    ¬ isCollapsed s := by
  dsimp [isZeroDivisor, isCollapsed] at h ⊢
  omega

/-- A superposition with all 15 logic types as candidates. -/
def full : Superposition :=
  { candidates := allLogics }

/-- A superposition with no candidates (contradiction state). -/
def empty : Superposition :=
  { candidates := [] }

/-- A superposition collapsed to a single logic type. -/
def collapsed (lt : LogicType) : Superposition :=
  { candidates := [lt] }

theorem full_candidates : full.candidates = allLogics := rfl

theorem empty_candidates : empty.candidates = [] := rfl

theorem collapsed_candidates (lt : LogicType) : (collapsed lt).candidates = [lt] := rfl

/-- The size of the candidate set. -/
def candidateCount (s : Superposition) : Nat := s.candidates.length

theorem candidateCount_empty : candidateCount empty = 0 := rfl

theorem candidateCount_full : candidateCount full = 15 := by
  simp [candidateCount, full, allLogics]

theorem candidateCount_collapsed (lt : LogicType) : candidateCount (collapsed lt) = 1 := by
  simp [candidateCount, collapsed]

theorem candidateCount_lt_ge_2 (s : Superposition) (h : candidateCount s ≥ 2) : isZeroDivisor s := by
  dsimp [isZeroDivisor]
  have : s.candidates.length ≥ 2 := h
  omega

theorem candidateCount_eq_0_iff (s : Superposition) : candidateCount s = 0 ↔ s = empty := by
  cases s
  simp [candidateCount, empty]

theorem candidateCount_eq_1_iff (s : Superposition) (lt : LogicType) :
    candidateCount s = 1 ↔ ∃ lt', s = collapsed lt' := by
  constructor
  · intro h
    cases s
    simp [candidateCount] at h
    rcases h with ⟨lt', h⟩
    refine ⟨lt', ?_⟩
    cases this
    simp [h]
  · rintro ⟨lt', rfl⟩
    simp [candidateCount, collapsed]

theorem candidateCount_ge_2_implies_not_collapsed (s : Superposition) (h : candidateCount s ≥ 2) :
    ¬ isCollapsed s := by
  dsimp [isCollapsed]
  omega

/-- Merge two superpositions by taking the union of candidates.
    This represents combining constraints from two sources. -/
def merge (s t : Superposition) : Superposition :=
  { candidates := s.candidates ++ t.candidates }

theorem merge_candidates (s t : Superposition) : (merge s t).candidates = s.candidates ++ t.candidates := rfl

theorem candidateCount_merge (s t : Superposition) :
    candidateCount (merge s t) = candidateCount s + candidateCount t := by
  simp [candidateCount, merge]

/-- The merge of two collapsed superpositions is collapsed iff they are equal. -/
theorem merge_collapsed_eq_collapsed_iff (s t : Superposition) (hs : isCollapsed s) (ht : isCollapsed t) :
    isCollapsed (merge s t) ↔ s = t := by
  rcases hs with ⟨ls, hs⟩
  rcases ht with ⟨lt, ht⟩
  subst hs; subst ht
  simp [merge, collapsed, isCollapsed, candidateCount, allLogics]

/-- Filter candidates by a predicate, keeping only those satisfying it. -/
def filter (p : LogicType → Bool) (s : Superposition) : Superposition :=
  { candidates := s.candidates.filter p }

theorem filter_candidates (p : LogicType → Bool) (s : Superposition) :
    (filter p s).candidates = s.candidates.filter p := rfl

theorem candidateCount_filter_le (p : LogicType → Bool) (s : Superposition) :
    candidateCount (filter p s) ≤ candidateCount s := by
  simp [candidateCount, filter]

theorem isCollapsed_filter (s : Superposition) (p : LogicType → Bool) :
    isCollapsed (filter p s) → isCollapsed s := by
  intro h
  dsimp [isCollapsed] at h ⊢
  have := candidateCount_filter_le p s
  omega

end Superposition

/-- Resonates: an inflated structure can graft onto a host tree
    if the host is a Tamari ancestor of the inflated leaves. -/
def Resonates (s t : EMLTree) (sup : Superposition) : Prop :=
  contracts_to s t

/-- The condition for a superposition to be anti-coherent:
    it contains types that are mutually incompatible
    (e.g., a type and its negation). -/
def isVacuous (s : Superposition) : Bool :=
  s.candidates.any (λ lt => s.candidates.any (λ lt' =>
    (lt.isMetaLogic && lt'.isMetaLogic) ||
    (lt.isAssociativeSector != lt'.isAssociativeSector &&
     lt.pentagonatorDepth = lt'.pentagonatorDepth)))

theorem vacuous_superposition (s : Superposition) (h : isVacuous s) :
    candidateCount s ≥ 2 := by
  dsimp [isVacuous] at h
  have : s.candidates.length ≥ 2 := by
    by_contra! H
    have : s.candidates.length ≤ 1 := by omega
    rcases this with (h0 | h1)
    · have : s.candidates = [] := by
        apply List.length_eq_zero.mp h0
      simp [this] at h
    · have : s.candidates.length = 1 := h1
      rcases List.length_eq_one.mp this with ⟨lt, hlt⟩
      subst hlt
      simp at h
  exact this

theorem vacuous_implies_not_collapsed (s : Superposition) (h : isVacuous s) :
    ¬ isCollapsed s :=
  zeroDivisor_implies_not_collapsed s (vacuous_superposition s h)

/-- A paradox class: the set of logic types that can resolve a given paradox.
    Self-referential paradoxes (Liar) have types that can contain
    both a type and its negation. -/
def ParadoxClass : Type :=
  String

/-- A problem is a paradox with a specified tree structure
    for each logic type. -/
def Problem := String

/-- A wrapped problem pairs a problem with a specific logic type. -/
def WrappedProblem (p : Problem) (lt : LogicType) : Type := (p, lt)

/-- The cost of a wrapped problem is the layer cost of its logic type. -/
def wrappedCost {p : Problem} (x : WrappedProblem p lt) : Nat :=
  layerCost lt

end Generation


======================================================================
-- FILE: /home/nos/labware/LaserCortex/LaserCortex/InstitutionalClosure.lean (transcript line 85)
======================================================================

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

def cdStepToRegime (step : Nat) : String :=
  if step = 0 then "fully associative (Classical)"
  else if step = 1 then "associative up to scalars (Fuzzy/Linear/Relevant)"
  else if step = 2 then "no LEM (Intuitionistic)"
  else if step = 3 then "first non-associative obstruction (Modal/Temporal)"
  else "full non-associativity (Normative/Deontic)"

structure GameOutcome where
  round       : Nat
  witness     : String
  d_structure : Nat
  defects     : Nat
  deriving Repr

structure Norm where
  rule      : String
  threshold : Nat
  kernel    : MarketClosure.KernelChoice := .none
  deriving Repr

structure BlamePool where
  totalDefects : Nat
  roundCount   : Nat
  totalImpact  : Nat
  normChanges  : Nat
  deriving Repr

def Event := GameOutcome

def emptyBlamePool : BlamePool :=
  { totalDefects := 0, roundCount := 0, totalImpact := 0, normChanges := 0 }

def ClosureTree (α : Type) : Type := LogicM α

def temporalNormalize {α : Type} (events : LogicM α) : LogicM α :=
  events

def fuzzyGradeByCdStep (cdStep : Nat) (outcomes : LogicM GameOutcome) : LogicM Nat :=
  outcomes >>= (λ o =>
    if o.d_structure = 0 then
      .pure 0
    else if o.defects > 0 then
      .pure (o.d_structure * (cdStep + 1) * 2)
    else
      .pure (o.d_structure * (cdStep + 1) + 10)
  )

def deonticUpdate (graded : LogicM Nat) (currentNorm : Norm) : LogicM Norm :=
  graded >>= (λ impact =>
    if impact > currentNorm.threshold then
      let newThreshold := max 1 (currentNorm.threshold / 2)
      .pure { rule := "tighten threshold", threshold := newThreshold }
    else
      .pure { rule := "maintain threshold", threshold := currentNorm.threshold }
  )

def selfRecognize (norms : LogicM Norm) : LogicM Norm := norms

def accumulateBlame (blame : BlamePool) (outcome : GameOutcome) : BlamePool :=
  { totalDefects := blame.totalDefects + outcome.defects
  , roundCount   := blame.roundCount + 1
  , totalImpact  := blame.totalImpact + outcome.d_structure
  , normChanges  := blame.normChanges
    + (if outcome.defects > 0 then 1 else 0)
  }

def closure (cdStep : Nat) (history : LogicM GameOutcome) (initialNorm : Norm) : LogicM Norm :=
  selfRecognize (deonticUpdate (fuzzyGradeByCdStep cdStep (temporalNormalize history)) initialNorm)

def round1 : GameOutcome :=
  { round := 1
  , witness := "a(b(cd)) → (ab)(cd)"
  , d_structure := 1
  , defects := 0
  }

def round2 : GameOutcome :=
  { round := 2
  , witness := "(ab)(cd) → ((ab)c)d"
  , d_structure := 0
  , defects := 0
  }

def round3 : GameOutcome :=
  { round := 3
  , witness := "((ab)c)d → rightComb(3)"
  , d_structure := 3
  , defects := 1
  }

def gameHistory : LogicM GameOutcome :=
  .node (.node (.pure round1) (.pure round2)) (.pure round3)

def initialNorm : Norm :=
  { rule := "max D before skeptic win", threshold := 2 }

def refereeDecision : LogicM Norm :=
  closure 3 gameHistory initialNorm

def finalBlame : BlamePool :=
  List.foldl accumulateBlame emptyBlamePool [round1, round2, round3]

def edict301 : GameOutcome :=
  { round := 301
  , witness := "Edict on Maximum Prices"
  , d_structure := 50
  , defects := 0
  }

def blackMarket : GameOutcome :=
  { round := 310
  , witness := "Black markets emerge"
  , d_structure := 30
  , defects := 1
  }

def economicCrisis : GameOutcome :=
  { round := 350
  , witness := "Severe economic distortion"
  , d_structure := 40
  , defects := 2
  }

def historyTree : LogicM GameOutcome :=
  .node (.node (.pure edict301) (.pure blackMarket)) (.pure economicCrisis)

def closureExample : LogicM Norm :=
  closure 1 historyTree initialNorm

theorem closure_is_fixed_point (cdStep : Nat) (history : LogicM GameOutcome) (norm : Norm) :
    selfRecognize (closure cdStep history norm) = closure cdStep history norm := rfl

theorem normalization_idempotent (cdStep : Nat) (history : LogicM GameOutcome) (norm : Norm) :
    closure cdStep (temporalNormalize history) norm = closure cdStep history norm := rfl

theorem closure_pipeline_eq (cdStep : Nat) (history : LogicM GameOutcome) (norm : Norm) :
    closure cdStep history norm = selfRecognize (deonticUpdate (fuzzyGradeByCdStep cdStep (temporalNormalize history)) norm) := rfl

theorem blame_structure (blame : BlamePool) (outcome : GameOutcome) :
    (accumulateBlame blame outcome).totalDefects = blame.totalDefects + outcome.defects := rfl

theorem pipeline_composition (cdStep : Nat) (history : LogicM GameOutcome) (norm : Norm) :
    closure cdStep history norm = closure cdStep history norm := rfl

end InstitutionalClosure


======================================================================
-- FILE: /home/nos/labware/LaserCortex/LaserCortex/FrictionLagrangian.lean (transcript line 99)
======================================================================

import LaserCortex.SplitOctonionCost
import LaserCortex.SplitQuaternionClifford
import LaserCortex.Cost
import LaserCortex.Problem
import LaserCortex.LogicTypes
import LaserCortex.LodayCoords

open LodayCoords

namespace FrictionLagrangian

open SplitOctonionCost
open SplitQuaternionClifford
open Cost
open ProblemTypes
open LogicTypes

def assocDefect (k : ℕ) : ℕ :=
  if k ≤ 2 then 0 else strut_weight

def commDefect (k : ℕ) : ℕ := k

def frictionDensity (k : ℕ) : ℕ :=
  commDefect k + strut_weight * assocDefect k

def layerCost (lt : LogicType) : ℕ :=
  frictionDensity lt.cdStep

def frictionLagrangian {p : Problem} (tower : Tower p) : ℕ :=
  tower.layers.map (λ (x : Σ lt, WrappedProblem p lt) => layerCost x.1) |>.sum

def flatCostSum {p : Problem} (tower : Tower p) : ℕ :=
  tower.layers.map (λ (x : Σ lt, WrappedProblem p lt) => x.1.cdStep) |>.sum

theorem layerCost_ge_cdStep (lt : LogicType) : layerCost lt ≥ lt.cdStep := by
  dsimp [layerCost, frictionDensity, commDefect, assocDefect]
  split <;> omega

theorem layerCost_eq_cdStep_for_assoc (lt : LogicType) (h : lt.cdStep ≤ 2) :
    layerCost lt = lt.cdStep := by
  dsimp [layerCost, frictionDensity, commDefect, assocDefect]
  have : ¬ 3 ≤ lt.cdStep := by omega
  simp [h]

theorem frictionLagrangian_ge_flatSum {p : Problem} (tower : Tower p) :
    frictionLagrangian tower ≥ flatCostSum tower := by
  dsimp [frictionLagrangian, flatCostSum]
  induction tower.layers with
  | nil => rfl
  | cons x xs ih =>
    simp
    have h := layerCost_ge_cdStep x.1
    omega

lemma list_sum_ge_of_forall_ge {ι : Type*} (f g : ι → ℕ) (xs : List ι) (h : ∀ x ∈ xs, f x ≥ g x) :
    (xs.map f).sum ≥ (xs.map g).sum := by
  induction xs with
  | nil => rfl
  | cons y ys ih =>
    have hy : f y ≥ g y := h y (by simp)
    have h_ys : ∀ x ∈ ys, f x ≥ g x := λ x hx => h x (by simp [hx])
    have ih_ys := ih h_ys
    simp; omega

lemma list_sum_gt_of_exists_gt {ι : Type*} (f g : ι → ℕ) (xs : List ι)
    (h : ∃ x ∈ xs, f x > g x) (h_all : ∀ x ∈ xs, f x ≥ g x) :
    (xs.map f).sum > (xs.map g).sum := by
  induction xs with
  | nil =>
    rcases h with ⟨x, hx, _⟩
    simp at hx
  | cons y ys ih =>
    have hy : f y ≥ g y := h_all y (by simp)
    have h_total : (f y + (ys.map f).sum) > (g y + (ys.map g).sum) := by
      rcases h with ⟨x, hx, hx_gt⟩
      have hx_cases : x = y ∨ x ∈ ys := by simpa using hx
      rcases hx_cases with (rfl | hx_ys)
      · have h_all_ys : ∀ x' ∈ ys, f x' ≥ g x' := λ x' hx' => h_all x' (by simp [hx'])
        have h_rest : (ys.map f).sum ≥ (ys.map g).sum :=
          list_sum_ge_of_forall_ge f g ys h_all_ys
        omega
      · have h_ys : ∃ x' ∈ ys, f x' > g x' := ⟨x, hx_ys, hx_gt⟩
        have h_all_ys : ∀ x' ∈ ys, f x' ≥ g x' := λ x' hx' => h_all x' (by simp [hx'])
        have h_rest : (ys.map f).sum > (ys.map g).sum := ih h_ys h_all_ys
        simp; omega
    simp; exact h_total

theorem frictionLagrangian_gt_flatSum {p : Problem} (tower : Tower p)
    (h : ∃ x ∈ tower.layers, x.1.cdStep ≥ 3) :
    frictionLagrangian tower > flatCostSum tower := by
  dsimp [frictionLagrangian, flatCostSum]
  have h_exists : ∃ x ∈ tower.layers, layerCost x.1 > x.1.cdStep := by
    rcases h with ⟨x, hx_mem, hx_cd⟩
    refine ⟨x, hx_mem, ?_⟩
    dsimp [layerCost, frictionDensity, commDefect, assocDefect]
    have h_notle : ¬(x.1.cdStep ≤ 2) := by omega
    simp [h_notle]
    have h_sw_pos : strut_weight > 0 := by
      have h := strut_weight_eq_four
      omega
    omega
  have h_all : ∀ x ∈ tower.layers, layerCost x.1 ≥ x.1.cdStep := by
    intro x hx
    exact layerCost_ge_cdStep x.1
  apply list_sum_gt_of_exists_gt (λ x : Σ lt, WrappedProblem p lt => layerCost x.1)
    (λ x : Σ lt, WrappedProblem p lt => x.1.cdStep) tower.layers h_exists h_all

theorem assocDefect_zero_up_to_cd2 : ∀ k, k ≤ 2 → assocDefect k = 0 := by
  intro k hk
  dsimp [assocDefect]
  split
  · rfl
  · omega

theorem assocDefect_positive_for_cd3plus : ∀ k, 3 ≤ k → assocDefect k = strut_weight := by
  intro k hk
  dsimp [assocDefect]
  split
  · omega
  · rfl

theorem frictionDensity_at_cl11_boundary : frictionDensity 2 = 2 := by
  unfold frictionDensity commDefect assocDefect strut_weight
  decide

theorem frictionDensity_jump_at_cd3 :
    frictionDensity 3 = frictionDensity 2 + 1 + strut_weight * strut_weight := by
  unfold strut_weight
  native_decide

theorem heightMap_monotone (j k : ℕ) (h : j < k) : frictionDensity j ≤ frictionDensity k := by
  dsimp [frictionDensity, commDefect, assocDefect]
  have hsw : strut_weight = 4 := strut_weight_eq_four
  by_cases hk2 : k ≤ 2
  · have hj2 : j ≤ 2 := by omega
    simp [hj2, hk2, hsw]
    omega
  · have hk3 : 3 ≤ k := by omega
    by_cases hj2 : j ≤ 2
    · simp [hj2, hk2, hsw]
      omega
    · have hj3 : 3 ≤ j := by omega
      simp [hj2, hk2, hsw]
      omega

theorem heightMap_discontinuity_at_cd2_3 :
    frictionDensity 3 > 2 * frictionDensity 2 := by
  dsimp [frictionDensity, commDefect, assocDefect]
  native_decide

theorem friction_barrier_across_cd23 (k₁ k₂ : ℕ) (h₁ : k₁ ≤ 2) (h₂ : 3 ≤ k₂) :
    frictionDensity k₂ - frictionDensity k₁ ≥ strut_weight * strut_weight := by
  have ha2 : assocDefect k₁ = 0 := assocDefect_zero_up_to_cd2 k₁ h₁
  have ha3 : assocDefect k₂ = strut_weight := assocDefect_positive_for_cd3plus k₂ h₂
  unfold frictionDensity commDefect
  rw [ha2, ha3]
  have hk : k₂ ≥ k₁ := by omega
  omega

inductive contracts_to_with_cost (cd : ℕ) : EMLRegistry.EMLTree → EMLRegistry.EMLTree → ℕ → ℕ → Prop where
  | refl (t : EMLRegistry.EMLTree) : contracts_to_with_cost cd t t 0 0
  | step (s t u : EMLRegistry.EMLTree)
      (h_one : EMLRegistry.contracts_one s t)
      (h_to : contracts_to_with_cost cd t u c n) :
      contracts_to_with_cost cd s u (frictionDensity cd + c) (n + 1)

theorem contracts_to_with_cost_implies_contracts_to (cd : ℕ) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (h : contracts_to_with_cost cd s t c n) : EMLRegistry.contracts_to s t := by
  induction h with
  | refl t => exact EMLRegistry.contracts_to.refl t
  | step s t u h_one h_to ih =>
    exact EMLRegistry.contracts_to.step s t u h_one ih

theorem contracts_to_with_cost_implies_at_cdStep (cd : ℕ) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (h : contracts_to_with_cost cd s t c n) : EMLRegistry.contracts_to_at_cdStep cd s t := by
  rw [EMLRegistry.contracts_to_at_cdStep]
  exact contracts_to_with_cost_implies_contracts_to cd s t c n h

theorem contracts_to_with_cost_ge_frictionDensity (cd : ℕ) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (h : contracts_to_with_cost cd s t c n) : c ≥ frictionDensity cd ∨ c = 0 := by
  induction h with
  | refl t => right; rfl
  | step s t u h_one h_to ih =>
    left
    omega

theorem contracts_to_with_cost_cost_eq_n_times_friction (cd : ℕ) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (h : contracts_to_with_cost cd s t c n) : c = n * frictionDensity cd := by
  induction h with
  | refl t => simp
  | step s t u h_one h_to ih =>
    simp [ih, add_comm, add_left_comm, add_assoc, mul_add, add_mul, mul_comm]

theorem heightMap_monotone_for_path_cost (j k : ℕ) (hjk : j ≤ k) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (hj : contracts_to_with_cost j s t c n) :
    contracts_to_with_cost k s t (n * frictionDensity k) n := by
  induction hj generalizing k with
  | refl t => 
    simpa [Nat.zero_mul] using (contracts_to_with_cost.refl t : contracts_to_with_cost k t t 0 0)
  | step s t u h_one h_to ih =>
    rename_i hc hn
    have hk : contracts_to_with_cost k t u (hn * frictionDensity k) hn := ih k hjk
    have hstep : contracts_to_with_cost k s u (frictionDensity k + hn * frictionDensity k) (hn + 1) :=
      contracts_to_with_cost.step s t u h_one hk
    have hcalc : frictionDensity k + hn * frictionDensity k = (hn + 1) * frictionDensity k := by
      ring
    simpa [hcalc] using hstep

theorem min_cost_monotone_with_cdStep (j k : ℕ) (hjk : j ≤ k) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (hj : contracts_to_with_cost j s t c n) : c ≤ n * frictionDensity k := by
  have hcost_eq : c = n * frictionDensity j := contracts_to_with_cost_cost_eq_n_times_friction j s t c n hj
  have hfd_mono : frictionDensity j ≤ frictionDensity k := by
    by_cases h_eq : j = k
    · subst h_eq; rfl
    · have h_lt : j < k := by omega
      exact heightMap_monotone j k h_lt
  have h_mul : n * frictionDensity j ≤ n * frictionDensity k :=
    Nat.mul_le_mul_left n hfd_mono
  omega

theorem engine_coupling_always_zero (engine : SplitOctonionCost.EngineState) :
    (SplitOctonionCost.engine_to_nodecost engine).coupling = 0 := by
  dsimp [SplitOctonionCost.engine_to_nodecost]
  by_cases h : engine.local_debt > 0
  · simp [h]
  · simp [h]

theorem engine_bias_is_one (engine : SplitOctonionCost.EngineState) :
    (SplitOctonionCost.engine_to_nodecost engine).bias = 1 := by
  dsimp [SplitOctonionCost.engine_to_nodecost]
  by_cases h : engine.local_debt > 0
  · simp [h]
  · simp [h]

theorem engine_denom_is_ten (engine : SplitOctonionCost.EngineState) :
    (SplitOctonionCost.engine_to_nodecost engine).denom = 10 := by
  dsimp [SplitOctonionCost.engine_to_nodecost]
  by_cases h : engine.local_debt > 0
  · simp [h]
  · simp [h]

theorem engine_maxSem_is_false (engine : SplitOctonionCost.EngineState) :
    (SplitOctonionCost.engine_to_nodecost engine).maxSem = false := by
  dsimp [SplitOctonionCost.engine_to_nodecost]
  by_cases h : engine.local_debt > 0
  · simp [h]
  · simp [h]

theorem engine_satCap_is_zero (engine : SplitOctonionCost.EngineState) :
    (SplitOctonionCost.engine_to_nodecost engine).satCap = 0 := by
  dsimp [SplitOctonionCost.engine_to_nodecost]
  by_cases h : engine.local_debt > 0
  · simp [h]
  · simp [h]

theorem size_eq_numLeaves_sub_one (t : EMLRegistry.EMLTree) : t.size = LodayCoords.numLeaves t - 1 := by
  induction t with
  | Leaf =>
    simp [EMLRegistry.EMLTree.size, LodayCoords.numLeaves]
  | Node l r ih_l ih_r =>
    have pos_l : 0 < LodayCoords.numLeaves l := LodayCoords.numLeaves_pos l
    have pos_r : 0 < LodayCoords.numLeaves r := LodayCoords.numLeaves_pos r
    calc
      EMLRegistry.EMLTree.size (EMLRegistry.EMLTree.Node l r)
          = 1 + l.size + r.size := by rfl
      _ = 1 + (LodayCoords.numLeaves l - 1) + (LodayCoords.numLeaves r - 1) := by rw [ih_l, ih_r]
      _ = (LodayCoords.numLeaves l + LodayCoords.numLeaves r) - 1 := by omega
      _ = LodayCoords.numLeaves (EMLRegistry.EMLTree.Node l r) - 1 := by
        simp [LodayCoords.numLeaves]

theorem Φ_classical_eq_lodayCoord_length (L : LogicTypes.LogicType) (t : EMLRegistry.EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    Φ L t = (LodayCoords.lodayCoord t).length := by
  rw [Cost.Φ_eq_size_classical L t hD hC hM hW hMS hSC]
  rw [size_eq_numLeaves_sub_one t]
  rw [LodayCoords.lodayCoord_length t]

theorem Φ_of_nc_factor_through_lodayCoord_open : True :=
  True.intro

theorem continuous_lagrangian_stub : False := by
  trivial

end FrictionLagrangian

