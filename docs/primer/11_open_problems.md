# Chapter 11 — Open problems and the formalization ledger

*Every [H] and [C] in the primer is listed here with its confirmation /
refutation sentence. Order = the order we intend to work them.*

## 11.1 Immediate (next formalization steps)

| # | Problem | Chapter | Status |
|---|---|---|---|
| 1 | **Imaginary-part property**: the associator `[a,b,c]` has vanishing e₀ component (purely imaginary) — the reduction of the flux to a sign | 4, 6 | open, next |
| 2 | **Pentagon cocycle identity**: `φ(b,c,d)·φ(a,bc,d)·φ(a,b,c) = φ(a,b,cd)·φ(ab,c,d)` — the δ²=0 check for the sign cocycle | 6, 8 | open, next |

Why these two first: without them, "handedness is a sign" stays analogy
and "flux is conserved because δ²=0" stays a picture. Both are finite
`decide`/`ring` computations over the 8-component split-octonion table,
following the pattern of `strut_weight_eq_four` and `pentagon_defect_bound`
(`foundations/Algebra.lean`). Item 1 confirms or refutes "the handedness is
one-dimensional"; item 2 confirms or refutes "flux conservation = δ²=0".

## 11.2 The closed ledger (what Part II rests on)

| # | Result | Where | Status |
|---|---|---|---|
| C2 | `dcStep` = geodesic (minimal rotation count) | `TamariMetric.dcStep_eq_geodesic` | **[P]** |
| C5 | `dcStep` is the maximal Bellman-consistent potential | `TamariMetric.dcStep_is_maximal_potential` | **[P]** |
| C3 | edge-Lipschitz + trust-Lipschitz | `weightedCost_edge_lipschitz`, `looseCost_linear_in_trust` | **[P]** |
| — | composition law `dcStep(Node l r) = dcStep l + dcStep r + rightSpine l` | `SubdivisionClosure` | **[P]** |
| — | Γ jump 2 → 19, unique | `gamma_increment`, `gamma_only_jump_at_cd2_3` | **[P]** |
| — | alternativity; associator antisymmetric | `left_alternative`, `right_alternative`, `associator_antisymm_left` | **[P]** |
| — | `strut_weight = 4` | `strut_weight_eq_four` | **[P]** |

## 11.3 The open ledger (the [H]s and [C]s)

| # | Problem | Chapter | Status |
|---|---|---|---|
| 3 | Right-spine/left-spine antipode duality (symmetrize the decomposition) | 7 | open |
| 4 | Flux conservation as a "divergence theorem" (total flux = boundary term) | 7, 6 | open |
| 5 | The **alternator strut**: a second Γ term at CD 4 (depolarization) | 5, 8 | open |
| 6 | The **limit shape**: empirical measure of transit coords → continuous limit | 9 | open, deferred |
| 7 | Invariant meaning of `rightSpine` (= interface flux?) | 7 | open |
| 8 | Anyon correspondence: `contracts_one` = F-move, vs a concrete fusion model | 6 | open |
| 9 | The timelike/spacelike ↔ axisymmetry/stellarator sketch | 1, 10 | open |

Each [H] carries its confirmation/refutation sentence in its chapter; the
discipline (front matter) requires that no new claim enters the primer without
a ledger row.

## 11.4 The formalization roadmap (draft)

1. Items 1–2 (immediate) — grounds Chapters 4 and 6.
2. Items 3–4 — grounds the interface chapter's "divergence theorem" and the
   antipode-dual picture.
3. Item 5 — decides whether CD 4 is a phase (the falsifiable gap of Chapter 5).
4. Item 8 — promotes the anyon reading from correspondence to theorem.
5. Item 6 — the continuum step; gated on everything above, since "flux" must
   be a theorem before its limit shape can be.
