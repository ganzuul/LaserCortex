# Chapter 6 — Flux

*Anchor C. "How much turns, net?"*

## 6.1 Conventional grounding: conserved flux (draft)

- Flux through a surface depends only on its boundary (Stokes) — because
  `∇·B = 0`.
- Flux through a comoving surface is conserved in ideal MHD (frozen-in).
- Both are "topological conservation": the flux is an invariant because the
  field is closed.

## 6.2 The flip count is a geodesic **[P]**

- `dcStep t` = minimal number of `contracts_one` rotations to the right comb.
  **[P]** (`TamariMetric.dcStep_eq_geodesic`, no `sorry`): the greedy count is
  minimal; the flux is **path-independent**.
- The composition law `dcStep (Node l r) = dcStep l + dcStep r + rightSpine l`
  **[P]** (`dcStep_node_compose`) — total = coarse + interface (Chapter 7).

*Level for the word "flux": analogy (apt).* The literal content is the two
proven facts above: the count is minimal and path-independent, so it behaves
like a conserved charge. "Flux" borrows the *conservation* of magnetic flux,
not its vector-field structure — the latter is conjectural here (§6.4).

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

- **[H]** The pentagon coherence is what makes the flux a well-defined
  invariant: `δ² = 0` for the associator as a cocycle, with `dcStep` its
  cohomology class. Confirm: prove the cocycle identity (item 2) for the sign
  cocycle and exhibit `dcStep` as its class; refute: `dcStep` is
  path-independent (already **[P]**) yet no cocycle structure reproduces that
  invariance — in which case the flux language stays analogy.
- **[C]** The **pentagon cocycle identity**:
  `φ(b,c,d)·φ(a,bc,d)·φ(a,b,c) = φ(a,b,cd)·φ(ab,c,d)` — the δ²=0 check,
  a finite computation, recorded as future work (Chapter 11). Confirm: a
  `decide`/`ring` check over basis triples succeeds; refute: it fails for any
  single triple.
- **[C]** The **imaginary-part property**: the associator's e₀ component
  vanishes — the reduction of the flux to a sign. Confirm/refute as in
  Chapter 4, §4.4.

## Sources

- `TamariMetric.lean` (geodesic, maximal potential), `SubdivisionClosure.lean`
  (composition law), `foundations/Algebra.lean` (associator).
- Notes 051, 052, 053 (§6–§7: anyon and MHD readings).
