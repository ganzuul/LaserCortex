# Born Test / Calibration Ladder Expansion

**Date**: 2026-06-28
**Status**: Planned — ready for Phase A implementation

---

## Overview

The goal is to build a formal Lean chain that:

1. **Completes `SplitQuaternionClifford.lean`** — adds multiplication and proves the composition algebra property `norm_mul` on split-quaternions over ℤ.
2. **Rewrites `BornTest.lean`** — replaces the ℂ-based Born rule sketch with a split-quaternion Born theory using the (2,2) norm. This becomes the staging ground for the metric-space interpretation of the calibration ladder.
3. **Adds `antipode_preserves_norm` to `Hopf.lean`** — the (4,4) norm is antipode-invariant, extending the Born rule to split-octonions.

The connecting thread: **the antipode preserves the norm at every level of the Cayley-Dickson ladder**, making the Born probability a metric-space invariant of the institutional closure algebra.

---

## Phase A: Complete `SplitQuaternionClifford.lean` (~40 lines)

**Files**: `LaserCortex/SplitQuaternionClifford.lean`

### A1: Multiplication table for `SplitQuat`
Basis `{1, i, j, k}` with:
- i² = -1, j² = +1, k² = +1
- ij = k = -ji, jk = -i = -kj, ki = j = -ik

The 16-term product (by bilinearity):
```
(a1 + b1·i + c1·j + d1·k) * (a2 + b2·i + c2·j + d2·k) =
  (a1·a2 − b1·b2 + c1·c2 + d1·d2)       — scalar
+ (a1·b2 + b1·a2 − c1·d2 + d1·c2) · i    — i
+ (a1·c2 − b1·d2 + c1·a2 + d1·b2) · j    — j
+ (a1·d2 + b1·c2 − c1·b2 + d1·a2) · k    — k
```

### A2: Algebraic instances
- `Mul`, `Add`, `AddCommGroup` instances (following the pattern in `Hopf.lean` for `SplitOctonion`)

### A3: `norm_mul` theorem
```
norm(x·y) = norm(x) · norm(y)
```
where `norm(a,b,c,d) = a² + b² − c² − d²` (the (2,2) signature).

Proof: `native_decide` on the 8-variable polynomial identity (verified numerically on 100 random ℤ inputs).

This formally confirms the composition algebra property, matching `test_norm_multiplicativity` in `test_split_quaternion_calibration.py`.

### A4: SQ antipode
```
def antipode_sq (q : SplitQuat) : SplitQuat :=
  { a := q.a, b := -q.b, c := -q.c, d := -q.d }
```

The SQ antipode negates the imaginary axes (i, j, k) and fixes the scalar (1). This is the grading involution for the ℤ/2-grading on the split-quaternion composition algebra.

**SQ pentagonator note**: The split-quaternions are associative (CD step 2'), so the pentagon defect vanishes identically — the associator is zero everywhere. However, the SQ ANTIPODE may generate non-trivial pentagonator curvature when the zero-divisor structure interacts with the (2,2) norm. This is the "special pentagonator" — the antipode as a source of pentagon-like coherence obstruction on the zero-divisor boundary, distinct from the non-associative pentagonator that appears at CD step 3 (split-octonions).

The formal investigation of the SQ antipode pentagonator is beyond this plan but worth noting for future work.

---

## Phase B: Rewrite `BornTest.lean` (~60 lines)

**Files**: `LaserCortex/BornTest.lean`

### B1: Born probability on SQ
```lean4
def born_probability (q : SplitQuat) : ℕ := (q.norm.natAbs)
```

### B2: Basic theorems
- `born_nonneg`: `0 ≤ (born_probability q : ℤ)`
- `born_normalized`: `q.norm = 1 → born_probability q = 1`
- `born_zero_on_null`: `q.norm = 0 → born_probability q = 0`
- `born_mul`: `born_probability (x * y) = born_probability x * born_probability y`

### B3: Antipode invariance
```lean4
theorem antipode_sq_preserves_born (q : SplitQuat) :
    born_probability (antipode_sq q) = born_probability q := ...
```
Proof: since `antipode_sq` negates b, c, d, the (2,2) norm uses squares, which kill the sign.

### B4: Metric space interpretation
The `born_probability` defines a metric on the SQ parameter space:
- distance `d(x,y) = born_probability (x - y)`
- invariant under the antipode: `d(S(x), S(y)) = d(x, y)`

---

## Phase C: `Hopf.lean` additions (~25 lines)

**Files**: `LaserCortex/Hopf.lean`

### C1: antipode preserves the (4,4) norm
```lean4
theorem antipode_preserves_norm (x : SplitOctonion) :
    octonion_norm (antipode x) = octonion_norm x := by
  simp [antipode, octonion_norm]
```

### C2: Cost-space antipode invariance
```lean4
theorem cost_born_antipode_invariant (nc : Cost.NodeCost) :
    (octonion_norm (antipode (toSO nc))).natAbs = (octonion_norm (toSO nc)).natAbs := ...
```

This extends the SQ Born invariance to the full 8D cost space.

### C3: CD extension note
Document that Q22 (SQ, 4D) extends to Q44 (SO, 8D) via Cayley-Dickson doubling, and that the antipode preserves the norm at every level.

---

## Calibration ladder tie-in

| Level | Algebra | Norm | Antipode | Python test | Lean file |
|-------|---------|------|----------|-------------|-----------|
| 2' | Split-quaternions ℍ̃ | (2,2) Q22 | `antipode_sq` negates i,j,k | `test_split_quaternion_calibration.py` | `SplitQuaternionClifford.lean` + `BornTest.lean` |
| 3  | Split-octonions 𝕆ˢ | (4,4) Q44 | `antipode` negates e₁,e₂,e₃,e₅,e₆,e₇ | `test_cayley_dickson_ladder.py` | `Hopf.lean` |
| —  | Spacetime logic | Φ cost | reserveGuard as e₀-detector | `test_torus_knot_calibration.py` | `AMM.lean` + `Hopf.lean` §6 |

---

## Implementation order

1. **Phase A** (SplitQuaternionClifford — `Mul` + `norm_mul`)
2. **Phase B** (BornTest — SQ Born rule)
3. **Phase C** (Hopf — norm invariance)

Total: ~125 lines of Lean, all `simp`/`native_decide`/`ring`, zero new `sorry`.
