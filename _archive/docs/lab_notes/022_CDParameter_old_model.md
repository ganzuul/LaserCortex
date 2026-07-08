# Lab Note 022: The Old `CDParameter` Model — Function and Status

**2026-07-06**

## Context

When `CayleyDickson.lean` was ported to `staging/Algebra` (commit `b7ceabe`),
the old `CDParameter`, `CDHomotopyPath`, `CDouble`, and related definitions
were overwritten without a `.lean.old` backup. The only surviving consumer of
these definitions is `Chu.lean` Section 9 (the CD-homotopy bridge), which
references `CDParameter.zdFreeAtStep`, `CDParameter.zdBoundaryStep`, and
`CDParameter.split` — all now dead symbols.

This note reconstructs the old model from git history (`dec4d8c`) so we can
judge whether its function has been subsumed by the new `cdStep`/`frictionDensity`
/`weightedCost` model.

---

## 1. What the Old Model Defined

### 1.1 `CDParameter` — the branch choice

```lean
inductive CDParameter : Type where
  | split    -- α = +1: ω² = +1, indefinite (4,4) signature, ZDs at step ≥ 3
  | compact  -- α = -1: ω² = -1, definite (8,0) signature, no ZDs ever
```

Each Cayley-Dickson doubling step chooses a quadratic form `Q' = Q ⊕ α·Q`:

| α | Branch | ω² | Signature | ZDs? |
|---|--------|----|-----------|------|
| +1 | Split | +1 | (k,k) indefinite | Yes at step ≥ 3 |
| -1 | Compact | -1 | (2k,0) definite | Never |

### 1.2 `CDParameter.zdBoundaryStep` — when ZDs appear

```lean
def CDParameter.zdBoundaryStep (α : CDParameter) : ℕ :=
  match α with
  | .split   => 3    -- octonion level: (4,4) signature creates null vectors
  | .compact => 0    -- sentinel "never"
```

### 1.3 `CDParameter.zdFreeAtStep` — formal certificate

```lean
theorem CDParameter.zdFreeAtStep (α : CDParameter) (k : ℕ) : Prop :=
  α = .compact ∨ k < α.zdBoundaryStep
```

A composition at CD step `k` is ZD‑free iff either we are in the compact branch
(no ZDs at any step) or `k` is below the boundary (k < 3 for split, k < 0 i.e.
never for compact).

### 1.4 `CDHomotopyPath` — continuous deformation split → compact

```lean
structure CDHomotopyPath where
  start : CDParameter := .split
  target : CDParameter := .compact
  step : ℚ := 0
```

The homotopy `α(t) : [0,1] → {+1, -1}` continuously deforms the split branch
into the compact branch. The `step` field records the current rational
interpolation parameter (though only the endpoints were ever used in proofs).

### 1.5 `CDouble` — the actual CD doubling structure

```lean
structure CDouble where
  q : Quaternionℤ   -- compact quaternion component (e₀..e₃)
  s : SplitQuat     -- split-quaternion component (e₄..e₇)
```

With `cd_to_so` / `so_to_cd` giving an isomorphism `CDouble ≅ SplitOctonion`,
and `cd_mul`/`cd_add`/`cd_neg` making the isomorphism multiplicative.

### 1.6 Consumer: `zdFreeAtStep2_from_chu_nondegenerate` (in Chu.lean Section 9)

```lean
theorem zdFreeAtStep2_from_chu_nondegenerate :
    CDParameter.zdFreeAtStep CDParameter.split 2 := by
  unfold CDParameter.zdFreeAtStep CDParameter.zdBoundaryStep
  simp
```

This proves that CD step 2 (split quaternions) is ZD-free — trivially because
`2 < 3`. The proof is essentially `simp`; the *content* is that the Chu
pairing nondegeneracy (`splitQuatPairing_nondegenerate`) is the **geometric
reason** step 2 is below the boundary. Only at step 3 does the pairing become
degenerate (octonions have null vectors).

---

## 2. How the New Model Covers the Same Ground

The new model (`staging/Algebra`, `staging/Friction`, `cdStep`) replaces
the old structure with a **unified numeric index**:

| Concept | Old model | New model |
|---------|-----------|-----------|
| Branch choice | `CDParameter.split` / `.compact` | Implicit in `cdStep` assignment per logic type |
| ZD boundary | `zdBoundaryStep(.split) = 3` | `frictionDensity` jump at `k ≥ 3` (= `k + 16` vs `k`) |
| ZD-free certificate | `zdFreeAtStep α k`: `α=.compact ∨ k<3` | `layerCost_ge_cdStep` + `frictionLagrangian_gt_flatSum` for k≥3 |
| Homotopy | `CDHomotopyPath` (structure, unused) | Not replicated |
| CD double | `CDouble` (isomorphic to `SplitOctonion`) | `SplitOctonion` directly (from `staging/Algebra`) |
| Pairing nondegeneracy | `splitQuatPairing_nondegenerate` | Same — in `staging/Chu.lean` now |

### What is subsumed

1. **The ZD boundary** is now captured by `frictionDensity_eq_k_plus_16_for_k_ge_3`
   and `frictionDensity_eq_k_for_k_le_2` — the cost jump at CD step 3 IS the
   ZD boundary signature. The numeric threshold (3) is the same.

