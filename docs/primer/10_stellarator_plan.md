# Chapter 10 — The stellarator comparison plan

*Where the CD-grounded model meets conventional computation. This chapter
names open-source tools but references no external repository; the plan is
self-contained.*

## 10.1 Why stellarators are the target [sketch, ties to Chapter 1 §1.3]

Conventional stellarator geometry is three-dimensional with no axisymmetry;
tokamaks are axisymmetric. The sketch reading developed in Chapter 1: at low
"logic temperature" (CD ≤ 2) the route census is mostly timelike — a preferred
direction exists; at CD ≥ 3 the entire population is spacelike — no preferred
direction remains. A preferred direction is what axisymmetry *is*. So the
non-associative regime is, in this reading, the regime that *forces* fully
three-dimensional geometry: exactly the stellarator regime.

**[H — sketch.]** The CD reduced lattice model should therefore show its
clearest signature in problems where symmetry is *not* available to lean on —
stellarator equilibria and their optimization — and its cleanest agreement with
convention in the axisymmetric (tokamak) limit, where the timelike structure
persists.

Confirmation/refutation sentence: confirm if the model's phase classification
(timelike/spacelike routes) aligns with the axisymmetric/non-axisymmetric
split of conventional equilibria; refute if the classification is insensitive
to that split.

## 10.2 The conventional side

Equilibrium and optimization codes the comparison would use. **[std —
unverified here.]** *Each line below is a characterization of an external
code; none is checked against upstream documentation in this draft. Before
external use, verify each against the tool's current docs — a wrong
characterization of VMEC/DESC/SIMSOPT/SPEC is the kind of error that
discredits the comparison plan around it.*

- **VMEC** — nested-flux-surface (single-helicity) ideal-MHD equilibrium; the
  W7-X-era workhorse. The description "equilibrium as a reduced continuum
  model" is *our* framing (Chapter 9), not the code's self-description.
- **DESC** — spectral/variational equilibrium + optimization.
- **SIMSOPT** — target-function optimization framework over equilibria
  (quasisymmetry operators etc.).
- **SPEC** — stepped-pressure equilibria *without* assumed nested flux
  surfaces (island/chaotic regions) — relevant because our flip count is
  defined on trees whose normal forms can sit in island-like regimes
  (Chapter 6).
- Coordinate-free quantities to compare against: rotational transform ι,
  field strength on surfaces |B|, island widths, and the *number of free
  parameters* each description needs (see §10.4).

## 10.3 What the CD side contributes

- The reduced lattice (Chapter 9): trees → transit coordinates, a many-to-one
  collapse **[V]**; `dcStep` as conserved flux **[P]** (with "flux" at
  analogy level, Chapter 6); Γ as resistivity **[H]** (Chapter 8).
- The honest object at this stage is the **reduced *lattice* model** — the
  continuum limit (Chapter 9 §9.5) is unproven and deferred.

## 10.4 The comparison quantities, in order (draft)

1. **Design-space counting.** How many distinct configurations does each
   description carry at a given size/complexity? Ours: Catalan trees collapsed
   to the transit map (132 → 29 at size 6). Theirs: discretized coil/surface
   parameters. Compare growth rates and redundancy (the "many-to-one"
   structure).
2. **The rotational transform as a timelike coordinate.** The sketch of §10.1
   turns into a test: is ι (or q) the conventional quantity that plays the
   role of our timelike/spacelike classifier?
3. **A single equilibrium family.** Run one family (e.g. a simple
   quasi-axisymmetric case) through both pipelines; compare the *phase*
   assignments (timelike/spacelike routes) with (non)axisymmetry.
4. **The Γ boundary.** Ask whether any conventional design transition (e.g.
   the nested-surface → island regime) lands at the model's CD 3 critical
   point in some matched parameterization. [H, provisional.]
5. **Where the model must fail.** Islands and chaos break nested-surface
   assumptions; the Tamari flip structure may (or may not) capture that
   breakdown. The comparison must include the cases the model cannot yet see —
   this is where the alternator strut (Chapter 5) and the limit shape
   (Chapter 9) would first be needed.

## 10.5 Sequencing (draft)

Phase 1: design-space counting and a single matched equilibrium (items 1–3) —
   no new formalism needed, only the existing reduced lattice and the census.
Phase 2: the Γ-boundary question (item 4) — requires the pentagon cocycle
   identity and imaginary-part property (Chapter 11) to be in place, so that
   "flux" is a theorem and not a picture.
Phase 3: the failure modes (item 5) — requires the alternator strut and the
   limit-shape program.

## Sources

- Chapters 1 (§1.3), 6 (census), 9 (reduced lattice), 11 (ledger).
- Conventional codes as named above; standard stellarator literature.
