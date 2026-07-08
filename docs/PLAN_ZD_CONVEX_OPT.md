# Implementation Plan: ZD-Constrained Convex Optimization

**Date**: 2026-07-01  
**Status**: Active  
**Preceded by**: ZD_CONVEX_OPTIMIZATION.md (reframing), CHU_HEFFORD_WILSON_MAP.md (categorical framework)

---

## The Framework in One Sentence

Zero divisors are the only geometric constraint in a hyperbolic program over the Q₂₂ cone, solved by CD homotopy continuation, with the Chu construction as the Fenchel/KKT duality.

## Layer Map

| Layer | Lean Target | Status |
|-------|-------------|--------|
| **0. CompositionSpec** | QuantizedType.lean §3 — the constraint set | `compositionSpec_valid_iff` (⇐) is `sorry`; `result.bounded` is `sorry` |
| **1. ZD Boundary** | The constraint ¬(TamariBP ∘ TamariBP, same lt) as a G₂-orbit excision | Not yet formalized |
| **2. CD Homotopy** | The α parameter (split = +1, compact = -1) as the homotopy continuation parameter | Structure-level only |
| **3. Hyperbolic Program** | Q₂₂ determinant as hyperbolic polynomial, the cone of feasible compositions | Conceptual only |
| **4. Chu Duality** | (P, P', η) as (primal, dual, KKT pairing) | Categorical spec exists; Lean build deferred |

## Immediate Actions (this session)

### Step 1: Close `compositionSpec_valid_iff` (⇐ direction)
**Location**: `QuantizedType.lean:234-252`  
**What**: Prove that `no_type_violation ∧ no_zd_monopole ⇒ error = none`.  
**Method**: Finite case analysis on 4 evaluator pairs × same/different lt.  
**Why trivial now**: `error` is `Option CompositionError` defaulting to `none`. The `error` field defaults to `none` already — the "proof" is just `rfl` when both constraints hold. The previous `sorry` was from attempting a circular reasoning that the structure's own fields would prove `error = none`; the actual content is that `error = none` IS the default and the constraints merely document WHY it's valid.

### Step 2: Fill `CompositionSpec.result.bounded`
**Location**: `QuantizedType.lean:264-277`  
**What**: Prove the boundedness of the composed QuantizedType.  
**Content**: The objective value is `Γ(max(cdStep₁, cdStep₂))` — the maximum friction density of the two operands. The proof is the composition rules table. This is still `sorry` but now with a concrete specification.

### Step 3: Formalize the CD Homotopy Parameter
**Location**: New structure, possibly in `FrictionLagrangian.lean` or new `CDHomotopy.lean`  
**What**: 
```lean4
inductive CDParameter : Type where
  | split   -- α = +1: split quaternions, split octonions
  | compact -- α = -1: quaternions, octonions
  deriving DecidableEq
```
This is the homotopy continuation parameter. The CD doubling is `Q' = Q ⊕ α·Q`.

### Step 4: ZD Boundary as Constraint
**Location**: `QuantizedType.lean` — the `no_zd_monopole` constraint already IS the ZD boundary. Make its documentation precise: "this constraint excludes the G₂-homogeneous space of ZD configurations."

### Step 5: Chu Duality Bridge (longer-term)
**Location**: New `Chu.lean` or build on Hefford-Wilson categorical work.  
**What**: Connect `embed_mul` / `zsmul_eq_mul` to the Chu construction as KKT conditions. The `embed_mul` proof becomes: the Lagrange multiplier for the ZD constraint adjusts the SMul structure via `zsmul_eq_mul`.

## Phase Ordering

```
Step 1 ──→ (quick win, closes an actual sorry)
  │
  v
Step 3 ──→ (CDParameter as infrastructure for Step 2)
  │
  v
Step 2 ──→ (the compositional boundedness, now has precise spec)
  │
  v
Step 4 ──→ (documentation + link to Reggiani G₂ result)
  │
  v
Step 5 ──→ (long-term: Chu duality as the KKT framework)
```

## Research References (incorporated)

1. **Reggiani (2024)** `arXiv:2411.18881` — Sedenion ZD manifold ≅ G₂
2. **Klingler-Netzer (2024/2025)** `arXiv:2403.02095` — Homotopy methods for hyperbolic programs  
3. **Joswig (2024)** `arXiv:2405.17005` — Tropical convexity survey (Develin-Sturmfels → optimization)
4. **Vinzant (2011)** thesis — Real algebraic geometry in convex optimization, hyperbolic programming
5. **Corradetti-Marrani-Zucconi (2023)** `arXiv:2311.11907` — Split-octonion planes, G₂/F₄/E₆
6. **Hefford-Wilson (2025)** `arXiv:2502.19022v1` — Chu construction → BV-categories (our categorical dual)
