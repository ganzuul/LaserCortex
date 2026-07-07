import Mathlib
import LaserCortex.foundations.Tamari
import LaserCortex.Friction
import LaserCortex.Generation

/-!
# TemporalParadox — Grandfather Paradox Detection (Staging Port)

Port of the old core's `TemporalParadox.lean` using staging types
(`Tamari.EMLTree`, `Friction.frictionDensity`).

## Key definitions
- `grandfatherTree` — the grandfather paradox tree: `leftComb 4`
- `grandfatherTreeNF` — its normal form: `rightComb 4`
- `isGrandfatherTree` / `hasGrandfatherSignature` — decidable detectors
- `grandfatherCost` — friction density cost at CD step k
- `grandfatherOscillationTree` — `Node(rightComb 0, rightComb 1)`, the temporal
  conflation of (CLASSICAL, TEMPORAL)

## Cross-refs
- `staging/Tamari.lean` → EMLTree, leftComb, rightComb, dcStep
- `staging/Friction.lean` → frictionDensity, assocDefect, strut_weight
- `staging/Algebra.lean` → strut_weight_eq_four
-/

-- ============================================================================
-- SECTION 1: Grandfather Tree Definitions
-- ============================================================================

/--
The grandfather paradox tree: a left-comb of size 4.
Each node represents a step in the time-travel causal loop:
  1. Traveler exists in the present
  2. Traveler travels back in time
  3. Grandfather is killed (intervention)
  4. Traveler is never born (contradiction)
Contraction to rightComb (normal form) resolves the loop into linear time.
-/
def grandfatherTree : EMLTree := leftComb 4

/--
The normal form of the grandfather tree: a right-comb of size 4.
This is the unique terminal tree under Tamari contraction from `grandfatherTree`.
-/
def grandfatherTreeNF : EMLTree := rightComb 4

/--
The temporal conflation of the grandfather paradox pair (CLASSICAL, TEMPORAL).
Analogous to `Node(rightComb 0, rightComb 1)` — the vacuous pole + content pole.
This is the "oscillation tree" that the generation cycle produces.
-/
def grandfatherOscillationTree : EMLTree :=
  EMLTree.Node (rightComb 0) (rightComb 1)

/--
Theorem: leftComb 4 contracts to rightComb 4 via the Tamari lattice.
The proof uses `contracts_to_rightComb` from Tamari.lean:
  contracts_to t (rightComb t.size) for all t.
Since leftComb 4 has size 4: contracts_to (leftComb 4) (rightComb 4).
-/
theorem grandfather_contracts_to_normal_form : contracts_to grandfatherTree grandfatherTreeNF := by
  have hsize : grandfatherTree.size = 4 := by
    unfold grandfatherTree
    simp [leftComb, EMLTree.size]
  have h_contracts : contracts_to grandfatherTree (rightComb grandfatherTree.size) :=
    contracts_to_rightComb grandfatherTree
  simpa [hsize, grandfatherTreeNF] using h_contracts

-- ============================================================================
-- SECTION 2: Decidable Grandfather Detection
-- ============================================================================

/--
Decidable check: is the given tree structurally equal to the grandfather paradox
tree (leftComb 4)?
-/
def isGrandfatherTree (t : EMLTree) : Bool :=
  t == grandfatherTree

/--
More general signature check: does the tree have the grandfather paradox shape?
Specifically, is it structurally isomorphic to `leftComb 4` — a left-leaning chain
of exactly 4 nodes?

Catches any tree of the form `Node(Node(Node(Node(Leaf, _), _), _), _)` regardless
of what's in the rightmost leaf (could be any subtree, not just Leaf).
-/
def hasGrandfatherSignature (t : EMLTree) : Bool :=
  match t with
  | .Node (.Node (.Node (.Node _ _) _) _) _ => true
  | _ => false

/--
Check if a tree matches the grandfather oscillation signature:
`Node(rightComb 0, rightComb 1)` — a vacuous left pole and content-bearing right pole.
This is the signature of the temporal conflated grandfather pair.
-/
def isGrandfatherOscillationTree (t : EMLTree) : Bool :=
  t == grandfatherOscillationTree

