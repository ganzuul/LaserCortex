# 018: CD Galois Theory — The Tower Lattice and the Uplift Groupoid

**Date**: 2026-06-28  
**Status**: Theoretical exploration (no code changes)  
**Prerequisites**: 017 (CD Uplift — 16 sign errors, the double-algebra structure)

---

## 1. The CD Tower Is Not a Chain

The codebase currently maps the Cayley-Dickson tower as a linear chain:

```
ℝ → ℂ → ℍ → 𝕆 → 𝕊
0    1    2    3    4
```

But the 017 analysis revealed that the split-octonion SO is **not CD(SQ)** with a single base algebra. Instead, SO pairs **two different 4D structures**:

```
SO = CD(ℚ, SQ̅)
```

Where:
- **ℚ** = compact quaternion ring (i²=j²=k²=-1) — the associative sector e₀..e₃
- **SQ̅** = split-quaternion (i²=-1, j²=+1, k²=+1) — the split sector e₄..e₇

This means the CD tower is **not a chain** but a **lattice**. At each step, we have a choice: compact or split?

---

## 2. The Full CD Lattice

```
                  Dimension    Norm Signature    Base field
                                                     │
                  ℝ₁           (+)                 ℤ[1]
                 / \
                /   \
               /     \
              ℂ₂      ℂ'₂
           (++,0)    (+-)      compact vs split complex
             / \     / \
            /   \   /   \
           /     \ /     \
          ℍ₄     ℍ₄'     ℍ₄''
      (++++)   (++--)   (+-+-)    three 4D algebras
          |\     / \     /|
          | \   /   \   / |
          |  \ /     \ /  |
          |   𝕆₈    𝕆₈'   |
          |(++++++++)(++++----)   two 8D algebras
           \    |    |    /
            \   |    |   /
             \  |    |  /
              𝕊₁₆  𝕊₁₆'
```

Where:
- **ℂ₂**: standard complex (i²=-1, norm ++)
- **ℂ'₂**: split-complex (j²=+1, norm +-)
- **ℍ₄**: quaternions (i²=j²=k²=-1, norm ++++)
- **ℍ₄'**: split-quaternions Cl(1,1) (i²=-1, j²=+1, k²=+1, norm ++--)
- **ℍ₄''**: para-quaternions (various)
- **𝕆₈**: standard octonions (norm ++++++++)
- **𝕆₈'**: split-octonions (norm ++++----)
- **𝕊₁₆**, **𝕊₁₆'**: sedenions (lose division algebra property)

**Key observation**: Our codebase uses *both* ℍ₄' (SQ in SplitQuaternionClifford.lean) and 𝕆₈' (SO in SplitOctonionCost.lean), with the ℚ subalgebra of 𝕆₈' being ℍ₄.

---

## 3. The Galois Correspondence

### The Classical Galois Picture

In classical Galois theory:
- **Fields** and **field extensions** form a poset
- **Automorphism groups** of extensions form a lattice
- There's an **order-reversing bijection** between intermediate fields and subgroups

### The CD Galois Analogy

| Classical Galois | CD Galois |
|------------------|-----------|
| Field F | Base ring ℤ |
| Field extension L/K | CD doubling E/A (dimension ×2) |
| Intermediate fields | Subalgebras of the CD algebra |
| Galois group Aut(L/K) | Automorphisms preserving the base |
| Fixed field of subgroup | Subalgebra fixed by automorphisms |
| Solvability by radicals | Uplift path existence (SQ → ℚ) |

### The CD Galois Correspondence Conjecture

For the CD tower over ℤ, there exists a **Galois connection** between:

1. **Subalgebras** of CDₙ(ℤ) (the n-th CD algebra) ordered by inclusion
2. **Subgroups** of Aut(CDₙ(ℤ)/ℤ) (automorphisms fixing ℤ) ordered by inclusion

Such that:
- Larger subalgebras ↔ smaller subgroups (order-reversing)
- The fixed subalgebra of a subgroup H is `{x ∈ CDₙ(ℤ) | ∀σ∈H, σ(x) = x}`
- The stabilizer subgroup of a subalgebra A is `{σ ∈ Aut | σ|ₐ = idₐ}`

**But with a twist**: Unlike fields, CD algebras can be **non-associative** (𝕆, 𝕊). This means the "automorphism group" is no longer a group in the usual sense — it becomes a **groupoid** or **higher category** where associativity constraints enter.

---

## 4. The Uplift Groupoid

