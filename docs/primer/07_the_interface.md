# Chapter 7 — The cut: the interface

*Anchor D. "What crosses the seam between parts?"*

## 7.1 Conventional grounding: the subband split (draft)

- Signal decomposition: a signal splits into coarse (low-pass) + detail
  (high-pass); the detail is what the coarse representation discards.
- The composition law is the same algebraic shape — a **lifting scheme**:
  `total = coarse + detail`.

## 7.2 The composition law [P] (draft)

- `dcStep (Node l r) = dcStep l + dcStep r + rightSpine l`.
- `rightSpine l` = the depth of l's output chain = **the cross-boundary
  coupling** = the number of flips that cross the l | r cut.
- Verification (worked example, `l = (ab)c`): `rightSpine l = 1`, and
  `((ab)c)·r` needs 1 + 0 + 1 = 2 flips — one internal, one crossing.
- [P: `dcStep_node_compose`, `rightSpine_rightComb`.]

## 7.3 The interface-flux hypothesis [H] (draft)

> `rightSpine l` is the invariant measuring cross-boundary coupling — the
> minimal flux of associativity moves across the l | r cut.

- `leftWeight` (the transit map's slow variable) *accumulates* exactly the
  `rightSpine` contributions — the reduced model already keeps the
  detail-integral while discarding the exact bracket.
- Predictions (from note 053): a right-spine/left-spine antipode duality;
  a "divergence theorem" (total flux = boundary term); the λ-discount as
  rate-distortion.

## 7.4 The λ-discount as rate-distortion [P for the exactness] (draft)

- `looseCost cd num den l r = (dcStep l + dcStep r)·γ + num·rightSpine l·γ/den`
  — the discount rescales *only the interface*, never the internal terms.
- `looseCost_linear_in_trust` [P]: exactly linear in the trust numerator over
  ℚ; stiffness `rightSpine l · γ / den`.
- Reading: λ is the "quality dial" — how much detail (interface flux) you pay
  for; `(1−λ)·S` is the discarded flux.

## Sources

- `SubdivisionClosure.lean` (§composition law, §loose coupling),
  `TamariMetric.lean`.
- Notes 049, 050, 053 (the wavelet reading), 054 (anchor D).
