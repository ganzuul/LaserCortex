# NC ↔ LC Bridge — Identified Gaps

## Architecture

**LC defines the inference target space; NC navigates it.**

The Phase 5 bootstrapping protocol (see `_spec.py`) enumerates what CAN be
inferred as `CortexSpec` objects — each with a witness schema, coupling
signature, mapping semantics, and magnitude contract. NC does not build
EMLTrees from nothing; it queries the `SpecRegistry`, picks a registered
spec, and produces evidence that matches that spec's witness schema and
satisfies its magnitude contract.

The EMLTree, certificate, and router index are bookkeeping that the bridge
generates automatically when NC selects a spec and executes against it.
They are not the primary interface.

Each gap is tagged with a **severity**:
- **BLOCKING**: LC cannot function without this (must fix before Phase 1)
- **MAJOR**: Significant capability missing (should fix in Phase 1)
- **MINOR**: Nice-to-have (Phase 2+)

---

## 1. NC Does Not Query the SpecRegistry for Inference Targets
**Severity: BLOCKING**

NC inferences have no concept of a `CortexSpec`. They execute against
flow indices and sequence types, but never ask "which registered spec
does this inference target?" The bridge currently generates EMLTrees
from flat flow indices — a heuristic that bypasses the spec entirely.

**Location**: `infra/_core/_inference.py` → `Inference.execute()`
**Fix**: Before executing, call `SpecRegistry.lookup_by_context(context)`
to find candidate specs. Attach the chosen spec to the inference. The
bridge can then derive the correct LogicType, coupling semantics, and
witness schema from the spec rather than guessing.

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

**Location**: `infra/_orchest/_orchestrator.py` → after all cycles complete
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

## 7. Decomposition UI Needs Spec-Based Browsing
**Severity: MAJOR**

The 10 seed `CortexSpec`s define the enumerated inference space (heap
threshold, locked room, Blue-Eyed Islanders, Monty Hall, etc.). NC's
Canvas UI has no way to browse, select, or inspect these specs as
possible inference targets.

**Location**: `canvas_app/` — UI
**Fix**: Add a spec browser panel that queries `SpecRegistry` and
displays each spec's witness schema, mapping hint, magnitude contract,
and examples. Selecting a spec should pre-populate an inference form
with its default_payload.

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

## 9. ~~No Coupling Signature to LogicType Mapping~~ (RESOLVED)
**Severity: MINOR** → **RESOLVED**

`_spec.py` now defines `COUPLING_TO_LOGIC`:

    commutative           → CLASSICAL
    non-commutative        → TEMPORAL
    non-associative        → QUANTUM
    commutative-associative → CLASSICAL

Each `CortexSpec.to_logic_type()` uses this mapping. The Phase 5
taxonomy (Blue-Eyed Islanders = non-commutative = TEMPORAL, Barber
paradox = non-associative = QUANTUM) is the ground truth.

Resolved in: `_spec.py` (COUPLING_TO_LOGIC, CortexSpec.to_logic_type()).

---

## 10. ~~No Flow Index to EMLTree Formal Mapping~~ (DEFERRED)
**Severity: MINOR** → **DEFERRED**

With the spec-centric architecture, the EMLTree shape is determined by
the chosen spec's dependency structure, not by a heuristic on the flow
index. The flow index becomes a routing identifier, not a tree topology.
This gap is moot until gap #1 (spec query) is resolved.

---

## 11. NC Cannot Select-and-Instantiate a Spec
**Severity: BLOCKING**

`SpecRegistry.lookup_by_context()` exists but nothing calls it. There is
no `instantiate(spec, witness_data)` that would construct a fully typed
Concept from a spec and real evidence, then push it through the TVK
(typed verification kernel).

**Location**: `infra/_cortex/_bridge.py`
**Fix**: Add `CortexBridge.instantiate_spec(spec, witness_data)` that:
1. Validates witness_data against spec.validation
2. Builds the EMLTree from the spec's coupling signature
3. Sets the Concept's logic_type via spec.to_logic_type()
4. Populates the form payload from spec.default_payload + witness_data
5. Runs the form through TVK validation
6. Returns a certified Concept+Certificate pair

---

## Summary

| # | Gap | Severity | File | Fix Scope |
|---|-----|----------|------|-----------|
| 1 | NC doesn't query SpecRegistry | BLOCKING | `_inference.py` | ~5 lines + design |
| 2 | No RouterIndex binding | BLOCKING | `_waitlist.py` | ~20 lines |
| 3 | No certificate on completion | BLOCKING | `_orchestrator.py` | ~10 lines |
| 4 | No LogicType on Concept | ~~MAJOR~~ **RESOLVED** | `_concept.py` | logic_type param + mappings |
| 5 | No paradox classification | MAJOR | `_orchestrator.py` | ~15 lines |
| 6 | No Event model | MAJOR | `_blackboard.py` | ~30 lines + design |
| 7 | No spec-based decomposition UI | MAJOR | `canvas_app/` | ~2 new panels |
| 8 | No checkpoint verification | MAJOR | `_checkpoint.py` | ~20 lines |
| 9 | Coupling→LogicType mapping | ~~MINOR~~ **RESOLVED** | `_spec.py` | COUPLING_TO_LOGIC dict |
| 10 | Flow→Tree formal mapping | ~~MINOR~~ **DEFERRED** | — | Moot until gap #1 resolved |
| 11 | Cannot instantiate a spec | BLOCKING | `_bridge.py` | ~40 lines + design |

**4 BLOCKING gaps** must be resolved before the bridge is functional.
**4 MAJOR gaps** should be resolved in Phase 1 (FastAPI + UI integration).
**2 RESOLVED**: gaps #4 and #9.
**1 DEFERRED**: gap #10.
