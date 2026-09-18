import Mathlib

/-!
# SpectrumOrder — R3: k-spectrum order reconstruction (Lean certificates)

R2 established (see `EngramReference.lean` §R2) that *"every anchored w-window of
the needle occurs in the host"* is **sound but merely NECESSARY**. Its decoy —
windows all present, nowhere contiguous — was an assertion in
`reference/ple_io.py`. R3 is the chaining theory that decides what the bag can and
cannot recover, and this file is its first certified instalment.

The naive hope is: *"the 2-gram edge bag determines the sequence up to rotation and
reversal (de Bruijn–Eulerian uniqueness)"*. **That hope is false**, and the main
result here is the machine-checked counterexample that kills it
(`edgeBag_does_not_determine_order`): over a vertex with three loops,
`[1,2,1,3,1,4,1]` and `[1,3,1,2,1,4,1]` carry the *same* edge bag and are neither
rotations nor reversals of each other. Any sufficiency theorem must therefore
carry a connectivity/degree hypothesis, and R3's job is to find the sharp one.

## Certified here (`sorry`-free, no axioms beyond Mathlib's three)

- `edges_cons`, `edges_append` — the **SEAM LAW**: chaining two fragments adds
  *exactly one* ordered boundary edge to the bag. This is the precise form of the
  "commutativity/associativity" claim in the roadmap: the bag channel is
  commutative *within* a fragment, and the entire order content of a concatenation
  lives in the single seam edge.
- `edges_length`, `edgeBag_card` — length recovery: |edges| + 1 = |s| for s ≠ [].
- `allWindows_present_not_contiguous` — the **decoy theorem**, machine-checked
  (upgrades the R2 assertion in `reference/ple_io.py` from experiment to proof).
- `edgeBag_does_not_determine_order` — the **counterexample**, i.e. the negative
  control on R3's own statement.

## NOT yet certified (next session — stated here so it cannot be quietly assumed)

For a sequence whose 2-gram digraph is a *simple path* (every value has out-degree
≤ 1 **and** the graph is connected), the edge bag determines the sequence given its
start. The counterexample below shows the degree hypothesis is not removable; the
connectivity hypothesis is expected to be needed too. This is the sufficiency
direction, and `edgeBag_card` + `edges_append` above are its intended lemmas.
-/

namespace SpectrumOrder

variable {α : Type*}

/-- 2-grams of `s`: consecutive ordered pairs, in occurrence order, with
multiplicity. Order is retained *here* — the loss happens on the way to the bag. -/
def edges : List α → List (α × α)
  | a :: b :: t => (a, b) :: edges (b :: t)
  | _ => []

/-- 3-grams of `s`: consecutive ordered triples, with multiplicity. -/
def triples : List α → List (α × α × α)
  | a :: b :: c :: t => (a, b, c) :: triples (b :: c :: t)
  | _ => []

/-- The order-free 2-gram bag — the object the table actually stores. -/
def edgeBag (s : List α) : Multiset (α × α) := Multiset.ofList (edges s)

/-- The order-free 3-gram bag. -/
def triBag (s : List α) : Multiset (α × α × α) := Multiset.ofList (triples s)

@[simp] theorem edges_nil : edges ([] : List α) = [] := rfl

@[simp] theorem edges_singleton (a : α) : edges [a] = [] := rfl

theorem edges_cons_cons (a b : α) (t : List α) :
    edges (a :: b :: t) = (a, b) :: edges (b :: t) := rfl

/-- `edges` unfolds at the head whenever the tail is inhabited. -/
theorem edges_cons (a : α) {r : List α} (h : r ≠ []) :
    edges (a :: r) = (a, r.head h) :: edges r := by
  cases r with
  | nil => exact (h rfl).elim
  | cons b t => rfl

/-! ## The seam law -/

/-- The seam edge of a chain — `(last of the left fragment, head of the right)` —
as a **total** function, empty when either side is empty. Totality is deliberate:
it keeps the seam law below free of side conditions, so it can be `simp`-driven and
stated in the same shape the Python mirror uses. -/
def seam : List α → List α → List (α × α)
  | [], _ => []
  | [_], [] => []
  | [a], b :: _ => [(a, b)]
  | _ :: a :: rest, t => seam (a :: rest) t

@[simp] theorem seam_nil_left (t : List α) : seam [] t = [] := rfl

@[simp] theorem seam_singleton_nil (a : α) : seam [a] [] = [] := rfl

@[simp] theorem seam_singleton_cons (a b : α) (t : List α) :
    seam [a] (b :: t) = [(a, b)] := rfl

@[simp] theorem seam_cons_cons (x a : α) (rest t : List α) :
    seam (x :: a :: rest) t = seam (a :: rest) t := rfl

