# BV-Category Specification — Lean Target

**Source**: arXiv:2502.19022v1, §3 (Hefford–Wilson 2025)
**Status**: Blueprint — NOT implemented in mathlib. Must build from scratch.

## 1. *-Autonomous Category

A symmetric monoidal category `(C, ⊗, I)` is *-autonomous when it has a full & faithful functor:
```
(-)* : C^op → C
```
inducing a natural isomorphism:
```
C(a ⊗ b, c) ≅ C(a, (b ⊗ c)*)
```

Equivalent definition: there exists an object `⊥` such that the double-dual map `a → (a*)*` is invertible and `a* = [a, ⊥]` (internal hom into ⊥).

The induced **par** connective:
```
a ⅋ b := (a* ⊗ b*)*
```
with unit `I_⅋ := I*`.

In a *-autonomous category, `(C, ⅋, I_⅋)` is also symmetric monoidal.

### Lean target structure (sketch):
```lean4
class StarAutonomousCategory (C : Type u) [Category.{v} C] extends
    SymmetricMonoidalCategory C, ClosedSymmetricMonoidalCategory C where
  dual : C ⥤ C
  dual_obj (a : C) : C := ...
  -- full and faithful
  ...
```

**Status**: Mathlib has `CategoryTheory.Closed.Monoidal` and `SymmetricMonoidalCategory`. The `StarAutonomous` notion may be present in experimental branches but Loogle confirmed absent from the main branch.

**Approach**: Build minimal *-autonomous on `Type`-like categories (sets with structure) using Chu.

---

## 2. Duoidal Category

A category `C` with **two monoidal structures** `(⊗, I_⊗)` and `(⊲, I_⊲)` plus a **distributor**:
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

The distributor δ is **associative** and **unital** in both directions.

### Normal duoidal
`I_⊗ ≅ I_⊲` — the two unit objects coincide. In this case `ν` is invertible.

### In our context
- `(⊗, I_⊗)` = **compact** tensor (space-like) — Day convolution in StProf(C).
- `(⊲, I_⊲)` = **split** tensor (time-like) — profunctor composition in StProf(C).
- `δ` = the **interchange law** between space-like and time-like composition.

### Lean target:
```lean4
class DuoidalCategory (C : Type u) [Category.{v} C] where
  tensor : MonoidalStructure C  -- (⊗, I_⊗)
  seq    : MonoidalStructure C  -- (⊲, I_⊲)
  δ : ∀ {a b c d}, (a ⊲ b) ⊗ (c ⊲ d) → (a ⊗ c) ⊲ (b ⊗ d)
  -- coherence axioms omitted for brevity
```

**Status**: Not in mathlib.

---

## 3. *-Functor

A functor `F: C → D` between *-autonomous categories that is ⊗-lax with:
- Laxator `l: F(a) ⊗ F(b) → F(a ⊗ b)`
- Unit `l₀: I_⊗^D → F(I_⊗^C)`
- Plus a **self-duality** natural isomorphism `s_a : F(a*) ≅ (F a)*`
- Satisfying the **pentagon condition** (eq. 2.1 in paper):

```
(Fa)* ⊗ Fa --ε--> I_⅋
   │ s⊗1         ↑ l₀*
   ↓             │
Fa* ⊗ Fa --l--> F(a* ⊗ a) --Fε--> F(I_⅋)
```

A *-functor is **normal** when `l₀` is an isomorphism.

### Equivalence (Thm 2.1)
`F` is a *-functor ⇔ `F` is a **degenerate linear functor** (i.e. `F⊗ = F⅋` with coinciding strengths).

### Lean target:
```lean4
structure StarFunctor (F : C → D) [StarAutonomous C] [StarAutonomous D]
    extends LaxMonoidalFunctor F where
  s : ∀ a, F (a*) ≅ (F a)*
  pentagon_condition : ...
```

---

## 4. (Pre-)BV-Category

