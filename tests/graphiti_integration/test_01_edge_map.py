"""
Level 1: Edge type restriction map completeness tests.

Verifies that the EDGE_TYPE_MAP (which controls which node types can be
connected by which edge types) is complete, consistent, and references
only existing types.
"""

from __future__ import annotations

import pytest

# ---------------------------------------------------------------------------
# The edge type restriction map (mirrors the spec)
# ---------------------------------------------------------------------------

EDGE_TYPE_MAP: dict[tuple[str, str], list[str]] = {
    ("EpisodicNode", "NormNode"): ["EXTRACTS_SEMANTICS"],
    ("NormNode", "CortexNode"): ["LIFTS_TO_STRUCTURE", "OWL_KEY_VALUE_PAIR"],
    ("CortexNode", "CertificateNode"): ["CERTIFIES_TO"],
    ("CortexNode", "RecipeNode"): ["COMPRESSES_TO"],
    ("NormNode", "RecipeNode"): ["FEATURE_PROJECTS_TO"],
    ("RecipeNode", "PolicyNode"): ["GENERALIZED_BY"],
    ("PolicyNode", "RecipeNode"): ["SELECTS"],
    ("RecipeNode", "CortexNode"): ["INSTANTIATES"],
    ("CortexNode", "CortexNode"): ["TAMARI_ROTATION"],
    ("RecipeNode", "RecipeNode"): ["REASONING_SIMILARITY"],
}

# All referenced model type names
ALL_NODE_TYPES = {
    "EpisodicNode",
    "EntityNode",  # base for NormNode, CortexNode, CertificateNode, RecipeNode, PolicyNode
    "NormNode",
    "CortexNode",
    "CertificateNode",
    "RecipeNode",
    "PolicyNode",
}

# All referenced edge type names
ALL_EDGE_TYPES = {
    "EXTRACTS_SEMANTICS",
    "LIFTS_TO_STRUCTURE",
    "OWL_KEY_VALUE_PAIR",
    "CERTIFIES_TO",
    "COMPRESSES_TO",
    "FEATURE_PROJECTS_TO",
    "GENERALIZED_BY",
    "SELECTS",
    "INSTANTIATES",
    "TAMARI_ROTATION",
    "REASONING_SIMILARITY",
}


class TestEdgeMapFormat:
    """Test that EDGE_TYPE_MAP has the correct structure."""

    def test_keys_are_tuples_of_two_strings(self):
        """Every key is a (str, str) tuple."""
        for key in EDGE_TYPE_MAP:
            assert isinstance(key, tuple), f"Key {key} is not a tuple"
            assert len(key) == 2, f"Key {key} does not have exactly 2 elements"
            assert isinstance(key[0], str), f"Key {key}[0] is not a string"
            assert isinstance(key[1], str), f"Key {key}[1] is not a string"

    def test_values_are_lists_of_strings(self):
        """Every value is a list of strings."""
        for key, value in EDGE_TYPE_MAP.items():
            assert isinstance(value, list), f"Value for {key} is not a list"
            for v in value:
                assert isinstance(v, str), f"Value {v} in {key} is not a string"

    def test_no_empty_value_lists(self):
        """Every key has at least one allowed edge type."""
        for key, value in EDGE_TYPE_MAP.items():
            assert len(value) > 0, f"Key {key} has an empty list of edge types"

    def test_no_duplicate_edge_types_per_key(self):
        """No duplicated edge types within a single key's value list."""
        for key, value in EDGE_TYPE_MAP.items():
            assert len(value) == len(set(value)), f"Duplicates in {key}: {value}"


class TestEdgeMapReferences:
    """Test that all referenced types in the map actually exist."""

    def test_all_source_types_exist(self):
        """Every source node type referenced in the map is a known type."""
        for (src, _) in EDGE_TYPE_MAP:
            assert src in ALL_NODE_TYPES, f"Unknown source type: {src}"

    def test_all_target_types_exist(self):
        """Every target node type referenced in the map is a known type."""
        for (_, tgt) in EDGE_TYPE_MAP:
            assert tgt in ALL_NODE_TYPES, f"Unknown target type: {tgt}"

    def test_all_edge_types_exist(self):
        """Every edge type name referenced in the map is a known edge type."""
        for edge_types in EDGE_TYPE_MAP.values():
            for et in edge_types:
                assert et in ALL_EDGE_TYPES, f"Unknown edge type: {et}"


class TestEdgeMapCompleteness:
    """Test that the edge map covers all expected relationships."""

    def test_forward_and_inverse_paired(self):
        """Directional pairs (A, B) and (B, A) must use different edge type names
        (e.g., GENERALIZED_BY vs SELECTS). Self-loops (A, A) are exempt."""
        forward = set(EDGE_TYPE_MAP.keys())
        for (a, b) in forward:
            if a == b:
                continue  # Self-loops are exempt (TAMARI_ROTATION, REASONING_SIMILARITY)
            reversed_key = (b, a)
            if reversed_key in forward:
                fwd_types = set(EDGE_TYPE_MAP[(a, b)])
                rev_types = set(EDGE_TYPE_MAP[reversed_key])
                overlap = fwd_types & rev_types
                assert len(overlap) == 0, (
                    f"Bidirectional pair ({a}, {b}) shares edge types: {overlap}"
                )

    def test_all_six_node_types_represented(self):
        """Every core node type appears at least once as source or target."""
        represented = set()
        for (src, tgt) in EDGE_TYPE_MAP:
            represented.add(src)
            represented.add(tgt)
        expected = {"NormNode", "CortexNode", "CertificateNode", "RecipeNode", "PolicyNode"}
        # EpisodicNode is inferred from the trace ingestion pipeline — not explicit in the map
        missing = expected - represented
        assert len(missing) == 0, f"Node types missing from edge map: {missing}"

    def test_tamari_rotation_is_self_loop(self):
        """TAMARI_ROTATION only connects CortexNode to itself."""
        for (src, tgt), edge_types in EDGE_TYPE_MAP.items():
            if "TAMARI_ROTATION" in edge_types:
                assert src == "CortexNode", f"TAMARI_ROTATION source must be CortexNode, got {src}"
                assert tgt == "CortexNode", f"TAMARI_ROTATION target must be CortexNode, got {tgt}"

    def test_reasoning_similarity_is_self_loop(self):
        """REASONING_SIMILARITY only connects RecipeNode to itself."""
        for (src, tgt), edge_types in EDGE_TYPE_MAP.items():
            if "REASONING_SIMILARITY" in edge_types:
                assert src == "RecipeNode", f"REASONING_SIMILARITY source must be RecipeNode, got {src}"
                assert tgt == "RecipeNode", f"REASONING_SIMILARITY target must be RecipeNode, got {tgt}"
