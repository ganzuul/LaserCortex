# 017: Cayley-Dickson Uplift — The Inductive Bias of Generation

**Date**: 2026-06-28  
**Status**: Exploration (no code changes to modules)  
**Build**: `lake build` passes with `antipode_mul` and `antipode_fixed_point_reserves_pool` as `sorry`  
**Commits**: `924b5d9` on `graphiti-integration`

---

## 1. The Attempt: SO = CD(SQ, γ) with Componentwise Mapping

### Setup

Given the split-octonion SO = ⟨e₀..e₇⟩ and split-quaternion SQ = ⟨a,b,c,d⟩ with i² = -1, j² = +1, k² = +1, we tested the Cayley-Dickson conjecture:

> **SO ≅ CD(SQ)** as ℤ-algebras, where CD(A) = A × A with the standard CD multiplication.

The simplest mapping:
```
First CD component  = (e₀, e₁, e₂, e₃)  ∈ SQ  (associative sector)
Second CD component = (e₄, e₅, e₆, e₇)  ∈ SQ  (split sector)
```

### The CD Multiplication Formula (γ = +1)

The standard CD formula with conjugation conj(a,b,c,d) = (a, -b, -c, -d):

```
(a,b)(c,d) = (ac + d̅·b,  d·a + b·c̅)
```

Where `ac` = SQ multiplication of first components, `d̅·b` = conj(last4-of-y) × last4-of-x, etc.

### Result: 16/64 Basis Pairs Disagree

Of the 64 basis product pairs eᵢ·eⱼ, **16 showed sign flips**. All involve the j,k basis elements:

| Pair | SO result | CD result | delta |
|------|-----------|-----------|-------|
| e₂·e₂ | -1 (j² = -1) | +1 (j² = +1 in SQ) | sign flip |
| e₃·e₃ | -1 (k² = -1) | +1 (k² = +1 in SQ) | sign flip |
| e₆·e₆ | +1 (J² = +1) | -1 (j² = -1 via CD) | sign flip |
| e₇·e₇ | +1 (K² = +1) | -1 (k² = -1 via CD) | sign flip |
| e₂·e₃ | +e₁ | -e₁ | sign flip |
| e₃·e₂ | -e₁ | +e₁ | sign flip |
| e₆·e₇ | +e₁ (in e₁ comp) | -e₁ | sign flip |
| e₇·e₆ | -e₁ | +e₁ | sign flip |
| e₂·e₆ | -e₄ | +e₄ | sign flip |
| e₆·e₂ | +e₄ | -e₄ | sign flip |
| e₂·e₇ | -e₅ | +e₅ | sign flip |
| e₇·e₂ | +e₅ | -e₅ | sign flip |
| e₃·e₆ | +e₅ | -e₅ | sign flip |
| e₆·e₃ | -e₅ | +e₅ | sign flip |
| e₃·e₇ | -e₄ | +e₄ | sign flip |
| e₇·e₃ | +e₄ | -e₄ | sign flip |

Every non-i imaginary component (j and k) has its square flipped between the two structures.

---

## 2. Root Cause: SO Has TWO Different 4D Multiplication Tables

The split-octonion's 64-term multiplication hides a duality:

| Sector | Basis | i² | j² | k² | Algebra Type |
|--------|-------|----|----|----|--------------|
| First 4 (e₀..e₃) | 1, e₁, e₂, e₃ | -1 | -1 | -1 | **ℚ[ℤ]** — quaternionic (all neg) |
| Last 4 (e₄..e₇) | e₄, e₅, e₆, e₇ | +1 | +1 | +1 | **Split-quaternionic** (all pos) |
| Our SQ | 1, i, j, k | -1 | +1 | +1 | **Mixed** — composition algebra |

**Key insight**: SO's first 4 components use a **different 4D algebra** than our SQ. They're the *standard quaternion ring* ℚ = ℍ[ℤ] where every imaginary unit squares to -1. Our SQ has mixed signs because it's a (2,2) composition algebra, not the (4,0) quaternions.

This means **SO is NOT CD(SQ) with a single base algebra**. It's more like:

```
SO = CD(ℚ, SQ̅)
```

Where ℚ = ⟨1,i,j,k⟩ with i²=j²=k²=-1, and SQ̅ has the "split" multiplication (i²=-1, j²=+1, k²=+1) — but with the basis relabeled so that the CD mixing terms involve the correct cross-term signs.

The CD construction pairs **two different 4D structures**: the compact quaternionic sector (associative, time-like) with the split-quaternionic sector (associative but with zero divisors, space-like).

---

