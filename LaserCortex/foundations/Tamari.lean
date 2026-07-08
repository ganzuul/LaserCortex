import Mathlib
import Mathlib.Logic.Relation

/-!
# Tamari Lattice Contraction

Tamari contraction on binary trees (EMLTree).

## Key definitions
- `EMLTree` — binary trees with size, height, leftWeight, rightWeight
- `contracts_one` — single right rotation (Tamari covering relation)
- `contracts_to` — reflexive-transitive closure (Tamari contraction)
- `rightComb` — the right-comb normal form (minimum element in Tamari order)
- `dcStep` — distance to rightComb (termination measure, proven decreasing by `dcStepMeasure`)

## Key theorems
- `contracts_to_antisymm` — antisymmetry: s → t ∧ t → s ⇒ s = t
- `contracts_to_refl` — reflexivity
- `contracts_to_trans` — transitivity
- `contracts_to_size_eq` — size preservation: s → t ⇒ s.size = t.size
-/

open Relation

-- ============================================================================
-- EMLTree: binary trees
-- ============================================================================

inductive EMLTree : Type where
  | Leaf : EMLTree
  | Node : EMLTree → EMLTree → EMLTree
  deriving DecidableEq, Repr

namespace EMLTree

def size : EMLTree → Nat
  | .Leaf       => 0
  | .Node l r   => 1 + l.size + r.size

def height : EMLTree → Nat
  | .Leaf       => 0
  | .Node l r   => 1 + max l.height r.height

end EMLTree

-- ============================================================================
-- Weight measures
-- ============================================================================

def leftWeight : EMLTree → Nat
  | .Leaf => 0
  | .Node l r => l.size + leftWeight l + leftWeight r

def rightWeight : EMLTree → Nat
  | .Leaf => 0
  | .Node l r => r.size + rightWeight l + rightWeight r

-- ============================================================================
-- Tamari covering relation (right rotation)
-- ============================================================================

inductive contracts_one : EMLTree → EMLTree → Prop where
  | rotate : ∀ (a b c : EMLTree),
      contracts_one (.Node (.Node a b) c) (.Node a (.Node b c))
  | left   : ∀ (l l' r : EMLTree),
      contracts_one l l' → contracts_one (.Node l r) (.Node l' r)
  | right  : ∀ (l r r' : EMLTree),
      contracts_one r r' → contracts_one (.Node l r) (.Node l r')

-- ============================================================================
-- Tamari contraction (reflexive-transitive closure)
-- ============================================================================

abbrev contracts_to : EMLTree → EMLTree → Prop := ReflTransGen contracts_one

namespace contracts_to

theorem refl (s : EMLTree) : contracts_to s s := ReflTransGen.refl

theorem step (s t u : EMLTree) (h_one : contracts_one s t) (h_to : contracts_to t u) : contracts_to s u :=
  ReflTransGen.head h_one h_to

end contracts_to

-- ============================================================================
-- Lifting lemmas (path validity monotonicity)
-- ============================================================================

