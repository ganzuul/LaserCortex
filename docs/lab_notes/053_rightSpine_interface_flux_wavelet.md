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
3. **`leftWeight` is the slow variable** the transit map tracks, and it
   accumulates exactly the `rightSpine` contributions (`leftWeight (Node l r) =
   l.size + leftWeight l + leftWeight r`). So the reduced model already
   *keeps* the detail-integral while discarding the exact bracket — the
   standard low-pass tradeoff.

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

## 6. Status

Open. This is a candidate *meaning*, not a proven invariant. It sits on the
reduced-model track (the many-to-one transit map and its limit shape) as the
answer to "what is the detail we are discarding, and is the decomposition
principled rather than heuristic?"
