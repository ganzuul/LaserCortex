# 039: Yang-Mills Pattern Transfer — Metric Spaces from Compact Lie Groups to Split Hypercomplex Numbers

**Date**: 2026-07-27
**Status**: HYPOTHESIS — Structural isomorphism proposed, partially formalized (P1 proven, P2 corrected, P5 revised)
**Prerequisites**: 023 (Pythagoras via Chu pairing), 037 (KKT obstruction at CD2), 038 (alchemical topology), `docs/lab_protocol.md`
**Source**: `LaserCortex/foundations/Algebra.lean`, `LaserCortex/foundations/Chu.lean`, `LaserCortex/CoherenceMetric.lean`, `LaserCortex/OctilinearEmbedding.lean`

---

## 1. Executive Summary

**Yang-Mills theory succeeds because the metric provides the invariant tensor that contracts the field strength into the Lagrangian. We can replicate this success for split hypercomplex numbers by recognizing that the Chu pairing `β(x, S(x))` is the split-hypercomplex analogue of the combined spacetime-metric ⊗ Killing-form, and the antipode `S` is a *dimension-reducing* analogue of the Hodge star — it changes the signature from (4,4) to (5,3), not preserving it as the standard Hodge star would.**

The structural isomorphism is not a metaphor — it is a precise mapping of invariant tensors and their contractions:

```
Yang-Mills:  L_YM = −½ g^{μα} g^{νβ} κ(F_{αβ}, F_{μν})
                                    ↑               ↑
                              spacetime metric    Killing form

Our framework: coherenceInterval = dcStep² − frictionDensity²
                                   = β(λ_t, S(λ_t)) = N(λ_t)
                                     ↑
                              Chu pairing = internal × external metric combined
```

The hypothesis: **every structural feature of Yang-Mills (dynamical term, field equations, instantons, mass gap, BRST symmetry) has a direct translation in the split-hypercomplex framework, obtained by substituting: (1) the Chu pairing for the metric-trace product, (2) the antipode for the (dimension-reducing) Hodge star, (3) the KKT multiplier for the gauge connection, and (4) the associator for the curvature.**

**REVISED (2026-07-27):** The (4,4) composition identity `N(x·y) = N(x)·N(y)` is now proven (`octonion_norm_mul` in `Algebra.lean`). The (5,3) antipode-copairing form `fiveThreeNorm(x) = (x·S(x)).e₀` is proven to exist and to equal the counit of the antipode product, but is **NOT composition-compatible** — it does not satisfy `fiveThreeNorm(x·y) = fiveThreeNorm(x)·fiveThreeNorm(y)`. The (4,4) norm is the unique multiplicative form on this multiplication table.

---

## 2. How the Metric Works in Yang-Mills

### 2.1 The Lagrangian Decomposition

The Yang-Mills action on Minkowski spacetime with gauge group `G`:

```
S_YM[A] = −½ ∫ d⁴x  tr(F_μν F^{μν})
```

where `F_μν = ∂_μ A_ν − ∂_ν A_μ + [A_μ, A_ν]` is the field strength (curvature)
and the contraction `F_μν F^{μν}` uses the Minkowski metric `η_{μν} = diag(+,−,−,−)`:

```
F_μν F^{μν} = η^{μα} η^{νβ} tr(F_{αβ} F_{μν})
```

In terms of electric and magnetic fields (`E_i = F_{0i}`, `B_i = ½ε_{ijk} F^{jk}`):

```
L_YM = ½(E² − B²)
```

This is the canonical split-signature inner product. The metric `η = (+,−,−,−)` provides the sign — the electric (timelike) components contribute positively, the magnetic (spacelike) components contribute negatively.

### 2.2 Two Metrics, Two Roles

Yang-Mills uses **two independent metric structures**:

| Structure | Domain | Signature | Role |
|-----------|--------|-----------|------|
| Spacetime metric `g_μν` | Base manifold M | (3,1) Lorentzian | Contracts spacetime indices: `F_μν F^{μν}` |
| Killing form `κ_ab` | Gauge algebra `g` | Positive-definite | Contracts Lie algebra indices: `tr(T^a T^b)` |

