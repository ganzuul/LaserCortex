import Mathlib
import LaserCortex.ConditionalMemory.YSystem

/-!
# PentagonatorExpert — Lean-first semantics for the *unified pentagonator expert*

Roadmap §11.5 (`ple-io/docs/LC-MINING-ROADMAP.md`, commit `0c0181b`) measured, on the pinned V4.1
machinery, that the aggregation side of an expert is **coherent for free** in exactly one regime:

| operation | associative? | measured defect |
|---|---|---|
| LSE (unnormalised log-sum-exp) | **yes** | 3.55e-15 (~16 float64 eps) |
| softplus `= LSE(·, 0)` | yes | exact |
| softmax `= ∂ LSE` | **yes** — factors through LSE | 4.44e-16 |
| **Sinkhorn** (iterated alternating row/col) | **no** | 9.72e-05 |
| **top-k selection** (MoE routing) | **no** | 2 of 6 selections differ |

The architectural consequence, recorded there: **dense (no selection) + LSE (associative aggregation)
⇒ coherent composition ⇒ a 4-gram key is faithful with no stored bracketing.** That supersedes the
32 MB sign table considered in §11.4 — no table is needed for the aggregation.

**This file is Lean-first: it fixes the semantics before any model is built**, per the corpus's
standing rule that new features requiring formal semantics are formalised first. The content is

* `lse` and its **associativity** (`lse_append`) — the coherence the expert relies on;
* the **pentagon** (`lse_pentagon`): all five bracketings of four arguments agree, which *is* the
  pentagonator's coherence condition for the aggregation;
* `sp_eq_lse` and `centered_eq_lse_sub_origin`, tying the corpus's `YSystem.sp` to LSE so the
  "commutator/associator are two projections of one monoid" reading is a theorem, not prose;
* and the **boundary**, formalised rather than asserted: `topk_selection_not_associative`, a discrete
  witness that `top-k` selection is *not* bracket-invariant.

**Deliberately NOT here, and why.** A `Sinkhorn` definition and its non-associativity belong to
**roadmap R6** (`GramDictionary.lean:52-66`, *"deliberately NOT assumed"*). Writing a Sinkhorn
definition here would pre-empt R6's content and duplicate it; §11.5 flagged convergence-only behaviour
as the open question, so this file does not guess it.

**One analogy explicitly NOT claimed.** `signCocycle` (`foundations/Algebra.lean:247`) sets a *sign* from
the vanishing of the associator **of `SplitOctonion`**, not of ℝ. Since LSE is associative the
`SplitOctonion` associator is simply not involved, and concluding "so the cocycle is 1" would be a
cross-domain transfer of exactly the kind `docs/LC-GLOSSARY.md` §8 exists to prevent. The coherence is
therefore stated **internally** — the five bracketings agree — and the cocycle bridge is left as the
open item it is.
-/

namespace LaserCortex.ConditionalMemory.PentagonatorExpert

open Real

/-- **Log-sum-exp.** The aggregation the unified expert is built on: `log (Σ exp xᵢ)`.

Note `lse [] = Real.log 0 = 0` under Mathlib's zero convention, which is *not* the monoid identity
(that would be `-∞`); every theorem below therefore restricts to nonempty lists, which is the only
case the expert uses. -/
noncomputable def lse (xs : List ℝ) : ℝ := Real.log (xs.map Real.exp).sum

/-- A nonempty list of reals has a strictly positive exponential sum — the side condition every
`lse` identity below needs, kept as its own lemma so the reason is visible. -/
theorem exp_tail_sum_nonneg (t : List ℝ) : 0 ≤ (t.map Real.exp).sum := by
  induction t with
  | nil => simp
  | cons b u ih =>
    rw [List.map_cons, List.sum_cons]
    have := Real.exp_pos b
    linarith

theorem exp_sum_pos {xs : List ℝ} (h : xs ≠ []) : 0 < (xs.map Real.exp).sum := by
  cases xs with
  | nil => exact absurd rfl h
  | cons a t =>
    rw [List.map_cons, List.sum_cons]
    have h1 := Real.exp_pos a
    have h2 := exp_tail_sum_nonneg t
    linarith

