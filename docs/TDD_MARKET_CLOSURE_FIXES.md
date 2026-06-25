# TDD Implementation Guide: Market Closure Fixes

**Status**: Draft · **Target**: 8 findings from GLM-5.2 verification of DeepSeek V4 Flash implementation  
**Method**: RED/GREEN Lean theorem-writing per finding — each fix begins with a failing theorem that captures the intended contract.  
**Build check**: `lake build LaserCortex.MarketClosure` (fast, ~10s) for phases 1–4; full `lake build` (~2min) for phase 5.

---

## Phase 0: Setup — test infrastructure

### 0a. Create a local test macro (optional but handy)

Add to `LaserCortex/TestUtils.lean` (new file, minimal imports):

```lean
import LaserCortex.AMM
import LaserCortex.MarketClosure
import LaserCortex.InstitutionalClosure
import LaserCortex.Cost

open AMM
open MarketClosure
open InstitutionalClosure
open Cost

/-! Shared test utilities for the TDD cycles below.
    These are `example` blocks that fail at import time if any
    of the basic types are missing or mis-typed. -/

example : KernelChoice = KernelChoice := rfl

example : MarketType = MarketType := rfl

example : AMM.Pool → AMM.Pool := id

example (L : LogicTypes.LogicType) (t1 t2 : EMLTree) : Nat :=
  crossImpactTree L t1 t2
```

Register in `LaserCortex.lean`:
```lean
import LaserCortex.TestUtils
```

TDD cycle: `lake build LaserCortex.TestUtils` should show 4 passing examples.

---

## Phase 1: Critical semantic drift (two interdependent fixes)

These two must be done together because `reserveGuard` needs the correct `L` parameter, and `marketClosure` needs to thread it through.

### Finding #2 (blocking): `marketClosure` hardcodes `LogicTypes.LogicType.Classical`

#### Contract

`marketClosure` must accept an `L : LogicTypes.LogicType` parameter and use it for ALL cost computations, rather than hardcoding `LogicTypes.LogicType.Classical`.

The kernel-norm abstraction demands:
- `KernelChoice.none` → `Φ .Fuzzy` (Sorites: graded valuation, bounded at 5)
- `KernelChoice.arbitrary` → `Φ .Deontic` (Edict: normative full non-associativity)
- `KernelChoice.fairPrice` → `Φ .Classical` (AMM: size-parametric cost)

But the *caller* decides — `marketClosure` should accept any `L` and use it mechanically.

#### RED test (write first, expect build error)

Add to `LaserCortex/MarketClosure.lean`, near line 155, BEFORE the existing `marketClosure` definition:

```lean
/-- TEST: marketClosure must accept a non-Classical LogicType and use it
    for all cost computations. If the test compiles, the parameter exists
    and is threaded through. -/
example (kernel : KernelChoice) (pool : AMM.Pool) (cdStep : Nat)
    (history : LogicM InstitutionalClosure.GameOutcome)
    (tree : EMLRegistry.EMLTree) (dx : Nat)
    (initialNorm : InstitutionalClosure.Norm) : True :=
  -- marketClosure must accept L : LogicTypes.LogicType as a parameter
  let _ := marketClosure kernel pool LogicTypes.LogicType.Fuzzy cdStep history tree dx initialNorm
  trivial
```

Expected error: `function marketClosure expects 8 arguments, but 9 are given`  
(or similar — the current signature takes 8 args, the test passes 9 including `L`).

#### GREEN fix

Change the `marketClosure` signature (line 155) to add `L` as the 3rd parameter:

```lean
def marketClosure (kernel : KernelChoice) (pool : AMM.Pool)
    (L : LogicTypes.LogicType)           -- ← NEW parameter (was hardcoded Classical)
    (cdStep : Nat) (history : LogicM InstitutionalClosure.GameOutcome)
    (tree : EMLRegistry.EMLTree) (dx : Nat)
    (initialNorm : InstitutionalClosure.Norm)
    : LogicM InstitutionalClosure.Norm × MarketType × Option CertifiedPrice :=
```

