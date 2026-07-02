# Split-Octonion to Laser Mode Dictionary

**Status**: Stub — mapping proposed, formalization deferred  
**Prerequisites**: `SplitOctonionCost.lean`, `SplitQuaternionClifford.lean`, `Chu.lean` §9  
**Source**: `lab_notes/023_cd_homotopy_bridge_chu_pythagoras_nuclear_metastability.md` §7.4

---

## 1. Purpose

This document maps the 8-dimensional split-octonion algebra (the `SplitOctonion`
type in `SplitOctonionCost.lean`) to the physical parameters of a tuned X-ray
laser cavity. The mapping is the **bridge to observables**: it turns algebraic
properties (`strut_weight = 4`, `assocDefect`, `splitQuatPairing`) into
experimentally measurable quantities (laser frequency, polarization, cavity
mode structure).

When complete, the dictionary should support a theorem of the form:

> **Isomer Triggering Theorem** (conjecture):  
> If an X‑ray laser mode `L` is tuned to the Chu resonance frequency  
> `ω_L = β(γ, S(γ))` where `γ` is the isomer's split‑octonion defect,  
> then the transition rate `Γ(L → isomer)` is non‑zero and given by  
> the `branch_lightening_strict` bound.

---

## 2. The 8 Generators

### 2.1 Compact Associative Sector (e₀…e₃)

These form the quaternion subalgebra ℍ — the compact, associative subspace
where the commutator acts but the associator is silent. In the laser cavity,
they define the **polarization basis** and **transverse mode structure**.

| Generator | Algebraic role | Laser analogue | Formal connection |
|-----------|---------------|----------------|-------------------|
| e₀ | Scalar (norm) | Phase/frequency carrier  `ω₀` | `e0_sq = 1` → the vacuum state normalization |
| e₁ | Imaginary i (space-like Cl(1,1)) | TEM₀₁ mode — vertical polarization | `e₁² = -1` → π phase shift on reflection |
| e₂ | Imaginary j (time-like Cl(1,1)) | TEM₁₀ mode — horizontal polarization | `e₂² = +1` → no phase shift (split axis) |
| e₃ | k = e₁·e₂ | Helicity basis (σ⁺/σ⁻) | `anticommute(e₁, e₂) = 0` → orthogonal modes |

**What to prove**: The Cl(1,1) gamma matrices (e₁ as σₓ, e₂ as iσᵧ, e₃ as σ₂)
act on the laser polarization spinor via the Pauli algebra. The `e0_sq = 1`
relation is the on‑shell condition `ω² = k²c²` for the photon.

### 2.2 The CD Generator (e₄ = ω)

This is the Cayley‑Dickson generator — the element that doubles the quaternion
algebra to the octonions. It is the **trigger operator**: the X‑ray photon
creation/annihilation operator that couples the compact (laser) sector to the
split (isomer) sector.

| Generator | Algebraic role | Laser analogue | Formal connection |
|-----------|---------------|----------------|-------------------|
| e₄ = ω | CD generator; ω² = +1 (split) | Photon creation operator a† | `ω_sq` theorem → a†a + aa† = 1 (canonical commutation) |
| ω anticommutes with e₁, e₂, e₃ | ωeᵢ = −eᵢω for i=1,2,3 | Photon polarization coupling | The anticommutation is the spin‑1 selection rule ΔJ = 1 |

**What to prove**: The anticommutation `ω·eᵢ + eᵢ·ω = 0` mirrors the canonical
anticommutation `{a, a†} = 1` of fermionic creation/annihilation operators
(though photons are bosons — the analogy is structural, not literal). More
precisely, `ω` acts as a **grading involution** that distinguishes the
associative (time) sector from the split (space) sector.

### 2.3 The Split Sector (e₅, e₆, e₇)

These generators extend the (4,4) signature from the quaternion basis. They
parameterize the **isomer's internal structure** — the topological defect that
stores the 2.44 MeV as non‑associative curvature.

| Generator | Algebraic role | Laser analogue | Formal connection |
|-----------|---------------|----------------|-------------------|
| e₅ | Split extension along e₁ | Transverse mode coupling coefficient κ | `strut_weight(e₁,e₂,e₄) = 4` → max coupling |
| e₆ | Split extension along e₂ | Cavity detuning δω | `assocDefect(e₁,e₂,e₆) = 3.1` → off‑resonance loss |
| e₇ | Split extension along e₃ | Nonlinear mixing channel χ⁽²⁾ | Non‑associativity → three‑wave mixing phase matching |

**What to prove**: The `strut_weight = 4` theorem (`SplitOctonionCost.lean`)
is the upper bound on the transverse mode coupling. The `assocDefect` values
for triples (e₁, e₂, e₄), (e₁, e₂, e₅), etc. define the tuning curve — the
bandwidth over which triggering is possible.

---

## 3. The Chu Resonance Condition

The central mapping is the **Chu pairing as resonance condition**:

```
Algebra:      β(x, S(x))  =  N(x)
Laser:        ω_laser  =  E_isomer / ħ
Connection:   The Chu pairing nondegeneracy (splitQuatPairing_nondegenerate)
              guarantees β(x, S(x)) ≠ 0 for x ≠ 0 — the resonance exists.
```

| Chu quantity | Laser observable | Source theorem |
|-------------|-----------------|----------------|
| `β(y, z)` | Transition matrix element | `splitQuatPairing` definition |
| `β(y, z) = 0` | Forbidden transition | `zdKernel` — null space of the pairing |
| `chu_embed_mul` | KKT stationarity = resonance matching | `Chu.chu_embed_mul` |
| `zdFreeAtStep α k` | Below/above triggering threshold | `CDParameter.zdFreeAtStep` |

---

## 4. Open Proof Obligations

The following must be proven to make the dictionary load‑bearing:

1. **[HIGH]** Prove that the Cl(1,1) gamma matrices (e₁, e₂, e₃) satisfy the
   Pauli algebra σᵢσⱼ = δᵢⱼ + iεᵢⱼₖσₖ in the split signature, and thus
   act on a 2‑component laser polarization spinor.

2. **[HIGH]** Prove that the anticommutation `ω·eᵢ + eᵢ·ω = 0` implies a
   selection rule ΔJ = 1, matching the electromagnetic dipole operator.

3. **[MEDIUM]** Derive the resonance lineshape from `norm_via_pairing_mul`:
   the composition algebra identity `N(xy) = N(x)N(y)` gives the frequency
   matching condition `ω_laser² = ω_isomer² + (bandgap)²`.

4. **[LOW]** Compute the `assocDefect` bandwidth for the (e₁, e₂, e₄)
   triple — the width of the resonance peak in keV — from the
   `strut_weight = 4` bound and the CD tower index.

---

## 5. Related Files

- `LaserCortex/SplitOctonionCost.lean` — strut_weight, assocDefect, split_oct_mul
- `LaserCortex/SplitQuaternionClifford.lean` — Cl(1,1) basis, e0_sq, e1_sq, anticommute
- `LaserCortex/Chu.lean` — SECTION 9: CD‑homotopy bridge, norm_via_pairing
- `LaserCortex/CayleyDickson.lean` — SECTION 5: CDParameter, CDHomotopyPath
- `lab_notes/023_cd_homotopy_bridge_chu_pythagoras_nuclear_metastability.md` — physical context
