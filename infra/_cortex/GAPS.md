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

## 1. ~~NC Does Not Query the SpecRegistry~~ **RESOLVED**
**Severity: BLOCKING** → **FIXED**

NC inferences had no concept of a `CortexSpec`. They executed against
flow indices and sequence types, but never asked "which registered spec
does this inference target?"

**Fix**: `on_inference_complete()` now calls `resolve_spec(concept)`
before lifting, which pre-populates the concept from the matching
statute and carries the ``spec_name`` into the ``LiftResult``.
Wired into ``Orchestrator._inference_execution()`` after every
successful inference.

See ``infra/_cortex/DESIGN.md`` for the statute book / constitutional
authority analogy.

---

## 2. ~~No RouterIndex Binding~~ **RESOLVED**
**Severity: BLOCKING** → **FIXED**

LC's `TypeRegistry` requires an injective mapping from `RouterIndex`
(bounded natural) to `EMLTree`. NC's flow indices are strings like
`"1.2.3"` with no formal mapping to a bounded index space.

**Fix**: `Waitlist.assign_router_indices()` assigns a `RouterIndex(i, n)`
to each item based on sorted flow-index position. Called in
`Orchestrator._create_waitlist()`.

See `infra/_cortex/DESIGN.md` for the architectural rationale
(legislative docket analogy, accountability, proof traces).

---

## 3. ~~No CortexCertificate on Completion~~ **RESOLVED**
**Severity: BLOCKING** → **FIXED**

LC's `certify(tree)` produces a `CortexCertificate` for any tree,
which serves as the proof-carrying audit trail. NC doesn't generate
or store certificates.

**Fix**: `NormCodeCortexBridge.stamp_seal(run_id)` collects all EMLTrees
lifted during the run, combines them into a composite tree, certifies it,
and stores the certificate. Called from `Orchestrator.run()` and
`Orchestrator.run_async()` when the optional `cortex_bridge` parameter
is provided.

See `infra/_cortex/DESIGN.md` for the wax seal / voyage analogy.

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

## 5. ~~No Paradox Classification on Inference Failures~~ **NOT A GAP**
**Severity: MAJOR** → **VOID**

LC's `WrappedProblem` classifies inference failures into 13 paradox
classes (Liar, Sorites, Grandfather, etc.). NC logs errors but does
not classify them.

**Why this is not a gap**: The triangle already handles garbage.

- **Coherent**: TVK rejects bad input at the reading clerk stage
  (wrong witness type, missing fields, schema violation). No writ
  is issued for garbage.
- **Unqualified**: `cert.verify()` replays every contraction step. If
  the input is paradoxical, `rightComb` detects it, `contracts_to`
  fails, and the seal is fraudulent. The certificate proves *that*
  it is garbage without classifying *why*.
- **Universal**: No matching statute → `resolve_spec` returns `None`
  → the inference lifts without a `spec_name` citation. The system
  says "I have no authority to certify this" — which itself is the
  certification.

The 13-class taxonomy is a UI concern (gap #7): present the failure
mode, let the human decide which paradox it is, if they care. The
formal guarantee is already complete without it.

---

## 6. ~~No Event Model for Institutional Closure~~ **SCAFFOLDED**
**Severity: MAJOR** → **SCAFFOLDED**

LC's institutional closure pipeline (`Temporal → Fuzzy → Deontic`)
operates on `LogicM[Event]`. NC has no `Event` type — the closest
analog is the Blackboard's inference history, but there was no formal
event structure with year/description/impact.

**Scaffold**: ``NormCodeCortexBridge.blackboard_to_events(blackboard)``
converts Blackboard history to ``List[Event]``. ``compute_blame(events)``
returns the simple commutative ``BlamePool`` (no interest, no pooling
threshold). The scaffold lives in ``_bridge.py`` and delegates to the
existing types in ``_closure.py``.

**Design rationale**: The BlamePool is a **debt ledger** in the Calvinist
sense. The scaffold is the commutative base case: no interest (non-
recursive blame), no pooling threshold (every event recorded independently).
Future pooling with interest is non-commutative/non-associative work that
must be fed forward to LC explicitly.

See ``infra/_cortex/DESIGN.md`` for the debt ledger analogy.

---

## 7. ~~Decomposition UI Needs Spec-Based Browsing~~ **RESOLVED**
**Severity: MAJOR** → **FIXED**

The 10 seed `CortexSpec`s define the enumerated inference space (heap
threshold, locked room, Blue-Eyed Islanders, Monty Hall, etc.). NC's
Canvas UI had no way to browse, select, or inspect these specs as
possible inference targets.

**Fix**: ``SpecBrowserPanel`` (React) — the **Reading Room** — lists
all seed specs in a left-hand sidebar with logic-type badges. Selecting
one shows its witness schema, coupling signature, magnitude contract,
worked examples with expand/collapse, and default payload preview.

**Backend** (``cortex_router.py``, ``/api/cortex/specs``):
- ``GET /api/cortex/specs`` — list all seed specs with summary info
- ``GET /api/cortex/specs/{name}`` — full spec detail
- ``GET /api/cortex/certificates`` — list certificate keys
- ``GET /api/cortex/certificates/{key}`` — certificate detail + verify
- ``POST /api/cortex/instantiate`` — issue a writ for a spec
- ``GET /api/cortex/bridge/state`` — bridge state snapshot

**UI** (``SpecBrowserPanel.tsx``):
- Split-panel layout: spec list (left) / spec detail (right)
- Specs display ``cortex_name``, logic-type badge (blue CLASSICAL,
  amber TEMPORAL, purple QUANTUM), and axes
- Detail section shows coupling, witness type, shape, magnitude contract,
  expandable worked examples, and default payload toggle
- Refresh and close controls in the panel header

**Data channels wired**: ``cortexApi.ts`` connects the panel to
the bridge via the FastAPI router.  The ``NormCodeCortexBridge``
singleton is lazily instantiated on first request.

---

## 8. ~~No Certificate Verification in Checkpoint Restore~~ **RESOLVED**
**Severity: MAJOR** → **FIXED**

LC's `contracts_to` provides idempotent verification (checkpoint
state should contract to rightComb normal form). NC's checkpoint
system (`CheckpointManager`) didn't verify this property.