Then replace the two `LogicTypes.LogicType.Classical` usages (lines 164, 169) with `L`:

```lean
  let mkt : MarketType := decideMarketType kernel pool L tree dx
  ...
      let closeRes := AMM.certifiedClose pool L tree dx
```

#### Verify

```bash
lake build LaserCortex.MarketClosure
```

All 1777 jobs should pass. The test `example` above now type-checks because `marketClosure` accepts `LogicType.Fuzzy`.

---

### Finding #1 (critical): `reserveGuard` semantics drift from pool reserve to swap output

#### Contract

`reserveGuard` must return `true` when `Φ L tree ≥ pool.reserveB` (pool survival check), NOT when `Φ L tree ≥ swapOut pool dx` (profitability check). The plan explicitly states:

> "would annihilate the **reserve**" (plan lines 83, 147)  
> "if FL ≥ reserve → paradoxMarket (ZD caught)" (plan line 139)

`pool.reserveB` is the pool's balance of token B — the total liquidity available. `swapOut pool dx` is a *fraction* of that. The plan intends to prevent the computation cost from draining the entire pool, not from exceeding the trade proceeds.

#### RED test (write first)

Add to `LaserCortex/AMM.lean`, near line 283, BEFORE the existing `reserveGuard`:

```lean
/-- TEST: reserveGuard must compare against pool.reserveB, NOT against
    swapOut pool dx. We construct a pool where swapOut < reserveB but
    Φ > swapOut, and assert that the guard is still FALSE because
    Φ < reserveB.

    Pool: 1000 A, 100 B (reserveB = 100).
    swapOut(10 A) = floor(100*10 / 1010) = 0 (floor division).
    Φ Classical for any tree of size 1 = 1 (size).
    1 ≥ 0 (swapOut) is true, but 1 ≥ 100 (reserveB) is false.
    The guard must return false (Φ < reserveB, no ZD). -/
example : ¬ AMM.reserveGuard
    (AMM.Pool.mk 1000 100 (by decide) (by decide))
    LogicTypes.LogicType.Classical
    (EMLTree.Node EMLTree.Leaf EMLTree.Leaf)
    10 := by
  native_decide
```

Expected error: `native_decide` fails because `reserveGuard` (current impl) returns `true` (it compares cost=1 ≥ swapOut=0, which is true), but the test expects `false`.

#### GREEN fix

Change line 287 in `AMM.lean` from `cost ≥ price` to `cost ≥ pool.reserveB`:

```lean
def reserveGuard (pool : Pool) (L : LogicTypes.LogicType) (tree : EMLTree) (dx : Nat) : Bool :=
  let cost := Φ L tree
  -- Compare against pool.reserveB (total liquidity), NOT swapOut (trade proceeds).
  -- plan: "would annihilate the reserve / ZD caught"
  cost ≥ pool.reserveB
```

Also update the docstring (lines 268–282) — remove references to "profitability" and "price", align with "reserve annihilation":

```
/-- The reserve-vs-FL guard. Returns true if the computation cost Φ L tree
    meets or exceeds the entire pool reserve (reserveB), meaning the attempt
    would annihilate the pool's liquidity (zero-divisor territory).

    Cases:
    1. Φ L tree ≥ pool.reserveB → true (reserve annihilated → paradox market).
    2. Φ L tree < pool.reserveB → false (safe to compute the price).

    ZD detection via Generation.revise is NOT yet wired into this guard;
    that would catch the case where both poles are vacuous even before
    the cost check. Tracked as a TODO once the WFC engine integration
    stabilizes.

    Cache lookup for precomputed Φ costs is a TODO (realistic systems
    would have libraries of precomputed costs; we start with no cache).
    The pool reserves are externally supplied; this function does not
    derive them from ProblemClass or BlamePool. -/
```

#### Verify

```bash
lake build LaserCortex.AMM
```

The `native_decide` test should now pass. Run the the swap-preserves-k-bound theorem to verify no regression on the existing proof:

