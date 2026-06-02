---
title: Phase 4 Target Contract
created: 2026-06-01
updated: 2026-06-02
type: concept
tags: [phase4, contract, typed-cortex, judgement, tvk, ir, or, bootstrap]
sources: [../raw/phase4-3-bootstrap-blocker.md, ../raw/typed-cortex-bootstrap-protocol.md, ../concepts/phase4-plan.md]
confidence: high
contested: false
---

# Phase 4 Target Contract

Implementation contract for `judgement_typed`.

## Sequence definition

```python
def set_up_judgement_typed(agent_frame):
    @register_inference_sequence("judgement_typed")
    def judgement_typed(self: Inference):
        "IR-TVK-OR"
        states = JudgementStates()

        # Floating terminator: bootstrap kink
        if not states.function:
            states.function.append(ReferenceRecordLite(step_name="IR"))
        if not states.inference:
            states.inference.append(ReferenceRecordLite(step_name="IR"))
        if not states.values:
            states.values.append(ReferenceRecordLite(step_name="IR"))

        states = input_references(inference=self, states=states)
        tvk(self, states)
        concept = getattr(self, "concept_to_infer", None)
        if concept is not None:
            states.workspace["category_decision"] = _category_decision(concept)
        states = output_reference(states)
        return states
```

## Step registration

```python
def configure_judgement_typed(agent_frame, inference_instance: Inference, methods: dict[str, Callable]):
    @inference_instance.register_step("IR")
    def ir(**fkwargs):
        fn = methods.get("input_references", input_references)
        return fn(**fkwargs)

    @inference_instance.register_step("TVK")
    def tvk_step(**fkwargs):
        fn = methods.get("typed_validation_kernel", tvk)
        states = fkwargs.get("states")
        if states is None:
            from infra._states._common_states import BaseStates
            states = getattr(inference_instance, "_tvk_fallback_states", None) or BaseStates()
        result = fn(inference_instance, states)
        concept = getattr(inference_instance, "concept_to_infer", None)
        if concept is not None and isinstance(result, JudgementStates):
            result.workspace["category_decision"] = _category_decision(concept)
        return result

    @inference_instance.register_step("OR")
    def or_(**fkwargs):
        fn = methods.get("output_reference", output_reference)
        return fn(**fkwargs)
```

## AgentFrame extension

- `"demo"` branch: `"judgement_typed"` case calls `configure_judgement_typed(...)`.
- `"composition"` branch: `"judgement_typed"` case maps to `configure_judgement_typed(...)`.

## Test contract

```python
Inference(
    sequence_name="judgement_typed",
    concept_to_infer=typed_concept,
    function_concept=function_concept,
    value_concepts=[...],
)
agent.configure(inference_instance, "judgement_typed")
state = inference_instance.execute()
```

## Runtime contract

### Pre-seeding rule

State categories must be seeded with placeholder `ReferenceRecordLite` records before execution begins. This mirrors the canonical seeding rule in `infra/_agent/_steps/judgement_direct/_iwi.py` and is required for the typed-cortex bootstrap kink to traverse IR -> TVK -> OR.

### Floating terminator

The first entry in `states.function`, `states.inference`, and `states.values` is the floating terminator:
- enacted unconditionally before any step runs
- picks up uncertainty cost across the IR -> TVK -> OR cycle
- persists as the bootstrap signal when `category_decision["binary_outcome"]` is `None` after OR

### IR helper

- Cannot assume `states.function[0]` exists before seeding
- Cannot assume `function_concept.reference` exists
- Seeds `ir_inference_record` in `states.inference` from `concept_to_infer`
- Preserves acquisition reference when present

### TVK

- Validates typed form via `validate_typed_form` from `infra._core._inference`
- Filters unauthorized concepts from `inference.value_concepts`
- Emits `category_decision` into `states.workspace`
- Raises `ValueError` on malformed typed forms rather than silent skip

### OR

Finalization order:
1. inherit from MIA when present
2. otherwise function reference from IR
3. otherwise IR inference record reference
4. otherwise complete with debug log and no finalized inference reference

## Open items

- Move bootstrap protocol into formal spec when Phase 5 begins
- Define uncertainty threshold and terminator cycle limit

## Related

- [[phase4-plan]]
- [[inference]]
- [[agentframe]]
- [[judgement-sequence]]
- [[typed-cortex-bootstrap-protocol]]
