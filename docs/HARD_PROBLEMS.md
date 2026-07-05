# Hard Problems Enabled by chu_embed_mul

**Date**: 2026-07-05
**Status**: Plan — awaiting prioritization
**Prerequisites**: `lab_notes/024` (chu_embed_mul proven), `docs/CHU_HEFFORD_WILSON_MAP.md`

---

## Context

`chu_embed_mul` proves that `SplitQuat.embed : SplitQuat → Cl(1,1)` is an algebra
homomorphism. This is the computational content of the Chu construction at the
ℤ-algebra level: `Cl11 = Chu(StProf(SplitType), 1)`.

Two "hard problems" are now tractable:

| # | Problem | What it unlocks | Difficulty |
|---|---------|---------------|------------|
| 1 | Cl11 is *-autonomous | Connection to Atkey (2006), full BV-category foundation | High — requires internal hom and adjunction |
| 2 | ChuTensor is associative + distributor δ | Duoidal structure on ChuSpace, Thm 4.2 (BV via Chu) | Medium — algebraic coherence conditions |

---

## Problem 1: Cl11 Is *-Autonomous

### 1.1 What *-Autonomous Means

A symmetric monoidal category `(C, ⊗, I)` is *-autonomous when there is a
full and faithful functor `(-)* : Cᵒᵖ → C` inducing a natural isomorphism:

```
C(a ⊗ b, c) ≅ C(a, [b, c])
```

where `[b, c] = (b* ⊗ c*)*` is the internal hom (par). Equivalently, the
double dual map `a → (a*)*` is an isomorphism.

In our ℤ-algebraic setting, `Cl11` with the Chu pairing should satisfy:

```
Cl11(a ⊗ b, c) ≅ Cl11(a, [b, c])
```

where `[b, c]` is defined by the Chu pairing and `⊗` is the Clifford tensor
(product in Cl11).

### 1.2 Why This Is Hard

| Sub-problem | What's needed |
|-------------|---------------|
| Define internal hom `[b, c]` | Use the Chu pairing: `[b, c] = (antipode b ⊗ c).a` (already have `splitQuatPairingAux_eq_product`) |
| Prove adjunction `a ⊗ b → c` iff `a → [b, c]` | Requires constructing the evaluation and coevaluation maps |
| Prove double dual isomorphism | `x ↦ [x, 1]` must be invertible |

The `splitQuatPairingAux_eq_product` lemma already gives:
```
splitQuatPairingAux y z = (antipode_sq y * z).a
```

This is the key identity: the Chu pairing equals the first component of the
antipode-applied product. This is the "norm via pairing" result.

### 1.3 Proof Sketch

```lean4
-- Step 1: Define the internal hom via the Chu pairing
-- [b, c] := antipode_sq b * c  (first component)
-- This is already implicit in splitQuatPairingAux_eq_product

def internalHom (b c : Cl11) : Cl11 := antipode_sq (???) * c
-- Need to lift antipode_sq from SplitQuat to Cl11

-- Step 2: Prove the adjunction
-- For all a, b, c : Cl11,
--   Cl11(a * b, c) ≅ Cl11(a, (antipode_sq b) * c)
-- The forward direction: λ f => ??? (use the Chu pairing)
-- The reverse direction: λ g => ??? (use the evaluation map)

-- Step 3: Prove the double dual is an isomorphism
-- The map x ↦ (antipode_sq x) * 1  (or equivalently, the pairing with 1)
-- is invertible
```

### 1.4 What chu_embed_mul Enables

`chu_embed_mul` proves that `embed` preserves multiplication. For the
*-autonomous property, we need to show that `embed` also preserves the
internal hom structure. Specifically:

```
embed([x, y]) = [embed x, embed y]
```

where `[x, y]` on the left is the internal hom in SplitQuat (via the
antipode) and on the right is the internal hom in Cl11 (via the Chu pairing).

This follows from `chu_embed_mul` and the definition of internal hom via
the pairing, but requires verifying that the pairing commutes with the
antipode.

---

## Problem 2: ChuTensor Is Associative + Distributor δ

### 2.1 What Duoidal Means

A category `C` with two monoidal structures `(⊗, I_⊗)` and `(⊲, I_⊲)` plus a
distributor:

```
δ_{a,b,c,d} : (a ⊲ b) ⊗ (c ⊲ d) → (a ⊗ c) ⊲ (b ⊗ d)
```

and unit maps:

```
γ : I_⊗ → I_⊗ ⊲ I_⊗
μ : I_⊲ ⊗ I_⊲ → I_⊲
ν : I_⊗ → I_⊲
```

satisfying coherence conditions (Aguiar 1997; Garner 2018).

**Normal duoidal**: `I_⊗ ≅ I_⊲` (the two unit objects coincide).

### 2.2 Why This Is Medium Difficulty

| Sub-problem | What's needed |
|-------------|---------------|
| ChuTensor associativity | `(X ⊗ Y) ⊗ Z = X ⊗ (Y ⊗ Z)` — requires verifying pairing condition |
| ChuSeq associativity | `(X ⊲ Y) ⊲ Z = X ⊲ (Y ⊲ Z)` — same |
| Distributor δ | The coherence condition linking ⊗ and ⊲ |

