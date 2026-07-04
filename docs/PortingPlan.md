# LaserCortex → mathlib Porting Plan

## Context

LaserCortex is a Lean 4 project formalizing a mathematical bridge between
the Tamari lattice (binary tree contraction) and split octonion algebra.
The project contains genuinely novel theorems but also extensive scaffolding,
metaphorical language, and pedagogical wrappers that obscure the mathematical
contribution.

This plan describes how to distill LaserCortex into a clean mathlib contribution:
six atomic files, each independently buildable, each with a clear mathematical
statement that mathlib would value.

## Why six files?

The contribution has six natural layers, each with its own mathematical
vocabulary and independently provable theorems. No layer depends on another
for its core definitions — only for previously established theorems.

## File architecture

```
staging/
├── Algebra.lean
├── Tamari.lean
├── Friction.lean
├── OctilinearEmbedding.lean
├── Chu.lean
└── Composition.lean
```

### Import hierarchy

```
Algebra.lean  (mathlib only)
    │
    ├── Tamari.lean  (mathlib + Algebra)
    │       │
    │       └── Friction.lean  (mathlib + Algebra + Tamari)
    │               │
    │               └── OctilinearEmbedding.lean  (mathlib + Algebra + Tamari + Friction)
    │
    ├── Chu.lean  (mathlib + Algebra)
    │
    └── Composition.lean  (mathlib + Algebra + Tamari)
```

Each file depends only on mathlib and previously completed staging files.
No scaffolding imports.

---

## File 1: Algebra.lean

**Source**: `LaserCortex/SplitOctonionCost.lean` (560 lines) + `LaserCortex/Hopf.lean` (284 lines)
**Lines to port**: ~844 lines

### What it contains

- Split-octonion algebra over ℤ with signature (4,4)
- Q44 quadratic form: positive squares for e₀-e₃, negative squares for e₄-e₇
- Strut weight: strut_weight = 4
- ω = e₄ with ω² = +1
- Antipode: S(eᵢ) = +eᵢ for i < 4, S(eᵢ) = -eᵢ for i ≥ 4
- Anticommutation: e₄·e₅ = -e₅·e₄, etc.
- Antipode non-morphism: S(xy) ≠ S(y)S(x) in general

### What mathlib already has

- `QuadraticForm` for Q44 (use instead of custom Q44)
- `CliffordAlgebra` for SplitQuat (use instead of custom SplitQuat)
- `LinearMap` for bilinear forms

### What to port

1. SplitOctonion type definition with basis
2. Q44 as a QuadraticForm
3. strut_weight = 4
4. ω definition and ω² = +1 proof
5. Antipode definition
6. Anticommutation lemmas
7. Antipode non-morphism counterexample
8. Q44 nondegeneracy

### What to discard

- Metaphorical module docstring ("cost landscape", "institutional closure", etc.)
- Interpretive comments about physics or philosophy
- References to WFC, hyperstition, pedagogical summaries

### Status

Shell created. Ready to port.

---

## File 2: Tamari.lean

**Source**: `LaserCortex/EMLRegistry.lean` (586 lines) + `LaserCortex/TamariBP.lean` (444 lines)
**Lines to port**: ~1,030 lines

### What it contains

- EMLTree: binary trees with size, depth, leftWeight, rightWeight
- contracts_one: single right rotation (Tamari covering relation)
- contracts_to: reflexive-transitive closure (Tamari contraction)
- rightComb: normal form (minimum element in Tamari order)
- dcStep: distance to rightComb (termination measure)
- Antisymmetry, transitivity, termination proofs

### What mathlib already has

- Free monoid structures
- Partial orders
- Termination measures

### What to port

1. EMLTree inductive type
2. contracts_one definition (right rotation)
3. contracts_to as ReflTransGen
4. rightComb definition
5. dcStep definition and measure properties
6. contracts_to_antisymm
7. contracts_to_refl, contracts_to_trans
8. contracts_to_size_eq
9. contracts_to_leftWeight_ge
10. dcStep termination proof

### What to discard

- Metaphorical docstrings about "cost landscape", "generation/collapse duality"
- Interpretive comments about paradox resolution
- Scaffolding structures (Superposition, AntiCoherentPair, inflate, etc.)

### Status

Shell created. Ready to port.

---

## File 3: Friction.lean

**Source**: `LaserCortex/FrictionLagrangian.lean` (812 lines)
**Lines to port**: ~812 lines

### What it contains

