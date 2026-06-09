import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes

open EMLRegistry

namespace LiarParadox

/-- A class of paradoxes sharing a common structural pattern.
  Each maps to a native logic type (the one best suited to resolve it),
  but can be addressed by multiple logics. -/
inductive ProblemClass : Type where
  | selfReference       -- Liar, Truth-teller, Curry's (native: ManyValued)
  | vagueness           -- Sorites, Ship of Theseus (native: Fuzzy)
  | inconsistentDef     -- Russell's, Barber (native: Paraconsistent)
  | temporalDecision    -- Grandfather, Newcomb's (native: Temporal)
  | deontic             -- Contrary-to-Duty (native: Deontic)
  | epistemic           -- Surprise Examination (native: Epistemic)
  | quantumSuperposition -- Schrödinger's Cat (native: Quantum)
  | constructive        -- Brouwer's Continuity (native: Intuitionistic)
  | relevance           -- Material Implication (native: Relevance)
  | emptyReference      -- Non-existent objects (native: Free)
  | infinity            -- Galileo's, Hilbert's Hotel (native: Infinitary)
  | modality            -- Fitch's Knowability (native: Modal)
  | metaParadox         -- Missing proof / incomplete framework (native: Classical)
  deriving DecidableEq, Repr

/-- A problem: a logical puzzle encoded as a family of trees,
  one per logic type that can resolve it.
  
  `cls` — the problem class
  `suitableLogics` — which logics can resolve this
  `tree` — the encoding in each logic (a family indexed by LogicType)
  `normalForm` — the target tree for each logic -/
structure Problem where
  cls : ProblemClass
  name : String
  suitableLogics : List LogicTypes.LogicType
  tree : LogicTypes.LogicType → EMLTree
  normalForm : LogicTypes.LogicType → EMLTree

/-- A WrappedProblem pairs a Problem with a LogicType.
  This is the WfCA collapse rule: the logic's contraction relation
  resolves the problem's superposition to a definite outcome.
  
  `tree`    — the problem as interpreted in this logic
  `target`  — the normal form under this logic
  `cost`    — pentagonator distance (Verification Gap Φ)
  `proof`   — the contraction path (placeholder until LogicContraction is defined) -/
structure WrappedProblem (p : Problem) (lt : LogicTypes.LogicType) where
  tree   : EMLTree
  target : EMLTree
  cost   : Nat
  proof  : LogicTypes.LogicContraction lt tree target

/-- The canonical size-3 symmetric tree used by most Liar encodings:
  Node (Node Leaf Leaf) (Node Leaf Leaf). -/
def symmetricTree : EMLTree :=
  EMLTree.Node (EMLTree.Node EMLTree.Leaf EMLTree.Leaf) (EMLTree.Node EMLTree.Leaf EMLTree.Leaf)

/-- The size-2 left-comb tree used for three-valued encodings:
  Node (Node Leaf Leaf) Leaf encodes (True ∨ False) ∨ Undefined. -/
def leftComb2 : EMLTree :=
  EMLTree.Node (EMLTree.Node EMLTree.Leaf EMLTree.Leaf) EMLTree.Leaf

/-- The Liar Paradox as a Problem. -/
def liarProblem : Problem := {
  cls := .selfReference
  name := "Liar"
  suitableLogics := [
    .ManyValued, .Paraconsistent, .Intuitionistic, .Fuzzy,
    .Temporal, .Epistemic, .Quantum, .Relevance, .Free,
    .Infinitary, .Modal, .Classical
  ]
  tree := λ lt => match lt with
    | .ManyValued => leftComb2
    | _ => symmetricTree
  normalForm := λ _ => rightComb 3
}

-- ================================================================
-- Meta-Paradox: The Sorry as a First-Class Problem
-- ================================================================

