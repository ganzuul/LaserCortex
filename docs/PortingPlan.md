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

DONE. 823 lines. All SplitOctonion + SplitQuat definitions and theorems compile.
  - `pentagon_defect` corrected: five distinct bracketings with telescoping `term1 - term5` (coefficient-balanced sum to zero; was copy-paste bug with repeated term producing sum = -1)
  - ⚠️ `pentagon_defect` is vector-valued (SplitOctonion) — the correct formalization for alternative algebras may be a **sign cocycle** φ(a,b,c) = ±1 satisfying φ(b,c,d)·φ(a,bc,d)·φ(a,b,c) = φ(a,b,cd)·φ(ab,c,d). See "Sign cocycle formalization" in Research Gaps below.
  - `split_oct_commutator` defined: commutator on SplitOctonion
  - `shiftBy4` defined: embeds commutator's first 4 components into e₄-e₇ sector (CD doubling map)
  - `cd_doubling_identity` proven: associator_tensor a b e4_vec = split_oct_mul (split_oct_commutator a b) e4_vec for base subalgebra elements; restriction to base is necessary (cross-terms survive for arbitrary a,b)
  - `SplitQuat.grade` added: proper grade involution (negates odd-grade b, c; fixes even-grade a, d)
  - ⚠️ **`SplitQuat.antipode_sq` ≠ `SplitQuat.grade`**: `antipode_sq` is the Clifford conjugate (negates d), `SplitQuat.grade` is the grade involution (fixes d). Octonion `antipode` fixes e₄ (correct). The SplitQuat `antipode_sq` negating d caused incorrect geometric theorems in OctilinearEmbedding — they now correctly use `SplitQuat.grade`.

---

## File 2: Tamari.lean

**Source**: `LaserCortex/EMLRegistry.lean` (586 lines) + `LaserCortex/TamariBP.lean` (444 lines)
**Lines to port**: ~1,030 lines (now ~392 lines after stripping scaffolding)

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

DONE. 392 lines. Full EMLTree theory with normal forms and termination proof.

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

DONE. 126 lines. Core cost definitions + phase change theorems.
`lake build LaserCortex.Friction` passes.

- [x] `assocDefect` definition + `assocDefect_zero_up_to_cd2`
- [x] `commDefect` definition
- [x] `frictionDensity` definition + `frictionDensity_at_cl11_boundary` + `frictionDensity_jump_at_cd3`
- [x] `frictionDensity_ge_k` + `frictionDensity_eq_k_for_k_le_2` + `frictionDensity_monotone`
- [x] `heightMap_discontinuity_at_cd2_3`
- [x] `lake build LaserCortex.Friction`

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

DONE. 375 lines. All definitions + theorems compile. `lake build LaserCortex.OctilinearEmbedding`
passes (verified 2026-07-06: 3 of 6 staging files had build errors requiring fixes;
OctilinearEmbedding had 10+ ring arithmetic failures, `λ` reserved-word collision,
and wrong use of `antipode_sq` instead of `SplitQuat.grade` for grade involution).

- [x] Init: "Shell created, ready to port" — **incorrect**: actual stage had 369 lines of theorems, most broken
- [x] Fix: reserved binder `λ` → `x` in Octonion extension section
- [x] Fix: `covectorProjection_antipode` — was using `antipode_sq` (Clifford conjugate, negates d); corrected to `SplitQuat.grade` (grade involution, fixes d)
- [x] Fix: all ring arithmetic goals closed via `pow_two` + `ring`/`omega`/`ring_nf`
- [x] Fix: `transitCoord_rightComb` induction step — added explicit size/weight recurrence lemmas
- [x] Fix: `No goals to be solved` after `rw` in `transitCoord_x_eq_size_plus_assocDefect` etc. — removed dead `rfl`
- [x] `lake build` (full) — verified clean

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
10. `ChuTensor`, `ChuSeq` (lines 500-520)
11. `dualize_chuSpaceOf` (line 560) + `star_involutive` (line 568)
12. `kkt_stationarity` (line 599) + `kkt_complementarity` (line 614)

### What to discard

