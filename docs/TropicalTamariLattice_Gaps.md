# Tropical Tamari Lattice: Unproven Theorems and Implementation Gaps

## Overview

This document catalogs the unproven theorems, placeholder implementations, and identified gaps in the `TropicalTamariLattice.lean` module and related files (`EMLRegistry.lean`, `TamariBP.lean`, `SplitQuaternionClifford.lean`, `SplitOctonionCost.lean`). These gaps represent work that was intended to be completed but was left as placeholders or TODOs.

---

## Gaps in `TropicalTamariLattice.lean`

### 1. `tamariTropicalPath` Function (Lines 128-129)

**Current State:**
```lean
def tamariTropicalPath (path : List EMLTree) : List TropicalTamariEdge :=
  [] -- TODO: Implement the mapping from EMLTree contraction path to TropicalTamariEdge list
```

**Gap:** The function returns `[]` as a placeholder. It needs to map a sequence of `contracts_one` steps (an `EMLTree` contraction path) to a sequence of `TropicalTamariEdge`s with proper `tropicalWeight` values.

**Required Implementation:**
- Iterate through the `path : List EMLTree` and identify consecutive pairs `(s, t)` where `contracts_one s t` holds.
- For each such pair, construct a `TropicalTamariEdge` with:
  - `source = s`
  - `target = t`
  - `tropicalWeight = ℕ` (derived from the `dcStep` difference or left-weight measure)
  - `isContraction = contracts_one s t`

### 2. `develin_sturmfels_tamari_correspondence` Theorem (Lines 155-157)

**Current State:**
```lean
theorem develin_sturmfels_tamari_correspondence (k m : ℕ) :
    True := by
  trivial
```

**Gap:** This is a placeholder theorem returning `True`. The actual theorem should state that regular subdivisions of △k × △m correspond dually to configurations of tropical hyperplanes that cut out the ν-associahedron.

**Required Theorem Statement:**
The theorem should formalize the Develin–Sturmfels correspondence for the Tamari lattice, stating that regular subdivisions of the product of two simplices △k × △m correspond dually to configurations of tropical hyperplanes that induce the polyhedral complex whose 1-skeleton is isomorphic to the ν-Tamari lattice Hasse diagram.

---

## Gaps from Invariants/Documentation

### 3. Tamari Lattice Hasse Diagram Isomorphism (Invariant 3)

**Invariant Statement:**
> "Tamari lattice Hasse diagram is isomorphic to the 1-skeleton of a polyhedral complex induced by tropical hyperplane arrangements"

**Gap:** This isomorphism between the `EMLTree` contraction lattice (via `contracts_one` and `contracts_to`) and the 1-skeleton of the polyhedral complex induced by tropical hyperplane arrangements has not been formalized.

**Required Formalization:**
- Define the polyhedral complex induced by tropical hyperplane arrangements.
- Define the 1-skeleton of this complex.
- Prove the isomorphism between this 1-skeleton and the Hasse diagram of the Tamari lattice (defined by `EMLTree` and `contracts_one`).

### 4. Develin–Sturmfels Theorem for the Tamari Lattice (Invariant 4)

**Invariant Statement:**
> "Regular subdivisions of △k × △m correspond dually to configurations of tropical hyperplanes (Develin–Sturmfels theorem)"

**Gap:** The formal statement and proof of the Develin–Sturmfels correspondence specifically for the Tamari lattice/ν-associahedron context has not been implemented.

**Required Formalization:**
- Formalize the Develin–Sturmfels theorem from tropical geometry: regular subdivisions of △k × △m correspond dually to configurations of tropical hyperplanes.
- Specialize this to the ν-Tamari lattice context, where the ν-associahedron is the relevant polytope.

---

## Gaps from Strategy/Next Steps

### 5. Tropical Valuation on `SplitQuat` and `SplitOctonion`

**Gap:** The tropical valuation on `SplitQuat` and `SplitOctonion` needs to be formalized. This would map the Cayley-Dickson algebra coordinates to tropical coordinates (`Tropical ℝ` or `Tropical ℤ`) suitable for the tube map application.

**Required Implementation:**
- Define a valuation map `val : SplitQuat → Tropical ℝ` (or `Tropical ℤ`).
- Define a valuation map `val : SplitOctonion → Tropical ℝ` (or `Tropical ℤ`).
- Prove that these valuations respect the tropical semiring operations (minimization for addition, ordinary addition for multiplication).

### 6. Connection between `TamariBP.dcStep` and Tropical Curve Length

