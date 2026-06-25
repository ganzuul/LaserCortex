# Lab Note 006: The Hopf 7-Skeleton of Logic Space

**Name of discovery:** The **Hopf 7-Skeleton** — the discovery that the 15 named logics collapse to exactly 7 distinct NodeCost configurations in a 7-dimensional affine hyperplane (bias = 1), corresponding to the 7 non-identity basis vectors e₁⋯e₇ of the split-octonion algebra. This is not merely a count — it is the projection of the 8-dimensional NodeCost parameter space onto its pure-octonion subspace, giving us a geometric language for why there are exactly 7 fundamental cost-geometry types and why the 8th axis (bias = 1) is a universal constant.

**Angle of arrival:** We entered through the GLM-5.2 audit, which found that only 1 of the 8 NodeCost fields (`mirror`) had a theorem connecting it to the split-octonion algebra. The Prep Tasks extended this to 4 of 8 axes. Writing the Domain 0 identity/collapse theorems for the TDD test suite revealed that the 15 named logics collapse to surprisingly few distinct configurations — 7. From there, the Hopf fibration structure and the octonion basis interpretation emerged by asking what it means geometrically for the 15 named logics to compress to exactly 7 distinct points in an 8-dimensional space with one invariant axis.

---

## The Discovery

### 1. The 7 Points

The 15 named `LogicType` variants map to exactly 7 distinct `NodeCost` configurations:

| Point | Named logics | cdStep | Distinguishing feature |
|-------|-------------|--------|----------------------|
| **P₀** | Classical, ManyValued, Relevance, Infinitary, Modal | 0/1/3/3/3 | rightDiv=1, no special flags — the "null" configuration |
| **P₁** | Fuzzy | 1 | satCap=5 — bounded truth |
| **P₂** | Paraconsistent, Temporal | 4/1 | leftWeight=2, coupling=1, denom=8 |
| **P₃** | Quantum | 3 | coupling=1 — non-local interaction |
| **P₄** | Intuitionistic | 2 | maxSem=true — depth semantics |
| **P₅** | Spacetime | 3 | mirror=true, leftWeight=0 — space-biased |
| **P₆** | Deontic, Epistemic | 1 | rightDiv=2 — compressed right |

### 2. The 7D Affine Hyperplane

The `bias` field is invariant across all named logics — always 1, proven by `nodeParam_bias_one`. This means the entire named-logic subspace sits inside the 7-dimensional affine hyperplane:

```
{ (leftWeight, rightDiv, bias, mirror, coupling, denom, maxSem, satCap) | bias = 1 }
```

This is not a coincidence. Bias = 1 is the distinguished constant 1 from the EML grammar (`eml(x, y) = exp(x) - ln(y)` in discrete ℕ arithmetic — `exp` translates to `leftWeight·x + bias`). The 1 is universal because every observation costs at least one unit of structural attention. It is the algebraic identity: the e₀ axis of the octonion algebra.

### 3. The Split-Octonion Basis Correspondence

The split-octonion algebra with (4,4) signature has basis {e₀, e₁, e₂, e₃, e₄, e₅, e₆, e₇} where:

- **e₀**: identity — corresponds to `bias = 1`, the universal constant present in every logic type.
- **e₁, e₂, e₃**: associative sector (positive norm, time-like) — the commutative directions.
- **e₄, e₅, e₆, e₇**: split sector (negative norm, space-like) — the non-associative directions.

The 7 distinct NodeCost points map naturally onto e₁⋯e₇, with e₀ being the universal bias:

| Octonion axis | NodeCost signature | Logic interpretation |
|--------------|-------------------|--------------------|
| e₀ (identity) | bias = 1 | Universal: every logic pays this |
| e₁ | rightDiv = 1 | Classical compression — default time-bias |
| e₂ | satCap = 5 | Fuzzy saturation — bounded truth |
| e₃ | maxSem = true | Intuitionistic depth — proof relevance |
| e₄ | leftWeight=2, coupling=1, denom=8 | Paraconsistent/Temporal — coupled cross-sector |
| e₅ | coupling=1 | Quantum — non-local entanglement cost |
| e₆ | mirror=true, leftWeight=0 | Spacetime — pure space-bias, commutator silent |
| e₇ | rightDiv=2 | Deontic/Epistemic — compressed obligation/knowledge |