```bash
lake build LaserCortex.AMM
# Check that swap_preserves_k_bound still holds:
lean-lsp_lean_diagnostic_messages LaserCortex/AMM.lean --severity error
```

Expected: 0 errors.

---

## Phase 2: Proof coverage (restoring theorems for generalized functions)

### Finding #4: Regression — `crossImpactTree` and `associatorCostTree` have zero theorems

The old Route-typed versions had `crossImpact_nonneg`, `crossImpact_classical`, `associatorCost_zero_classical`. The EMLTree-typed generalizations have none. This is a regression in proof coverage.

#### 2a. Theorem: `crossImpactTree_nonneg`

Add to `LaserCortex/AMM.lean`, after the `crossImpactTree` definition (line 245):

```lean
/-- TEST (RED): crossImpactTree is always non-negative (ℕ subtraction truncates,
    so the theorem is trivial — but it must exist to match the Route-typed
    version's proof coverage). -/
example (L : LogicTypes.LogicType) (t1 t2 : EMLTree) : 0 ≤ crossImpactTree L t1 t2 := by
  -- This will fail because crossImpactTree is defined as truncating subtraction,
  -- and the theorem exists only at the meta-level. If crossImpactTree were
  -- redefined as Int arithmetic, this would need a real proof.
  sorry
```

**GREEN proof** (replace `sorry`):

```lean
theorem crossImpactTree_nonneg (L : LogicTypes.LogicType) (t1 t2 : EMLTree) :
    0 ≤ crossImpactTree L t1 t2 :=
  Nat.zero_le _
```

This is a vacuous truth in ℕ (truncated subtraction is always ≥ 0), same as the original `crossImpact_nonneg`. The theorem exists to:
1. Match the proof surface of the old Route-typed version
2. Provide a hook for when/if we move to `Int` arithmetic (where the theorem would be non-trivial)

#### 2b. Theorem: `crossImpactTree_classical`

Add after `crossImpactTree_nonneg`:

```lean
/-- TEST (RED): For classical logic parameters (rightDiv=0, coupling=0,
    not mirror, leftWeight=1, not maxSem, satCap=0), crossImpactTree
    equals 1 for any non-trivial tree pair.

    This is the EMLTree analogue of the original crossImpact_classical,
    generalized from Route to EMLTree.

    The classical condition means Φ L t = t.size, so:
      crossImpactTree L t1 t2 = (t1.size + t2.size + 1) - (t1.size + t2.size) = 1
    — because Φ(Node t1 t2) = size(Node t1 t2) = 1 + t1.size + t2.size,
    and Φ(t1) + Φ(t2) = t1.size + t2.size. -/
theorem crossImpactTree_classical (L : LogicTypes.LogicType) (t1 t2 : EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    crossImpactTree L t1 t2 = 1 := by
  sorry
```

**GREEN proof**:

```lean
theorem crossImpactTree_classical (L : LogicTypes.LogicType) (t1 t2 : EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    crossImpactTree L t1 t2 = 1 := by
  dsimp [crossImpactTree]
  have hΦnode : Φ L (.Node t1 t2) = (.Node t1 t2).size :=
    Φ_eq_size_classical L (.Node t1 t2) hD hC hM hW hMS hSC
  have hΦt1 : Φ L t1 = t1.size :=
    Φ_eq_size_classical L t1 hD hC hM hW hMS hSC
  have hΦt2 : Φ L t2 = t2.size :=
    Φ_eq_size_classical L t2 hD hC hM hW hMS hSC
  rw [hΦnode, hΦt1, hΦt2]
  simp [EMLTree.size]
```

#### 2c. Theorem: `associatorCostTree_zero_classical`

Add after `associatorCostTree` definition (line 249):

```lean
/-- TEST (RED): For classical logic parameters, the associator cost is zero
    (pentagon coherence: both bracketings of a triple have the same Φ cost
    under classical logic). This is the EMLTree analogue of the original
    associatorCost_zero_classical. -/
theorem associatorCostTree_zero_classical (L : LogicTypes.LogicType) (t1 t2 t3 : EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    associatorCostTree L t1 t2 t3 = 0 := by
  sorry
```

