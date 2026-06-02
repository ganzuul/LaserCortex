#!/usr/bin/env python3
"""
Phase 5 TDD harness: uncertainty model, threshold policy, agent pipeline,
cortex registry, and reuse path.

Usage:
    python tests/phase5_tdd_tests.py

This file is the RED/GREEN gate for Phase 5. All tests must pass before
any Phase 5 commit is accepted.
"""
import sys
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

# ---------------------------------------------------------------------------
# TDD gate helpers
# ---------------------------------------------------------------------------
PASS_COUNT = 0
FAIL_COUNT = 0
FAILURES = []


def assert_true(name, condition):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"[PASS] {name}")
    else:
        FAIL_COUNT += 1
        FAILURES.append(name)
        print(f"[FAIL] {name}")


# ---------------------------------------------------------------------------
# Phase 5.1 — Uncertainty model
# ---------------------------------------------------------------------------
def test_uncertainty_score_absent_function_reference():
    from infra._states._judgement_states import States
    from infra._states._common_states import ReferenceRecordLite

    states = States()
    states.function.append(ReferenceRecordLite(step_name="IR"))
    states.inference.append(ReferenceRecordLite(step_name="IR"))
    states.values.append(ReferenceRecordLite(step_name="IR"))
    states.workspace["category_decision"] = {
        "authorized": False,
        "binary_outcome": None,
        "path_valid": None,
    }

    # Placeholder import hook until Phase 5.1 is implemented
    try:
        from infra._agent._steps.uncertainty import compute_uncertainty
    except ImportError:
        compute_uncertainty = None

    if compute_uncertainty is None:
        assert_true("compute_uncertainty_importable", False)
        return
    assert_true("compute_uncertainty_importable", True)

    score = compute_uncertainty(states)
    assert_true("uncertainty_score_absent_function_reference", score >= 0.75)


# ---------------------------------------------------------------------------
# Phase 5.2 — Threshold policy
# ---------------------------------------------------------------------------
def test_terminator_triggers_after_n_cycles():
    try:
        from infra._agent._threshold import should_trigger_agent_pipeline
    except ImportError:
        should_trigger_agent_pipeline = None

    if should_trigger_agent_pipeline is None:
        assert_true("should_trigger_agent_pipeline_importable", False)
        return
    assert_true("should_trigger_agent_pipeline_importable", True)

    states = _bootstrap_states(cycles=3, uncertainty=0.87)
    assert_true(
        "terminator_triggers_after_n_cycles",
        should_trigger_agent_pipeline(states) is True,
    )


def test_terminator_does_not_trigger_below_threshold():
    try:
        from infra._agent._threshold import should_trigger_agent_pipeline
    except ImportError:
        return

    states = _bootstrap_states(cycles=3, uncertainty=0.50)
    assert_true(
        "terminator_does_not_trigger_below_threshold",
        should_trigger_agent_pipeline(states) is False,
    )


# ---------------------------------------------------------------------------
# Phase 5.3 — AI agent pipeline contracts
# ---------------------------------------------------------------------------
def test_pipeline_input_contract_validated():
    try:
        from infra._agent._pipeline import validate_pipeline_input
    except ImportError:
        assert_true("validate_pipeline_input_importable", False)
        return
    assert_true("validate_pipeline_input_importable", True)

    payload = _sample_pipeline_input()
    assert_true("pipeline_input_contract_validated", validate_pipeline_input(payload) is True)


def test_pipeline_output_spec_accepted_into_registry():
    try:
        from infra._agent._pipeline import CortexSpec
        from infra._agent._registry import CortexRegistry
    except ImportError:
        assert_true("cortex_registry_importable", False)
        return
    assert_true("cortex_registry_importable", True)

    registry = CortexRegistry()
    spec = CortexSpec(
        cortex_name="threshold_category",
        form_type="threshold_category",
        form_schema_version="0.1.0",
        coupling_signature="commutative",
        validation={},
        axes=["f"],
        tensor_shape=[1],
        default_payload={},
    )
    cortex_id = registry.register_cortex_spec(spec)
    assert_true("pipeline_output_spec_accepted_into_registry", cortex_id is not None)


