# Lab Note 060 — The Anatomy of a Hole: Zero Divisors, Horizons, and the Cone Theorem

**Date**: 2026-09-01
**Follows**: 059 (twist vs associator; skeleton senses), 058 (F1–F5; the fidelity
dial), 057 (strut quantization), 039 (the (5,3) self-correction)
**Trigger**: owner question — is a Hodge-conjecture-style statement relevant to
the topological hole our zero divisors make? The multiplicity of zero-divisor
forms "has some similarity" to the multiplicity of HC obstructions.
**Status**: NOTE + PROVEN — the cone theorem landed in
`LaserCortex/foundations/Algebra.lean` this pass; the HC verdict is argument in
§4 and stands on definitions.
**Protocol**: Timespace Decomposition v0.3 — (4,4) Signature Model

---

## 0. Abstract

Holes come in kinds, and the zero-divisor locus is not the kind the Hodge
conjecture speaks about: the (4,4) null cone is **contractible** — it shelters
no homology for cycles to span, so a "HC for our holes" is vacuous. But the
question forced the vague part of the program into a theorem: *the horizon is
exactly the null cone* (`isZeroDivisor_iff_octonion_norm_eq_zero` [P]), the
algebra's identity can never be a zero divisor
(`not_isZeroDivisor_split_one` [P]) — so the `IdentityZeroDivisor` paradox
lives on the logic tree, never in the composition algebra — and the
multiplicity the owner sensed resolves into a small taxonomy: **one cone per
quadratic form, only composable forms carve horizons**, plus two register
shifts (monopole, paradox). The shared shape with HC is the *realization
problem* ("which structurally-defined classes admit geometric representatives?")
— a schema we solved in its finite case (F2) and which is open exactly because
the continuum case trades decidability for periods.

## 1. What our zero-divisor record actually says

| form of "hole" | object | failure mode | source |
| --- | --- | --- | --- |
| **Null cone** $Q_{44}=0$, $e_i+e_j$ channels ($i\le3$, $j\ge4$) | ground algebra | the inverse $x^{-1}=\bar x/Q(x)$ blows up | `lab_protocol.md`; now **[P]** (§2) |
| **ZD monopole** | composition of two `TamariBP` at equal `cdStep` | composition infeasible; "the singularities are the zero divisors… the homotopy moves away by going up the CD tower" | `ZD_CONVEX_OPTIMIZATION.md`, `Composition.lean` |
| **Identity zero divisor** | logic-tree markers | `(2:ℤ)=0 → False` — logical collapse | `ParadoxAxioms.lean`, `Hopf.lean`; **cannot be instantiated by the algebra** [P] |
| **Shadow null** $(5,3)$ | antipode-pairing form | form is *not multiplicative*: shadow-null ≠ annihilator | `fiveThreeNorm_non_composition` **[P]**; 039's correction |
| **Homological hole** | (none here) | — | the cone is contractible; §3 |

## 2. What was proven this pass

New section "Norm composition, conjugation, and the zero-divisor cone" in
`foundations/Algebra.lean` (build green; axioms `propext, Classical.choice,
Quot.sound` — **no new `native_decide` footprint**; the whole argument is
equational):

- `split_conj` + adjugate identities `split_oct_mul_split_conj`,
  `split_conj_split_oct_mul` **[P]**: `x·x̄ = x̄·x = Q₄₄(x)·1`.
- `conj_mul_assoc_left` / `mul_assoc_conj_right` **[P]**:
  `(x̄·x)·y = x̄·(x·y)` and the right variant — **the exact step where
  alternativity earns its keep** (documented in `associator_conj_left/right`
  **[P]**: `[x̄,x,y] = 0`, `[y,x,x̄] = 0`).
- `isZeroDivisor` (nonzero `x` annihilating a nonzero `y` from either side)
  and the **cone theorem** `isZeroDivisor_iff_octonion_norm_eq_zero` **[P]**:
  for nonzero `x`, being a zero divisor ↔ `Q₄₄(x) = 0`.
- `not_isZeroDivisor_split_one` **[P]**: the unit is never a zero divisor.
- `example : isZeroDivisor (e₀ + e₄)` **[V]** by `decide` — the
  `lab_protocol` interface channel is an inhabitant.
