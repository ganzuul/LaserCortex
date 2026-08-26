import LaserCortex.foundations.Tamari

/-!
# Tamari Metric: `dcStep` is the geodesic distance

Proves the C2 "potentiality" claim of lab note 051: the greedy flip count
`dcStep` equals the *minimal* number of `contracts_one` rotations needed to
reach the right-comb normal form.  Equivalently, `dcStep` is the rank function
of the Tamari lattice — a graded-lattice invariant.

## Strategy

The defining recursion of `dcStep` already realizes a path of exactly
`dcStep t` rotations.  The missing piece is minimality, which follows from the
single bound

  `dcStep_contracts_one_le` : every rotation decreases `dcStep` by **at most** 1.

Together with the existing `dcStep_contracts_one` (decreases by at least 0),
each step drops `dcStep` by exactly 0 or 1, so any path from `t` to the
right comb (which has `dcStep = 0`) must take at least `dcStep t` steps —
and the greedy path takes exactly `dcStep t`.

A note on why the bound is "at most 1" and not "exactly 1": a rotation in the
*left* subtree leaves `dcStep` unchanged in some cases, so the drop can be 0.
-/

namespace TamariMetric

open EMLTree

-- ============================================================================
-- dcStep drops by at most 1 per rotation
-- ============================================================================

