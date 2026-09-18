# The Pentagonator claim, reviewed: Softmax as associator, Softplus as commutator

**Date:** Sep 16.

**Status:** review note (external-collaborator claims assessment, math + numerics).

## Scope

| Referent | Value |
|---|---|
| claim under review | `docs/diffusion-router-training-draft.md` §"Alternative B" (L146+) |
| theory source | `~/labware/llocollama/plans/GemFlash38-on_algebra.md` (associator half, developed) |
| new claim (this note's target) | "Softmax is an associator; **Softplus is a commutator**; one formula combines both" |
| code anchors | sglang `layers/attention/mamba/mamba.py` (dt_softplus), `kernels/ops/attention/fla/fused_gdn_gating.py`, `layers/n_gram_embedding.py` |
| session context | SpecForge `docs/sections/research/speculative-prefill-port-analysis.md` ("Scorer Directions" + PLE research program) |

## 0. Verdict at a glance

| Claim | Status |
|---|---|
| Softmax is the associator | **True, sharpened**: not "breaks" associativity — it is a nontrivial but pentagon-coherent associator of the LSE monoid (§2) |
| Softplus is the commutator | **Not literally** (§3 preamble: the commutator of the underlying op vanishes) — **exactly true in three defensible senses**, in increasing order of taste (§3 E1–E3) |
| "One formula combines both" | **True — in the centered log-Y form, verified (T2)**: `x' = LSE_β(0,x) − x_prev` closes at period 5 **exactly for all β** (exp-conjugacy to Zamolodchikov's A₂ Y-system) and in the tropical limit. ⚠️ The draft's *literal* `y' = y + log(1+eˣ)` never closes — Fibonacci divergence (φ). The algebra survives; the formula needs the minus term (§3 E2, §4, T2) |
| B.1 gate `sign(g)·[e^{β|g|} − 4·log(1+g²)]` | **Fails numerically** — jump at 0, unbounded attractor (§4). B.2/B.3's `φ = sign·softplus(β|·|)` **also jumps ±log 2 at 0** (softplus(0) = log 2 ≠ 0). Both are repairable without touching the algebra (§4 fixes) |

## 1. The one-paragraph algebra

Define the **log-sum-exp join** on ℝ:

```
x ⊕_β y := (1/β)·log(e^{βx} + e^{βy})          β>0,  β→∞ ⟶ max  (Maslov dequantization)
```

Facts, all elementary:
- `exp(β·(x⊕y)) = e^{βx}·e^{βy}` — **exp conjugates ⊕ to ×**, so ⊕ is **strictly commutative and strictly associative** (unit −∞). It is *the* smooth interpolation between `+` (β→0 after recentering) and `max` (β→∞).
- **Softmax = ∇LSE** (normalized); it is the *derivative/gauge* of the join.
- **Softplus = anchored join**: `log(1+eˣ) = LSE(0, x)` — merge with a *constant slot* (the "vacuum" term).
- `σ = softplus'` and σ(g) = softmax₂(0, g) — the 2-class softmax. Hence
  **SiLU(g) = g·softmax₂(0,g)**: stock GLU gating already sits at the softmax∧bag junction; the pentagonator family is its generalization, not a departure from it.

Everything in §2–§3 is a reading of these four lines.

## 2. The associator side (algebra doc) — correct, with precision upgrades

1. Linear attention parenthesizes freely (`(QK)V = Q(KV)`, operator products associative);
   softmax attention does not commute with contraction: `softmax(QKᵀ)V ≠ Q(KᵀV)`-side fold.
   Standard, correct.
2. **Sharpening:** the parenthesization defect is *exactly a gauge*, not a breakdown.
   FlashAttention's online rescale factors `exp(ℓ_old − ℓ_new)` (running-LSE increments) are
   **the explicit associator α**, and they satisfy the pentagon because ⊕ is exp-conjugate to
   strict addition. Attention is associativity-up-to-transport; the transport is 1-cocycle,
   closed under re-bracketing.
3. **Polytope bookkeeping (this matters for the claim's name):**
   - The **pentagon identity** lives on **K₄** (5 vertices = the 5 bracketings of 4 factors).
   - **K₅** (3-dim, 14 vertices) has pentagon *and square* 2-faces; the squares are exactly the
     cases where **two independent re-bracketing moves commute with each other** —
     commutativity *internal* to the associator structure. The draft's "on the associahedron K₅
     closes the 5-fold re-bracketing" is right one dimension too early: K₅'s *pentagon faces* do
     the 5-fold closure; its *square faces* are where commutation first appears.
   - Full associator↔commutator (braiding) coupling is the **hexagon axiom**, whose cells are
     facets of the **permutoassociahedron PA(4)** (Kapranov–Voevodsky). So: K₄ = pentagon,
     K₅ = squares, PA(4) = hexagon. The program's "one formula for both" is, in exact terms,
     a request for an element with **braided-monoid coherence** — and PA(4) is the polytope
     where the two coherence cells are glued. The instinct pointed at the correct object.

## 3. The commutator side — the literal claim fails; three exactings survive

**Literal form fails:** if softplus/⊕ *is* the commutator of something, that something would have
to fail to commute. But ⊕ is strictly commutative (§1). And the associative-monoid commutator
`[x⊕y] − [y⊕x] = 0` identically. So "Softplus is a commutator" needs an anchor. Three:

### E1 — Channel exacting (theorem-grade, and the one this repo needs)

*Softmax is the operator of the **associative read channel**; softplus is the gate of the
**commutative write channel**.*

- **Write/bag side (everything commutes):**
  - PLE/Engram/gram tables: context enters as **sums of looked-up vectors** — merge order of
    writes is meaningless; the structure is a multiset (bag).
  - Mamba-2 / GDN state: `S = Σᵢ γ^{t−i}·(kᵢ⊗vᵢ)` — the *sum* is commutative; time-order enters
    only through **scalar** decay products (commutative scalars). Associative-recall-by-bag.
  - And the write gates are **literally softplus**, verified in production code:
    `mamba.py:626,729,754 → dt_softplus=True` (Δ = softplus(dt_proj + dt_bias)),
    `fused_gdn_gating.py: g = −exp(A_log)·softplus(a + dt_bias); β_out = sigmoid(b)`.
    Softplus is the *positivity gate on bag writes*.
- **Read/chain side (parenthesization matters):** attention operator products
  `(QK)V ≠ Q(KV)`-fold; the read is a non-commutative composition, softmax is its gauge.
  The algebra doc's "linear/SSM vertex Q(KV): summary memory" **is** the commutative bag seen
  from the chain side; its "softmax vertex (QK)V" is the associative read.

So the draft's φ(s)=sign·softplus(β|s|) on *routing similarity* and the softplus-gated writes in
Lightning/qwen4exp are the same mathematical animal: joins anchored on a constant — the merge
algebra of a bag. "Softplus = commutator" reads correctly as "**softplus = the algebra of the
commutative channel**". E1 alone retro-grounds this session: **prefill token-dropping is a bag
edit (safe: sums ignore which term is absent) and a chain edit (destructive: order-preserving
reads are why SpecPrefill §3.2.4 calls position restoration "crucially essential")**. The 2-gram =
edge-bag / 3-gram = composition-pinning result (see port-analysis §PLE) is the same split one
level below.

### E2 — Cluster/TBA exacting (theorem-grade)

Two forms must be distinguished — the review's central numerical finding:

1. **Draft-literal:** `x_{t+1} = x_t + log(1+e^{x_{t−1}})`. For large x, `log(1+eˣ) ≈ x`, so the
   recurrence approaches `x_{t+1} ≈ x_t + x_{t−1}` — **Fibonacci: golden-ratio divergence**
   (verified: ratios 1.605 → 1.619 by step 8; never closes). As written, the draft's "closes the
   5-fold re-bracketing" claim is **false for this map**.
2. **Centered log-Y form (the correction):** taking the Y-system `Y_{t+1}Y_{t−1} = 1 + Y_t` in log
   coordinates `x = log Y`:

   ```
   x_{t+1} = log(1 + e^{x_t}) − x_{t−1}        (equivalently  x_{t+1} + x_{t−1} = softplus(x_t))
   ```

   **closes at period 5 identically in β** for the whole family
   `x_{t+1} = β⁻¹log(1+e^{βx_t}) − x_{t−1} = LSE_β(0, x_t) − x_{t−1}` — because `X = e^{βx}`
   conjugates every β back to the same exact Y-system — and likewise in the tropical limit
   `β→∞`: `max(0,x_t) − x_{t−1}` (all verified, T2).

This is **stronger than the draft claimed**: no β-tuning trades off closure — the pentagon holds
*throughout* the max↔mean interpolation. The softplus is doing exactly what Zamolodchikov's
Y-systems and the TBA (`log Y = ε + K ∗ log(1+e^Y)` — softplus is the interaction kernel of
integrable quantum statistical mechanics) do with it: it is the join that the *second-difference*
structure closes periodically. Mutation sequences remain the standard example of non-commuting
operations assembled from commutative joins (braid = "how far from commuting," exact).
In this corrected sense the one formula really does combine associativity structure (5-cycle
pentagon, β-invariant) with commutativity failure (braid): **E2 is the rigorous content of the
pentagonator's name, and it is now machine-verified rather than hoped (§6 T2).**

**Noncommutative coefficients: alternativity does NOT rescue closure (numerical test, this
session).** Transporting `T(X,Y) = (Y, (1+Y)/X)` (right division, quaternion inverse `q̄/|q|²`) to
generic quaternion seeds: period-5 closure **fails hard** — residuals `|x₅−X|, |x₆−Y|` = O(1–4) on
5/5 random seeds. Quaternions are fully *associative*, hence trivially *alternative*, so this is
not an associativity gap: **Artin's theorem** (2-generated subalgebras associate — which does keep
every Y-orbit step inside the associative `⟨x_{t−1}, x_t⟩`) cannot help, because the Zamolodchikov
reduction also *reorders* factors (`ab → ba`). **Closure requires commutativity, not merely
alternativity.** Consequences for the octonion-coefficient pentagonator program
(`foundations/Algebra.lean`, `Cost.lean`):
(i) naive transport breaks at the quaternion tier already — before octonion non-associativity even
enters; seeds must be restricted to **commutative subalgebras** for closure to hold fiberwise;
(ii) the structurally right generalization is **q-commutative Y-systems** (Inoue–Kuniba–Suzuki
quantum Y-systems; quantum dilogarithms), where variables commute up to a scalar and periodicity
survives deformed — a natural home for the Z₂-graded `antipode`/sign-cocycle machinery already in
`Algebra.lean`;
(iii) the theory now demands a **commutator defect** dual to `pentagon_defect` (associator
measure): a complete pentagonator algebra must bound *both* defects, and (iii) is exactly the
sense in which the review's answer to "are we missing alternativity?" is: **the formalization
over ℝ is complete; the octonion program was missing not alternativity but commutativity — and
alternativity turns out to be the wrong lever.**

### E3 — Statistics exacting (suggestive; testable, unproven)

`log(1+eˣ)` **is** the grand-canonical free energy of a **single two-state fermionic mode**
(the "1+" is Pauli exclusion — a graded Fock-space trace), while `log Σᵢ e^{xᵢ}` (LSE/softmax) is
the **bosonic** many-state partition function. Fermions are the *anti*-commuting objects; a
sign-twisted (odd) gate is graded algebra by construction. So:
**bosonic/braided composition ↔ associator side (softmax/LSE); fermionic/exclusion join ↔
commutator side (softplus)**, and the pentagonator gate `sign(g)·[…]` keeps the fermionic parity
literally. Status: physics-adjacent rhetoric *unless* pinned by a measurable (T4) — the draft's
±iωt phase-conjugate counterflow (B.2) and odd-sign gates are, however, structurally at home
here. Do not cite E3 as proof; cite it as the reason the claim might be true.

## 4. Numerical review of Alternative B (this kills the run at step ~0, not at convergence)

| Site | Defect | Fix (algebra-preserving) |
|---|---|---|
| B.1 `gate' = sign(g)·[e^{β|g|} − 4log(1+g²)]` | **Jump at 0**: g→0⁺ gives `e⁰ − 0 = 1` while sign(0)·(·) = 0 — a ±1 discontinuity exactly where router logits init | see centering below |
| same | **Unbounded attractor**: with *learnable* β, `e^{β|g|}` runs away (CE loss locally rewards sharper attractors); the −4log(1+g²) barrier is logarithmic — it cannot tame an exponential. Multiplying expert outputs ⇒ blowup | saturate: `sign(g)·(1 − e^{−(s(β|g|)−s(0))})` ∈ (−1,1), or keep the attractor in the **log domain** (score = LSE of energies — softmax *already is* this, never exp the raw gate) |
| B.2/B.3 `φ(s) = sign(s)·softplus(β|s|)` | **Also jumps**: softplus(0) = log 2 ⇒ φ: −0.693 → +0.693 across 0 | **center it**: `φ̃ = sign(s)·(softplus(β|s|) − log 2)` — C¹ at 0 (near 0: φ̃ ≈ βs/2), same tail, same parity. General rule: every member of the family must vanish at the anchor: `s(x) − s(0) ≥ 0` |
| "mutation closes the 5-fold re-bracketing" (`y' = y + log(1+eˣ)`) | **Diverges at φ** as literally written (Fibonacci regime; verified) | use the **centered log-Y form** `x' = LSE_β(0, x_prev) − x_old` — exact period-5 closure for all β (E2/T2); the centering rule applies here too |
| β learnable, unclamped | overflow in bf16/fp8 paths (e^{0.4·88} ≈ 6.6e7 vs fp8-max 448 on quantized legs) | parameterize `β̂ = clamp(softplus(β), ≤βmax)`; compute fused-stable exactly as the shipped kernel already does (`fused_gdn_gating.py: where(βx ≤ 20, β⁻¹log(1+e^{βx}), x)`) — threshold 20 is the precedent |
| training protocol | draft's warmup note is right but incomplete | log `max|gate|` from step 0; LR-warm β; run A→B swap (already proposed there) with the *centered, saturated* gate so A/B deltas measure the algebra, not the blowup |

## 5. The spine: one split, four levels

| Level | bag / commutative (write, softplus-gated) | chain / associative (read, softmax-gauged) |
|---|---|---|
| activation | softplus = LSE(0,x), σ = 2-softmax | softmax = ∇LSE; attention bracketing |
| memory | PLE/Engram table sums; Mamba/GDN Hebbian Σ | attention over past states; (QK)V operator products |
| token structure | 2-gram edge-bag (multiset of transitions) | 3-gram path-pinning (which edges compose; de Bruijn–Eulerian order) |
| prefill editing | **dropping terms is safe** (bag sum) — this is SpecPrefill's entire win | **order/positions must be preserved** — this is SpecPrefill §3.2.4; and why the delta-table write path (port-analysis §Research program) is "commutative writes, no chain edit" |

The pentagonator is what this table *demands of a gate*: read-side selection is a softmax gauge;
write-side commitment is a centered softplus join; one formula spanning both is a
braided-monoid object (PA(4) coherence) — which is why K₅/PA(4) naming is the right ambition.

## 6. Falsifiable tests (cheap → mid)

- **T1 (zero training):** fp32/bf16 gradient audit of `gate'` and `φ̃` at |g| ∈ [0, 2⁻⁸] — the
  jump/centering effects at init scale.
- **T2 (machine-checked in Lean):** formalized in
  `~/labware/LaserCortex/LaserCortex/ConditionalMemory/YSystem.lean` (compiles via `lake build`;
  commits `e97eaee`, `795b8e9`). Axiom audit: `T_period5`, `S_beta_period5`,
  `draft_no_period5` depend only on `propext, Classical.choice, Quot.sound` — no `sorry`;
  the two quaternion certificates use `native_decide` (compiler-trust axiom, flagged in the
  file header). Contents:
  `T_period5` (A₂ closure — **generalized to any linearly ordered field**: this pinned
  Mathlib has retired the bundled `LinearOrderedField` class for decomposed binders
  `[Field α] [LinearOrder α] [IsStrictOrderedRing α]`), `S_beta_period5` (**centered log-Y
  pentagonator map is 5-periodic for every β ≠ 0 and every real seed** — β-invariance is a
  theorem via the `E_β = exp(β·)` conjugacy, not a sweep), `draft_no_period5` (the draft-literal
  map provably fails closure at seed (1,1); full φ-divergence rate not formalized),
  `quaternion_no_period5` + `quaternion_commute_closes` (see quaternion row below).

  | map | behavior |
  |---|---|
  | exact Y `Y' = (1+Y)/Y_prev`, seed (1,1) | `1,1,2,3,2 → 1,1` — closes, period 5 ✓ **(Lean)** |
  | centered log-Y `x' = LSE_β(0,x) − x_prev`, all β ≠ 0, all real seeds | closes, period 5 ✓ **(Lean theorem)** |
  | same, tropical β→∞ (`max(0,·)`): seed (1,1) | `1,1,0,−1,0 → 1,1` ✓ (numeric; piecewise, not formalized) |
  | **draft-literal** `x' = x_prev + softplus(x_old)` | 1,1,2.31,3.63,6.03,… ratios → φ = 1.618 — **never closes** ✓ (Lean: seed-(1,1) witness; numeric: rate) |
  | **quaternion** seeds, right division | **fails to close**: seed (1+i, 1+j) → i-component 42/55 ≠ 1 ✓ **(Lean, `quaternion_no_period5`)**; commuting ℂᵢ-plane seeds **close** ✓ **(Lean, `quaternion_commute_closes`)** — commutativity, not alternativity, is the live condition |

  Explanation: `X = e^{βx}` conjugates the centered family to the *same* Y-system for every β
  (closure is β-invariant by construction); the draft-literal form is a different map entirely
  (linear regime ⇒ Fibonacci). **Remaining open work**: the *genuine* q-deformation
  (quantum-dilogarithm `[n]_q` coefficients — is closure preserved off the exp-conjugacy
  one-parameter family? — the quaternion test says plain non-commutativity breaks it, so the
  q-commutative route is the only surviving graded generalization) and per-layer/head β
  assignment, which the conjugacy does not cover.
- **T3 (architecture, from the algebra doc):** MQAR on the 150M tree-associator testbed,
  bag-vs-chain ablation: kill the commutative channel (gram/table) → long-range membership recall
  collapses; kill the associative read (softmax cells) → verbatim/order tasks collapse.
  This tests the §5 table as a *mechanistic* claim, not just a taxonomy.
- **T4 (statistics probe, E3):** paired training runs, odd-centered vs even same-shape gates;
  E3 predicts parity-sign structure matters beyond the centering fix (§4). If no delta, E3 is
  rhetoric and E1+E2 stand alone — publishable either way.

## 7. References

- arXiv:2502.02789 (SpecPrefill, §3.2.4 position restoration) · 2601.07372 (Engram, DeepSeek) ·
  2504.03624 (Nemotron-H ngram hypothesis) · 2403.12968 (LLMLingua-2) · 2501.00663 (Titans) ·
  2412.06769 (Coconut) · 2304.08467 (Gisting)
- Zamolodchikov 1991 (Y-systems, TBA periodicity); Fomin–Zelevinsky 2002–3 (cluster algebras);
  **Inoue–Kuniba–Suzuki** (quantum Y-systems / q-commutative periodicity); Stasheff associahedra
  (Kₙ; pentagon = K₄); Mac Lane coherence; Kapranov–Voevodsky PA(4); Artin (alternative algebras);
  Ramsauer et al. 2020 (Hopfield attention).
- Code: sglang `mamba.py:626,729,754`; `fla/fused_gdn_gating.py:8–9,30–32`;
  `layers/n_gram_embedding.py` (orders {2,3}×8 heads); SpecForge research docs
  `speculative-prefill-port-analysis.md` (Scorer Directions; PLE substrate; Research program).