### Pre-BV-category
A *-autonomous category `(C, ⊗, I)` equipped with an **additional monoidal structure** `(⊲, I_⊲)` such that:
1. `(C, ⊗, ⊲)` is a ⊗-closed, ⊗-symmetric duoidal category.
2. `(C, ⊲, ⅋)` is a duoidal category (dual of 1 via *-autonomy).
3. The associator `α_⊲` is **linear natural** (commutes with the *-autonomous structure).
4. `- ⊲ -` is a **degenerate linear functor** `C × C → C`.
5. **Self-duality**: `(a ⊲ b)* ≅ a* ⊲ b*` and `I_⊲ ≅ I_⊲*`.

### BV-category
A pre-BV-category with `I_⊲ ≅ I_⊗` (isomix). Equivalent to:
- `(C, ⊗, ⊲)` is **normal** duoidal (i.e. `I_⊗ ≅ I_⊲`)
- `C` is *-autonomous
- The induced `(C, ⊲, ⅋)` is also duoidal (automatically normal because `I_⊲ ≅ I_⊗ ≅ I_⅋`)

### Key theorem (Thm 3.2)
A (pre-)BV-category is equivalently a **pseudomonoid** in the 2-category `*Aut` (resp. `*Aut_N`).

### Physical meaning
The three monoidal structures:
- `⊗` = space-like (no communication) — e.g. two separate labs
- `⊲` = time-like (one-directional communication) — e.g. before/after
- `⅋` = causally indefinite (arbitrary communication) — e.g. indefinite causal order

### Lean target (simplified for `Type`):
```lean4
class BVCategory (C : Type u) [Category.{v} C] extends
    StarAutonomousCategory C where
  seq : MonoidalStructure C       -- (⊲, I_⊲)
  duoidal_tensor_seq : DuoidalCategory C  -- inherits from ⊗ and ⊲ (with distributor δ)
  duoidal_seq_par   : DuoidalCategory C  -- (⊲, ⅋) — dual structure
  seq_self_dual     : ∀ a b, (a ⊲ b)* ≅ a* ⊲ b*
  seq_unit_self_dual : I_⊲ ≅ I_⊲*
  seq_degenerate_linear : ...  -- -⊲- is a degenerate linear functor
  seq_associator_linear : ...  -- α_⊲ is linear natural
```

---

## 5. Chu Construction

For a category `C` with pullbacks and chosen object `⊥`, the Chu category `Chu(C, ⊥)` has:
- **Objects**: triples `(a, a', r: a ⊗ a' → ⊥)` — a Chu space
- **Morphisms**: `(f, f'): (a,a',r) → (b,b',s)` where `f: a → b`, `f': b' → a'` making:

```
a ⊗ a' --r--> ⊥
 f⊗1      ↑ s
↓         │
b ⊗ a' --1⊗f'-> b ⊗ b'
```

### Chu tensor product
```
(a,a',r) ⊗ (b,b',s) = (a⊗b, [a,b'] ×_{[a⊗b',⊥]} [b,a'], r⊗s composite)
```
where `[-,-]` is the internal hom and `×_` denotes pullback.

### Chu par
```
(a,a',r) ⅋ (b,b',s) = ((a,a',r) ⊗ (b,b',s)*)*
       = ([a',b] ×_{[a'⊗b',⊥]} [b',a], a'⊗b')
```

### Chu seq (from duoidal structure)
When `C` is duoidal, there's a **lifted** ⊲:
```
(a,a',r) ⊲ (b,b',s) = (a⊲b, a'⊲b', m∘(r⊲s)∘δ)
```
where `m: ⊥⊲⊥ → ⊥` is the ⊲-monoid structure on `⊥`.

### Key theorem (Thm 4.1/4.2)
If `C` is ⊗-closed, ⊗-symmetric duoidal + pullbacks + `⊥` is a ⊲-monoid, then `Chu(C,⊥)` is **pre-BV**.
If `C` is **normal** duoidal + pullbacks, then `Chu(C, I_⊗)` is **BV**.