**GREEN proof**:

```lean
theorem associatorCostTree_zero_classical (L : LogicTypes.LogicType) (t1 t2 t3 : EMLTree)
    (hD : (nodeParam L).rightDiv = 0) (hC : (nodeParam L).coupling = 0)
    (hM : ¬(nodeParam L).mirror) (hW : (nodeParam L).leftWeight = 1)
    (hMS : ¬(nodeParam L).maxSem) (hSC : (nodeParam L).satCap = 0) :
    associatorCostTree L t1 t2 t3 = 0 := by
  dsimp [associatorCostTree, absDiff]
  have h_eq : Φ L (.Node (.Node t1 t2) t3) = Φ L (.Node t1 (.Node t2 t3)) :=
    Φ_contracts_one_eq_classical L hD hC hM hW hMS hSC (by
      apply EMLRegistry.contracts_one.rotate)
  simp [h_eq]
```

This proof mirrors the original `associatorCost_zero_classical` exactly but operates on `EMLTree` directly (no `routeToTree` conversion needed).

#### Verify

```bash
lake build LaserCortex.AMM
```

All 3 new theorems should compile without `sorry`. Run the existing `swap_preserves_k_bound` to verify no regression:

```bash
lean-lsp_lean_diagnostic_messages LaserCortex/AMM.lean --severity error
```

Expected: 0 errors.

---

## Phase 3: Missing documentation and vacuum proofs

### Finding #3: Add the `fuzzyGrade` TODO comment in `InstitutionalClosure.lean`

#### Contract

Per plan §3c, add a TODO comment near `fuzzyGradeByCdStep` that notes the future `engine_to_nodecost` delegation.

#### RED test

There is no Lean test for this — it's a documentation issue. Instead, the test is:

```bash
grep -c "engine_to_nodecost" LaserCortex/InstitutionalClosure.lean
# Expected output: ≥ 1 (must contain the keyword)
```

#### GREEN fix

Insert after line 272 (`fuzzyGradeByCdStep` definition, after the closing `)`), add the TODO comment:

```lean

/- TODO: in the (b) development of KernelChoice, fuzzyGrade could delegate
   to SplitOctonionCost.engine_to_nodecost rather than hardcoding the
   D→impact mapping. The current hardcoded version is the (a) minimal
   scaffold; the (b) version would unify BlamePool and NonAssociativeBudget.
   See also docs/PLAN_market_closure.md §3c and §6. -/
```

**Location**: between the `fuzzyGradeByCdStep` definition (ending line 272 `)`) and the `fuzzyGradeByCdStep` docstring of the next section. The intended locus is *inside* the `/-! ### Pentagonator-Graded Evaluation` section but *after* the existing function — a natural boundary for a forward-looking note.

#### Verify

```bash
grep "engine_to_nodecost" LaserCortex/InstitutionalClosure.lean
```

Should return the comment line.

---

### Finding #7: Document `CloseResult.h_nonnegative` as vacuous

#### Contract

The `h_nonnegative` field in `CloseResult` currently proves `Nat.zero_le (price - costDeduction)` — always true in ℕ. The real invariant is enforced by `reserveGuard`. Document this explicitly.

#### RED test

```bash
grep -c "vacuous" LaserCortex/AMM.lean
# Expected: ≥ 1 (contains the word "vacuous" near CloseResult)
```

#### GREEN fix

Update the `CloseResult` docstring and field comment (line 261–266):

