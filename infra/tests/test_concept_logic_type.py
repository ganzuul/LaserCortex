"""Tests for Concept.to_logic_type() — LogicType binding on Concepts."""
from infra._core._concept import Concept, FORM_TO_LOGIC, TYPE_TO_LOGIC
from infra._cortex._logic_types import LogicType


def test_default_logic_type_is_classical():
    c = Concept("x")
    assert c.to_logic_type() == LogicType.CLASSICAL


def test_explicit_logic_type():
    c = Concept("x", logic_type=LogicType.TEMPORAL)
    assert c.to_logic_type() == LogicType.TEMPORAL


def test_form_type_maps_to_logic():
    for form_type, expected in FORM_TO_LOGIC.items():
        c = Concept("x", type="{}", form_type=form_type,
                     form_schema_version="0.1.0", coupling_signature="commutative")
        assert c.to_logic_type() == expected, f"{form_type} -> {expected}"


def test_concept_type_maps_to_logic():
    for nc_type, expected in TYPE_TO_LOGIC.items():
        c = Concept("x", type=nc_type)
        assert c.to_logic_type() == expected, f"{nc_type} -> {expected}"


def test_explicit_overrides_form():
    c = Concept("x", type="{}", form_type="threshold_category",
                 form_schema_version="0.1.0", coupling_signature="commutative",
                 logic_type=LogicType.QUANTUM)
    assert c.to_logic_type() == LogicType.QUANTUM


def test_form_overrides_concept_type():
    c = Concept("x", type="<>", form_type="narrative_justification",
                 form_schema_version="0.1.0", coupling_signature="commutative")
    assert c.to_logic_type() == LogicType.TEMPORAL  # from FORM_TO_LOGIC, not TYPE_TO_LOGIC


def test_bridge_uses_concept_to_logic_type():
    from infra._cortex._bridge import NormCodeCortexBridge
    bridge = NormCodeCortexBridge()
    c = Concept("x", type="<>", form_type="narrative_justification",
                 form_schema_version="0.1.0", coupling_signature="commutative")
    result = bridge.on_inference_complete("1", c, "functional", "run_test")
    assert result.logic_type == LogicType.TEMPORAL


def test_copy_preserves_logic_type():
    c = Concept("x", logic_type=LogicType.QUANTUM)
    c2 = c.copy()
    assert c2.to_logic_type() == LogicType.QUANTUM


def test_functional_type_maps_to_classical():
    c = Concept("x", type="<=")
    assert c.to_logic_type() == LogicType.CLASSICAL


def test_temporal_operators_map_to_temporal():
    for t in ["@if", "@after", "@before", "@by", "@while", "@until"]:
        c = Concept("x", type=t)
        assert c.to_logic_type() == LogicType.TEMPORAL, f"{t} -> TEMPORAL"


def test_quantifiers_map_to_modal():
    for t in ["*every", "*some", "*count"]:
        c = Concept("x", type=t)
        assert c.to_logic_type() == LogicType.MODAL, f"{t} -> MODAL"


def test_epistemic_operators():
    for t in ["$what?", "$how?", ":S:"]:
        c = Concept("x", type=t)
        assert c.to_logic_type() == LogicType.EPISTEMIC, f"{t} -> EPISTEMIC"


def test_judgement_is_paraconsistent():
    c = Concept("x", type="<>")
    assert c.to_logic_type() == LogicType.PARACONSISTENT
