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
Algebra.lean  (mathlib + Algebra internal: SplitQuat, Cl11, Clifford relations)
    │
    ├── Tamari.lean  (mathlib + Algebra)
    │       │
    │       └── Friction.lean  (mathlib + Algebra + Tamari)
    │               │
    │               └── OctilinearEmbedding.lean  (mathlib + Algebra + Tamari + Friction)
    │
    ├── Chu.lean  (mathlib + Algebra)
    │
    └── Composition.lean  (mathlib + Algebra + Tamari + Friction)
```

Each file depends only on mathlib and previously completed staging files.
No scaffolding imports.

---

## File 1: Algebra.lean

**Source**: `LaserCortex/SplitOctonionCost.lean` (560 lines) + `LaserCortex/Hopf.lean` (284 lines) + `LaserCortex/SplitQuaternionClifford.lean` (353 lines)
**Lines to port**: ~1,197 lines (SplitOctonion + SplitQuat + Clifford relations)

### What it contains

**SplitOctonion** (signature (4,4)):
- Q44 quadratic form: positive squares for e₀-e₃, negative squares for e₄-e₇
- Strut weight: strut_weight = 4
- ω = e₄ with ω² = +1
- Antipode: S(eᵢ) = +eᵢ for i < 4, S(eᵢ) = -eᵢ for i ≥ 4
- Anticommutation: e₄·e₅ = -e₅·e₄, etc.
- Antipode non-morphism: S(xy) ≠ S(y)S(x) in general

**SplitQuat** (signature (2,2)):
- Q11 quadratic form, Cl11 = CliffordAlgebra Q11
- Clifford relations: e₀² = 1, e₁² = -1, e₀·e₁ + e₁·e₀ = 0
- SplitQuat type (a, b, c, d)
- embed: SplitQuat → Cl11 (ℤ-algebra homomorphism)
- norm: (2,2) norm N(x) = a² + b² - c² - d²
- antipode_sq: grading involution on SplitQuat
- split_quat_mul, norm_mul

### What mathlib already has

- `QuadraticForm` for Q44/Q11 (use instead of custom Q44/Q11)
- `CliffordAlgebra` for Cl11 (use instead of custom Cl11)
- `LinearMap` for bilinear forms
- `QuadraticForm` already provides nondegeneracy

### What to port

**SplitOctonion** (from SplitOctonionCost + Hopf):
1. SplitOctonion type with 8 basis components
2. Q44 as QuadraticForm (signature (4,4))
3. strut_weight = 4 (norm of associator at e₁,e₂,e₄)
4. ω = e₄, ω² = +1 proof
5. Antipode S(x)
6. Anticommutation lemmas
7. Antipode non-morphism: S(xy) ≠ S(y)S(x)
8. octonion_norm, associator_tensor, pentagon_defect

**SplitQuat** (from SplitQuaternionClifford):
9. Q11 quadratic form, Cl11 = CliffordAlgebra Q11
10. e₀, e₁ basis elements + Clifford relations
11. SplitQuat type (a, b, c, d)
12. SplitQuat.embed: SplitQuat → Cl11
13. SplitQuat.norm + norm_mul
14. split_quat_mul, split_quat_add, split_quat_neg
15. antipode_sq + 7 theorems

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
**Lines to port**: lines 150-305, 360-400 (core cost definitions)

### What it contains

- assocDefect: ℕ → ℕ (0 for cdStep ≤ 2, strut_weight for cdStep ≥ 3)
- commDefect: ℕ → ℕ (= k)
- frictionDensity: ℕ → ℕ (= commDefect + strut_weight * assocDefect)
- layerCost (simplified: ℕ → ℕ, was LogicType → ℕ)
- contracts_to_with_cost: cost-annotated Tamari contraction
- Phase change theorems at CD 2→3
- heightMap_discontinuity

### What to port

1. `assocDefect` (line 159) + `assocDefect_zero_up_to_cd2` (line 261)
2. `commDefect` (line 170)
3. `frictionDensity` (line 180) + `frictionDensity_at_cl11_boundary` (line 289)
4. `frictionDensity_jump_at_cd3` (line 296)
5. `layerCost` (line 195, simplify to `ℕ → ℕ`)
6. `layerCost_ge_cdStep` (line 202) + `layerCost_eq_cdStep_for_assoc` (line 209)
7. `contracts_to_with_cost` (line 655) + related theorems (663-714)

### What to discard

- Metaphorical "Friction Lagrangian" language
- Continuous Lagrangian stub (unformalized research gap)
- References to action functionals, Lagrangian density
- Tower/Problem scaffolding (lines 84-89, 230-258, 360-640)
- EngineState, LodayCoords (lines 394-527)
- Flat cost sum, frictionLagrangian_ge_flatSum (lines 230-258)

### Status

Shell created. Ready to port.

---

## File 4: OctilinearEmbedding.lean

**Source**: `LaserCortex/TropicalCovector.lean` (511 lines) + `LaserCortex/TropicalTamariLattice.lean` (516 lines)
**Lines to port**: lines 63-300, 300-511 from TropicalCovector; lines 431-503 from TropicalTamariLattice

### What it contains

- kktMultiplier: EMLTree → SplitQuat (CD covector)
- covectorProjection: SplitQuat → ℤ × ℤ
- tubeCoord: EMLTree → ℤ × ℤ (coordinates: x = size + assocDefect, y = leftWeight - rightWeight)
- cd3_nonassociative_signature: algebra signature from tree measures
- tubeCoord_cd_diff: coordinates depend on components, not CD step
- tubeCoord_monotone: monotonicity along contraction paths
- kktMultiplierOct, covectorProjectionOct, tubeCoordOct (octonion versions)
- pairing_signature_phase_change, cd3_nonassociative_signature

### What to port

1. `kktMultiplier` (line 92) + `kktMultiplier_antipode` (103)
2. `covectorProjection` (line 135) + `covectorProjection_antipode` (143)
3. `tubeCoord` (line 170) + `tubeCoord_expand` (176)
4. `tubeCoord_leaf` (185), `tubeCoord_node_leaf_leaf` (192)
5. `tubeCoord_rightComb` (201), `tubeCoord_assoc_step` (220)
6. `tubeCoord_cd_diff` (247) + `tubeCoord_x_eq_size_plus_assocDefect` (257)
7. `tubeCoord_y_eq_leftWeight_sub_rightWeight` (266)
8. `tubeCoord_monotone` (from TropicalTamariLattice)
9. `kktMultiplierOct` (line 300), `covectorProjectionOct` (347)
10. `tubeCoordOct` (line 381) + `tubeCoordOct_eq_tubeCoord` (393)
11. `pairing_signature_phase_change` (line 483)
12. `cd3_nonassociative_signature` (line 503)

### What to discard

- "Tube map" metaphor
- Tropical lattice instances (lines 88-92, already in mathlib)
- Develin-Sturmfels scaffolding (lines 176-388)
- EdgeAngle (line 499)
- Interpretive comments about geometry

### Status

Shell created. Ready to port.

---

## File 5: Chu.lean

**Source**: `LaserCortex/Chu.lean` (727 lines)
**Lines to port**: lines 60-104, 122-216, 239-347, 412-621
**Imports**: `Mathlib + LaserCortex.staging.Algebra`

### What it contains

- ChuSpace: triple (a, a', β) with ℤ-bilinear pairing
- splitQuatPairing: SplitQuat → SplitQuat → ℤ (canonical bilinear form)
- splitQuatPairing_nondegenerate
- octonionPairing: SplitOctonion → SplitOctonion → ℤ (polarization of (4,4) norm)
- octonionPairing_nondegenerate
- antipodePairing_nondegenerate
- chuEmbed: SplitQuat → Cl11 (algebra homomorphism)
- chu_embed_mul, chu_zsmul_eq_mul
- ChuTensor, ChuSeq (monoidal structure)
- dualize, star_involutive
- kkt_stationarity, kkt_complementarity

### What to port

1. `ChuSpace` structure (line 84) + `primal`/`dual`/`dualize` (91-104)
2. `splitQuatPairingAux` (line 122) + `splitQuatPairing` (line 146)
3. `splitQuatPairingAux_symm` (line 167) + `splitQuatPairing_antipode_symm` (line 177)
4. `splitQuatPairing_nondegenerate` (line 196)
5. `octonionPairingAux` (line 239) + `octonionPairing` (line 282)
6. `octonionPairingAux_symm` (line 309) + `octonionPairing_antipode_symm` (line 322)
7. `octonionPairing_nondegenerate` (line 349) + `antipodePairing_nondegenerate` (line 390)
8. `chuEmbed` (line 412) + `chuSpaceOf` (line 422)
9. `chu_embed_mul` (line 456) + `chu_zsmul_eq_mul` (line 481)
10. `ChuTensor` (line 500), `ChuSeq` (line 517)
11. `dualize_chuSpaceOf` (line 560) + `star_involutive` (line 568)
12. `kkt_stationarity` (line 599) + `kkt_complementarity` (line 614)

### What to discard

- CD-homotopy bridge (lines 639-727): `norm_via_pairing`, `zdFreeAtStep2_from_chu_nondegenerate`
- Metaphorical docstrings
- Chu space category-theoretic wrapper (ChuSeq, ChuTensor are algebraic, not categorical)

### Status

Shell created. Ready to port.

---

## File 6: Composition.lean

**Source**: `LaserCortex/QuantizedType.lean` (353 lines)
**Lines to port**: lines 34-37, 68-71, 104-107, 145-166, 180-198, 247-270, 320-351
**Imports**: `Mathlib + LaserCortex.staging.Algebra + LaserCortex.staging.Tamari + LaserCortex.staging.Friction`

### What it contains

- EvaluatorKind: tamariBP | amm
- QuantizedType: logic type + evaluator + boundedness proof
- CompositionError: typeViolation | zeroDivisor
- CompositionSpec: valid composition specification with Prop proof fields
- free_not_quantized: counterexample proof (leftComb 22)
- quantized_types_are_exactly_non_meta_logics: partition theorem

### What to port

1. `EvaluatorKind` (line 34)
2. `QuantizedType` (line 68) + `quantizedFrictionDensity` (line 77)
3. `CompositionError` (line 104)
4. `CompositionSpec` (line 145) + `CompositionSpec.error` (line 163)
5. `compositionSpec_valid_iff` (line 180)
6. `CompositionSpec.result` (line 214)
7. `free_not_quantized` (line 247)
8. `quantized_types_are_exactly_non_meta_logics` (line 324)

### What to discard

- LogicTypes dependency (lines 1-33, 84-100, 115-161, 188-246, 272-322): scaffolding
- "Factory" metaphor
- Metaphorical docstrings

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
2. `lake build LaserCortex.Algebra` — SplitOctonion + SplitQuat + Clifford
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

### Stage 0: SplitQuat in Algebra.lean

- [ ] Q11 quadratic form (signature (2,2))
- [ ] Cl11 = CliffordAlgebra Q11
- [ ] e₀, e₁ basis elements + Clifford relations (e₀²=1, e₁²=-1, e₀·e₁+e₁·e₀=0)
- [ ] SplitQuat type (a, b, c, d)
- [ ] SplitQuat.embed: SplitQuat → Cl11
- [ ] SplitQuat.norm + norm_mul theorem
- [ ] split_quat_mul, split_quat_add, split_quat_neg
- [ ] antipode_sq + 7 theorems
- [ ] Run `lake build LaserCortex.Algebra`

### Stage 1: Tamari

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

### Stage 2: Friction

- [ ] assocDefect definition (line 159) + phase change (line 261)
- [ ] commDefect definition (line 170)
- [ ] frictionDensity definition (line 180) + boundary/jump (lines 289-296)
- [ ] layerCost (line 195, simplified to ℕ → ℕ)
- [ ] layerCost_ge_cdStep (line 202) + layerCost_eq_cdStep_for_assoc (line 209)
- [ ] contracts_to_with_cost (line 655) + related theorems (663-714)
- [ ] Run `lake build LaserCortex.Friction`

### Stage 3: OctilinearEmbedding

- [ ] kktMultiplier: EMLTree → SplitQuat (line 92)
- [ ] covectorProjection: SplitQuat → ℤ × ℤ (line 135)
- [ ] tubeCoord: EMLTree → ℤ × ℤ (line 170)
- [ ] tubeCoord_leaf, tubeCoord_node_leaf_leaf, tubeCoord_rightComb (lines 185-201)
- [ ] tubeCoord_assoc_step (line 220)
- [ ] tubeCoord_cd_diff (line 247) + tubeCoord_x_eq_size_plus_assocDefect (line 257)
- [ ] tubeCoord_y_eq_leftWeight_sub_rightWeight (line 266)
- [ ] kktMultiplierOct, covectorProjectionOct, tubeCoordOct (lines 300-393)
- [ ] pairing_signature_phase_change (line 483)
- [ ] cd3_nonassociative_signature (line 503)
- [ ] Run `lake build LaserCortex.OctilinearEmbedding`

### Stage 4: Chu

- [ ] ChuSpace structure (line 84)
- [ ] splitQuatPairingAux + splitQuatPairing (lines 122-163)
- [ ] splitQuatPairing_symm + splitQuatPairing_antipode_symm (lines 167-179)
- [ ] splitQuatPairing_nondegenerate (line 196)
- [ ] octonionPairingAux + octonionPairing (lines 239-301)
- [ ] octonionPairing_symm + octonionPairing_antipode_symm (lines 309-324)
- [ ] octonionPairing_nondegenerate (line 349) + antipodePairing_nondegenerate (line 390)
- [ ] chuEmbed + chuSpaceOf (lines 412-425)
- [ ] chu_embed_mul (line 456) + chu_zsmul_eq_mul (line 481)
- [ ] ChuTensor, ChuSeq (lines 500-520)
- [ ] dualize_chuSpaceOf + star_involutive (lines 560-569)
- [ ] kkt_stationarity + kkt_complementarity (lines 599-615)
- [ ] Run `lake build LaserCortex.Chu`

### Stage 5: Composition

- [ ] EvaluatorKind: tamariBP | amm (line 34)
- [ ] QuantizedType structure (line 68)
- [ ] CompositionError: typeViolation | zeroDivisor (line 104)
- [ ] CompositionSpec with Prop proof fields (line 145)
- [ ] CompositionSpec.error + compositionSpec_valid_iff (lines 163-198)
- [ ] CompositionSpec.result (line 214)
- [ ] free_not_quantized counterexample (line 247)
- [ ] quantized_types_are_exactly_non_meta_logics (line 324)
- [ ] Run `lake build LaserCortex.Composition`

### Stage 6: Full build + cleanup

- [ ] Full `lake build` passes
- [ ] Remove umbrella `LaserCortex.lean`
- [ ] Remove scaffolding files
- [ ] Update `.gitignore` if needed
- [ ] Commit all changes

### Stage 7: Research gaps

- [ ] Formalize `continuous_lagrangian_stub` (research gap)
- [ ] Reverse direction of Develin-Sturmfels correspondence (research gap)
