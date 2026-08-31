# Lab Note 057 — Strut Quantization: the 512-Triple Basis Associator Spectrum

**Date**: 2026-08-31
**Follows**: 056 (Rees construction, `strut_weight = 4`, hypotheses 1–3 for weights 1,2,3)
**Status**: NOTE — hypothesis 2 of 056 §4 is **refuted** [P]; hypothesis 1 (intermediate
Rees fibres of the operator) is the sole live reading; hypothesis 3 (sedenions) untouched.
**Protocol**: Timespace Decomposition v0.3 — (4,4) Signature Model

---

## 0. Abstract

The test 056 §4 prescribed — enumerate `|[eᵢ,eⱼ,eₖ]|` for all 8³ = 512 ordered basis
triples of the (4,4) split octonions — is now done *in Lean*, not by script. The
histogram has exactly two bars: **0 ↦ 344** and **4 ↦ 168**. No basis triple realizes
an associator magnitude of 1, 2, or 3. The strut is *quantized on the basis*: a basis
associator is either absent or full-strength. "What would a half-strut mean?" therefore
has no answer inside the basis; its only address is the Rees fibre coordinate `c` of
the chirplet *operator* (`chirpletOperator c l = rightSpine l * c`), i.e. hypothesis 1
of 056.

## 1. What was proven

All in `LaserCortex/foundations/Algebra.lean`, section "Associator spectrum on the
basis" (patterns: `strut_weight_eq_four`, `pentagon_defect_bound`; `native_decide`
consistent with `pentagon_cocycle_basis`):

| Declaration | Content | Tag |
| --- | --- | --- |
| `assocBasis i j k` | the associator on the basis triple `(eᵢ,eⱼ,eₖ)` | def |
| `assocNormHist n` | count of ordered triples with `\|Q44-norm\| = n` | def |
| `strut_quantized_on_basis` | histogram = {0 ↦ 344, 4 ↦ 168}; bars 1,2,3 empty | **[P]** |
| `assocBasis_norm_eq_zero_or_four` | pointwise: every triple's magnitude ∈ {0,4} | **[P]** |
| `assocBasis_nonzero_count` | exactly 168 triples have a nonzero associator | **[P]** |
| `assocBasis_nonzero_null_free` | nonzero ⟹ `compL1 = 2` and `\|Q44-norm\| = 4` | **[P]** |
| `assocBasis_sign_split` | signed Q44 norm: −4 on 96 triples, +4 on 72 | **[P]** |
| `assocBasis_vanishes_with_unit` | any index 0 ⟹ associator = 0 | **[P]** |

`compL1` (sum of absolute component values) was introduced because in signature (4,4)
the Q44 norm *can* vanish on nonzero elements (the null cone). The theorem
`assocBasis_nonzero_null_free` says this never happens for basis associators: every
nonzero one is exactly ±2 times a single basis vector. So |Q44-norm| is a faithful
magnitude on this spectrum — there is no degeneracy hiding intermediate struts.

## 2. Reading the numbers in English

* **168 = 28 × 6.** There are C(7,3) = 35 triples of distinct *imaginary* basis
  vectors; 7 are the associative Fano-plane lines of the (split) imaginary octonions
  and 28 are not. Each non-associative triple yields a nonzero associator in all six
  orderings (total antisymmetry, `associator_antisymm_left` [P]). 28 × 6 = 168. The
  split form (4,4) has the same *pattern* of vanishing as the classical division
  octonions — matching the published combinatorics (Lounesto; hep-th/9906065). What
  differs is where the ±2 lands: the space-like sector e₄…e₇ carries negative Q44,
  which is why 96 triples give norm −4 (the `strut_weight` case) while 72 give +4.
* **Sign sensitivity.** `strut_weight` is `(-octonion_norm ·).toNat`: it reads the
  magnitude only when the associator lands space-like (norm −4 → 4). On a time-like
  associator (norm +4) the same expression would read 0. The distinguished fibre
  (e₁,e₂,e₄) crosses the (4,4) boundary and lands space-like, so the definition is
  right *for the strut*; as a general magnitude it must be replaced by |·| or `compL1`.
* **Consequence for 056's hypotheses.** Hypothesis 2 (some basis triple gives 1, 2,
  or 3) is refuted. Hypothesis 1 (c = 1,2,3 as intermediate Rees fibres of the
  operator, i.e. running the chirplet at 25/50/75 % of the strut) survives and is now
  the *only* basis for a graded dial — its test is behavioural, not enumerative: does
  any observable (compression, the O(n³) macro-state bound, reconnection cost) vary
  with c at fixed tree? Hypothesis 3 (CD-4/sedenion magnitudes) is untouched; it
  needs a Sedenion type, which is still not in the build.

## 3. Downstream effects

1. **`docs/primer/11_open_problems.md`** — §11.1 items 1 and 2 were stale (both were
   proven Aug 30: `associator_e0_vanishes`, `pentagon_cocycle_basis`); §11.1 now lists
   all three items as [P] with references and §11.2 gained the closed rows.
2. **`HyperbolicChirplet.lean`** — its header gate ("Status: `[C]` until 11.1.1 … and
   11.1.2 …") has passed. The `chirpRate` stub (`:= 1`) is now the open item: per this
   note, a *basis* realization of c ∈ {1,2,3} is impossible, so `chirpRate` must be
   defined on trees (via `rightSpine`/subband data), not read off the algebra.
   Follow-up, not done here (needs its own derivation turn).
3. **Calibration toy dial** — the chirplet dial's honest range is the *operator*
   parameter c ∈ {0,1,2,3,4} with 1,2,3 flagged `[H]` (meaning-to-be-established),
   while the algebraic quantized values are {0,4}. See
   `docs/calibration_toy_geometry_options.md` for the open geometry decision.

## 4. Reproduction

The enumeration was first run as `#eval` against the prebuilt module (probe deleted
after porting); the artifact is the theorem block itself — `lake build
LaserCortex.foundations.Algebra` re-checks every count through
`native_decide`-generated proofs (axiom footprint as the existing precedents:
`propext`, `Quot.sound`, per-theorem `native_decide` ax).

---

## References

* `LaserCortex/foundations/Algebra.lean` — §"Associator spectrum on the basis"
* `docs/lab_notes/056_rees_strut_weight.md` §4–5 — the hypotheses this note settles
* `docs/primer/11_open_problems.md` — the ledger, now synced
* Lounesto, *Octonions and Triality*; hep-th/9906065 (associator on basis triples)
