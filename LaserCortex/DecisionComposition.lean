
/-
# Module: DecisionComposition

## Intent

Implements a compile-time refinement type system for chaining logic modalities as gates, guaranteeing data preservation and proof-bound soundness across EMLTree evaluations.

## Contracts

Gate.ofLogicType, Gate.check, Decision.empty, Decision.singleton, Decision.compose, Decision.composeOf, LogicPipeline.run, LogicPipeline.runAux, closurePipeline, decide, soundness, closure_sound, decide_sound

## Cross-refs

LaserCortex.EMLRegistry → EMLTree, LogicM, Event, Norm; LaserCortex.LogicTypes → LogicType, LogicContraction, logic_contracts_to_normal_form; LaserCortex.InstitutionalClosure → InstitutionalClosure.closure

## Invariants

∀ g ∈ gates, g.check datum (type-level gate refinement); (d.compose g h).datum = d.datum (datum immutability); (p.run tree).datum = tree (pipeline identity preservation); soundness/closure_sound/decide_sound enforce logical validity of all passed gates.

## Tags

#lean4-theorem #invariant #proof-bound

-/

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes
import LaserCortex.LogicMonad
import LaserCortex.LiarParadox
import LaserCortex.InstitutionalClosure

open EMLRegistry
open LogicMonad
open LiarParadox
open InstitutionalClosure

/-! # DecisionComposition — Public API

Binary decision composition with type-level gate tracking.

The key idea from the decision support specification:
**the type signature IS the channel** — data carries a compile-time
proof of which gates it has passed, and downstream functions require
that proof.
-/

namespace DecisionComposition

-- ================================================================
-- Gate: a binary decision function indexed by logic modality
-- ================================================================

structure Gate where
  name      : String
  modality  : LogicTypes.LogicType
  check     : EMLTree → Prop

def Gate.ofLogicType (lt : LogicTypes.LogicType) : Gate :=
  {
    name     := lt.name
    modality := lt
    check    := λ tree => LogicTypes.LogicContraction lt tree (LogicTypes.LogicNormalForm lt tree.size)
  }

theorem Gate.check_ofLogicType (lt : LogicTypes.LogicType) (tree : EMLTree) :
    (Gate.ofLogicType lt).check tree :=
  LogicTypes.logic_contracts_to_normal_form lt tree

-- ================================================================
-- Decision: datum + proof of gate passage (refinement type)
-- ================================================================

structure Decision (gates : List Gate) where
  datum   : EMLTree
  proof   : ∀ (g : Gate), g ∈ gates → g.check datum

def Decision.empty (tree : EMLTree) : Decision [] where
  datum := tree
  proof := by
    intro g h
    simp at h

def Decision.singleton (tree : EMLTree) (g : Gate) (h : g.check tree) : Decision [g] where
  datum := tree
  proof := by
    intro g' hmem
    simp at hmem
    subst hmem
    exact h

def Decision.singletonOf (tree : EMLTree) (lt : LogicTypes.LogicType) : Decision [Gate.ofLogicType lt] :=
  Decision.singleton tree (Gate.ofLogicType lt) (Gate.check_ofLogicType lt tree)

-- ================================================================
-- Compose: chain a gate, augmenting the type
-- ================================================================

def Decision.compose {gates : List Gate} (d : Decision gates) (g : Gate)
    (h : g.check d.datum) : Decision (g :: gates) :=
  {
    datum := d.datum
    proof := by
      intro g' hmem
      simp at hmem
      rcases hmem with (rfl | hmemTail)
      · exact h
      · exact d.proof g' hmemTail
  }

def Decision.composeOf (d : Decision gates) (lt : LogicTypes.LogicType) : Decision (Gate.ofLogicType lt :: gates) :=
  d.compose (Gate.ofLogicType lt) (Gate.check_ofLogicType lt d.datum)

theorem Decision.datum_compose {gates : List Gate} (d : Decision gates) (g : Gate)
    (h : g.check d.datum) : (d.compose g h).datum = d.datum := rfl