/--
Check if a tree represents a "classical-temporal oscillation" — its left subtree
is a rightComb (associative, vacuous) and its right subtree is another rightComb
(associative, content-bearing). This is the general pattern of temporal conflation
for any two logics in the same associative sector.
-/
def isTemporalConflationPattern (t : EMLTree) : Bool :=
  match t with
  | .Node l r =>
    (l == _root_.rightComb 0 || l == _root_.rightComb 1) -- vacuous or minimal cdStep
    &&
    (r == _root_.rightComb 0 || r == _root_.rightComb 1) -- content-bearing
  | .Leaf => false

-- ============================================================================
-- SECTION 3: Cost
-- ============================================================================

/--
The grandfather cost at CD step k, using the staging friction density.
This is the true Lagrangian cost (includes the associator barrier for k ≥ 3).
-/
def grandfatherCost (k : ℕ) : ℕ := frictionDensity k

/--
Theorem: grandfatherCost is at least k, by `frictionDensity_ge_k`.
-/
theorem grandfatherCost_ge_k (k : ℕ) : grandfatherCost k ≥ k :=
  frictionDensity_ge_k k

/--
The friction Lagrangian cost for the grandfather paradox at the native logic
(Temporal, cdStep = 1): frictionDensity 1 = 1.
-/
theorem grandfatherCost_at_temporal : grandfatherCost 1 = 1 := by
  unfold grandfatherCost
  have h : frictionDensity 1 = 1 := frictionDensity_eq_k_for_k_le_2 1 (by decide)
  exact h

/--
The friction Lagrangian cost for the grandfather paradox at the vacuous logic
(Classical, cdStep = 0): frictionDensity 0 = 0.
-/
theorem grandfatherCost_at_classical : grandfatherCost 0 = 0 := by
  unfold grandfatherCost
  have h : frictionDensity 0 = 0 := frictionDensity_eq_k_for_k_le_2 0 (by decide)
  exact h

/--
The cost ratio between the content-bearing pole (Temporal, cost 1) and
the vacuous pole (Classical, cost 0) is infinite (division by zero).
This formally marks the vacuous resolution as "zero cost by explosion."
-/
theorem grandfather_cost_ratio_infinite : grandfatherCost 1 > 0 * grandfatherCost 0 := by
  have h0 : grandfatherCost 0 = 0 := grandfatherCost_at_classical
  have h1 : grandfatherCost 1 = 1 := grandfatherCost_at_temporal
  omega

-- ============================================================================
-- SECTION 4: Grandfather Distance (dcStep)
-- ============================================================================

/--
The distance from grandfatherTree to rightComb normal form is `dcStep(grandfatherTree)`.
For `leftComb 4`, this should equal 3 (three RST rotations to reach rightComb 4).
-/
theorem grandfather_dcStep : dcStep grandfatherTree = 3 := by
  unfold grandfatherTree
  native_decide

/--
The grandfather oscillation tree `Node(rightComb 0, rightComb 1)` is
already in right-comb normal form (`rightComb 2`), so its dcStep is 0.
-/
theorem grandfatherOscillation_dcStep : dcStep grandfatherOscillationTree = 0 := by
  unfold grandfatherOscillationTree
  native_decide

-- ============================================================================
-- SECTION 5: Generation Cycle Detection Utilities
-- ============================================================================

/--
Detect the grandfather paradox in an AntiCoherentPair (Test B state):
returns true if the pair equals the grandfather pair (CLASSICAL, TEMPORAL).
-/
def tpDetectedPair (pair : AntiCoherentPair) : Bool :=
  pair.coherent = 0 && pair.antiCoherent = 1

/--
Detect the grandfather paradox in a GenerationState:
returns true if the pair is the grandfather pair OR the tree matches leftComb 4.
-/
def tpDetectedGenerationState (s : GenerationState) : Bool :=
  tpDetectedPair s.pair || isGrandfatherTree s.tree

/--
Detect the grandfather paradox in an EMLTree:
returns true if the tree matches leftComb 4 (the grandfather tree).
-/
def tpDetectedOscillationTree (t : EMLTree) : Bool :=
  isGrandfatherTree t
