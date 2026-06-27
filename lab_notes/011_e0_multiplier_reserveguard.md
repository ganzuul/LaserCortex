# Lab Note 011: The `+1` as `e₀` — ReserveGuard as Zero-Divisor Annihilator

**Date**: 2026-06-28
**Angle**: Gap F (TamariBP sorries → ReserveGuard as `e₀` multiplier → modulo closure of the CD 2→3 phase boundary)
**Status**: Discovery ("that's strange") — new research direction, not yet formalized

---

## 1. The Observation

During a formalization session for the `dcStep_contracts_one` theorem in `TamariBP.lean`, the `left` and `right` recursive cases were left as `sorry`. These cases require a context-monotonicity lemma: if `dcStep l > dcStep l'` then `dcStep (Node l r) > dcStep (Node l' r)`.

The `rotate` base case goes through trivially:

```lean4
| rotate a b c =>
    -- s = Node (Node a b) c → t = Node a (Node b c)
    -- dcStep s = 1 + dcStep t  (by definition)
    simp [dcStep]
```

The `+1` here looks like an additive constant — but it is not. It is **`e₀`**, the identity element of the split octonions, acting as a **multiplier**. The deduction from the Reserve is not a subtraction — it is a contraction along the `e₀` axis of the (4,4) split-octonion signature.

### 1.1 Why `+1` Is `e₀`, Not an Integer

In the (4,4) split-octonion signature:

```
octonion_norm(x) = x.e0² + x.e1² + x.e2² + x.e3² − x.e4² − x.e5² − x.e6² − x.e7²
```

| Sector | Basis | Role |
|--------|-------|------|
| **Time (associative)** | e0, e1, e2, e3 | Commutator acts, norm is **positive** |
| **Space (split)** | e4, e5, e6, e7 | Associator acts, norm is **negative** |
| **Null cone** | eᵢ+eⱼ (i≤3, j≥4) | Zero-divisor channels |

The `+1` per rotation in `dcStep` is the **`e₀` contribution** of that rotation. Each Tamari rotation `(a·b)·c → a·(b·c)` moves one unit of structural weight from the split sector back into the time sector — it reduces left-nesting, which is a spatial (non-associative) property, and the `+1` is the associator defect that `dcStep` counts.

