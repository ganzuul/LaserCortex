# Chapter 11 — Open problems and the formalization ledger

*Every [H] and [C] in the primer is listed here with its confirmation /
refutation sentence. Order = the order we intend to work them.*

## 11.1 Immediate (next formalization steps)

| # | Problem | Chapter | Status |
| --- | --- | --- | --- |
| 1 | **Imaginary-part property**: the associator `[a,b,c]` has vanishing e₀ component (purely imaginary) — the reduction of the flux to a sign | 4, 6 | **[P]** `associator_e0_vanishes` (`foundations/Algebra.lean`) |
| 2 | **Pentagon cocycle identity**: `φ(b,c,d)·φ(a,bc,d)·φ(a,b,c) = φ(a,b,cd)·φ(ab,c,d)` — the δ²=0 check for the sign cocycle | 6, 8 | **[P]** on basis elements: `pentagon_cocycle_basis`, `native_decide` over 8⁴ = 4096 quadruples (general-element case not claimed) |
| 3 | **Associator spectrum on the basis**: histogram of `\|[eᵢ,eⱼ,eₖ]\|` over all 8³ = 512 ordered basis triples (lab note 056 §4, hypothesis-2 test) — do weights 1,2,3 have a basis realization? | 4, 8 | **[P]** `strut_quantized_on_basis`: histogram = {0 ↦ 344, 4 ↦ 168}; **no** triple realizes 1, 2, or 3 — the strut is quantized on the basis |

Why these were first: without them, "handedness is a sign" stayed analogy
and "flux is conserved because δ²=0" stayed a picture. All three were finite
`decide`/`ring`/`native_decide` computations over the 8-component
split-octonion table, following the pattern of `strut_weight_eq_four` and
`pentagon_defect_bound` (`foundations/Algebra.lean`). Item 1 confirmed "the
handedness is one-dimensional"; item 2 confirmed "flux conservation = δ²=0"
on the basis; item 3 refuted hypothesis 2 of lab note 056 (1,2,3 as basis
associator magnitudes) and left hypothesis 1 — c = 1,2,3 as intermediate
Rees fibres of the chirplet *operator*, not as basis magnitudes — as the
live reading. The 168 nonzero triples are the 28 non-associative imaginary
triples in six orderings each (`assocBasis_sign_split`: Q44 norm −4 on 96,
+4 on 72); `assocBasis_nonzero_null_free` shows no nonzero basis associator
lies on the (4,4) null cone, so |Q44 norm| is a faithful magnitude here.

Consequence for the record: `HyperbolicChirplet.lean` still carries its
`[C]` header ("until 11.1.1 … and 11.1.2 …") — that gate has now passed
and the header/`chirpRate` stub should be revisited. Note also
`strut_weight = (-·).toNat` is sign-sensitive: it reads 0 on a time-like
associator (+4); the distinguished fibre (e₁,e₂,e₄) has norm −4.

## 11.2 The closed ledger (what Part II rests on)

| # | Result | Where | Status |
| --- | --- | --- | --- |
| C2 | `dcStep` = geodesic (minimal rotation count) | `TamariMetric.dcStep_eq_geodesic` | **[P]** |
| C5 | `dcStep` is the maximal Bellman-consistent potential | `TamariMetric.dcStep_is_maximal_potential` | **[P]** |
| C3 | edge-Lipschitz + trust-Lipschitz | `weightedCost_edge_lipschitz`, `looseCost_linear_in_trust` | **[P]** |
| — | composition law `dcStep(Node l r) = dcStep l + dcStep r + rightSpine l` | `SubdivisionClosure` | **[P]** |
| — | Γ jump 2 → 19, unique | `gamma_increment`, `gamma_only_jump_at_cd2_3` | **[P]** |
| — | alternativity; associator antisymmetric | `left_alternative`, `right_alternative`, `associator_antisymm_left` | **[P]** |
| — | `strut_weight = 4` | `strut_weight_eq_four` | **[P]** |
| — | discrete div∘curl certificate (closure free for ψ-form fields, any grid, any `AddCommGroup` values) | `Stencil.dx_dy`, `Stencil.div_curl_eq_zero`, `div_curl` | **[P]** |
| — | zero-divisor cone: for nonzero lattice elements, zero divisor ⟺ Q₄₄-null; the unit is never a zero divisor; conjugate cancellation (alternativity at work) | `isZeroDivisor_iff_octonion_norm_eq_zero`, `not_isZeroDivisor_split_one`, `conj_mul_assoc_left` | **[P]** (note 060) |
| 11.1.1 | imaginary-part property: associator e₀ component vanishes | `associator_e0_vanishes` | **[P]** |
| 11.1.2 | pentagon cocycle identity on basis elements (δ²=0 for the sign cocycle) | `pentagon_cocycle_basis` | **[P]** |
| 11.1.3 | strut quantization: basis associator spectrum is {0, 4}; 1,2,3 un-realized; null-cone free | `strut_quantized_on_basis`, `assocBasis_norm_eq_zero_or_four`, `assocBasis_nonzero_null_free`, `assocBasis_sign_split` | **[P]** |