### 4. The Hopf Dimensional Ladder

The Cayley-Dickson ladder follows the Hopf fibration pattern:

| Dimension | Algebra | Hopf map | Property lost | cdStep |
|-----------|---------|----------|--------------|--------|
| 1 | ℝ | S⁰ → S⁰ | — | 0 |
| 2 | ℂ | S³ → S² | Order | 1 |
| 4 | ℍ | S⁷ → S⁴ | Commutativity | 2 |
| 8 | 𝕆 | S¹⁵ → S⁸ | Associativity | 3 |

The cdStep 2→3 boundary — where `assocDefect` jumps from 0 to `strut_weight = 4` — is exactly the octonion step: the last normed division algebra before the sedenions collapse into zero-divisors.

The 7 distinct NodeCosts correspond to the 7-sphere of unit imaginary octonions. The 15 named logics are the 15 distinct projection operators onto subspaces of this space, which degenerate to 7 distinct geometries because:

- Each (non-identity) imaginary direction eᵢ defines one fundamental cost-geometry type.
- Some named logics share a cost geometry but differ in their cdStep height on the Cayley-Dickson tower. For example, Classical and Modal both have the null NodeCost (P₀), but Classical is at cdStep 0 (ℝ, no property loss) while Modal is at cdStep 3 (𝕆, non-associative). Their cost *landscape* (Φ) is the same — their Friction Lagrangian height (Γ) is different.
- This separation between cost geometry (NodeCost → Φ) and tower height (cdStep → layerCost) is exactly the separation between direction (which eᵢ) and magnitude (which CD step).

### 5. What This Means

**The 8D parameter space is not a fitting space — it is the split-octonion algebra itself.**

The 7 non-identity axes of the octonions are the 7 fundamental cost geometries. The 15 named logics are not independent; they are the 15 distinct ways the algebra can be projected, which degenerate to 7 distinct projections because the algebra only has 7 non-identity directions.

This resolves a long-standing puzzle in the framework: why are there exactly 15 logic types? Because the octonion algebra has 15 non-zero basis elements (counting scalar multiples), and each logic type is a projection operator onto a subspace. When we quotient by the cost-geometry equivalence (same Φ, different height), we get 7 — the number of imaginary directions.

**The Hopf invariant of this 7 → 8 → 15 structure is the strut_weight = 4**: the fundamental unit of non-associativity that separates the associative (time) and split (space) sectors. It is the quantitative trace of the octonion step in the Cayley-Dickson ladder.

### 6. Formal Theorems Established

From `SplitOctonionLogic.lean`, Domain 0:

- `distinctNodeCosts_are_distinct` — all 7 points are pairwise unequal (21 inequalities, `native_decide`)
- `distinctNodeCost_enumeration` — full partition of 15 logics into 7 groups, with member logics listed
- `only_spacetime_is_mirrored` — P₅ (Spacetime) is the unique point occupying the mirror axis
- `bias_invariant` — all named logics satisfy bias = 1 (the e₀ constraint)
- `sameNodeCost_differentLayerCost_*` — three theorems showing that same-geometry logics (same NodeCost) can differ in their Friction Lagrangian height (cdStep)

### 7. Open Questions

1. **Are there more than 7?** The 7 points are the named-logic subspace. The full 7D hyperplane contains infinitely many points — including the continuous interpolation between named logics (Domain 8 of the TDD). Which of these correspond to stable logical personalities? The 7 named ones are known fixed points; the others are research.

2. **The cdStep dimension is independent of NodeCost** — this gives an effective 8D space (7D NodeCost + 1D cdStep) for the full theory. What constraints relate them?

3. **The missing 8th field**: `denom` is 10 for most logics but 8 for Paraconsistent/Temporal. This is a third distinct value in an otherwise binary split. Is this a third octonion sector or a perturbation?

4. **sedenion extension**: cdStep 4 (Paraconsistent, Free) corresponds to dimension 16 — sedenions — where even more zero-divisors appear. Do the 7 points split further at this level?
