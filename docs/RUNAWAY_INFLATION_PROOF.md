# Runaway Inflation Proof

**Goal**: Prove that certain smart contracts exhibit unbounded token printing
(runaway inflation) *because* they lack the structural mechanisms that only
become available at higher cdSteps.

This ties the Eigenstate bridge back to the institutional closure narrative
and demonstrates resolution in the hard-to-reach parts of the algebraic
structure (CD 2→3 discontinuity, e₄ coupling, non-associative regimes).

---

## 1. What "runaway inflation" means

A contract exhibits **runaway inflation** when there is no bound on the total
token supply reachable from a finite initial state via valid state transitions.

Formally:
```
runaway_inflation (c : EVMContract) : Prop :=
  ∀ supply : ℕ, ∃ (steps : List StateTransition),
    execute c initialState steps = some (finalState)
    ∧ finalState.supply ≥ supply
```

The **reserve guard** `reserveB ≥ L` from MarketClosure is exactly the
mechanism that prevents this: it caps the cost that can be extracted from
the pool, bounding the price movement.

---

## 2. The cdStep hierarchy explains *why* some contracts inflate

The `contracts_to_at_cdStep` framework (EMLRegistry.lean) provides the
permission lattice:

| cdStep | Available mechanisms | Inflation possible? |
|--------|---------------------|-------------------|
| 0      | Pure storage (commutative) | ✅ Unbounded — no cost guard at all |
| 1      | Storage + simple transfer | ✅ Unbounded — cost model incomplete |
| 2      | **Reserve guard available** (non-commutative) | ❌ Bounded — `reserveB ≥ L` invariant holds |
| 3+     | Institutional closure + certificates | ❌ Bounded + provably certified |

**Key insight**: A contract written at cdStep < 2 *cannot* include a reserve
guard, because the reserve guard requires non-commutative semantics (ordering
of swapOut vs. reserve check matters). Therefore:

```
theorem low_cdStep_implies_unbounded :
    contracts_to_at_cdStep c 0 ∨ contracts_to_at_cdStep c 1
    → runaway_inflation c
```

The proof constructs an explicit sequence of `mint` calls that exhausts any
finite reserve bound, using the commutativity of storage at those cdSteps
to reorder checks.

---

## 3. The CD 2→3 discontinuity is the critical boundary

The monotonicity proof (`contracts_to_at_cdStep_monotone`) tells us that
cdStep permission only increases. But there's a **discontinuity at 2→3**:

- **cdStep = 2**: Reserve guard exists, but the contract cannot *certify*
  that the guard holds — it must trust an external oracle.
- **cdStep ≥ 3**: The contract can produce its own `CortexCertificate`
  proving the invariant holds, via institutional closure.

This is where Eigenstate adds value: the bridge lifts the EVM state root
into the Lean formal layer, and the invariance proof is certified at cdStep
3+. A contract at cdStep 2 that relies on the Eigenstate bridge for
certification has a **latency window** during which inflation could occur.

**Demonstration target**:
```
theorem cd_2_3_discontinuity_creates_inflation_window :
    ∃ (c : EVMContract) (steps : List StateTransition),
      contracts_to_at_cdStep c 2
      ∧ ¬ contracts_to_at_cdStep c 3
      ∧ finalState.supply > initialSupply * 2
      ∧ (∀ step ∈ steps, at_cdStep step 2)  -- all steps legal at cdStep 2
```

---

## 4. The e₄ coupling dimension controls inflation severity

From the split octonion cost landscape: the e₄ dimension (Z) couples to
the cost via `NodeCost.coupling`. In non-associative regimes:

| Logic type | Coupling behavior | Inflation severity |
|-----------|------------------|-------------------|
| CLASSICAL | No coupling bound | Worst — unbounded in all dimensions |
| FUZZY | Bounded in all dims | Inflation impossible (reserve guards always fire) |
| PARACONSISTENT | e₄ coupling only | Inflation bounded in X/Y/Z but unbounded in e₄ — novel! |
| INTUITIONISTIC | maxSem — cost = proof depth | Inflation bounded by proof size |

**The novel result**: Under PARACONSISTENT logic, inflation can still occur
in the e₄ dimension even when reserve guards fire in X/Y/Z. This is a
"hidden inflation" that only manifests in the coupling algebra.

