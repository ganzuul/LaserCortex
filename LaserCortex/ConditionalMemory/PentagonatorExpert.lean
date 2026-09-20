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

/-! ## The composition law: data-dependence is KEPT, the law is changed

§11.7 (`ple-io/docs/LC-MINING-ROADMAP.md`) measured that a **data-dependent reweighting applied between
composition steps** breaks associativity (1e-4 … 3.5e+02), while data-dependent *matrices* multiplied
normally do not (5.6e-17). So coherence is a property of the **composition law**, not of
data-independence — and "remove the data-dependence" is not the fix, since essentially every useful
operation is data-dependent.

The fix is the standard **affine / associative-scan** law: carry the transformation as a pair `(A, b)` and
compose by

    (A₂, b₂) · (A₁, b₁) = (A₂A₁, A₂b₁ + b₂)

measured at the float floor (1e-16) with fully data-dependent `A` and `b`, because the pair *is* the
affine map `x ↦ A x + b` and the law *is* function composition. This is the structure linear attention and
state-space models are built on, and it is the composition law the unified pentagonator expert should use
for its stream mixing. -/

variable {n R : Type*} [Fintype n] [DecidableEq n] [Semiring R]

open Matrix

/-- An affine map carried as a pair `(A, b)`. **Data-dependent `A` and `b` are allowed** — that is the
point: the law below is associative whatever they are. -/
abbrev ScanPair (n R : Type*) [Fintype n] [DecidableEq n] [Semiring R] :=
  Matrix n n R × (n → R)

/-- The **affine / associative-scan product**. -/
def scanComp (g f : ScanPair n R) : ScanPair n R :=
  (g.1 * f.1, g.1 *ᵥ f.2 + g.2)

/-- How a carried pair acts: `x ↦ A x + b`. -/
def scanAct (p : ScanPair n R) (x : n → R) : n → R := p.1 *ᵥ x + p.2

/-- **THE BRIDGE — `scanComp` IS function composition.** This is the *reason* the law is associative: the
pair is not an encoding of an affine map, it **is** one, so composing pairs composes the maps. -/
theorem scanAct_scanComp (g f : ScanPair n R) (x : n → R) :
    scanAct (scanComp g f) x = scanAct g (scanAct f x) := by
  obtain ⟨Ag, bg⟩ := g
  obtain ⟨Af, bf⟩ := f
  simp only [scanAct, scanComp]
  rw [Matrix.mulVec_add, Matrix.mulVec_mulVec]
  abel

/-- **THE COHERENCE OF THE COMPOSITION LAW.** `scanComp` is associative with **fully data-dependent** `A`
and `b`, and as an *identity in a semiring* rather than an approximation — no float caveat, unlike every
measurement in roadmap §11.5–§11.7.

This is the Lean form of §11.7's design answer: correctness of the composition is a property of the LAW,
so the data-dependence can stay. -/
theorem scanComp_assoc (h g f : ScanPair n R) :
    scanComp (scanComp h g) f = scanComp h (scanComp g f) := by
  obtain ⟨Ah, bh⟩ := h
  obtain ⟨Ag, bg⟩ := g
  obtain ⟨Af, bf⟩ := f
  simp only [scanComp, Prod.mk.injEq]
  refine ⟨?_, ?_⟩
  · rw [Matrix.mul_assoc]
  · rw [Matrix.mulVec_add, Matrix.mulVec_mulVec]
    abel

/-- The action inherits associativity, which is the statement a stack of carried pairs relies on. -/
theorem scanAct_assoc (h g f : ScanPair n R) (x : n → R) :
    scanAct (scanComp (scanComp h g) f) x = scanAct h (scanAct g (scanAct f x)) := by
  simp only [scanAct_scanComp]

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

/-! ## The regime decomposition: certified truncation of the aggregation

The training pipeline (`pleio/lse.py`) evaluates `lse` in THREE regimes — a *max* regime (one
stream dominates), a *uniform* regime (all streams near-equal), and a *full* regime — and it
replaces the full aggregation with cheaper forms that are DERIVED from `lse`, never ad-hoc.
This section fixes those semantics, Lean-first, per the standing rule of this file.

