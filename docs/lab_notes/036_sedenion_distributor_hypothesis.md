# 036: The Sedenion Distributor Hypothesis — Flat Doubling vs Snowball

**Date**: 2026-07-20  
**Status**: HYPOTHESIS — CD4 (sedenion) level not yet formalized; CD≤2 base case proven;  
  `ChuHom`/distributor morphism is the proposed instrument for deciding  
**Prerequisites**: 027 (CD doubling identity), 029 (pentagon defect correction),  
  030 (mixed-case scope limit), Chu.lean (sliding law `splitQuatPairingAux_mul_slide`)  
**Source**: `LaserCortex/foundations/Chu.lean`, `docs/the_point.md`, `docs/BV_CATEGORY_SPEC.md`

---

## 1. The Question

The Cayley–Dickson doubling ladder produces:
- **CD1** (complex): commutative, associative → no associator defect
- **CD2** (quaternion): associative → no associator defect  
- **CD3** (octonion): non-associative → associator appears, sliding law holds  
- **CD4** (sedenion): non-associative, non-alternative → ?

**CD4 hypothesis** (from 027, corrected): Does non-associative complexity  
*snowball* (each doubling amplifies the defect) or *flatten* (the defect  
saturates at a fixed algebraic form)?

The CD3 base case says: `associator(x,y,ℓ) = κ · [x,y]` where `[x,y]` is the  
commutator in the base algebra, and `ℓ` is the doubling generator. This is  
the "flat" scenario — the associator reduces to commutator arithmetic and  
doesn't grow new structural complexity at the next level.

Lab note 030 showed this does **not** extend to mixed arguments (one base, one  
split), but that doesn't settle the CD4 question — it only says the base→split  
boundary has richer structure than the pure base subalgebra.

---

## 2. What the Sliding Law Tells Us (CD≤2)

The sliding law in Chu.lean (`splitQuatPairingAux_mul_slide`, line 380) says:

```
β(u·v, w) = β(v, S(u)·w)
```

where `β` is the pairing and `S` is the antipode. This is the **CD≤2** base  
case of the distributor axiom. In Chu space terms:

- `β` is the evaluation pairing on Chu spaces
- `S` is the `dualize` involution (line 64)
- The sliding law says `chuSpaceOf(x*y)` is compatible with `dualize` and  
  the tensor product `ChuTensor`

This has been proven for the split-quaternion case. The question is: what  
happens at CD4?

---

## 3. Why `ChuHom` / Distributor Morphism Is the Right Instrument

### 3.1 The Duoidal Frame

A duoidal category `(⊗, ◁, δ)` has two monoidal structures linked by a  
distributor (interchanger):

```
δ : (a ⊲ b) ⊗ (c ⊲ d) → (a ⊗ c) ⊲ (b ⊗ d)
```

where `⊲` is the "sequential" product (here: `ChuSeq`, composition-like)  
and `⊗` is the "parallel" product (here: `ChuTensor`, tensor-like).

The distributor `δ` being an isomorphism says the two products commute  
up to canonical isomorphism — the category is "braided" in a suitable sense.

When `δ` fails to be an iso, the failure encodes exactly the associator/  
commutator defect: `δ ∘ δ⁻¹` (where it exists as a partial map) gives a  
measured "non-braidedness."

### 3.2 The CD4 Decision

**If CD4 is flat**: `δ` at the sedenion level is still an iso (or at least  
its failure is controlled by the same commutator formula). The complexity  
doesn't snowball.

**If CD4 is a snowball**: `δ` at sedenions fails to be an iso in a way  
that generates genuinely new structural complexity — higher-order terms  
that don't reduce to commutator arithmetic of the base.

### 3.3 What We Can Measure

The `Chu_distributor` theorem (line 393) currently says (for CD≤2):

```
β(x·y, z·w) = β(y, S(x)·z·w)  [sliding applied twice]
```

At CD4, we would define:

```lean
def chuHom (f : SplitOctonion → SplitOctonion) : Prop :=
  ∀ x y, chuSpaceOf (f (x * y)) = ChuTensor (chuSpaceOf (f x)) (chuSpaceOf (f y))

def distributor_cd4 (a b c d : SplitOctonion) : Prop :=
  ...  -- the interchanger map on ChuSeq ⊗ ChuSeq → ChuTensor
```

and ask: does `distributor_cd4` hold? If not, what is the defect?

---

## 4. What the Sedenion Structure Actually Looks Like

Sedenions (CD4, dim 16) have the Cayley–Dickson multiplication:

```
(a₀ + a₁ℓ)(b₀ + b₁ℓ) = (a₀b₀ - ℓ̄₁b₁) + (b₁a₀ + a₁ℓ̄₀)ℓ
```

where `ℓ̄` is the conjugate in the base octonion. The key structural  
difference from CD3:

- CD3: one new generator, base is quaternion (associative)  
- CD4: one new generator, base is octonion (non-associative)  

The associator `[x, y, z]` at CD4 involves the octonion associator in the  
base, which itself reduces to commutator terms (by 027). So the CD4  
associator is a "double reduction": CD4 associator → octonion associator →  
commutator terms.

**The snowball hypothesis** says this double reduction introduces new  
cross-terms that don't collapse.

**The flat hypothesis** says the double reduction is still controlled by the  
same algebraic form — the commutator structure propagates without amplification.

---

## 5. Formalization Plan

### Phase 1: `ChuHom` Definition
Define morphisms between Chu spaces that respect both products:
```lean
structure ChuHom (X Y : ChuSpace SplitQuat) where
  primal : SplitQuat → SplitQuat
  dual : SplitQuat → SplitQuat
  preserves_tensor : ...
  preserves_seq : ...
```

### Phase 2: Distributor Construction
Define the interchanger `δ : (a ⊲ b) ⊗ (c ⊲ d) → (a ⊗ c) ⊲ (b ⊗ d)`  
for the split-quaternion case (where it should be an iso).

### Phase 3: CD4 Lift
Attempt to lift the distributor to the sedenion case. The defect of this  
lift is the CD4 decision instrument.

### Phase 4: Measurement
Compute (or bound) the defect. If it's zero → flat. If it's non-zero but  
controlled → bounded snowball. If it's uncontrolled → full snowball.

---

## 6. Status

| Component | Status |
|-----------|--------|
| Sliding law (CD≤2) | ✅ Proven (`splitQuatPairingAux_mul_slide`) |
| `Chu_distributor` (CD≤2) | ✅ Proven (line 393) |
| `ChuHom` definition | ❌ Not started |
| Distributor `δ` construction | ❌ Not started |
| CD4 lift attempt | ❌ Blocked on Phase 1-2 |
| Flat vs snowball decision | ❌ Blocked on Phase 3 |

The next action is Phase 1: define `ChuHom` and begin constructing the  
distributor morphism for the split-quaternion case.

---

## 7. Connection to Other Work

- **027 (CD doubling identity)**: The base case that makes flatness plausible  
- **029 (pentagon defect)**: The pentagon identity is another instance of the  
  same question — does the coherence condition snowball or flatten?  
- **030 (mixed-case limit)**: Shows the base→split boundary is where new  
  structure enters — this is exactly where `δ` would fail to be an iso  
- **FreeEnergy.lean**: The free energy functional `coherencePotential` could  
  be extended to measure the distributor defect as a cost term