**Gap:** The connection between `TamariBP.dcStep` (the decision/computability distance to idempotence, i.e., the number of `contracts_one` iterations needed to reach the right-comb normal form) and tropical curve length needs to be formalized.

**Required Formalization:**
- Define the length of a tropical curve edge in terms of its `tropicalWeight`.
- Prove that the sum of `tropicalWeight`s along a `tamariTropicalPath` corresponds to the `dcStep` of the initial tree in the path.

### 7. Mapping `AMM.Route` to Tube Map Edges with 90/45 Constraints

**Gap:** The mapping from `AMM.Route` to tube map edges with 90-degree and 45-degree turn constraints has not been implemented. The 90-degree turns differ by 1 in x and 1 in y, and 45-degree turns differ by 1 in x and 2 in y or 2 in x and 1 in y.

**Required Implementation:**
- Define the 90-degree turn constraint: `|dx| = 1 ∧ |dy| = 1`.
- Define the 45-degree turn constraint: `(|dx| = 1 ∧ |dy| = 2) ∨ (|dx| = 2 ∧ |dy| = 1)`.
- Map the `AMM.Route` or `EMLTree` contraction paths to sequences of coordinates satisfying these constraints.

---

## Gaps in `EMLRegistry.lean`

### 8. Lifting Lemmas: Monotonicity of Evolution Paths under `Node` (Line 83)

**Current State (from comments):**
```lean
-- 3. Lifting lemmas (monotonicity of evolution paths under Node) - TODO
```

**Gap:** The lifting lemmas that establish the monotonicity of evolution paths under the `Node` composition operation have not been proven.

**Required Theorems:**
- `contracts_to_node_left`: If `contracts_to s t`, then `contracts_to (Node l s) (Node l t)`.
- `contracts_to_node_right`: If `contracts_to s t`, then `contracts_to (Node s r) (Node t r)`.

### 9. Main Convergence Theorem: `contracts_to_rightComb` (Line 85)

**Current State (from comments):**
```lean
-- 5. Main convergence theorem (contracts_to_rightComb) - TODO
```

**Gap:** The main convergence theorem stating that all trees contract to the `rightComb` normal form (`contracts_to_rightComb`) has not been fully proven.

**Required Theorem:**
```lean
theorem contracts_to_rightComb (t : EMLTree) : contracts_to t (rightComb t.size)
```

This theorem should be proven using the `dcStep` measure and the `dcStep_contracts_one` lemma, showing that repeated application of `contracts_one` eventually reaches the `rightComb` normal form.

---

## Summary Table

| # | Gap | File | Status |
|---|-----|------|--------|
| 1 | `tamariTropicalPath` implementation | `TropicalTamariLattice.lean` | Placeholder returning `[]` |
| 2 | `develin_sturmfels_tamari_correspondence` theorem | `TropicalTamariLattice.lean` | Placeholder returning `True` |
| 3 | Tamari Hasse diagram ↔ 1-skeleton isomorphism | `TropicalTamariLattice.lean` (invariants) | Not formalized |
| 4 | Develin–Sturmfels theorem for Tamari lattice | `TropicalTamariLattice.lean` (invariants) | Not formalized |
| 5 | Tropical valuation on `SplitQuat` and `SplitOctonion` | Strategy/Next Steps | Not formalized |
| 6 | Connection between `dcStep` and tropical curve length | Strategy/Next Steps | Not formalized |
| 7 | Mapping `AMM.Route` to tube map edges (90/45 constraints) | Strategy/Next Steps | Not implemented |
| 8 | Lifting lemmas: monotonicity of evolution paths under `Node` | `EMLRegistry.lean` | TODO |
| 9 | Main convergence theorem: `contracts_to_rightComb` | `EMLRegistry.lean` | TODO |

---

## Next Steps for Resolution

1. **Immediate Priority**: Implement `tamariTropicalPath` using the `dcStep` measure and `contracts_one` relation from `TamariBP.lean` and `EMLRegistry.lean`.
2. **Theorem Formalization**: Replace the `develin_sturmfels_tamari_correspondence` placeholder with a proper statement referencing Mathlib's tropical geometry or external literature on the Develin–Sturmfels theorem.
3. **EMLRegistry Completeness**: Prove the lifting lemmas and the main convergence theorem `contracts_to_rightComb` in `EMLRegistry.lean`.
4. **Tube Map Integration**: Formalize the tropical valuation on `SplitQuat` and `SplitOctonion`, and implement the 90/45-degree turn constraints for the tube map application.