theorem Decision.datum_empty (tree : EMLTree) : (Decision.empty tree).datum = tree := rfl

-- ================================================================
-- LogicPipeline: a pipeline over a list of logic types
-- ================================================================

structure LogicPipeline where
  logics : List LogicTypes.LogicType
  name   : String

/-- The gates of a LogicPipeline (derived). -/
def LogicPipeline.gates (p : LogicPipeline) : List Gate :=
  p.logics.map Gate.ofLogicType

/-- Auxiliary: run a list of logics as gates on a tree.
  Returns a Sigma type pairing the Decision with a proof that its
  datum equals the input tree. This lets composition use the tree's
  gate checks via rewriting. -/
def LogicPipeline.runAux (logics : List LogicTypes.LogicType) (tree : EMLTree) :
    { d : Decision (logics.map Gate.ofLogicType) // d.datum = tree } :=
  match logics with
  | [] =>
    ⟨Decision.empty tree, rfl⟩
  | lt :: lts =>
    let ⟨rest, hDatum⟩ := LogicPipeline.runAux lts tree
    have hCheckRest : (Gate.ofLogicType lt).check rest.datum := by
      rw [hDatum]
      exact Gate.check_ofLogicType lt tree
    have hCast : (Gate.ofLogicType lt :: (lts.map Gate.ofLogicType)) = ((lt :: lts).map Gate.ofLogicType) := by
      simp
    let composed : Decision (Gate.ofLogicType lt :: (lts.map Gate.ofLogicType)) :=
      rest.compose (Gate.ofLogicType lt) hCheckRest
    have hDatumCast : (hCast ▸ composed).datum = tree := by
      calc
        (hCast ▸ composed).datum = composed.datum := by simp
        _ = rest.datum := by
          simp [composed, Decision.datum_compose]
        _ = tree := hDatum
    ⟨hCast ▸ composed, hDatumCast⟩

/-- Run a LogicPipeline on a tree, producing a Decision. -/
def LogicPipeline.run (p : LogicPipeline) (tree : EMLTree) : Decision (p.logics.map Gate.ofLogicType) :=
  (LogicPipeline.runAux p.logics tree).1

theorem LogicPipeline.run_datum (p : LogicPipeline) (tree : EMLTree) :
    (p.run tree).datum = tree :=
  (LogicPipeline.runAux p.logics tree).2

-- ================================================================
-- Institutional closure as a LogicPipeline
-- ================================================================

/-- The institutional closure as a LogicPipeline. -/
def closurePipeline : LogicPipeline :=
  {
    logics := [.Temporal, .Fuzzy, .Deontic]
    name := "institutional_closure"
  }

-- ================================================================
-- Theorems: compile-time contracts
-- ================================================================

theorem soundness (d : Decision gates) (g : Gate) (mem : g ∈ gates) : g.check d.datum :=
  d.proof g mem

theorem closure_sound (tree : EMLTree) (g : Gate) (mem : g ∈ LogicPipeline.gates closurePipeline) : g.check tree := by
  have h := (closurePipeline.run tree).proof g mem
  have hDatum : (closurePipeline.run tree).datum = tree := LogicPipeline.run_datum closurePipeline tree
  simpa [hDatum] using h

-- ================================================================
-- Entry point: decide
-- ================================================================

/-- Run the full institutional closure pipeline on LogicM GameOutcome.
  Default cdStep = 1 (Fuzzy regime — graded evaluation suitable for
  meta-reasoning auditor aggregation). -/
def decide (events : LogicM GameOutcome) : Decision (closurePipeline.logics.map Gate.ofLogicType) :=
  let norm : LogicM Norm :=
    InstitutionalClosure.closure 1 events { rule := "gate closure threshold", threshold := 10 }
  closurePipeline.run (norm.toEMLTree)

theorem decide_sound (events : LogicM Event) (g : Gate) (mem : g ∈ LogicPipeline.gates closurePipeline) :
    g.check (decide events).datum :=
  (decide events).proof g mem