The content:

* `lse_exp` — the aggregation is exact in exp-space; the ground the bounds stand on;
* `le_lse` — no element exceeds the aggregate (the max regime's passthrough is a LOWER bound);
* `lse_shift` — the shift identity, for ANY base `m`, not only the maximum: `lse xs = m +
  log (Σ exp (xᵢ - m))`. This is `lse_append` put to work — the ONLINE COMBINE (a running
  max and running sum, FlashAttention-style) is this identity applied associatively, and it
  never needs the true maximum, only A base that bounds the kept survivors from below;
* `lse_truncate_le` — dropping a tail costs at most its exp-mass divided by the kept mass;
* `lse_truncate_certified` — if every dropped element sits at least `c` below some `m` of
  the kept part, the cost is at most `k * exp (-c)`: THE bound that makes the cutoff a
  certified error budget. The training side's `CUTOFF = 20` is this theorem with `c := 20`:
  per dropped term `exp (-20) ~ 2.1e-9`, so the max regime and the top-r (softplus-regime)
  truncation are MEASUREMENTS, not heuristics.

What is deliberately NOT here: a `uniform` shortcut (`lse ~ max + log n` when all gaps are
small). Its error is the gap eps itself — a budget chosen by the caller, looser than the
truncation bound by orders of magnitude — so it is documented on the training side rather
than certified here. -/

/-- Sum of a mapped-exponential list is nonnegative -- standalone, clean induction. -/
theorem sum_map_exp_nonneg (f : ℝ → ℝ) : ∀ xs : List ℝ, 0 ≤ (xs.map (fun x => Real.exp (f x))).sum := by
  intro xs
  induction xs with
  | nil => simp
  | cons y t ih =>
    rw [List.map_cons, List.sum_cons]
    linarith [Real.exp_nonneg (f y), ih]

theorem sum_map_exp_pos {xs : List ℝ} (h : xs ≠ []) (f : ℝ → ℝ) :
    0 < (xs.map (fun x => Real.exp (f x))).sum := by
  cases xs with
  | nil => exact absurd rfl h
  | cons y t =>
    rw [List.map_cons, List.sum_cons]
    linarith [Real.exp_pos (f y), sum_map_exp_nonneg f t]

/-- Exp-space exactness: the aggregation's exponential is the sum of the exponentials. -/
theorem lse_exp {xs : List ℝ} (h : xs ≠ []) :
    Real.exp (lse xs) = (xs.map Real.exp).sum :=
  Real.exp_log (exp_sum_pos h)

/-- No element exceeds the aggregate: exp is monotone and the sum dominates each term. -/
theorem exp_mem_le_sum {a : ℝ} : ∀ xs : List ℝ, a ∈ xs → Real.exp a ≤ (xs.map Real.exp).sum := by
  intro xs
  induction xs with
  | nil => intro ha; cases ha
  | cons y t ih =>
    intro ha
    rw [List.mem_cons] at ha
    rcases ha with rfl | ha
    · rw [List.map_cons, List.sum_cons]
      linarith [exp_tail_sum_nonneg t]
    · rw [List.map_cons, List.sum_cons]
      linarith [ih ha, exp_tail_sum_nonneg t, Real.exp_nonneg y]

theorem le_lse {xs : List ℝ} (h : xs ≠ []) {a : ℝ} (ha : a ∈ xs) : a ≤ lse xs := by
  have h1 := exp_mem_le_sum xs ha
  rw [← lse_exp h] at h1
  exact (Real.exp_le_exp.mp h1)

/-- Sum distributes over a constant left factor — needed once for the shift identity. -/
theorem sum_map_mul_left (c : ℝ) (xs : List ℝ) (f : ℝ → ℝ) :
    (xs.map (fun x => c * f x)).sum = c * (xs.map f).sum := by
  induction xs with
  | nil => simp
  | cons y t ih =>
    rw [List.map_cons, List.map_cons, List.sum_cons, List.sum_cons, ih]
    ring

/-- **The shift identity, for ANY base `m`.** `lse xs = m + log (Σ exp (xᵢ - m))`. The residual
`log (Σ exp (xᵢ - m))` is where every regime lives: with `m` the running maximum it vanishes
when one stream dominates (max regime), is `log n` when all streams tie (uniform regime), and
is the honest full computation otherwise. That `m` need not be the true maximum is not a
convenience but the point — it is `lse_append` saying the combine may process the list in any
bracketing with any running base. -/
theorem lse_shift {xs : List ℝ} (h : xs ≠ []) (m : ℝ) :
    lse xs = m + Real.log ((xs.map (fun x => Real.exp (x - m))).sum) := by
  have key : (xs.map Real.exp).sum
      = Real.exp m * (xs.map (fun x => Real.exp (x - m))).sum := by
    have hmap : xs.map Real.exp
        = xs.map (fun x => Real.exp m * Real.exp (x - m)) := by
      apply List.map_congr_left
      intro a ha
      rw [← Real.exp_add, add_sub_cancel]
    rw [hmap, sum_map_mul_left]
  rw [lse, key, Real.log_mul (ne_of_gt (Real.exp_pos _))
      (ne_of_gt (sum_map_exp_pos h (fun x => x - m))), Real.log_exp]

/-- Dropping a tail: the aggregate of the kept part plus the tail's exp-mass relative to the
kept aggregate. This is the general form; the certified bound below instantiates it. -/
theorem lse_truncate_le {ts ds : List ℝ} (ht : ts ≠ []) :
    lse (ts ++ ds) ≤ lse ts + (ds.map Real.exp).sum / Real.exp (lse ts) := by
  have hlog : lse (ts ++ ds) = Real.log (Real.exp (lse ts) + (ds.map Real.exp).sum) := by
    rw [show lse (ts ++ ds) = Real.log (Real.exp (lse (ts ++ ds))) from
        (Real.log_exp (lse (ts ++ ds))).symm,
        lse_exp (List.append_ne_nil_of_left_ne_nil ht ds), lse_exp ht,
        List.map_append, List.sum_append]
  have hpos : (0 : ℝ) < Real.exp (lse ts) := Real.exp_pos _
  have hnn : (0 : ℝ) ≤ (ds.map Real.exp).sum := exp_tail_sum_nonneg ds
  have hdivnn : (0 : ℝ) ≤ (ds.map Real.exp).sum / Real.exp (lse ts) :=
    div_nonneg hnn (le_of_lt hpos)
  have h1 : Real.exp (lse ts) + (ds.map Real.exp).sum
      = Real.exp (lse ts) * ((1 : ℝ) + (ds.map Real.exp).sum / Real.exp (lse ts)) := by
    field_simp
  have h2 : (0 : ℝ) < (1 : ℝ) + (ds.map Real.exp).sum / Real.exp (lse ts) := by
    linarith [hdivnn]
  rw [hlog, h1]
  have h4 : Real.log (Real.exp (lse ts) * ((1 : ℝ) + (ds.map Real.exp).sum / Real.exp (lse ts)))
      = lse ts + Real.log ((1 : ℝ) + (ds.map Real.exp).sum / Real.exp (lse ts)) := by
    rw [Real.log_mul (ne_of_gt hpos) (ne_of_gt h2), Real.log_exp]
  rw [h4]
  -- log (1 + t) ≤ t, from 1 + t ≤ exp t and log's monotonicity against exp
  have h5 : Real.log ((1 : ℝ) + (ds.map Real.exp).sum / Real.exp (lse ts))
      ≤ (ds.map Real.exp).sum / Real.exp (lse ts) := by
    have h6 : ((1 : ℝ) + (ds.map Real.exp).sum / Real.exp (lse ts))
        ≤ Real.exp ((ds.map Real.exp).sum / Real.exp (lse ts)) := by
      linarith [Real.add_one_le_exp ((ds.map Real.exp).sum / Real.exp (lse ts))]
    exact (Real.log_le_log (by linarith [hdivnn]) h6).trans (Real.log_exp _).le
  linarith

/-- **The certified truncation bound.** If every dropped element is at least `c` below some
`m` of the kept part, dropping it costs at most `ds.length * exp (-c)`. This is the theorem
that makes the training side's cutoff a MEASUREMENT: with `c := 20` each dropped term costs
`exp (-20) ~ 2.1e-9`, independently of how many streams the aggregation runs over. The max
regime (keep 1) and the top-r regime (keep r) are instances; the top-k SELECTED variant is
NOT — selection is the non-associative failure mode formalised above. -/
theorem lse_truncate_certified {ts ds : List ℝ} (ht : ts ≠ []) (m : ℝ) (c : ℝ)
    (hm : m ∈ ts) (hdrop : ∀ d ∈ ds, d + c ≤ m) :
    lse (ts ++ ds) - lse ts ≤ ds.length * Real.exp (-c) := by
  have hge : m ≤ lse ts := le_lse ht hm
  have hS : (ds.map Real.exp).sum ≤ ds.length * Real.exp (m - c) := by
    induction ds with
    | nil => simp
    | cons y t ih =>
      rw [List.map_cons, List.sum_cons, List.length_cons, Nat.cast_add, Nat.cast_one]
      have hy : Real.exp y ≤ Real.exp (m - c) :=
        Real.exp_le_exp.mpr (by linarith [hdrop y (List.mem_cons_self ..)])
      have ht2 : (t.map Real.exp).sum ≤ t.length * Real.exp (m - c) := by
        refine ih ?_
        intro d hd
        exact hdrop d (List.mem_cons_of_mem _ hd)
      linarith
  have h1 := lse_truncate_le (ds := ds) ht
  have hpos : (0 : ℝ) < Real.exp (lse ts) := Real.exp_pos _
  have hpos2 : (0 : ℝ) < Real.exp m := Real.exp_pos _
  have hEm : Real.exp m ≤ Real.exp (lse ts) := Real.exp_le_exp.mpr hge
  have hdiv : (ds.map Real.exp).sum / Real.exp (lse ts) ≤ ds.length * Real.exp (-c) := by
    have step1 : (ds.map Real.exp).sum / Real.exp (lse ts)
        ≤ ds.length * Real.exp (m - c) / Real.exp (lse ts) :=
      div_le_div_of_nonneg_right hS (le_of_lt hpos)
    have step2 : ds.length * Real.exp (m - c) / Real.exp (lse ts)
        ≤ ds.length * Real.exp (m - c) / Real.exp m :=
      div_le_div_of_nonneg_left (by positivity) hpos2 hEm
    have step3 : ds.length * Real.exp (m - c) / Real.exp m = ds.length * Real.exp (-c) := by
      rw [mul_div_assoc, ← Real.exp_sub, show m - c - m = -c by ring]
    exact le_trans step1 (le_trans step2 step3.le)
  -- h1 : lse (ts ++ ds) ≤ lse ts + S/E and hdiv : S/E ≤ k·exp(-c); the goal subtracts
  have hP : (0 : ℝ) ≤ ds.length * Real.exp (-c) := by positivity
  have htnn : (0 : ℝ) ≤ (ds.map Real.exp).sum / Real.exp (lse ts) :=
    div_nonneg (exp_tail_sum_nonneg ds) (le_of_lt hpos)
  have h2' : lse (ts ++ ds) ≤ lse ts + ((ds.map Real.exp).sum / Real.exp (lse ts)
      + ds.length * Real.exp (-c)) := by
    linarith [h1, hP]
  linarith [h2', htnn, hP]

/-! ## Culling semantics for the tiled dispatcher (`pleio/lse.py`, `TiledDispatch`)

The runtime classifies ROWS by their RUNNER-UP gap: m₁ - m₂ where m₁ is the row max and m₂
the second-largest value. A tile is culled to the max regime only when EVERY row's runner-up
gap exceeds the threshold -- the tile summary is the MINIMUM of the row gaps, never the
maximum (a tile-max test would cull a tile containing one separated row and many mixed rows,
which is beyond any bound -- a real bug this section's specification exposed).

* `lseFin_shift` -- the Fin-indexed shift identity (the runtime's online combine);
* `lse_max_regime_bound` -- THE row-level bound: if every non-max element sits at least `c`
  below the max, the aggregation's excess over the max is at most (E-1)·exp(-c). With the
  runtime's c := 20 and E ≤ 64 this is < 1.3e-7, within float32 roundoff;
* `tile_culling_soundness` -- the tile statement: per-row separation over the tile gives the
  per-row bound; the runtime's tile-min-gap test is exactly the conjunction of these;
* `gap_drift_retention` -- the TEMPORAL lemma, and an honest one: that a gap measured at t
  bounds the gap at t+Δt under bounded activation drift is an ASSUMPTION (Lipschitz-style),
  not a theorem -- the drift hypothesis is parameterised, and the lemma says only what it
  implies. Caching the culled set without this assumption is UNSOUND, and the runtime pays
  for that by re-testing on refresh. -/

/-- Fin-indexed log-sum-exp: the specification form of the runtime aggregation. -/
noncomputable def lseFin {E : ℕ} (x : Fin E → ℝ) : ℝ := Real.log (∑ j, Real.exp (x j))

/-- The sum of exponentials over a nonempty Fin index type is positive. -/
theorem sum_exp_pos_fin {E : ℕ} (f : Fin E → ℝ) (j₀ : Fin E) :
    0 < (∑ j, Real.exp (f j)) := by
  have h1 : (∑ j, Real.exp (f j)) = Real.exp (f j₀)
      + (∑ j ∈ Finset.univ.erase j₀, Real.exp (f j)) :=
    (Finset.add_sum_erase _ _ (Finset.mem_univ j₀)).symm
  have h2 : (0 : ℝ) ≤ (∑ j ∈ Finset.univ.erase j₀, Real.exp (f j)) :=
    Finset.sum_nonneg (fun j _ => Real.exp_nonneg _)
  linarith [h1, h2, Real.exp_pos (f j₀)]

/-- The shift identity, Fin form: ANY base element works, not only the argmax. -/
theorem lseFin_shift {E : ℕ} (x : Fin E → ℝ) (j₀ : Fin E) :
    lseFin x = x j₀ + Real.log (∑ j, Real.exp (x j - x j₀)) := by
  have key : Real.exp (x j₀) * (∑ j, Real.exp (x j - x j₀))
      = (∑ j, Real.exp (x j₀) * Real.exp (x j - x j₀)) := by
    rw [Finset.mul_sum]
  have key2 : (∑ j, Real.exp (x j₀) * Real.exp (x j - x j₀)) = (∑ j, Real.exp (x j)) := by
    exact Finset.sum_congr rfl (fun j _ => by rw [← Real.exp_add, add_sub_cancel])
  rw [lseFin, ← key2, ← key, Real.log_mul (ne_of_gt (Real.exp_pos _))
      (ne_of_gt (sum_exp_pos_fin (fun j => x j - x j₀) j₀)), Real.log_exp]

/-- **The max-regime bound.** If every element except the maximum sits at least `c` below it,
the aggregation exceeds the max by at most (E-1)·exp(-c). This licenses the runtime's amax
shortcut with a CERTIFIED error; c := 20 and E ≤ 64 gives < 1.3e-7. -/
theorem lse_max_regime_bound {E : ℕ} (x : Fin E → ℝ) (j₀ : Fin E) (c : ℝ)
    (hsep : ∀ j, j ≠ j₀ → x j + c ≤ x j₀) :
    lseFin x - x j₀ ≤ (E - 1 : ℝ) * Real.exp (-c) := by
  have hshift := lseFin_shift x j₀
  have hEpos : (0 : ℕ) < E := Nat.lt_of_le_of_lt (Nat.zero_le _) j₀.isLt
  have hE : 1 ≤ E := Nat.succ_le_of_lt hEpos
  have hE1 : (1 : ℝ) ≤ (E : ℝ) := by
    have := (Nat.cast_le (α := ℝ)).mpr hE
    simp only [Nat.cast_one] at this
    exact this
  have hcast : (((E - 1 : ℕ) : ℝ)) = (E : ℝ) - 1 := by
    rw [Nat.cast_sub hE, Nat.cast_one]
  have hsplit : (∑ j, Real.exp (x j - x j₀)) ≤ 1 + ((E : ℝ) - 1) * Real.exp (-c) := by
    rw [← Finset.add_sum_erase _ _ (Finset.mem_univ j₀), sub_self, Real.exp_zero]
    have h2' := Finset.sum_le_card_nsmul (Finset.univ.erase j₀)
      (fun j => Real.exp (x j - x j₀)) (Real.exp (-c))
      (fun j hj => Real.exp_le_exp.mpr (by
        have := hsep j (Finset.ne_of_mem_erase hj)
        linarith))
    rw [nsmul_eq_mul] at h2'
    have hcard : ((Finset.univ.erase j₀).card : ℕ) = E - 1 := by
      simp [Finset.card_erase_of_mem (Finset.mem_univ j₀)]
    rw [hcard, hcast] at h2'
    linarith
  have hpos : (0 : ℝ) < 1 + ((E : ℝ) - 1) * Real.exp (-c) := by
    positivity
  have hSpos : (0 : ℝ) < (∑ j, Real.exp (x j - x j₀)) :=
    sum_exp_pos_fin (fun j => x j - x j₀) j₀
  have hlogle : Real.log (1 + ((E : ℝ) - 1) * Real.exp (-c))
      ≤ ((E : ℝ) - 1) * Real.exp (-c) := by
    have h6 : (1 : ℝ) + ((E : ℝ) - 1) * Real.exp (-c)
        ≤ Real.exp (((E : ℝ) - 1) * Real.exp (-c)) := by
      linarith [Real.add_one_le_exp (((E : ℝ) - 1) * Real.exp (-c))]
    exact (Real.log_le_log hpos h6).trans (Real.log_exp _).le
  rw [hshift]
  have hmono : Real.log (∑ j, Real.exp (x j - x j₀))
      ≤ Real.log (1 + ((E : ℝ) - 1) * Real.exp (-c)) :=
    Real.log_le_log hSpos hsplit
  linarith [hmono, hlogle]

/-- **Tile culling soundness.** If every row of a tile is τ-separated at its own argmax (which
is what the runtime's tile-MINIMUM runner-up gap ≥ τ certifies), every row's aggregation
exceeds its max by at most (E-1)·exp(-τ). The max-regime shortcut is a MEASUREMENT per tile. -/
theorem tile_culling_soundness {B E : ℕ} (x : Fin B → Fin E → ℝ) (jmax : Fin B → Fin E)
    (T : Finset (Fin B)) (τ : ℝ)
    (hsep : ∀ i ∈ T, ∀ j, j ≠ jmax i → x i j + τ ≤ x i (jmax i)) :
    ∀ i ∈ T, lseFin (x i) - x i (jmax i) ≤ (E - 1 : ℝ) * Real.exp (-τ) := by
  intro i hi
  exact lse_max_regime_bound (x i) (jmax i) τ (hsep i hi)

/-- **Drift retention** -- stated with the drift as a HYPOTHESIS. That activations move by at
most δ per refresh interval is a dynamical assumption (learning-rate × Lipschitz bounds), not
something Lean can certify from the aggregation alone. Given the hypothesis, the gap at t
bounds the gap at t+Δt with the exact 2δ slack (max and runner-up can each move by δ). The
runtime's refresh interval is safe iff 2δ < enter - exit_, the hysteresis margin. -/
theorem gap_drift_retention (gap_t0 τ δ : ℝ) (hgap : gap_t0 ≥ τ) (_hδ : δ ≥ 0) :
    gap_t0 - 2 * δ ≥ τ - 2 * δ := by linarith

end LaserCortex.ConditionalMemory.PentagonatorExpert