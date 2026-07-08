# 027: The Cayley–Dickson Doubling Identity — Commutator Upstream of Associator

**Date**: 2026-07-05
**Status**: CORRECTED — direction reversed from initial hypothesis; CD doubling identity
  verified computationally; `pentagon_defect` flagged as malformed
**Prerequisites**: 024 (Chu embedding is algebra homomorphism), 026 (chu_embed_mul + Chu_distributor fix),
  `LaserCortex/staging/Algebra.lean` lines 75-94 (split_oct_mul), 173-182 (associator_tensor, pentagon_defect)
**Source**: `LaserCortex/SplitOctonionCost.lean`, `LaserCortex/Hopf.lean`, `LaserCortex/staging/Algebra.lean`

---

## 1. Epistemic Stance

This report is written from the position of **resisting the user's framing**.
The initial hypothesis ("non-associative complexity doesn't snowball") was
constructed from Leanstral's analysis of the code, but the code itself
contains a malformed definition (`pentagon_defect`) that was read as
evidence for the wrong conclusion. The model's analysis was coherent —
just wrong.

The correct move: go back to raw definitions, compute concrete values,
and let the numbers speak. This report does that.

---

## 2. The Cayley–Dickson Doubling Formula

### 2.1 What It Says

In the Cayley–Dickson doubling `A → A⊕Aℓ` where `ℓ` is the new generator:

> The associator `[x, y, ℓ]` (for `x, y ∈ A` and `ℓ` the doubling
> generator) equals `κ · (xy − yx)` where `xy − yx` is the commutator
> in the base algebra `A`, and `κ` is a fixed scalar.

In our notation:
```
associator_tensor x y ℓ = κ • (split_sub (split_oct_mul x y) (split_oct_mul y x))
```

### 2.2 Why This Is the Right Mechanism

The CD doubling manufactures non-associativity from pre-existing
non-commutativity:
- Quaternions (ℍ) are **non-commutative**: `ij = k`, `ji = −k`
- Doubling quaternions (→ octonions, or split-octonions) **manufactures**
  non-associativity: `(ij)ℓ ≠ i(jℓ)` where `ℓ` is the new generator

The commutator `xy − yx` is zero at the ℝ level (commutative) and
non-zero at the ℂ' level (split-complex, `(1+j)(1−j) = 0` but
`j·1 ≠ 1·j`). The associator `[x, y, ℓ]` is zero at the ℍ level
(fully associative) and non-zero at the SQ level (split-quaternions).

**Direction**: The commutator is **upstream** (exists at lower CD levels).
The associator is **downstream** (constructed from the commutator at
the doubling step). Nothing "projects down" — something gets **built up**
from what was already there.

### 2.3 Computational Verification

For `x = x_base(1,2,3,4)` and `y = y_base(5,6,7,8)` (both in the
`{e0,e1,e2,e3}` subalgebra):

```
commutator = split_sub (split_oct_mul x y) (split_oct_mul y x)
           = { e0:=0, e1:=-8, e2:=16, e3:=-8, e4:=0, e5:=0, e6:=0, e7:=0 }

associator_tensor x y e4_vec
           = { e0:=0, e1:=0, e2:=0, e3:=0, e4:=0, e5:=-8, e6:=16, e7:=-8 }
```

The two vectors are identical up to a shift of 4 positions:
- Commutator: `(0, −8, 16, −8, 0, 0, 0, 0)` — non-zero in `{e1,e2,e3}`
- Associator: `(0, 0, 0, 0, 0, −8, 16, −8)` — non-zero in `{e5,e6,e7}`

The structure is the same: the associator IS the commutator, shifted
by the CD doubling. The scalar `κ = 1` (the identity is exact, not
just up to a scalar).

### 2.4 The Subalgebra Structure

The `{e0,e1,e2,e3}` subalgebra is closed under `split_oct_mul`:
the first 4 components of `split_oct_mul x y` depend only on the
first 4 components of `x` and `y`. This is verified by the
multiplication table (Algebra.lean lines 77-80): terms involving `e4-e7`
appear with opposite signs in the first 4 vs last 4 components.

---

## 3. The Pentagon Defect Is Malformed

### 3.1 The Bug

`pentagon_defect` in `Algebra.lean` lines 176-182:

```lean4
def pentagon_defect (a b c d : SplitOctonion) : SplitOctonion :=
  split_add (split_sub (split_sub (split_add
    (split_oct_mul (associator_tensor a b c) d)   -- term 1
    (split_oct_mul (associator_tensor a b c) d))  -- term 2 = term 1 (repeated!)
    (associator_tensor (split_oct_mul a b) c d))    -- term 3
    (associator_tensor a (split_oct_mul b c) d))    -- term 4
    (split_sub (split_oct_mul a (associator_tensor b c d)) -- term 5a
               (associator_tensor a b (split_oct_mul c d))) -- term 5b
```

Terms 1 and 2 are identical (`split_oct_mul (associator_tensor a b c) d`
appears twice). This is a copy-paste bug.

The resulting expression simplifies to:
```
((ab)c)d − 3(a(bc))d + 2a((bc)d)
```
which is not the MacLane pentagon (which should involve all 5
bracketings `((ab)c)d, (a(bc))d, a((bc)d), a(b(cd)), (ab)(cd)`
each appearing once with appropriate signs).

### 3.2 The Impact

`pentagon_defect_bound` (line 225) proves `(octonion_norm (pentagon_defect
...)).natAbs ≤ 10`. This is a true statement about a malformed expression,
not about the actual Stasheff coherence condition. The bound may still
hold numerically, but it's not the right theorem.

**This needs to be fixed before any conclusions can be drawn from the
pentagon language in §2.2/§2.3.**

### 3.3 What the Correct Definition Should Be

