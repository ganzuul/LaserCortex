import Mathlib
import LaserCortex.foundations.Algebra
import LaserCortex.Stencil
import LaserCortex.Coherence

/-!
# Physics API v0.1 — the façade by which solvers consume the model

Documented in lab note 061. The design principle is the honesty policy made
operational: **every named endpoint here re-exports a [P] theorem**; nothing
hypothesis-level gets a name — open obligations live in docstrings, and a
comment only graduates to a theorem when a proof exists. The F-series
(058 §5) discharges those obligations.

Four sectors:

* **Ledger** — the multiplicative books (`octonion_norm` as monoid
  homomorphism into `(ℤ, ·)`), commits (zero-charge steps), their
  indivisibility, the lattice gap, and undo (the adjugate).
* **Fields** — the only admissible B is stream-function-built, with the F1
  closure certificate.
* **Bookkeeping** — bracketings as evaluation schedules: serializability,
  the per-edge sign as local cocycle, the closed pentagon face.
* **Settings** — `FidelitySettings`: the levers named; ranges and
  monotonicity are F3's job, so they are comments here, not constraints.
-/

namespace PhysicsAPI

/-! ## Ledger -/

/-- The books: every step's event-content is one integer, composed
multiplicatively along a product of steps. -/
abbrev ledger : SplitOctonion → ℤ := octonion_norm

/-- The ledger is a monoid homomorphism `(SplitOctonion, ·) → (ℤ, ·)` — this
is what makes the books additive across a computed trajectory. -/
theorem ledger_mul (x y : SplitOctonion) :
    ledger (split_oct_mul x y) = ledger x * ledger y := octonion_norm_mul x y

/-- A **commit**: a nonzero step with zero ledger charge. By the cone theorem
this is exactly a zero divisor — the horizon *is* the null cone. -/
def isCommit (x : SplitOctonion) : Prop := x ≠ 0 ∧ ledger x = 0

/-- A **smooth step**: nonzero ledger charge; abortable, undoable over the
rationals, freely submissible as work (but see `commit_gap`: never close to
a commit on the lattice). -/
def isSmooth (x : SplitOctonion) : Prop := ledger x ≠ 0

theorem isCommit_iff_isZeroDivisor (x : SplitOctonion) :
    isCommit x ↔ isZeroDivisor x := by
  constructor
  · rintro ⟨hx, hq⟩
    exact (isZeroDivisor_iff_octonion_norm_eq_zero hx).mpr hq
  · intro hz
    exact ⟨hz.1, (isZeroDivisor_iff_octonion_norm_eq_zero hz.1).mp hz⟩

/-- **Indivisibility of commits** (the primitive interface): a commit never
factors through smooth steps. If `y·z` carries zero charge then `y` or `z`
does. Reconnection is atomic in the multiplicative accounting: it cannot be
bookkept away by subdividing. -/
theorem commit_indivisible {y z : SplitOctonion}
    (h : ledger (split_oct_mul y z) = 0) :
    ledger y = 0 ∨ ledger z = 0 := norm_eq_zero_of_mul_eq_zero h

/-- **The gap**: on the lattice, a smooth step's charge has absolute value
at least one. Invertible schemes are not merely unable to *reach* a commit;
they are a uniform full atom away from the horizon. (Over `ℝ` the gap
closes — it is integrality that buys it. The API therefore keeps field
channels continuous but the defect ledger integer-valued: 061 §4.) -/
theorem commit_gap {x : SplitOctonion} (h : isSmooth x) :
    1 ≤ (ledger x).natAbs :=
  Nat.one_le_iff_ne_zero.mpr (Int.natAbs_ne_zero.mpr h)

/-- **Undo for smooth steps** (adjugate identity): `x·x̄ = (ledger x)·e₀`,
so over the rationals the rollback is `x̄ / ledger x`. For a commit the
adjugate *annihilates* instead — commit has no rollback, only the annihilator
(`Algebra.null_annihilated_by_conj`). -/
theorem undo_smooth (x : SplitOctonion) :
    split_oct_mul x (split_conj x)
      = ⟨ledger x, 0, 0, 0, 0, 0, 0, 0⟩ := split_oct_mul_split_conj x

/-- Commit content is invariant under composing with smooth factors:
pre/post-multiplication by an invertible step neither creates nor destroys
an event. The horizon is frame-invariant. -/
theorem commit_invariant (y z : SplitOctonion) (hy : isSmooth y) :
    ledger (split_oct_mul y z) = 0 ↔ ledger z = 0 := norm_mul_eq_zero_iff hy

