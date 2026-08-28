# Chapter 1 — The problem, conventionally

*Why magnetohydrodynamics; why confinement; why three dimensions.*

## 1.1 Plasma, fields, and the equilibrium problem (draft)

- Magnetic field as the confining structure; ∇·B = 0; the equilibrium
  `J × B = ∇p`.
- **Reduced continuum model:** equilibrium codes do not simulate particles;
  they solve a *reduced continuum model* — this phrase is load-bearing and
  recurs in Chapter 9.
- [std claims: standard magnetohydrodynamics; no tags needed in conventional
  passages, per front matter.]

## 1.2 Tokamaks, stellarators, and the cost of symmetry (draft)

- Tokamak = axisymmetry + plasma current; stellarator = fully 3D coils, no
  toroidal current needed.
- Stellarator geometry is *much* more complex: no symmetry to lean on.
- Quasisymmetry / quasi-isodynamicity as design goals; islands; ι/q.

## 1.3 Why the Cayley–Dickson tower belongs here — a sketch [H]

**[H — sketch, do not nail down in this draft.]** The lightcone census
(Chapter 6, and computed in `scripts/metric_sweep.py`): over the 132
size-6 route configurations, at low "logic temperature" (CD ≤ 2) most routes
are *timelike* — a preferred causal direction exists; at CD ≥ 3 the entire
population is *spacelike* — no preferred direction remains. The sketch
reading: a preferred direction is what axisymmetry *is*, and losing it is
what stellarator geometry *costs*. So the CD tower's phase diagram of
handedness (Chapter 5) might be read as a phase diagram of
"how much geometry is forced": associative regimes tolerate symmetry;
the non-associative regime forces fully three-dimensional structure.

Confirmation/refutation sentence: confirm if a conventional quantity —
e.g. rotational transform as a "timelike coordinate" — can be matched to the
timelike/spacelike classification; refute if the census' classification has
no invariant (coordinate-free) meaning. [Marginalia: this is the passage the
primer exists to make respectable; it is currently a picture, and the picture
is allowed to be provisional in Part I.]

## 1.4 What this primer promises

- A cost on re-association, proven path-independent, with a phase transition.
- A reading of that structure in conventional MHD vocabulary (Part II).
- A plan to compare the resulting reduced model against conventional
  equilibrium and optimization computations (Chapter 10).

## Sources

- Notes 048 (phase diagram), 051 (lightcone census), 054 (anchors).
- Computed: `scripts/metric_sweep.py`, `plots/lightcone_census.png`.
- Conventional content restated from standard MHD literature (no external repo
  referenced).