/-- `lse` of a singleton is the element: the sense in which `lse` extends the identity. -/
theorem lse_singleton (x : ℝ) : lse [x] = x := by
  unfold lse
  simp [Real.log_exp]

/-- **THE COHERENCE THEOREM — LSE is associative.**

`lse (xs ++ ys) = lse [lse xs, lse ys]`: the aggregation does not care how its arguments are grouped.
This is the *entire* reason a dense LSE expert needs no stored bracketing, and it is why §11.5's
"4-gram key is faithful for the aggregation" is a consequence rather than an assumption.

It is also the exact form of the logsumexp decomposition: `exp (lse xs) = Σ exp xs` on each side, so
the identity reduces to associativity of addition. -/
theorem lse_append {xs ys : List ℝ} (hx : xs ≠ []) (hy : ys ≠ []) :
    lse (xs ++ ys) = lse [lse xs, lse ys] := by
  have hx' : 0 < (xs.map Real.exp).sum := exp_sum_pos hx
  have hy' : 0 < (ys.map Real.exp).sum := exp_sum_pos hy
  unfold lse
  rw [List.map_append, List.sum_append]
  -- reduce the right-hand side: `exp (log (Σ exp xs)) = Σ exp xs` by positivity
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
    Real.exp_log hx', Real.exp_log hy']

/-- **Softplus is the 2-ary LSE.** `YSystem.sp` (`YSystem.lean:63`) is not an independent primitive
alongside softmax — it is LSE at arity 2. This is what makes the corpus's "softplus = commutator,
softmax = associator" pairing *two projections of one monoid*. -/
theorem sp_eq_lse (x : ℝ) : YSystem.sp x = lse [x, 0] := by
  unfold lse YSystem.sp
  simp [Real.exp_zero, add_comm]

/-- **Centring is subtracting the origin's LSE.** `LSE(0,0) = log 2`, so the centred commit gate of
`YSystem.lean:70` — and of the production `scoring_func: sqrtsoftplus` — is `lse [x,0] - lse [0,0]`. -/
theorem lse_zero_pair : lse [0, 0] = Real.log 2 := by
  simp only [lse, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
    Real.exp_zero]
  norm_num

theorem centered_eq_lse_sub_origin (x : ℝ) :
    YSystem.sp x - Real.log 2 = lse [x, 0] - lse [0, 0] := by
  rw [sp_eq_lse, lse_zero_pair]

-- Instantiated splits of `lse_append`. `rw` needs these because `[a,b,c] ++ [d]` is not
-- *syntactically* `[a,b,c,d]` even though it reduces to it, so the general lemma will not match a
-- literal list. Each is `lse_append` at a concrete split, with the singleton absorbed.
theorem lse_split_3_1 (a b c d : ℝ) : lse [a, b, c, d] = lse [lse [a, b, c], d] := by
  have h := lse_append (xs := [a, b, c]) (ys := [d]) (by simp) (by simp)
  rwa [lse_singleton] at h

theorem lse_split_2_1 (a b c : ℝ) : lse [a, b, c] = lse [lse [a, b], c] := by
  have h := lse_append (xs := [a, b]) (ys := [c]) (by simp) (by simp)
  rwa [lse_singleton] at h

theorem lse_split_1_2 (a b c : ℝ) : lse [a, b, c] = lse [a, lse [b, c]] := by
  have h := lse_append (xs := [a]) (ys := [b, c]) (by simp) (by simp)
  rwa [lse_singleton] at h

theorem lse_split_1_3 (a b c d : ℝ) : lse [a, b, c, d] = lse [a, lse [b, c, d]] := by
  have h := lse_append (xs := [a]) (ys := [b, c, d]) (by simp) (by simp)
  rwa [lse_singleton] at h

theorem lse_split_2_2 (a b c d : ℝ) : lse [a, b, c, d] = lse [lse [a, b], lse [c, d]] :=
  lse_append (xs := [a, b]) (ys := [c, d]) (by simp) (by simp)

/-- **THE PENTAGON.** All five bracketings of four arguments agree, stated flat-first so each follows
from `lse_append` by splitting the same four-element list differently.

