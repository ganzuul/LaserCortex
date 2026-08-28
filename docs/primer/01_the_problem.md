# Chapter 1 — The problem, conventionally

*Why magnetohydrodynamics; why confinement; why three dimensions.*

## 1.1 Plasma, fields, and the equilibrium problem

A plasma is a hot, electrically conducting gas: it carries current, and
currents feel magnetic force. The practical consequence is that a plasma can
be confined — held away from material walls — by a magnetic field shaped for
the purpose. Two equations carry the idea. The field is *solenoidal*,

    ∇·B = 0,

meaning field lines never begin or end: there are no magnetic monopoles, so
lines close on themselves or leave the domain. And equilibrium is a force
balance,

    J × B = ∇p,

between magnetic force (current density crossed with field) and the pressure
gradient of the hot gas. The `×` is the cross product — the same right-hand
rule that Chapter 4 makes central — and its meaning is that magnetic force
acts *sideways*, perpendicular to both current and field. That sideways
character is what turns confinement into a geometry problem rather than a
wall-strength problem.

Equilibrium codes do not simulate every particle. They solve the balance above
as a **reduced continuum model** — coarse fields standing in for fine
particles — and that same divide-and-conquer between detail and structure is
what Part II makes precise for re-association.

## 1.2 Tokamaks, stellarators, and the cost of symmetry

A **tokamak** confines plasma in a torus (a doughnut) whose field is
*axisymmetric*: essentially identical on every toroidal circuit, so the
geometry repeats and a large plasma current supplies the missing twist. A
**stellarator** gives up that symmetry and shapes its coils so the twist
comes from the magnets themselves, with no steady plasma current required.
The trade is stark: tokamaks live with current-driven instabilities;
stellarators live with fully three-dimensional geometry.

That geometry has a number. A field line advancing around the torus turns
through a poloidal angle per toroidal circuit — the **rotational transform**
`ι` (or its reciprocal, the safety factor `q`). Where `ι` lands on a nice
rational value, the nested surfaces break into **magnetic islands**: bundles
of field lines that close on themselves after a few circuits — and between
islands, chaos. The design programs called **quasisymmetry** and
**quasi-isodynamicity** are convictions that a well-chosen three-dimensional
field can recover some of the good behavior that axisymmetry bought for free,
without buying back the current.

One asymmetry should be registered here, because this whole primer stands on
it: axisymmetry is not an approximation that is always available. It is a
*preferred direction* — and preferred directions are exactly what the census
of Chapter 6 finds vanishing at high "logic temperature" (§1.3).

## 1.3 Why the Cayley–Dickson tower belongs here — a sketch [H]

**[V]** The lightcone census (Chapter 6; computed in
`scripts/metric_sweep.py` and re-verified by `scripts/presentation_data.py`):
over the 132 size-6 route configurations, at low "logic temperature"
(CD ≤ 2) most routes are *timelike* — a preferred causal direction exists; at
CD ≥ 3 the entire population is *spacelike* — no preferred direction remains.

**[H — sketch, do not nail down in this draft. Level: picture.]** The reading:
a preferred direction is what axisymmetry *is*, and losing it is
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
