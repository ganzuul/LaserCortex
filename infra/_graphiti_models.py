"""
Graphiti Integration Models — Pydantic models for LaserCortex + NormCode graph entities.

This module provides the shared Pydantic models that define the custom entity
and edge types for the Graphiti integration, as specified in:
  docs/graphiti_integration_spec.md

These models are used both by:
  - Tests (tests/graphiti_integration/)
  - Implementation (infra/_graphiti_service.py, scripts/)

The models enforce the blood-brain barrier pattern between LaserCortex (formal OWL
keys) and NormCode (natural language values) via the OwlKeyValuePair edge.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


# =============================================================================
# Entity Node Attribute Models
# =============================================================================
# These are stored in EntityNode.attributes when entities are created in Graphiti.
# Each model corresponds to a custom entity type in the graph.


class NormNodeAttrs(BaseModel):
    """NormCode semantic node — alpha-channel object with OWL key-value pairing.
    
    Represents a semantic inference or concept from NormCode's reasoning layer.
    The blood-brain barrier is enforced via:
      - owl_key: Formal OWL two-word composition (LaserCortex grammar algebra)
      - nl_value: Natural language phrasing (reasoning traces/tool calls)
    """
    alpha_features: list[str] = Field(
        default=[],
        description="Semantic decomposition features extracted from traces"
    )
    inference_units: list[dict] = Field(
        default=[],
        description="Inference units extracted from reasoning traces"
    )
    coupling_signature: Literal["commutative", "non_commutative", "non_associative"] = Field(
        default="commutative",
        description="Coupling regime for the inference"
    )
    owl_key: str = Field(
        default="",
        description="OWL two-word composition key (e.g., 'ReserveGuard'). "
                    "Formal grammar algebra identifier from LaserCortex."
    )
    nl_value: str = Field(
        default="",
        description="Natural language value (e.g., 'reserve guard'). "
                    "Human-readable phrasing from reasoning traces or tool calls."
    )


class CortexNodeAttrs(BaseModel):
    """LaserCortex structural node — CD/Tamari structure with OWL key.
    
    Represents a formal structure from LaserCortex's CD algebra and Tamari lattice.
    The blood-brain barrier correlation is maintained via the owl_key field,
    which must match the owl_key of its paired NormNode.
    """
    eml_tree: str = Field(
        default="",
        description="Serialized EMLTree S-expression"
    )
    cd_step: int = Field(
        default=0,
        ge=0,
        le=4,
        description="Cayley-Dickson step (0-4)"
    )
    tamari_path: list[dict] = Field(
        default=[],
        description="Path through Tamari lattice (sequence of rotations)"
    )
    assoc_defect: float = Field(
        default=0.0,
        description="Associativity defect (0 or 4.0)"
    )
    pentagonator_distance: int = Field(
        default=0,
        ge=0,
        description="Steps to rightComb normal form"
    )
    owl_key: str = Field(
        default="",
        description="OWL two-word composition key. Must match NormNode.owl_key "
                    "to maintain blood-brain barrier correlation."
    )


class CertificateNodeAttrs(BaseModel):
    """Certificate node — proof of contraction validity."""
    source_tree: str = Field(
        default="",
        description="Source EMLTree S-expression"
    )
    target_tree: str = Field(
        default="",
        description="Target (rightComb) S-expression"
    )
    proof_object: str = Field(
        default="",
        description="Serialized contracts_to proof object"
    )
    validity: bool = Field(
        default=False,
        description="Whether the certificate verifies"
    )


class RecipeNodeAttrs(BaseModel):
    """Recipe node — distilled reusable algorithm from reasoning trajectories."""
    feature_signature: list[float] = Field(
        default=[],
        description="Embedding centroid for recipe matching"
    )
    allowed_cd_range: tuple[int, int] = Field(
        default=(0, 4),
        description="Range of CD steps this recipe supports"
    )
    canonical_tamari_shape: str = Field(
        default="",
        description="Canonical tree shape identifier"
    )
    success_rate: float = Field(
        default=0.0,
        ge=0.0,
        le=1.0,
        description="Historical success rate (0.0-1.0)"
    )
    cost_profile: dict = Field(
        default={},
        description="Average cost metrics for this recipe"
    )


class PolicyNodeAttrs(BaseModel):
    """Policy node — routing rule induced from repeated recipe success."""
    trigger_features: list[str] = Field(
        default=[],
        description="Feature names that trigger this policy"
    )
    selects_recipe_id: str = Field(
        default="",
        description="UUID of the RecipeNode this policy selects"
    )
    priority_weight: float = Field(
        default=1.0,
        description="Routing priority weight"
    )
    stability_score: float = Field(
        default=1.0,
        description="How stable the routing decision is"
    )


# =============================================================================
# Edge Attribute Models
# =============================================================================
# These are stored in EntityEdge.attributes when edges are created in Graphiti.
# Each model corresponds to a custom edge type in the graph.


class ExtractsSemanticsAttrs(BaseModel):
    """Edge: EpisodicNode → NormNode
    
    Semantics: 'This trace is decomposed into alpha-features + inference units.'
    """
    extraction_method: str = Field(
        default="llm",
        description="Method used for semantic extraction"
    )
    confidence: float = Field(
        default=1.0,
        ge=0.0,
        le=1.0,
        description="Confidence in the extraction"
    )
    feature_overlap: float = Field(
        default=0.0,
        ge=0.0,
        le=1.0,
        description="Overlap score between extracted features"
    )


class LiftsToStructureAttrs(BaseModel):
    """Edge: NormNode → CortexNode
    
    Semantics: 'Semantic inference is embedded into CD/Tamari structure.'
    This is the formal bridge lift operation.
    """
    coupling_signature: Literal["commutative", "non_commutative", "non_associative"] = Field(
        default="commutative",
        description="Coupling regime for the lift"
    )
    tree_generation_method: str = Field(
        default="tree_from_inference_entry",
        description="Method used to generate the EMLTree"
    )
    flow_index: str = Field(
        default="",
        description="Flow index from NormCode plan (e.g., '1.2.3')"
    )


class OwlKeyValuePairAttrs(BaseModel):
    """Edge: NormNode → CortexNode (Blood-Brain Barrier edge)
    
    Semantics: 'This NormNode's natural language value corresponds to this 
    CortexNode's OWL key.'
    
    This edge EXPLICITLY ENFORCES the blood-brain barrier by ensuring:
      - key (formal OWL two-word composition) = NormNode.owl_key = CortexNode.owl_key
      - value (natural language phrasing) = NormNode.nl_value
      - coupling_signature matches NormNode.coupling_signature
      - cd_step matches CortexNode.cd_step
    
    Usage: Every LIFTS_TO_STRUCTURE edge SHOULD have a corresponding 
    OWL_KEY_VALUE_PAIR edge to maintain the key-value correlation.
    """
    key: str = Field(
        default="",
        description="OWL two-word composition (e.g., 'ReserveGuard'). "
                    "Must equal NormNode.owl_key and CortexNode.owl_key."
    )
    value: str = Field(
        default="",
        description="Natural language phrasing (e.g., 'reserve guard'). "
                    "Must equal NormNode.nl_value."
    )
    coupling_signature: Literal["commutative", "non_commutative", "non_associative"] = Field(
        default="commutative",
        description="Must match NormNode.coupling_signature"
    )
    cd_step: int = Field(
        default=0,
        ge=0,
        le=4,
        description="Must match CortexNode.cd_step"
    )


class CertifiesToAttrs(BaseModel):
    """Edge: CortexNode → CertificateNode
    
    Semantics: 'This structure contracts to canonical form under rules.'
    """
    contracted_at_cd: int = Field(
        default=0,
        ge=0,
        le=4,
        description="CD step at which contraction occurred"
    )
    pentagonator_distance: int = Field(
        default=0,
        ge=0,
        description="Pentagonator distance for the contraction"
    )
    verified_in_lean: bool = Field(
        default=False,
        description="Whether the certificate was verified in Lean"
    )


class CompressesToAttrs(BaseModel):
    """Edge: CortexNode → RecipeNode
    
    Semantics: 'This reasoning trajectory is reusable as algorithm.'
    """
    compression_ratio: float = Field(
        default=0.0,
        ge=0.0,
        description="Compression ratio achieved"
    )
    script_format: str = Field(
        default="priming_prompt",
        description="Format of the compressed script"
    )
    cluster_size: int = Field(
        default=0,
        ge=0,
        description="Size of the cluster being compressed"
    )


class FeatureProjectsToAttrs(BaseModel):
    """Edge: NormNode → RecipeNode
    
    Semantics: 'Semantic similarity → reusable algorithm space.'
    """
    similarity: float = Field(
        default=0.0,
        ge=0.0,
        le=1.0,
        description="Semantic similarity score"
    )
    projection_method: str = Field(
        default="centroid_cosine",
        description="Method used for projection"
    )


class GeneralizedByAttrs(BaseModel):
    """Edge: RecipeNode → PolicyNode
    
    Semantics: 'Repeated success induces higher-level routing rule.'
    """
    generalization_count: int = Field(
        default=0,
        ge=0,
        description="Number of times this recipe was generalized"
    )
    success_threshold: float = Field(
        default=0.7,
        ge=0.0,
        le=1.0,
        description="Success rate threshold for generalization"
    )
    stability_window: int = Field(
        default=0,
        ge=0,
        description="Window size for stability calculation"
    )


class SelectsAttrs(BaseModel):
    """Edge: PolicyNode → RecipeNode
    
    Semantics: 'Inference-time control flow: policy picks recipe.'
    """
    routing_frequency: int = Field(
        default=0,
        ge=0,
        description="How often this policy selects a recipe"
    )
    last_selected_at: str = Field(
        default="",
        description="Timestamp of last selection"
    )


class InstantiatesAttrs(BaseModel):
    """Edge: RecipeNode → CortexNode
    
    Semantics: 'Recipe becomes concrete compositional execution.'
    """
    cd_step_at_instantiation: int = Field(
        default=0,
        ge=0,
        le=4,
        description="CD step at which instantiation occurred"
    )
    context_used: str = Field(
        default="",
        description="Context used for instantiation"
    )


class TamariRotationAttrs(BaseModel):
    """Edge: CortexNode → CortexNode (self-loop)
    
    Semantics: 'Discrete curvature of reasoning space.'
    """
    rotation_type: Literal["right", "left"] = Field(
        default="right",
        description="Type of Tamari rotation"
    )
    strut_cost: float = Field(
        default=0.0,
        description="Cost per non-associative step (0.0 or 4.0)"
    )
    assoc_delta: float = Field(
        default=0.0,
        description="Change in associativity defect"
    )
    cd_step: int = Field(
        default=0,
        ge=0,
        le=4,
        description="CD step for this rotation"
    )


class ReasoningSimilarityAttrs(BaseModel):
    """Edge: RecipeNode → RecipeNode (self-loop)
    
    Semantics: 'Recipe space distance under Laser metric.'
    """
    feature_overlap: float = Field(
        default=0.0,
        ge=0.0,
        le=1.0,
        description="Overlap between feature signatures"
    )
    cd_compatibility: float = Field(
        default=1.0,
        ge=0.0,
        le=1.0,
        description="CD step compatibility score"
    )
    cost_distance: float = Field(
        default=0.0,
        ge=0.0,
        description="Distance in cost profile space"
    )
    weight: float = Field(
        default=0.0,
        ge=0.0,
        description="Weight for similarity graph"
    )


# =============================================================================
# Edge Type Restriction Map
# =============================================================================
# Controls which edge types can connect which entity types.
# This is the canonical map referenced by both tests and implementation.

EDGE_TYPE_MAP: dict[tuple[str, str], list[str]] = {
    ("EpisodicNode", "NormNode"): ["EXTRACTS_SEMANTICS"],
    ("NormNode", "CortexNode"): ["LIFTS_TO_STRUCTURE", "OWL_KEY_VALUE_PAIR"],
    ("CortexNode", "CertificateNode"): ["********ES_TO"],
    ("CortexNode", "RecipeNode"): ["COMPRESSES_TO"],
    ("NormNode", "RecipeNode"): ["FEATURE_PROJECTS_TO"],
    ("RecipeNode", "PolicyNode"): ["GENERALIZED_BY"],
    ("PolicyNode", "RecipeNode"): ["SELECTS"],
    ("RecipeNode", "CortexNode"): ["INSTANTIATES"],
    ("CortexNode", "CortexNode"): ["TAMARI_ROTATION"],
    ("RecipeNode", "RecipeNode"): ["REASONING_SIMILARITY"],
}


# =============================================================================
# Type Registry
# =============================================================================
# All entity and edge type names for validation.

ALL_NODE_TYPES = {
    "EpisodicNode",
    "EntityNode",  # base for all custom types
    "NormNode",
    "CortexNode",
    "CertificateNode",
    "RecipeNode",
    "PolicyNode",
}

ALL_EDGE_TYPES = {
    "EXTRACTS_SEMANTICS",
    "LIFTS_TO_STRUCTURE",
    "OWL_KEY_VALUE_PAIR",
    "********ES_TO",
    "COMPRESSES_TO",
    "FEATURE_PROJECTS_TO",
    "GENERALIZED_BY",
    "SELECTS",
    "INSTANTIATES",
    "TAMARI_ROTATION",
    "REASONING_SIMILARITY",
}


# =============================================================================
# Model Registry
# =============================================================================
# Mapping from type names to their Pydantic model classes.
# Used by tests and implementation to get the model for a given type.

ENTITY_MODELS = {
    "NormNode": NormNodeAttrs,
    "CortexNode": CortexNodeAttrs,
    "CertificateNode": CertificateNodeAttrs,
    "RecipeNode": RecipeNodeAttrs,
    "PolicyNode": PolicyNodeAttrs,
}

EDGE_MODELS = {
    "EXTRACTS_SEMANTICS": ExtractsSemanticsAttrs,
    "LIFTS_TO_STRUCTURE": LiftsToStructureAttrs,
    "OWL_KEY_VALUE_PAIR": OwlKeyValuePairAttrs,
    "********ES_TO": CertifiesToAttrs,
    "COMPRESSES_TO": CompressesToAttrs,
    "FEATURE_PROJECTS_TO": FeatureProjectsToAttrs,
    "GENERALIZED_BY": GeneralizedByAttrs,
    "SELECTS": SelectsAttrs,
    "INSTANTIATES": InstantiatesAttrs,
    "TAMARI_ROTATION": TamariRotationAttrs,
    "REASONING_SIMILARITY": ReasoningSimilarityAttrs,
}


# =============================================================================
# Invariants
# =============================================================================
# Formal invariants that must hold for the blood-brain barrier pattern.

class OwlKeyValueInvariants:
    """Invariants for OWL key-value pairing (blood-brain barrier)."""
    
    @staticmethod
    def check_normnode_cortexnode_pair(norm_node: NormNodeAttrs, cortex_node: CortexNodeAttrs) -> bool:
        """Invariant: NormNode.owl_key == CortexNode.owl_key"""
        return norm_node.owl_key == cortex_node.owl_key
    
    @staticmethod
    def check_normnode_edge_pair(norm_node: NormNodeAttrs, edge: OwlKeyValuePairAttrs) -> bool:
        """Invariant: NormNode.owl_key == OwlKeyValuePair.key and NormNode.nl_value == OwlKeyValuePair.value"""
        return (norm_node.owl_key == edge.key and 
                norm_node.nl_value == edge.value and
                norm_node.coupling_signature == edge.coupling_signature)
    
    @staticmethod
    def check_cortexnode_edge_pair(cortex_node: CortexNodeAttrs, edge: OwlKeyValuePairAttrs) -> bool:
        """Invariant: CortexNode.owl_key == OwlKeyValuePair.key and CortexNode.cd_step == OwlKeyValuePair.cd_step"""
        return (cortex_node.owl_key == edge.key and 
                cortex_node.cd_step == edge.cd_step)
    
    @staticmethod
    def check_non_trivial_cd_has_owl_key(cortex_node: CortexNodeAttrs) -> bool:
        """Invariant: CortexNode with cd_step >= 1 must have non-empty owl_key"""
        if cortex_node.cd_step >= 1:
            return bool(cortex_node.owl_key)
        return True  # cd_step == 0 is exempt
    
    @staticmethod
    def check_owl_key_uniqueness(norm_nodes: list[NormNodeAttrs]) -> bool:
        """Invariant: OWL keys are unique across NormNodes"""
        keys = [n.owl_key for n in norm_nodes if n.owl_key]
        return len(keys) == len(set(keys))
