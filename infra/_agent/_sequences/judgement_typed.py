"""
judgement_typed sequence — Phase 4 target: IR-TVK-OR
Insertion point 1 only: typed credential validation + filtering in TVK.
"""

from infra._core import Inference, register_inference_sequence
from infra._states._judgement_states import States as JudgementStates
from infra._core._reference import Reference
from typing import Callable
from infra._agent._steps.typed_validation import typed_validation_kernel


def _null_step(**fkwargs):
    return None


def set_up_judgement_typed(agent_frame):
    """Register the `judgement_typed` sequence on the Inference class."""
    working_interpretation = agent_frame.working_interpretation
    body = agent_frame.body

    @register_inference_sequence("judgement_typed")
    def judgement_typed(self: Inference):
        """`IR-TVK-OR`"""
        states = JudgementStates()
        # Step 1: IR
        states = _step_ir(self, states=states)
        # Step 2: TVK
        states = typed_validation_kernel(self, states)
        # Step 3: OR
        states = _step_or(self, states=states)
        return states


def _step_ir(self, states):
    return states


def _step_or(self, states):
    return states


def configure_judgement_typed(agent_frame, inference_instance: Inference, methods: dict[str, Callable]):
    default_null_step = _null_step

    @inference_instance.register_step("IR")
    def ir(**fkwargs):
        return methods.get("input_references", default_null_step)(**fkwargs)

    @inference_instance.register_step("TVK")
    def tvk(**fkwargs):
        states = fkwargs.get("states")
        if states is None:
            from infra._states._common_states import BaseStates
            states = getattr(inference_instance, '_tvk_fallback_states', None) or BaseStates()
        return typed_validation_kernel(inference_instance, states)

    @inference_instance.register_step("OR")
    def or_(**fkwargs):
        return methods.get("output_reference", default_null_step)(**fkwargs)