```lean
/-- The result of an AMM close operation: the fair price, the friction cost
    deduction, and the net residue. This is the AMM-local structure that
    MarketClosure.CertifiedPrice wraps with a CortexCertificate.

    INVARIANT NOTE: the field `h_nonnegative : residue ≥ 0` is intentionally
    VACUOUS in ℕ arithmetic (truncated subtraction means residue is always
    ≥ 0). The *operational* guarantee that price ≥ costDeduction is enforced
    by the caller-side `reserveGuard` returning false, which ensures
    Φ L tree < pool.reserveB (the pool survives the computation).
    A future migration to Int arithmetic would make h_nonnegative
    a non-trivial proof obligation (see also docs/PLAN_market_closure.md §6).

    See MarketClosure.lean for the full CertifiedPrice structure that wraps
    this result with a CortexCertificate. -/
structure CloseResult where
  price         : Nat
  costDeduction : Nat
  residue       : Nat
  h_nonnegative : residue ≥ 0     -- vacuous in ℕ; real invariant is caller-side reserveGuard
```

#### Verify

```bash
grep "vacuous" LaserCortex/AMM.lean
```

---

### Finding #8: Fix unnecessarily verbose `LogicTypes.LogicType.Classical` → `LogicType.Classical`

#### Contract

`open LogicTypes` is already declared at the top of `MarketClosure.lean` (line 60). The fully qualified `LogicTypes.LogicType.Classical` is redundant. Fix both occurrences.

#### RED test

```bash
grep -c "LogicTypes.LogicType.Classical" LaserCortex/MarketClosure.lean
# Expected: 0 (after both occurrences are replaced)
```

#### GREEN fix

Replace both occurrences of `LogicTypes.LogicType.Classical` with `LogicType.Classical`:

```lean
  -- Line 164:
  let mkt : MarketType := decideMarketType kernel pool L tree dx
  -- (L replaces the old hardcoded Classical — already fixed in Phase 1)
```

Wait — the hardcoded `LogicTypes.LogicType.Classical` on line 164 was already replaced by `L` in Phase 1. Let me check what remains.

Actually, with Phase 1 fix, both lines 164 and 169 now use `L` instead of `LogicTypes.LogicType.Classical`. So Finding #8 is resolved as a side-effect of Finding #2. 

However, there may be other instances in the file where the fully qualified name is used unnecessarily. Check:

```bash
grep "LogicTypes.LogicType" LaserCortex/MarketClosure.lean
```

