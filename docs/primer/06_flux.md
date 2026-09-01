# Chapter 6 — Flux

*Anchor C. "How much turns, net?"*

## 6.1 Conventional grounding: conserved flux (draft)

- Flux through a surface depends only on its boundary (Stokes) — because
  `∇·B = 0`.
- Flux through a comoving surface is conserved in ideal MHD (frozen-in).
- Both are "topological conservation": the flux is an invariant because the
  field is closed.

## 6.2 The flip count is a geodesic **[P]**

We need a flip count that does not depend on which re-association path is
chosen — otherwise "cost" would be ambiguous. Two facts make it usable.

- `dcStep t` = minimal number of `contracts_one` rotations to the right comb.
  **[P]** (`TamariMetric.dcStep_eq_geodesic`, no `sorry`). In English: the
  greedy count is minimal, so the flux is **path-independent**.
- The flip count then *decomposes*: `dcStep (Node l r) = dcStep l + dcStep r +
  rightSpine l` **[P]** (`dcStep_node_compose`). In English: total =
  coarse + interface — the shape Chapter 7 makes central.

*Level for the word "flux": analogy (apt) — updated by §6.5.* The literal
content is the two proven facts above: the count is minimal and
path-independent, so it behaves like a conserved charge. "Flux" borrows the
*conservation* of magnetic flux, not its vector-field structure — but the
latter has stopped being conjectural: on the periodic lattice the
vector-field half is a theorem (§6.5). What remains hypothesis is the
dynamical reading (§6.4).

## 6.3 The lightcone census

- 196 trees (sizes ≤ 6); the size-6 census of 132 routes classified against
  `⟨dcStep,dcStep⟩ = dcStep² − γ²` (classification as in
  `scripts/metric_sweep.py`; the split-signature form is
  `CoherenceMetric.lean` **[def]**): at CD ≤ 2 mostly timelike; at CD ≥ 3 the
  *entire* population is spacelike. **[V]**
- **[H — sketch]** the population-wide inversion as the phase signature;
  its reading for geometry is Chapter 1 §1.3.
- Computed: `scripts/metric_sweep.py`; figure `plots/lightcone_census.png`.

## 6.4 The conservation claim

Everything above in this chapter is theorem or computation; this section is
the hypothesis that would connect them, and it is where the word "flux" either
graduates to literal structure or stays an analogy. Three claims, from
softest to hardest:

- **[H]** The pentagon coherence is what makes the flux a well-defined
  invariant: `δ² = 0` for the associator as a cocycle, with `dcStep` its
  cohomology class. The first half has landed: the cocycle identity is
  **[P] on the basis** (next bullet; general elements not claimed) and the
  discrete closure of the flux is **[P]** (§6.5). The reading — that this
  coherence is *what makes* the flux invariant, with `dcStep` as its class —
  remains hypothesis. Confirm: exhibit `dcStep` as the cohomology class of
  the proven cocycle; refute: `dcStep`'s invariance (already **[P]**)
  reproduces under a different structure than the cocycle.
- **[P] on the basis** The **pentagon cocycle identity**:
  `φ(b,c,d)·φ(a,bc,d)·φ(a,b,c) = φ(a,b,cd)·φ(ab,c,d)` — the δ²=0 check,
  decided over all 8⁴ = 4096 basis quadruples (`pentagon_cocycle_basis`).
  In English: re-bracketing the bookkeeping in two different orders gives
  the same sign — the flux ledger closes. The general-element case is not
  claimed; the coarsening of the associator to a sign (`signCocycle`,
  Chapter 4) is what was tested.
- **[P]** The **imaginary-part property**: the associator's e₀ component
  vanishes for all `a, b, c` (`associator_e0_vanishes`) — the flux drops its
  scalar part and lives in the seven imaginary directions. The further
  reduction to a *single signed direction* remains Chapter 4's
  **[C]**; on the basis lattice what replaces it is quantization
  (Chapter 8, §8.6).

## 6.5 The stencil certificate **[P]** — closure as theorem

The conservation story so far is about flip counts. For the magnetic field
itself there is a second, sharper certificate, and it is the kind of result
that changes what a numerical claim may say: on a discrete grid, the
closure `∇·B = 0` is not an aspiration but a theorem about stencils.

Take a periodic grid (`Nx × Ny` points on a torus) and one scalar field
`ψ` — a *stream function*. Build the field from it by central differences:
`B = (∂y ψ, −∂x ψ)`, where `∂x f` means "value one step forward minus value
one step back", indices wrapping around. Then:

- **The partial differences commute**: `∂x(∂y ψ) = ∂y(∂x ψ)` cell by cell,
  every grid, every field **[P]** (`Stencil.dx_dy`). In English: the x- and
  y-steps touch different coordinates, so the four corners of the stencil
  cancel pairwise — an identity, not an approximation.
- **Therefore the divergence of `B` vanishes identically**:
  `div (curl ψ) = 0` **[P]** (`Stencil.div_curl_eq_zero`, global form
  `div_curl`). In English: a discrete field built from a stream function is
  divergence-free **to the roundoff of the individual arithmetic operations
  — the stencil composition itself contributes zero error**. No grid size,
  no shape, no field is an exception (degenerate grids included, where a
  whole direction collapses and the identity holds trivially).

Two features of the proof deserve to be noticed by a physicist.

- **No solver, no correction.** Schemes that *project* `B` onto a
  divergence-free field after each step converge only to a solver
  tolerance, and — worse for our purposes — an instantaneous global
  projection is known to destroy exactly the comoving-loop flux
  conservation this chapter is about. The stream-function form is
  divergence-free *by construction*; there is nothing to measure and
  nothing to fix. This is the difference between a number you compute and a
  number you certify.
- **The values may be non-associative.** The proof uses only addition,
  negation, and index shifts, and shifts commute (`dx_dy` *is* the statement
  that the grid's translation group is abelian). So the certificate
  survives fields carrying split-octonion or matrix values: a proof that
  never multiplies cannot be broken by bad multiplication. The consequence
  is a partition of the error budget for any dynamical step: **closure is
  free, and associativity defects — the physics of this book — can enter
  only through the multiplicative channels: advection and the Lorentz
  coupling.** Chapter 8, §8.6 is where that priced channel gets its dial.

*Level for the word "flux": literal on the lattice.* The §6.2 disclaimer is
amended at one point: the vector-field structure of flux is now a theorem
for stream-function fields on the periodic stencil **[P]**. What remains
hypothesis is the dynamical half — conservation through *comoving* loops
under a full time step (frozen-in), and the divergence-theorem reading of
the flip count (Chapter 11, item 4).

## Sources

- `TamariMetric.lean` (geodesic, maximal potential), `SubdivisionClosure.lean`
  (composition law), `foundations/Algebra.lean` (associator, sign cocycle,
  pentagon), `Stencil.lean` (div–curl certificate).
- Notes 051, 052, 053 (§6–§7: anyon and MHD readings); 056–058 (Rees fibres,
  quantization, the fidelity dial).
