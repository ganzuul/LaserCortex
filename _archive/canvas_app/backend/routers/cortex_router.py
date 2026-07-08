"""Cortex Bridge API — the Reading Room for the Statute Book.

Exposes the NormCodeCortexBridge, SpecRegistry, and certificate store
as REST endpoints for the React frontend.  This is the ``/api/cortex``
namespace.
"""
from fastapi import APIRouter, HTTPException
from typing import Any, Dict, List, Optional
from pydantic import BaseModel
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/cortex", tags=["cortex"])


# ── Lazy bridge singleton ─────────────────────────────────────────────

_bridge: Optional[Any] = None


def get_bridge():
    global _bridge
    if _bridge is None:
        from infra._cortex import NormCodeCortexBridge
        _bridge = NormCodeCortexBridge()
    return _bridge


# ── Pydantic response schemas ─────────────────────────────────────────


class SpecSummary(BaseModel):
    cortex_name: str
    form_type: str
    coupling_signature: str
    logic_type: str
    axes: List[str]
    tensor_shape: List[int]
    witness_type: str
    example_count: int


class SpecDetail(BaseModel):
    cortex_name: str
    form_type: str
    form_schema_version: str
    coupling_signature: str
    logic_type: str
    axes: List[str]
    tensor_shape: List[int]
    validation: Dict[str, Any]
    default_payload: Dict[str, Any]
    magnitude_contract: Dict[str, Any]
    examples: List[Dict[str, str]]
    provenance: Dict[str, Any]


class CertificateInfo(BaseModel):
    key: str
    source: str
    target: str
    path_len: int
    verified: bool


class BridgeState(BaseModel):
    registry_bindings: List[Dict[str, Any]]
    certificate_count: int
    lift_cache_size: int
    certificate_keys: List[str]


class InstantiateRequest(BaseModel):
    spec_name: str
    witness_data: Dict[str, Any]


class InstantiateResponse(BaseModel):
    concept_name: str
    spec_name: str
    logic_type: str
    certificate_key: str
    certificate_verified: bool


# ── Spec endpoints ────────────────────────────────────────────────────


@router.get("/specs", response_model=List[SpecSummary])
async def list_specs():
    """List all seed CortexSpecs with summary info."""
    from infra._cortex import SEED_REGISTRY

    return [
        SpecSummary(
            cortex_name=spec.cortex_name,
            form_type=spec.form_type,
            coupling_signature=spec.coupling_signature,
            logic_type=spec.to_logic_type().value,
            axes=spec.axes,
            tensor_shape=spec.tensor_shape,
            witness_type=spec.validation.witness_type,
            example_count=len(spec.examples),
        )
        for spec in SEED_REGISTRY.specs.values()
    ]


@router.get("/specs/{name}", response_model=SpecDetail)
async def get_spec(name: str):
    """Get full detail for a single CortexSpec."""
    from infra._cortex import SEED_REGISTRY

    spec = SEED_REGISTRY.lookup_by_name(name)
    if spec is None:
        raise HTTPException(status_code=404, detail=f"Spec '{name}' not found")

    return SpecDetail(
        cortex_name=spec.cortex_name,
        form_type=spec.form_type,
        form_schema_version=spec.form_schema_version,
        coupling_signature=spec.coupling_signature,
        logic_type=spec.to_logic_type().value,
        axes=spec.axes,
        tensor_shape=spec.tensor_shape,
        validation={
            "uncertainty_required": spec.validation.uncertainty_required,
            "uncertainty_min": spec.validation.uncertainty_min,
            "uncertainty_max": spec.validation.uncertainty_max,
            "witness_type": spec.validation.witness_type,
            "binary_outcome_type": spec.validation.binary_outcome_type,
            "category_label_type": spec.validation.category_label_type,
        },
        default_payload=dict(spec.default_payload),
        magnitude_contract={
            "witness_mass_min": spec.magnitude_contract.witness_mass_min,
            "witness_mass_max": spec.magnitude_contract.witness_mass_max,
            "witness_mass_required": spec.magnitude_contract.witness_mass_required,
            "skeptic_mass_min": spec.magnitude_contract.skeptic_mass_min,
            "skeptic_mass_max": spec.magnitude_contract.skeptic_mass_max,
            "skeptic_mass_required": spec.magnitude_contract.skeptic_mass_required,
            "balance_threshold": spec.magnitude_contract.balance_threshold,
        },
        examples=[
            {
                "title": ex.title,
                "source_text": ex.source_text,
                "witness_extraction": ex.witness_extraction,
                "mapping_hint": ex.mapping_hint,
            }
            for ex in spec.examples
        ],
        provenance={
            "prompt": spec.provenance.prompt,
            "agent_version": spec.provenance.agent_version,
            "human_reviewed": spec.provenance.human_reviewed,
        },
    )


# ── Certificate endpoints ─────────────────────────────────────────────


@router.get("/certificates", response_model=List[str])
async def list_certificates():
    """List all stored certificate keys."""
    bridge = get_bridge()
    return bridge.list_certificates()


@router.get("/certificates/{key}", response_model=Optional[CertificateInfo])
async def get_certificate(key: str):
    """Get a stored certificate by key."""
    bridge = get_bridge()
    cert = bridge.get_certificate(key)
    if cert is None:
        raise HTTPException(status_code=404, detail=f"Certificate '{key}' not found")
    return CertificateInfo(
        key=key,
        source=repr(cert.source),
        target=repr(cert.target),
        path_len=len(cert.path),
        verified=cert.verify(),
    )


# ── Instantiation endpoint ────────────────────────────────────────────


@router.post("/instantiate", response_model=InstantiateResponse)
async def instantiate_spec(req: InstantiateRequest):
    """Issue a writ: instantiate a CortexSpec with witness data."""
    from infra._cortex import SEED_REGISTRY

    spec = SEED_REGISTRY.lookup_by_name(req.spec_name)
    if spec is None:
        raise HTTPException(status_code=404, detail=f"Spec '{req.spec_name}' not found")

    bridge = get_bridge()
    try:
        concept, cert = bridge.instantiate_spec(spec, req.witness_data)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    return InstantiateResponse(
        concept_name=concept.name,
        spec_name=spec.cortex_name,
        logic_type=spec.to_logic_type().value,
        certificate_key=f"{concept.name}:instantiate",
        certificate_verified=cert.verify(),
    )


# ── Bridge state endpoint ─────────────────────────────────────────────


@router.get("/bridge/state", response_model=BridgeState)
async def get_bridge_state():
    """Snapshot of the current NormCodeCortexBridge state."""
    bridge = get_bridge()
    return BridgeState(
        registry_bindings=[
            {"router_index": str(idx), "eml_tree": repr(tree)}
            for idx, tree in bridge.registry.all_bindings()
        ],
        certificate_count=len(bridge._certificates),
        lift_cache_size=len(bridge._lift_cache),
        certificate_keys=bridge.list_certificates(),
    )
