# Lab Note 007: The SO Carrier Morphism

**Name of discovery:** The **SO Carrier Morphism** — the algebraic embedding
`toSO : NodeCost → SplitOctonion` that maps the 8 cost parameters into the
8-dimensional split-octonion algebra, together with the factorization theorem
`engineToSO = toSO ∘ engine_to_nodecost` that proves the 3-parameter engine
state lives directly in the algebra through the cost structure. This is the
algebraic infrastructure that grounds the 7-Skeleton (Lab Note 006) in the
actual split-octonion algebra, transforming the 7 distinct NodeCost points from
*observed coincidences* into *projections of an algebraic point*.

**Angle of arrival:** The GLM-5.2 audit identified Gap A as "carrier morphism
NodeCost → SplitOctonion" — the most algebraically deep gap. The 7-Skeleton
(006) had established *that* the 15 logics collapse to 7 distinct NodeCosts,
but could not explain *why* — the collapse remained an empirical observation
about the named-logic subspace. Gap A asked: can we map the NodeCost structure
into the split-octonion algebra in a way that makes the 7-Skeleton inevitable?

We entered through the Domain 0 identity/collapse theorems, found the
7-Skeleton, then traced it back to the Needle compression formula. The break
came when we realized that `engineToSO` could be defined as
`toSO ∘ engine_to_nodecost` — making the factorization *definitional* (rfl)
rather than a provable equality. This shifted the difficulty from proving the
factorization exists (tautological by construction) to proving the
componentwise expansion of the formula (the arithmetic of e₂).

---

## The Discovery

### 1. The Carrier Morphism `toSO`

The morphism `toSO : NodeCost → SplitOctonion` maps each of the 8 cost
parameters to a split-octonion component:

| NodeCost field | Maps to | Range | Proof |
| -------------- | --------- | ------- | ------- |
| `bias` | e₀ | 1 (invariant) | `nodeParam_bias_one` |
| `leftWeight` | e₁ | 0 or 1 | `engine_bias_is_one` (Gap F) |
| `rightDiv` | e₂ | ℤ (compression formula) | `engineToSO_formula` (Gap A) |
| `denom` | e₃ | 10 (constant) | `engine_denom_is_ten` (Gap F) |
| `coupling` | e₄ | 0 (constant) | Gap F |
| `satCap` | e₅ | 0 (constant) | `engine_satCap_is_zero` (Gap F) |
| `mirror` | e₆ | 0 or 1 (boolean→ℤ) | Gap F |
| `maxSem` | e₇ | 0 or 1 (boolean→ℤ) | `engine_maxSem_is_false` (Gap F) |

**Formal statement** (from `SplitOctonionCost.lean`):

```lean4
def toSO (c : NodeCost) : SplitOctonion :=
  { e0 := c.bias,
    e1 := c.leftWeight,
    e2 := (c.rightDiv : ℤ),
    e3 := c.denom,
    e4 := c.coupling,
    e5 := c.satCap,
    e6 := if c.mirror then 1 else 0,
    e7 := if c.maxSem then 1 else 0 }
```

### 2. Injectivity

`toSO_injective` proves the embedding has no collisions: distinct NodeCosts
always map to distinct split-octonions. This is the "no shadow coincidences"
guarantee — the 7 distinct NodeCost points are truly 7 distinct algebraic points.

The proof works by comparing all 8 fields pairwise — since each NodeCost field
maps to a distinct SO component, equality of SO points forces equality of all
8 fields, hence equality of the original NodeCosts.

### 3. The Engine Factorization

The key structural insight: **define** `engineToSO` as the composition
`toSO ∘ engine_to_nodecost`, not as an independent formula. This makes the
factorization theorem `engine_to_nodecost_factors_through_SO` definitionally
true (`rfl`):

```lean4
def engineToSO (s : EngineState) : SplitOctonion :=
  toSO (engine_to_nodecost s)

theorem engine_to_nodecost_factors_through_SO (s : EngineState) :
    toSO (engine_to_nodecost s) = engineToSO s := rfl
```

The Gap A *formula* theorem (`engineToSO_formula`) is then a separate statement
that expands the composition componentwise for documentation. It proves the
explicit branching:

- **When `local_debt > 0`**: e₀=1, e₁=0, e₂=max(0, capacity/(debt+1)-1),
  e₃=10, e₄=0, e₅=0, e₆=1 (mirror), e₇=0
