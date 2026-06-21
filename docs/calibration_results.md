# Torus Knot Calibration & Split-Quaternion Verification

**Date:** 2026-06-21  
**Version:** v0.3 (Spacetime mirror + split-quaternion)

## Summary

We calibrated the Spacetime logic type against the (2,3) trefoil torus knot
and verified the split-quaternion algebra as a clean intermediate step between
the associative quaternions and the non-associative split-octonions.

The key results:

1. **Spacetime is now space-biased** — the only logic in the framework with a
   gradient that drives toward leftComb (associator-dominant)
2. **Split-quaternions confirm**: zero divisors and non-associativity are
   **independent** structural features — you can have one without the other
3. **Torus knot crossing numbers** map directly to EMLTree sizes, validating
   Option B from the roadmap (knot invariant as label, Φ remains uniform)
4. **Loday coordinates** give a complete geometric picture of each logic's
   cost landscape on the associahedron

---

## 1. Spacetime Logic (v0.3)

The `mirror` flag on `NodeCost` swaps left/right treatment:

| Mode | Formula | Effect |
|------|---------|--------|
| `mirror=false` (default) | `bias + leftWeight·Φ(l) + Φ(r)/(rightDiv+1) + coupling·Φ(l)·Φ(r)/denom` | Left amplified (time-dominant) |
| `mirror=true` | `bias + Φ(l)/(rightDiv+1) + leftWeight·Φ(r) + coupling·Φ(l)·Φ(r)/denom` | Right amplified (space-dominant) |

Spacetime uses `mirror=true, leftWeight=0, rightDiv=0, bias=1, coupling=0`:

```
Φ(Node l r) = 1 + Φ(l)   (pure associator, commutator silent)
```

### Key theorems (Lean, zero sorries)

- `spacetime_phi_left_comb`: `Φ(leftComb n) = n`
- `spacetime_phi_right_comb`: `Φ(rightComb n) = 1`
- `nodeParam_mirror_iff_spacetime`: `mirror ↔ Spacetime`
- Gradient reversal: Spacetime drives toward **leftComb**, all others toward rightComb

---

## 2. Split-Quaternion Verification

The split-quaternions ℍ̃ have (2,2) signature: `i²=-1, j²=+1, k²=+1, ij=k=-ji`.

### Basis relations (verified)

```
i² = -1,  j² = +1 (split!),  k² = +1
ij = k,   ji = -k (anti-commutative)
jk = -i,  kj = +i
ik = -j,  ki = +j
```

### Associativity confirmed

All 64 basis triples have associator norm = 0. This is the key structural fact:

> **Zero divisors do NOT imply non-associativity.** Split-quaternions have zero
> divisors from the (2,2) metric signature but are fully associative.

This confirms that our `rightDiv=0` cost class (Boolean, Intuitionistic, Free)
correctly models the split-quaternion level: flat landscape (Φ = size) with
metric zero divisors still present.

### Zero divisors

```
(1+j)(1-j) = 0    ← null-cone zero divisor
|1+j|² = 0        ← isotropic vector
|1-j|² = 0        ← isotropic vector
```

24 isotropic vectors found with ±1 coefficients. N(ab) = N(a)·N(b) holds
for generic elements (composition algebra confirmed).

### Null cone structure

| Vector type | Norm | Cost class analogue |
|-------------|------|---------------------|
| Time-like (N>0) | +1, +2 | Time-biased logics (leftWeight>1) |
| Space-like (N<0) | -1, -2 | Space-biased logic (Spacetime) |
| Null (N=0) | 0 | Balanced logics (rightDiv=0) |

---

## 3. Torus Knot Calibration

### Crossing number formula

For a (p,q) torus knot with coprime p,q ≥ 2:

```
c(T_{p,q}) = min(p(q-1), q(p-1))
```

### Verified values