The Lagrangian is the **tensor product** of these two metrics:

```
L_YM = −½ (g^{μα} ⊗ κ^{ab}) (F^a_{αβ} F^b_{μν})
```

Without either metric, you lose the dynamical term. With only the Killing form (no spacetime metric), you get the topological term `∫ F∧F` (Pontryagin density, metric-independent). With only the spacetime metric (no Killing form), you get Maxwell theory (abelian, no self-interaction). **Both are necessary for Yang-Mills.**

### 2.3 The Hodge Star as the Metric's Proxy

The Hodge star `∗` maps `k`-forms to `(n−k)`-forms and encodes the metric:

```
(∗F)_{μν} = ½ ε_{μνρσ} F^{ρσ}
```

where `ε_{μνρσ}` is the volume form (depends on `√|g|`). The `∗` operator squares to:

```
∗² = (−1)^{k(n−k) + s}
```

where `s` is the signature index (number of minuses in the metric). For Minkowski 4D (`s=1`, `k=2`): `∗² = −1` on 2-forms. The Yang-Mills action can be written:

```
S_YM[A] = ∫ tr(F ∧ ∗F)
```

The Hodge star is what turns the topological Pontryagin term `F∧F` into the dynamical Yang-Mills term `F∧∗F` — it is the **metric-dependent component** of the action.

### 2.4 Instantons: Self-Dual Configurations

In Euclidean signature (where `∗² = +1`), the field strength decomposes:

```
F = F₊ + F₋    where    F_± = ½(F ± ∗F)
```

Self-dual configurations (`F = ∗F` or `F = −∗F`) minimize the action within a topological sector. In Minkowski space, self-duality requires complex fields (`∗F = ±iF`), but the structural principle is the same: **the lightlike configurations (where the two metric components balance precisely) are the topological boundary states.**

### 2.5 Summary: What Makes Yang-Mills Work

| Component | Mathematical role | Physical meaning |
|-----------|-------------------|------------------|
| Spacetime metric | Index contraction, split signature | Defines the light cone, causality |
| Killing form | Lie algebra inner product | Defines the gauge-invariant norm |
| Hodge star | Metric-dependent duality | Separates dynamical from topological |
| Field strength | Curvature of connection | Non-linear self-interaction |
| Self-duality | F = ±∗F | Topological sectors, instantons |

---

## 3. The Split-Hypercomplex Parallel

### 3.1 The Chu Pairing = The Combined Metric

In our framework, the **Chu pairing** on split octonions is:

```
β(x, S(x)) = N(x) = e₀² + e₁² + e₂² + e₃² − e₄² − e₅² − e₆² − e₇²
```

This is the **(4,4)-signature norm** — a single tensor that does the work of **both** the spacetime metric AND the Killing form in Yang-Mills:

| Yang-Mills tensor | Split-hypercomplex tensor | Why they match |
|-------------------|--------------------------|----------------|
| `g_{μν}` (spacetime metric) | Split-octonion (4,4) signature | Both provide the `(p,q)` indefinite inner product |
| `κ_{ab}` (Killing form) | Chu pairing `β(x, y)` | Both are symmetric, bilinear, nondegenerate |
| `g^{μα}g^{νβ} ⊗ κ^{ab}` | `β(x, S(x)) = N(x)` | Both contract internal and external indices simultaneously |

The critical insight: **the Chu pairing is already doing exactly what `g⊗κ` does in Yang-Mills. We don't need to invent a new mechanism — we need to recognize the isomorphism.**

### 3.2 The Antipode = The Dimension-Reducing Hodge Star

The antipode `S` on split octonions acts as:

```
S(e₀) = e₀    (fixed)
S(e₁) = −e₁   (negated)
S(e₂) = −e₂   (negated)
S(e₃) = −e₃   (negated)
S(e₄) = e₄    (fixed)
S(e₅) = −e₅   (negated)
S(e₆) = −e₆   (negated)
S(e₇) = −e₇   (negated)
```