- **Meta-finding**: norm compositionality `octonion_norm_mul` (`Q(xy) =
  Q(x)Q(y)`) was **already proven** in this file's Cayley–Dickson section —
  found when the compiler rejected my re-added copy ("has already been
  declared") after my own `grep | head` had truncated the original out of
  view. Sharper: **the cone theorem does not even need the Hurwitz law** —
  the adjugate + alternativity-cancellation route suffices. The horizon is
  carved by the *adjugate*, not by full compositionality; compositionality
  then adds the two-sidedness (over a field: non-null ⇒ unit).

## 3. Reading it in English

- **The horizon is the null cone.** "Quench-collapse threshold" now names a
  set with a theorem attached: the directions in which re-association debt
  cannot be repaid are exactly the directions in which no inverse exists.
  Crossing a null channel means multiplying into a kernel — information is
  annihilated, not rotated. That is the honest algebraic content of the
  black-hole analogy: **a one-way surface for the multiplication map**, not
  a region hiding a tunnel.
- **The unit can never cross.** `Q(1) = 1` — so the paradox structure
  `IdentityZeroDivisor` is *nowhere realized* in the algebra. Two objects in
  this repo share the name "identity zero divisor"; the separation is itself
  the lesson: paraconsistency is a property of marker/claim **trees**, and
  the ground algebra stays classical. (Compare 059 §0: "skeleton" needed the
  same treatment.)
- **Multiplicity deflated, then made precise.** "Zero divisors come in many
  forms" resolves to: (i) a cone per quadratic form, but only the composing
  form's cone is the horizon (4,4) [P vs P]; (ii) register shifts (algebra /
  composition-feasibility / tree-paradox). Nothing infinite-dimensional is
  hiding in the multiplicity.

## 4. The Hodge verdict

**Relevant? No — and the reason is structural, not of degree.**

- HC is a statement about **homological holes of complex projective
  varieties**: every rational class of type (p,p) should be spanned by an
  algebraic cycle. Our cone, as a subset of ℝ⁸, is contractible: its
  (co)homology is that of a point. There is no class to represent, no
  positivity to violate, no torsion to hide. A Hodge conjecture restricted
  to our holes is vacuously true and vacuously uninteresting.
- The black-hole comparison is a **hiding** theorem, not a spanning one:
  topological censorship (Friedman–Schleich–Witt; Galloway–Woolgar) says
  nontrivial topology behind horizons is unobservable from infinity. Our
  algebraic analogue: null data is *uninvertible from inside the sheet* —
  `ZD_CONVEX_OPTIMIZATION`'s "go up the CD tower" is the change-of-sheet
  clause. Censorship bounds what you can probe; HC bounds what you can
  represent. Both are no-go theorems — that is the whole of the kinship at
  theorem level.
- **The genuine shared schema** — and the most useful thing this question
  produced: HC is a *realization problem* ("class defined by linear-analytic
  conditions ⇒ geometric representative?"). Our mathematics poses the same
  schema at its own scale and **solves it**: F2's `rotBridge` says every
  skeleton sign-transport class (a cocycle-defined defect) is realized by an
  actual bracketing, and `pentagonLoop` says the face conditions close. The
  reason ours is decidable and HC is not is exactly the reason the analogy
  must not be pushed: the finite loop is replaced by cohomology with
  periods, moduli, and transcendence. **Our solved toy is a microscope on
  the gap, not a bridge across it** — which is precisely the health-check
  property the owner asked for: nothing we prove smells like a route to HC.
- Multiplicity-of-obstructions vs multiplicity-of-forms: both are taxonomies
  of failure, but of different maps — HC's obstructions (torsion
  Atiyah–Hirzebruch/Totaro; transcendence Noether–Lefschetz; positivity
  Voisin) are reasons the *cycle-class map* misses classes; ours are ways
  the *inverse map* fails to be defined. Taxonomic resemblance, no
  correspondence.

## 5. What is genuinely topological here (future work, [H])

The cone itself is trivial; the shadows it casts are not:

