# VSM Loop Orchestration Service

**File:** `infra/_cortex/_vsm_loop.py`
**Design Date:** 2026-06-26

## Purpose

The VSM Loop is the **Eigenstate oracle**: it takes a session trace (NCDS) and
answers the question: "Is this garbage or data?" by running each thinking block
through the S4→S3→S2→S3*→S1→S5 cycle. The answer is not a parsing decision
but a **convergence metric**: traces whose VSM loops converge within the
friction barrier are "data"; traces that oscillate across the sector boundary
without grounding are "garbage."

This operationalizes the core LaserCortex insight: **the CFG/CSG boundary is
in the cost landscape, not the grammar.** The six reasoning categories map to
EMLTree shapes (pure CFG, always decidable); the context sensitivity is that
ungrounded NL has unbounded cost while grounded NL has bounded cost. The VSM
loop measures which regime a trace actually occupies.

## Data Model

### ThinkingBlock

```python
@dataclass
class ThinkingBlock:
    """A single thinking step from session data, fed into the VSM loop.

    This is the bridge between raw NCDS format and the LC type system.
    Each block represents one inference step in the session trace.

    Fields:
        flow_index: Hierarchical position in the NC flow space (e.g. "1.2.3")
        source: The NL content of the thinking block
        coupling_signature: Optional coupling signature ("commutative",
            "non-commutative", "non-associative", "commutative-associative")
        tool_outcome: Optional ToolOutput from the actual tool call
            (S1 ground truth from the session)
        cert_bits: Optional certificate verification string
            (S3* artifact if present in the session)
    """
```

### VSMState

```python
@dataclass
class VSMState:
    """Accumulated state across VSM loop iterations for one block.

    This is the **Eigenstate carrier** — it holds the current iteration's
    S4/S3/S2/S3*/S1 outputs and tracks S5 stability.

    Fields:
        block: The ThinkingBlock being processed
        candidate_logic: The LogicType produced by S4 (lift_inference)
        contracted_tree: The EMLTree from S4's lift result
        friction_cost: The S3 friction density cost of the LogicType
        resonance_ok: Whether S2's canCoexist check passed with previous block
        cert_verified: Whether S3* independent verification passed
        tool_matched: Whether S1's tool outcome cost ≤ barrier
        iteration: How many VSM cycles this block required
        stable: Whether S5 logic stability converged
        prev_candidate_logic: LogicType from the previous iteration
            (for S5 stability comparison)
    """
```

### VSMLoopResult

```python
@dataclass
class VSMLoopResult:
    """The verdict of running the VSM loop on a session trace.

    Fields:
        plan_id: Identifier for the session / plan being evaluated
        converged: True if all blocks reached S5 stability
        convergence_iterations: Total S4→S3→S2→S3*→S1→S5 cycles across all
            blocks (Σ per-block iterations)
        cost_trajectory: Friction cost per block (list of floats, one per block)
        barrier_crossed: True if any block's cost exceeded the CD 2→3 barrier
            (strut_weight² = 16)
        stable_type: The LogicType S5 settled on for the final block
            (None if no blocks or no convergence)
        alpha: Convergence confidence (0.0 - 1.0)
        failures: List of flow_index values for blocks that never converged
    """
```

## Alpha Formula

```
alpha = 1.0 - (total_iterations / (n_blocks * max_iterations)) * barrier_penalty

where barrier_penalty = 0.5 if barrier_crossed else 0.0
```

This gives:
- `alpha = 1.0` — every block converged in 1 iteration, no barrier crossing
- `alpha = 0.0` — every block hit max_iterations AND barrier was crossed
- Intermediate values for partial convergence

**GAP:** The `0.5` penalty factor is a heuristic. The Lean formalization
(`free_is_viable` theorem in Generation.lean Section 12) should eventually
supply the correct penalty based on the actual friction ratio
(Γ_k₂ / Γ_k₁ for the crossing blocks).

## Algorithm