/-- Right-context propagation with slack 1: if `dcStep r ≤ dcStep r' + 1` then
the same holds after both are wrapped in `Node l _`. -/
theorem dcStep_right_add_one :
    ∀ (l r r' : EMLTree), dcStep r ≤ dcStep r' + 1 →
      dcStep (EMLTree.Node l r) ≤ dcStep (EMLTree.Node l r') + 1 := by
  intro l
  induction l with
  | Leaf =>
    intro r r' h
    simpa [dcStep] using h
  | Node a b iha ihb =>
    intro r r' h
    have hb : dcStep (EMLTree.Node b r) ≤ dcStep (EMLTree.Node b r') + 1 := ihb r r' h
    have ha : dcStep (EMLTree.Node a (EMLTree.Node b r)) ≤ dcStep (EMLTree.Node a (EMLTree.Node b r')) + 1 :=
      iha (EMLTree.Node b r) (EMLTree.Node b r') hb
    simp [dcStep]
    omega

/-- A root rotation increases `dcStep` by exactly 1. -/
theorem dcStep_rotate_add_one (a b r : EMLTree) :
    dcStep (EMLTree.Node (EMLTree.Node a b) r) = dcStep (EMLTree.Node a (EMLTree.Node b r)) + 1 := by
  simp [dcStep]
  omega

/-- Left-context propagation: a contraction `l → l'` lifts to `Node l r`
with the same at-most-1 drop. -/
theorem dcStep_node_left_contracts_le {l l' : EMLTree} (h : contracts_one l l') (r : EMLTree) :
    dcStep (EMLTree.Node l r) ≤ dcStep (EMLTree.Node l' r) + 1 := by
  induction h generalizing r with
  | rotate a b c =>
    calc
      dcStep (EMLTree.Node (EMLTree.Node (EMLTree.Node a b) c) r)
          = 1 + dcStep (EMLTree.Node (EMLTree.Node a b) (EMLTree.Node c r)) := by simp [dcStep]
      _ = 1 + dcStep (EMLTree.Node a (EMLTree.Node (EMLTree.Node b c) r)) := by
            rw [dcStep_rotate_identity a b c r]
      _ = dcStep (EMLTree.Node (EMLTree.Node a (EMLTree.Node b c)) r) := by simp [dcStep]
      _ ≤ dcStep (EMLTree.Node (EMLTree.Node a (EMLTree.Node b c)) r) + 1 := by omega
  | left l1 l1' r1 h1 ih =>
    have hh := ih (EMLTree.Node r1 r)
    simp [dcStep]
    omega
  | right l1 r1 r1' h1 ih =>
    have hh : dcStep (EMLTree.Node r1 r) ≤ dcStep (EMLTree.Node r1' r) + 1 := ih r
    have hr := dcStep_right_add_one l1 (EMLTree.Node r1 r) (EMLTree.Node r1' r) hh
    simp [dcStep]
    omega

/-- **The crux.** Each Tamari rotation decreases `dcStep` by at most 1. -/
theorem dcStep_contracts_one_le {s t : EMLTree} (h : contracts_one s t) :
    dcStep s ≤ dcStep t + 1 := by
  induction h with
  | rotate a b c =>
    simp [dcStep]
    omega
  | left l l' r h1 ih =>
    exact dcStep_node_left_contracts_le h1 r
  | right l r r' h1 ih =>
    exact dcStep_right_add_one l r r' ih

-- ============================================================================
-- Step-counted reachability
-- ============================================================================

/-- `ContractsToSteps s t n`: a chain of exactly `n` `contracts_one` rotations
from `s` to `t`. -/
inductive ContractsToSteps : EMLTree → EMLTree → Nat → Prop where
  | refl (t : EMLTree) : ContractsToSteps t t 0
  | step (s u t : EMLTree) (n : Nat) (h : contracts_one s u) (ht : ContractsToSteps u t n) :
      ContractsToSteps s t (n + 1)

/-- Lifting a step-counted chain through a right context preserves the count. -/
theorem ContractsToSteps_node_right {l r r' : EMLTree} {n : Nat} (h : ContractsToSteps r r' n) :
    ContractsToSteps (EMLTree.Node l r) (EMLTree.Node l r') n := by
  induction h with
  | refl t => exact ContractsToSteps.refl (EMLTree.Node l t)
  | step s u t m h1 ht ih =>
    exact ContractsToSteps.step (EMLTree.Node l s) (EMLTree.Node l u) (EMLTree.Node l t) m
      (contracts_one.right l s u h1) ih

/-- The `Node .Leaf r` case of greedy reduction: lift the sub-chain through the
right context and align the size / `dcStep` bookkeeping. -/
theorem ContractsToSteps_node_leaf_step {r : EMLTree} :
    ContractsToSteps r (rightComb r.size) (dcStep r) →
    ContractsToSteps (EMLTree.Node EMLTree.Leaf r) (rightComb (EMLTree.Node EMLTree.Leaf r).size)
      (dcStep (EMLTree.Node EMLTree.Leaf r)) := by
  intro h
  have hlift : ContractsToSteps (EMLTree.Node EMLTree.Leaf r) (EMLTree.Node EMLTree.Leaf (rightComb r.size)) (dcStep r) :=
    ContractsToSteps_node_right (l := EMLTree.Leaf) h
  have hdc : dcStep (EMLTree.Node EMLTree.Leaf r) = dcStep r := by simp [dcStep]
  have hrc : rightComb (EMLTree.Node EMLTree.Leaf r).size = EMLTree.Node EMLTree.Leaf (rightComb r.size) := by
    simp [EMLTree.size]
    rw [Nat.add_comm 1 r.size]
    rfl
  rw [hdc, hrc]
  exact hlift

/-- The `Node (Node a b) r` case of greedy reduction: one rotate step then the
sub-chain, aligned to the parent's size / `dcStep`. -/
theorem ContractsToSteps_rotate_step {a b r : EMLTree} :
    ContractsToSteps (EMLTree.Node a (EMLTree.Node b r)) (rightComb (EMLTree.Node a (EMLTree.Node b r)).size)
      (dcStep (EMLTree.Node a (EMLTree.Node b r))) →
    ContractsToSteps (EMLTree.Node (EMLTree.Node a b) r) (rightComb (EMLTree.Node (EMLTree.Node a b) r).size)
      (dcStep (EMLTree.Node (EMLTree.Node a b) r)) := by
  intro h
  have hrot : contracts_one (EMLTree.Node (EMLTree.Node a b) r) (EMLTree.Node a (EMLTree.Node b r)) :=
    contracts_one.rotate a b r
  have hstep := ContractsToSteps.step _ _ _ _ hrot h
  rw [dcStep_rotate_add_one a b r]
  rw [contracts_one_size_eq hrot]
  exact hstep

-- ============================================================================
-- Lower bound: dcStep is a floor on path length
-- ============================================================================

/-- Any `n`-step contraction path from `s` to `t` satisfies
`dcStep s ≤ dcStep t + n`: each step drops `dcStep` by at most 1. -/
theorem dcStep_le_contracts_to_steps {s t : EMLTree} {n : Nat} (h : ContractsToSteps s t n) :
    dcStep s ≤ dcStep t + n := by
  induction h with
  | refl t => simp
  | step s u t m h1 ht ih =>
    calc
      dcStep s ≤ dcStep u + 1 := dcStep_contracts_one_le h1
      _ ≤ (dcStep t + m) + 1 := Nat.add_le_add_right ih 1
      _ = dcStep t + (m + 1) := by omega

/-- Any path from `t` to the right comb needs at least `dcStep t` steps. -/
theorem dcStep_le_path_to_rightComb {t : EMLTree} {n : Nat} (h : ContractsToSteps t (rightComb t.size) n) :
    dcStep t ≤ n := by
  have hmain := dcStep_le_contracts_to_steps h
  have hz : dcStep (rightComb t.size) = 0 := dcStep_rightComb t.size
  simpa [hz] using hmain

-- ============================================================================
-- Achievability: the greedy recursion realizes a path of exactly dcStep steps
-- ============================================================================

private def tmMeasure (t : EMLTree) : Nat := leftWeight t + t.size

private theorem tmMeasure_leaf_lt (r : EMLTree) :
    tmMeasure r < tmMeasure (EMLTree.Node EMLTree.Leaf r) := by
  unfold tmMeasure
  have h_lw : leftWeight (EMLTree.Node EMLTree.Leaf r) = leftWeight r := by simp [leftWeight, EMLTree.size]
  have h_sz : (EMLTree.Node EMLTree.Leaf r).size = 1 + r.size := by simp [EMLTree.size]
  simp [h_lw, h_sz]

private theorem tmMeasure_rotate_lt (a b r : EMLTree) :
    tmMeasure (EMLTree.Node a (EMLTree.Node b r)) < tmMeasure (EMLTree.Node (EMLTree.Node a b) r) := by
  unfold tmMeasure
  have h_lw : leftWeight (EMLTree.Node (EMLTree.Node a b) r) > leftWeight (EMLTree.Node a (EMLTree.Node b r)) :=
    contracts_one_leftWeight_decreases (contracts_one.rotate a b r)
  have h_sz : (EMLTree.Node (EMLTree.Node a b) r).size = (EMLTree.Node a (EMLTree.Node b r)).size :=
    contracts_one_size_eq (contracts_one.rotate a b r)
  omega

/-- Greedy reduction: a computable proof that `t` reaches its right-comb normal
form in exactly `dcStep t` rotations, mirroring the `dcStep` recursion. -/
def contractsToStepsProof : (t : EMLTree) → ContractsToSteps t (rightComb t.size) (dcStep t)
  | .Leaf => by
      simp [dcStep, rightComb, EMLTree.size]
      exact ContractsToSteps.refl EMLTree.Leaf
  | .Node .Leaf r => ContractsToSteps_node_leaf_step (contractsToStepsProof r)
  | .Node (.Node a b) r => ContractsToSteps_rotate_step (contractsToStepsProof (EMLTree.Node a (EMLTree.Node b r)))
termination_by t => tmMeasure t
decreasing_by
  · exact tmMeasure_leaf_lt r
  · exact tmMeasure_rotate_lt a b r

/-- Achievability: the right comb is reachable in exactly `dcStep t` steps. -/
theorem contracts_to_steps_of_dcStep (t : EMLTree) :
    ContractsToSteps t (rightComb t.size) (dcStep t) :=
  contractsToStepsProof t

-- ============================================================================
-- C2: dcStep is the geodesic distance
-- ============================================================================

/-- **C2 / potentiality.** `dcStep t` is the minimal number of Tamari rotations
to reach the right comb: it is both achievable and a lower bound on every path. -/
theorem minimal_path_length_eq_dcStep (t : EMLTree) :
    (∀ n, ContractsToSteps t (rightComb t.size) n → dcStep t ≤ n) ∧
    ContractsToSteps t (rightComb t.size) (dcStep t) :=
  ⟨fun _ h => dcStep_le_path_to_rightComb h, contracts_to_steps_of_dcStep t⟩

/-- `dcStep t` is the least step count among all paths from `t` to its
right-comb normal form. -/
theorem dcStep_eq_geodesic (t : EMLTree) :
    IsLeast {n : Nat | ContractsToSteps t (rightComb t.size) n} (dcStep t) := by
  constructor
  · exact contracts_to_steps_of_dcStep t
  · intro n hn
    exact dcStep_le_path_to_rightComb hn

end TamariMetric
