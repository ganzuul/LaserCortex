# 019: Develin-Sturmfels Through the QuantizedType Lens — Cost as Regular Subdivision

**Date**: 2026-07-01  
**Status**: Theoretical exploration (no code changes yet)  
**Prerequisites**: QuantizedType.lean, FrictionLagrangian.lean, TropicalTamariLattice.lean, 017 (CD Galois theory)

---

## 1. The Core Hypothesis

The **Develin-Sturmfels theorem** (2004) establishes a duality between:

1. **Regular subdivisions** of a product of simplices Δ_{k−1} × Δ_{m−1}
2. **Tropical convex hulls** of m points in ℝ^k (configurations of tropical hyperplanes)

The subdivision is *regular* because it is induced by a **height function** — a vector of real numbers assigned to the vertices of Δ_{k−1} × Δ_{m−1} that lifts each cell and takes the lower envelope.

**Hypothesis**: The friction density Γ(k) = k + strut_weight·assocDefect(k) is exactly such a height function, but with additional structure:

1. It factors through the CD ladder (not arbitrary — it comes from algebraic constraints)
2. It has a **composition theory** given by the CompositionSpec factory rules
3. It **breaks** for meta-logics (Free is not Quantized — the theorem is proven)
4. It has a **phase change** at CD 2→3 that changes the subdivision qualitatively (Γ₃/Γ₂ = 9.5)

The QuantizedType `bounded` condition — `∀ t, dcStep t ≤ Γ(k)` — is the **coherence condition** that makes the height function a valid lift: every vertex of the subdivision lies on or above the lower envelope.

---

## 2. What the Product of Simplices Is in Our Setting

The vertices of Δ_{k−1} × Δ_{m−1} are indexed by pairs (i, j) where:

| Index | Range | Meaning |
|-------|-------|---------|
| i | 0…k−1 (CD step) | Which Cayley-Dickson layer (logic type) |
| j | 0…m−1 (dcStep class) | Which contraction-cost class of EMLTrees |

A vertex (i, j) corresponds to: *"trees of contraction cost j, evaluated at CD step i"*.

### The Height Function

```
h(i, j) = Γ(i) = i + strut_weight · assocDefect(i)
```

This is a **product height function** — it factors through the projection onto the first factor (the CD step). Therefore the induced regular subdivision is a **product** of:

- A **1D subdivision** of Δ_{k−1} (the simplex of CD steps), with a break at i=2→3 where Γ jumps from 2 to 19
- The **trivial subdivision** of Δ_{m−1} (all tree shapes are indistinguishable by Γ at a fixed CD step)

### Why This Is Not Trivial

The product structure seems too simple to be interesting — why would the tree shape dimension contribute nothing? Because the height function depends only on Γ(i), not on j.

But the **dual** tropical convex hull is where the tree shape dimension becomes visible:

- The tropical convex hull of the columns of the height matrix A (whose rows are CD steps and columns are tree shapes) has **its supporting hyperplanes determined by which trees are in which boundedness class**
- The **normal complex** of this tropical polytope has cells indexed by trees, and its 1-skeleton IS the Tamari lattice — because `contracts_one` between trees corresponds to adjacency in the normal complex
- This is the content of the `tamariTropicalPath` mapping: contraction steps become tropical edge weights

So the triviality of the subdivision in the j-direction is **compensated** by the non-trivial structure of the dual tropical convex hull, which captures the tree contraction lattice.

---

## 3. The QuantizedType Lens

### 3a. QuantizedType IS the Existence of a Regular Subdivision

| Develin-Sturmfels concept | QuantizedType equivalent |
|---|---|
| Height function on Δ_{k-1} × Δ_{m-1} | `frictionDensity(k) = Γ(k)` |
| Lift is coherent (lower envelope) | `bounded: ∀ t, dcStep t ≤ Γ(k)` |
| Regular subdivision is well-defined | `QuantizedType` structure exists at CD step k |
| Cells of subdivision | Sets of trees with same dcStep |
| 1-skeleton of dual = tropical convex hull | Tamari lattice (contraction poset) |
| Subdivision is non-degenerate | `¬isMetaLogic` (Free excluded) |

**QuantizedType provides the existence condition for the regular subdivision.** Given a QuantizedType at CD step k, the height function Γ(k) induces a valid regular subdivision of Δ_{k−1} × Δ_{m−1}. The proof is:

1. Γ is monotone (`heightMap_monotone` — proven) so the lift is order-preserving
2. `bounded` ensures no vertex lies above the lower envelope
3. The subdivision's cells are the fibers of `dcStep` under Γ(k), which are finite for each k

