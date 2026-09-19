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



/-! ## R3 sufficiency: the sliding law that holds, and the obstruction that does not

Lab note 066 established (and `DistributorObstruction.lean` proved) that at CD 3 the
duoidal distributor's content fails while its *adjoint for the pairing* still exists:
`β(u*v, w) = β(v, S(u)*w)` is the sliding law, it holds at CD ≤ 2
(`Chu.lean:380`), and it fails at CD 3 on exactly three Fano lines. The lesson there
was that a shuffle **depending on the factorization of its input rather than its
product** cannot be linear (`Chu.lean:451-470`).

The theorems below are the spectrum-side analogue, and they come out the same way:
the *sliding law holds* (a linear functional of the spectrum decomposes along a
concatenation with the seam as the only extra term), while *reconstruction fails
because the seam itself is factorization-dependent*. That is R3's sufficiency
obstruction in LC's shape, not a new phenomenon. -/

/-- **The spectrum pairing.** Pair a sequence's 2-gram spectrum against a test function
    `φ : α × α → ℤ`, i.e. `∑_{e ∈ edges s} φ e`.

    This is the bilinear form the readout's query/key product instantiates: a *linear
    functional of the bag*. Everything the readout can see of a spectrum is one of
    these, which is why the results below bound what any readout can recover. -/
def pairing (s : List α) (φ : α × α → ℤ) : ℤ :=
  ((edges s).map φ).sum

/-- **THE SLIDING LAW (it holds).**

    Property enforced: the spectrum form of `splitQuatPairingAux_mul_slide`
    (`foundations/Chu.lean:380`, `β(u*v, w) = β(v, S(u)*w)`) — a factor can be carried
    across the pairing, and a concatenation contributes its two fragments plus exactly
    one extra term, the seam. Obtained by pushing `edges_append` through linearity of
    `∑`, which is why it holds at *every* order rather than only CD ≤ 2: the spectrum
    pairing has no associator to break it.

    Read as a reconstruction handle: the seam is the *only* part of a concatenation a
    linear functional cannot already see inside the fragments. That is simultaneously
    the good news (the seam is a well-defined linear-functional object) and the bad news
    (`seam_factorization_dependent` below). -/
theorem pairing_append (s t : List α) (φ : α × α → ℤ) :
    pairing (s ++ t) φ = pairing s φ + ((seam s t).map φ).sum + pairing t φ := by
  unfold pairing
  rw [edges_append, List.map_append, List.map_append, List.sum_append, List.sum_append]

/-- **THE OBSTRUCTION: the seam is factorization-dependent.**

    The same sequence, cut in two different places, has two different seams — for
    `[1,2,3]` the cut `([1,2],[3])` gives seam `(2,3)` and the cut `([1],[2,3])` gives
    seam `(1,2)`. So the seam is a function of the *cut*, not of the sequence, and hence
    certainly not of the bag (`edgeBag` of the two concatenations is equal, since the
    concatenations are equal).

    Property enforced: this is the spectrum mirror of LC's documented obstruction that
    *"no linear map on a non-commutative algebra can perform factorization-dependent
    shuffles"* (`foundations/Chu.lean:451-470`) — and of `antipode_mul_false`
    (`foundations/Algebra.lean:720`), which is what makes the CD 3 sliding law fail.
    In LC the shuffle depends on the factorization of the input rather than its
    product; here the seam depends on the cut rather than the sequence. Same defect,
    and it is exactly what blocks R3's sufficiency: `pairing_append` says the seam is
    the entire order content of a concatenation, and this theorem says the seam is not
    recoverable from the concatenation's bag.

    Witness is minimal (size 3), found by reading `seam`'s clauses rather than searching. -/
theorem seam_factorization_dependent :
    ∃ (s t s' t' : List ℕ), s ++ t = s' ++ t' ∧ seam s t ≠ seam s' t' :=
  ⟨[1, 2], [3], [1], [2, 3], rfl, by decide⟩

/-- **R3's sufficiency obstruction, as an absence result.**

    There is **no** function of the bag that recovers the seam. Since the seam is the
    whole order content of a concatenation (`pairing_append`, `edges_append`), this
    sharpens `no_bag_only_reconstruction` (which ruled out recovery up to rotation and
    reversal) to the stronger statement that even the *local* order datum is not a
    function of the bag — no linear or nonlinear bag-only map can produce it.

    Property enforced: the absence is written down as a named result, following the
    corpus convention (`antipode_mul_false`, `draft_no_period5`, `free_not_quantized`,
    `real_projection_blind_to_supercompleteness`). Note what it does **not** say: it
    says nothing against the Eulerian-path route to R3 (lab note 066 §4), which supplies
    ordering information *beyond* the bag — just as LC's distributor replacement must be
    signed/braided rather than a bag-level adjoint. -/
theorem no_bag_only_seam_recovery :
    ¬ ∃ ψ : Multiset (ℕ × ℕ) → List (ℕ × ℕ), ∀ s t : List ℕ, ψ (edgeBag (s ++ t)) = seam s t := by
  rintro ⟨ψ, h⟩
  have key : seam [1, 2] [3] = seam [1] [2, 3] :=
    calc seam [1, 2] [3] = ψ (edgeBag ([1, 2] ++ [3])) := (h [1, 2] [3]).symm
      _ = ψ (edgeBag ([1] ++ [2, 3])) := by rfl
      _ = seam [1] [2, 3] := h [1] [2, 3]
  exact absurd key (by decide)


end SpectrumOrder