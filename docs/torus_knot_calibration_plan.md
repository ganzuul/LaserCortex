# Torus Knot Calibration Plan

**Version 1.0** | 2026-06-21

## Purpose

Implement torus-knot topology for Spacetime logic in Lean, enabling space-biased
projection operators in the cost landscape, and unify the Lean/Python `NodeCost`
formula by adding the coupling product term that currently exists only in Python.

## Background

### The Structural Problem

The `NodeCost.apply` formula is:

```
Φ(Node a b) = bias + leftWeight·Φ(a) + Φ(b)/(rightDiv+1)
```

This always amplifies left (associative/time) and compresses right (split/space).
No logic can be space-biased. Spacetime logic requires the mirror — swapping which
subtree is amplified vs. compressed.

### The Coupling Gap

Python `_cost.py` includes a product term `coupling·a·b/denom` but Lean `Cost.lean`
does not. The Lean theorems prove properties of a strictly weaker cost function.
This must be unified.

### Critical Corrections (from `docs/critical_corrections.md`)

The cost function is a **depth-1 approximation** — it cannot represent:
- Cross-terms (Quantum non-distributivity, Boolean idempotence)
- Saturation/capping (Fuzzy, Paraconsistent boundedness)
- Max-semantics (Intuitionistic constructive disjunction)
- Fixed-point terms (Epistemic KK thesis)

These are **structural gaps** deferred to Stages 2-4. Stage 1 (this PR) adds
mirror + coupling, which is the minimum for:
1. Space-biased logic (Spacetime)
2. Non-zero cross-terms (Quantum, Paraconsistent, Temporal)
3. Lean/Python parity

## Architecture: Staged Extension

| Stage | What | Status |
|-------|------|--------|
| 0 (current) | `bias + leftWeight·a + b/(rightDiv+1)` | Lean only, no coupling, no mirror |
| **1 (this PR)** | + `mirror : Bool` + `coupling : Nat` + `denom : Nat` | Enables space-bias, unifies Lean/Python |
| 2 (future) | + `satCap : Option Nat` for Fuzzy/Paraconsistent saturation | Capping |
| 3 (future) | + idempotence check for Boolean `Node t t → t` | Quench-collapse |
| 4 (future) | EML depth-2 master formula (14 parameters) | Full expressiveness |

## Step-by-Step Implementation

### Step 1: Extend `NodeCost` in Lean (`Cost.lean`)

**Current structure:**
```lean
structure NodeCost where
  leftWeight : Nat
  rightDiv : Nat
  bias : Nat
```

**Target structure:**
```lean
structure NodeCost where
  leftWeight : Nat
  rightDiv : Nat
  bias : Nat
  mirror : Bool := false
  coupling : Nat := 0
  denom : Nat := 10
```

**Target `apply`:**
```lean
def NodeCost.apply (c : NodeCost) (a b : Nat) : Nat :=
  let linear := if c.mirror then
    c.bias + (a / c.rightDiv.succ) + c.leftWeight * b
  else
    c.bias + c.leftWeight * a + (b / c.rightDiv.succ)
  let product := c.coupling * a * b / max 1 c.denom
  linear + product
```

**Why existing theorems are preserved:**
- All existing logics have `mirror := false` and `coupling := 0` (defaults)
- When `mirror = false` and `coupling = 0`: linear = old formula, product = 0
- `Φ_rightComb_succ`: the coupling term vanishes because the left subtree of
  `rightComb(n+1)` is always `Leaf` with cost 0, so `coupling * 0 * b = 0`
- `max 1 c.denom` prevents division by zero when `denom = 0`

### Step 2: Update `nodeParam` in Lean (`Cost.lean`)

Add coupling values for logics that have them in Python and set Spacetime mirror:

```lean
| .Paraconsistent => { leftWeight := 2, rightDiv := 1, bias := 1, coupling := 1, denom := 8 }
| .Temporal       => { leftWeight := 2, rightDiv := 1, bias := 1, coupling := 1, denom := 8 }
| .Quantum        => { leftWeight := 1, rightDiv := 1, bias := 1, coupling := 1, denom := 10 }
| .Spacetime      => { leftWeight := 0, rightDiv := 0, bias := 1, mirror := true, coupling := 0, denom := 10 }
```