### Lean target:
```lean4
def Chu (C : Type u) [Category.{v} C] [MonoidalCategory C] (⊥ : C) : Type (max u v) :=
  Σ (a a' : C), (a ⊗ a' ⟶ ⊥)

structure ChuHom {C} [Category C] [MonoidalCategory C] {⊥ : C}
    (X Y : Chu C ⊥) : Type v where
  f  : X.1 ⟶ Y.1
  f' : Y.2.1 ⟶ X.2.1
  condition : Y.2.2 ∘ (f ⊗ 𝟙 Y.2.1) = X.2.2 ∘ (𝟙 X.1 ⊗ f')
```

---

## 6. Strong Hyland Envelope

```
StEnv(C) := Chu(StProf(C), 1)
```
where `1 = C(-,-)` is the hom profunctor (unit of both ⊗ and ⊲ in StProf(C)).

Since `StProf(C)` is **normal duoidal** (Garner 2018), `StEnv(C)` is a **BV-category** by Thm 4.2.

### Physical content
- Object: `(P, P', η: P ⊗ P' → 1)` = intervention + context + evaluation.
- Morphism: `(f,f')` where `f: P → Q` (intervention map), `f': Q' → P'` (context map backwards).
- **Duality**: `(P, P', η)* = (P', P, η∘σ)` — swaps intervention and context.
- **Event** at `(a,a')`: `(C{a}, C{a}*, ev)` where `C{a} = C(-, a⊗-) × C(a'⊗-, -)`.

---

## 7. Categorical Chain Summary

```
C (base sym mon cat)
  │ ── doubling D(C) = C × C^op
  ▼
C × C^op
  │ ── Yoneda embedding
  ▼
Prof(C) = PSh(C × C^op)      ← duoidal (⊗ = Day, ⊲ = coend comp)
  │ ── normalisation (restrict to Tambara modules, Garner)
  ▼
StProf(C)                     ← normal duoidal (I_⊗ = I_⊲ = 1_C)
  │ ── Chu(–, 1)
  ▼
StEnv(C)                      ← BV-category!

Embedding: StProf(C) → StEnv(C) :: P ↦ (P, P*, ev)   — strong monoidal, fully faithful
```

## 8. What Our Lean Code Actually Needs (Minimal)

For the algebraic core of LaserCortex, we don't need the full 2-categorical apparatus. We need:

### Phase 1: Chu over a monoidal category (in Type)
```lean4
structure ChuOver (M : Type u) [Monoidal M] (⊥ : M) where
  left  : M
  right : M
  pair  : left ⊗ right ⟶ ⊥

-- tensor, par, seq (if M is duoidal)
-- proof that ChuOver(M, ⊥) is *-autonomous
-- proof that ChuOver(M, I_⊗) is BV if M is normal duoidal
```

### Phase 2: Apply to ℤ-algebras
- `M = StProf(SplitTypes)` — but we don't need the full profunctor category. Instead:
- `M = SplitQuat`-with-⊗ = tensor product of ℤ-modules, ⊲ = Clifford product
- Show that `SplitQuat` with `(⊗, ⊲)` is a **normal duoidal monoid** (= duoidal category with one object)
- Then `Chu(SplitQuat, ℤ)` = our `Cl11` — the BV-category at ℤ-algebra level

### Phase 3: The embed_mul proof
- `embed: SplitQuat → Cl11` = `q ↦ (q, q*, ev)` — the canonical embedding
- `embed_mul` = `embed(a) ⊲ embed(b) = embed(a·b)` — this is the Chu structure at work
- The `zsmul_eq_mul` bridge = the explicit computation that `r·(q, q*, ev) = (r·q, r·q*, ev)` = the Chu-module structure

### Phase 4: Pentagonator
- The distributivity `δ: (a⊲b)⊗(c⊲d) → (a⊗c)⊲(b⊗d)` in the duoidal structure
- In our ℤ-algebra case: `δ` corresponds to the exchange law between Clifford (⊲) and tensor (⊗) products
- The associahedron K₄ face = the associativity coherence for 4 objects in this duoidal setting
- Tropical pentagonator hypothesis: this δ is given by `min(a,b,c,d)` formula over the tropical semiring