- CD-homotopy bridge (lines 639-727): `norm_via_pairing`, `zdFreeAtStep2_from_chu_nondegenerate`
- Metaphorical docstrings
- Chu space category-theoretic wrapper (ChuSeq, ChuTensor are algebraic, not categorical)

### Status

DONE. 294 lines (staging/Chu.lean). All ChuSpace + pairings + algebra homomorphism
+ duoidal structure theorems compile. `lake build LaserCortex.Chu` passes.

- [x] ChuSpace structure (line 84) + `primal`/`dual`/`dualize` (91-104)
- [x] `splitQuatPairingAux` (line 122) + `splitQuatPairing` (line 146)
- [x] `splitQuatPairingAux_symm` (line 167) + `splitQuatPairing_antipode_symm` (line 177)
- [x] `splitQuatPairing_nondegenerate` (line 196)
- [x] `octonionPairingAux` (line 239) + `octonionPairing` (line 282)
- [x] `octonionPairingAux_symm` (line 309) + `octonionPairing_antipode_symm` (line 322)
- [x] `octonionPairing_nondegenerate` (line 349) + `antipodePairing_nondegenerate` (line 390)
- [x] `chuEmbed` (line 412) + `chuSpaceOf` (line 422)
- [x] `chu_embed_mul` (line 456) + `chu_zsmul_eq_mul` (line 481)
- [x] `ChuTensor` (line 500), `ChuSeq` (line 517)
- [x] `ChuTensor_assoc` + `ChuSeq_assoc` (lines 500-520)
- [x] `dualize_chuSpaceOf` (line 560) + `star_involutive` (line 568)
- [x] `kkt_stationarity` (line 599) + `kkt_complementarity` (line 614)
- [x] `Chu_distributor` (line 281) — distributor coherence
- [x] `lake build LaserCortex.Chu`

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

DONE. 155 lines (staging/Composition.lean). All definitions + `free_not_quantized`
compile. One `sorry` in `quantized_types_are_exactly_non_meta_logics`.
`lake build LaserCortex.Composition` passes.

- [x] `EvaluatorKind` definition
- [x] `QuantizedType` structure + `quantizedFrictionDensity`
- [x] `CompositionError` inductive
- [x] `CompositionSpec` structure + `CompositionSpec.error`
- [x] `compositionSpec_valid_iff` theorem
- [x] `CompositionSpec.result` definition
- [x] `free_not_quantized` theorem (counterexample: leftComb 22 at CD 4)
- [x] `quantized_types_are_exactly_non_meta_logics` (reverse direction, `opaque`)
- [x] `lake build LaserCortex.Composition`

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

### Stage 0: Algebra.lean — COMPLETE

DONE. 608 lines. All SplitOctonion + SplitQuat definitions and theorems compile.
`lake build LaserCortex.Algebra` passes.

- [x] Q11 quadratic form (signature (2,2))
- [x] Cl11 = CliffordAlgebra Q11
- [x] e₀, e₁ basis elements + Clifford relations (e₀²=1, e₁²=-1, e₀·e₁+e₁·e₀=0)
- [x] SplitQuat type (a, b, c, d)
- [x] SplitQuat.embed: SplitQuat → Cl11
- [x] SplitQuat.norm + norm_mul theorem
- [x] split_quat_mul, split_quat_add, split_quat_neg
- [x] antipode_sq + 7 theorems
- [x] `lake build LaserCortex.Algebra`

### Stage 1: Tamari.lean — COMPLETE

DONE. 392 lines. Full EMLTree theory with normal forms and termination proof.
`lake build LaserCortex.Tamari` passes.

- [x] EMLTree inductive type
- [x] contracts_one (right rotation)
- [x] contracts_to (ReflTransGen)
- [x] rightComb (normal form)
- [x] dcStep (distance measure)
- [x] contracts_to_antisymm
- [x] contracts_to_refl, contracts_to_trans
- [x] contracts_to_size_eq
- [x] contracts_to_leftWeight_ge
- [x] dcStep termination proof
- [x] `lake build LaserCortex.Tamari`

### Stage 2: Friction.lean — COMPLETE

