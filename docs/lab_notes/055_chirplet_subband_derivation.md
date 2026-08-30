# Lab Note 055 — Chirplet + Subband as the Reduced Lattice

**Date**: 2026-08-28
**Follows**: 054 (ontological anchors), 053 (interface flux), TamariMetric C2/C5/C3, primer Ch 7/9
**Status**: DERIVATION — how `wavelet+subband → chirplet+subband` is forced by the
CD construction, and how the result *is* the reduced lattice already in Lean.

## 1. The progression is forced, not chosen

```
Fourier atom            e^{i ω t}                  i² = -1   (elliptic)
      │  CD α = +1 on phase  (use split unit j, j² = +1)
      ▼
Hyperbolic Fourier      e^{j ω t}=cosh+sinh        j² = +1   (hyperbola)
      │  add quadratic phase (let associator be non-zero)
      ▼
Hyperbolic chirplet     e^{j(ωt + c t²/2)}·window   c = associator sign
      │  CD-double the envelope (1D → 2D → 4D via (2,2)→(4,4))
      ▼
(4,4)-hyperbolic chirplet  split-octonion valued, Q44-normalized
```

Each arrow is "apply the CD doubling to the *phase algebra*." The split
branch `j²=+1` is not an extra hypothesis — it is already in
`Algebra.lean:13-14` (`ω=e₄, ω²=+1`) and in `Q44` (4,4). The hyperbolic turn
is what the tower *contains* once it is taken as substrate (Ch 3).

## 2. What we already have *is* `wavelet+subband`

The Lean you have encodes a 2-channel subband filter bank, without calling it
that. The proven law in `SubdivisionClosure.lean` is the analysis bank:

```lean
dcStep (Node l r) = dcStep l + dcStep r + rightSpine l   -- [P] dcStep_node_compose
```

Read as:

* **Coarse (low-pass):** `dcStep l + dcStep r` — cost inside each subband.
* **Detail (high-pass):** `rightSpine l` — cross-boundary flux.
* **Synthesis:** graft `l` and `r`.

Iterate the analysis on `l` and `r` recursively. The limit is `rightComb n`
where `dcStep = 0` — exactly JPEG2000's **scaling function** (fully coarse,
detail = 0). `OctilinearEmbedding.lean:transitCoord = (size+assocDefect,
leftWeight-rightWeight)` is the *coarse coordinate* (low-pass output).

So the **reduced lattice *is* the subband limit**. No new structure is needed
to claim `wavelet+subband = reduced lattice`. The many-to-one collapse
`132 → 29` at size 6 is the empirical signature of that subband (exponential
micro-states, polynomial macro-states — Ch 9).

| JPEG2000 | This project (proven) |
|---|---|
| wavelet atom | rotation `Node(Node a b) c → Node a(Node b c)` |
| subband (low+high) | `Node l r → (coarse: l,r ; detail: rightSpine l)` |
| scaling function (limit, detail→0) | `rightComb` (`dcStep=0`, associator→0) |
| filter bank iteration | recursion on `l` and `r` |

## 3. The forced extension to chirplet

A wavelet is the coherent state of the affine group (dilations + translations).
A chirplet adds the **shear / chirp** generator — quadratic phase. That
generator *is* what alternativity provides.

You proved this session in `foundations/Algebra.lean`:

* `left_alternative` / `right_alternative` → `associator_antisymm_left:
  [a,b,c] = -[b,a,c]` **[P]**

An *alternating* associator is *one signed scalar* (`strut_weight =
|[e₁,e₂,e₄]| = 4` **[P]**), not a vector. Its antisymmetry is the chirp
rate's orientation — the right-hand rule. That antisymmetric 3-form *is* the
chirp rate `c`.

Therefore the progression `wavelet → chirplet` is forced once the phase
algebra is doubled via CD to its split branch:

* **Elliptic Fourier** `e^{i ω t}` (`i²=-1`) — CD `α=-1`, associativity holds.
* **Hyperbolic Fourier** `e^{j ω t}` (`j²=+1`) — CD `α=+1`, already in the
  tower as `e₄`.