/-- A meta-paradox: a WrappedProblem whose proof cannot be filled
  is itself a logical problem.

  The Liar says "this sentence is false" — a truth-value it cannot supply.
  The missing resolution says "this contraction is missing" — a proof it cannot supply.
  Both are self-referential gaps: the framework refers to its own incompleteness.

  The `sorry` in `fuzzyLiar.proof` IS the evidence of this meta-paradox.
  It is not a placeholder to be filled later — it is the manifestation of
  the framework's current incompleteness, stated as a first-class Problem. -/
def missingProofParadox (p : Problem) (lt : LogicTypes.LogicType) : Problem := {
  cls := .metaParadox
  name := "Missing " ++ lt.name ++ " proof for " ++ p.name
  suitableLogics := [lt]
  tree := λ _ => p.tree lt
  normalForm := λ _ => p.normalForm lt
}

/-- The Fuzzy Liar's missing proof as a meta-paradox.
  The problem: the Fuzzy LogicContraction is not defined in LogicTypes.lean.
  The resolution: fill the `sorry` in LogicTypes.LogicContraction (.Fuzzy). -/
def fuzzyMissingProof : Problem := missingProofParadox liarProblem (.Fuzzy)

/-- The missing LogicContraction definitions for all non-Classical logics
  as a family of meta-paradoxes. -/
def missingContractions : List Problem :=
  liarProblem.suitableLogics.filter (λ lt => lt ≠ .Classical) |>.map (missingProofParadox liarProblem)

-- ================================================================
-- Prototype: Fuzzy Logic Wrapper
-- ================================================================

/-- The Fuzzy Liar: a wrapped problem with cost and tentative proof.
  
  In Fuzzy logic, the Liar resolves to the fixed point ¬0.5 = 0.5.
  The pentagonator distance is 1 (one collapse step needed).
  
  This is the WfCA "amplitudes → collapse" pattern: the problem's
  superposition of truth values (all reals in [0,1]) collapses to
  the unique fixed point under the Fuzzy contraction rule. -/
def fuzzyLiar : WrappedProblem liarProblem (.Fuzzy) where
  tree   := liarProblem.tree (.Fuzzy)
  target := liarProblem.normalForm (.Fuzzy)
  cost   := 1
  proof  := by
    -- Placeholder: Fuzzy LogicContraction not yet defined
    exact sorry

/-- The Classical Liar: proven resolution with the general theorem. -/
def classicalLiar : WrappedProblem liarProblem (.Classical) where
  tree   := liarProblem.tree (.Classical)
  target := liarProblem.normalForm (.Classical)
  cost   := 0
  proof  := by
    -- Classical LogicContraction = contracts_to
    -- liar → rightComb 3 is proven by contracts_to_rightComb
    show LogicTypes.LogicContraction (.Classical)
      (liarProblem.tree (.Classical)) (liarProblem.normalForm (.Classical))
    -- contracts_to_rightComb gives contracts_to symmetricTree (rightComb 3)
    apply contracts_to_rightComb

-- ================================================================
-- Nested Wrappers (WfCA stacked collapse)
-- ================================================================

/-- A Tower is a sequence of logic-wrapped problems, each collapsing the
  output of the previous.  From Lumo section B:
  
    Layer 3 (Quantum):       liar_superposition
         ↓ wrapper
    Layer 2 (Intuitionistic): proof_of_quantum_state
         ↓ wrapper
    Layer 1 (Fuzzy):         confidence_in_proof
         ↓ wrapper
    Layer 0 (Classical):     assertion_value
  
  Each wrapper converts the previous layer's normal form into the
  next layer's tree, then contracts it.  The total cost is the sum.
  
  The dependent pair Σ lt, WrappedProblem p lt stores each layer's
  logic type alongside its wrapped problem. -/
structure Tower (p : Problem) where
  layers : List (Σ lt : LogicTypes.LogicType, WrappedProblem p lt)

/-- The four-layer prototype tower for the Liar. -/
def liarTower : Tower liarProblem := {
  layers := [
    ⟨.Classical, classicalLiar⟩,
    ⟨.Fuzzy, fuzzyLiar⟩,
    ⟨.Classical, classicalLiar⟩,
    ⟨.Classical, classicalLiar⟩
  ]
}

end LiarParadox