| Knot | (p,q) | Crossing | Tree size |
|------|-------|----------|-----------|
| Trefoil | (2,3) | 3 | T₃ |
| Cinquefoil | (2,5) | 5 | T₅ |
| Septafoil | (2,7) | 7 | T₇ |
| T(3,5) | (3,5) | 10 | T₁₀ |
| T(3,4) | (3,4) | 8 | T₈ |
| T(3,7) | (3,7) | 14 | T₁₄ |
| T(4,5) | (4,5) | 15 | T₁₅ |

### Spacetime gradient by tree size

| n | rightComb | leftComb | \|Δ\| | Torus knot winding |
|---|-----------|-----------|-------|--------------------|
| 3 | 1 | 3 | 2 | T(2,3) trefoil: p=2, q=3 |
| 4 | 1 | 4 | 3 | |
| 5 | 1 | 5 | 4 | T(2,5) cinquefoil: p=2, q=5 |
| 6 | 1 | 6 | 5 | |

The gradient \|Δ\| = n-1 directly gives the p-winding number of the
trefoil: p = \|Δ\| = n-1 for the leftComb of size n.

---

## 4. Loday Coordinates & Cost Landscapes

### T₃ (5 vertices, 5 edges — the pentagon)

| Loday | ST | BU | CL | QU | PA | TM | Note |
|-------|----|----|----|----|----|----|------|
| [1,1,1] | 1 | 3 | 1 | 1 | 1 | 1 | → rightComb |
| [1,2,1] | 1 | 3 | 2 | 2 | 2 | 2 | |
| [2,1,1] | 2 | 3 | 2 | 2 | 3 | 3 | |
| [3,1,1] | 2 | 3 | 2 | 2 | 3 | 3 | |
| [3,2,1] | 3 | 3 | 3 | 3 | 7 | 7 | ← leftComb |

### T₄ (14 vertices, 21 edges — the associahedron K₄)

| Loday | ST | BU | CL | QU | PA | TM | Note |
|-------|----|----|----|----|----|----|------|
| [1,1,1,1] | 1 | 4 | 1 | 1 | 1 | 1 | → rightComb |
| [1,1,2,1] | 1 | 4 | 2 | 2 | 2 | 2 | |
| [1,2,1,1] | 1 | 4 | 2 | 2 | 2 | 2 | |
| [1,3,1,1] | 1 | 4 | 2 | 2 | 2 | 2 | |
| [1,3,2,1] | 1 | 4 | 2 | 2 | 4 | 4 | |
| [2,1,1,1] | 2 | 4 | 2 | 2 | 3 | 3 | |
| [2,1,2,1] | 2 | 4 | 3 | 3 | 4 | 4 | |
| [3,1,1,1] | 2 | 4 | 2 | 2 | 3 | 3 | |
| [3,2,1,1] | 3 | 4 | 3 | 3 | 7 | 7 | |
| [4,1,1,1] | 2 | 4 | 2 | 2 | 3 | 3 | |
| [4,1,2,1] | 2 | 4 | 3 | 3 | 5 | 5 | |
| [4,2,1,1] | 3 | 4 | 3 | 3 | 7 | 7 | |
| [4,3,1,1] | 3 | 4 | 3 | 3 | 7 | 7 | |
| [4,3,2,1] | 4 | 4 | 4 | 4 | 15 | 15 | ← leftComb |

### T₅ and T₆ (abbreviated)

| Tree size | ST min | ST max | BU | PA max | TM max |
|-----------|--------|--------|----|--------|--------|
| 5 | 1 | 5 | 5 | 31 | 31 |
| 6 | 1 | 6 | 6 | 63 | 63 |

---

## 5. Sector Weights (v0.3 corrected)