**Fix**: ``NormCodeCortexBridge.verify_checkpoint(run_id, cycle)``
recomputes the stored seal and calls ``cert.verify()`` (the Skeptic
replays every contraction step). ``checkpoint_proof(run_id, cycle)``
packages the proof for smart contract consumption.

See ``infra/_cortex/DESIGN.md`` for the purser's inspection analogy
and paydata / smart contract integration path.

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

## 11. ~~NC Cannot Select-and-Instantiate a Spec~~ **RESOLVED**
**Severity: BLOCKING** → **FIXED**

`SpecRegistry.lookup_by_context()` exists but nothing calls it. There was
no `instantiate(spec, witness_data)` that would construct a fully typed
Concept from a spec and real evidence, then push it through the TVK.

**Fix**: ``CortexBridge.instantiate_spec(spec, witness_data)`` now:
1. Validates witness_data against spec.validation (type check)
2. Creates a Concept with the spec's form metadata
3. Merges spec.default_payload + witness_data into form_payload
4. Runs validate_typed_form (reading clerk countersigns)
5. Builds EMLTree from coupling signature
6. Certifies the tree (applies the wax seal)
7. Returns (Concept, CortexCertificate)

See ``infra/_cortex/DESIGN.md`` for the writ / sealed writ analogy.

---

## Summary

| # | Gap | Severity | File | Fix Scope |
|---|-----|----------|------|-----------|
| 1 | NC doesn't query SpecRegistry | ~~BLOCKING~~ **RESOLVED** | `_bridge.py` | +DESIGN.md |
| 2 | No RouterIndex binding | ~~BLOCKING~~ **RESOLVED** | `_waitlist.py` | +DESIGN.md |
| 3 | No certificate on completion | ~~BLOCKING~~ **RESOLVED** | `_orchestrator.py` | +DESIGN.md |
| 4 | No LogicType on Concept | ~~MAJOR~~ **RESOLVED** | `_concept.py` | logic_type param + mappings |
| 5 | No paradox classification | ~~MAJOR~~ **VOID** | — | triangle handles it |
| 6 | No Event model | ~~MAJOR~~ **SCAFFOLDED** | `_bridge.py` | debt ledger scaffold |
| 7 | No spec-based decomposition UI | ~~MAJOR~~ **RESOLVED** | `canvas_app/` | Reading Room panel + API router |
| 8 | No checkpoint verification | ~~MAJOR~~ **RESOLVED** | `_bridge.py` | purser's inspection |
| 9 | Coupling→LogicType mapping | ~~MINOR~~ **RESOLVED** | `_spec.py` | COUPLING_TO_LOGIC dict |
| 10 | Flow→Tree formal mapping | ~~MINOR~~ **DEFERRED** | — | Moot until gap #1 resolved |
| 11 | Cannot instantiate a spec | ~~BLOCKING~~ **RESOLVED** | `_bridge.py` | writ + seal |

**0 BLOCKING gaps** must be resolved before the bridge is functional.
**0 MAJOR gaps** should be resolved in Phase 1 (FastAPI + UI integration).
**8 RESOLVED**: gaps #1, #2, #3, #4, #7, #8, #9, and #11.
**1 DEFERRED**: gap #10.