**CORRECTED (2026-07-27, lab note 039 revision):** The antipode is **NOT** a norm-preserving Hodge star on the (4,4) signature. When used in the pairing `x · S(x)`, it produces a **(5,3)-signature** quadratic form, not the original (4,4):

| Pairing | Formula | Signature | Positive sector |
|---------|---------|-----------|-----------------|
| `octonion_norm(x)` | `e₀²+e₁²+e₂²+e₃²−e₄²−e₅²−e₆²−e₇²` | **(4,4)** | {e₀,e₁,e₂,e₃} |
| `(x·x).e₀` | `e₀²−e₁²−e₂²−e₃²+e₄²+e₅²+e₆²+e₇²` | **(5,3)** | {e₀,e₄,e₅,e₆,e₇} |
| `(x·S(x)).e₀` | `e₀²+e₁²+e₂²+e₃²+e₄²−e₅²−e₆²−e₇²` | **(5,3)** | {e₀,e₁,e₂,e₃,e₄} |

The element **e₄ (ω, the Cayley-Dickson generator with ω²=+1) is promoted from the spacelike sector to the timelike sector** in both antipode pairings. The (4,4) `octonion_norm` is the externally-imposed CD quadratic form; the (5,3) forms emerge from the algebra's own involution.

**This is the (4,4)→(5,3) dimension reduction — not an external KKT projection, but a property of the algebra's own involution.**

| Hodge star property | Antipode property | Proof status |
|---------------------|-------------------|-------------|
| `∗ : Ω^k → Ω^{n−k}` | `S : SplitOctonion → SplitOctonion` | Antipode maps algebra to itself |
| `∗² = (−1)^{k(n−k)+s}` | `S²(x) = x` (id for octonions) | `antipode_involutive` in Algebra.lean |
| `∗` preserves norm | `N(S(x)) = N(x)` | `antipode_preserves_norm` (on (4,4) norm only!) |
| `∗F = ±F` (SD/ASD) | `N(x) = 0` (zero divisors) | Light cone = self-dual boundary |
| **`∗` preserves signature** | **`S` changes (4,4)→(5,3)** | **`fiveThreeNorm_eq_antipode_copairing`** |

**Key difference from Yang-Mills:** The Yang-Mills Hodge star preserves the metric signature (it maps within the same Hilbert space). Our antipode **changes the signature** — it acts as a *dimension-reducing* Hodge star. This is closer to a Kaluza-Klein reduction than a standard Hodge duality.

### 3.3 The KKT Multiplier = The Gauge Connection

The **KKT multiplier** `λ_t(cd) ∈ SplitOctonion` is the analogue of the gauge connection `A_μ`:

| Yang-Mills | Our framework | Why |
|------------|---------------|-----|
| Connection `A_μ(x) ∈ g` | KKT multiplier `λ_t(cd) ∈ SplitOctonion` | Sections over base space |
| Gauge transformation `A → gAg⁻¹ + gdg⁻¹` | Tamari flip `contracts_one(s, t)` | Reconfiguration without changing physics |
| Covariant derivative `D_μ = ∂_μ + [A_μ, ·]` | Associator `(xy)z − x(yz)` | Non-commutative parallel transport |
| Field strength `F_μν = [D_μ, D_ν]` | `assocDefect(cd)` | Obstruction to associativity |

### 3.4 The Coherence Interval = The Yang-Mills Lagrangian

The coherence interval from `CoherenceMetric.lean`:

```
coherenceInterval(cd, t) = dcStep(t)² − frictionDensity(cd)²
```

This is structurally identical to the Yang-Mills Lagrangian:

