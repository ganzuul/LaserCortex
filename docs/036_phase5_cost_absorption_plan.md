# Phase 5: Absorb NodeCost + cdStep into the Type Algebra

**Status**: PLAN
**Prerequisites**: Phases 1–3 (staging → foundations, old-core → `.lean.old`),
  `docs/type_theory_map.md`, `docs/type_algebra_worked_example.md`,
  `docs/plan_graphiti_to_transit_map.md`
**Dependencies**: `foundations/` (Algebra, Tamari, Chu), `LaserCortex/Friction.lean`,
  `LaserCortex/SubdivisionClosure.lean`, `LaserCortex/AMM.lean`

---

## 1. What "Absorb NodeCost + cdStep" Means

The oldest docs described a 98-parameter cost function (14 LogicTypes × 7 NodeCost
fields) that was scaffolding before the CD tower and Tamari lattice were formalised.
The staging/ files and the type theory docs together replaced this with:

- **Cost is `weightedCost cd t = dcStep t × frictionDensity cd`** — a single ℕ.
- **The "coordinates" are `(x, y) = (size + assocDefect cd, leftWeight − rightWeight)`**
  — the KKT multiplier / transit coord from Develin–Sturmfels type theory.
- **cdStep is the pentagonator depth** — derived (`cdStep_eq_pentagonatorDepth`),
  not a table lookup.
- **The 15 logic types reduce to their cdStep** — the type algebra treats
  `(S₂, S₃)` pairs per tree, not a 15-way enumeration.

The absorption has already happened in the cost layer (`Friction.lean`,
`SubdivisionClosure.lean`, `AMM.lean`) and the coordinate layer
(`OctilinearEmbedding.lean`, `TropicalTypeAlgebra.lean`). What remains is
the **middle layer**: `Generation.lean` and `Problem.lean` still import
`LaserCortex.LogicTypes` (the old 15-type enumeration) for `cdStep` and
`isAssociativeSector` lookups. Those lookups are now trivial:

| Old lookup | New form |
|-----------|----------|
| `lt.cdStep` | `pentagonWeakening(lt).depth` — or just a `ℕ` literal for the concrete pairs |
| `lt.isAssociativeSector` | `cdStep ≤ 2` |
| `lt.isMetaLogic` | `cdStep = 4` (Free) |
| `AntiCoherentPair LogicType × LogicType` | `ℕ × ℕ` (just the two cdSteps) |

---

## 2. What Changes

### 2.1 `Generation.lean` — remove `LogicTypes` import

**Current** (lines 50-53):
```lean
structure AntiCoherentPair where
  coherent : LogicType
  antiCoherent : LogicType
```

**New**:
```lean
structure AntiCoherentPair where
  coherent : ℕ        -- cdStep of the coherent logic
  antiCoherent : ℕ    -- cdStep of the anti-coherent logic
```

The concrete pairs (`barber`, `liar`, `grandfather`) become concrete ℕ pairs:

| Name | Old (LogicType) | New (ℕ × ℕ) | Meaning |
|------|----------------|-------------|---------|
| `barber` | `⟨.Classical, .Paraconsistent⟩` | `⟨0, 4⟩` | Associative vs Free |
| `liar` | `⟨.Classical, .ManyValued⟩` | `⟨0, 1⟩` | Two associative logics |
| `grandfather` | `⟨.Classical, .Temporal⟩` | `⟨0, 1⟩` | Temporal at cdStep 1 |

`temporalConflate` (line 93) builds the tree from the cdSteps directly:
```lean
def temporalConflate (pair : AntiCoherentPair) : EMLTree :=
  EMLTree.Node
    (rightComb pair.coherent)
    (rightComb pair.antiCoherent)
```

`inflate` (line 69) maps `ProblemClass → (ℕ × ℕ)` — a pure data table
without `LogicType`:
```lean
def inflate (pc : ProblemClass) : AntiCoherentPair :=
  match pc with
  | .selfReference       => ⟨0, 1⟩     -- classical, many-valued
  | .vagueness           => ⟨0, 1⟩     -- classical, fuzzy
  | .inconsistentDef     => ⟨0, 4⟩     -- classical, paraconsistent
  | .temporalDecision    => ⟨0, 1⟩     -- classical, temporal
  ...
```

`isVacuousType (lt : LogicType)` (line 102) becomes `isVacuousCd (cd : ℕ)`:
```lean
def isVacuousCd (cd : ℕ) : Bool := cd = 0
```

### 2.2 `Problem.lean` — remove `LogicTypes` import

`Problem.lean` currently imports `LogicTypes` for `LogicType` in some type
signatures. With `Generation.lean` moving to `ℕ`, the LogicType references
in Problem.lean's `ProblemClass` and `Problem` structures should be reviewed
— if they're only used by Generation, they become ℕ too.

### 2.3 `Friction.lean` — `native_decide` fix

`frictionDensity_at_cl11_boundary` (line 87) currently uses `native_decide`.
Change to `decide`. This is a trivial computation (Γ₂ = 2) and should be
kernel-checked.

### 2.4 `LogicTypes.lean` — no longer imported by Generation/Problem

The file stays as a theory result (pentagonWeakening, cdStep derivation,
logicFactorization theorems). But it stops being a mandatory dependency
for the generation layer. The `cdStep_eq_pentagonatorDepth` theorem remains
the formal justification for treating `ℕ` as the cost parameter.

---

## 3. What Stays

- `foundations/` — unchanged. Algebra, Tamari, Chu are clean.
- `Friction.lean` — only the `native_decide` fix. `frictionDensity`, `assocDefect`,
  `commDefect`, and all phase-change theorems stay as-is.
- `SubdivisionClosure.lean` — unchanged. `weightedCost`, `closure` are correct.
- `AMM.lean` — unchanged. Already uses `cd : ℕ`, `weightedCost`, `reserveGuard`.
- `TemporalParadox.lean` — unchanged. Already uses `grandfatherCost k = frictionDensity k`.
- `Boundlessness.lean`, `Hopf.lean`, `Entanglement.lean` — all clean.

---

## 4. Files Modified

| File | Change | Risk |
|------|--------|------|
| `LaserCortex/Generation.lean` | `LogicType` → `ℕ` in `AntiCoherentPair` and dependents | Medium — renames and data table changes, no logic change |
| `LaserCortex/Problem.lean` | Remove `LogicTypes` import, review type refs | Low — may already be ℕ-only in practice |
| `LaserCortex/Friction.lean` | `native_decide` → `decide` at line 87 | None |

---

## 5. Order of Operations

```
1. Friction.lean: native_decide → decide    (5 min, no dependencies)
2. Generation.lean: LogicType → ℕ           (30 min, needs #1 for clean build)
3. Problem.lean: remove LogicTypes import    (10 min, needs #2 to verify no dangling refs)
4. lake build                                (verify everything compiles)
5. Commit
```

Total: ~1 hour.
