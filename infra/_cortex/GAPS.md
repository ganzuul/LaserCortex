# NC ↔ LC Bridge — Identified Gaps

These are the places where NC (NormCode) doesn't yet produce the data
that LC (LaserCortex) requires. Each gap is a future integration point.

Each gap is tagged with a **severity**:
- **BLOCKING**: LC cannot function without this (must fix before Phase 1)
- **MAJOR**: Significant capability missing (should fix in Phase 1)
- **MINOR**: Nice-to-have (Phase 2+)

---

## 1. No EMLTree Production from NC Inferences
**Severity: BLOCKING**

LC needs every NC inference to produce an `EMLTree` (binary tree shape
encoding the inference's dependency structure). Currently NC executes
inferences but produces no tree.

**Location**: `infra/_core/_inference.py` → `Inference.execute()`
**Fix**: After each successful execution, call
`CortexBridge.flow_index_to_tree(flow_index)` and store the tree
alongside the inference result.

---

## 2. No RouterIndex Binding
**Severity: BLOCKING**

LC's `TypeRegistry` requires an injective mapping from `RouterIndex`
(bounded natural) to `EMLTree`. NC's flow indices are strings like
`"1.2.3"` with no formal mapping to a bounded index space.

**Location**: NC flow indices are managed by `Waitlist` in
`infra/_orchest/_waitlist.py`
**Fix**: Assign each unique flow index a `RouterIndex` at waitlist
creation time. Ensure bound is large enough for all inferences.

---

## 3. No CortexCertificate on Completion
**Severity: BLOCKING**

LC's `certify(tree)` produces a `CortexCertificate` for any tree,
which serves as the proof-carrying audit trail. NC doesn't generate
or store certificates.

**Location**: `infra/_orchest/_orchestrator.py` → after all cycles
complete
**Fix**: Call `NormCodeCortexBridge.on_plan_complete(run_id)` at the
end of orchestration and store the certificate in the run database.

---

## 4. ~~No LogicType Binding on Concepts~~ (RESOLVED)
**Severity: MAJOR** → **RESOLVED**

`Concept.__init__` now accepts an optional `logic_type` parameter.
`Concept.to_logic_type()` resolves via: explicit > `FORM_TO_LOGIC` >
`TYPE_TO_LOGIC` > `CLASSICAL` fallback. Bridge `infer_logic_type()`
delegates to `concept.to_logic_type()` when available.

Resolved in: `_concept.py` (FORM_TO_LOGIC, TYPE_TO_LOGIC, logic_type
parameter, to_logic_type()), `_bridge.py` (infer_logic_type updated).

---

## 5. No Paradox Classification on Inference Failures
**Severity: MAJOR**

LC's `WrappedProblem` classifies inference failures into 13 paradox
classes (Liar, Sorites, Grandfather, etc.). NC logs errors but does
not classify them.

**Location**: `infra/_orchest/_orchestrator.py:_handle_inference_failure`
**Fix**: Route inference failures through `CortexBridge.detect_paradox()`
and store the `WrappedProblem` with the error record.

---

## 6. No Event Model for Institutional Closure
**Severity: MAJOR**

LC's institutional closure pipeline (`Temporal → Fuzzy → Deontic`)
operates on `LogicM[Event]`. NC has no `Event` type — the closest
analog is the Blackboard's inference history, but there's no formal
event structure with year/description/impact.

**Location**: `infra/_orchest/_blackboard.py`
**Fix**: Either add an Event model to NC's execution tracking, or
build a bridge that converts Blackboard state changes to Events.

---

## 7. No Decomposition Consumption
**Severity: MAJOR**

LC's `Decomposition` and `ancestorsUpTo` provide counterfactual
reasoning paths (what prior states could lead to the current
decision). NC has no UI or storage for decompositions.

**Location**: `canvas_app/` — UI
**Fix**: Add a decomposition explorer to the Canvas UI that queries
`CortexBridge.decompose_decision()`.

---

## 8. No Certificate Verification in Checkpoint Restore
**Severity: MAJOR**

LC's `contracts_to` provides idempotent verification (checkpoint
state should contract to rightComb normal form). NC's checkpoint
system (`CheckpointManager`) doesn't verify this property.

**Location**: `infra/_orchest/_checkpoint.py`
**Fix**: On checkpoint load, verify the checkpoint state tree
contracts to its rightComb normal form. Reject if not.

---

## 9. No Coupling Signature to LogicType Mapping
**Severity: MINOR**

NC's `COUPLING_SIGNATURES` = `{commutative, non-commutative,
non-associative, commutative-associative}`. LC's `LogicType` has 13
variants. The mapping between them is heuristic.

**Location**: `infra/_cortex/_bridge.py:_coupling_to_logic_type`
**Fix**: This is a design question. Does each coupling signature
correspond to a specific LogicType, or can a concept with a given
coupling be processed by multiple logics?

---

## 10. No Flow Index to EMLTree Formal Mapping
**Severity: MINOR**

The current `tree_from_flow_index()` heuristic builds right-nested
trees from dotted index strings. The formal mapping should use the
inference's dependency subgraph topology to determine tree shape.

**Location**: `infra/_cortex/_bridge.py:flow_index_to_tree`
**Fix**: Build the EMLTree from the actual dependency DAG
(Waitlist.get_supporting_items) rather than from the flat index.

---

## Summary

| # | Gap | Severity | File | Fix Scope |
|---|-----|----------|------|-----------|
| 1 | No EMLTree production | BLOCKING | `_inference.py` | 1-2 lines hook |
| 2 | No RouterIndex binding | BLOCKING | `_waitlist.py` | ~20 lines |
| 3 | No certificate on completion | BLOCKING | `_orchestrator.py` | ~10 lines |
| 4 | No LogicType on Concept | ~~MAJOR~~ **RESOLVED** | `_concept.py` | logic_type param + FORM_TO_LOGIC + TYPE_TO_LOGIC |
| 5 | No paradox classification | MAJOR | `_orchestrator.py` | ~15 lines |
| 6 | No Event model | MAJOR | `_blackboard.py` | ~30 lines + design |
| 7 | No decomposition UI | MAJOR | `canvas_app/` | ~2 new panels |
| 8 | No checkpoint verification | MAJOR | `_checkpoint.py` | ~20 lines |
| 9 | Coupling→LogicType mapping | MINOR | `_bridge.py` | Design decision |
| 10 | Flow→Tree formal mapping | MINOR | `_bridge.py` | Design decision |

**3 BLOCKING gaps** must be resolved before the bridge is functional.
**4 MAJOR gaps** should be resolved in Phase 1 (FastAPI + UI integration).
**2 MINOR gaps** are design questions for future refinement.
**1 RESOLVED**: gap #4 (LogicType on Concept).