All other logics use defaults (`mirror := false, coupling := 0, denom := 10`).

### Step 3: Relax `nodeParam_leftWeight_ge_one`

**Current:** `∀ L, 1 ≤ (nodeParam L).leftWeight` — breaks for Spacetime (leftWeight=0).

**Target:**
```lean
theorem nodeParam_leftWeight_ge_one (L : LogicTypes.LogicType)
    (h : ¬(nodeParam L).mirror) : 1 ≤ (nodeParam L).leftWeight := by
  cases L <;> simp [nodeParam] at h ⊢
```

Also add a general `nodeParam_leftWeight_nonneg` (trivial for Nat):
```lean
theorem nodeParam_leftWeight_nonneg (L : LogicTypes.LogicType) :
    0 ≤ (nodeParam L).leftWeight := Nat.zero_le _
```

### Step 4: Add Spacetime-specific theorems

With Spacetime params `{ leftWeight := 0, rightDiv := 0, bias := 1, mirror := true, coupling := 0 }`:

```lean
/-- Spacetime cost follows the left spine: Φ(Node l r) = 1 + Φ(l) -/
theorem Φ_spacetime_apply (l r : EMLRegistry.EMLTree) :
    Φ .Spacetime (.Node l r) = 1 + Φ .Spacetime l := by
  simp [Φ, nodeParam, NodeCost.apply]
  ring

/-- Right-comb under Spacetime always costs 1 (left child is always Leaf). -/
theorem Φ_spacetime_rightComb (n : Nat) :
    Φ .Spacetime (EMLRegistry.rightComb n) = 1 := by
  sorry  -- prove by induction

/-- Left-comb under Spacetime costs n (matches p-winding of (2,3) trefoil). -/
theorem Φ_spacetime_leftComb (n : Nat) (hn : 0 < n) :
    Φ .Spacetime (EMLRegistry.leftComb n) = n := by
  sorry  -- prove by induction

/-- Spacetime gradient reverses: L-bracketing costs MORE than R-bracketing. -/
theorem Φ_spacetime_gradient_reversed :
    Φ .Spacetime (.Node (.Node .Leaf .Leaf) .Leaf) = 2 ∧
    Φ .Spacetime (.Leaf .Node .(.Leaf .Leaf)) = 1 := by
  constructor <;> simp [Φ, nodeParam, NodeCost.apply]
```

### Step 5: Update `LogicTypes.lean` — Spacetime sector

Change `isAssociativeSector` for Spacetime from `true` to `false`:

```lean
| .Spacetime => false  -- Space-biased: associator-dominant split sector
```

### Step 6: Update Python `_cost.py`

Add `mirror` field to `NodeCost`:

```python
@dataclass(frozen=True)
class NodeCost:
    leftWeight: int
    rightDiv: int
    bias: int
    coupling: int = 0
    denom: int = 10
    mirror: bool = False

    def apply(self, a: int, b: int) -> int:
        if self.mirror:
            linear = self.bias + (a // max(1, self.rightDiv + 1)) + self.leftWeight * b
        else:
            linear = self.bias + self.leftWeight * a + (b // max(1, self.rightDiv + 1))
        product = (self.coupling * a * b) // max(1, self.denom)
        return linear + product
```

Update `NODE_PARAM` for Spacetime:
```python
LogicType.SPACETIME: NodeCost(leftWeight=0, rightDiv=0, bias=1, mirror=True),
```

### Step 7: Update Python `_logic_types.py`

Remove Spacetime from `is_associative_sector`:
```python
return self in {
    LogicType.CLASSICAL, LogicType.FUZZY, LogicType.MANY_VALUED,
    LogicType.TEMPORAL, LogicType.DEONTIC, LogicType.EPISTEMIC,
    LogicType.BOOLEAN,
    # Spacetime REMOVED — now space-biased via mirror flag
}
```

### Step 8: Update `test_timespace_decomposition.py`

