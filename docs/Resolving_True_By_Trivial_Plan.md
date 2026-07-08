# Resolving `True := by trivial` Patterns with Actual Theorems

## Overview

This document outlines the plan for resolving `True := by trivial` or `: True :=` patterns in the Lean codebase with actual theorems or proper documentation. These patterns currently serve as placeholders where actual mathematical theorems should be stated.

## Current Instances of `True := by trivial`

### 1. Primary Target: `develin_sturmfels_tamari_correspondence`
**File:** `LaserCortex/TropicalTamariLattice.lean:178-180`

```lean
theorem develin_sturmfels_tamari_correspondence (k m : ℕ) :
    True := by
  trivial
```

**Gap:** This is a placeholder theorem returning `True`. The actual theorem should state that regular subdivisions of △k × △m correspond dually to configurations of tropical hyperplanes that cut out the ν-associahedron.

### 2. Other Instances:
- `PosetQuotient.lean:600` - `theorem swappable : True := True.intro`
- `Generation.lean:645` - `theorem strut_weight_conjecture : True := True.intro`
- `Generation.lean:738` - `theorem free_is_viable : True := by ... trivial`
- `Decomposition.lean:294` - `theorem lean4_limitation_note : True := by trivial`
- `TamariBP.lean:403-404` - `theorem generation_in_bounded_class ... : True := by ... trivial`

## Information Sources for Bolstering Understanding

### 1. Mathlib Tropical Semiring Structures
**File:** `.lake/packages/mathlib4/Mathlib/Algebra/Tropical/Basic.lean`
- `Tropical R`: Type synonym for tropical interpretation of `R`
- `Semiring (Tropical R)`: Tropical semiring where:
  - Addition is `min` (tropical addition)
  - Multiplication is ordinary addition (tropical multiplication)
- Key theorems: `untrop_add`, `untrop_mul`, `trop_add_def`, `trop_mul_def`

### 2. Mathlib Simplex Structures
**Files:** 
- `.lake/packages/mathlib4/Mathlib/Analysis/Convex/StdSimplex.lean` - `stdSimplex 𝕜 ι`
- `.lake/packages/mathlib4/Mathlib/LinearAlgebra/AffineSpace/Simplex/Basic.lean` - `Affine.Simplex`
- `.lake/packages/mathlib4/Mathlib/Analysis/Convex/SimplicialComplex/Basic.lean` - `SimplicialComplex`

### 3. External Literature for Develin-Sturmfels Correspondence
The Develin-Sturmfels theorem states:
> Regular subdivisions of △k × △m correspond dually to configurations of tropical hyperplanes that cut out the ν-associahedron.

**Key references to consult:**
1. Develin, M., & Sturmfels, B. (2004). "Tropical convexity." *Documenta Mathematica*
2. Speyer, D. E., & Sturmfels, B. (2009). "The tropical Grassmannian." *Advances in Geometry*
3. Postnikov, A. (2009). "Permutohedra, associahedra, and beyond." *International Mathematics Research Notices*

## Strategy for Proving/Resolving

### Strategy 1: Formalize as a Definition/Axiom (Short-term)

Replace `True := by trivial` with a proper statement that references the correspondence without requiring a full proof. This involves:

1. Adding proper documentation referencing external literature
2. Using `True` or a `Prop` placeholder with clear TODO comments
3. Documenting the mathematical statement that should be proven

### Strategy 2: State the Theorem Properly (Long-term)

When Mathlib has the necessary tropical geometry structures, the theorem should be:

```lean
theorem develin_sturmfels_tamari_correspondence (k m : ℕ) :
  -- Regular subdivisions of △k × △m correspond dually to configurations of 
  -- tropical hyperplanes that cut out the ν-associahedron, whose 1-skeleton 
  -- is isomorphic to the ν-Tamari lattice Hasse diagram.
  ∃ (correspondence : RegularSubdivisionsToTropicalHyperplanes k m),
    correspondence ≃ νAssociahedron1Skeleton k m
```

### Strategy 3: Use `sorry` with Documentation (Immediate Action)

Replace `True := by trivial` with a `sorry`-ed theorem that has proper documentation:

```lean
/-- 
The Develin-Sturmfels correspondence for the Tamari lattice.
States that regular subdivisions of △k × △m correspond dually to configurations
of tropical hyperplanes that cut out the ν-associahedron.

Reference: Develin, M., & Sturmfels, B. (2004). "Tropical convexity." 
Documenta Mathematica, 9, 1-27.

TODO: Formalize using Mathlib's tropical geometry or external literature
on the Develin-Sturmfels theorem and the ν-associahedron polyhedral complex.
-/
theorem develin_sturmfels_tamari_correspondence (k m : ℕ) : Prop := by
  sorry
```

## Implementation Plan

### Phase 1: Immediate Actions
1. Replace `True := by trivial` with `sorry` and proper documentation for theorems that need actual mathematical statements
2. Add references to external literature (Develin-Sturmfels, Postnikov's associahedra paper)
3. Update `TropicalTamariLattice.lean` with the `develin_sturmfels_tamari_correspondence` theorem using Strategy 3

### Phase 2: Short-term Actions
1. Formalize as a Definition/Axiom for theorems that cannot yet be proven
2. Add proper documentation and TODO comments for future proof work

### Phase 3: Long-term Actions
1. Wait for or contribute Mathlib support for tropical subdivisions and the ν-associahedron polyhedral complex
2. Implement the full mathematical statement and proof of the Develin-Sturmfels correspondence for the Tamari lattice

## References

1. Develin, M., & Sturmfels, B. (2004). "Tropical convexity." *Documenta Mathematica*, 9, 1-27.
2. Speyer, D. E., & Sturmfels, B. (2009). "The tropical Grassmannian." *Advances in Geometry*, 4(3), 389-411.
3. Postnikov, A. (2009). "Permutohedra, associahedra, and beyond." *International Mathematics Research Notices*, 2009(6), 1026-1106.
4. Mathlib4 Tropical Algebra: `.lake/packages/mathlib4/Mathlib/Algebra/Tropical/Basic.lean`
5. Mathlib4 Standard Simplex: `.lake/packages/mathlib4/Mathlib/Analysis/Convex/StdSimplex.lean`