/-- **Amplitude is free**: every integer is some step's charge (Lagrange
four-squares on the time-like block). The amplitude axis of the dial always
has lattice representatives. The defect axis is quantized elsewhere:
`Coherence` + 057's `{0, strut}` spectrum — *amplitude free, defect
quantized* is the pair `amplitude_free` / `strut` standing together. -/
theorem amplitude_free (c : ℤ) : ∃ x, ledger x = c := exists_octonion_norm_eq c

/-- The unit of defect: `strut = 4` (`Algebra.strut_weight_eq_four` [P]); the
basis associator spectrum is `{0, strut}` (057 [P]). -/
abbrev strut : ℕ := strut_weight

/-! ## Admissible fields -/

/-- The **only** constructor of B-fields in the API: a stream function in, a
field out. A solver that hand-builds flux components outside `makeField` is
outside the certificate. -/
def makeField {Nx Ny : ℕ} {R : Type*} [AddCommGroup R]
    (ψ : Stencil.GridF Nx Ny R) : Stencil.VecF Nx Ny R := Stencil.curl ψ

/-- **Closure certificate** (F1): every API-built field is discretely
divergence-free by theorem — the stencil composition contributes zero
error; only the field components carry rounding. A number you certify, not
a number you measure. -/
theorem divFree {Nx Ny : ℕ} {R : Type*} [AddCommGroup R]
    (ψ : Stencil.GridF Nx Ny R) : Stencil.div (makeField ψ) = 0 :=
  Stencil.div_curl ψ

/-! ## Bookkeeping — bracketings are evaluation schedules -/

/-- **Serializability**: any two bracketings (evaluation schedules) of the
same signed-basis word agree up to sign — all n, skeleton domain
(`Coherence.basisWord_eq_or_neg`). -/
theorem rebracket_agrees {t u : Coherence.BTree}
    (h : Coherence.leaves t = Coherence.leaves u) :
    Coherence.eval t = Coherence.eval u ∨
      Coherence.eval t = split_neg (Coherence.eval u) :=
  Coherence.basisWord_eq_or_neg h

/-- **The per-edge sign is the local cocycle**: for skeleton blocks, the
rotation's value ratio equals `signCocycle` of the block triple — φ *is* the
transport (the skeleton F-symbol; ledger item 8's first concrete instance). -/
theorem edge_sign_is_cocycle {x y z : SplitOctonion}
    (hx : Coherence.basisLike x) (hy : Coherence.basisLike y)
    (hz : Coherence.basisLike z) :
    (signCocycle x y z = 1 ∧
        split_oct_mul (split_oct_mul x y) z = split_oct_mul x (split_oct_mul y z)) ∨
    (signCocycle x y z = -1 ∧
        split_oct_mul (split_oct_mul x y) z =
          split_neg (split_oct_mul x (split_oct_mul y z))) :=
  Coherence.rotBridge hx hy hz

/-- **The face closes**: the five edge signs around a K₄ pentagon schedule
multiply to 1 — the re-bracketing ledger is flat (independent value-level
re-check of `pentagon_cocycle_basis`). -/
theorem face_closes (a b c d : Fin 8) :
    let A := basisVec a
    let B := basisVec b
    let C := basisVec c
    let D := basisVec d
    signCocycle A B C * signCocycle A (split_oct_mul B C) D
      * signCocycle B C D * signCocycle A B (split_oct_mul C D)
      * signCocycle (split_oct_mul A B) C D = 1 :=
  Coherence.pentagonLoop a b c d

/-! ## Settings — levers named; obligations open (F3) -/

/-- The fidelity ladder's control surface (061 §3). v0.1 deliberately states
**no constraints**: constraints are proved, not declared. Graduation list
(F3's job, 058 §5):

* `amplitude` (the Rees fibre `c`): intended `0 ≤ amplitude ≤ strut`;
  obligations: monotonicity of committed cost in `c`, exact-discount
  identity at the endpoints `{0, strut}`, and a real `chirpRate`
  (057 §3.2). What `c` *buys* remains [H] — `amplitude_free` [P] only says
  representatives exist at every charge.
* `discount` (trust `λ ≤ 1`): the `looseCost` mould is [P] **for tree
  costs** (`looseCost_discount_exact`, `linear_in_trust`); wiring that
  exactness to solver bookkeeping of MHD events is open.
* **commit count is not a field**: a solver's commits are determined by its
  step's ledger charge, not by settings — `commit_indivisible` and
  `commit_gap` make that a theorem, which is exactly why the dial is a
  *commit policy* and not a resolution slider. -/
structure FidelitySettings where
  amplitude : ℤ
  discount : ℚ

end PhysicsAPI