`sector_weights()` must handle mirror:
```python
def sector_weights(params: NodeCost) -> Dict[str, float]:
    if params.mirror:
        tw = 1.0 / (params.rightDiv + 1)      # time compressed
        sw = params.leftWeight                     # space amplified
    else:
        tw = params.leftWeight                     # time amplified
        sw = 1.0 / (params.rightDiv + 1)         # space compressed
    ...
```

### Step 9: Create `test_torus_knot_calibration.py`

Tests:
1. Mirror formula applies correctly for Spacetime
2. Spacetime Φ follows left spine: Φ(Node l r) = 1 + Φ(l)
3. Spacetime rightComb always costs 1
4. Spacetime leftComb costs n (matches trefoil p-winding)
5. Gradient reversal: leftComb is maximum for Spacetime (not rightComb)
6. Canonical triple: |Φ(L) - Φ(R)| = 1 for Spacetime (was 2 for Paraconsistent)
7. Coupling product term is mirror-invariant (symmetric in a·b)
8. All existing Boolean, zero-divisor, Cayley-Dickson tests still pass
9. Spacetime is now space-biased (sw > tw)
10. All other logics remain time-biased or balanced

### Step 10: Update documentation

- `docs/lab_protocol.md` v0.3: Mirror flag, coupling in Lean, Spacetime recalibrated, sector table update
- `lab_notes/004_coupling_sweep.md`: Append Spacetime recalibration results

## Torus Knot Verification Targets

The (p,q) = (2,3) trefoil knot has:
- p = 2 (associative/time winding) → leftWeight=0 silences the commutator
- q = 3 (split/space winding) → the associator dominates (Φ follows left spine)
- Crossing number: min(p(q-1), q(p-1)) = min(4, 3) = 3

For Spacetime (mirrored, leftWeight=0, rightDiv=0):
- Φ(leftComb(n)) = n → matches p-winding = 2 at depth 2
- |Φ(L) - Φ(R)| = 1 → gradient drives toward leftComb
- The torque of the cost landscape now spirals in the opposite direction

## Known Structural Gaps (Deferred)

Per `docs/critical_corrections.md`, the following are **not in scope** for this PR:

1. **Boolean idempotence** — `Node t t → t` with cost 0, requires structural comparison
2. **Max-semantics for Intuitionistic** — `max(a, b)` requires depth-4 EML tree
3. **Saturation capping** — `min(a+b, C)` for Fuzzy/Paraconsistent (Stage 2)
4. **EML depth-2 master formula** — 14-parameter full expressiveness (Stage 4)
5. **Epistemic KK fixed-point** — Self-referential cost, infinite regress

These are documented as future milestones.

## Verification Checklist

- [ ] `lake build` passes with zero sorries
- [ ] `nodeParam_leftWeight_ge_one` relaxed to conditional on `¬mirror`
- [ ] `nodeParam_bias_one` still holds for all 15 logics
- [ ] `Φ_rightComb_succ` still correct (coupling vanishes at rightComb Leaf)
- [ ] `Φ_rightComb_classical` still correct for Boolean/Intuitionistic/Free
- [ ] `Φ_eq_size_classical` still correct for rightDiv=0 logics
- [ ] Spacetime mirror mode produces inverted gradient
- [ ] Spacetime `isAssociativeSector = false` in both Lean and Python
- [ ] All existing Python tests pass (Boolean, zero-divisor, Cayley-Dickson, timespace)
- [ ] New torus knot tests pass
- [ ] Coupling term in Lean matches Python for all coupled logics

## Files Modified

| File | Change |
|------|--------|
| `LaserCortex/Cost.lean` | Add mirror/coupling/denom fields, update apply, update nodeParam, add theorems |
| `LaserCortex/LogicTypes.lean` | Change Spacetime sector to false |
| `infra/_cortex/_cost.py` | Add mirror field, update apply, update NODE_PARAM |
| `infra/_cortex/_logic_types.py` | Update is_associative_sector |
| `infra/tests/test_torus_knot_calibration.py` | New test file |
| `infra/tests/test_timespace_decomposition.py` | Update sector_weights for mirror |
| `docs/lab_protocol.md` | Update to v0.3 |
| `lab_notes/004_coupling_sweep.md` | Append Spacetime recalibration |
| `docs/torus_knot_calibration_plan.md` | This file |