- **Ray space**: the projectivized null cone $\{Q=0\}\setminus\{0\}/\mathbb
  R^+ \cong (S^3\times S^3)/\{\pm1\}$, hence $\pi_1 = \mathbb Z/2$
  [H — verify; logged to `research_questions.md`]. If true, the **only**
  topological hole our zero divisors make is a ℤ/2 loop-space — and the
  natural conjecture is that our sign transport (`signCocycle` /
  `Coherence`) is its holonomy: φ stops being bookkeeping and becomes the
  deck-transformation character of the double cover.
- **Unit shells** $\{Q = \pm1\}$: two components (signature (4,4) — the
  lightcone census's timelike/spacelike dichotomy at algebra level);
  automorphism group $G_2$ (split) retracts to SO(4), also π₁ = ℤ/2
  [verify]. The sign of `octonion_norm` classifies sheets; a Z/2 local
  system appears again.
- If §5 lands, the F-series acquires a geometric spine: **the strut's ℤ/2
  is the fundamental group of the ray space of the horizon.**

## 6. Pointers into the F-series

- **F3 (dial theorems)**: the dial prices multiplicative channels (F1
  remark); the cone theorem adds: the wavelet limit and full-chirplet
  straddling are statements *across* a non-invertible locus — intermediate
  fibres `c ∈ {1,2,3}` must be formulated so no division by a null
  direction is ever needed. Formalize or drop in F3.
- **F4 (particles)**: a "compact associator charge" must be measured
  against the composable form Q₄₄ — shadow-nulls ((5,3)) are disqualified
  as horizon data by [P]. Conservation claims get their stage: the ray
  space's π₁ is the natural home of a "charge = winding" reading, if §5
  verifies.
- **Ledger item 8 (anyon/F-move)**: 059's twist-vs-F separation + this
  note's §5 = concrete to-do: realize φ as the holonomy character before
  claiming a fusion model; the fusion model must not co-claim the strip's
  θ.

## 7. Process findings (agent hygiene — cheap, reusable)

1. **Grep with full output before declaring anything.** "Missing"
   `octonion_norm_mul` had been in the file the whole time; a truncated
   `grep | head` hid it and the compiler's duplicate-declaration error found
   it. The moralized version: the ledger discipline applies to *files*, not
   only claims.
2. **Transparency note (this toolchain)**: `simp` does not unfold the
   `instOfNat/Zero.zero → split_zero` chain at numeral-projection sites —
   goals like `(0 : SplitOctonion).e0 = 0` stay stuck; prove with explicit
   `split_zero` in the simp set or by `rfl`.
3. **Equality orientation**: an equation *defining* a difference
   (`associator_tensor ... = 0`) does not rewrite bracketings via `▸`;
   carry the explicit cancellation equality (`conj_mul_assoc_left`) as the
   workhorse and the associator form as documentation. That separation is
   itself a small echo of the primer's honesty policy: the documentation
   lemma and the load-bearing lemma are different claims.

## 8. Status of claims

- §2: all **[P]** (build green; no new decide-axioms).
- §3: reading; stands on §2.
- §4: **argument** — final on current evidence; revisit only if a complex
  variety ever appears in this program's objects (none does; see 059 §2).
- §5: **[H]**, logged to `research_questions.md`.
- §6: pointers, not claims.

---

## References

- `LaserCortex/foundations/Algebra.lean` — new cone section; `octonion_norm_mul`
  (CD section); `fiveThreeNorm_non_composition`
- `docs/lab_protocol.md` (null cone = interface); `docs/ZD_CONVEX_OPTIMIZATION.md`
  (monopole, change-of-sheet); `LaserCortex/Composition.lean`;
  `LaserCortex/ParadoxAxioms.lean`, `LaserCortex/Hopf.lean`
- Notes 039 (Hodge-star correction, (5,3)), 057 (quantization), 058 (F-series),
  059 (senses of skeleton; twist vs associator)
- [std] Hurwitz composition algebras; Zaabek, classification of 8-dimensional
  composition algebras [C — pin]; Friedman–Schleich–Witt, *Topological
  Censorship* (PRL 1993); Galloway–Woolgar refinements; Atiyah–Hirzebruch /
  Totaro / Voisin on integral-HC obstructions (as in 059 §3)