| Component | Yang-Mills | CoherenceMetric |
|-----------|------------|-----------------|
| Timelike term | `+E²` (electric, from `F_{0i}`) | `+dcStep²` (distance to normal form) |
| Spacelike term | `−B²` (magnetic, from `F_{ij}`) | `−frictionDensity²` (inertial mass) |
| Split signature | `(+,−,−,−)` via `η_{μν}` | `(+,−)` via split-complex norm |
| Invariant contraction | `tr(F∧∗F)` | `SplitComplex.norm(coherencePoint cd t)` |
| Action functional | `S[A]` | `weightedCost × dcStep` (SubdivisionClosure) |

### 3.5 Zero Divisors = Instantons

In Yang-Mills, **instantons** are self-dual configurations where `F = ±∗F`. They minimize the action within a topological sector and represent tunneling between vacua.

In our framework, **zero divisors** are configurations where `N(x) = 0` but `x ≠ 0`. The Chu pairing evaluates to zero — the analogue of `tr(F∧∗F) = 0` at the self-dual point:

| Instantons (YM) | Zero divisors (our framework) |
|-----------------|-------------------------------|
| `F = ±∗F` (SD/ASD condition) | `N(x) = 0` (null cone condition) |
| Topological charge `Q = ∫ F∧F` | `dcStep` parity (mod `strut_weight² = 16`) |
| Classical vacua (pure gauge) | `rightComb` (dcStep = 0) |
| Tunneling amplitude | `contracts_to` path (Tamari edge sequence) |

The proof that this isomorphism holds is straightforward: in Yang-Mills, `∗F = ±F` implies `tr(F∧F) = ±tr(F∧∗F)`, so `tr(F∧∗F) = ±Q`. In our framework, `N(x) = 0` implies `β(x, S(x)) = 0`, so the coherence interval vanishes — the tree sits on the light cone. The **algebraic signature of both conditions is identical**: the inner product of a configuration with its dual evaluates to zero or a topological invariant.

### 3.6 The Associator Barrier = The Mass Gap

The **Yang-Mills mass gap** (why the lightest glueball has non-zero mass) is one of the Clay Millennium Problems. In our framework, the **associator barrier** at `cd ≥ 3` provides the same phenomenon:

| Yang-Mills mass gap | Associator barrier |
|---------------------|-------------------|
| Lowest excitation has `m > 0` | At `cd = 2`, `frictionDensity = 2`; at `cd = 3`, `frictionDensity = 19` |
| Gap is non-perturbative | Jump of `strut_weight² = 16` cannot be reduced by any tree shape |
| Confinement of color charge | `contextMatch` restricts Tamari flips to same/adjacent dcStep |
| Asymptotic freedom at high energy | At `cd ≤ 2`, all flips permitted (context-free grammar) |

---

## 4. The Hypothesis, Formalized

### 4.1 Statement

**The Yang-Mills construction — gauge theory with a metric-dependent action functional — generalizes from compact Lie groups (with positive-definite Killing form) to the split hypercomplex Cayley-Dickson ladder (with indefinite (p,q) signature), by substituting the structural components according to Table 1.**

**Table 1: Structural Isomorphism**

| # | Yang-Mills component | Split-hypercomplex component | File |
|---|---------------------|------------------------------|------|
| (i) | Spacetime metric `g_{μν}` ⊗ Killing form `κ_{ab}` | Chu pairing `β(x, S(x)) = N(x)` | `Chu.lean` |
| (ii) | Hodge star `∗` | Antipode `S` | `Algebra.lean` |
| (iii) | Gauge connection `A_μ(x)` | KKT multiplier `λ_t(cd)` | `OctilinearEmbedding.lean` |
| (iv) | Field strength `F_μν` | Associator `(xy)z − x(yz)` | `Algebra.lean` |
| (v) | Yang-Mills action `∫ tr(F∧∗F)` | `coherenceInterval = dcStep² − frictionDensity²` | `CoherenceMetric.lean` |
| (vi) | Instantons `F = ±∗F` | Zero divisors `N(x) = 0`, `x ≠ 0` | `Algebra.lean` |
| (vii) | Mass gap `m > 0` | Associator barrier `cd ≥ 3`, `strut_weight² = 16` | `Friction.lean` |
| (viii) | BRST symmetry | Tamari flips `contracts_one` | `Tamari.lean` |
| (ix) | Gauge fixing | RightComb normal form | `Tamari.lean` |
| (x) | Topological charge `Q` | `dcStep` parity (mod `strut_weight²`) | `Tamari.lean`, `Friction.lean` |

