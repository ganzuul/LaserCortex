# Lab Note 053 — `rightSpine` as the interface-flux invariant (wavelet reading)

**Date**: 2026-08-26
**Follows**: 052_tamari_metric_geodesic.md (C2/C5/C3), the reduced-model discussion
**Status**: HYPOTHESIS — a candidate answer to the open "invariant meaning of `rightSpine`" problem, framed as a divide-and-conquer decomposition.

## 1. The question

The ledger carries an open problem: **what is the invariant meaning of
`rightSpine`?** We know its role combinatorially — it is the coupling term in
the composition law

    dcStep (Node l r) = dcStep l + dcStep r + rightSpine l

and the depth of `l`'s rightmost ("output") chain. But why *that* quantity, and
what does it measure?

The hypothesis here: **`rightSpine l` is the cross-boundary coupling — the
minimal flux of associativity moves across the `l | r` cut** — and the
composition law is a divide-and-conquer decomposition of exactly the shape that
signal processing uses to separate coarse structure from fine detail.

## 2. The correspondence

| Signal processing (JPEG2000 / wavelets) | This project |
|---|---|
| subband split (low + high) | the `l \| r` partition |
| low-pass approximation (coarse) | `dcStep l + dcStep r` (internal costs) |
| detail / wavelet coefficients | **`rightSpine l`** — the interface flux |
| total = coarse + detail | `dcStep (Node l r) = dcStep l + dcStep r + rightSpine l` |
| the all-coarse image (DC) | the right comb (`dcStep = 0`) |
| "where to draw the line" = quantization + rate-distortion | the trust discount λ (pay for the coupling or don't) |
| CDF 5/3 lossless integer↔integer lifting | ℕ-valued `dcStep`/`rightSpine` |

The last row is why the analogy is more than decorative: JPEG2000's *lossless*
path uses the CDF 5/3 wavelet precisely because it maps integers to integers,
and our cost is ℕ-valued for the same bookkeeping reason.

### Verification of "flux" (not asserted, computed)

`l = (ab)c` has `rightSpine l = 1`, and `Node l r = ((ab)c)·r` needs
`1 + 0 + 1 = 2` moves: one internal (`dcStep l = 1`), one crossing the boundary
(`rightSpine l = 1`, the root rotation `(ab)c ⋆ r → (ab)(c ⋆ r)`). The
`rightSpine` term counts exactly the elements on `l`'s right edge that must
move across the cut during full right-association. So "flux" is literal, not
metaphorical.

## 3. The invariant-meaning conjecture

> **`rightSpine l` is the invariant measuring cross-boundary coupling** — the
> interface width / entanglement of a composition — and it is the one quantity
> the coarse-graining cannot discard without losing the ability to reconstruct
> the exact bracket.

This ties together three things that had been sitting in separate notes:

1. **The composition law is a lifting scheme** (divide-and-conquer, total =
   coarse + detail). This is the *algebraic shape* of the reduced model.
2. **`rightSpine` is the detail coefficient** at the `l | r` cut — the
   high-frequency information lost in a low-pass (coarse) reduction.
3. **`leftWeight` is the slow variable** the transit map tracks. [Correction
   added 2026-08-28 in the primer pass: an earlier draft said leftWeight
   "accumulates exactly the `rightSpine` contributions" — that is false, and
   its own displayed formula refutes it.] `leftWeight (Node l r) =
   l.size + leftWeight l + leftWeight r` accumulates the *sizes* of the left
   children along the joins, while `dcStep` (via the composition law)
   accumulates their *rightSpine* depths: the same recursion path, coarser and
   finer weights respectively (left-comb of size 4: leftWeight = 3,
   dcStep = 2). The reduced model keeps the coarse measure; the flux keeps
   the fine one — the standard low-pass tradeoff, but with the two measures
   now kept properly distinct.

## 4. Caveats (where the analogy must not be pushed)

1. **Combinatorial, not analytic.** `rightSpine` is a path length; a wavelet
   filter carries vanishing moments and orthogonality. The parallel holds at
   the level of *hierarchical decomposition with a coupling scalar*, not "the
   same kind of object as a CDF filter."
2. **Asymmetric, not two-band-symmetric.** Wavelets produce symmetric low+high
   at every level; here the coupling is attributed entirely to the *left*
   operand's right spine. Whether a right-spine dual symmetrizes this (a
   left-comb-to-normal-form `leftSpine`) is itself open.
3. **The "line" is a resource tradeoff, not a cutoff.** JPEG2000 draws the line
   by quantization under a bit budget (rate-distortion); we draw it by the
   trust discount λ. Both are "how much detail can you afford" — but λ is a
   semantic (institutional) dial, not a quantizer.

## 5. What this predicts / next checks

If "interface flux" is the right invariant, then:

- **Right-spine symmetry.** A left-comb normal form should admit a mirror
  `leftSpine` with its own composition law; the two should be Galois/antipode
  duals (the antipode already negates odd-grade weights — see
  OctilinearEmbedding `covectorProjection_antipode`).
- **Flux conservation.** The total `rightSpine` flux over a full reduction
  should equal a boundary term — a "divergence theorem" on the cover graph.
- **Rate-distortion formalization.** The λ-discount as the analog of
  rate-distortion: `looseCost` (discard detail) vs `weightedCost` (keep all
  detail) is a distortion measure with `(1−λ)·S` the discarded flux — already
  exact via `looseCost_linear_in_trust`.

The first is the cheapest to check and would upgrade this note from hypothesis
to theorem (or kill it cleanly).

## 6. Insight for the anyon correspondence

