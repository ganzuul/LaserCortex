import Mathlib
import LaserCortex.foundations.Algebra

/-!
# F2 — Bracketing coherence on the basis skeleton

Lab note 058 registers F2 as the artifact that turns "associator =
backpropagation defect" from analogy into theorem; lab note 059 §0 fixes
its domain: the **basis skeleton** — the signed basis {±e₀ … ±e₇}, the
Cayley–Dickson loop Q₃. Three scoping facts frame this module:

1. **General elements admit no sign transport.** For arbitrary `x y z`,
   `(xy)z − x(yz) = [x,y,z]` is a seven-dimensional vector; there is no
   scalar "factor" relating the two bracketings. The ledger's original
   wording ("any two bracketings differ by a factor governed by
   `signCocycle`") is *false over the continuum*, and this module proves
   the strongest honest reading instead.
2. **On the skeleton the defect collapses to a sign** (`signed_rotOr`):
   products of signed basis vectors are signed basis vectors
   (`basisLike.mul`), so a rotation can only preserve or negate the value
   — never change its axis or magnitude. F2a (`basisWord_eq_or_neg`)
   lifts this to any two bracketings of any signed-basis word, *all n*.
3. **The bridge** (`rotBridge`): on skeleton triples the equal-or-negate
   alternative is decided by the cocycle — the value ratio of one
   re-bracketing *is* `signCocycle` of the block triple. `signCocycle` is
   therefore literally the F-symbol of the skeleton, and this is the
   first concrete instance of ledger item 8 ("`contracts_one` = F-move").
   `pentagonLoop` verifies the pentagon face condition around K₄ at the
   value level — an independent re-check of `pentagon_cocycle_basis` [P]
   through the product of all five edge signs.

The general-n statement that survives over arbitrary elements is Artin's
theorem (words in ≤ 2 generators associate exactly) — registered as
future work (058 F2c), not claimed here.
-/

namespace Coherence

/-! ## Sign lemmas for the multiplication -/

theorem split_neg_mul (x y : SplitOctonion) :
    split_oct_mul (split_neg x) y = split_neg (split_oct_mul x y) := by
  ext <;> simp [split_oct_mul, split_neg] <;> ring

theorem split_mul_neg (x y : SplitOctonion) :
    split_oct_mul x (split_neg y) = split_neg (split_oct_mul x y) := by
  ext <;> simp [split_oct_mul, split_neg] <;> ring

theorem split_neg_neg (x : SplitOctonion) : split_neg (split_neg x) = x := by
  ext <;> simp [split_neg]

/-! ## The basis skeleton (lab note 059 §0, sense (b)) -/

/-- Signed basis vector: `eᵢ` or `−eᵢ`. -/
def signed (b : Bool) (i : Fin 8) : SplitOctonion :=
  if b then split_neg (basisVec i) else basisVec i

theorem signed_false (i : Fin 8) : signed false i = basisVec i := by simp [signed]

theorem signed_true (i : Fin 8) : signed true i = split_neg (basisVec i) := by simp [signed]

/-- Membership in the signed-basis skeleton (the Cayley–Dickson loop Q₃).
Reducible so that decidability searches see the underlying existential. -/
abbrev basisLike (x : SplitOctonion) : Prop :=
  ∃ (b : Bool) (i : Fin 8), x = signed b i

/-- The skeleton is closed under negation. -/
theorem basisLike.neg {x : SplitOctonion} (h : basisLike x) : basisLike (split_neg x) := by
  obtain ⟨b, i, rfl⟩ := h
  cases b
  · exact ⟨true, i, by simp [signed]⟩
  · exact ⟨false, i, by simp [signed, split_neg_neg]⟩

/-- Closure: products of basis vectors land back on the skeleton (64 cases). -/
theorem basisVec_mul (i j : Fin 8) :
    basisLike (split_oct_mul (basisVec i) (basisVec j)) := by
  revert i j
  native_decide +revert

/-- The skeleton is closed under multiplication. -/
theorem basisLike.mul {x y : SplitOctonion}
    (hx : basisLike x) (hy : basisLike y) : basisLike (split_oct_mul x y) := by
  obtain ⟨b1, i, rfl⟩ := hx
  obtain ⟨b2, j, rfl⟩ := hy
  cases b1
  · cases b2
    · rw [signed_false, signed_false]; exact basisVec_mul i j
    · rw [signed_false, signed_true, split_mul_neg]; exact (basisVec_mul i j).neg
  · cases b2
    · rw [signed_true, signed_false, split_neg_mul]; exact (basisVec_mul i j).neg
    · rw [signed_true, signed_true, split_neg_mul, split_mul_neg, split_neg_neg]
      exact basisVec_mul i j

/-! ## Rotations -/

/-- The ± alternative for a rotation at the block triple `(x, y, z)`. -/
abbrev rotOr (x y z : SplitOctonion) : Prop :=
  split_oct_mul (split_oct_mul x y) z
    = split_oct_mul x (split_oct_mul y z) ∨
  split_oct_mul (split_oct_mul x y) z =
    split_neg (split_oct_mul x (split_oct_mul y z))

/-- **Rotation on the skeleton**: one re-bracketing preserves the value or
negates it — never changes axis or magnitude. Signed triple check,
2³ · 8³ = 4096 cases. -/
theorem signed_rotOr (b1 b2 b3 : Bool) (i j k : Fin 8) :
    rotOr (signed b1 i) (signed b2 j) (signed b3 k) := by
  revert b1 b2 b3 i j k
  native_decide +revert

/-- Signed-lift to skeleton-valued blocks. -/
theorem basisLike.rotOr {x y z : SplitOctonion}
    (hx : basisLike x) (hy : basisLike y) (hz : basisLike z) : rotOr x y z := by
  obtain ⟨b1, i, rfl⟩ := hx
  obtain ⟨b2, j, rfl⟩ := hy
  obtain ⟨b3, k, rfl⟩ := hz
  exact signed_rotOr b1 b2 b3 i j k

/-- **F2 bridge — the cocycle is the transport.** On skeleton triples the
equal-or-negate alternative of a rotation is decided by the local
`signCocycle`: the two bracketings agree exactly when φ = 1 and are exact
negates of each other exactly when φ = −1. This is the statement that
`signCocycle` is the F-symbol of the skeleton (ledger item 8, first
concrete instance). -/
theorem rotBridge {x y z : SplitOctonion}
    (hx : basisLike x) (hy : basisLike y) (hz : basisLike z) :
    (signCocycle x y z = 1 ∧
        split_oct_mul (split_oct_mul x y) z = split_oct_mul x (split_oct_mul y z)) ∨
    (signCocycle x y z = -1 ∧
        split_oct_mul (split_oct_mul x y) z =
          split_neg (split_oct_mul x (split_oct_mul y z))) := by
  obtain ⟨b1, i, rfl⟩ := hx
  obtain ⟨b2, j, rfl⟩ := hy
  obtain ⟨b3, k, rfl⟩ := hz
  revert b1 b2 b3 i j k
  native_decide +revert

/-- **F2b — the pentagon face closes at the value level.** The product of
the five edge cocycles around K₄ (the associahedron for four letters:
successive edges `((ab)c)d → (a(bc))d → a((bc)d) → a(b(cd)) → (ab)(cd)`,
closing back to `((ab)c)d`) is 1 — an independent `native_decide`
re-check of `pentagon_cocycle_basis` [P] through the bracketing
transport, 4096 quadruples. -/
theorem pentagonLoop (a b c d : Fin 8) :
    let A := basisVec a; let B := basisVec b; let C := basisVec c; let D := basisVec d
    signCocycle A B C * signCocycle A (split_oct_mul B C) D
      * signCocycle B C D * signCocycle A B (split_oct_mul C D)
      * signCocycle (split_oct_mul A B) C D = 1 := by
  revert a b c d
  native_decide +revert

/-! ## Bracketings and re-bracketing paths -/

/-- A bracketing: binary tree with signed-basis leaves. -/
inductive BTree where
  | leaf (b : Bool) (i : Fin 8)
  | node (l r : BTree)

/-- Evaluate a bracketing in the skeleton. -/
def eval : BTree → SplitOctonion
  | .leaf b i => signed b i
  | .node l r => split_oct_mul (eval l) (eval r)

/-- Leaf word, left to right. -/
def leaves : BTree → List (Bool × Fin 8)
  | .leaf b i => [(b, i)]
  | .node l r => leaves l ++ leaves r

theorem eval_basisLike (t : BTree) : basisLike (eval t) := by
  induction t with
  | leaf b i => exact ⟨b, i, rfl⟩
  | node l r hl hr => exact hl.mul hr

/-- Two bracketings are connected if one can pass between them by
re-bracketings `(xy)z ↔ x(yz)` performed at any depth, in either
direction. This is the rotation path along the Tamari graph
(059 §0, sense (c)). -/
inductive Path : BTree → BTree → Prop where
  | refl (t : BTree) : Path t t
  | rot (x y z : BTree) :
      Path (BTree.node (BTree.node x y) z) (BTree.node x (BTree.node y z))
  | symm {t u} (h : Path t u) : Path u t
  | trans {t u v} (h₁ : Path t u) (h₂ : Path u v) : Path t v
  | ctxL (v : BTree) {t u} (h : Path t u) :
      Path (BTree.node t v) (BTree.node u v)
  | ctxR (v : BTree) {t u} (h : Path t u) :
      Path (BTree.node v t) (BTree.node v u)

private theorem or_trans {a b c : SplitOctonion}
    (h₁ : a = b ∨ a = split_neg b) (h₂ : b = c ∨ b = split_neg c) :
    a = c ∨ a = split_neg c := by
  cases h₁ with
  | inl h₁ => cases h₂ with
    | inl h₂ => exact .inl (h₁.trans h₂)
    | inr h₂ => exact .inr (by rw [h₁, h₂])
  | inr h₁ => cases h₂ with
    | inl h₂ => exact .inr (by rw [h₁, h₂])
    | inr h₂ => exact .inl (by rw [h₁, h₂, split_neg_neg])

private theorem or_symm {a b : SplitOctonion} (h : a = b ∨ a = split_neg b) :
    b = a ∨ b = split_neg a := by
  cases h with
  | inl h => exact .inl h.symm
  | inr h => exact .inr (by rw [h, split_neg_neg])

/-- **Path steps move values by ±** — the engine of F2a. -/
theorem eval_path_or_neg {t u} (h : Path t u) :
    eval t = eval u ∨ eval t = split_neg (eval u) := by
  induction h with
  | refl _ => exact .inl rfl
  | rot x y z =>
      show rotOr (eval x) (eval y) (eval z)
      exact (eval_basisLike x).rotOr (eval_basisLike y) (eval_basisLike z)
  | symm _ ih => exact or_symm ih
  | trans _ _ ih₁ ih₂ => exact or_trans ih₁ ih₂
  | ctxL v _ ih =>
      simp only [eval]
      cases ih with
      | inl e => exact .inl (congrArg (fun w => split_oct_mul w (eval v)) e)
      | inr e => exact .inr (by rw [e, split_neg_mul])
  | ctxR v _ ih =>
      simp only [eval]
      cases ih with
      | inl e => exact .inl (congrArg (fun w => split_oct_mul (eval v) w) e)
      | inr e => exact .inr (by rw [e, split_mul_neg])

/-! ## Normalization to the right comb (connectivity of the rotation paths) -/

/-- Right comb of a leaf word; the `[]` value is unreachable from real
trees and pinned to `e₀`. -/
def rcomb : List (Bool × Fin 8) → BTree
  | [] => .leaf false 0
  | [w] => .leaf w.1 w.2
  | w₁ :: w₂ :: rest => .node (.leaf w₁.1 w₁.2) (rcomb (w₂ :: rest))

theorem rcomb_singleton (b : Bool) (i : Fin 8) : rcomb [(b, i)] = .leaf b i := rfl

theorem rcomb_cons (w : Bool × Fin 8) (L : List (Bool × Fin 8)) (hL : L ≠ []) :
    rcomb (w :: L) = .node (.leaf w.1 w.2) (rcomb L) := by
  cases L with
  | nil => exact absurd rfl hL
  | cons y rest => cases rest with
    | nil => rfl
    | cons z rest₂ => rfl

theorem leaves_ne_nil (t : BTree) : leaves t ≠ [] := by
  have pos : 0 < (leaves t).length := by
    induction t with
    | leaf b i => simp [leaves]
    | node l r hl hr =>
        rw [leaves, List.length_append]
        omega
  exact List.ne_nil_of_length_pos pos

/-- Two combs glued by one rotation path. -/
theorem path_rcomb_append :
    ∀ (Xs Ys : List (Bool × Fin 8)), Xs ≠ [] → Ys ≠ [] →
      Path (BTree.node (rcomb Xs) (rcomb Ys)) (rcomb (Xs ++ Ys)) := by
  intro Xs
  induction Xs with
  | nil => intro Ys hX _; exact absurd rfl hX
  | cons x xs ih =>
      intro Ys hX hY
      cases xs with
      | nil =>
          cases Ys with
          | nil => exact absurd rfl hY
          | cons y ys => exact .refl _
      | cons y ys =>
          cases Ys with
          | nil => exact absurd rfl hY
          | cons z zs =>
              refine .trans (.rot (BTree.leaf x.1 x.2)
                  (rcomb (y :: ys)) (rcomb (z :: zs))) ?_
              refine .trans (.ctxR (BTree.leaf x.1 x.2) (ih (z :: zs) (by simp) hY)) (.refl _)

/-- **Every bracketing is a rotation path away from the right comb of its
leaf word.** -/
theorem path_rcomb (t : BTree) : Path t (rcomb (leaves t)) := by
  induction t with
  | leaf b i =>
      rw [leaves, rcomb_singleton]
      exact .refl _
  | node l r hl hr =>
      have h1 : Path (BTree.node l r)
          (BTree.node (rcomb (leaves l)) (rcomb (leaves r))) :=
        .trans (.ctxR l hr) (.ctxL (rcomb (leaves r)) hl)
      have h2 : Path (BTree.node (rcomb (leaves l)) (rcomb (leaves r)))
          (rcomb (leaves l ++ leaves r)) :=
        path_rcomb_append _ _ (leaves_ne_nil l) (leaves_ne_nil r)
      simpa [leaves] using h1.trans h2

/-- **F2a — skeleton bracketing coherence (all n).** Any two bracketings
of the same signed-basis word evaluate to equal or negated values. The
bracketing defect of the skeleton is a sign, with no scale and no
direction change, for every word length — the theorem that makes
"evaluation order changes an octonion-network product only by a
cocycle-computed sign" literal. (Over arbitrary continuum values the
analogue is false; see the module header and 058 F2c/Artin.) -/
theorem basisWord_eq_or_neg {t u : BTree} (h : leaves t = leaves u) :
    eval t = eval u ∨ eval t = split_neg (eval u) := by
  have ht := eval_path_or_neg (path_rcomb t)
  have hu := eval_path_or_neg (path_rcomb u)
  rw [h] at ht
  cases ht with
  | inl ht => cases hu with
    | inl hu => exact .inl (by rw [ht, hu])
    | inr hu => exact .inr (by rw [ht, hu, split_neg_neg])
  | inr ht => cases hu with
    | inl hu => exact .inr (by rw [ht, hu])
    | inr hu => exact .inl (by rw [ht, hu])

end Coherence