- assocDefect: ℕ → ℕ (0 for cdStep ≤ 2, strut_weight for cdStep ≥ 3)
- frictionDensity: ℕ → ℕ
- layerCost
- contracts_to_with_cost
- Phase change theorem at CD 2→3
- heightMap_discontinuity_at_cd2_3

### What to port

1. assocDefect definition
2. assocDefect_phase_change theorem
3. frictionDensity definition
4. frictionDensity_monotone theorem
5. heightMap_discontinuity_at_cd2_3
6. frictionDensity_jump_at_cd3
7. contracts_to_with_cost (cost-annotated contraction)

### What to discard

- Metaphorical "Friction Lagrangian" language
- Continuous Lagrangian stub (unformalized research gap)
- References to action functionals, Lagrangian density

### Status

Shell created. Ready to port.

---

## File 4: OctilinearEmbedding.lean

**Source**: `LaserCortex/TropicalCovector.lean` (511 lines) + `LaserCortex/TropicalTamariLattice.lean` (516 lines)
**Lines to port**: ~1,027 lines

### What it contains

- kktMultiplier: EMLTree → SplitQuat (CD covector)
- covectorProjection: SplitQuat → ℤ × ℤ
- tubeCoord: EMLTree → ℤ × ℤ (coordinates: x = size + assocDefect, y = leftWeight - rightWeight)
- cd3_nonassociative_signature: algebra signature from tree measures
- tubeCoord_cd_diff: coordinates depend on components, not CD step
- tubeCoord_monotone: monotonicity along contraction paths

### What to port

1. kktMultiplier definition
2. covectorProjection definition
3. tubeCoord definition
4. tubeCoord_cd_diff theorem
5. tubeCoord_x_eq_size_plus_assocDefect
6. tubeCoord_y_eq_leftWeight_sub_rightWeight
7. cd3_nonassociative_signature theorem
8. tubeCoord_monotone theorem
9. tubeCoord rightComb/leaf/node theorems

### What to discard

- "Tube map" metaphor
- Tropical lattice references (not the same as mathlib Tropical)
- Interpretive comments about geometry

### Status

Shell created. Ready to port.

---

## File 5: Chu.lean

**Source**: `LaserCortex/Chu.lean` (727 lines)
**Lines to port**: ~727 lines

### What it contains

- SplitQuat type (split quaternion algebra)
- split_one, split_zero
- splitQuatPairing: SplitOctonion → SplitOctonion → ℤ
- splitQuatPairing_nondegenerate
- Behavior on associative vs non-associative sectors

### What to port

1. SplitQuat type definition
2. split_one, split_zero definitions
3. splitQuatPairing definition
4. splitQuatPairing_nondegenerate theorem
5. split_one_pairing, split_zero_pairing
6. Associative sector behavior
7. Non-associative sector behavior

### What to discard

- Metaphorical docstrings
- Chu space references (category theory wrapper)

### Status

Shell created. Ready to port.

---

## File 6: Composition.lean

**Source**: `LaserCortex/QuantizedType.lean` (353 lines)
**Lines to port**: ~353 lines

### What it contains

- QuantizedType: the composition type at a given cdStep
- CompositionSpec: specification of a valid composition
- free_not_quantized: Free Logic cannot be quantized (counterexample)
- CompositionSpec factory

### What to port

1. QuantizedType definition
2. CompositionSpec definition
3. free_not_quantized theorem
4. CompositionSpec_valid

### What to discard

- Metaphorical "QuantizedType factory" language
- References to "logic of will", Gödelian incompleteness framing

### Status

Shell created. Ready to port.

---

## Scaffolding files to discard

These files contain no mathlib-contribution value. They are pedagogical
wrappers, computational examples, or failed experiments.

```
LaserCortex/AMM.lean
LaserCortex/Boundlessness.lean
LaserCortex/Cost.lean
LaserCortex/Decomposition.lean
LaserCortex/Generation.lean
LaserCortex/InstitutionalClosure.lean
LaserCortex/KernelChoice.lean
LaserCortex/LiarParadox.lean
LaserCortex/LodayCoords.lean
LaserCortex/LogicMonad.lean
LaserCortex/LogicTypes.lean
LaserCortex/Problem.lean
LaserCortex/RussellsParadox.lean
LaserCortex/SoritesParadox.lean
LaserCortex/TemporalParadox.lean
```

## Umbrella file

`LaserCortex.lean` (the umbrella file) should be removed. The six staging
files replace it.

---

## Build strategy