## 3. The Uplift Conjecture: Generation as a CD Functor

### The Core Observation

If SO pairs two different 4D algebras (ℚ and SQ̅), then **we can move between them via the CD doubling**:

```
ℚ → CD(ℚ, something) → SQ (as projection)
SQ → CD(SQ, something) → something else
```

But more importantly:

```
SQ → resolveSO(SQ) → ℚ
```

If we can **embed SQ into SO** (via the second sector) and then **project the first sector**, we get ℚ back. The Generation process (WFC) is the "something else" that performs this uplift.

### The Inductive Bias

This gives us a primitive for inductive bias:

> **Given a split algebra A, we can generate its compact form B by:**
> 1. Embed A into the "space-like" sector of the CD double CD(B, A)
> 2. Apply Generation (Wave Function Collapse) to the double
> 3. Project the "time-like" sector to obtain B

Or diagrammatically:

```
A ──embed──→ CD(B, A) ──resolve──→ B
```

Where the double is the **total space** that contains both structures, and Generation finds the most coherent path between them.

### Connection to Our Architecture

- `resolveSQ: SplitOctonion → SplitQuat` projects the associative sector to SQ
- The reverse would be an **embedding** `embedSQ: SplitQuat → SplitOctonion` mapping SQ into the split sector
- The **Generation** process (EMLTree collapse / TamariBP contraction) provides the non-deterministic search that bridges the two
- The cost function Φ measures the "distance" between the two structures

### Why This Matters

If this holds, it indicates a **group theory for Cayley-Dickson constructions**:

1. **Objects**: Composition algebras over ℤ (ℝ, ℂ, ℍ, 𝕆, and their split forms)
2. **Morphisms**: CD doubling and projection functors
3. **Group structure**: A Galois-like correspondence between subalgebras and the CD tower

The CD tower becomes a **lattice** (not just a chain) because at each step we can choose the compact or split form of the base algebra. The uplift primitive moves between these choices.

---

## 4. Connection to the Existing Framework

### TamariBP

The `dcStep` measure in TamariBP counts associator rotations. The CD construction introduces non-associativity precisely at the third step (ℍ → 𝕆). The **boundedness** of SO→SQ resolution is bounded by how many associator corrections the CD generator introduces — exactly what `BoundednessClass` tracks.

### The Pentagonator

The pentagon defect measures the failure of the Mac Lane pentagon identity. In CD terms, it's the obstruction to the CD multiplication being associative — which is zero for the first two CD steps (ℝ→ℂ→ℍ) and non-zero for the third (ℍ→𝕆). The timespace decomposition splits it into:
- **Commutator part** (time-like): handled by the ℚ subalgebra (associative, commutative)
- **Associator part** (space-like): handled by the SQ̅ subalgebra (non-associative, zero divisors)

---

## 5. Next Steps

1. **Formalize ℚ = ℍ[ℤ]**: Define a quaternion ring over ℤ with all i²=j²=k²=-1. This is our "compact" associative sector.
2. **Prove the CDouble formula by computation**: Use `native_decide` to verify that `SplitOctonion ≅ CDouble(ℚ, SQ)` with the correct basis mapping (which will involve sign changes on j,k).
3. **Build the embedding `SQ → SplitOctonion`**: Map SQ into the e₄..e₇ sector, giving us the "uplift" path.
4. **Conjecture the CD Galois correspondence**: Document the lattice of subalgebras of CD doubles and the projection/embedding functors.

---

## Appendix: Verification Script

The Python verification script used to identify all 16 errors:

```python
def sq_mul(p, q):
    # Split-quaternion multiplication with i²=-1, j²=+1, k²=+1
    a1,b1,c1,d1 = p; a2,b2,c2,d2 = q
    return (a1*a2 - b1*b2 + c1*c2 + d1*d2,
            a1*b2 + b1*a2 - c1*d2 + d1*c2,
            a1*c2 - b1*d2 + c1*a2 + d1*b2,
            a1*d2 + b1*c2 - c1*b2 + d1*a2)

def cd_mul(x, y):
    # CD formula with γ=+1: (a,b)(c,d) = (ac + d̅·b, d·a + b·c̅)
    (a,b), (c,d) = x, y
    conj = lambda z: (z[0], -z[1], -z[2], -z[3])
    first = sq_add(sq_mul(a, c), sq_mul(conj(d), b))
    second = sq_add(sq_mul(d, a), sq_mul(b, conj(c)))
    return (first, second)
```

The 16 errors all involve the j/k components (indices 2,3 in the first 4, indices 6,7 in the second 4), with consistent sign flips.
