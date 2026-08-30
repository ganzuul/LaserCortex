# Lab Note 056 — Rees Construction: Operators with Scalars and the Meaning of `strut_weight = 4`

**Date**: 2026-08-28
**Follows**: 055 (chirplet+subband), 054 (anchors), `foundations/Algebra.lean` (alternativity, `strut_weight_eq_four`)
**Status**: NOTE — Rees construction is new to this project; `strut_weight = 4` now has a geometric address, weights 1,2,3 are open for investigation.
**Protocol**: Timespace Decomposition v0.3 — (4,4) Signature Model

---

## 0. Abstract

An operator with a scalar attached, `T_c`, is not `c·T`. It is a *family* over the base that the scalar coordinates — a section of a line bundle over `Spec ℤ[c]`, the Rees construction / deformation to the normal cone in miniature. The scalar lives in the **base**, not the fibre.

For us the base is the CD tower (the `strut_weight` axis) and `c = chirpRate` is the fibre coordinate. The distinguished fibre `c = 4` is `strut_weight = |[e₁,e₂,e₄]|`. This note records what `strut_weight = 4` actually *means* and asks, for the first time, what `c = 1,2,3` would mean.

---

## 1. Rees construction in one paragraph

An operator `T : X → Y` with a scalar `c` attached, written `T_c`, is the `c`-fibre of a family

```
    𝒯 → 𝔸¹ = Spec ℤ[c]
      ↘
       c
```

Varying `c` moves in the base; at each `c` you have a different operator. This is the **Rees construction**: the associated graded of a filtered algebra, spread out over `c`. In this project:

* `c = 0` — fibre `C₀` is the **wavelet** (no chirp), detail = `rightSpine l` itself.
* `c = chirpScalar = 4` — fibre `C₄` is the **chirplet**, detail = `rightSpine l · φ(l)` with `|φ|=1`.

`HyperbolicChirplet.lean:chirpletOperator c l = rightSpine l * c` is exactly this: not post-multiplication, but the `c`-fibre. `strut_weight` is the *distinguished* fibre.

---

## 2. What `strut_weight = 4` actually means

**Lean fact [P]:** `strut_weight = (-octonion_norm (associator_tensor e₁ e₂ e₄)).toNat = 4` (`Algebra.lean:234`).

In the primer's anchors:

* **Right-hand rule = associator antisymmetry** [P] (`associator_antisymm_left`): re-association has a handedness.
* **Polarization = the associator is a sign** [C, pending 11.1.1]: `e₀` vanishes, so `[a,b,c]` lives in the 7-dim imaginary subspace, one signed direction.
* **`strut_weight = 4` = the fixed *magnitude* of that handedness.** It is the norm of the associator on the distinguished basis triple `(e₁,e₂,e₄)` — the triple that *crosses* the (4,4) boundary (`e₁,e₂` time-like, `e₄` space-like, `lab_protocol.md` §(4,4) Signature Model). In MHD language it is the *unit* of resistivity: the cost of one polarized interface flip.

So `strut_weight` is not a free parameter. It is the *unit* in which the chirp rate `c` is measured: `scaledChirpRate = φ · strut_weight`, and on `(e₁,e₂,e₄)` this is `±4` [P] (`HyperbolicChirplet.scaledChirpRate_e1_e2_e4`).

---

## 3. Timespace reading (per `lab_protocol.md` v0.3)

Per protocol §(4,4) Signature Model, the 8 dimensions split ++++----:

* `e₀…e₃` (+) — **Time** (associative sector, commutator acts, irreversibility)
* `e₄…e₇` (−) — **Space** (split sector, associator acts, differentiability)
* `eᵢ+eⱼ` (null) — **Interface** (zero-divisor channels, quench-collapse)

`strut_weight = 4` lives in the *interface* — it is the associator that straddles time and space (`e₁,e₂` time-like, `e₄` space-like). The Rees family `c ↦ C_c` is therefore a deformation *across* the null cone, with `c` the interface coordinate. `c=0` is the time-like fibre (no associator, frozen-in), `c=4` is the fully polarized interface.

---