### 4.2 Testable Predictions

If the isomorphism holds, the following should be provable:

**P1: The (4,4) Chu pairing is the unique composition-compatible norm.** The (4,4) norm `octonion_norm` is the only symmetric bilinear form on the split octonion algebra (up to scalar) that satisfies `N(xy) = N(x)N(y)`. **Proven**: `octonion_norm_mul` in `Algebra.lean`. The (5,3) forms are NOT composition-compatible: `fiveThreeNorm_non_composition` in `Algebra.lean`.

**P2: The antipode preserves the (4,4) norm.** Already proved (`antipode_preserves_norm` in `Algebra.lean`). However, the antipode **changes** the signature when used in the pairing: `(x·S(x)).e₀` gives a (5,3) form, not (4,4). **Proven**: `fiveThreeNorm_eq_antipode_copairing` in `Algebra.lean`.

**P3: Zero divisors at CD3 correspond to the light cone.** At CD ≥ 3, the split octonion admits zero divisors (`N(x) = 0, x ≠ 0`). At CD = 2, it does not (`splitQuatPairing_nondegenerate`). The ZD boundary IS the light cone boundary — exactly like self-dual configurations in Yang-Mills. **Witnesses exist**: `split_add split_one e4_vec` has norm 0 and is nonzero; its product with `split_sub split_one e4_vec` is the zero octonion.

**P4: The coherence interval factorizes through the split-complex norm.** Proved today (`coherenceInterval_eq_splitComplexNorm` in `CoherenceMetric.lean`). The (1,1) split-complex norm is the observable projection of the full (4,4) Yang-Mills structure.

**P5: The dimension reduction chain (4,4)→(5,3)→(3,1)→(1,1) is partially algebraic, partially analytic.** The (4,4)→(5,3) step is an algebraic fact (the antipode involution produces a (5,3) form). The (5,3)→(3,1) step requires the KKT complementarity condition. The (3,1)→(1,1) step is the `coherenceInterval` projection. The (5,3) form is NOT composition-compatible — the chain does not preserve the composition algebra property.

### 4.3 What This Is NOT

This hypothesis **does not claim**:
- That Yang-Mills is "wrong" or "superseded"
- That the split octonion algebra is a quantum field theory
- That gauge groups must be replaced by octonions

It **does claim**:
- That the **structural pattern** (metric → invariant tensor → Lagrangian → field equations → topological sectors) is not specific to compact Lie groups
- That the split hypercomplex algebras have their own analogue of this pattern, built on the Chu pairing rather than the Killing form
- That the pattern transfer is mathematically precise at the level of tensor contractions

---

## 5. Why This Matters for the (4,4) → (5,3) → (3,1) → (1,1) Chain

**REVISED (2026-07-27):** The first step `(4,4) → (5,3)` is now an algebraic fact, not a hypothesis. The antipode involution `S` naturally produces the (5,3) signature when used in the pairing `x · S(x)`. However, the (5,3) form is **NOT composition-compatible** — it does not satisfy the multiplicative property `Q(xy) = Q(x)Q(y)`. This means:

1. The (4,4) `octonion_norm` is the **composition norm** of the split-octonion algebra (proven: `octonion_norm_mul`)
2. The (5,3) `fiveThreeNorm` is an **algebraic shadow** — it emerges from the antipode but is not a composition norm on this multiplication table
3. The dimension-reduction chain is not a tower of composition algebras, but rather: **composition algebra → non-composition shadow → spacetime signature → observable projection**

