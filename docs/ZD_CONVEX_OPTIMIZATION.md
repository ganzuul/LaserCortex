# Zero-Divisor-Constrained Convex Optimization

**Reframing** (2026-07-01): The framework is a convex optimization problem over the CD tower, with ZDs as the only geometric constraints.

## The Optimization Problem

```
minimize    Γ(k) = k + 4·H(k-3)   subject to composition constraints
variables   lt : LogicType, evaluator : {TamariBP, AMM}, cdStep : ℕ
```

Where:
- `H` is the Heaviside step — the `assocDefect` hinge at CD 3
- Γ is convex, piecewise-linear, with one kink at the associativity boundary
- The **feasible set** is defined by two exclusion constraints:

### Constraints (from CompositionSpec)

| Constraint | Form | Meaning |
|-----------|------|---------|
| **Type violation** | ¬(AMM ∘ TamariBP) | Base cannot contain total |
| **ZD monopole** | ¬(TamariBP ∘ TamariBP, same lt) | Identical evaluators diverge |

Everything else is feasible. This is the **least-viable convex program**: two linear constraints, one kink in the objective.

## Duality: The Chu Construction as Lagrangian

The Chu evaluation `η: P ⊗ P' → 1` is the **duality bracket** in the Lagrangian:
- **Primal** `P` = the intervention (what the agent does) — the left operand in composition
- **Dual** `P'` = the context (the spacetime surrounding) — the right operand's logic type
- **η** = the pairing that prices the ZD constraint

The `zsmul_eq_mul` bridge = the **KKT condition**: the dual variables adjust the SMul structure exactly enough to make `embed_mul` hold. The proof that the constraint is tight.

## CD Homotopy: The Feasible Descent Direction

The Cayley-Dickson doubling parameter α ∈ {+1 (split), -1 (compact)} defines a **homotopy** on quadratic forms:

```
Q_{k+1} = Q_k ⊕ α·Q_k
```

- α = -1: compact (ℂ, ℍ, 𝕆) — no ZDs up to ℍ, ZDs appear at 𝕆
- α = +1: split (ℍ̃, 𝕆ˢ) — ZDs appear at ℍ̃, become non-associative at 𝕆ˢ

The ZD monopole at `TamariBP(qt) ∘ TamariBP(qt)` corresponds to the **determinant vanishing** — the quadratic form Q₂₂ becomes singular (has null vectors). Composition is feasible exactly when the product avoids this singularity.

**Solution**: the singularities are the **zero divisors** of the split quaternion algebra. The homotopy moves us away from the singularity by going up the CD tower — to a larger matrix (Q₄₄) that is non-singular.

## Known Matrix Decomposition Analogy

This is structurally identical to:
- **Cholesky/LU with pivoting**: ZDs = zero pivots in the factorization. The CD homotopy = the pivot selection strategy: when we hit a zero pivot (ZD), we expand the matrix (go up a CD step).
- **Homotopy continuation**: α is the homotopy parameter. The feasible compositions are the path-connected components of the α-parameter space avoiding the ZD locus.
- **KKT system**: The composition constraints define a linear matrix inequality (LMI) over the friction density cone.

## What Fills the Blanks

The `sorry` in `CompositionSpec` is now concretely:

### 1. `compositionSpec_valid_iff` (the ⇐ direction)
The constraints are **strong dual** — there's no hidden third constraint. Proof: construct a feasible composition for every pair satisfying both constraints. This is a case analysis over the finite evaluator pairs + lt equality.

### 2. `CompositionSpec.result.bounded`
The boundedness proof = the **optimal value** of the convex program:
```
Γ_composed(qt₁, qt₂) = min{ Γ(k) | feasible(qt₁, qt₂, k) }
```
When qt₁ ≠ qt₂ (different lt), the composition moves to the higher cdStep, giving Γ(max(k₁,k₂)). When same lt with AMM, stays at that step. The barrier (Γ=16) only appears when crossing CD 2→3.

### 3. `embed_mul`
Not a 16×16 brute force — it's the **KKT stationarity condition**: the gradient ∇Γ embeds the constraint into the Clifford algebra, and `zsmul_eq_mul` is the explicit multiplier adjustment.