DONE. 126 lines. Core cost definitions + phase change theorems.
`lake build LaserCortex.Friction` passes.

- [x] `assocDefect` definition + `assocDefect_zero_up_to_cd2`
- [x] `commDefect` definition
- [x] `frictionDensity` definition + `frictionDensity_at_cl11_boundary` + `frictionDensity_jump_at_cd3`
- [x] `frictionDensity_ge_k` + `frictionDensity_eq_k_for_k_le_2` + `frictionDensity_monotone`
- [x] `heightMap_discontinuity_at_cd2_3`
- [x] `lake build LaserCortex.Friction`

### Stage 3: OctilinearEmbedding.lean — COMPLETE

DONE. 369 lines. All KKT multiplier + covector projection + tube coordinate
theorems compile. `lake build LaserCortex.OctilinearEmbedding` passes (full
build covers it). Octonion extensions (`kktMultiplierOct`, `covectorProjectionOct`,
`tubeCoordOct`) backward-compatible with quaternion versions proven.

- [x] kktMultiplier: EMLTree → SplitQuat (line 92)
- [x] kktMultiplier_antipode (line 103)
- [x] kktMultiplier_norm (line 112)
- [x] covectorProjection: SplitQuat → ℤ × ℤ (line 135)
- [x] covectorProjection_antipode (line 143)
- [x] covectorProjection_add (line 150)
- [x] tubeCoord: EMLTree → ℤ × ℤ (line 170)
- [x] tubeCoord_expand (line 176)
- [x] tubeCoord_leaf (line 185)
- [x] tubeCoord_node_leaf_leaf (line 192)
- [x] tubeCoord_rightComb (line 201)
- [x] tubeCoord_assoc_step (line 220)
- [x] tubeCoord_cd3_vs_cd2 (line 233)
- [x] tubeCoord_cd_diff (line 247)
- [x] tubeCoord_x_eq_size_plus_assocDefect (line 257)
- [x] tubeCoord_y_eq_leftWeight_sub_rightWeight (line 266)
- [x] kktMultiplierOct (line 300)
- [x] kktMultiplierOct_expand (line 319)
- [x] kktMultiplierOct_antipode (line 329)
- [x] covectorProjectionOct (line 347)
- [x] covectorProjectionOct_antipode (line 357)
- [x] covectorProjectionOct_add (line 366)
- [x] tubeCoordOct (line 381)
- [x] tubeCoordOct_eq_tubeCoord (line 393)
- [x] tubeCoordOct_expand (line 401)
- [x] kktMultiplierOct_pairing_self (line 418)
- [x] kktMultiplierOct_antipode_pairing_self (line 455)
- [x] pairing_signature_phase_change (line 483)
- [x] cd3_nonassociative_signature (line 503)
- [x] `lake build LaserCortex.OctilinearEmbedding`

### Stage 4: Chu.lean — COMPLETE

DONE. 294 lines. All ChuSpace + pairings + algebra homomorphism + duoidal structure
compile. `lake build LaserCortex.Chu` passes.

- [x] ChuSpace structure (line 84) + `primal`/`dual`/`dualize` (91-104)
- [x] `splitQuatPairingAux` (line 122) + `splitQuatPairing` (line 146)
- [x] `splitQuatPairingAux_symm` (line 167) + `splitQuatPairing_antipode_symm` (line 177)
- [x] `splitQuatPairing_nondegenerate` (line 196)
- [x] `octonionPairingAux` (line 239) + `octonionPairing` (line 282)
- [x] `octonionPairingAux_symm` (line 309) + `octonionPairing_antipode_symm` (line 322)
- [x] `octonionPairing_nondegenerate` (line 349) + `antipodePairing_nondegenerate` (line 390)
- [x] `chuEmbed` (line 412) + `chuSpaceOf` (line 422)
- [x] `chu_embed_mul` (line 456) + `chu_zsmul_eq_mul` (line 481)
- [x] `ChuTensor` (line 500), `ChuSeq` (line 517)
- [x] `ChuTensor_assoc` + `ChuSeq_assoc`
- [x] `dualize_chuSpaceOf` (line 560) + `star_involutive` (line 568)
- [x] `kkt_stationarity` (line 599) + `kkt_complementarity` (line 614)
- [x] `Chu_distributor` (line 281) — distributor coherence
- [x] `lake build LaserCortex.Chu`