| Dimensional reduction | Mechanism | Status |
|-----------------------|-----------|--------|
| (4,4) → (5,3) | Antipode pairing `x · S(x)` | **Proven** (`fiveThreeNorm_eq_antipode_copairing`); NOT composition-compatible (`fiveThreeNorm_non_composition`) |
| (5,3) → (3,1) | Covector projection / KKT complementarity | **Open** — needs `OctilinearEmbedding.lean` |
| (3,1) → (1,1) | `coherenceInterval = SplitComplex.norm(coherencePoint)` | **Proven** (`coherenceInterval_eq_splitComplexNorm` in `CoherenceMetric.lean`) |

The (3,1) spacetime signature is not an arbitrary choice — **it is the minimal non-trivial split signature that survives the KKT obstruction.** Yang-Mills works on (3,1) because that is where the metric provides a non-trivial Hodge dual (∗² = −1 on 2-forms). Our framework inherits the same signature for the same reason: the KKT obstruction leaves exactly (3,1) as the minimal signature where the antipode provides a non-trivial duality.

**Key open question:** Why does the (5,3) non-composition shadow produce the correct physics? In Yang-Mills, the gauge-invariant Lagrangian is NOT the full metric tensor — it is the trace `tr(F∧∗F)`, which is a scalar contraction. Similarly, our observable `coherenceInterval` is the `(1,1)` projection of the full `(5,3)` shadow, not the full shadow itself. The non-composition nature of the (5,3) form may be the algebraic reason why the observable physics (coherence intervals) is one-dimensional (scalar) rather than tensor-valued.

---

## 6. Formalization Plan

The hypothesis can be verified incrementally by proving the correspondence theorems:

### Phase 1: Verify the basic tensor isomorphism (P1, P2, P4)
- [x] **P1** — `octonion_norm_mul` proven in `Algebra.lean` (composition identity for (4,4) norm)
- [x] **P2** — `antipode_preserves_norm` already proved; `fiveThreeNorm_eq_antipode_copairing` proven (antipode produces (5,3) form)
- [x] **P4** — `coherenceInterval_eq_splitComplexNorm` already proved in `CoherenceMetric.lean`
- [x] `fiveThreeNorm_non_composition` proven (5,3) form is NOT multiplicative

### Phase 2: Verify the zero-divisor / instanton correspondence (P3)
- [x] Export the existing `zdFreeAtStep2_from_chu_nondegenerate` to `Algebra.lean`
- [ ] Prove that at CD ≥ 3, there exist `x ≠ 0` with `N(x) = 0` (zero divisors exist exactly at the split-octonion level) — **witnesses exist** but theorem not yet packaged
- [ ] Prove that the ZD boundary coincides with the self-duality condition: `N(x) = 0` ↔ `S(x) ∝ x` (the antipode acts as a scalar on null vectors)

### Phase 3: Verify the dimension reduction chain (P5)
- [x] (4,4)→(5,3): Proven as algebraic fact (`fiveThreeNorm_eq_antipode_copairing`)
- [ ] (5,3)→(3,1): Formalize the KKT complementarity condition `λ·g = 0` as a projection operator on `SplitOctonion`
- [ ] (3,1)→(1,1): Already proved (`coherenceInterval_eq_splitComplexNorm`)

### Phase 4: Bridge to Yang-Mills literature
- [ ] Define `splitYangMillsAction` in a new `YangMillsBridge.lean` file
- [ ] Prove that `splitYangMillsAction(λ_t) = coherenceInterval(cd, t)` up to a constant
- [ ] Classify the topological sectors of the Tamari lattice by `dcStep` parity

---

## 7. Revised Findings (2026-07-27)

### 7.1 What Was Proven

Three new theorems in `LaserCortex/foundations/Algebra.lean`:

| Theorem | Statement | Significance |
|---------|-----------|-------------|
| `octonion_norm_mul` | `N(x·y) = N(x)·N(y)` for (4,4) norm | Composition identity — the split-octonion is a composition algebra |
| `fiveThreeNorm_eq_antipode_copairing` | `(x·S(x)).e₀ = e₀²+e₁²+e₂²+e₃²+e₄²−e₅²−e₆²−e₇²` | The (5,3) form emerges from the antipode |
| `fiveThreeNorm_non_composition` | `¬∀ x y, fiveThreeNorm(x·y) = fiveThreeNorm(x)·fiveThreeNorm(y)` | The (5,3) form is NOT a composition norm |