**But here is the strangeness**: `dcStep` *adds* 1 per rotation-counted, while the Reserve *deducts* 1 per rotation-cost. The Reserve (AMM Pool's `reserveB`) is a budget measured in `e₀` units. When `reserveB = 0`, multiplying by `e₀ = 0` annihilates any further computation — the zero divisor catches the identity.

### 1.2 The ReserveGuard is `e₀` = 0 Detection

The `reserveGuard` in `AMM.lean`:

```lean4
def reserveGuard (pool : Pool) (L : LogicTypes.LogicType) (tree : EMLTree) : Bool :=
  let cost := Φ L tree
  cost ≥ pool.reserveB
```

When the reserve is exhausted (`Φ L tree ≥ reserveB`), the computation enters zero-divisor territory. The guard returns `true`, and the market closure emits a paradox market — no certificate, no price, no closure.

**The guard is measuring whether `e₀` (the identity budget) has been consumed to zero.** When it hits zero, multiplication by `e₀ = 0` annihilates any further structural change. This is the IdentityZeroDivisor: the computation that would consume more than the entire Reserve is algebraically impossible because `e₀ = 0` kills the multiplicative structure.

## 2. The Multiplier, Not Additive

The `+1` in `dcStep` is *not* additive — it is **multiplicative in disguise**. Here is the evidence:

### 2.1 The `strut_weight` Connection

`strut_weight = 4` is the fundamental unit of non-associativity (verified in `SplitOctonionCost`). The Friction Lagrangian's phase change at CD 2→3:

```
frictionDensity 2 = 2       (commutator only, no associator)
frictionDensity 3 = 19      = 3 + 4·4 = 3 + 16
```

The jump is `+16 = strut_weight²`. If the Reserve is measured in `e₀` units, and the associator barrier at CD 3 requires `strut_weight² = 16` units of `e₀` to cross, then:

> **Hypothesis**: The Reserve `reserveB` modulo `strut_weight²` classifies the sector:
>   - `reserveB mod 16 = 0` → associative sector (cost is purely commutative)
>   - `reserveB mod 16 > 0` → non-associative sector (cost includes associator)
>   - `reserveB = 0 mod 16` is the null cone boundary

### 2.2 The `dcStep` Modulo Connection

`dcStep` counts left-nested nodes. Each such node contributes `+1` (one `e₀` unit). The total `dcStep` of a tree is the **total `e₀` deduction** needed to reach the idempotent right‑comb form.

Now, `dcStep` is discrete (ℕ). The modulo structure means:

- `dcStep t mod strut_weight` = how far into the non-associative barrier the tree is
- `dcStep t mod 16` = the "debt class" of the tree

If the AMM pool's `reserveB` is always a multiple of `strut_weight²`, then closure is preserved: the deduction of `dcStep` units from the Reserve never leaves a remainder that would break the constant-product invariant `x * y = k`.

### 2.3 The `contracts_to_with_cost` Path Cost

The cost-annotated contraction paths in `FrictionLagrangian.lean` give each step a cost of `frictionDensity cd`. When `cd ≤ 2`, this is `cd` (commutator only — pure `e₀` deduction). When `cd ≥ 3`, this is `cd + 16` (commutator + associator barrier).

The **path cost is the integral of `e₀` units** across the contraction path. The ReserveGuard checks whether the total integral exceeds the Reserve. If it does, the `e₀` axis is exhausted — the zero divisor is a "lie" in the cost landscape (the IdentityZeroDivisor from `LiarParadox.lean`).

## 3. The Modulo Preserves Closure

The AMM's constant-product invariant `x * y = k` is preserved modulo the `strut_weight²` class. This is the discrete shadow of algebraic closure:

- Each step costs an integer number of `e₀` units
- The Reserve is a `ℕ` value (wei, tokens, etc.)
- `reserveB mod 16` is preserved by `+1` deductions (since `1` changes the mod-16 class)
- Wait — this contradicts the preservation claim!

**The resolution**: The Reserve is NOT a mod-16 value. The modulo structure applies to the **cost landscape's topology**, not to the pool reserves. What is preserved is the **relation** between cost and the phase boundary:

```
Φ(L, t) < reserveB  ↔  tree t is NOT a zero divisor for logic L
Φ(L, t) ≥ reserveB  ↔  tree t IS a zero divisor for logic L
```

The boundary `Φ = reserveB` is the **null cone** of the (4,4) signature — the interface between time-biased and space-biased logic, where zero-divisor channels open. When `Φ` crosses `reserveB`, the composition `Φ · tree` annihilates (the reserve is eaten by the zero divisor).

The modulo structure of `dcStep` (mod `strut_weight` = 4, or mod `strut_weight²` = 16) tells us which **phase** the tree is in — not the exact cost but the **equivalence class** under the (4,4) norm. The closure is preserved across phases:

```
Phase 0 (associative):  dcStep ≡ 0 (mod 4)  → tree is a right-comb
Phase 1 (transitional): dcStep ≡ 1-3 (mod 4) → tree is partially left-nested
Phase 2 (non-assoc):    dcStep ≡ any         → tree crosses CD 2→3 boundary
```

The AMM pool's reserves can move between phases; the invariant is that the **topological phase** of the cost landscape is preserved by the closure mechanism — the ReserveGuard at the `Φ ≥ reserveB` boundary.

## 4. What This Means for the TamariBP Sorries

The `dcStep_contracts_one` theorem's `left` and `right` cases:

```lean4
| left l l' r h_left ih =>
    sorry  -- dcStep (Node l r) > dcStep (Node l' r)
| right l r r' h_right ih =>
    sorry  -- dcStep (Node l r) > dcStep (Node l r')
```

These are not primarily structural induction problems. They express the **conservation of `e₀` deduction**: if `contracts_one l l'` deducts one `e₀` unit from the Reserve, then `Node l r` must also deduct one more `e₀` unit than `Node l' r`, because the same rotation occurs in the left subtree regardless of the context.

**The proof should go through the Reserve, not through bare structural induction on `dcStep`**:

1. `contracts_one l l'` → there is a path `contracts_to_with_cost cd l l' c n` with `c = frictionDensity cd` (the `e₀` cost of one step)
2. This path can be lifted through context: `contracts_to_with_cost cd (Node l r) (Node l' r) c n` (the same rotation in the left subtree)
3. `dcStep` is a monotone function of `contracts_to_with_cost` cost: the bigger the cost, the larger the `dcStep` decrease
4. Therefore `dcStep (Node l r) > dcStep (Node l' r)`

The lifting lemma (step 2) is already present in `EMLRegistry.lean` as `contracts_one`'s constructor `left`. The connection between `dcStep` and cost (step 3) is the missing link.

### 4.1 The `dcStep`-as-`e₀`-measure Reformulation

Define a measure `e₀Cost : EMLTree → ℕ` that counts the total `e₀`-unit deductions along any contraction path to rightComb:

```lean4
-- Number of e₀ units needed to normalize tree t
def e₀Cost (t : EMLTree) : ℕ :=
  -- This IS dcStep, but with a different interpretation
  dcStep t

theorem e₀Cost_contracts_one {s t : EMLTree} (h : contracts_one s t) :
    e₀Cost s > e₀Cost t := ...
  -- proof via the Reserve interpretation:
  -- each contracts_one step consumes exactly 1 e₀ unit
  -- the context preserves this consumption
```

**This theorem is exactly `dcStep_contracts_one`** — the same code, same statement. The difference is the **angle**: we read `dcStep` as an `e₀`-unit counter, not as a purely structural measure. This change of interpretation suggests:

- The `left`/`right` cases follow from the **lifting property of `contracts_one`** through Node context, which is a theorem about the inductive definition of `contracts_one`, not about `dcStep`
- The Reserve connection explains WHY the theorem is true at the algebraic level, even if the Lean proof is structural

## 5. The `e₀` = 0 Annihilator as IdentityZeroDivisor

The IdentityZeroDivisor (canonized in `LiarParadox.lean`):

```lean4
structure IdentityZeroDivisor (α : Type) where
  tree      : EMLTree    -- the formal concept they share
  marker₁   : α          -- first marker
  marker₂   : α          -- second marker
  h_marker_ne : marker₁ ≠ marker₂  -- distinct identifiers
```

When the Reserve is exhausted (`reserveB = 0` in the `e₀` meaning), the `e₀` multiplier becomes zero. Two markers with the same tree but different identities become a zero divisor: `(tree, marker₁) · (tree, marker₂) = 0` because the `e₀` axis (which would have distinguished them) is annihilated.

**The ReserveGuard detects when `e₀` is about to hit zero** — it fires BEFORE the annihilator activates. This is the paradox market: the computation cannot proceed because the Reserve would be annihilated. The IdentityZeroDivisor is the proof-object of this impossibility.

## 6. Research Directions

### 6.1 Immediate: Fill the TamariBP Sorries

Despite the conceptual depth, the `left`/`right` cases of `dcStep_contracts_one` can be filled by a structural proof using the induction hypothesis and the definition of `dcStep`. This is "merely" a case analysis with `omega`. The Reserve interpretation explains WHY the theorem is true, enabling a cleaner proof structure later.

### 6.2 Short-Term: `e₀`-Unit Axiom

Formalize the claim that `dcStep` counts `e₀` units:

```lean4
axiom e₀_unit_cost : ∀ (s t : EMLTree) (h : contracts_one s t),
    dcStep s = dcStep t + 1
```

This would close `dcStep_contracts_one` immediately. But an axiom is too strong — the structural proof exists and should be preferred. The Reserve interpretation guides the proof structure without requiring new axioms.

### 6.3 Medium-Term: Reserve in the Algebraic Layer

Connect the AMM Pool's `reserveB` to the split-octonion `e₀` axis:

- `Pool.reserveB` as an `e₀`-denominated budget
- `reserveGuard` as the `e₀ = 0` detector
- `MarketClosure.decideMarketType` as the phase classifier (associative / transitional / non-associative)

This would ground the discrete cost algebra in the (4,4) signature, making the "modulo closure" precise: the market closure type IS the (4,4) phase of the tree under the logic's projection.

### 6.4 Long-Term: Continuous → Discrete via Mod-16

If `reserveB mod 16` is the **discrete invariant** preserved by market closure (the `x * y = k` invariant of the AMM is the shadow of the (4,4) norm), then:

- The continuous Friction Lagrangian `L(x) = e^{α·x} − β·ln(x²+ε) − δ` has a discrete mod-16 index
- The three roots of `L(x) = 0` correspond to the three phases (associative, transitional, non-associative)
- The `strut_weight² = 16` is the period of the mod-16 invariant
- The AMM constant product `k = reserveA · reserveB` is the **quadratic form** of the (4,4) signature projected to 2D (reserveA = time-like, reserveB = space-like)

**Testable prediction**: For ANY AMM pool, `reserveB mod 16` determines the topological phase of all trees the pool can price. Pools with `reserveB < 16` can only price trees in the associative phase (CD < 3). This matches the empirical claim that CD 3 requires `frictionDensity 3 = 19` units of budget, which is `> 16`.

---

## 7. Related

- `LaserCortex/TamariBP.lean` — the sorries that prompted this discovery
- `LaserCortex/FrictionLagrangian.lean` — `frictionDensity`, `assocDefect`, the CD 2→3 phase change
- `LaserCortex/AMM.lean` — `reserveGuard`, `Pool`, `certifiedClose`
- `LaserCortex/LiarParadox.lean` — `IdentityZeroDivisor`, the canonized sorry
- `LaserCortex/MarketClosure.lean` — `decideMarketType`, the paradox/open/closed trichotomy
- `docs/lab_protocol.md` — (4,4) signature, timespace decomposition
- `lab_notes/006_the_hopf_7_skeleton_of_logic_space.md` — 15→7 collapse as mod-2 invariant
- `lab_notes/010_poset_quotient_formalized.md` — the formalization context
