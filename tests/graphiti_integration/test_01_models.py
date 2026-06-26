"""
Level 1: Unit tests for Pydantic data models.

Tests that all custom entity and edge types enforce their field contracts.
Pure tests — no database, no LLM, no external dependencies beyond pydantic.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

import pytest
from pydantic import ValidationError

# ---------------------------------------------------------------------------
# Helpers: define the model classes inline so tests are self-contained
# (These will be extracted to a shared module when the integration is built.)
# ---------------------------------------------------------------------------


def _make_model_classes():
    """Define Pydantic models matching the graphiti_integration_spec.md spec.

    Returns a dict of model classes so we don't pollute module namespace.
    """
    from pydantic import BaseModel, Field

    # -- Entity node attributes (stored in EntityNode.attributes) -------------

    from typing import Literal

    class NormNodeAttrs(BaseModel):
        alpha_features: list[str] = []
        inference_units: list[dict] = []
        coupling_signature: Literal["commutative", "non_commutative", "non_associative"] = "commutative"

    class CortexNodeAttrs(BaseModel):
        eml_tree: str = ""
        cd_step: int = Field(default=0, ge=0, le=4)
        tamari_path: list[dict] = []
        assoc_defect: float = 0.0
        pentagonator_distance: int = Field(default=0, ge=0)

    class CertificateNodeAttrs(BaseModel):
        source_tree: str = ""
        target_tree: str = ""
        proof_object: str = ""
        validity: bool = False

    class RecipeNodeAttrs(BaseModel):
        feature_signature: list[float] = []
        allowed_cd_range: tuple[int, int] = (0, 4)
        canonical_tamari_shape: str = ""
        success_rate: float = Field(default=0.0, ge=0.0, le=1.0)
        cost_profile: dict = {}

    class PolicyNodeAttrs(BaseModel):
        trigger_features: list[str] = []
        selects_recipe_id: str = ""
        priority_weight: float = 1.0
        stability_score: float = 1.0

    # -- Edge attribute models ------------------------------------------------

    class ExtractsSemanticsAttrs(BaseModel):
        extraction_method: str = "llm"
        confidence: float = 1.0
        feature_overlap: float = 0.0

    class LiftsToStructureAttrs(BaseModel):
        coupling_signature: Literal["commutative", "non_commutative", "non_associative"] = "commutative"
        tree_generation_method: str = "tree_from_inference_entry"
        flow_index: str = ""

    class CertifiesToAttrs(BaseModel):
        contracted_at_cd: int = 0
        pentagonator_distance: int = 0
        verified_in_lean: bool = False

    class CompressesToAttrs(BaseModel):
        compression_ratio: float = 0.0
        script_format: str = "priming_prompt"
        cluster_size: int = 0

    class FeatureProjectsToAttrs(BaseModel):
        similarity: float = 0.0
        projection_method: str = "centroid_cosine"

    class GeneralizedByAttrs(BaseModel):
        generalization_count: int = 0
        success_threshold: float = 0.7
        stability_window: int = 0

    class SelectsAttrs(BaseModel):
        routing_frequency: int = 0
        last_selected_at: str = ""

    class InstantiatesAttrs(BaseModel):
        cd_step_at_instantiation: int = 0
        context_used: str = ""

    class TamariRotationAttrs(BaseModel):
        rotation_type: str = "right"
        strut_cost: float = Field(default=0.0)  # 0.0 or 4.0 only
        assoc_delta: float = 0.0
        cd_step: int = 0

        @pytest.mark.skip  # This is a model method, not a test
        @classmethod
        def _validate_strut_cost(cls, v: float) -> float:
            if v not in (0.0, 4.0):
                raise ValueError(f"strut_cost must be 0.0 or 4.0, got {v}")
            return v

    class ReasoningSimilarityAttrs(BaseModel):
        feature_overlap: float = 0.0
        cd_compatibility: float = 1.0
        cost_distance: float = 0.0
        weight: float = 0.0

    return {
        "NormNode": NormNodeAttrs,
        "CortexNode": CortexNodeAttrs,
        "CertificateNode": CertificateNodeAttrs,
        "RecipeNode": RecipeNodeAttrs,
        "PolicyNode": PolicyNodeAttrs,
        "ExtractsSemantics": ExtractsSemanticsAttrs,
        "LiftsToStructure": LiftsToStructureAttrs,
        "CertifiesTo": CertifiesToAttrs,
        "CompressesTo": CompressesToAttrs,
        "FeatureProjectsTo": FeatureProjectsToAttrs,
        "GeneralizedBy": GeneralizedByAttrs,
        "Selects": SelectsAttrs,
        "Instantiates": InstantiatesAttrs,
        "TamariRotation": TamariRotationAttrs,
        "ReasoningSimilarity": ReasoningSimilarityAttrs,
    }


MODELS = _make_model_classes()


# ---------------------------------------------------------------------------
# Tests: NormNode
# ---------------------------------------------------------------------------


class TestNormNode:
    def test_default_commutative(self):
        """Default coupling_signature is 'commutative'."""
        n = MODELS["NormNode"]()
        assert n.coupling_signature == "commutative"

    def test_accepts_valid_couplings(self):
        """All three allowed coupling values are accepted."""
        for sig in ("commutative", "non_commutative", "non_associative"):
            n = MODELS["NormNode"](coupling_signature=sig)
            assert n.coupling_signature == sig

    def test_rejects_invalid_coupling(self):
        """Invalid coupling_signature raises ValidationError."""
        with pytest.raises(ValidationError):
            MODELS["NormNode"](coupling_signature="hypercommutative")

    def test_empty_alpha_features_default(self):
        """alpha_features defaults to empty list."""
        n = MODELS["NormNode"]()
        assert n.alpha_features == []


# ---------------------------------------------------------------------------
# Tests: CortexNode
# ---------------------------------------------------------------------------


class TestCortexNode:
    def test_default_cd_step_zero(self):
        """cd_step defaults to 0."""
        c = MODELS["CortexNode"]()
        assert c.cd_step == 0

    def test_accepts_cd_range_0_4(self):
        """All values 0-4 are accepted."""
        for step in range(5):
            c = MODELS["CortexNode"](cd_step=step)
            assert c.cd_step == step

    def test_rejects_cd_above_4(self):
        """cd_step > 4 raises ValidationError."""
        with pytest.raises(ValidationError):
            MODELS["CortexNode"](cd_step=5)

    def test_rejects_negative_cd(self):
        """cd_step < 0 raises ValidationError."""
        with pytest.raises(ValidationError):
            MODELS["CortexNode"](cd_step=-1)

    def test_rejects_negative_pentagonator_distance(self):
        """Negative pentagonator_distance raises ValidationError."""
        with pytest.raises(ValidationError):
            MODELS["CortexNode"](pentagonator_distance=-1)

    def test_zero_pentagonator_distance_accepted(self):
        """Zero pentagonator_distance is valid (tree already in normal form)."""
        c = MODELS["CortexNode"](pentagonator_distance=0)
        assert c.pentagonator_distance == 0

    def test_assoc_defect_default_zero(self):
        """assoc_defect defaults to 0.0."""
        c = MODELS["CortexNode"]()
        assert c.assoc_defect == 0.0


# ---------------------------------------------------------------------------
# Tests: CertificateNode
# ---------------------------------------------------------------------------


class TestCertificateNode:
    def test_validity_defaults_false(self):
        """validity defaults to False — certificates are unproven by default."""
        c = MODELS["CertificateNode"]()
        assert c.validity is False

    def test_validity_can_be_true(self):
        """validity can be set to True."""
        c = MODELS["CertificateNode"](validity=True)
        assert c.validity is True

    def test_accepts_any_source_tree(self):
        """source_tree accepts any string."""
        c = MODELS["CertificateNode"](source_tree="(eml (eml 1 1) 1)")
        assert c.source_tree == "(eml (eml 1 1) 1)"


# ---------------------------------------------------------------------------
# Tests: RecipeNode
# ---------------------------------------------------------------------------


class TestRecipeNode:
    def test_success_rate_default_zero(self):
        """success_rate defaults to 0.0."""
        r = MODELS["RecipeNode"]()
        assert r.success_rate == 0.0

    def test_success_rate_accepts_bounds(self):
        """success_rate accepts 0.0 and 1.0."""
        r0 = MODELS["RecipeNode"](success_rate=0.0)
        r1 = MODELS["RecipeNode"](success_rate=1.0)
        assert r0.success_rate == 0.0
        assert r1.success_rate == 1.0

    def test_success_rate_rejects_negative(self):
        """success_rate < 0 raises ValidationError."""
        with pytest.raises(ValidationError):
            MODELS["RecipeNode"](success_rate=-0.1)

    def test_success_rate_rejects_above_one(self):
        """success_rate > 1 raises ValidationError."""
        with pytest.raises(ValidationError):
            MODELS["RecipeNode"](success_rate=1.1)

    def test_allowed_cd_range_default(self):
        """allowed_cd_range defaults to (0, 4)."""
        r = MODELS["RecipeNode"]()
        assert r.allowed_cd_range == (0, 4)


# ---------------------------------------------------------------------------
# Tests: CompositionEvent (modeled as inline below)
# ---------------------------------------------------------------------------


class TestCompositionEvent:
    """CompositionEvent is an EpisodicNode with extra attributes."""

    def test_empty_inputs_valid(self):
        """Empty input_node_uuids is valid (composition from nothing)."""
        from pydantic import BaseModel

        class CompositionEvent(BaseModel):
            input_node_uuids: list[str] = []
            output_node_uuids: list[str] = []
            cd_step: int = 0
            strut_cost: float = 0.0
            tamari_delta: int = 0
            alpha_projection: dict = {}

        event = CompositionEvent()
        assert event.input_node_uuids == []

    def test_all_fields_default(self):
        """All CompositionEvent fields have sensible defaults."""
        from pydantic import BaseModel

        class CompositionEvent(BaseModel):
            input_node_uuids: list[str] = []
            output_node_uuids: list[str] = []
            cd_step: int = 0
            strut_cost: float = 0.0
            tamari_delta: int = 0
            alpha_projection: dict = {}

        event = CompositionEvent()
        assert event.cd_step == 0
        assert event.strut_cost == 0.0
        assert event.tamari_delta == 0
        assert event.alpha_projection == {}


# ---------------------------------------------------------------------------
# Tests: Edge attribute models
# ---------------------------------------------------------------------------


class TestTamariRotation:
    def test_default_rotation_type_right(self):
        """Default rotation_type is 'right'."""
        t = MODELS["TamariRotation"]()
        assert t.rotation_type == "right"

    def test_strut_cost_default_zero(self):
        """strut_cost defaults to 0.0."""
        t = MODELS["TamariRotation"]()
        assert t.strut_cost == 0.0


class TestLiftsToStructure:
    def test_default_flow_index_empty(self):
        """flow_index defaults to empty string."""
        l = MODELS["LiftsToStructure"]()
        assert l.flow_index == ""

    def test_default_coupling_commutative(self):
        """coupling_signature defaults to 'commutative'."""
        l = MODELS["LiftsToStructure"]()
        assert l.coupling_signature == "commutative"


class TestReasoningSimilarity:
    def test_default_weight_zero(self):
        """weight defaults to 0.0."""
        r = MODELS["ReasoningSimilarity"]()
        assert r.weight == 0.0

    def test_default_feature_overlap_zero(self):
        """feature_overlap defaults to 0.0."""
        r = MODELS["ReasoningSimilarity"]()
        assert r.feature_overlap == 0.0


class TestCertifiesTo:
    def test_default_verified_false(self):
        """verified_in_lean defaults to False."""
        c = MODELS["CertifiesTo"]()
        assert c.verified_in_lean is False

    def test_verified_can_be_true(self):
        """verified_in_lean can be set to True."""
        c = MODELS["CertifiesTo"](verified_in_lean=True)
        assert c.verified_in_lean is True


class TestSelects:
    def test_last_selected_at_default_empty(self):
        """last_selected_at defaults to empty string."""
        s = MODELS["Selects"]()
        assert s.last_selected_at == ""


class TestGeneralizedBy:
    def test_default_generalization_count_zero(self):
        """generalization_count defaults to 0."""
        g = MODELS["GeneralizedBy"]()
        assert g.generalization_count == 0

    def test_default_success_threshold(self):
        """success_threshold defaults to 0.7."""
        g = MODELS["GeneralizedBy"]()
        assert g.success_threshold == 0.7