If any remain outside of the decideMarketType signature (which uses `LogicTypes.LogicType` as a parameter type — that's necessary because `LogicType` is defined in both `EMLRegistry` and `LogicTypes`, and the open is for `LogicTypes`), replace with `LogicType` where unambiguous.

The `decideMarketType` signature on line 124 uses `LogicTypes.LogicType` — this is correct because the function parameter type needs the full path to disambiguate from `EMLRegistry.LogicType` (which is the EML tree logic type, different from the cost algebra LogicType). Keep as-is.

#### Verify

```bash
lake build LaserCortex.MarketClosure
lean-lsp_lean_diagnostic_messages LaserCortex/MarketClosure.lean --severity error
```

---

## Phase 4: Dead-code removal

### Finding #5: Remove unused imports

#### Contract

`Generation` and `FrictionLagrangian` are imported in both `AMM.lean` and `MarketClosure.lean` but not used (all references are in doc comments only, not in actual code). Remove them to avoid dead-weight dependencies and unnecessary compile-time expansion.

#### RED test

Check that removing the imports doesn't break the build:

```bash
# Before change: note current build state
lake build LaserCortex.AMM LaserCortex.MarketClosure
```

#### GREEN fix

In `AMM.lean` (lines 29–30):
```lean
-- Remove:
import LaserCortex.Generation
import LaserCortex.FrictionLagrangian
```

Also remove the `open` references if any exist (they don't in AMM.lean — only `open EMLRegistry` and `open Cost`).

In `MarketClosure.lean` (lines 52–53):
```lean
-- Remove:
import LaserCortex.Generation
import LaserCortex.FrictionLagrangian
```

And remove the corresponding `open` statements (lines 64–65):
```lean
-- Remove:
open FrictionLagrangian
open SplitOctonionCost
```

**Check** that `SplitOctonionCost` is also unused (verify no symbol from that module is referenced in MarketClosure.lean). If `NonAssociativeBudget` from `SplitOctonionCost` is used in `blameToBudget`, keep the import. Indeed, line 187 references `NonAssociativeBudget`, so `SplitOctonionCost` stays — but the `open SplitOctonionCost` may be unnecessary if `NonAssociativeBudget` is used qualified. Check:

In `blameToBudget` (line 187): `: NonAssociativeBudget` — if `open SplitOctonionCost` is removed, this must become `SplitOctonionCost.NonAssociativeBudget` or `NonAssociativeBudget` must be resolved through a qualified import. Since the return type is `NonAssociativeBudget`, and there's no other `NonAssociativeBudget` in scope, it'll fail without the open or without qualification. So either:
- Keep `open SplitOctonionCost`, OR
- Remove the open and qualify the return type: `: SplitOctonionCost.NonAssociativeBudget`

Recommend: keep `open SplitOctonionCost` for now (it's actually used). Remove only `FrictionLagrangian` and `Generation`.

#### Verify

```bash
lake build LaserCortex.AMM LaserCortex.MarketClosure
```

If any symbol breaks, examine the error — it may point to an undocumented use (e.g. a `Φ` from `FrictionLagrangian` rather than from `Cost`). Re-add only the minimal import that resolves the failure.

---

### Finding #6: Clean up comment-block formatting

#### Contract

Plan §3f specified `/- ... -/` block comments for the old Route-typed functions. DeepSeek used `--` line comments which are functional but messy. The fix is optional (stylistic) — only do this if other changes touch the same area.

#### GREEN fix (optional, low priority)

Replace lines 191–232 (the commented-out definitions) with a single block comment:

```lean
/-! ### Route-typed cross-impact (preserved for design wisdom)

    The following crossImpact and associatorCost definitions (Route-typed)
    are commented out, NOT deleted. They carry design information about
    AMM's concept of binary-tree swap routes that should be assimilated
    before removal. Once the EMLTree generalizations below are fully
    verified, these can be removed or their design wisdom documented
    separately.

    Generalized to EMLTree below — these Route-typed versions are preserved
    here for design wisdom until the assimilation is verified. Once the
    EMLTree version is fully tested, these can be removed.
-/

/-- Absolute difference of two natural numbers: |a - b| in ℕ. -/
def absDiff (a b : Nat) : Nat := (a - b) + (b - a)

/-
[Original crossImpact definition, commented out]
def crossImpact (L : LogicTypes.LogicType) (r1 r2 : Route) : Nat := ...

[Original crossImpact_nonneg theorem, commented out]
theorem crossImpact_nonneg (L : LogicTypes.LogicType) (r1 r2 : Route) : 0 ≤ crossImpact L r1 r2 := ...

[Original crossImpact_classical theorem, commented out]
theorem crossImpact_classical (L : LogicTypes.LogicType) (r1 r2 : Route) ... : crossImpact L r1 r2 = 1 := ...

[Original associatorCost definition, commented out]
def associatorCost (L : LogicTypes.LogicType) (r1 r2 r3 : Route) : Nat := ...

[Original associatorCost_zero_classical theorem, commented out]
theorem associatorCost_zero_classical (L : LogicTypes.LogicType) (r1 r2 r3 : Route) ... : associatorCost L r1 r2 r3 = 0 := ...
-/
```

**Note**: the `absDiff` definition (line 189) must stay OUTSIDE the block comment — it is used by the new `associatorCostTree` and is not deprecated.

#### Verify

```bash
lake build LaserCortex.AMM
```

---

## Phase 5: Integration tests (NormCode pipeline)

### Contract

The .ncd plan must correctly dispatch through the new signatures. Three inferences were verified during the initial implementation — after the fixes above, they must still lift.

#### 5a. Parse test (smoke)

```bash
python3 /home/nos/labware/open-notebook/scripts/pipeline/normcode_parse_file.py \
  /home/nos/labware/LaserCortex/LaserCortex/examples/market_closure/market_closure.ncd
```

Expected: structured JSON output, no parse errors.

#### 5b. Lift test (three inferences)

Re-run the three `normcode_lift_inference` calls:

```bash
# Temporal normalize (index 1017/1024)
curl -s http://localhost:8080/normcode/lift_inference \
  -H "Content-Type: application/json" \
  -d '{
    "flow_index": "1017",
    "concept_name": "market_events",
    "sequence_type": "temporal_normalize",
    "supporting_count": 1
  }'

# Compute price (index 0/1024)
curl -s http://localhost:8080/normcode/lift_inference \
  -H "Content-Type: application/json" \
  -d '{
    "flow_index": "0",
    "concept_name": "fair_price",
    "sequence_type": "compute_price",
    "concept_json": "{\"pool\": {\"reserveA\": 1000, \"reserveB\": 100}}",
    "supporting_count": 1
  }'

# Deontic update (index 1020/1024)
curl -s http://localhost:8080/normcode/lift_inference \
  -H "Content-Type: application/json" \
  -d '{
    "flow_index": "1020",
    "concept_name": "threshold",
    "sequence_type": "deontic_update",
    "supporting_count": 1
  }'
```

Expected: each returns a JSON with `"certificate": {...}` and `"concept": {...}`.

#### 5c. Economic integration test

Add a **new end-to-end test** to `tests/test_cortex_bridge.py` that exercises the full `marketClosure` pipeline through the Python bridge:

```python
# In tests/test_cortex_bridge.py, add:

def test_market_closure_sorites_path():
    """Sorites (KernelChoice.none) → openMarket — no certificate emitted."""
    bridge = NormCodeCortexBridge()

    # Sorites path: no kernel selected
    result = bridge.invoke_market_closure(
        kernel="none",
        pool={"reserveA": 1000, "reserveB": 100},
        L="Fuzzy",
        tree=rightComb(3),
        dx=10,
        cdStep=1,
        norm={"rule": "initial", "threshold": 100, "kernel": "none"},
    )
    assert result["market_type"] == "openMarket"
    assert result["certified_price"] is None
```

If `invoke_market_closure` doesn't exist on the Python bridge, the test serves as a specification for the missing bridge function — defer to Phase 2 of the .ncd plan.

---

## Acceptance criteria

All fixes pass when the following command exits with status 0:

```bash
echo "=== Phase 1 ===" && \
lake build LaserCortex.MarketClosure && \
lake build LaserCortex.AMM && \
echo "=== Phase 2 ===" && \
lake build LaserCortex.AMM && \
echo "=== Phase 3 ===" && \
grep -q "engine_to_nodecost" LaserCortex/InstitutionalClosure.lean && \
grep -q "vacuous" LaserCortex/AMM.lean && \
echo "=== Phase 4 ===" && \
lake build LaserCortex.AMM LaserCortex.MarketClosure && \
echo "=== Phase 5 ===" && \
python3 tests/test_cortex_bridge.py -k test_market_closure && \
echo "=== ALL PASS ==="
```

## Execution order (recommended)

| Step | Finding | File(s) | Estimated time |
|------|---------|---------|----------------|
| 1 | #2 marketClosure L param | MarketClosure.lean | 5 min |
| 2 | #1 reserveGuard semantics | AMM.lean | 10 min |
| 3 | Build check | `lake build` | 2 min |
| 4 | #4 crossImpactTree theorems | AMM.lean | 15 min |
| 5 | Build check | `lake build` | 2 min |
| 6 | #3 fuzzyGrade TODO | InstitutionalClosure.lean | 2 min |
| 7 | #7 h_nonnegative documentation | AMM.lean | 3 min |
| 8 | #5 unused imports | AMM.lean, MarketClosure.lean | 5 min |
| 9 | Final build | `lake build` | 2 min |
| 10 | #6 comment formatting (opt) | AMM.lean | 3 min |
| 11 | Phase 5 integration tests | .ncd, test_cortex_bridge.py | 10 min |

**Total**: ~60 min for all fixes, ~45 min for critical+high priority only (Phases 1–3).
