---
title: Phase 4 Plan
created: 2026-06-01
updated: 2026-06-02
type: concept
tags: [phase4, plan, auth, typed-cortex, bootstrap, tvk]
sources: [../raw/phase4-3-bootstrap-blocker.md, ../raw/typed-cortex-bootstrap-protocol.md, ./phase4-target-contract.md]
confidence: high
contested: false
---

# Phase 4 Plan

Goal: Turn typed-cortex type signatures into inference credentials. Failure to authenticate = exclusion from tensor, not crash.

Claude’s minimal insertion points for typed credentials:
1. Typed form envelope — Laws 1 and 4 enforcement
2. Monotonicity guard on persistence writes — Law 2 enforcement
3. Category refactor as first-class governance inference — Law 3
4. Audit trail table — pipeline-level monotonicity verification

## Phase 4.1 — Typed cortex lockout
All typed-cortex modules active. Tests intentionally fail authentications. Outcome: failing auth-focused test suite.

## Phase 4.2 — Re-establish authentication via insertion points
Scope: insertion point 1 only.
Outcome:
- `validate_typed_form` gates form registration and typed inference creation
- TVK (`infra/_agent/_steps/typed_validation.py`) filters unauthorized concepts from `inference.value_concepts`
- `judgement_typed` sequence registered on `Inference` via `set_up_judgement_typed`
- `configure_judgement_typed` wires IR/TVK/OR with override hooks

## Phase 4.3 — Wired sequence + bootstrap protocol
Outcome: `judgement_typed` becomes an observable typed-cortex loop.

### Verified behavior
- IR populates state records from `concept_to_infer` and `function_concept`
- TVK emits binary category decision into `states.workspace`
- OR finalizes the inference reference from accumulated state
- `execute()` returns `JudgementStates`

### Bootstrap rule
State categories must be seeded with placeholder `ReferenceRecordLite` records before execution begins. This mirrors the canonical seeding rule from `infra/_agent/_steps/judgement_direct/_iwi.py`.

### Floating terminator
The first seeded entries in `states.function`, `states.inference`, and `states.values` are enacted unconditionally and accumulate uncertainty cost across the sequence. When `category_decision["binary_outcome"]` is `None` after OR, the terminator is the bootstrap signal for a missing typed cortex.

### OR fallback chain
Finalization order:
1. inherit from MIA when present
2. otherwise function reference from IR
3. otherwise IR inference record reference
4. otherwise complete with debug log and no finalized inference reference

### Committed artifacts
- `infra/_agent/_sequences/judgement_typed.py`
- `infra/_agent/_steps/typed_validation.py`
- `infra/_agent/_steps/judgement/_ir.py`
- `infra/_agent/_steps/judgement/_or.py`

## Related

- [[phase4-target-contract]]
- [[inference]]
- [[agentframe]]
- [[tdd-airlock]]