```
theorem paraconsistent_hidden_inflation :
    let c := paraconsistent_token_contract
    in ¬ runaway_inflation c                              -- X/Y/Z bounded
    ∧ ∃ (steps : List StateTransition),
        finalState.supply_e4 > initialSupply_e4 * 1000    -- e₄ unbounded
```

---

## 5. Proof targets (in order)

### 5a. Simple token printer (cdStep 0)
**File**: `LaserCortex/examples/contracts/token_printer.lean`
```
contract token_printer:
  supply : storage Nat
  mint() → supply := supply + 1   // no guard, no check

theorem token_printer_runaway : runaway_inflation token_printer := ...
```
Proof: trivial infinite loop of `mint` calls. Establishes base case.

### 5b. Single-asset pool without reserve guard (cdStep 1)
**File**: `LaserCortex/examples/contracts/unprotected_pool.lean`
```
contract unprotected_pool:
  reserveA, reserveB : storage Nat
  swapOut(dx) → reserveA := reserveA + dx
                reserveB := reserveB - price(dx)   // no reserveB ≥ L check
```
Proof: attacker swaps repeatedly until reserveB = 0, then price → ∞.

### 5c. Guarded pool (cdStep 2) — prove bounded
**File**: Already exists as `AMM.Pool` + `reserveGuard`.
```
theorem guarded_pool_bounded :
    ∀ (pool : AMM.Pool) (dx : Nat),
      reserveGuard pool L tree dx = true
      → swapOut pool dx |>.reserveB ≥ L
```
(This is already implicit in the Lean spec — make it explicit.)

### 5d. CD 2→3 window (cdStep 2, but needs certification)
**File**: `LaserCortex/examples/contracts/guarded_but_not_certified.lean`
```
theorem exists_inflation_window : ... → see §3 above.
```

### 5e. PARACONSISTENT hidden inflation in e₄ (cdStep 3, coupling dimension)
**File**: `LaserCortex/examples/contracts/paraconsistent_token.lean`
```
theorem e4_inflation_unbounded_while_xyz_bounded : ... → see §4 above.
```

---

## 6. Connection to Eigenstate bridge

The `eigenstate_bridge.ncd` plan defines the EVM↔Lean translation pipeline.

The inflation proofs fit into this pipeline as **invariant proofs**:
```
EVM bytecode → Eigenstate.lift → Lean term → 
  theorem invariant: Φ(state) < reserveB
  → CortexCertificate(bytecode, invariant)
  → ground certificate → Solidity verifier
```

Specifically:
- 5a–5b demonstrate failure modes that Eigenstate's invariant checker
  would catch (no invariant provable → certificate refused)
- 5c demonstrates a successful certification
- 5d demonstrates a temporal gap that the bridge must handle
  (certificate latency creates a window)
- 5e demonstrates the need for multi-dimensional cost coupling in the
  bridge's invariant language

---

## 7. Hard-to-reach parts of the algebraic structure

| Area | What's hard | How inflation proofs reach it |
|------|-----------|-------------------------------|
| CD 2→3 discontinuity | No monotone interpolation | 5d constructs explicit state at boundary |
| e₄ coupling | Split octonion Z dimension | 5e isolates e₄ from X/Y/Z |
| Non-associativity | Cost depends on tree shape | 5b uses imbalanced trees to maximize Φ |
| PARACONSISTENT fixed point | Zig-zag can find equilibrium | 5e shows equilibrium is illusory (e₄ drifts) |
| INTUITIONISTIC proof depth | Cost = proof length | 5c's `reserveGuard` proof length controls bound |

---

## 8. Immediate next steps (after break)

1. Write `token_printer.lean` — simplest contract + `runaway_inflation` proof
   (~40 lines, establishes pattern)
2. Write `unprotected_pool.lean` — single-asset pool without guard
   (~60 lines, uses `swapOut` from AMM.lean)
3. Prove `guarded_pool_bounded` — explicit invariant theorem in AMM.lean
   (~30 lines, formalizes the reserve guard guarantee)
4. Model the CD 2→3 window — uses Eigenstate bridge for certificate latency
   (~80 lines, most novel)
5. Prove PARACONSISTENT hidden inflation — uses `NodeCost.coupling` in e₄
   (~100 lines, ties into split octonion cost landscape)
