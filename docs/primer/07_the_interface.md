# Chapter 7 — The cut: the interface

*Anchor D. "What crosses the seam between parts?"*

## 7.1 Conventional grounding: the subband split

- Signal decomposition: a signal splits into coarse (low-pass) + detail
  (high-pass); the detail is what the coarse representation discards.
- The composition law is the same algebraic shape — a **lifting scheme**:
  `total = coarse + detail`.

*Level for "lifting scheme": analogy (equational).* The match is the shape
`total = coarse + detail`. No analytic filter content is claimed: no vanishing
moments, no orthogonality. [Marginalia: caught while fixing — the previous
draft implied the filter structure transfers too; it does not, because there
is no transform here, only a recursion.]

## 7.2 The composition law **[P]**

- `dcStep (Node l r) = dcStep l + dcStep r + rightSpine l`.
  (**[P]** `dcStep_node_compose`)
- `rightSpine l` = the depth of l's output chain = **the cross-boundary
  coupling** = the number of flips that cross the l | r cut.
- Verification (worked example, `l = (ab)c`): `rightSpine l = 1`, and
  `((ab)c)·r` needs 1 + 0 + 1 = 2 flips — one internal, one crossing. **[V]**
- `rightSpine (rightComb n) = n`. **[P]** (`rightSpine_rightComb`)

## 7.3 The interface-flux hypothesis **[H]**

> `rightSpine l` is the invariant measuring cross-boundary coupling — the
> minimal flux of associativity moves across the l | r cut.

Confirm: `rightSpine l` is path-independent across all reduction paths of
`Node l r` and equals the number of cross-boundary flips in each; refute: any
reduction path whose cross-boundary count differs from `rightSpine l` (then
"interface flux" needs a different invariant). *Level: analogy (apt) until the
path-independence sentence is proved.*

- Two spine-measures, related but *not equal* **[V]** (recomputed here):
  along a left comb, `leftWeight` accumulates the *sizes* of the left
  children at the joins, while `dcStep` accumulates their *rightSpine*
  depths — the same recursion path, coarser and finer weights respectively.
  The transit map keeps the coarse one; the flux keeps the fine one.
  [Marginalia: an earlier draft of this section claimed leftWeight
  "accumulates exactly the rightSpine contributions". Checked against the
  recursion: left-comb of size 4 has `leftWeight = 3`, `dcStep = 2`. Fixed;
  recorded in the register.]
- Predictions (from note 053): a right-spine/left-spine antipode duality
  (Chapter 11, item 3); a "divergence theorem" (total flux = boundary term;
  item 4); the λ-discount as rate-distortion (§7.4). **[H]**

## 7.4 The λ-discount as rate-distortion **[P]** exactness / **[H]** reading

- `looseCost cd num den l r = (dcStep l + dcStep r)·γ + num·rightSpine l·γ/den`
  — the discount rescales *only the interface*, never the internal terms.
  **[def]**
- `looseCost_linear_in_trust` **[P]**: exactly linear in the trust numerator
  over ℚ; stiffness `rightSpine l · γ / den`.
- Reading: λ is the "quality dial" — how much detail (interface flux) you pay
  for; `(1−λ)·S` is the discarded flux. **[H]** *Level: analogy (apt).*
  Confirm: a rate-distortion problem (distortion = discarded interface flux,
  rate = trust paid) whose optimum reproduces `looseCost`; refute: `looseCost`
  cannot be recovered as any such optimum — the discount is an ad-hoc dial,
  not a solved tradeoff.

## Sources

- `SubdivisionClosure.lean` (§composition law, §loose coupling),
  `TamariMetric.lean`.
- Notes 049, 050, 053 (the wavelet reading), 054 (anchor D).