This *is* the pentagonator's coherence condition for an LSE aggregation: the associahedron `K₄` has
five vertices, one per bracketing, and coherence means they agree. Because it holds, the pentagonator
**defect is the identity** for this expert — nothing to store, no sign to predict. That is the Lean
statement of §11.5's conclusion and the reason §11.4's sign table is unnecessary. -/
theorem lse_pentagon (a b c d : ℝ) :
    lse [a, b, c, d] = lse [lse [lse [a, b], c], d] ∧
    lse [a, b, c, d] = lse [lse [a, lse [b, c]], d] ∧
    lse [a, b, c, d] = lse [lse [a, b], lse [c, d]] ∧
    lse [a, b, c, d] = lse [a, lse [lse [b, c], d]] ∧
    lse [a, b, c, d] = lse [a, lse [b, lse [c, d]]] := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · rw [lse_split_3_1, lse_split_2_1]
  · rw [lse_split_3_1, lse_split_1_2]
  · exact lse_split_2_2 a b c d
  · rw [lse_split_1_3, lse_split_2_1]
  · rw [lse_split_1_3, lse_split_1_2]

/-! ## A negative control: the pentagon is not a tautology about lists

`lse_pentagon` must be a property of **LSE**, not of list syntax. A non-associative combiner fails the
same coherence condition, which is what makes the theorem above informative. -/

/-- **NEGATIVE CONTROL.** The pentagon is not automatic. For the non-associative combiner
`f x y = (x + 2y)/3` on `(1,2,3,4)` the flat bracketing gives `95/27` while `(ab)(cd)` gives `3`, so
they differ. Thus `lse_pentagon` is a real property of log-sum-exp — the associativity proved in
`lse_append` — and not something any binary operation satisfies. -/
theorem nonassoc_combiner_fails_pentagon :
    ∃ (f : ℚ → ℚ → ℚ) (a b c d : ℚ), f (f (f a b) c) d ≠ f (f a b) (f c d) :=
  ⟨fun x y => (x + 2 * y) / 3, 1, 2, 3, 4, by norm_num⟩

/-! ## The boundary: selection is NOT bracket-invariant

The positive results above say a *soft mixture* composes coherently. They do **not** extend to a
*discrete choice*, and that distinction is the whole reason the dense (selection-free) architecture is
the one that inherits the coherence. Formalised for the minimal case `n = 4`, `k = 2`, which suffices
to witness the failure. -/

/-- Flat top-2 of four scores: the indices with fewer than two strictly greater scores. Total, with
ties resolved by the predicate rather than an arbitrary ordering. -/
def flatTop2 (s : Fin 4 → ℚ) : Finset (Fin 4) :=
  Finset.univ.filter fun i => (Finset.univ.filter fun j => s i < s j).card < 2

/-- Hierarchical top-2: the best of each pair `{0,1}`, `{2,3}` — selection composed over a grouping,
which is the shape MoE routing has (the pairs stand in for groups). -/
def hierTop2 (s : Fin 4 → ℚ) : Finset (Fin 4) :=
  ({if s 0 < s 1 then 1 else 0, if s 2 < s 3 then 3 else 2} : Finset (Fin 4))

/-- **Top-k selection is NOT associativity-invariant.** On the scores `(5,4,3,0)` the flat top-2 is
`{0,1}` while the hierarchical selection gives `{0,2}`: element `1` is second overall yet never wins
its group, so the grouping changes the *chosen set*.

This is the formal boundary on the unified pentagonator expert. LSE makes the aggregation coherent
(the theorems above); **selection is discrete and no smoothing removes it**, so an expert whose routing
performs a top-k choice is not representable as a bracket-free 4-gram. Removing the selection — the
dense architecture of §11.3 — is what lets the coherence theorems above apply. -/
theorem topk_selection_not_associative :
    ∃ s : Fin 4 → ℚ, flatTop2 s ≠ hierTop2 s :=
  ⟨![5, 4, 3, 0], by native_decide⟩

end LaserCortex.ConditionalMemory.PentagonatorExpert