The interface-flux reading does real work for the anyon track — it converts the
loose "fusion tree = EMLTree" dictionary into three specific, testable claims.

1. **F-move depth decomposes into internal + interface.** `dcStep` = F-move
   depth (minimal associator applications to trivialize a fusion tree). The
   composition law says
   `F-move depth = internal F-moves (within l, within r) + interface F-moves
   (across the l | r cut)`, and the interface count is exactly `rightSpine l`.
   In a fusion tree `Node l r`, the nontrivial associativity that crosses the
   cut is `rightSpine l` — the "detail" attributable to neither side alone.

2. **Γ is the price of interface flux.** The associator strut (Γ: 2 → 19 at
   CD 3, octonions) is the cost of the cross-boundary F-moves becoming
   nontrivial. At CD ≤ 2 the associator vanishes — interface flux is free; at
   CD ≥ 3 each interface F-move costs one grind. The loose-coupling discount
   (`looseCost_linear_in_trust`, which discounts only the `rightSpine · γ`
   term) is literally "don't pay for the interface flux" — the rate-distortion
   dial in anyon clothing.

3. **The pentagon coherence is what makes the flux a well-defined invariant.**
   The pentagon equation (F-matrix coherence) is exactly the path-independence
   of `dcStep`: no fusion path beats the greedy one. So the geodesic theorem
   *is* pentagon coherence restated, and `rightSpine l` is its per-cut
   contribution. The "flux conservation" prediction of §5 is therefore a
   topological statement — total F-move depth is a path-independent charge.

**Caveat.** This is the *kinematic* structure (the free associahedron shared by
every fusion category), not the *dynamical* data (the specific F-matrix weights
/ 6j symbols of e.g. Fibonacci anyons). The interface-flux claim says *how
many* cross-boundary F-moves there are and that the associator prices them; a
concrete model would add *how much* each charges. That piece is still required
to promote "`contracts_one` = F-move" from correspondence to theorem.

## 7. Flux conservation and magnetohydrodynamics

The "flux conservation" prediction of §5 resembles magnetohydrodynamics (MHD)
at the level of **topological conservation** — a flux that depends only on the
boundary / is path-independent, because the underlying object is closed.

| Ideal/resistive MHD | This project |
|---|---|
| magnetic field `B` | the associator (the nontrivial cross-cut structure) |
| `B = ∇ × A` (field is a curl) | the associator as a coboundary (exact) |
| `∇·B = 0` (no monopoles) | the **pentagon equation** (cocycle condition) |
| flux `= ∫ B·dA = ∮ A·dl` (Stokes: boundary-only) | total `rightSpine` flux = a boundary term |
| Alfvén frozen-in (comoving flux conserved) | `dcStep` is path-independent under the cover dynamics |
| **resistivity η turning on** | **the Γ strut turning on at CD 3** |

The two "conservation" senses line up: Stokes' theorem (boundary-only flux)
↔ the divergence theorem on the cover graph; frozen-in (time-conserved flux)
↔ path-independence of `dcStep`. Both reduce to the same sentence — *the flux
is a topological invariant because the underlying object is closed (coherent).*

### Γ is "resistivity"

The sharpest part is the phase transition:

- **Ideal MHD** = zero resistivity = field lines frozen in = no reconnection =
  flux perfectly conserved.
- **Resistive MHD** = η > 0 = reconnection allowed = flux dissipates into heat.

Mapped onto the tower:

- **CD ≤ 2 (associative)** = "ideal": associator trivial, pentagon vacuous,
  re-association free, flux perfectly conserved.
- **CD ≥ 3 (non-associative)** = "resistive": associator nontrivial, pentagon a
  real constraint, each interface F-move carries a Γ charge — the flux
  "dissipates" into cost.

So the Γ jump `2 → 19` at the octonions is **the resistivity turning on** — the
point where conserved (frozen-in) flux gives way to charged (dissipative)
reconnection. The loose-coupling discount (`looseCost_linear_in_trust`, removing
`(1−λ)·S` of interface flux) is then a *finite-resistivity* relaxation: detail
is allowed to leak away to save cost.

### Limits and the lead

Two limits keep this honest: ours is **discrete** (a combinatorial Stokes/Gauss
on a graph, not a continuous PDE), and **scalar** (a count `rightSpine`, not a
vector field `B`). The second is constructive: to make the analogy tight, the
associator/flux should be promoted to a **1-cochain** on the cover graph whose
coboundary is the associator and whose integral is `dcStep`.

That names the rigorous target — **cohomology of the associahedron**:

- the pentagon equation *is* the cocycle condition (`δ² = 0`);
- the associator *is* a 2-cocycle (classically: a Hochschild cocycle);
- `dcStep` / the flux *is* its cohomology class — conserved because closed,
  boundary-only because exact off the cut;
- the phase transition: at CD ≤ 2 the class is trivial (no flux); at CD ≥ 3 it
  is nontrivial (flux carries charge).

This connects to existing fragments in the repo (`006_hopf_7_skeleton`,
`023_cd_homotopy_bridge`, the Chu/KKT duality). The MHD intuition is therefore
not decorative — it names the *formalization*: prove the associator is a
cocycle and `dcStep` is its cohomology class, so that "flux conservation" is
`δ² = 0` and the Γ jump is the class going from trivial to nontrivial.

## 8. Status

Open. This is a candidate *meaning*, not a proven invariant. It sits on the
reduced-model track (the many-to-one transit map and its limit shape) as the
answer to "what is the detail we are discarding, and is the decomposition
principled rather than heuristic?"
