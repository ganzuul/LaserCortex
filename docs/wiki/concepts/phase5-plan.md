---
title: Phase 5 Plan
created: 2026-06-02
updated: 2026-06-02
type: concept
tags: [phase5, plan, bootstrap, uncertainty, terminator, cortex, registry]
sources: [./phase4-plan.md, ./phase4-target-contract.md, ../raw/typed-cortex-bootstrap-protocol.md]
confidence: high
contested: false
---

# Phase 5 Plan

Goal: Make the floating terminator productive. When uncertainty persists across typed-cortex cycles, trigger discovery, accumulate cortex specs, and reuse them.

Phase 4 gives us: a seeded bootstrap state, an observable IR->TVK->OR cycle, and a `category_decision` with `binary_outcome=None` when no typed cortex applies.

Phase 5 adds: persistence of that signal, thresholding, agent-pipeline invocation, cortex-spec generation, registry storage, and reuse on subsequent inferences.

## Phase 5 scope

In scope:
1. Uncertainty accumulation rules and scoring
2. Terminator threshold policy
3. AI agent pipeline: prompt-JSON-validation -> logic type signature
4. Cortex registry interface: storage, lookup, instantiation
5. Reuse path: match inference context to accumulated cortex spec

Out of scope for 5.x:
- Training or fine-tuning models
- Petal/provider-specific runtime details
- Persistence to disk beyond in-process registry (deferred to 6.x)

## Phase 5.1 — Uncertainty model

### Sources of cost
- IR: `function_concept` reference absent or placeholder
- TVK: `binary_outcome` is `None`, `authorized` is `False`
- OR: `inference[OR]` reference unresolved or null

### Score
- Boolean evidence: each unresolved source adds `0.25`
- Total in `[0.0, 1.0]`
- Stored in `states.workspace["uncertainty"]`

### Witness
- Derived from `category_decision["binary_outcome"]` and reference presence:
  - `crossed`: `binary_outcome` is `True` and reference finalized
  - `not_crossed`: `binary_outcome` is `False` or reference absent
  - `absent`: `binary_outcome` is `None`

## Phase 5.2 — Threshold policy

Trigger when all of:
- `uncertainty >= 0.75` for current terminator
- same terminator survives `N = 3` consecutive traversals

Action:
1. Capture sequence trace as prompt context
2. Invoke agent pipeline
3. Store emitted cortex spec in registry
4. Terminate bootstrap trajectory

## Phase 5.3 — AI agent pipeline

### Input contract
```json
{
  "floating_terminator": { "step_name": "IR", "concept": { "id": null }, "reference": null, "survived_cycles": 3, "uncertainty_score": 0.87 },
  "sequence_trace": { "IR": {...}, "TVK": {"category_decision": {...}}, "OR": {"finalized_reference": null} },
  "context": { "function_concept_name": "...", "concept_to_infer_type": "{}", "working_interpretation": {} }
}
```

### Output contract
```json
{
  "cortex_name": "threshold_category",
  "form_type": "threshold_category",
  "form_schema_version": "0.1.0",
  "coupling_signature": "commutative",
  "validation": { "uncertainty": {...}, "witness": {...}, "binary_outcome": {...}, "category_label": {...} },
  "axes": ["f"],
  "tensor_shape": [1],
  "default_payload": { "uncertainty": {...}, "witness": null, "binary_outcome": null, "category_label": null }
}
```

### Invariant
- Pipeline emits a *spec*, not an instance
- Spec is versioned
- Pipeline never mutates running inference state

## Phase 5.4 — Cortex registry

Interface:
- `register_cortex_spec(spec) -> cortex_id`
- `lookup_by_context(context) -> spec | None`
- `instantiate(spec_id, context) -> Concept`

Spec must include:
- `cortex_name`
- `form_type`
- `form_schema_version`
- `axes`
- `tensor_shape`
- `validation` schema
- `default_payload`

## Phase 5.5 — Reuse path

1. New `Inference` arrives with `function_concept`
2. Compute match key from `working_interpretation` and `function_concept`
3. Registry lookup by match key -> `cortex_id`
4. `instantiate(cortex_id, context)` -> typed `Concept`
5. Set `inference.function_concept` to instantiated cortex
6. Proceed through IR->TVK->OR with resolved reference

Success means:
- Second traversal of similar context does not bootstrap
- `uncertainty` stays near zero
- terminator never reaches threshold

## Phase 5 test contract

Target file: replace `/tmp/phase4_tdd_tests.py` with `tests/phase5_tdd_tests.py`.

Required assertions:
1. uncertainty score computed correctly for each source combination
2. threshold triggers after N consecutive cycles
3. pipeline input contract validated before invocation
4. pipeline output spec accepted into registry
5. registry lookup returns same spec for matching context
6. instantiated cortex resolves in TVK without bootstrapping
7. reuse path prevents second bootstrap for same context
8. all Phase 4 tests still pass

## Phase 5 commit plan

| Sub-phase | Commit message | Test gate |
|---|---|---|
| 5.1 | `feat(phase5.1): uncertainty model in JudgementStates workspace` | 5.1 tests pass |
| 5.2 | `feat(phase5.2): terminator threshold in judgement_typed` | 5.1+5.2 pass |
| 5.3 | `feat(phase5.3): AI agent pipeline input/output contracts` | 5.3 pass |
| 5.4 | `feat(phase5.4): cortex registry interface` | 5.4 pass |
| 5.5 | `feat(phase5.5): reuse path for accumulated cortex specs` | ALL 5.x pass |

## Milestone

MVP = Phase 5 complete + Phase 4 green + at least one cortex spec accumulated and reused across two inferences.
