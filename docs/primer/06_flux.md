# Chapter 6 — Flux

*Anchor C. "How much turns, net?"*

## 6.1 Conventional grounding: conserved flux (draft)

- Flux through a surface depends only on its boundary (Stokes) — because
  `∇·B = 0`.
- Flux through a comoving surface is conserved in ideal MHD (frozen-in).
- Both are "topological conservation": the flux is an invariant because the
  field is closed.

## 6.2 The flip count is a geodesic [P] (draft)

- `dcStep t` = minimal number of `contracts_one` rotations to the right comb.
- `dcStep_eq_geodesic` (`TamariMetric.lean`, no `sorry`): the greedy count is
  minimal; the flux is **path-independent**.
- The composition law `dcStep (Node l r) = dcStep l + dcStep r + rightSpine l`
  [P] — total = coarse + interface (Chapter 7).

## 6.3 The lightcone census (draft)

- 196 trees (sizes ≤ 6); the size-6 census of 132 routes classified against
  `⟨dcStep,dcStep⟩ = dcStep² − γ²`: at CD ≤ 2 mostly timelike; at CD ≥ 3 the
  *entire* population is spacelike.
- **[H — sketch]** the population-wide inversion as the phase signature;
  its reading for geometry is Chapter 1 §1.3.
- Computed: `scripts/metric_sweep.py`; figure `plots/lightcone_census.png`.

## 6.4 The conservation claim (draft)

- **[H]** The pentagon coherence is what makes the flux a well-defined
  invariant: `δ² = 0` for the associator as a cocycle, with `dcStep` its
  cohomology class.
- **[C]** The **pentagon cocycle identity**:
  `φ(b,c,d)·φ(a,bc,d)·φ(a,b,c) = φ(a,b,cd)·φ(ab,c,d)` — the δ²=0 check,
  a finite computation, recorded as future work (Chapter 11).
- **[C]** The **imaginary-part property**: the associator's e₀ component
  vanishes — the reduction of the flux to a sign.

## Sources

- `TamariMetric.lean` (geodesic, maximal potential), `SubdivisionClosure.lean`
  (composition law), `foundations/Algebra.lean` (associator).
- Notes 051, 052, 053 (§6–§7: anyon and MHD readings).
