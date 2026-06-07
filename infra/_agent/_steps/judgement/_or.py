import logging

from infra._states._judgement_states import States


def output_reference(states: States) -> States:
    """Finalize the output reference."""
    # Primary path: inherit from MIA when present (full judgement loop).
    mia_ref = states.get_reference("inference", "MIA")
    if mia_ref:
        states.set_reference("inference", "OR", mia_ref)
    else:
        # Bootstrap / typed-cortex path: no MIA, prefer function anchor,
        # otherwise fall back to the IR inference record so OR produces
        # a conclusive reference and the bootstrap trajectory remains
        # observable in state.
        function_ref = states.get_reference("function", "IR")
        if function_ref:
            states.set_reference("inference", "OR", function_ref)
        else:
            ir_record = next((r for r in states.inference if r.step_name == "IR"), None)
            if ir_record is not None and ir_record.reference is not None:
                states.set_reference("inference", "OR", ir_record.reference)
            else:
                logging.debug("OR completed without MIA, function, or IR inference reference")
    states.set_current_step("OR")
    logging.debug(f"OR completed. Final inference state: {states.inference}")
    return states 