## 4. Do weights 1, 2, 3 mean anything?

This is now a well-posed question because `c` has a geometric address.

**What the Lean currently says:**

* `associator_tensor a b c` is proven alternating and purely imaginary (`e₀=0` [P] `associator_e0_vanishes`), so after normalization it *is* a sign. The only *proven* magnitude is `4` on `(e₁,e₂,e₄)`.
* No basis triple has been shown to give `|[a,b,c]| = 1,2,3`. The associator norms seen so far are `0` or `4` (and `pentagon_defect` bound `≤10`).

**Three hypotheses for 1,2,3, each falsifiable:**

1. **Fractional chirps (sub-maximal fibres).** `c = 1,2,3` are the *intermediate* fibres between wavelet (`c=0`) and full chirplet (`c=4`). They are not realized as `|[eᵢ,eⱼ,eₖ]|` for any basis triple, but they *are* realized as `C_c` with `c=1,2,3` — i.e. a chirplet operator run at 25%, 50%, 75% of the strut. Test: does the `O(n³)` macro-state bound (Ch 9) vary monotonically with `c`? If 1,2,3 interpolate, the collapse `132→29` should shift smoothly.

2. **Other basis triples / other CD levels.** Maybe some basis triple *does* give `|[a,b,c]| = 2` (e.g. involving `e₃`, `e₅` etc.), and `1,2,3` are the magnitudes of associators that stay *inside* the time-like or space-like sectors, not crossing the interface. Test: enumerate `|[eᵢ,eⱼ,eₖ]|` for all 8³ = 512 basis triples (a finite `decide` like `strut_weight_eq_four`); the histogram *is* the answer. If only `0` and `4` appear, then 1,2,3 have no basis realization and hypothesis 1 is the right reading.

3. **Higher CD levels.** `strut_weight` is defined as `|[e₁,e₂,e₄]|` at CD 3. At CD 4 (sedenions, non-alternative) the associator stops being alternating and ceases to be a sign — weights 1,2,3 might be the *new* magnitudes that appear when the associator becomes vector-valued. Test: requires a Sedenion type (not yet in the build; Ch 3 notes this gap). Until a Sedenion algebra exists, 1,2,3 as sedenion associator norms remain [H].

**What would confirm/refute:**

* Confirm 1: the `c=1,2,3` fibres are *useful* — they give strictly intermediate compression/behaviour in the plasma toy (Ch 10) between `c=0` and `c=4`.
* Refute 1: `c=1,2,3` are indistinguishable from `c=0` or `c=4` in every observable (then the strut is quantized, only 0 or 4 matter).
* Confirm 2: the 512-triple enumeration shows `1,2,3` occur.
* Refute 2: enumeration shows only `0` and `4` (then 1,2,3 are not basis associator magnitudes).
* Confirm 3: a Sedenion associator enumeration shows `1,2,3` appear.

---

## 5. Status

* `[P]` The Rees reading itself (`T_c` is a family over `Spec ℤ[c]`, `c=0` wavelet, `c=4` chirplet) — established in `HyperbolicChirplet.lean` as a definition, not a theorem.
* `[P]` `strut_weight = 4` as the distinguished fibre — proven.
* `[H]` Weights 1,2,3 as intermediate fibres — the investigation above, now logged as future work alongside `11.1.1` (imaginary-part) and `11.1.2` (pentagon) in `docs/primer/11_open_problems.md`.

No new physics is posited; the hyperbolic turn is what the tower already contains, now with an address (`c`) for the question "what would a half-strut mean?"

---

## References

* `foundations/Algebra.lean` — `associator_tensor`, `left/right_alternative`, `associator_antisymm_left`, `associator_e0_vanishes`, `strut_weight`, `signCocycle`
* `HyperbolicChirplet.lean` — `chirpRate`, `chirpletOperator`, `chirpScalar`, `scaledChirpRate`
* `lab_protocol.md` v0.3 — (4,4) Signature Model, timespace decomposition
* `docs/primer/00_introduction.md` — unqualified vs universal absolute (regulative idea)
* `docs/primer/04_handedness.md` — right-hand rule chapter