The central discovery of 017 is the **uplift primitive**: given a split algebra, we can embed it into the split sector of a CD double and project the compact sector.

```
SQ → 𝕆₈' → ℚ
```

This is a **span** in the CD lattice:

```
       𝕆₈'
      /    \
     /      \
    SQ      ℚ
   (split)  (compact)
```

The SQ → 𝕆₈' embedding is a **morphism** in the "CD Galois groupoid" — it maps a split algebra into the total space. The 𝕆₈' → ℚ projection is another morphism.

These two morphisms compose to give the uplift: `SQ → ℚ`. But they don't compose in the usual way (the span isn't a composable pair of arrows in a category) — they compose as a **correspondence** (a relation).

### The Uplift Groupoid Structure

Objects: All CD algebras (ℝ, ℂ, ℂ', ℍ, ℍ', ℍ'', 𝕆, 𝕆', 𝕊, ...)

Morphisms:
1. **CD doubling** `D: A → CD(A, B)`: embed A into the first component of CD(A, B) (associative, dimension-preserving in one component)
2. **Split embedding** `S: A → CD(B, A)`: embed A into the second component of CD(B, A) (split sector)
3. **Projection** `P₁: CD(A, B) → A`: forget the second component
4. **Projection** `P₂: CD(A, B) → B`: forget the first component

Composition rule: The **uplift** of A to B exists iff there is a CD double CD(B, A) such that:
- A embeds via S into CD(B, A)
- B projects via P₁ from CD(B, A)
- The cost Φ(CD(B, A)) is finite (bounded by dcStep)

This is NOT a group, but a **groupoid** (a category where all morphisms are invertible up to cost). The invertibility is the key: the projection and embedding are not inverses (composing S then P₁ gives a nontrivial endomorphism of A), but they are **adjoint** in the bicategorical sense.

---

## 5. Connection to the Logic Type Poset

The existing codebase maps 15 logic types onto the CD tower. The Galois connection explains the logic type architecture:

```
Logic types                  CD algebras
    |                            |
Classical ───────────────── ℝ   (compact, ordered, commutative, associative)
    |     ╲                  |
    |      ╲──ℂ'──────────── ℂ'  (split complex: Fuzzy, ManyValued)
    |          ╲             |
Intuitionistic ─╲─────── ℍ  (compact: assoc sector of SO)
    |              ╲         |
    |               ╲──ℍ'─── SQ (split quat: available for uplift)
    |                   ╲    |
Quantum  ───────────────── 𝕆₈'  (split octonion: total space)
    |                   /    |
    |               ╲──ℍ''─── (resolved compact sector)
    |              ╲         |
Paraconsistent ──── 𝕊₁₆'  (sedenion: beyond associativity)
```

The lift/diagonal arrows (╲) are the **uplift paths**: they correspond to Generation finding the compact structure from the split one. The cost barrier (strut_weight² = 16 at the CD 2→3 boundary) is the **minimum cost** of any uplift path.

---

## 6. The Cost Function as a Galois Trace

In classical Galois theory, the **trace** Tr_{L/K}(x) = Σ σ(x) sums over all Galois automorphisms.

In CD Galois theory, the **cost function** Φ(L) plays an analogous role: it aggregates over all possible "automorphisms" (resolution paths) of the CD algebra:

```
Φ(L) = min_{uplift paths p: L → compact form} cost(p)
```

The `friction_barrier_across_cd23` theorem (proven in the codebase) gives the minimum trace: Φ(L) jumps by at least 16 when crossing the associativity boundary.

This suggests:

> **Φ is the Galois trace of the CD groupoid** — it measures the minimal cost to resolve a split algebra into its compact form via Generation.

---

## 7. Open Questions

1. **What is Aut(𝕆₈'/ℤ)?** The automorphism group of the split-octonions over ℤ is known to be the split form of G₂ (a 14-dimensional exceptional Lie group). Over ℤ, this becomes a group scheme. The CD Galois groupoid is the **action groupoid** of G₂(ℤ) acting on the lattice of subalgebras.

2. **Is the uplift path unique?** Given SQ, there may be multiple embeddings into 𝕆₈', each giving a different projection to ℚ. The `dcStep` measure in TamariBP selects the **boundedness class** of the uplift — paths with minimum associator cost.

3. **Can we formalize the CD groupoid in Lean?** This would require a bicategorical framework (since associativity fails at CD ≥ 3). The existing TamariBP (with its tree rotations and dcStep) provides the coherence data for the non-associative case.

---

## 8. The Complex Remainder: The CD Generator ω as the Galois Element

### The Discovery

When SQ → SO → ℚ, we get **ℚ as the fixed subalgebra** and **ℂ (or ℂ') as the remainder**. The remainder is NOT an element that already existed in SQ — it's the **CD generator ω** introduced by the doubling.

### Why It Can't Live in SQ

A direct search over SQ elements e with e² = +1 shows:

| e²=+1 candidate | Anticommutative with j? | Anticommutative with k? |
|-----------------|------------------------|-------------------------|
| j | ✗ (commutes with itself) | ✓ |
| k | ✓ | ✗ (commutes with itself) |
| -j | ✗ | ✓ |
| -k | ✓ | ✗ |
| a·i + b·j + c·k (mixed) | ✗ | ✗ |

No element of SQ anticommutes with both j and k simultaneously. The transition from j²=+1 to J²=-1 requires a generator **outside** SQ.

### ω as the CD Generator

In the CD double SO = CD(ℚ, SQ), the CD generator ω satisfies:

- **ω² = γ** where γ = -1 for compact (standard) or γ = +1 for split
- **ω anticommutes** with the second component (SQ): ω·x = -x·ω for x ∈ SQ (imaginary)
- **Conjugation by ω** transforms the (j,k) plane:

```
J = ω·j   →  J² = -1  (now quaternionic)
K = ω·k   →  K² = -1
i·J = K  (correct quaternion cross product)
```

The subalgebra generated by ω is:

- **ℂ** if ω² = -1 (standard complex numbers)
- **ℂ'** if ω² = +1 (split-complex numbers)

### The Galois Interpretation

The CD extension CD(ℚ, SQ)/SQ has a **Galois group** generated by ω:

```
Gal(CD(ℚ, SQ)/SQ) ≅ ℤ/2ℤ

σ: CD(ℚ, SQ) → CD(ℚ, SQ)
   (a, b) ↦ (a, -b)    [ω acts as reflection on the second component]
```

The fixed subalgebra under this action:

```
{a ∈ CD(ℚ, SQ) | σ(a) = a} = ℚ ⊕ ⟨ω⟩
```

Where:
- **ℚ** is the first component (fixed because σ fixes a)
- **⟨ω⟩** ≅ ℂ is generated by ω (fixed because σ(ω) = ω in the standard representation)

**Key**: The notation "SQ → SO → ℚ + ℂ" decomposes as:
- **SQ** → the base algebra (what we start with)
- **SO** = CD(ℚ, SQ) = ℚ ⊕ ω·SQ (the total space)
- **ℚ** = the fixed subalgebra under ω-action (the "compact resolved" part)
- **ℂ** = ⟨ω⟩ (the Galois generator — the remainder)

### The Connection to 017's Uplift

This gives a precise algebraic meaning to the "uplift primitive" from 017:

```
SQ → SO → ℚ + ℂ

Split sector → Total space → (Compact sector + Galois generator)
```

The **inductive bias** is: ω is the generator of all possible uplifts. Different choices of ω (with ω² = ±1) give different extensions:

| ω² | Generator type | Fixed algebra | Remainder | CD algebra |
|----|---------------|---------------|-----------|------------|
| -1 | Standard complex i | ℚ | ℂ | **Standard octonions** 𝕆 |
| +1 | Split-complex j | ℚ | ℂ' | **Split octonions** 𝕆' (our case) |

The lift from SQ → ℚ is always the same (project the first component), but the **remainder** ℂ vs ℂ' distinguishes whether we're in the compact or split branch of the CD lattice.

## 9. Summary

The CD Galois idea gives a principled foundation for:

| Concept | CD Galois analog | Codebase connection |
|---------|------------------|---------------------|
| Field extension | CD double CD(A, B) | SplitOctonionCost.lean (64-term mult) |
| Automorphism group | Uplift groupoid G₂(ℤ) | Generation.lean (WFC search) |
| Fixed field | Subalgebra fixed by projections | Hopf.lean (resolveSQ) |
| Trace | Cost function Φ | FrictionLagrangian.lean (layerCost) |
| Solvability | BoundednessClass k | TamariBP.lean (dcStep) |
| Galois correspondence | Logic type ↔ CD algebra | LogicTypes.lean (cdStep) |

**The central thesis**: Generation (WFC) IS the CD Galois groupoid in action — it searches the space of uplift paths between split and compact forms, and the cost function Φ is the trace over this groupoid.