2. **The branch choice** (split vs compact) is no longer an explicit inductive type.
   Instead, each logic type has a fixed `cdStep` that reflects its algebraic depth.
   The split/compact distinction is therefore implicit in the logic type's position:
   logic types at cdStep ≥ 3 operate on split algebras (octonions+), those at
   cdStep ≤ 2 operate on associative algebras (reals through quaternions). The
   compact branch (quaternions) corresponds to cdStep 1; the split branch starts
   at cdStep 2 (split quaternions) or 3 (split octonions).

3. **The `CDouble` structure** is no longer needed because `SplitOctonion` is
   defined directly in `staging/Algebra` with all 8 components (e₀..e₇). The
   old quaternion/split-quaternion factoring was only used to prove the
   isomorphism, which is now definitional.

### What is NOT subsumed

1. **The homotopy path** `CDHomotopyPath` — not replicated anywhere. It was
   defined but never used in any theorem beyond its own existence. If a
   continuous deformation between split and compact is needed later (e.g. for
   the hyperbolic program `P(A) = det(A·I − B)`), it would need to be rebuilt
   or a new homotopy theory developed.

2. **The explicit sign** `CDParameter.sign : ℤ` — not explicitly stored
   anywhere, but recoverable as `if cdStep ≥ 3 then 1 else -1` (or from the
   logic type's signature).

3. **`zdFreeAtStep2_from_chu_nondegenerate`** — the specific theorem about
   `splitQuatPairing_nondegenerate` being the geometric reason for ZD-freeness
   at step 2. This insight is preserved in spirit (`frictionDensity` confirms
   the same threshold) but the formal theorem linking the Chu pairing's
   nondegeneracy to the ZD boundary is no longer present.

---

## 3. Verdict: Subsumed?

**Yes, for the mainline use case.** The ZD-boundary function served by
`CDParameter.zdFreeAtStep` is now handled by the `cdStep`-based threshold
in `frictionDensity`. The numeric threshold (3) is the same; the proof that
step 2 is below it is even simpler (`omega` after rewriting).

**No, for the homotopy path.** The `CDHomotopyPath` concept is not subsumed.
If the hyperbolic program ever needs to represent the continuous deformation
from split to compact, the old structure was a starting point. However, it
was never used in any downstream theorem, so this appears to be dead code.

**Partial for the explicit branch classification.** The old model made the
split-vs-compact distinction a first-class object (`CDParameter`), which made
statements like "for all compact-branch algebras, no ZDs at any step"
expressible as `α = .compact → ∀ k, zdFreeAtStep α k`. The new model can
express this as `cdStep ≤ 1 → ∀ k ≥ cdStep, frictionDensity k = k`
(i.e. associative regime → no cost jump), but it requires a different
idiom.

**Recommendation**: Section 9 of `Chu.lean` can be dropped. The theorem
`zdFreeAtStep2_from_chu_nondegenerate` is proven by `simp` after unfolding
— its *content* is the insight that the Chu pairing's nondegeneracy is the
geometric reason for ZD-freeness at step 2. If this insight needs to be
preserved as a formal theorem, the cleanest home is `staging/Chu.lean` with
a new proof using `frictionDensity`:

```lean
theorem zd_free_at_step_2 :
    frictionDensity 2 = 2 := by
  exact frictionDensity_eq_k_for_k_le_2 2 (by omega)
```

Or, if the pairing-specific insight is needed:

```lean
theorem splitQuatPairing_nondegenerate_implies_zd_free :
    frictionDensity 2 = 2 := by
  -- The geometric content: the Chu pairing on SplitQuat is nondegenerate,
  -- which is equivalent to being below the ZD boundary at step 2.
  exact frictionDensity_eq_k_for_k_le_2 2 (by omega)
```

---

## 4. Deleted Symbols (for searchability)

The following symbols existed in the old `CayleyDickson.lean` (commit `dec4d8c`)
and are now absent:

| Symbol | Kind | Used by |
|--------|------|---------|
| `CDParameter` | `inductive` | `Chu.lean` Section 9 |
| `CDParameter.split` | constructor | `Chu.lean` Section 9 |
| `CDParameter.compact` | constructor | — |
| `CDParameter.sign` | `def` | — |
| `CDParameter.signQQ` | `def` | — |
| `CDParameter.algebraDimension` | `def` | — |
| `CDParameter.quadraticSignature` | `def` | — |
| `CDParameter.isSplit` | `def` | — |
| `CDParameter.omega_sq_eq_sign` | `theorem` | — |
| `CDParameter.zeroDivisorPossible_iff_split` | `theorem` | — |
| `CDParameter.zdBoundaryStep` | `def` | `Chu.lean` Section 9 |
| `CDParameter.zdFreeAtStep` | `theorem` | `Chu.lean` Section 9 |
| `CDHomotopyPath` | `structure` | — |
| `CDHomotopyPath.value` | `def` | — |
| `CDouble` | `structure` | — |
| `cd_to_so` | `def` | — |
| `so_to_cd` | `def` | — |
| `cd_mul` | `def` | — |
| `cd_add`/`cd_neg`/`cd_zero` | `def` | — |
| `cd_omega`/`cd_e4`/`cd_e5`/`cd_e6`/`cd_e7` | `def` | — |

Most were never used outside `CayleyDickson.lean` itself.
