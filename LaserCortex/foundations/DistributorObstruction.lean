import LaserCortex.foundations.Chu

/-!
# DistributorObstruction — the CD3 obstruction to the duoidal distributor

Lab note 066 (`docs/lab_notes/066_missing_adjoint_cd3_distributor_obstruction.md`)
§3, formalized: promotes that note's `[V]` computational results to `[P]`.

## The mathematical property being enforced

`cd2_distributor` (`foundations/Chu.lean:490`) exists because at CD ≤ 2 the
**sliding law**

```
β(u * v, w) = β(v, S(u) * w)            -- `splitQuatPairingAux_mul_slide`
```

holds. That law is the algebra's statement that *a left factor can be carried
across the bilinear pairing by conjugating with the antipode* `S`. It is exactly
what makes `S` an adjoint for the pairing, and therefore exactly what makes the
duoidal distributor — the interchange `ChuTensor ⊗ ChuTensor → ChuSeq ⊗ ChuSeq` —
possible at all: the distributor's only surviving content is an adjoint pair
(`Distributor.pair_preserved`, `Chu.lean:471`), the normalization fields having
been omitted because the shuffle is factorization-dependent and no linear map can
perform it (`Chu.lean:451-470`).

At CD 3 every ingredient is present **except** the law above:

* the pairing is nondegenerate — `octonionPairing_nondegenerate` (`Chu.lean:179`)
* the antipode is self-adjoint — `octonionPairing_antipode_symm` (`Chu.lean:175`)
* the antipode is involutive — `antipode_involutive` (`Algebra.lean:714`)
* **the antipode is NOT contravariant** — `antipode_mul_false` (`Algebra.lean:720`)

The theorems below certify what follows, and the finding that matters:

**`slideDefect_orthogonal_to_associator`** — the sliding defect and the
associator are *disjoint*: `assoc(u,v,w) ≠ 0 ⟹ slideDefect = 0`, and
`slideDefect ≠ 0 ⟹ assoc(u,v,w) = 0`. So the CD 3 distributor obstruction is
**not** an associativity defect and cannot be located by chasing `assocDefect` /
`frictionDensity` / `strut_weight` (`Friction.lean:30, :43`) — the natural and
wrong first move. The two defects partition the basis triples.

## What this buys

`cd2_distributor` cannot be extended to CD 3 by the antipode route, and the
obstruction is orthogonal to the one LC's cost landscape is built on, so the
replacement must be a **signed/braided** adjoint (cf. `signCocycle`,
`Algebra.lean:247`; `basisWord_eq_or_neg`, `Coherence.lean:300`). As a
`Distributor` question: *find a `Distributor` at CD 3 whose adjoint is not the
antipode* — or prove none exists, in which case the deliverable is a named absence
theorem following the corpus convention (`antipode_mul_false`, `draft_no_period5`,
`free_not_quantized`, `real_projection_blind_to_supercompleteness`).

## Scope

All enumeration results are over the **512 basis triples** (`native_decide` on
concrete data, in the `headMods_pairwise_coprime` idiom, `GramDictionary.lean:277`).
They are complete for the basis and are *not* claims about arbitrary elements;
`slideDefect_orthogonal_to_associator` in particular should be re-checked at CD 4
before being believed in general (lab note 066 §6 unit 2).

**Axiom status.** All theorems here are discharged by `native_decide` and therefore
carry the standard compiler-trust private axiom
(`<name>._native.native_decide.ax_1_1`), which is the same status as the three
real-model layout certificates in `GramDictionary.lean:258-260`. Where the proof
also touches `List.all`/`filter` it picks up `propext`/`Classical.choice`/
`Quot.sound` on top. No `sorryAx` anywhere. The `[V]` results this module
promotes to `[P]` are therefore certified *given* the compiler, which is stated
here rather than left for a reader to discover from `#print axioms`.
-/

namespace DistributorObstruction

/-- A basis triple, as Lean's right-nested product. -/
abbrev Triple := SplitOctonion × SplitOctonion × SplitOctonion

/-- **Sliding defect.** `β(u*v, w) − β(v, S(u)*w)`.

    Zero exactly when the sliding law holds at `(u,v,w)` — i.e. when the antipode
    `S` carries `u` across the pairing, which is the property `cd2_distributor`
    needs. Nonzero = the antipode is *not* an adjoint at that triple, so the
    distributor's `pair_preserved` field cannot be discharged there. -/