The pairing condition for `ChuTensor` is:
```
splitQuatPairing (X.a * Y.a) Z = splitQuatPairing X.a (Y.a * Z.a)
```

This follows from `splitQuatPairingAux_symm` and the bilinearity of the pairing.

### 2.3 Proof Sketch

```lean4
-- Step 1: ChuTensor associativity
-- (X ⊗ Y) ⊗ Z = X ⊗ (Y ⊗ Z)
-- Both sides have a = X.a * Y.a * Z.a
-- Pairing condition: splitQuatPairing (X.a * Y.a) Z = splitQuatPairing X.a (Y.a * Z.a)
-- This follows from symmetry + bilinearity of the pairing

theorem ChuTensor_assoc (X Y Z : ChuSpace SplitQuat) :
    ChuTensor (ChuTensor X Y) Z = ChuTensor X (ChuTensor Y Z) := by
  ext <;> simp [ChuTensor, splitQuatPairingAux_symm, add_comm, add_left_comm, mul_assoc]

-- Step 2: ChuSeq associativity (same pattern, reversed duals)
theorem ChuSeq_assoc (X Y Z : ChuSpace SplitQuat) :
    ChuSeq (ChuSeq X Y) Z = ChuSeq X (ChuSeq Y Z) := by
  ext <;> simp [ChuSeq, splitQuatPairingAux_symm, mul_assoc]

-- Step 3: Distributor δ
-- δ : (X ⊲ Y) ⊗ (Z ⊲ W) → (X ⊗ Z) ⊲ (Y ⊗ W)
-- The coherence condition: the pairing must be compatible
-- splitQuatPairing (X.a * Z.a) (W.a' * Y.a') = splitQuatPairing X.a Z.a * splitQuatPairing Y.a' W.a' ???
-- Actually, the distributor is a map in Cl11, not just a pairing condition.
-- We need to construct the explicit map.
```

### 2.4 What chu_embed_mul Enables

`chu_embed_mul` proves that `embed(x * y) = embed x * embed y`. For the
duoidal structure:

- `embed` preserves `⊲` (proved in `chu_space_of_seq`)
- `embed` should also preserve `⊗` and the distributor δ

The distributor δ in the Chu construction comes from the naturality of the
pairing with respect to both tensor products. `chu_embed_mul` provides the
algebraic foundation for verifying that the distributor law holds.

---

## Comparison

| | Problem 1 (*-autonomous) | Problem 2 (duoidal) |
|---|---|---|
| **What it proves** | Cl11 has internal hom + adjunction | ChuSpace SplitQuat has duoidal structure |
| **Connects to** | Atkey (2006), full BV-category | Hefford-Wilson Thm 4.2 (BV via Chu) |
| **Key input** | Chu pairing + antipode | ChuTensor, ChuSeq definitions |
| **Key lemma** | `splitQuatPairingAux_eq_product` | `splitQuatPairingAux_symm` |
| **Enabled by** | `chu_embed_mul` | `chu_space_of_seq` (already proven) |
| **Difficulty** | High — adjunction + isomorphism | Medium — associativity + coherence |

### Problem 2 Is More Immediate

Problem 2 is closer because `ChuTensor` and `ChuSeq` are already defined and
`chu_space_of_seq` is already proven. The associativity of `ChuTensor` is a
straightforward computation using `splitQuatPairingAux_symm`.

### Problem 1 Is More Ambitious

Problem 1 connects to the full BV-category structure and the Atkey theorem.
It requires proving that the Chu pairing induces an adjunction, which is
a deeper categorical result.

---

## Recommended Approach

1. **Start with Problem 2** — ChuTensor associativity + distributor δ
   - These are concrete algebraic identities in Cl11
   - `chu_embed_mul` provides the monoidal homomorphism property
   - Completes the duoidal structure on ChuSpace SplitQuat

2. **Then Problem 1** — Cl11 is *-autonomous
   - Builds on Problem 2 (duoidal structure)
   - Requires defining internal hom via the Chu pairing
   - Proves the adjunction and double dual isomorphism

3. **Finally: BV-category** — Cl11 is BV
   - Combines Problems 1 and 2
   - Applies Hefford-Wilson Thm 4.2
   - This is the "grand unification" target

---

## Open Questions

- Does `ChuTensor` associativity actually hold? The pairing condition
  `splitQuatPairingAux (X.a * Y.a) Z.a' = splitQuatPairingAux X.a (Y.a * Z.a')`
  needs verification.

- What is the explicit form of the distributor δ? In the Chu construction,
  δ comes from the naturality of the pairing. We need to construct it
  as a map in Cl11.

- Can we avoid formalizing the full duoidal category structure and instead
  prove a weaker result that still enables the BV connection?

---

## References

- Atkey (2006): " Chu sends duoidal pomonoids to BV-pomonoids"
- Hefford-Wilson (2025): arXiv:2502.19022v1, "A BV-Category of Spacetime Interventions"
- Garner (2018): "Normal duoidal structure of StProf(C)"
- Aguiar (1997): " Monoidal categories in geometry and analysis"
- `lab_notes/023`: CD-homotopy bridge (Chu pairing + antipode + ZD boundary)
- `docs/CHU_HEFFORD_WILSON_MAP.md`: Mapping Chu construction to LaserCortex