### 3b. Composition of Subdivisions = CompositionSpec Factory

The factory rules describe how regular subdivisions at different CD steps glue:

| Composition | Valid? | Tropical subdivision meaning |
|---|---|---|
| TamariBP ∘ AMM | YES | Finer subdiv. projects to coarser → **tropical retraction** (total→base) |
| TamariBP ∘ TamariBP (same lt) | NO: ZD monopole | Self-gluing of identical subdiv. → **degenerate tropical hull** |
| AMM ∘ TamariBP | NO: type violation | Coarser cannot refine finer → **projection fails** |
| TamariBP ∘ TamariBP (different lt) | YES | Two different subdivisions glue along tropical intersection |
| AMM ∘ AMM | YES | Two coarser subdivisions glue compatibly |

This **composition theory** is new — the Develin-Sturmfels theorem does not traditionally address how to compose regular subdivisions. The directionality constraint (total→base, not base→total) is a **novel structural insight**: tropical convex hulls have a direction (inclusion) that is not symmetric, and this directionality is captured by the EvaluatorKind.

### 3c. Metaphor: The Subdivider's Lens

Think of the regular subdivision as a **lens** through which we view the tree space:

- **TamariBP** = microscope (high resolution, sees all contraction details)
- **AMM** = naked eye (sees only market-constrained patterns)

Composing TamariBP ∘ AMM means looking at the AMM-subdivision through the microscope — you see more detail but still within the AMM's region. Composing AMM ∘ TamariBP means trying to see microscopic detail with the naked eye — impossible, a type violation.

The ZD monopole (TamariBP ∘ TamariBP, same lt) is like putting two identical microscopes in series — you get interference fringes (zero-divisors) because the second magnification of an already-perfect image is degenerate.

### 3d. Meta-Logics Break the Correspondence

Free Logic is not Quantized (`free_not_quantized` — proven by `native_decide` with counterexample `leftComb 22`). This means:

**The Develin-Sturmfels correspondence fails for meta-logics**: there is no regular subdivision of Δ_{4-1} × Δ_{m-1} induced by Γ(4) = 20 as a height function, because the `bounded` condition fails — `dcStep(leftComb 22) = 21 > 20`.

This is a genuinely new prediction: **a tropical convex hull exists iff the logic has finite inductive bias**. Non-meta logics produce valid tropical polytopes; meta-logics do not. The correspondence is not universal — it is conditioned on QuantizedType's existence.

---

## 4. Reformulated Theorem Statement

The placeholder `develin_sturmfels_tamari_correspondence` in `TropicalTamariLattice.lean` can be replaced with a structured theorem:

```lean
/--
**Develin-Sturmfels correspondence for the QuantizedType framework**.

Given a QuantizedType `qt` at CD step `k` and a natural number `m` (number of
tree-shape classes), the friction density `Γ(k) = frictionDensity k` induces a
regular subdivision of the product of simplices Δ_{k−1} × Δ_{m−1}. The dual
tropical convex hull has a 1-skeleton isomorphic to the poset of EMLTrees
under `contracts_to`, i.e., the Tamari lattice.

The forward direction (QuantizedType ⇒ regular subdivision exists) is
provable within Lean. The reverse direction (regular subdivision ⇒
QuantizedType) is meta-theoretical — it says that any regular subdivision
induced by a height function that bounds all trees must come from a
non-meta logic type.

Reference: Develin, M., & Sturmfels, B. (2004). "Tropical convexity."
Documenta Mathematica, 9, 1-27.
-/
theorem develin_sturmfels_quantized_correspondence
    (qt : QuantizedType) (m : ℕ) :
    RegularSubdivision (Δ (qt.lt.cdStep - 1) × Δ (m - 1)) := ...
```

Where `RegularSubdivision` is a structure representing the subdivision,
constructed from the height function `h(i, j) = frictionDensity i`.

### Structure of the Proof (Forward Direction)

1. **Define** the regular subdivision from Γ(k): cells are equivalence classes of vertices with equal `h(i, j)`
2. **Show** the subdivision is regular: `heightMap_monotone` gives the coherence condition
3. **Construct** the dual tropical convex hull: the tropical convex hull of m points at heights Γ(0), …, Γ(k−1)
4. **Prove** the 1-skeleton is the Tamari lattice: each cell of the subdivision corresponds to a set of trees with a specific `contracts_one` structure, and adjacency = `contracts_one`
5. **Prove** the `tamariTropicalPath` mapping sends each contraction step to an edge of the tropical hull

