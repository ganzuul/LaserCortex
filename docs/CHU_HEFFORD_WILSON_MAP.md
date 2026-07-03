# Chu Construction — Hefford–Wilson (2025) Mapping

**Paper**: arXiv:2502.19022v1 — "A BV-Category of Spacetime Interventions"
**Reference**: M. Hefford, M. Wilson (CentraleSupélec / UCL)
**Dumped**: 2026-07-01

## Core Result

The Chu construction sends **closed normal duoidal categories** to **BV-categories**.
This is a categorification of Atkey's result (Chu sends duoidal pomonoids → BV-pomonoids).

Specifically:
```
Chu(StProf(C), 1) = StEnv(C)   ← "Strong Hyland Envelope"
```

where StProf(C) = strong endoprofunctors (= Tambara modules) over a symmetric monoidal category C.

## The Categorical Pipeline (Cat → BV-Cat)

```
C → C × C^op → Prof(C) → StProf(C) → Chu(StProf(C),1) = StEnv(C)
│       │         │           │              │
│     double     free       normalize      Chu
│   (Earnshaw)  cocompletion (Garner)    (Barr)
│                           = duoidal
```

Each step:
1. **Doubling** `D(C) = C × C^op` — splice an object with its dual.
2. **Yoneda** `y: C×C^op → Prof(C)` — free cocompletion, Prof(C) is duoidal.
3. **Normalisation** `N: Prof(C) → StProf(C)` — restrict to strong profunctors (Tambara modules). **Normal** duoidal (both unit objects coincide: 1_C for both ⊗ and ⊲).
4. **Chu** `Chu(StProf(C), 1)` — the Strong Hyland Envelope, which IS a BV-category.

## Key Theorems (numbered from paper)

### Thm 4.1 (pre-BV via Chu)
If C is ⊗-closed ⊗-symmetric duoidal with pullbacks and ⊥ is a ⊲-monoid, then `Chu(C,⊥)` is a **pre-BV-category**.

### Thm 4.2 (BV via Chu)
If C is ⊗-closed ⊗-symmetric **normal** duoidal with pullbacks, then `Chu(C, i_⊗)` is a **BV-category**.
(Here `i_⊗` = unit of the ⊗ tensor = unit of ⊲ tensor since normal.)

### Thm 4.3 (Cofreeness)
Chu is **right 2-adjoint** to the forgetful functor `U: BV → CSNDuo`.
→ BV-categories are **cofreely** constructed from duoidal categories.

### Prop 4.4 (Self-dual ⊲)
`((a,a',r) ⊲ (b,b',s))* = (a,a',r)* ⊲ (b,b',s)*`
The sequencing operator is strictly self-dual in Chu(C,⊥).

## The Three Connectives of BV-Logic

| Connective | Name | Physical interpretation | Category theory |
|-----------|------|------------------------|-----------------|
| ⊗ | Tensor | **Space-like** — no communication, separable interventions | Day convolution on Prof(C) |
| ⊲ | Seq | **Time-like** — one-directional communication | Profunctor composition (coend) |
| ⅋ | Par | Causally indefinite — arbitrary communication | Dual of ⊗ via *-autonomy |

Duoidal = category with **both** ⊗ and ⊲, interacting via a distributor:
```
(a ⊲ b) ⊗ (c ⊲ d) → (a ⊗ c) ⊲ (b ⊗ d)
```

## StProf(C) in Detail

- **Objects**: Strong endoprofunctors P: C → C (Tambara modules) — have actions both vertically (composition) and horizontally (tensor).
- **⊗**: Quotiented Day convolution — unit = 1_C (= hom profunctor C(-,-)).
- **⊲**: Profunctor composition — unit = 1_C (= same! this is what makes it **normal** duoidal).
- **Fun fact**: StProf(C) ≅ PSh(Optic(C)) (copresheaves on the coend-optics category).

### Physical interpretation