def slideDefect (u v w : SplitOctonion) : ℤ :=
  Chu.octonionPairingAux (split_oct_mul u v) w
    - Chu.octonionPairingAux v (split_oct_mul (antipode u) w)

/-- **Associator.** `(u*v)*w − u*(v*w)`, the defect whose magnitude `assocDefect`
    (`Friction.lean:30`) drives the whole CD cost landscape. Zero = the triple
    associates. The point of this module is that it is *orthogonal* to
    `slideDefect`. -/
def associator (u v w : SplitOctonion) : SplitOctonion :=
  split_sub (split_oct_mul (split_oct_mul u v) w) (split_oct_mul u (split_oct_mul v w))

/-- The eight basis vectors, in index order `e0 … e7`. -/
def basis : List SplitOctonion :=
  [e0_vec, e1_vec, e2_vec, e3_vec, e4_vec, e5_vec, e6_vec, e7_vec]

/-- All 512 basis triples, in index order. -/
def triples : List Triple :=
  basis.foldr (fun u acc =>
    acc.reverse ++ basis.foldr (fun v acc2 =>
      acc2 ++ basis.map (fun w => (u, v, w))) []) []

/-- Index of a basis vector, for reporting which triples fail. -/
def basisIdx (x : SplitOctonion) : ℕ :=
  basis.findIdx (fun b => decide (b = x))

/-- Does `(u,v,w)` fail to associate? -/
def assocNontrivial : Triple → Bool
  | (u, v, w) => decide (associator u v w ≠ split_zero)

/-- Does the sliding law fail at this triple? -/
def slideFails : Triple → Bool
  | (u, v, w) => decide (slideDefect u v w ≠ 0)

/-- Is `(a,b,c)` a permutation of `(x,y,z)`? -/
def isPerm3 (a b c x y z : ℕ) : Bool :=
  (a == x && b == y && c == z) || (a == x && b == z && c == y) ||
  (a == y && b == x && c == z) || (a == y && b == z && c == x) ||
  (a == z && b == x && c == y) || (a == z && b == y && c == x)

/-- **The three Fano lines.** Is this triple supported on `{e1,e4,e5}`,
    `{e2,e4,e6}` or `{e3,e4,e7}`?

    Property: these are the three octonion multiplication lines that cross the
    (4,4) sector boundary — each contains the split axis `e4`, one associative
    axis `e1,e2,e3`, and its product partner `e5,e6,e7` (`e_i * e_4 = ± e_{i+4}`). -/
def onFanoLine : Triple → Bool
  | (u, v, w) =>
    let i := basisIdx u; let j := basisIdx v; let k := basisIdx w
    isPerm3 i j k 1 4 5 || isPerm3 i j k 2 4 6 || isPerm3 i j k 3 4 7

/-! ## 1. The CD 2 result (positive control) -/

/-- **The sliding law holds throughout the associative sector.**

    Property enforced: `splitQuatPairingAux_mul_slide` (`Chu.lean:380`) — the
    antipode *is* an adjoint across the pairing when the algebra associates,
    which is the entire reason `cd2_distributor` goes through. Restricting to
    `e0..e3` (64 triples) is the CD 2 case living inside the CD 3 algebra; zero
    failures here confirms that the CD 3 failure is algebraic and not an artifact
    of the statement. -/
theorem slide_holds_on_associative_sector :
    ((basis.take 4).foldr (fun u acc =>
      acc ++ (basis.take 4).foldr (fun v acc2 =>
        acc2 ++ (basis.take 4).map (fun w => (u, v, w))) []) []).all
          (fun t => !slideFails t) = true := by
  native_decide

/-! ## 2. The CD 3 failure: witness, count, and exact locus -/

/-- **The sliding law FAILS at CD 3** — explicit witness.

    Property enforced: at CD 3 the antipode is not contravariant
    (`antipode_mul_false`, `Algebra.lean:720`), and this is where that failure
    lands on the distributor. With `u = e1`, `v = e4`, `w = e5`:
    `β(e1*e4, e5) = −1` while `β(e4, S(e1)*e5) = +1`, so the defect is `−2`.
    Consequently `cd2_distributor`'s proof cannot be replayed at CD 3 — its
    `pair_preserved` obligation is **false** here, not merely unproved.
    Witness matches lab note 066 §3.1 and the Python harness
    (`infra/tests/test_cayley_dickson_ladder.py::check_distributor_slide`). -/