/-- **SEAM LAW.** Chaining two fragments reproduces the 2-gram bag exactly: the
fragments' bags plus *one* ordered boundary edge. This is the precise form of the
roadmap's "commutativity/associativity" claim — the bag channel is commutative
*within* a fragment, and the complete order content of a concatenation is the
single seam edge. Chaining is therefore exactly the assertion that a seam edge is
present, which is what the R2 decoy fails. -/
theorem edges_append (s t : List α) :
    edges (s ++ t) = edges s ++ seam s t ++ edges t := by
  induction s with
  | nil => simp
  | cons a s' ih =>
    cases s' with
    | nil =>
      cases t with
      | nil => simp
      | cons b u => simp [edges_cons_cons]
    | cons c u =>
      rw [List.cons_append] at ih
      rw [List.cons_append, List.cons_append, edges_cons_cons, ih, seam_cons_cons]
      simp [edges_cons_cons, List.append_assoc]

/-! ## Length recovery -/

theorem edges_length (s : List α) (h : s ≠ []) : (edges s).length + 1 = s.length := by
  induction s with
  | nil => exact (h rfl).elim
  | cons a t ih =>
    cases t with
    | nil => simp
    | cons b u =>
      rw [edges_cons_cons]
      have h' : b :: u ≠ [] := by simp
      have := ih h'
      simp only [List.length_cons] at this ⊢
      omega

/-- A bag with `n` facts recovers a sequence of length `n + 1`. -/
theorem edgeBag_card (s : List α) (h : s ≠ []) : (edgeBag s).card + 1 = s.length := by
  rw [edgeBag, Multiset.coe_card]
  exact edges_length s h

/-! ## Window enumeration and the decoy -/

/-- Every contiguous length-`w` window of `s`, in order of occurrence. -/
def windows (w : ℕ) (s : List α) : List (List α) :=
  (List.range (s.length - w + 1)).map (fun i => (s.drop i).take w)

/-- `t` occurs contiguously in `s` (equivalently: `t` is one of its own length's
windows). -/
def Occurs (t s : List α) : Prop := t ∈ windows t.length s

/-- The R2 decoy host: contains `(1,2,3)` and `(2,3,9)` as windows, but the
decoy's *concatenation* nowhere occurs. -/
def decoyHost : List ℕ := [1, 2, 3, 7, 2, 3, 9]

def decoyNeedle : List ℕ := [1, 2, 3, 9]

/-- **DECOY THEOREM (R2's gap, machine-checked).** Every 3-window of the needle is
a 3-window of the host, yet the needle does not occur contiguously. Presence of all
anchored windows is therefore *not* sufficient for membership: the windows must
also be *chained*, and chaining is exactly the seam-edge coherence of
`edges_append`. -/
theorem allWindows_present_not_contiguous :
    (∀ w ∈ windows 3 decoyNeedle, w ∈ windows 3 decoyHost) ∧
      ¬ Occurs decoyNeedle decoyHost := by
  -- `decide` needs the decidability of membership visible; instance search will not
  -- unfold our own non-instance `def`s at `instances` transparency, so open them.
  unfold Occurs windows
  decide

/-! ## The counterexample: R3's sufficiency needs a hypothesis -/

/-- Rotations of `s` (cyclic shifts), including `s` itself. -/
def rotations (s : List α) : List (List α) :=
  (List.range s.length).map (fun k => s.drop k ++ s.take k)

/-- `t` is `s` up to rotation or reversal — the most a purely order-free bag could
hope to determine. -/
def IsRotOrRev (s t : List α) : Prop := t ∈ rotations s ∨ t ∈ rotations s.reverse

/-- **NEGATIVE CONTROL on R3's own statement.** The 2-gram edge bag does *not*
determine the sequence up to rotation/reversal. The witnesses are two Eulerian
circuits of a figure-eight over a 3-loop vertex, sharing the edge multiset
`{(1,2),(2,1),(1,3),(3,1),(1,4),(4,1)}` while being neither rotations nor
reversals of each other. Consequently any reconstruction theorem must assume
something about the underlying digraph (a degree/connectivity condition); the
sequence's order is *not* a function of its spectrum alone. -/
theorem edgeBag_does_not_determine_order :
    edgeBag ([1, 2, 1, 3, 1, 4, 1] : List ℕ) = edgeBag [1, 3, 1, 2, 1, 4, 1] ∧
      ¬ IsRotOrRev [1, 2, 1, 3, 1, 4, 1] [1, 3, 1, 2, 1, 4, 1] := by
  constructor
  · rw [edgeBag, edgeBag, Multiset.coe_eq_coe]
    decide
  · unfold IsRotOrRev rotations
    decide

/-- The ceiling the counterexample implies: no function of the bag alone recovers
the sequence. Spelled out so `edgeBag_does_not_determine_order` cannot be read as a
statement about a single unlucky pair of sequences. -/
theorem no_bag_only_reconstruction :
    ¬ (∀ s t : List ℕ, edgeBag s = edgeBag t → IsRotOrRev s t) := by
  intro h
  have heq : edgeBag ([1, 2, 1, 3, 1, 4, 1] : List ℕ) = edgeBag [1, 3, 1, 2, 1, 4, 1] :=
    edgeBag_does_not_determine_order.1
  exact edgeBag_does_not_determine_order.2 (h _ _ heq)

end SpectrumOrder