# ---------------------------------------------------------------------------
# Phase 5.4 — Cortex registry
# ---------------------------------------------------------------------------
def test_registry_lookup_returns_matching_spec():
    try:
        from infra._agent._registry import CortexRegistry
        from infra._agent._pipeline import CortexSpec
    except ImportError:
        return

    registry = CortexRegistry()
    spec = CortexSpec(
        cortex_name="threshold_category",
        form_type="threshold_category",
        form_schema_version="0.1.0",
        coupling_signature="commutative",
        validation={},
        axes=["f"],
        tensor_shape=[1],
        default_payload={},
    )
    registry.register_cortex_spec(spec)
    found = registry.lookup_by_context({"function_concept_name": "threshold_category"})
    assert_true("registry_lookup_returns_matching_spec", found is not None)


# ---------------------------------------------------------------------------
# Phase 5.5 — Reuse path
# ---------------------------------------------------------------------------
def test_instantiated_cortex_resolves_without_bootstrap():
    try:
        from infra._agent._registry import CortexRegistry
        from infra._agent._pipeline import CortexSpec
    except ImportError:
        return

    registry = CortexRegistry()
    spec = CortexSpec(
        cortex_name="threshold_category",
        form_type="threshold_category",
        form_schema_version="0.1.0",
        coupling_signature="commutative",
        validation={"binary_outcome": {"type": "boolean"}},
        axes=["f"],
        tensor_shape=[1],
        default_payload={"binary_outcome": None},
    )
    cortex_id = registry.register_cortex_spec(spec)
    concept = registry.instantiate(cortex_id, {"function_concept_name": "threshold_category"})
    assert_true("instantiated_cortex_resolves_without_bootstrap", concept is not None)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _bootstrap_states(cycles: int, uncertainty: float):
    from infra._states._judgement_states import States
    from infra._states._common_states import ReferenceRecordLite

    states = States()
    states.function.append(ReferenceRecordLite(step_name="IR"))
    states.inference.append(ReferenceRecordLite(step_name="IR"))
    states.values.append(ReferenceRecordLite(step_name="IR"))
    states.workspace["category_decision"] = {
        "authorized": False,
        "binary_outcome": None,
        "path_valid": None,
    }
    states.workspace["uncertainty"] = uncertainty
    states.workspace["survived_cycles"] = cycles
    return states


def _sample_pipeline_input():
    return {
        "floating_terminator": {
            "step_name": "IR",
            "concept": {"id": None},
            "reference": None,
            "survived_cycles": 3,
            "uncertainty_score": 0.87,
        },
        "sequence_trace": {
            "IR": {},
            "TVK": {"category_decision": {"authorized": False, "binary_outcome": None}},
            "OR": {"finalized_reference": None},
        },
        "context": {
            "function_concept_name": "threshold_category",
            "concept_to_infer_type": "{}",
            "working_interpretation": {},
        },
    }


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
def main():
    global PASS_COUNT, FAIL_COUNT

    test_uncertainty_score_absent_function_reference()
    test_terminator_triggers_after_n_cycles()
    test_terminator_does_not_trigger_below_threshold()
    test_pipeline_input_contract_validated()
    test_pipeline_output_spec_accepted_into_registry()
    test_registry_lookup_returns_matching_spec()
    test_instantiated_cortex_resolves_without_bootstrap()

    print(f"\nPhase 5 gate: {PASS_COUNT} PASS, {FAIL_COUNT} FAIL")
    if FAIL_COUNT:
        print("Failures:")
        for name in FAILURES:
            print(f"  - {name}")
        sys.exit(1)
    print("ALL PASS")
    sys.exit(0)


if __name__ == "__main__":
    main()