## 11.3 The open ledger (the [H]s and [C]s)

| # | Problem | Chapter | Status |
| --- | --- | --- | --- |
| 3 | Right-spine/left-spine antipode duality (symmetrize the decomposition) | 7 | open |
| 4 | Flux conservation as a "divergence theorem" (total flux = boundary term) | 7, 6 | open — discrete closure half now **[P]** (§6.5 / `Stencil.lean`); the continuum/divergence-theorem reading remains |
| 5 | The **alternator strut**: a second Γ term at CD 4 (depolarization) | 5, 8 | open |
| 6 | The **limit shape**: empirical measure of transit coords → continuous limit | 9 | open, deferred |
| 7 | Invariant meaning of `rightSpine` (= interface flux?) | 7 | open |
| 7a | **Bracketing coherence for general n** (lab notes 058, F2; 059 §0): any two bracketings of an n-fold product differ by a `signCocycle`-governed factor, pentagon-consistently | 4, 6, 8 | **[P] on the basis skeleton** — `Coherence.basisWord_eq_or_neg` (all n, sign only), `Coherence.rotBridge` (edge sign = φ), `Coherence.pentagonLoop` (K₄ face at value level). The literal arbitrary-elements reading is **false** (vectorial associator); the true general-n statement over arbitrary elements is Artin — row 7b |
| 7b | **Artin's theorem for the split octonions** (058 F2c): the subalgebra generated by any two elements is associative — equivalently, every word in `{a, b}` brackets identically. Needs only the bilinearity plumbing (`mul_add`, `add_mul` for `split_oct_mul`, each `ext; simp; ring`) plus word induction over the [P] alternativity/antisymmetry facts | 4, 6 | open, next |
| 8 | Anyon correspondence: `contracts_one` = F-move, vs a concrete fusion model | 6 | open |
| 9 | The timelike/spacelike ↔ axisymmetry/stellarator sketch | 1, 10 | open |

Each [H] carries its confirmation/refutation sentence in its chapter; the
discipline (front matter) requires that no new claim enters the primer without
a ledger row.

## 11.4 The formalization roadmap (draft)

1. Items 1–2 (immediate) — grounds Chapters 4 and 6. *Done, along with
   item 3 (basis spectrum / strut quantization), the F1 stencil
   certificate (`Stencil.lean`, closure-exactness of the ψ-form), and F2
   on the basis skeleton (§11.3, row 7a — with the arbitrary-elements
   reading refuted and Artin logged as 7b).*
   Next immediate step: revisit the `HyperbolicChirplet` `[C]` gate and
   the `chirpRate` stub, now that 11.1.1/11.1.2 hold.
2. Items 3–4 — grounds the interface chapter's "divergence theorem" and the
   antipode-dual picture.
3. Item 5 — decides whether CD 4 is a phase (the falsifiable gap of Chapter 5).
4. Item 8 — promotes the anyon reading from correspondence to theorem.
   *Partly advanced by F2: `Coherence.rotBridge` proves the single-edge
   case — `contracts_one` transport on the skeleton equals the
   `signCocycle` F-symbol — but the concrete fusion model (all n, with
   unit/counit data) remains open.*
5. Item 6 — the continuum step; gated on everything above, since "flux" must
   be a theorem before its limit shape can be.