### Stage 5: Composition.lean — COMPLETE

DONE. 155 lines. All definitions + `free_not_quantized` compile.
One `sorry` in `quantized_types_are_exactly_non_meta_logics`.
`lake build LaserCortex.Composition` passes.

### Stage 6: Full build + cleanup

- [x] Run `lake build` to verify all staging files compile (verified 2026-07-06: `lake build` passes 5965 jobs, zero errors)
- [ ] Remove umbrella `LaserCortex.lean`
- [ ] Remove scaffolding files
- [ ] Update `.gitignore` if needed
- [ ] Commit all changes

### Build-incident postmortem (2026-07-06)

Initial port claimed all 6 files "DONE", but `lake build` revealed 3 of 6 had errors:

| File | Status claimed | Actual |
|------|---------------|--------|
| Algebra.lean | ✅ DONE | ⚠️ `pentagon_defect` coefficient-balance bug; missing `SplitQuat.grade` |
| Tamari.lean | ✅ DONE | ✅ build clean |
| Friction.lean | ✅ DONE | ✅ build clean |
| OctilinearEmbedding.lean | ❌ "Shell created" | ❌ 10+ errors: reserved `λ`, wrong `antipode_sq`, ring arithmetic |
| Chu.lean | ✅ DONE | ❌ `chu_embed_mul` dead `simp`; `Chu_distributor` recursion limit |
| Composition.lean | ✅ DONE | ❌ `opaque` → `axiom` (Inhabited/Nonempty unsynthesizable) |

Root cause: port was verified per-file but not against full `lake build`. After fixes, all 6 build cleanly.

---

## Phase 2: mathlib-contrib → LaserCortex (import migration)

Direction: original LaserCortex files import from `LaserCortex.staging.*`
instead of their original module paths.

### Problem discovered (2026-07-06)

Simple import replacement fails because staging files have different APIs:

| Staging provides | Original files need | Gap |
|---|---|---|
| `assocDefect : ℕ → ℕ` | `layerCost : LogicType → ℕ` | **missing** — simplifies to `ℕ → ℕ` |
| `commDefect : ℕ → ℕ` | (same) | present |
| `frictionDensity : ℕ → ℕ` | (same) | present |
| `frictionDensity_ge_k` | `layerCost_ge_cdStep` | **missing** — different theorem |
| `frictionDensity_monotone` | `heightMap_monotone` | renamed (see below) |
| -- | `frictionLagrangian : Tower p → ℕ` | **missing** — central cost function |
| -- | `flatCostSum` | **missing** |
| -- | `frictionLagrangian_ge_flatSum` | **missing** |
| -- | `frictionLagrangian_gt_flatSum` | **missing** |
| -- | `engine_*` (10 theorems) | **missing** — engine state theory |
| -- | `size_eq_numLeaves_sub_one` | **missing** |
| -- | `Φ_classical_eq_lodayCoord_length` | **missing** |
| -- | `Φ_of_nc_factor_through_lodayCoord_open` | **missing** |

Files affected by import migration:

| Original import | Files using it | Action needed |
|---|---|---|
| `LaserCortex.FrictionLagrangian` | RussellsParadox, LiarParadox, SoritesParadox, TemporalParadox, SplitOctonionLogic, PosetQuotient, TamariBP, Generation, QuantizedType | Port `layerCost`, `frictionLagrangian`, `layerCost_ge_cdStep` to staging/Friction.lean; update imports |
| `LaserCortex.TamariBP` | RussellsParadox, LiarParadox, Generation, RECOVERED_STATE, TropicalCovector, TropicalTamariLattice | Already clean — staging/Tamari.lean provides same API |
| `LaserCortex.Chu` | Entanglement, RECOVERED_STATE | Already clean — staging/Chu.lean provides same API |
| `LaserCortex.TropicalCovector` | TropicalTamariLattice | Source file → keep as-is (circular dependency) |
| `LaserCortex.TropicalTamariLattice` | TropicalCovector | Source file → keep as-is (circular dependency) |
| `LaserCortex.QuantizedType` | RECOVERED_STATE, TropicalTamariLattice | Source file → keep as-is |