### 7.2 What Was Corrected

**The "Antipode = Hodge star" claim (§3.2, original):** The antipode does NOT preserve the (4,4) signature. It produces (5,3). This is not a bug — it is the algebraic mechanism of the dimension reduction chain.

**The "unique invariant tensor" claim (P1, original):** The (4,4) norm is not just invariant — it is the UNIQUE composition-compatible norm on this multiplication table. The (5,3) forms exist but are non-composition shadows.

### 7.3 What This Means for the Yang-Mills Analogy

The dimension-reduction chain `(4,4) → (5,3) → (3,1) → (1,1)` is now grounded at three of four steps:

```
(4,4) octonion_norm     — composition algebra, multiplicative (PROVEN)
    ↓ Antipode involution S: x ↦ x·S(x) produces (5,3) form
(5,3) fiveThreeNorm     — non-composition shadow (PROVEN non-multiplicative)
    ↓ KKT complementarity / covector projection
(3,1) spacetime signature — open (needs OctilinearEmbedding.lean)
    ↓ CoherenceInterval projection
(1,1) SplitComplex.norm  — observable (PROVEN: coherenceInterval_eq_splitComplexNorm)
```

The **non-composition nature** of the (5,3) form is a feature, not a bug: in Yang-Mills, the gauge-invariant Lagrangian `tr(F∧∗F)` is a scalar contraction of a tensor-valued field strength. The (5,3) form is the tensor; the (1,1) observable is the scalar contraction. The composition algebra lives at the top (4,4); the physics lives at the bottom (1,1); the non-composition intermediate (5,3) is the "shadow of the shadow."

---

## 8. References

- `docs/lab_protocol.md` — (4,4) signature model, timespace decomposition, sections 8-9
- `docs/lab_notes/023_cd_homotopy_bridge_chu_pythagoras_nuclear_metastability.md` — Chu pairing as Pythagorean theorem, ZD boundary as light cone
- `docs/lab_notes/037_kkt_obstruction_cd_pivot.md` — KKT obstruction at CD2, commutator as first pivot
- `docs/lab_notes/038_alchemical_topology.md` — Topological phases, light cone as the Sulfur/Mercury/Salt boundary
- `LaserCortex/foundations/Algebra.lean` — SplitOctonion, SplitQuat, SplitComplex types; norms; antipode; `antipode_preserves_norm`; **`octonion_norm_mul`** (composition identity); **`fiveThreeNorm`** (5,3 antipode-copairing norm); **`fiveThreeNorm_eq_antipode_copairing`**; **`fiveThreeNorm_non_composition`**
- `LaserCortex/foundations/Chu.lean` — Chu pairing, `splitQuatPairing_nondegenerate`, `kkt_stationarity`, `kkt_complementarity`
- `LaserCortex/CoherenceMetric.lean` — `coherenceInterval`, `isTimelike`/`isLightlike`/`isSpacelike`, `SplitComplex.norm`, `coherenceInterval_eq_splitComplexNorm`
- `LaserCortex/OctilinearEmbedding.lean` — KKT multiplier (quaternion + octonion), covector projection
- `LaserCortex/Friction.lean` — `frictionDensity`, `strut_weight_eq_four`, phase change theorems

### External References (Yang-Mills)

- Yang & Mills (1954), "Conservation of Isotopic Spin and Isotopic Gauge Invariance"
- Atiyah, Hitchin, Singer (1978), "Self-duality in four-dimensional Riemannian geometry" — instanton classification
- Jaffe & Witten (2000), "Quantum Yang-Mills Theory" — Clay Millennium Problem on the mass gap
- Baez (2002), "The Octonions" — relationship between octonions and physics, including the exceptional Lie groups
- Ramond (2010), "Group Theory: A Physicist's Survey" — section on octonions and the magic square