theorem slide_fails_at_cd3_witness : slideDefect e1_vec e4_vec e5_vec = -2 := by
  native_decide

/-- **Exactly 18 of the 512 basis triples fail.**

    Property enforced: the CD 3 distributor obstruction is *finite and
    enumerable* — not generic non-associativity, not an open-ended failure.
    18 = 3 lines × 6 orderings. -/
theorem slide_failure_count : (triples.filter slideFails).length = 18 := by
  native_decide

/-- **Every failure lies on a Fano line** (soundness of the locus).

    Property enforced: the obstruction is supported only on the three lines
    crossing the (4,4) sector boundary — it is not spread over the non-associative
    triples generally. -/
theorem slide_failure_locus_sound :
    (triples.filter slideFails).all onFanoLine = true := by
  native_decide

/-- **Every triple on a Fano line fails** (completeness of the locus).

    Property enforced: the converse of `slide_failure_locus_sound`. Together the
    two pin the failure set *exactly* to the three Fano lines, with no slack in
    either direction. -/
theorem slide_failure_locus_complete :
    (triples.filter onFanoLine).all slideFails = true := by
  native_decide

/-- The locus has 18 elements (3 lines × 6 orderings), matching the failure count
    — so the two sets are equal, not merely mutually inclusive. -/
theorem slide_failure_locus_count : (triples.filter onFanoLine).length = 18 := by
  native_decide

/-- **Every failure forms a product.**

    Property enforced: `w = ±u*v` at all 18 failures, so the sliding law fails
    precisely where the algebra *closes*. This is the check that decided the
    failure is load-bearing for the distributor rather than an artifact of probing
    basis elements (lab note 066 §3.1). -/
theorem slide_failures_are_product_triples :
    (triples.filter slideFails).all (fun (u, v, w) =>
      decide (split_oct_mul u v = w ∨ split_oct_mul u v = -w)) = true := by
  native_decide

/-! ## 3. The finding: the obstruction is orthogonal to the associator -/

/-- **Where the algebra fails to associate, the sliding law HOLDS.**

    Property enforced: `assoc(u,v,w) ≠ 0 ⟹ slideDefect = 0` — all 168
    non-associating basis triples satisfy the sliding law. So the distributor
    obstruction is **not** a shadow of the associator, and `assocDefect` /
    `frictionDensity` / `strut_weight` cannot locate it. -/
theorem assoc_nontrivial_implies_slide_holds :
    (triples.filter assocNontrivial).all (fun t => !slideFails t) = true := by
  native_decide

/-- **Where the sliding law fails, the algebra ASSOCIATES.**

    Property enforced: `slideDefect ≠ 0 ⟹ assoc(u,v,w) = 0` — the converse of the
    previous theorem. Together the two make the defects *disjoint*: they partition
    the triples rather than overlapping. This is lab note 066 §3.3, the result the
    note exists to report. -/
theorem slide_fails_implies_assoc_zero :
    (triples.filter slideFails).all (fun t => !assocNontrivial t) = true := by
  native_decide

/-- **The disjointness, as one statement.**

    Property enforced: the CD 3 distributor obstruction and the associativity
    defect are **orthogonal** — no basis triple fails both. Hence the distributor
    needs a *second, independent* invariant of the CD tower; and if this survives
    at CD 4 it is a structural fact about the tower rather than a CD 3 coincidence
    (lab note 066 §6 unit 2). Note the count below: non-associativity is the
    *common* case (168) while distributor failure is rare (18), and neither
    implies the other. -/
theorem slideDefect_orthogonal_to_associator :
    triples.all (fun t => !(assocNontrivial t && slideFails t)) = true := by
  native_decide

/-! ## 4. Counts, for the record -/

/-- 168 of the 512 basis triples fail to associate. -/
theorem assoc_nontrivial_count : (triples.filter assocNontrivial).length = 168 := by
  native_decide

/-- The two classes are disjoint, so their sizes add: 168 + 18 = 186 of the 512
    triples are defective in one way or the other; the remaining 326 both associate
    and slide. -/
theorem partition_counts :
    (triples.filter assocNontrivial).length + (triples.filter slideFails).length = 186 := by
  native_decide

end DistributorObstruction
