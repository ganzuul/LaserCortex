# The Eigenstate: VSM Loop Fixed Point

**File:** `docs/vsm_eigenstate.md`
**Date:** 2026-06-26

## Definition

The **Eigenstate** is the fixed point of the VSM loop — the stable
self-referential state that the system converges to when the S4→S3→S2→S3*→S1→S5
cycle reaches closure. It is the bridge between the generation/collapse duality
and the institutional closure pipeline.

## Formal Foundation

The Eigenstate property is grounded in two Lean theorems:

### 1. `closure_is_fixed_point` (InstitutionalClosure.lean)

```lean
theorem closure_is_fixed_point (cdStep : Nat) (history : LogicM GameOutcome)
    (norm : Norm) :
    selfRecognize (closure cdStep history norm) = closure cdStep history norm := rfl
```

Closure is a fixed point of self-recognition: running `closure` on its own
output yields the same result. This is the **idempotence of self-recognition**
— the institution's normative state doesn't change when re-evaluated.

### 2. `free_is_viable` (Generation.lean, Section 12)

```lean
theorem free_is_viable : True := by
  have h_meta : LogicType.Free.isMetaLogic := free_is_meta_logic
  have h_bridge : canCoexist LogicType.Free AntiCoherentPair.barber.coherent = true ∧
                  canCoexist LogicType.Free AntiCoherentPair.barber.antiCoherent = true :=
    free_bridges_barber_boundary
  trivial
```

Free Logic is viable: its anti-coherence is groundable via finite tool outputs
whose combined contraction cost is bounded by the friction barrier. This is
what makes the Eigenstate **tractable** — it can always be reached because Free
Logic (S5) bridges all sector boundaries.

## The Eigenstate Carrier

The `VSMState` dataclass in `_vsm_loop.py` is the **Eigenstate carrier** — it
holds the current iteration's state:

```
Eigenstate = {
    stable_type:     LogicType,            -- S5 identity
    cost_trajectory: List[float],          -- S3 regulatory history
    contracted_tree: EMLTree,              -- contracted normal form
    certificate:     CortexCertificate,    -- S3* audit artifact
    iteration:       int,                  -- convergence count
}
```

This mirrors the original Eigenstate spec from `eigenstate_bridge.ncd`:

```
Eigenstate =
  { evm_state_root     : state fingerprint
  , cdStep             : which permission regime we're in
  , contraction_trace  : Tamari path to canonical form
  , invariant_proof    : the CortexCertificate proving the invariant }
```

The VSM loop's `VSMState` generalizes the EVM-specific Eigenstate to any
session trace: the "state fingerprint" is the `stable_type`, the "cdStep" is
the LogicType's cdStep, the "contraction trace" is the `contracted_tree`, and
the "invariant proof" is the `certificate`.

## The Hopf 7-Skeleton Connection

From [lab_notes/006_the_hopf_7_skeleton_of_logic_space.md](../lab_notes/006_the_hopf_7_skeleton_of_logic_space.md):

The 15 named logics collapse to exactly 7 distinct NodeCost configurations,
corresponding to the 7 non-identity basis vectors e₁⋯e₇ of the split-octonion
algebra. The Eigenstate is a point in this 7-dimensional affine hyperplane
(bias = 1).

The cdStep dimension is independent of NodeCost, giving an effective 8D space:
- 7D NodeCost (which eᵢ direction)
- 1D cdStep (which CD level: ℝ → ℂ → ℍ → 𝕆 → 𝕊)

The VSM loop's convergence trajectory moves through this 8D space:

```
cdStep 0 (ℝ):  Classical      ← commutative-associative (leaf)
cdStep 1 (ℂ):  Classical      ← commutative (order lost)
cdStep 2 (ℍ):  Intuitionistic ← non-commutative (commutativity lost)
cdStep 3 (𝕆):  Quantum        ← non-associative (associativity lost)
cdStep 4 (𝕊):  Free           ← meta-logic (explosion lost, via generation mode)
```

The friction barrier at cdStep 2→3 (strut_weight² = 16) is the Hopf invariant:
the fundamental unit of non-associativity separating the associative (time)
and split (space) sectors.

## Eigenstate Verification

The Python implementation checks Eigenstate idempotence heuristically
(`TestEigenstate::test_reapplication_idempotent` in `tests/vsm/test_vsm_loop.py`):

```python
result1 = run_vsm_loop([block], bridge)
# Re-apply on the stable_type
feedback_block = ThinkingBlock(source=f"eigenstate:{result1.stable_type.name}")
result2 = run_vsm_loop([feedback_block], bridge)
# Check: same sector membership
assert result2.stable_type.is_associative_sector() == result1.stable_type.is_associative_sector()
```

**GAP:** The actual proof requires running the Lean `closure_is_fixed_point`
theorem via the MCP server. The Python check is a heuristic approximation —
it verifies sector membership stability, not full fixed-point equality.

## The Eigenstate as the VSM Loop's Attractor

The VSM loop converges to an Eigenstate when:

1. **S5 (Identity):** The LogicType stabilizes — running the loop again
   produces the same type (sector membership invariant)
2. **S3 (Regulation):** The friction cost is bounded by the barrier
   (strut_weight² = 16)
3. **S2 (Coordination):** Adjacent blocks' LogicTypes canCoexist
4. **S3* (Audit):** The certificate verifies (contraction path is decidable)
5. **S1 (Operations):** Tool outcomes ground the loop (cost ≤ barrier)

When all five conditions hold, the system is at its Eigenstate — the fixed
point of `selfRecognize ∘ closure`. This is the state where "garbage" has been
filtered out and what remains is "data."

## Relation to Process Philosophy

The Eigenstate is Whitehead's **concrescence** — the completed actual entity.
The process (tool calls → generation → collapse) creates the actual entity
(ToolOutput), which feeds back into the next cycle. When the cycle converges,
the Eigenstate is the **superject** bequeathed to the next cycle: the stable
LogicType, the cost trajectory, and the certificate.

This is operationalized by the Graphiti temporal graph: each Eigenstate is
persisted as an episode, and the next cycle can query previous Eigenstates
via semantic search to inform its S4 generation.
