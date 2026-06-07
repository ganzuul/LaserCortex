"""
judgement_typed sequence — Phase 4.1-4.3
Contract: IR-TVK-OR

- 4.1/4.2: credential validation + filtering in TVK.
- 4.3: step functions produce observable typed-cortex behavior:
  IR populates state records; TVK emits binary category decision;
  OR finalizes inference reference.
"""

from infra._core import Inference, register_inference_sequence
from infra._states._judgement_states import States as JudgementStates
from infra._core._reference import Reference
from typing import Callable
from infra._states._common_states import ReferenceRecordLite
from infra._agent._steps.typed_validation import typed_validation_kernel as tvk
from infra._agent._steps.judgement._ir import input_references
from infra._agent._steps.judgement._or import output_reference


def _null_step(**fkwargs):
    return None


def _is_authorized(concept):
    from infra._core._concept import FORM_TYPES
    return getattr(concept, "form_type", None) in FORM_TYPES


def _category_decision(concept):
    if not _is_authorized(concept):
        return {
            "authorized": False,
            "witness": None,
            "binary_outcome": None,
            "path_valid": None,
            "step": "TVK",
        }
    ref = getattr(concept, "reference", None)
    payload = ref.form_payload if ref and ref.form_payload else {}
    return {
        "authorized": True,
        "witness": payload.get("witness"),
        "binary_outcome": payload.get("binary_outcome"),
        "path_valid": True,
        "step": "TVK",
    }


def set_up_judgement_typed(agent_frame):
    """Register the `judgement_typed` sequence on the Inference class."""

    @register_inference_sequence("judgement_typed")
    def judgement_typed(self: Inference):
        """`IR-TVK-OR`"""
        logger = _logger()
        logger.info("Executing typed-cortex sequence: judgement_typed")
        states = JudgementStates()

        # Floating terminator: seed state categories with placeholder
        # records so the bootstrap kink can traverse IR -> TVK -> OR.
        # This mirrors the canonical pre-seeding rule from
        # judgement_direct/_iwi.py, but scoped to the typed-cortex loop.
        if not states.function:
            states.function.append(ReferenceRecordLite(step_name="IR"))
        if not states.inference:
            states.inference.append(ReferenceRecordLite(step_name="IR"))
        if not states.values:
            states.values.append(ReferenceRecordLite(step_name="IR"))

        # Step 1: IR — fix value concepts then materialize references
        kwargs_ir = {"inference": self, "states": states}
        states = input_references(**kwargs_ir)

        # Step 2: TVK — typed credential gate
        tvk(self, states)
        concept = getattr(self, "concept_to_infer", None)
        if concept is not None:
            states.workspace["category_decision"] = _category_decision(concept)

        # Step 3: OR — finalize reference
        states = output_reference(states)

        return states


def configure_judgement_typed(agent_frame, inference_instance: Inference, methods: dict[str, Callable]):
    """Configure typed steps with optional method overrides."""

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


class _SeqLogger:
    def info(self, msg):
        print(msg)
    def debug(self, msg):
        print(msg)


def _logger():
    return _SeqLogger()