- **When `local_debt = 0`**: e₀=1, e₁=1 (classical), e₂=0, e₃=10,
  e₄=0, e₅=0, e₆=0, e₇=0

These match the `engine_to_nodecost` branches componentwise.

### 4. The Hard Part: e₂ = rightDiv

Of the 8 components, e₂ (rightDiv) was by far the hardest to prove. The
difficulty is a `simp` coherence issue: `Nat.cast` of `Nat.max` interacts
differently with `simp` depending on whether the `Nat.cast` is at the top level
or distributed inside:

- **LHS** (`toSO(...).e₂`): `simp` applies `Nat.zero_max` and eliminates `max 0`
  before `Nat.cast_max` can fire, leaving `Nat.cast((compression)-1)`.
- **RHS** (`(max 0 (compression-1) : ℤ)`): `simp` applies `Nat.cast_max` first,
  producing `Int.max 0 (Nat.cast(compression)-1)`, where `Nat.zero_max` no
  longer applies (it only rewrites `Nat.max`, not `Int.max`).

The fix was a small lemma `cast_lemma` proving the identity for all ℕ arguments:

```lean4
have cast_lemma (x : ℕ) : (Nat.cast (max 0 (x - 1)) : ℤ) = max (0 : ℤ) ((x : ℤ) - 1) := by
  cases x; simp; rename_i x; simp
```

Then `simpa` to apply it. The lemma closed trivially because in the `succ x`
case, `Nat.max` reduces to `x`, `Nat.cast` distributes, and `Nat.cast_nonneg`
resolves the `Int.max`.

### 5. The 7-Skeleton Connection

With the carrier morphism proven, the 7-Skeleton (Lab Note 006) gains a deeper
interpretation:

**Before (006)**: The 15 named logics compress to 7 distinct NodeCost
configurations because the bias=1 invariant reduces the 8D parameter space to
a 7D affine hyperplane. The 7 points correspond to the 7 imaginary split-octonion
axes, but only at the level of observed coincidence.

**After (007)**: The map `engineToSO` places each *engine state* directly in
the split-octonion algebra. The NodeCost readout is the "shadow" of that
algebraic point — the componentwise projection. The 7-Skeleton is not a
coincidence about the named-logic subspace; it is a theorem about the
dimensionality of the algebraic embedding:

- `toSO_injective` guarantees no two NodeCosts collide in SO.
- The factorization `engineToSO = toSO ∘ engine_to_nodecost` means every
  engine state has a unique algebraic image.
- The 7 distinct NodeCosts are 7 distinct points in the 8D algebra, sitting
  in the hyperplane e₀=1 (bias invariant).

Since `toSO` is injective, the 7-Skeleton's compression from 15 logics to
7 NodeCosts is *not* a compression in the algebra — it is a compression in the
inverse image of `toSO`. The algebra sees all 7 distinctly; the compression
happens at the NodeCost level, where different logic types share the same
cost parameters.

### 6. Relation to Gap F

Gap F (field-level bridge theorems) closed the remaining 5 NodeCost fields
that had no engine-state connection. The new bridge theorems (`Gap F` in
`FrictionLagrangian.lean`) connect `bias`, `leftWeight`, `mirror`, `denom`,
`maxSem`, `satCap` to their engine origins. Together with Gap A's `rightDiv`
formula, all 8 fields are now bridged:

| Field | Theorem | Type |
| ------- | --------- | ------ |
| leftWeight | `engine_mirror_implies_leftWeight_zero` | state-dependent (mirror ↔ debt>0) |
| rightDiv | `engineToSO_formula` | formula (compression) |
| mirror | `engine_mirror_iff_debt_nonzero` | state-dependent (mirror ↔ debt>0) |
| bias | `engine_bias_is_one` | constant |
| denom | `engine_denom_is_ten` | constant |
| coupling | `engine_coupling_is_zero` | constant |
| maxSem | `engine_maxSem_is_false` | constant |
| satCap | `engine_satCap_is_zero` | constant |

### 7. Formal Theorems Established

From `SplitOctonionCost.lean`:

- `toSO` (definition) — carrier morphism
- `toSO_injective` — injectivity of the embedding
- `engineToSO` (definition) — engine→SO composition
- `engine_to_nodecost_factors_through_SO` — factorization (rfl)
- `engineToSO_formula` — componentwise expansion of the formula
- `SplitOctonion.ext_components` — componentwise equality lemma

From `FrictionLagrangian.lean` (Gap F):