### Structure of the Reverse Direction (Meta-theoretical)

The reverse direction — that every regular subdivision of Δ × Δ induced by a "tropical bounding function" comes from a non-meta logic — requires:

1. Showing the height function must be Γ(k) for some k (i.e., it must satisfy the CD ladder structure)
2. Showing k < 4 (Free's CD step), i.e., the logic is not meta
3. Constructing a QuantizedType from this data

This is meta-theoretical because step 2 requires proving that `k ≥ 4` implies a counterexample tree exists — which is exactly the `free_not_quantized` theorem's contrapositive.

---

## 5. Connection to Existing Codebase

### What's Already Proven

| Theorem | File | Status |
|---------|------|--------|
| `heightMap_monotone` | FrictionLagrangian.lean | PROVEN |
| `heightMap_discontinuity_at_cd2_3` | FrictionLagrangian.lean | PROVEN |
| `friction_barrier_across_cd23` | FrictionLagrangian.lean | PROVEN |
| `free_not_quantized` | QuantizedType.lean | PROVEN |
| `quantized_types_are_exactly_non_meta_logics` (forward) | QuantizedType.lean | PROVEN |
| `contracts_to_with_cost` | FrictionLagrangian.lean | PROVEN |
| `frictionLagrangian_gt_flatSum` | FrictionLagrangian.lean | PROVEN |

### What Needs to Be Built

| Component | What | Status |
|-----------|------|--------|
| Product of simplices Δ_{k} | `RegularSubdivision` structure type | NOT YET DEFINED |
| Height function from Γ | Mapping from CD step × tree class to ℕ | EASY (exists in FrictionLagrangian) |
| Tropical hyperplane arrangement | Dual complex from Γ values | NEEDS DEFINITION |
| 1-skeleton isomorphism | `contracts_to` ↔ tropical hull edges | NEEDS PROOF |
| `tamariTropicalPath` correctness | Edge weights = Γ(k) differences | NEEDS PROOF |
| ZD monopole → subdivision degeneracy | TamariBP self-composition fails | ALREADY in CompositionSpec |

---

## 6. The Key Insight in Three Sentences

**The Develin-Sturmfels correspondence** says: tropical convex hulls = regular subdivisions of Δ × Δ.

**The QuantizedType lens** says: the height function is not arbitrary — it is Γ(k), the friction density from the CD ladder, which has a phase change at CD 3 and fails entirely for meta-logics.

**The new result**: the correspondence is composable (via CompositionSpec), directional (TamariBP vs AMM), and conditioned on finite inductive bias — making it a **tropical cost theory** rather than just a geometric duality.

---

## 7. Next Steps

1. **Define `RegularSubdivision` type** in `TropicalTamariLattice.lean` — a structure bundling the product of simplices, the height function, and the cell decomposition
2. **Prove forward direction**: given `qt : QuantizedType` and `m : ℕ`, construct the regular subdivision from `frictionDensity qt.lt.cdStep` as height function
3. **Prove 1-skeleton isomorphism**: show `contracts_to` s t iff there is an edge between the corresponding cells in the dual complex
4. **Prove CompositionSpec corresponds to subdivision gluing**: valid composition = compatible subdivisions; invalid = incompatible (ZD or type violation)
5. **Update `develin_sturmfels_tamari_correspondence`** to call the new theorem, and mark the reverse direction as meta-theoretical (matching the pattern in QuantizedType.lean)

---

## References

- `LaserCortex/QuantizedType.lean` — QuantizedType structure, CompositionSpec, free_not_quantized
- `LaserCortex/FrictionLagrangian.lean` — frictionDensity, heightMap_monotone, phase change theorems
- `LaserCortex/TropicalTamariLattice.lean` — TropicalTamariEdge, ContractionStep, develin_sturmfels_tamari_correspondence (placeholder)
- `LaserCortex/TamariBP.lean` — dcStep, BoundednessClass
- `LaserCortex/EMLRegistry.lean` — contracts_one, contracts_to, leftComb, rightComb
- `LaserCortex/LogicTypes.lean` — LogicType, cdStep, isMetaLogic
- `docs/TropicalTamariLattice_Gaps.md` — identified gaps in the existing formalization
- Develin, M., & Sturmfels, B. (2004). "Tropical convexity." Documenta Mathematica, 9, 1-27.
- lab_notes/017 (CD Uplift Inductive Bias)
- lab_notes/018 (CD Galois Theory and the Tower Lattice)