```
run_vsm_loop(blocks, bridge, max_iterations=7, barrier=16):

    if no blocks → converged immediately, alpha = 1.0

    for each block:
        state = VSMState(block)
        
        while not state.stable and state.iteration < max_iterations:
            
            S4: lift = bridge.core.lift_inference(
                    flow_index=block.flow_index,
                    concept_name=block.source,
                    sequence_type="sequential",
                    coupling_signature=block.coupling_signature)
                state.candidate_logic = lift.logic_type
                state.contracted_tree = lift.eml_tree
            
            S3: state.friction_cost = friction_density(lift.logic_type)
                if state.friction_cost > barrier → record barrier_crossed
            
            S2: if prev_stable_type exists:
                    state.resonance_ok = can_coexist(prev_stable_type,
                                                     lift.logic_type)
                    if not state.resonance_ok:
                        try inflation from lift.anti_coherent_pair
                        (GAP: this is where the Eigenstate transitions)
                else:
                    state.resonance_ok = True
            
            S3*: if block.cert_bits and lift.certificate:
                     state.cert_verified = verify_certificate(lift.certificate)
            
            S1: if block.tool_outcome:
                    state.tool_matched = tool_outcome.cost <= barrier
            
            S5: state.stable = (state.candidate_logic == 
                                state.prev_candidate_logic)

        total_iterations += state.iteration
        cost_trajectory.append(state.friction_cost)
        
        if state.stable:
            prev_stable_type = state.candidate_logic
        else:
            failures.append(block.flow_index)

    alpha = compute_alpha(total_iterations, n_blocks, max_iterations, barrier_crossed)

    return VSMLoopResult(converged=(len(failures)==0), ...)
```

**GAP:** The inner while-loop may oscillate forever for a deterministic
`lift_inference` — if the bridge returns the same LogicType every call, the
iteration count will never increase. The loop relies on the bridge's
internal generation mode (which auto-inflates on ZD detection at lines
428-446 of `_bridge.py`) to produce a different LogicType on subsequent calls.
This is correct for cases where ZD is detected; for non-ZD cases the loop
converges in 1 iteration. The max_iterations guard prevents infinite loops.

## Eigenstate Property

The VSM loop converges to an **Eigenstate** when running it twice on the same
trace produces the same `VSMLoopResult`. This mirrors the Lean theorem
`closure_is_fixed_point` from `InstitutionalClosure.lean`:

```lean
theorem closure_is_fixed_point (cdStep : Nat) (history : LogicM GameOutcome)
    (norm : Norm) : selfRecognize (closure cdStep history norm) = closure cdStep history norm := rfl
```

The Eigenstate is the carrier structure:
```
Eigenstate = {
    stable_type: LogicType,     -- S5 identity
    cost_trajectory: [],         -- S3 regulatory history
    contraction_path: EMLTree,   -- contracted normal form
    certificate: CortexCertificate,  -- S3* audit artifact
}
```

**GAP:** The Python implementation checks Eigenstate idempotence heuristically
(comparing sector membership of re-application results). The actual proof
requires running the Lean `closure_is_fixed_point` theorem via the MCP server.

## Gaps / Heuristics

Every heuristic in the implementation is marked with `# GAP:` or
`# GAP (issue #vsm-N):` in the code. These are design debts that will be
replaced as the Lean formalization catches up:

| # | Gap | Current Heuristic | Lean Replacement |
|---|-----|-------------------|-----------------|
| 1 | S2 resonance detection | `can_coexist` on LogicType only | `Resonates` inductive (Tamari ancestor + type compat) |
| 2 | S4 loopback on ZD | Relies on bridge's auto-inflation | Explicit `inflate` call with host tree |
| 3 | S3* cert verification | `verify_certificate` on bridge | `decidable_contracts_to` theorem |
| 4 | Alpha formula | `0.5 * barrier_penalty` | `free_is_viable` → friction ratio |
| 5 | NCDS coupling sig. | Heuristic from coupling_signature | `tree_from_inference_entry` |
| 6 | Eigenstate check | Python sector comparison | `closure_is_fixed_point` via Lean MCP |
| 7 | ncds_to_blocks | Only parses `<-` concept lines | Full NCDS grammar (<=, <*, <= if) |

## Integration

The VSM loop service is used by:

1. **`mcp_normcode_server.py`** — new MCP tool `normcode_vsm_loop` that takes
   an NCDS text and returns a `VSMLoopResult`
2. **`scripts/bulk_mine_tamari.py`** — orchestrator that feeds each session
   NCDS through `run_vsm_loop` and builds the alpha map by tree shape
3. **Graphiti ingestion** — `alpha` value stored on each episode's metadata
   for temporal quality analysis

## Relation to Other Modules

| Module | Relation |
|--------|----------|
| `_bridge.py` | `CortexBridge.lift_inference` provides S4 generation |
| `_wfc.py` | `friction_density`, `can_coexist` provide S3/S2 |
| `_closure.py` | `closure_is_fixed_point` is the Eigenstate theorem |
| `Generation.lean:12` | `ViableSystem`, `free_is_viable` are the Lean spec |
| `InstitutionalClosure.lean` | `closure_is_fixed_point` is the Eigenstate proof |
| `eigenstate_bridge.ncd` | Canonical Eigenstate NC spec (EVM → Lean bridge) |

## Test File

`tests/vsm/test_vsm_loop.py` — 37+ tests organized by VSM system layer,
following TDD. Run with:

```bash
python3 -m pytest tests/vsm/test_vsm_loop.py -v
```