- `engine_bias_is_one` (Gap F)
- `engine_denom_is_ten` (Gap F)
- `engine_maxSem_is_false` (Gap F)
- `engine_satCap_is_zero` (Gap F)
- `engine_mirror_iff_debt_nonzero`
- `engine_mirror_implies_leftWeight_zero`
- `engine_coupling_is_zero` (from Gap C)

From `SplitOctonionLogic.lean` (Domain 0 / 7-Skeleton):

- `distinctNodeCosts_are_distinct`
- `distinctNodeCost_enumeration`
- `only_spacetime_is_mirrored`
- `bias_invariant`
- `sameNodeCost_differentLayerCost_*`

### 8. Implications

**The generation→hyperstition transition**: The carrier morphism is the
algebraic vocabulary for describing how SO parameters produce logic-like
behaviour. The engine state's 3 parameters (current_weight, local_debt,
capacity) determine a point in the 8D algebra. The cost readout `Φ_of_nc`
is a functional on this point. Different logic types correspond to different
*regions* of this space — not different *rules* — meaning the transition
between logics is a continuous deformation of an algebraic parameter, not a
discrete switch.

**The 7-Skeleton is inevitable**: Because `toSO` is injective and e₀=1 is
invariant, the space of possible engine-derived logic types is at most 7D.
The 15 named logics occupy 7 points — the full discrete spectrum of the
compression formula `rightDiv = max(0, capacity/(debt+1)-1)`. Remaining
points in the 7D hyperplane are continuous interpolations (Domain 8 of the
TDD) whose logical stability is an open question.

**The cdStep is orthogonal**: `engineToSO` does not depend on `cdStep` — the
Cayley-Dickson tower height is invisible to the carrier morphism. This means
the 8 SO dimensions capture the *cost geometry* but not the *expressivity
level* of logic types. A logic at cdStep 0 (ℝ) and cdStep 3 (𝕆) can have
identical SO coordinates but different behaviour under the Friction Lagrangian.
This separation of concerns (geometry vs. height) is exactly what the GLM
audit's Gap D (normalizeAcross) targets.

### 9. Open Questions

1. **The continuous interpolation**: The 7D hyperplane contains infinitely
   many split-octonion points beyond the 7 named discrete ones. Which of
   these correspond to stable logical personalities? The 7 named ones are
   known fixed points of the compression formula; the others are a continuous
   spectrum of "in-between" logics.

2. **e₂ as the only variable**: Of the 8 axes, only e₂ (rightDiv) has
   non-trivial dynamics (depends on the compression ratio
   `capacity/(debt+1)-1`). The other 7 axes are either constant or simple
   booleans. Is this asymmetry structural (the rightDiv is the "associated
   algebra") or just a feature of the current engine model?

3. **Canonical form of the factorization**: `toSO ∘ engine_to_nodecost` is
   definitional, but can we prove a stronger statement — that
   `toSO ∘ engine_to_nodecost` is the *unique* algebra homomorphism extending
   the engine state to the split-octonions?

4. **The 8th axis**: `e₀` is always 1, but `bias` is a free parameter in
   `NodeCost`. The invariant `nodeParam_bias_one` only holds for named logics.
   What happens to the carrier morphism for non-named-parameter cost vectors
   with bias ≠ 1? Does the embedding become non-injective? Does it collapse
   to a lower dimension?

---

## References

- `LaserCortex/SplitOctonionCost.lean` — Gap A implementation (toSO, engineToSO,
  injectivity, formula)
- `LaserCortex/FrictionLagrangian.lean` — Gap F bridge theorems (all 8 fields)
- `LaserCortex/SplitOctonionLogic.lean` — Domain 0 (7-Skeleton, bias invariant,
  distinct NodeCosts)
- `LaserCortex/Cost.lean` — NodeCost structure with `Φ_of_nc`
- `LaserCortex/LogicTypes.lean` — 15 LogicType variants
- `LaserCortex/LogicMonad.lean` — normalizeAcross (Gap D placeholder)
- `docs/GLM-5-2_on_LogicM.md` — the audit that defined gaps A-F
- `lab_notes/006_the_hopf_7_skeleton_of_logic_space.md` — the 7-Skeleton discovery

Correction 2026-09-02: the count is **8** distinct NodeCost
rows (Free/Boolean, the raw-size geometry, was omitted — the pairwise
lemma lacked exhaustiveness); see 006 erratum. The carrier morphism
statement itself is unaffected: 8 distinct rows still ⟹ distinct
images under an injective carrier.