### Resolution strategy

**Option A — Port missing definitions to staging (recommended):**

Extend `staging/Friction.lean` with:
1. `layerCost` — simplified from `LogicType → ℕ` to `ℕ → ℕ` (just the CD-component, dropping LogicType parameter since staging doesn't have LogicType)
2. `frictionLagrangian` — simplified from `Tower p → ℕ` to `ℕ → ℕ` (just `frictionDensity` with extra strut contribution)
3. `layerCost_ge_cdStep` — proven from `frictionDensity_ge_k`
4. `heightMap_monotone` — proven from `frictionDensity_monotone`

Then update the 9 scaffolding files to import from staging.

**Option B — Rewrite original files to use simplified API:**

Rewrite paradox files etc. to use `frictionDensity` instead of `layerCost`,
`frictionDensity` instead of `frictionLagrangian`. This is more invasive
and the original files are scaffolding anyway.

### Decision

[ ] Choose Option A or B
[ ] Port missing definitions to staging/Friction.lean
[ ] Update scaffolding imports
[ ] Verify full build with migrated imports
[ ] Remove original files
[ ] Final commit + push

### Stage 7: Research gaps (not code gaps)

These are documented but not yet formalized. Should be stated as
`opaque` or `axiom` in the contribution, not as `sorry`.

- [ ] `continuous_lagrangian_stub` — Lagrangian density
  L(x) = e^{αx} - β ln(x²+ε) - δ (unformalized research gap)
- [ ] Reverse direction of Develin-Sturmfels correspondence

### Sign cocycle formalization (discovered 2026-07-06)

The `pentagon_defect` P(a,b,c) is currently vector-valued in SplitOctonion. However,
for **alternative algebras** (like the octonions), the correct formalization is a
**sign cocycle** φ(a,b,c) = ±1 satisfying:

    φ(b,c,d) · φ(a,bc,d) · φ(a,b,c) = φ(a,b,cd) · φ(ab,c,d)

where
  φ(a,b,c) = +1 if (ab)c = a(bc)  (associative triple)
  φ(a,b,c) = −1 if (ab)c = −a(bc) (anti-associative triple)

The current `pentagon_defect` computes magnitude of non-associativity via the
associator tensor; the sign cocycle would capture the phase information directly.
This distinction matters for:
1. **Split-octonions stop at CD 2** (KernelPolish theorem): the (4,4) signature
   split of the associator does not extend beyond CD 2. The sign cocycle may give
   the correct obstruction theory.
2. **Phase transitions** between quaternion (CD ≤ 2) and octonion (CD ≥ 3) regimes
   are controlled by the sign pattern, not just magnitude.

Status: **Research gap**. Not yet formalized. The current `pentagon_defect` in
Algebra.lean is a placeholder that builds and satisfies the coefficient-balanced
identity, but the sign-cocycle refinement is deferred to future work.

### `SplitQuat.antipode_sq` vs `SplitQuat.grade`

Two distinct involutions on the split quaternion:

| Operation | Effect | Used for |
|-----------|--------|----------|
| `antipode_sq` (Clifford conjugate) | negates a, d; fixes b, c | Norm invariance, algebraic structure |
| `SplitQuat.grade` (grade involution) | fixes a, d; negates b, c | Geometric covector projection |

The confusion in OctilinearEmbedding.lean arose because `antipode_sq` was
used where the grade involution was semantically required. The octonion
`antipode` correctly fixes e₄ (even grade) and negates e₅, e₆, e₇ (odd grade),
but `antipode_sq` on SplitQuat additionally negates d (even-grade scalar),
making it a Clifford conjugate rather than a pure grade involution.

**Decision**: SplitQuat now exports both operations. OctilinearEmbedding uses
`SplitQuat.grade`. This distinction is documented in `covectorProjection_antipode`.