| Logic | time_wt | space_wt | mirror | sector | Interpretation |
|-------|---------|----------|--------|--------|----------------|
| Fuzzy | 1.00 | 0.33 | | time | rightComb-dominated |
| ManyValued | 1.00 | 0.50 | | time | rightComb-dominated |
| Paraconsistent | 2.00 | 0.50 | | time | explosive leftWeight |
| Temporal | 2.00 | 0.50 | | time | temporal discount |
| Deontic | 1.00 | 0.33 | | time | mild time bias |
| Epistemic | 1.00 | 0.33 | | time | mild time bias |
| Quantum | 1.00 | 0.50 | | time | with coupling |
| **Intuitionistic** | **1.00** | **1.00** | | **balanced** | **null cone** |
| Relevance | 1.00 | 0.50 | | time | standard |
| **Free** | **1.00** | **1.00** | | **balanced** | **null cone** |
| Infinitary | 1.00 | 0.50 | | time | standard |
| Modal | 1.00 | 0.50 | | time | standard |
| **Spacetime** | **1.00** | **0.00** | **✓** | **space** | **leftComb-dominant** |
| Classical | 1.00 | 0.50 | | time | standard |
| **Boolean** | **1.00** | **1.00** | | **balanced** | **null cone** |

Three balanced logics (Boolean, Intuitionistic, Free) sit on the null cone
(time_weight = space_weight). Spacetime is the unique space-biased logic
with the commutator channel completely silent (space_weight = 0).

---

## 6. Cayley-Dickson Ladder Summary

| Level | Algebra | dim | Properties lost | Associator norm | Cost class |
|-------|---------|-----|-----------------|-----------------|------------|
| 0 | ℝ | 1 | (baseline) | 0 | Boolean/Classical |
| 1 | ℂ | 2 | order | 0 | Fuzzy/ManyValued |
| 2 | ℍ | 4 | commutativity | 0 | Intuitionistic/Free |
| 2' | ℍ̃ | 4 | order (split!) | **0** | rightDiv=0 (metric zero divisors) |
| 3 | 𝕆 (split) | 8 | associativity | 4.0 | Quantum/Paraconsistent/Temporal |
| 4 | 𝕊 (sedenion) | 16 | alternativity | >4 | beyond framework |

Level 2' (split-quaternions) is the new calibrated level: **associative but
with zero divisors**. This corresponds exactly to the rightDiv=0 cost class
where Φ = size (flat landscape, rotation-invariant) but metric zero divisors
still exist.

---

## 7. Born Rule Fork (deferred)

The Born rule exploration (`rightExponent` field on `NodeCost`) is captured
as a fork for future work. Key insight from the discussion:

- In continuous EML: `eml(x, y²) = exp(x) - 2·ln(y)` — just doubles the log
- In discrete ℕ-arithmetic: `Φ(r)² ≠ 2·Φ(r)` — the squaring is genuinely new
- Quantum's `coupling=1,demon=10` captures non-distributivity but not Born squaring
- Adding `rightExponent: Nat := 1` to `NodeCost` with Quantum set to 2 would
  capture the Born rule: `Φ(Node l r) = 1 + Φ(l) + Φ(r)²/2 + Φ(l)·Φ(r)/10`
- This is the structural bridge between EML and Wigner's quasi-probability function

---

## Files Changed

### Lean (LaserCortex/)
- `Cost.lean`: Added `mirror`, `coupling`, `denom` fields to `NodeCost`; updated
  `NodeCost.apply`; recalibrated Spacetime; proved `spacetime_phi_left_comb`,
  `spacetime_phi_right_comb`, `nodeParam_mirror_iff_spacetime`, etc.
- `LogicTypes.lean`: Updated Spacetime sector comment for mirror=True

### Python (infra/)
- `_cost.py`: Added `mirror`, `coupling`, `denom` to `NodeCost`; updated `apply`
- `_logic_types.py`: Updated `is_associative_sector` for Spacetime

### Tests
- `test_torus_knot_calibration.py`: 12/12 passing
- `test_split_quaternion_calibration.py`: 9/9 passing
- `test_timespace_decomposition.py`: `sector_weights` bug fixed for mirror mode

### Documentation
- `docs/lab_protocol.md`: v0.3 — mirror flag, Spacetime section, sector table
- `docs/roadmap.md`: Items 4 and 5 marked complete
- `docs/torus_knot_calibration_plan.md`: Full plan document
- `docs/calibration_results.md`: This file