* **Hyperbolic chirplet** `e^{j(ωt + c t²/2)}` — add the quadratic phase `c`,
  where `c` *is* the associator sign (polarization). At CD ≤2, `c=0`
  (associator trivial) → chirplet collapses to hyperbolic Fourier; at CD ≥3,
  `c = ±1` → genuine chirp.

The split signature `(4,4)` is not incidental — it *is* the hyperbolic
geometry of the chirplet. Conventional spectral `i²=-1` gives the circle;
split `j²=+1` gives the hyperbola, and `Q44` in `Algebra.lean:222` is that
hyperbola's norm. The chirplet lives on the hyperbola by construction.

## 4. Derivation of `chirplet+subband` as the reduced lattice

Put 2 + 3 together. The derived representation is:

**Analysis:**
```
Node l r  ──►  ( coarse: dcStep l , dcStep r ;
                 detail: rightSpine l · exp(j·c) )    where c = φ(l)
```

**Subband iteration:** apply recursively to `l` and `r` until `rightComb`
(detail → 0). The iterated detail coefficients are the **chirplet subband**.

**Limit:** `rightComb n` (`dcStep=0`, `assocDefect=0` at CD≤2) is the scaling
chirplet — fully coarse, associator limit, exactly as in §2.

This is *directly* the Lean you have, with one new scalar `c`. Concretely,
a minimal Lean extension is:

```lean
def chirpRate (a b c : SplitOctonion) : ℤ :=  -- [C] pending 11.1.1
  sorry -- sign of associator after imaginary-part reduction

def chirpletDetail (l : EMLTree) : ℤ :=
  rightSpine l * chirpRate_of_tree l

-- enriched law (to be proven, collapses to dcStep_node_compose when c=0):
-- dcStep_chirplet (Node l r) = dcStep l + dcStep r + chirpletDetail l
```

When `chirpRate = 0` (associative / CD≤2) this *is* `dcStep_node_compose`.
When `chirpRate = ±1` (alternative, after 11.1.1) it is the hyperbolic
chirplet. This makes the "next progression" literal: keep the proven
`wavelet+subband` (the reduced lattice), replace the atom `rightSpine` by
`rightSpine·exp(j·c)`.

## 5. Honest status

* **[P]** The subband structure *is* the reduced lattice (composition law +
  geodesic + collapse 132→29). No new theorem needed to claim
  `wavelet+subband = reduced lattice`.
* **[P]** The associator is alternating (just proven) — so a chirp *rate* as a
  sign exists in principle.
* **[C]** That the associator reduces to a sign (purely imaginary, `e₀=0`) —
  **Chapter 11, item 1** — is the step that makes `chirpRate` a single scalar
  `c` rather than a vector. Until it is proven, `chirplet+subband` is the
  correct *shape* but the atom is vector-valued.
* **[C]** The pentagon cocycle identity `φ(b,c,d)·… = …` — **Chapter 11,
  item 2** — is what makes the chirplet subband *coherent* (flux conserved,
  `δ²=0`). Also pending, but a finite `decide`/`ring` check.

**Bottom line:** Yes, `chirplet+subband` with *subband = associator → 0
limit* is exactly the right description of the reduced lattice you already
have, and it is the forced next step after `wavelet+subband` once the phase
algebra is doubled via CD to its hyperbolic branch. The Lean to make it
literal is one scalar definition (`chirpRate`) plus the two open items in
Chapter 11 — the same two items that already block Chapter 6's literal flux
claim.

## 6. What to do next

The derivation note is the *trace* (this file). The Lean skeleton
`LaserCortex/HyperbolicChirplet.lean` stubs `chirpRate` / `chirpletDetail`
as `[C]` so the subband theorem type-checks now and becomes `[P]` when
11.1.1 lands. No new physics is posited; the hyperbolic turn is what the
tower already contains.
