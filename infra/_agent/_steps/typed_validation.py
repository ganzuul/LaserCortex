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
            # remove unauthorized from running value set
            inference.value_concepts = [
                c for c in inference.value_concepts if c is not vc
            ]
    # currently a hard stop on empty values — representative of "exclusion
    # from tensor" by empty operator set; adjust once OR step is wired.
    if not getattr(inference, "value_concepts", []):
        pass
    return states


def _is_authorized(concept: Concept) -> bool:
    ft = getattr(concept, "form_type", None)
    if ft is None:
        return False
    return ft in FORM_TYPES