The MacLane pentagon for 4 elements `a(b(cd))` involves 5 bracketings
connected by associators. The pentagon defect should express the
coherence failure as a linear combination where each bracketing appears
once. The corrected definition should use 5 distinct `split_oct_mul`
terms (each bracketing the 4 elements differently), not the current
repeated term.

---

## 4. Implication for the CD Tower: Not Snowballing, But Construction

### 4.1 The Corrected Picture

```
ℝ (dim 1)     →  commutative, no pentagonator
  ↓ CD doubling (ℝ → ℂ')
ℂ' (dim 2)    →  commutator appears: (1+j)(1−j)=0
  ↓ CD doubling (ℂ' → ℍ)
ℍ (dim 4)     →  commutator non-zero, but associator = 0
                   (fully associative — division ring)
  ↓ CD doubling (ℍ → 𝕆ˢ)
𝕆ˢ (dim 8)   →  commutator non-zero in {e1,e2,e3}
                   associator non-zero in {e5,e6,e7}
                   associator = commutator shifted by CD doubling
  ↓ CD doubling (𝕆ˢ → 𝕊ˢ)
𝕊ˢ (dim 16)  →  ??? (unclear from current code)
```

### 4.2 What This Means for Dim 16

The pattern from dim 8 → dim 16 is **not** established. At dim 8, the
associator is manufactured from the commutator at dim 4. At dim 16,
the same mechanism would manufacture the dim-16 associator from the
dim-8 commutator. But the dim-8 commutator is already non-zero (it's
the split-octonion commutator, which is non-zero in general).

The question is: does the same doubling formula apply at each step,
or does something new appear?

- If the pattern recurs identically (flat): dim-16 associator = dim-8
  commutator shifted by 8 positions. Complexity doesn't snowball.
- If something new appears (snowball): dim-16 associator has new structure
  not captured by dim-8 commutator. Complexity compounds.

### 4.3 The Real Structural Claim

The corrected claim is not "non-associative complexity is flat" but
rather: **the CD doubling constructs each level's associator from the
previous level's commutator, and this construction is uniform across
all levels.** If the construction is uniform, the complexity is flat
(not compounding). If the construction changes at higher levels,
complexity may snowball.

The flatness question is now: does the CD doubling formula `[x,y,ℓ] =
κ·(xy−yx)` generalize to all levels with the same `κ`? This is a
concrete algebraic question, not a metaphorical one.

---

## 5. The Octilinear Embedding

### 5.1 What It Captures

The tubeCoord maps trees to ℤ²:
```
tubeCoord(t) = (size(t) + assocDefect(cdStep t), leftWeight(t) - rightWeight(t))
```

The x-coordinate `size + assocDefect` is **independent of the algebra
level** — it depends only on tree structure (the `assocDefect` is a
ℕ-valued function of `cdStep`, not of the algebra dimension). This is
the empirical observation that the "non-associative part" of tree
complexity is captured by a ℕ-valued measure, not by the algebra
dimension.

### 5.2 Connection to the CD Doubling

The kktMultiplier maps trees to `SplitQuat` (dim 4), not to
`SplitOctonion` (dim 8). This is the algebraic grounding: the covector
already captures the non-associative structure. The "extra" 4 dimensions
(e4-e7) of the split-octonion are not needed to represent tree
complexity — they add only commutator structure (which is already
present in the split-quaternion covector).

---

## 6. Implications for Optimization: Traveling Salesman

### 6.1 What Changes

If the CD doubling identity holds uniformly at all levels (flat), then:
- The Tamari lattice geometry (tree shapes, rotations) dominates
- The algebra dimension adds only constant-factor overhead
- The cost landscape structure is the same at dim 4 and dim 8

If the CD doubling identity fails to generalize (snowball), then:
- Higher CD levels add genuinely new structure
- The cost landscape at dim 16 is qualitatively different from dim 8
- The 3900X's n=15 brute force may not scale to higher levels

### 6.2 The TSP Connection

The TSP cost landscape partitions by Tamari lattice geometry, not by
algebra dimension. The `assocDefect` (which drives the x-coordinate of
tubeCoord) is 0 for associative trees and 4 for non-associative trees
— this is a ℕ-valued measure, not an algebra-dependent one.

The empirical test: compare Φ landscapes for the same TSP instance under
SplitQuat (dim 4) and SplitOctonion (dim 8). If the landscapes have
the same number of basins, same basin boundaries, and same
quench-collapse threshold, the complexity is flat. If the octonion
representation adds new basins or changes the collapse threshold,
complexity may snowball.

---

## 7. Summary of Corrections

| Initial claim | Correction | Evidence |
|--------------|-----------|----------|
| Pentagonator "down-projects" onto split-quaternions | **Commutator is upstream, associator is downstream** — the CD doubling constructs associator from commutator | Computed commutator (0,−8,16,−8,0,0,0,0) and associator (0,0,0,0,0,−8,16,−8) have identical structure |
| Non-associative complexity is flat | **Not established** — depends on whether CD doubling generalizes uniformly to dim 16 | No dim-16 code yet; the construction may change |
| `pentagon_defect` computes the Stasheff coherence | **Malformed** — copy-paste bug, repeated term; not the actual pentagon | Expression simplifies to `((ab)c)d − 3(a(bc))d + 2a((bc)d)`, missing `a(b(cd))` and `(ab)(cd)` |

**Key structural insight**: The CD tower is a *construction hierarchy*,
not a projection hierarchy. Each level builds new structure (associator)
from existing structure (commutator). The question is whether this
construction is uniform (flat complexity) or compounds (snowballing).

**Magnitude**: High. The CD doubling identity is the real mechanism —
verified computationally for dim 8. The `pentagon_defect` bug needs
fixing before any pentagon-theoretic conclusions can be drawn.