theorem contracts_to_node_left {l l' r : EMLTree} (h : contracts_to l l') :
    contracts_to (.Node l r) (.Node l' r) := by
  refine ReflTransGen.rec
    (motive := λ x hx => contracts_to (EMLTree.Node l r) (EMLTree.Node x r))
    ?refl_case ?tail_case h
  · exact contracts_to.refl (EMLTree.Node l r)
  · intro b c h_to h_one ih
    have h_one' : contracts_one (EMLTree.Node b r) (EMLTree.Node c r) :=
      contracts_one.left b c r h_one
    exact ih.tail h_one'

theorem contracts_to_node_right {l r r' : EMLTree} (h : contracts_to r r') :
    contracts_to (.Node l r) (.Node l r') := by
  refine ReflTransGen.rec
    (motive := λ x hx => contracts_to (EMLTree.Node l r) (EMLTree.Node l x))
    ?refl_case ?tail_case h
  · exact contracts_to.refl (EMLTree.Node l r)
  · intro b c h_to h_one ih
    have h_one' : contracts_one (EMLTree.Node l b) (EMLTree.Node l c) :=
      contracts_one.right l b c h_one
    exact ih.tail h_one'

-- ============================================================================
-- Basic properties
-- ============================================================================

theorem contracts_to_trans {s t u : EMLTree} (h₁ : contracts_to s t) (h₂ : contracts_to t u) :
    contracts_to s u :=
  ReflTransGen.trans h₁ h₂

theorem contracts_one_size_eq {s t : EMLTree} (h : contracts_one s t) : s.size = t.size := by
  induction h with
  | rotate a b c =>
    simp [EMLTree.size]
    omega
  | left l l' r h ih =>
    simp [EMLTree.size, ih]
  | right l r r' h ih =>
    simp [EMLTree.size, ih]

theorem contracts_to_size_eq {s t : EMLTree} (h : contracts_to s t) : s.size = t.size := by
  refine ReflTransGen.rec
    (motive := λ x hx => s.size = x.size)
    ?refl_case ?tail_case h
  · rfl
  · intro b c h_to h_one ih
    have h_sz : b.size = c.size := contracts_one_size_eq h_one
    calc
      s.size = b.size := ih
      _ = c.size := h_sz

theorem contracts_one_leftWeight_decreases {s t : EMLTree} (h : contracts_one s t) : leftWeight s > leftWeight t := by
  induction h with
  | rotate a b c =>
    simp [leftWeight, EMLTree.size]
    omega
  | left l l' r h_left ih =>
    have hsz : l.size = l'.size := contracts_one_size_eq h_left
    simp [leftWeight, hsz, ih]
  | right l r r' h_right ih =>
    simp [leftWeight, ih]

theorem contracts_to_leftWeight_ge {s t : EMLTree} (h : contracts_to s t) : leftWeight s ≥ leftWeight t := by
  refine ReflTransGen.rec
    (motive := λ x hx => leftWeight s ≥ leftWeight x)
    ?refl_case ?tail_case h
  · exact Nat.le_refl _
  · intro b c h_to h_one ih
    have h_decr : leftWeight b > leftWeight c := contracts_one_leftWeight_decreases h_one
    exact Nat.le_of_lt (Nat.lt_of_lt_of_le h_decr ih)

-- ============================================================================
-- Antisymmetry (Tamari lattice is a partial order)
-- ============================================================================

theorem contracts_to_antisymm {s t : EMLTree} (h₁ : contracts_to s t) (h₂ : contracts_to t s) : s = t := by
  match h₁ with
  | ReflTransGen.refl =>
    match h₂ with
    | ReflTransGen.refl => rfl
    | @ReflTransGen.tail _ _ _ x _ h₂' h_one' =>
      have h_decr : leftWeight x > leftWeight s := contracts_one_leftWeight_decreases h_one'
      have h_lw_s_ge_x : leftWeight s ≥ leftWeight x := contracts_to_leftWeight_ge h₂'
      omega
  | @ReflTransGen.tail _ _ _ x _ h_to h_one =>
    have h_lw_s_ge_x : leftWeight s ≥ leftWeight x := contracts_to_leftWeight_ge h_to
    have h_xs : contracts_to x s := ReflTransGen.head h_one h₂
    have h_lw_x_ge_s : leftWeight x ≥ leftWeight s := contracts_to_leftWeight_ge h_xs
    have h_decr : leftWeight x > leftWeight t := contracts_one_leftWeight_decreases h_one
    have h_lw_t_ge_s : leftWeight t ≥ leftWeight s := contracts_to_leftWeight_ge h₂
    omega

-- ============================================================================
-- Normal forms
-- ============================================================================

def rightComb : Nat → EMLTree
  | 0     => .Leaf
  | n + 1 => .Node .Leaf (rightComb n)

def leftComb : Nat → EMLTree
  | 0     => .Leaf
  | n + 1 => .Node (leftComb n) .Leaf

/-- The size of a right-comb of size n equals n. -/
theorem rightComb_size (n : ℕ) : (rightComb n).size = n := by
  induction' n with k ih
  · rfl
  · simp [rightComb, EMLTree.size, ih]
    omega

/-- The size of a left-comb of size n equals n. -/
theorem leftComb_size (n : ℕ) : (leftComb n).size = n := by
  induction' n with k ih
  · rfl
  · simp [leftComb, EMLTree.size, ih]
    omega

-- ============================================================================
-- dcStep: distance to rightComb
-- ============================================================================

private def dcStepMeasure (t : EMLTree) : Nat := leftWeight t + t.size

private theorem dcStepMeasure_node_lt (a b r : EMLTree) :
    dcStepMeasure (EMLTree.Node a (EMLTree.Node b r)) < dcStepMeasure (EMLTree.Node (EMLTree.Node a b) r) := by
  unfold dcStepMeasure
  calc
    leftWeight (EMLTree.Node a (EMLTree.Node b r)) + (EMLTree.Node a (EMLTree.Node b r)).size
        = a.size + leftWeight a + leftWeight (EMLTree.Node b r) + (1 + a.size + (EMLTree.Node b r).size) := by
      simp [leftWeight, EMLTree.size]
    _ = a.size + leftWeight a + (b.size + leftWeight b + leftWeight r) + (1 + a.size + (1 + b.size + r.size)) := by
      simp [leftWeight, EMLTree.size]
    _ = 2 + 2*a.size + 2*b.size + leftWeight a + leftWeight b + leftWeight r + r.size := by omega
    _ < 3 + 3*a.size + 2*b.size + leftWeight a + leftWeight b + leftWeight r + r.size := by omega
    _ = ((EMLTree.Node a b).size + leftWeight (EMLTree.Node a b) + leftWeight r) + (1 + (EMLTree.Node a b).size + r.size) := by
      simp [leftWeight, EMLTree.size]
      omega
    _ = leftWeight (EMLTree.Node (EMLTree.Node a b) r) + (EMLTree.Node (EMLTree.Node a b) r).size := by
      simp [leftWeight, EMLTree.size]

private theorem dcStepMeasure_leaf_lt (r : EMLTree) : dcStepMeasure r < dcStepMeasure (EMLTree.Node EMLTree.Leaf r) := by
  unfold dcStepMeasure
  have h_lw : leftWeight (EMLTree.Node EMLTree.Leaf r) = leftWeight r := by
    simp [leftWeight, EMLTree.size]
  have h_sz : (EMLTree.Node EMLTree.Leaf r).size = 1 + r.size := by
    simp [EMLTree.size]
  have h_ineq : leftWeight r + r.size < leftWeight r + (1 + r.size) := by omega
  simpa [h_lw, h_sz] using h_ineq

def dcStep : EMLTree → Nat
  | .Leaf => 0
  | .Node .Leaf r => dcStep r
  | .Node (.Node a b) r => 1 + dcStep (.Node a (.Node b r))
termination_by t => dcStepMeasure t
decreasing_by
  · exact dcStepMeasure_leaf_lt r
  · exact dcStepMeasure_node_lt a b r

theorem dcStep_node_right_anti (l r r' : EMLTree) (h : dcStep r ≥ dcStep r') :
    dcStep (EMLTree.Node l r) ≥ dcStep (EMLTree.Node l r') := by
  induction l generalizing r r' with
  | Leaf =>
    simp [dcStep, h]
  | Node a b ih_a ih_b =>
    have h_inner : dcStep (EMLTree.Node a (EMLTree.Node b r)) ≥ dcStep (EMLTree.Node a (EMLTree.Node b r')) :=
      ih_a (EMLTree.Node b r) (EMLTree.Node b r') (ih_b r r' h)
    calc
      dcStep (EMLTree.Node (EMLTree.Node a b) r) = 1 + dcStep (EMLTree.Node a (EMLTree.Node b r)) := by simp [dcStep]
      _ ≥ 1 + dcStep (EMLTree.Node a (EMLTree.Node b r')) := Nat.add_le_add_left h_inner 1
      _ = dcStep (EMLTree.Node (EMLTree.Node a b) r') := by simp [dcStep]

theorem dcStep_node_right_eq (l r r' : EMLTree) (h : dcStep r = dcStep r') :
    dcStep (EMLTree.Node l r) = dcStep (EMLTree.Node l r') := by
  apply le_antisymm
  · exact dcStep_node_right_anti l r' r h.le
  · exact dcStep_node_right_anti l r r' h.ge

theorem dcStep_rotate_identity (a b c r : EMLTree) :
    dcStep (EMLTree.Node (EMLTree.Node a b) (EMLTree.Node c r)) =
    dcStep (EMLTree.Node a (EMLTree.Node (EMLTree.Node b c) r)) := by
  induction a generalizing b c r with
  | Leaf =>
    simp [dcStep]
  | Node a1 a2 ih_a1 ih_a2 =>
    calc
      dcStep (EMLTree.Node (EMLTree.Node (EMLTree.Node a1 a2) b) (EMLTree.Node c r))
          = 1 + dcStep (EMLTree.Node (EMLTree.Node a1 a2) (EMLTree.Node b (EMLTree.Node c r))) := by simp [dcStep]
      _ = 1 + dcStep (EMLTree.Node a1 (EMLTree.Node (EMLTree.Node a2 b) (EMLTree.Node c r))) := by simp [ih_a1 a2 b (EMLTree.Node c r)]
      _ = 1 + dcStep (EMLTree.Node a1 (EMLTree.Node a2 (EMLTree.Node (EMLTree.Node b c) r))) := by
        have h_eq : dcStep (EMLTree.Node (EMLTree.Node a2 b) (EMLTree.Node c r)) = dcStep (EMLTree.Node a2 (EMLTree.Node (EMLTree.Node b c) r)) :=
          ih_a2 b c r
        have h3 : dcStep (EMLTree.Node a1 (EMLTree.Node (EMLTree.Node a2 b) (EMLTree.Node c r))) = dcStep (EMLTree.Node a1 (EMLTree.Node a2 (EMLTree.Node (EMLTree.Node b c) r))) :=
          dcStep_node_right_eq a1 (EMLTree.Node (EMLTree.Node a2 b) (EMLTree.Node c r)) (EMLTree.Node a2 (EMLTree.Node (EMLTree.Node b c) r)) h_eq
        simp [h3]
      _ = dcStep (EMLTree.Node (EMLTree.Node a1 a2) (EMLTree.Node (EMLTree.Node b c) r)) := by simp [dcStep]

theorem dcStep_node_left_ge (l l' r : EMLTree) (h : contracts_one l l') :
    dcStep (EMLTree.Node l r) ≥ dcStep (EMLTree.Node l' r) := by
  induction h generalizing r with
  | rotate a b c =>
    have h_eq : dcStep (EMLTree.Node (EMLTree.Node (EMLTree.Node a b) c) r) = dcStep (EMLTree.Node (EMLTree.Node a (EMLTree.Node b c)) r) := by
      calc
        dcStep (EMLTree.Node (EMLTree.Node (EMLTree.Node a b) c) r) = 1 + dcStep (EMLTree.Node (EMLTree.Node a b) (EMLTree.Node c r)) := by simp [dcStep]
        _ = 1 + dcStep (EMLTree.Node a (EMLTree.Node (EMLTree.Node b c) r)) := by simp [dcStep_rotate_identity a b c r]
        _ = dcStep (EMLTree.Node (EMLTree.Node a (EMLTree.Node b c)) r) := by simp [dcStep]
    simpa [h_eq] using le_refl (dcStep (EMLTree.Node (EMLTree.Node (EMLTree.Node a b) c) r))
  | left l1 l1' r1 h_left ih =>
    simp [dcStep]
    exact ih (EMLTree.Node r1 r)
  | right l1 r1 r1' h_right ih =>
    simp [dcStep]
    apply dcStep_node_right_anti l1 (EMLTree.Node r1 r) (EMLTree.Node r1' r)
    exact ih r

theorem dcStep_contracts_one {s t : EMLTree} (h : contracts_one s t) :
    dcStep s ≥ dcStep t := by
  induction h with
  | rotate a b c =>
    simp [dcStep]
  | left l l' r h_left ih =>
    exact dcStep_node_left_ge l l' r h_left
  | right l r r' h_right ih =>
    apply dcStep_node_right_anti l r r'
    exact ih

-- ============================================================================
-- isRightComb: decidable idempotence predicate
-- ============================================================================

def isRightComb : EMLTree → Prop
  | .Leaf => True
  | .Node .Leaf r => isRightComb r
  | .Node _ _ => False

theorem isRightComb_iff_dcStep_zero (t : EMLTree) :
    isRightComb t ↔ dcStep t = 0 := by
  induction t with
  | Leaf =>
    simp [isRightComb, dcStep]
  | Node l r ih_l ih_r =>
    unfold isRightComb
    unfold dcStep
    cases l with
    | Leaf =>
      exact ih_r
    | Node a b =>
      simp

theorem dcStep_rightComb (n : Nat) : dcStep (rightComb n) = 0 := by
  induction n with
  | zero =>
    simp [dcStep, rightComb]
  | succ n ih =>
    simp [dcStep, rightComb, ih]

-- ============================================================================
-- Composition lemma: Node (rightComb a) (rightComb b) contracts to rightComb
-- ============================================================================

theorem node_of_rightCombs_contracts_to_rightComb (a b : Nat) :
    contracts_to (EMLTree.Node (rightComb a) (rightComb b)) (rightComb (1 + a + b)) := by
  induction a with
  | zero =>
    have h₁ : rightComb (1 + b) = EMLTree.Node .Leaf (rightComb b) := by
      have h₂ : 1 + b = b + 1 := by omega
      rw [h₂]
      simp [rightComb]
    simp [rightComb, h₁]
    exact contracts_to.refl _
  | succ a ih =>
    have rot : contracts_one
        (EMLTree.Node (EMLTree.Node .Leaf (rightComb a)) (rightComb b))
        (EMLTree.Node .Leaf (EMLTree.Node (rightComb a) (rightComb b))) :=
      contracts_one.rotate .Leaf (rightComb a) (rightComb b)
    have lifted : contracts_to
        (EMLTree.Node .Leaf (EMLTree.Node (rightComb a) (rightComb b)))
        (EMLTree.Node .Leaf (rightComb (1 + a + b))) :=
      contracts_to_node_right ih
    have combined : contracts_to
        (EMLTree.Node (EMLTree.Node .Leaf (rightComb a)) (rightComb b))
        (EMLTree.Node .Leaf (rightComb (1 + a + b))) :=
      contracts_to.step _ _ _ rot lifted
    have h_target : rightComb (1 + (a + 1) + b) = EMLTree.Node .Leaf (rightComb (1 + a + b)) := by
      calc
        rightComb (1 + (a + 1) + b) = rightComb (a + b + 2) := by
          simp [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]
        _ = EMLTree.Node .Leaf (rightComb (a + b + 1)) := by simp [rightComb]
        _ = EMLTree.Node .Leaf (rightComb (1 + a + b)) := by
          simp [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]
    rw [h_target]
    exact combined

-- ============================================================================
-- Main theorem: every tree contracts to its right-comb normal form
-- ============================================================================

theorem contracts_to_rightComb (t : EMLTree) :
    contracts_to t (rightComb t.size) := by
  induction t using EMLTree.recOn with
  | Leaf =>
    simp [EMLTree.size, rightComb]
    exact contracts_to.refl _
  | Node l r ih_l ih_r =>
    have h₁ : rightComb (1 + l.size + r.size) = EMLTree.Node .Leaf (rightComb (l.size + r.size)) := by
      have h₂ : 1 + l.size + r.size = (l.size + r.size) + 1 := by omega
      rw [h₂]
      simp [rightComb]
    have h_lift_l : contracts_to (EMLTree.Node l r) (EMLTree.Node (rightComb l.size) r) :=
      contracts_to_node_left ih_l
    have h_lift_r : contracts_to (EMLTree.Node (rightComb l.size) r) (EMLTree.Node (rightComb l.size) (rightComb r.size)) :=
      contracts_to_node_right ih_r
    have h_lift_both : contracts_to (EMLTree.Node l r) (EMLTree.Node (rightComb l.size) (rightComb r.size)) :=
      contracts_to_trans h_lift_l h_lift_r
    have h_compose : contracts_to (EMLTree.Node (rightComb l.size) (rightComb r.size)) (rightComb (1 + l.size + r.size)) :=
      node_of_rightCombs_contracts_to_rightComb l.size r.size
    have h_target : rightComb (1 + l.size + r.size) = EMLTree.Node .Leaf (rightComb (l.size + r.size)) := by
      have h₂ : 1 + l.size + r.size = (l.size + r.size) + 1 := by omega
      rw [h₂]
      simp [rightComb]
    simpa [EMLTree.size, h_target] using contracts_to_trans h_lift_both h_compose