- `C(a,b)` = hom set of **first-order processes** (a → b in C).
- `P(d,c)` = set of **interventions** — probe with choice c, observe outcome d.
- `yo{a}` = `Optic(C)((a,a'), -)` = **context** at (a,a') — a "hole" in the string diagram.
- `C{a}` = `C(-, a⊗-) × C(a'⊗-, -)` = set of **interventions** at (a,a') — the concrete probing device.

**Critical**: `C{a}* ≅ yo{a}` for sufficiently nice C (finite-dimensional quantum), but in general `C{a}* ≅/= yo{a}`. The failure of *-autonomy for StProf(C) is precisely the failure of this isomorphism.

## StEnv(C) = Chu(StProf(C), 1) as Spacetime

An object of StEnv(C) = `(P, P', η: P⊗P' → 1)` where:
- **P** = the **intervention** (what the agent does)
- **P'** = the **context** (the spacetime surrounding the agent)
- **η** = evaluation — how the context acts on the intervention

**Events**: The canonical embedding `StProf(C) → StEnv(C)` sends:
```
P ↦ (P, P*, ev)
```
Basic event at (a,a'): `Event(a,a') = (C{a}, C{a}*, ev)`

### Causally faithful events
`(C{a}, yo{a}, ev)` — contexts restricted to combs (no pathological non-linear maps). Only possible when `C{a}* ≅ yo{a}`, which is a **decomposition theorem** for single-party supermaps.

## Mapping to Our Framework

| Hefford–Wilson | LaserCortex | What it means |
|---------------|-------------|---------------|
| C (base sym mon cat) | `Type` with `⊗` = `×` | Our base symmetric monoidal category |
| Prof(C) | Pre-duoidal structure | Bimodules over Types |
| StProf(C) | **`QuantizedType`** as Tambara module | Strong endoprofunctors = Quantized types |
| `⊗` (Day convolution) | **Compact** tensor (split-quaternion) | Space-like composition |
| `⊲` (profunctor composition) | **Split** tensor (time-like/ordered) | Time-like/sequential composition |
| `(·)* = [·, 1]` | The dualising functor | Weak dual — generally not involutive |
| `Chu(StProf(C), 1)` | **`SplitQuat.embed` via `zsmul_eq_mul`** | Resolving the SMul = resolving `P** ≅ P` failure |
| `StEnv(C)` | Our target: full QuantizedType hierarchy | BV-category of spacetime events |
| `⅋` (par) | **Pentagonator** = tropical modification | Associativity defect resolved at ℍ→𝕆 transition |
| Causally faithful events | Split-Octonion type (CD 3 in our class) | `yo{a}* ≅ C{a}` holds (normed division algebra) |
| Non-causally faithful events | Split-Quaternion, Split-Complex (CD 1-2) | `yo{a}* ≅/= C{a}` — pathological maps exist |

### The SMul Mismatch (= embed_mul) IS the Chu Construction

The `zsmul_eq_mul` bridge was **not** an accident — it is the explicit algebraic shadow at the ℤ-algebra level of the Chu construction.

Our pipeline:
1. `SplitQuat` = StProf(SplitType) — a Tambara module over split types.
2. `Cl11` = `Chu(StProf(SplitType), 1)` — the Chu construction at ℤ-algebra level.
3. `embed: SplitQuat → Cl11` sends `q ↦ (q, q*, ev)` — the canonical embedding.
4. `embed_mul` = the proof that `embed` is a monoid homomorphism, which requires the Chu modification of the SMul structure.

The `zsmul_eq_mul` lemma **is** the explicit, algebraic proof that the Chu construction works at the ℤ-algebra level. It's not deferred — it's the computational content of the Chu construction for our specific case.

### Three-Sign Cancellation = BV-Logic

The three signs (+/−/Λ) of hyperfield / Kim (2026) "three-sign cancellation" correspond directly to the three BV connectives:

| Sign | BV connective | Hyperfield operation | Physical |
|------|--------------|---------------------|----------|
| + | ⊗ (tensor) | Addition (spacelike) | No communication |
| − | ⅋ (par) | Subtraction | Arbitrary communication |
| Λ | ⊲ (seq) | "Three-sign" cancellation | One-directional communication |

The tropical pentagonator hypothesis: the associativity defect κ = 2·min(a,b) = the distributor δ for (⊗,⊲) in the duoidal structure over the tropical semiring.

## What We Need to Build in Lean

### Structures absent from mathlib (confirmed via Loogle):
1. **Duoidal category** typeclass — two monoidal structures (⊗, ⊲) with distributor δ
2. **Normal duoidal** — i_⊗ ≅ i_⊲
3. ***-autonomous category** typeclass — exists in mathlib as `StarAutonomousCategory`? NO — confirm
4. **Chu construction** — `Chu(C, ⊥)` with objects as pairs + evaluation
5. **BV-category** typeclass — *-autonomous + ⊲ with self-duality + duoidal with (⊗,⊲) and (⊲,⅋)
6. **Strong profunctor** (Tambara module) — not urgent for the algebraic core

### Our immediate targets (algebraic core):
1. **Duoidal** on `Ring`-like objects (two monoid structures on same set with interchange law)
2. **Chu** over a monoidal category in `Type` — objects = (a, a', a⊗a' → ⊥)
3. **StarAutonomous** — closed sym mon + dualising functor
4. **BV** = *-autonomous + ⊲ + duoidal conditions
5. **Proof that `Chu(C, ⊥)` is BV** when C is normal duoidal

## Critical Citations from the Paper

- **Atkey (2006)**: `atkey_bv` — Chu sends duoidal pomonoids to BV-pomonoids; our Thm 4.2 categorifies this.
- **Garner (2018)**: `garner` — StProf(C) is normal duoidal.
- **Earnshaw (2022)**: `earnshaw` — Duoidal structure of Prof(C) and normalisation.
- **Pastro-Street (2008)**: `pastro_street` — Tambara modules = copresheaves on optics.
- **Hefford (2024)**: `hefford_supermaps` — Supermaps = strong natural transformations in StProf(C).
- **Loregian (2015)**: `loregian_coend` — Coend calculus.
- **Loregian (2021)**: `lucyshynwright2015relativesymmetricmonoidalclosed` — PsMon lifts to 2-functor.
- **Pavlovic (199-)**: `pavlovic_chu` — Chu is right 2-adjoint to forgetful.

## Open Questions for our Work

1. **Is the tropical semiring a duoidal category?** The paper only needs a distributor δ. Tropical addition (⊗ = min) and tropical multiplication (⊲ = +) have a natural interchange: `min(a+b, c+d) => min(a,c) + min(b,d)`. This is the **tropical distributivity** law. If the tropical semiring forms a duoidal category (with discrete category structure), then `Chu(Tropical, 0)` would be a BV-category — and that would be the **tropical BV-category** that the pentagonator hypothesis predicts.

2. **What is `Chu(SplitQuatTypes, 1)`?** Our `Cl11` with the `zsmul_eq_mul` bridge. If `SplitQuatTypes` (strong profunctors over split types) is normal duoidal, then `Cl11` is BV. The `embed_mul` proof would be the explicit verification.

3. **Can we prove the pentagonator identity (associahedron K₄ face) as the distributor δ?** The K₄ face relates 5 ways to parenthesize 4 objects. In the duoidal setting, δ exactly mediates between (⊗, ⊲) interactions. The tropical pentagonator hypothesis claims δ = the min-formula associator of the tropical semiring. If true, the associahedron = secondary fan of min(x₁,...,xₙ).

4. **Do causally faithful events correspond exactly to CD(ℚ, SQ̅) in our hierarchy?** The split-octonion type has yo{a}* ≅ C{a} (normed division algebra property), which is the condition for causally faithful events. The SQ type (CD 1) does NOT satisfy this — hence the `zsmul_eq_mul` bridge needed.
