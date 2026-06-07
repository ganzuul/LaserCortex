"""
Typed Validation Kernel — TVK
Phase 4 insertion point 1: typed-cortex authority gate in IR/TVK.

Contract:
- dotted path: infra._agent._steps.typed_validation.typed_validation_kernel
- accepts (Inference, States) and returns States
- raises ValueError on malformed typed form rather than silent skip
  (malformed forms are corrected at Concept/Inference boundary; here we
  simply gate authorization on value concept set membership)
"""

from typing import Any
from infra._core._concept import Concept, FORM_TYPES
from infra._core._inference import validate_typed_form


def typed_validation_kernel(inference: Any, states: Any) -> Any:
    """Gate value concepts by typed-cortex authorization.

    Unauthorized concepts are removed from the inference payload that
    downstream steps operate over. exceptions surface typed-form errors.
    """
    _ = validate_typed_form(inference.concept_to_infer)
    if inference.function_concept is not None:
        _ = validate_typed_form(inference.function_concept)
    for vc in list(getattr(inference, "value_concepts", None) or []):
        if not _is_authorized(vc):
            inference.value_concepts = [
                c for c in inference.value_concepts if c is not vc
            ]

    concept = getattr(inference, "concept_to_infer", None)
    decision = _build_decision(concept)
    states.workspace["category_decision"] = decision
    return states


def _get_payload(concept):
    ref = getattr(concept, "reference", None)
    return ref.form_payload if ref and ref.form_payload else {}


def _build_decision(concept):
    payload = _get_payload(concept)
    authorized = _is_authorized(concept)
    if not authorized:
        return {
            "authorized": False,
            "witness": None,
            "binary_outcome": None,
            "path_valid": None,
            "step": "TVK",
            "field": None,
        }
    witness = payload.get("witness")
    binary_outcome = payload.get("binary_outcome")
    if not isinstance(binary_outcome, bool):
        binary_outcome = bool(binary_outcome)
    return {
        "authorized": True,
        "witness": witness,
        "binary_outcome": binary_outcome,
        "path_valid": True,
        "step": "TVK",
        "field": payload.get("category_label"),
    }


def _is_authorized(concept: Concept) -> bool:
    ft = getattr(concept, "form_type", None)
    if ft is None:
        return False
    return ft in FORM_TYPES