At each step:
1. Port one staging file completely
2. Run `lake build LaserCortex.<StagingFile>`
3. Fix any errors (missing imports, type mismatches)
4. Only then move to the next file

Final verification:
1. `lake build` — full build passes
2. `lake build LaserCortex.Algebra` — each file builds independently
3. `lake build LaserCortex.Tamari`
4. `lake build LaserCortex.Friction`
5. `lake build LaserCortex.OctilinearEmbedding`
6. `lake build LaserCortex.Chu`
7. `lake build LaserCortex.Composition`

---

## Naming conventions

- Use mathlib style: `QuadraticForm` not custom `Q44`
- Use mathlib style: `CliffordAlgebra` not custom `SplitQuat`
- Use mathlib style: `FreeMonoid` not custom `EMLTree`
- Use descriptive names: `assocDefect`, `frictionDensity`, `kktMultiplier`
- Strip metaphorical names: "TubeMap", "FrictionLagrangian", "QuantizedType"

---

## Research gaps (not code gaps)

These are documented but not yet formalized. They should be stated as
`opaque` or `axiom` in the contribution, not as `sorry`.

1. `continuous_lagrangian_stub` — the continuous theory (Lagrangian density
   L(x) = e^{αx} - β ln(x²+ε) - δ) is documented but unformalized
2. Reverse direction of Develin-Sturmfels correspondence

---

## ToDo

### Phase 1: Algebra

- [ ] SplitOctonion type over ℤ with basis e₀-e₇
- [ ] Q44 as QuadraticForm (signature (4,4))
- [ ] strut_weight = 4
- [ ] ω = e₄, ω² = +1
- [ ] Antipode S(x) = +x for i<4, -x for i≥4
- [ ] Anticommutation lemmas
- [ ] Antipode non-morphism: S(xy) ≠ S(y)S(x)
- [ ] Q44 nondegeneracy proof
- [ ] Run `lake build LaserCortex.Algebra`

### Phase 2: Tamari

- [ ] EMLTree inductive type (size, depth, leftWeight, rightWeight)
- [ ] contracts_one (right rotation)
- [ ] contracts_to (ReflTransGen)
- [ ] rightComb (normal form)
- [ ] dcStep (distance measure)
- [ ] contracts_to_antisymm
- [ ] contracts_to_refl, contracts_to_trans
- [ ] contracts_to_size_eq
- [ ] contracts_to_leftWeight_ge
- [ ] dcStep termination proof
- [ ] Run `lake build LaserCortex.Tamari`

### Phase 3: Friction

- [ ] assocDefect definition
- [ ] assocDefect_phase_change theorem
- [ ] frictionDensity definition
- [ ] frictionDensity_monotone theorem
- [ ] heightMap_discontinuity_at_cd2_3
- [ ] frictionDensity_jump_at_cd3
- [ ] contracts_to_with_cost
- [ ] Run `lake build LaserCortex.Friction`

### Phase 4: OctilinearEmbedding

- [ ] kktMultiplier: EMLTree → SplitQuat
- [ ] covectorProjection: SplitQuat → ℤ × ℤ
- [ ] tubeCoord: EMLTree → ℤ × ℤ
- [ ] tubeCoord_x_eq_size_plus_assocDefect
- [ ] tubeCoord_y_eq_leftWeight_sub_rightWeight
- [ ] tubeCoord_cd_diff
- [ ] cd3_nonassociative_signature
- [ ] tubeCoord_monotone
- [ ] Run `lake build LaserCortex.OctilinearEmbedding`

### Phase 5: Chu

- [ ] SplitQuat type
- [ ] split_one, split_zero
- [ ] splitQuatPairing
- [ ] splitQuatPairing_nondegenerate
- [ ] split_one_pairing, split_zero_pairing
- [ ] Associative sector behavior
- [ ] Non-associative sector behavior
- [ ] Run `lake build LaserCortex.Chu`

### Phase 6: Composition

- [ ] QuantizedType definition
- [ ] CompositionSpec definition
- [ ] free_not_quantized theorem
- [ ] CompositionSpec_valid
- [ ] Run `lake build LaserCortex.Composition`

### Phase 7: Full build + cleanup

- [ ] Full `lake build` passes
- [ ] Remove umbrella `LaserCortex.lean`
- [ ] Remove scaffolding files (Phase 1-6)
- [ ] Update `.gitignore` if needed
- [ ] Commit all changes

### Phase 8: Research gaps

- [ ] Formalize `continuous_lagrangian_stub` (research gap)
- [ ] Reverse direction of Develin-Sturmfels correspondence (research gap)
