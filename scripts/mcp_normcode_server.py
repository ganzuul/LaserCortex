#!/usr/bin/env python3
"""
NormCode MCP Server — exposes parser, cortex bridge, and orchestrator as MCP tools.

Usage:
    python scripts/mcp_normcode_server.py          # Start server (stdio transport)

Configuration:
    Set ``LASERCORTEX_DEBUG=1`` for verbose logging.
    Set ``LASERCORTEX_ORCH_DB`` for checkpoint database path (default: `checkpoints.sqlite`).

Architecture:
    Single-process, single-threaded. Holds an in-process ``NormCodeCortexBridge``
    and optionally an ``Orchestrator`` for plan execution.  Plan state is NOT
    persisted across MCP restarts (checkpoints ARE persisted via SQLite).

Tool groups:
    - ``normcode_parse_*``   — Parsing .ncd / .ncn / .ncdn / .ncds files
    - ``normcode_cortex_*``  — Lifting, grounding, verifying via CortexBridge
    - ``normcode_orch_*``    — Loading and stepping through NC plan execution
"""

from __future__ import annotations

import json
import logging
import os
import sys
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

# ── Path setup: add canvas_app/backend so we can import NormCodeParser ──
_BACKEND = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "canvas_app", "backend")
if _BACKEND not in sys.path:
    sys.path.insert(0, _BACKEND)

# ── MCP ────────────────────────────────────────────────────────────────
from mcp.server.fastmcp import FastMCP

# ── Parser ──────────────────────────────────────────────────────────────
try:
    from services.parsers.normcode import NormCodeParser
except ImportError:
    NormCodeParser = None  # type: ignore

# ── Infra modules ───────────────────────────────────────────────────────
from infra._cortex._bridge import (
    CortexBridge,
    NormCodeCortexBridge,
    CortexBridgeError,
)
from infra._cortex._eml_tree import (
    EMLTree, tree_from_inference_entry, tree_from_flow_index,
)
from infra._cortex._spec import CortexSpec, SpecRegistry, SEED_REGISTRY
from infra._cortex._types import CortexCertificate, RouterIndex, RouterIndexError, flow_to_index

# ── Logging ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.DEBUG if os.environ.get("LASERCORTEX_DEBUG") else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("mcp-normcode")

# =========================================================================
# Server instance
# =========================================================================

mcp = FastMCP(
    "normcode-server",
    instructions="NormCode MCP server — parser, cortex bridge, and orchestrator tools",
)

# =========================================================================
# Global state (per-process)
# =========================================================================

_bridge = NormCodeCortexBridge(registry_bound=1024)
_orch_store: Dict[str, Any] = {}       # plan_id -> Orchestrator instance
_plan_store: Dict[str, Any] = {}        # plan_id -> parsed plan data
_logger = logger

# =========================================================================
# Helper — serialize bridge objects to JSON-safe dicts
# =========================================================================

def _tree_to_dict(tree: EMLTree) -> Dict[str, Any]:
    """Convert an EMLTree to a JSON-serialisable dict."""
    if tree.is_leaf:
        return {"type": "leaf"}
    return {
        "type": "node",
        "left": _tree_to_dict(tree.left),
        "right": _tree_to_dict(tree.right),
    }


def _lift_result_to_dict(result: Any) -> Dict[str, Any]:
    """Convert a LiftResult to a JSON-serialisable dict."""
    return {
        "router_index": {
            "index": result.router_index.index,
            "bound": result.router_index.bound,
        },
        "eml_tree": {
            "bits": result.eml_tree.to_bits(),
            "size": result.eml_tree.size(),
            "height": result.eml_tree.height(),
            "tree": _tree_to_dict(result.eml_tree),
        },
        "logic_type": str(result.logic_type),
        "gate_results": result.gate_results,
        "spec_name": result.spec_name,
    }


def _certificate_to_dict(cert: CortexCertificate) -> Dict[str, Any]:
    """Convert a CortexCertificate to a JSON-serialisable dict."""
    return {
        "source_bits": cert.source.to_bits(),
        "target_bits": cert.target.to_bits(),
        "source_size": cert.source.size(),
        "target_size": cert.target.size(),
    }


# =========================================================================
# PARSER TOOLS
# =========================================================================


@mcp.tool(
    name="normcode_parse_file",
    description="Parse a .ncd / .ncn / .ncdn / .ncds file into structured JSON",
)
def parse_file(path: str, format: Optional[str] = None) -> str:
    """Parse a NormCode file at *path* and return structured JSON.

    Args:
        path: Absolute or relative path to the NormCode file.
        format: File format (ncd, ncn, ncdn, ncds).  Auto-detected from
            extension if omitted.

    Returns:
        JSON string with ``lines``, each containing flow_index, depth,
        concept_name, concept_type, inference_marker, nc_main, ncn_content, etc.
    """
    if NormCodeParser is None:
        return json.dumps({"error": "NormCodeParser not available (canvas_app import failed)"})

    if format is None:
        ext = os.path.splitext(path)[1].lstrip(".").lower()
        if ext in ("ncd", "ncn", "ncdn", "ncds"):
            format = ext
        else:
            format = "ncdn"  # default

    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        return json.dumps({"error": f"File not found: {path}"})
    except Exception as e:
        return json.dumps({"error": str(e)})

    return _parse_text(content, format)


@mcp.tool(
    name="normcode_parse_text",
    description="Parse inline NormCode text into structured JSON",
)
def parse_text(text: str, format: str = "ncdn") -> str:
    """Parse inline NormCode text and return structured JSON.

    Args:
        text: NormCode content (raw text).
        format: One of 'ncd', 'ncn', 'ncdn', 'ncds' (default 'ncdn').

    Returns:
        JSON string with the parsed structure.
    """
    if NormCodeParser is None:
        return json.dumps({"error": "NormCodeParser not available (canvas_app import failed)"})
    return _parse_text(text, format)


def _parse_text(text: str, format: str) -> str:
    """Shared parse logic for file and text tools."""
    try:
        parser = NormCodeParser()
        result = parser.parse(text, format)
        if not result.success:
            return json.dumps({"error": "; ".join(result.errors) if result.errors else "Parse failed"})
        return json.dumps(result.lines, indent=2, ensure_ascii=False, default=str)
    except Exception as e:
        _logger.exception("Parse error")
        return json.dumps({"error": str(e)})


@mcp.tool(
    name="normcode_list_inferences",
    description="Extract inference list from parsed NormCode plan data",
)
def list_inferences(plan_json: str) -> str:
    """Extract a list of inferences from previously-parsed plan data.

    Each inference includes: flow_index, concept_name, concept_type,
    inference_marker, depth, and ncn_content (if available).

    Args:
        plan_json: The JSON string returned by ``normcode_parse_file``
            or ``normcode_parse_text``.

    Returns:
        JSON list of inference entries.
    """
    try:
        data = json.loads(plan_json)
    except json.JSONDecodeError as e:
        return json.dumps({"error": f"Invalid JSON: {e}"})

    lines = data if isinstance(data, list) else data.get("lines", [])
    inferences = []
    for line in lines:
        if isinstance(line, dict) and line.get("type") == "main":
            inferences.append({
                "flow_index": line.get("flow_index"),
                "concept_name": line.get("concept_name"),
                "concept_type": line.get("concept_type"),
                "operator_type": line.get("operator_type"),
                "inference_marker": line.get("inference_marker"),
                "depth": line.get("depth"),
                "ncn_content": line.get("ncn_content", ""),
                "nc_main": line.get("nc_main", ""),
            })
    return json.dumps(inferences, indent=2, ensure_ascii=False)


@mcp.tool(
    name="normcode_summary",
    description="Human-readable summary of a parsed NormCode plan",
)
def plan_summary(plan_json: str) -> str:
    """Return a human-readable summary of the plan.

    Args:
        plan_json: JSON output from ``normcode_parse_file`` or
            ``normcode_parse_text``.

    Returns:
        Multi-line summary string.
    """
    try:
        data = json.loads(plan_json)
    except json.JSONDecodeError as e:
        return f"Error: {e}"

    lines = data if isinstance(data, list) else data.get("lines", [])
    inferences = [l for l in lines if isinstance(l, dict) and l.get("type") == "main"]
    comments = [l for l in lines if isinstance(l, dict) and l.get("type") != "main"]

    parts = [
        f"Plan summary:",
        f"  Inferences:  {len(inferences)}",
        f"  Comments:    {len(comments)}",
        f"  Depth range: 0–{max((l.get('depth', 0) for l in lines if isinstance(l, dict)), default=0)}",
    ]

    # Count concept types
    type_counts: Dict[str, int] = {}
    for inf in inferences:
        ct = inf.get("concept_type", "unknown") or "unknown"
        type_counts[ct] = type_counts.get(ct, 0) + 1
    if type_counts:
        parts.append(f"  Concept types: {dict(sorted(type_counts.items()))}")

    # Flow index range
    fis = [inf.get("flow_index") for inf in inferences if inf.get("flow_index")]
    if fis:
        parts.append(f"  Flow index range: {min(fis)} – {max(fis)}")

    return "\n".join(parts)


@mcp.tool(
    name="normcode_convert_format",
    description="Convert parsed NormCode data to a different format",
)
def convert_format(plan_json: str, target_format: str) -> str:
    """Convert parsed NormCode data to another format.

    Args:
        plan_json: JSON output from ``normcode_parse_file`` or
            ``normcode_parse_text``.
        target_format: One of 'ncd', 'ncn', 'ncdn', 'ncds', 'json', 'nci'.

    Returns:
        Converted content as a string.
    """
    if NormCodeParser is None:
        return json.dumps({"error": "NormCodeParser not available"})
    try:
        data = json.loads(plan_json)
    except json.JSONDecodeError as e:
        return json.dumps({"error": f"Invalid JSON: {e}"})

    if not isinstance(data, dict):
        data = {"lines": data}

    try:
        parser = NormCodeParser()
        result = parser.serialize(data, target_format)
        if not result.success:
            return json.dumps({"error": "; ".join(result.errors) if result.errors else "Serialize failed"})
        return result.content
    except Exception as e:
        _logger.exception("Convert error")
        return json.dumps({"error": str(e)})


# =========================================================================
# CORTEX TOOLS
# =========================================================================


@mcp.tool(
    name="normcode_list_specs",
    description="List all registered CortexSpecs (statutes) in the seed registry",
)
def list_specs() -> str:
    """List all statutes (CortexSpecs) registered in the seed registry.

    Returns:
        JSON list of spec names and descriptions.
    """
    specs = []
    for spec in SEED_REGISTRY.specs.values():
        specs.append({
            "cortex_name": spec.cortex_name,
            "form_type": spec.form_type,
            "coupling_signature": spec.coupling_signature,
            "axes": spec.axes,
        })
    return json.dumps(specs, indent=2, ensure_ascii=False)


@mcp.tool(
    name="normcode_get_spec",
    description="Get a specific CortexSpec by name",
)
def get_spec(name: str) -> str:
    """Get a specific statute (CortexSpec) by its ``cortex_name``.

    Args:
        name: The ``cortex_name`` of the spec (e.g. ``"will.temporal"``).

    Returns:
        JSON dict with the spec's full definition, or an error if not found.
    """
    spec = SEED_REGISTRY.lookup(name)
    if spec is None:
        return json.dumps({"error": f"Spec '{name}' not found"})
    return json.dumps({
        "cortex_name": spec.cortex_name,
        "form_type": spec.form_type,
        "form_schema_version": spec.form_schema_version,
        "coupling_signature": spec.coupling_signature,
        "axes": spec.axes,
        "default_payload": spec.default_payload,
    }, indent=2, ensure_ascii=False)


@mcp.tool(
    name="normcode_lift_inference",
    description="Lift an NC inference into the LaserCortex formal layer",
)
def lift_inference(
    flow_index: str,
    concept_name: str,
    sequence_type: str,
    concept_json: Optional[str] = None,
    coupling_signature: Optional[str] = None,
    spec_name: Optional[str] = None,
    value_concept_count: int = 0,
    has_function_concept: bool = False,
    supporting_count: int = 0,
) -> str:
    """Lift an NC inference into the LC formal layer.

    Produces an EMLTree (with size/shape determined by the dependency
    structure), a CortexCertificate (contraction path to normal form),
    a LogicType, and gate pipeline results — all under the authority
    of a governing statute (CortexSpec).

    Args:
        flow_index: NC flow index (e.g. ``"1.2.3"``).
        concept_name: The concept being inferred.
        sequence_type: NC inference sequence type (e.g. ``"simple"``).
        concept_json: Optional Concept attributes as JSON (e.g.
            ``{"coupling_signature": "non-commutative"}``).
        coupling_signature: Coupling signature override if not in
            ``concept_json``.
        spec_name: Name of the governing statute (CortexSpec).
        value_concept_count: Number of value/input concepts.
        has_function_concept: Whether a function concept exists.
        supporting_count: Number of sub-inferences feeding into this one.

    Returns:
        JSON with eml_tree, router_index, logic_type, gate_results, spec_name.
    """
    # Resolve concept object
    concept = None
    if concept_json:
        try:
            concept_data = json.loads(concept_json)
        except json.JSONDecodeError as e:
            return json.dumps({"error": f"Invalid concept_json: {e}"})
        # Build a minimal Concept-like object
        concept = _MinimalConcept(
            name=concept_name,
            coupling_signature=concept_data.get("coupling_signature") or coupling_signature,
        )
    else:
        concept = _MinimalConcept(
            name=concept_name,
            coupling_signature=coupling_signature,
        )

    # Resolve spec
    spec = None
    if spec_name:
        spec = SEED_REGISTRY.lookup(spec_name)

    # Build formal tree when dependency structure available
    if value_concept_count > 0 or has_function_concept or supporting_count > 0:
        sig = coupling_signature
        if sig is None and hasattr(concept, "coupling_signature"):
            sig = concept.coupling_signature
        tree = tree_from_inference_entry(
            value_concept_count=value_concept_count,
            has_function_concept=has_function_concept,
            supporting_count=supporting_count,
            coupling_signature=sig,
        )
    else:
        tree = None  # fall back to heuristic

    try:
        result = _bridge.core.lift_inference(
            flow_index=flow_index,
            concept_name=concept_name,
            sequence_type=sequence_type,
            coupling_signature=coupling_signature,
            concept=concept,
            spec=spec,
            eml_tree=tree,
        )
        return json.dumps(_lift_result_to_dict(result), indent=2, ensure_ascii=False)
    except Exception as e:
        _logger.exception("Lift error")
        return json.dumps({"error": str(e)})


@mcp.tool(
    name="normcode_ground_certificate",
    description="Ground a CortexCertificate back into NC: Decomposition + Decision",
)
def ground_certificate(cert_key: str) -> str:
    """Ground a cached CortexCertificate back into NC.

    Produces the Decomposition (ancestor trees) and Decision (truth table)
    that reconstruct the certificate's contraction path.

    Args:
        cert_key: Certificate key in the format ``{run_id}:{flow_index}``
            or ``{run_id}`` (for wax seals).

    Returns:
        JSON with certificate, decompositions, and decision.
    """
    # Check wax seals first, then lift cache
    cert = _bridge._certificates.get(cert_key)
    if cert is None:
        lift_result = _bridge._lift_cache.get(cert_key)
        if lift_result is not None:
            cert = lift_result.certificate
    if cert is None:
        return json.dumps({"error": f"Certificate '{cert_key}' not found in bridge cache"})

    try:
        result = _bridge.core.ground_certificate(cert)
        return json.dumps({
            "certificate": _certificate_to_dict(cert),
            "decompositions": [
                {"source_bits": d.source.to_bits(), "target_bits": d.target.to_bits()}
                for d in result.decompositions
            ],
            "decision": {
                "tree_bits": result.decision.tree.to_bits() if hasattr(result.decision, "tree") else None,
                "source_bits": result.decision.tree.source.to_bits() if hasattr(result.decision, "tree") and hasattr(result.decision.tree, "source") else None,
            },
        }, indent=2, ensure_ascii=False, default=str)
    except Exception as e:
        _logger.exception("Ground error")
        return json.dumps({"error": str(e)})


@mcp.tool(
    name="normcode_list_certificates",
    description="List all cached certificates in the bridge",
)
def list_certificates() -> str:
    """List all certificates cached in the bridge (both lift cache and wax seals).

    Returns:
        JSON list of certificate keys with metadata.
    """
    certs = []
    for key, cert in _bridge._certificates.items():
        certs.append({
            "key": key,
            "type": "wax_seal",
            "source_size": cert.source.size(),
            "target_size": cert.target.size(),
        })
    for key, lift_result in _bridge._lift_cache.items():
        certs.append({
            "key": key,
            "type": "lift",
            "source_size": lift_result.certificate.source.size(),
            "target_size": lift_result.certificate.target.size(),
            "flow_index": key.split(":", 1)[1] if ":" in key else None,
        })
    return json.dumps(certs, indent=2, ensure_ascii=False)


@mcp.tool(
    name="normcode_verify_certificate",
    description="Verify a certificate's contraction path is valid",
)
def verify_certificate(cert_key: str) -> str:
    """Verify that a cached certificate's contraction path is valid.

    Checks that ``contracts_to(cert.source, cert.target)`` holds.

    Args:
        cert_key: Certificate key (``{run_id}:{flow_index}`` or ``{run_id}``).

    Returns:
        JSON with ``verified`` (bool) and details.
    """
    from infra._cortex._eml_tree import contracts_to, decidable_contracts_to

    cert = _bridge._certificates.get(cert_key)
    if cert is None:
        lift_result = _bridge._lift_cache.get(cert_key)
        if lift_result is not None:
            cert = lift_result.certificate
    if cert is None:
        return json.dumps({"error": f"Certificate '{cert_key}' not found"})

    try:
        ok = decidable_contracts_to(cert.source, cert.target)
        return json.dumps({
            "verified": ok,
            "source_bits": cert.source.to_bits(),
            "target_bits": cert.target.to_bits(),
            "source_size": cert.source.size(),
            "target_size": cert.target.size(),
        }, indent=2, ensure_ascii=False)
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool(
    name="normcode_bridge_state",
    description="Get current bridge state (registered trees, certificate count)",
)
def bridge_state() -> str:
    """Return the current state of the bridge.

    Includes:
      - TypeRegistry registered tree count
      - Lift cache size
      - Wax seal (certificate) count
      - Registry bound

    Returns:
        JSON dict with bridge state.
    """
    return json.dumps({
        "registry_tree_count": len(_bridge.registry._entries),
        "lift_cache_size": len(_bridge._lift_cache),
        "wax_seal_count": len(_bridge._certificates),
        "registry_bound": _bridge.registry.bound,
    }, indent=2, ensure_ascii=False)


@mcp.tool(
    name="normcode_instantiate_writ",
    description="Issue a writ under a statute: instantiate a Concept + Certificate from witness data",
)
def instantiate_writ(spec_name: str, witness_json: str) -> str:
    """Issue a formal writ under a CortexSpec.

    Takes concrete witness data and produces a certified Concept
    under the statute's authority.

    Args:
        spec_name: Name of the CortexSpec (statute).
        witness_json: JSON dict with witness data fields matching
            the spec's ``writ_checks``.

    Returns:
        JSON with the created Concept and CortexCertificate.
    """
    spec = SEED_REGISTRY.lookup(spec_name)
    if spec is None:
        return json.dumps({"error": f"Spec '{spec_name}' not found"})

    try:
        witness = json.loads(witness_json)
    except json.JSONDecodeError as e:
        return json.dumps({"error": f"Invalid witness_json: {e}"})

    try:
        concept, cert = _bridge.instantiate_spec(spec, witness)
        return json.dumps({
            "concept_name": concept.name if hasattr(concept, "name") else str(concept),
            "certificate": _certificate_to_dict(cert),
            "spec_name": spec_name,
        }, indent=2, ensure_ascii=False, default=str)
    except Exception as e:
        _logger.exception("Instantiate error")
        return json.dumps({"error": str(e)})


@mcp.tool(
    name="normcode_run_closure",
    description="Run institutional closure on a list of events",
)
def run_closure(events_json: str) -> str:
    """Run the institutional closure pipeline on a list of events.

    Closure = temporal_normalize → fuzzy_grade → deontic_update,
    producing a BlamePool.

    Each event: ``{"year": int, "description": str, "impact": float}``.

    Args:
        events_json: JSON list of events.

    Returns:
        JSON with events and BlamePool.
    """
    from infra._cortex._closure import Event, BlamePool, closure as run_closure

    try:
        events_data = json.loads(events_json)
    except json.JSONDecodeError as e:
        return json.dumps({"error": f"Invalid events_json: {e}"})

    if not isinstance(events_data, list):
        events_data = [events_data]

    events = [
        Event(year=e.get("year", 0), description=e.get("description", ""), impact=float(e.get("impact", 0)))
        for e in events_data
    ]

    try:
        result_events, pool = run_closure(events)
        return json.dumps({
            "events": [
                {"year": e.year, "description": e.description, "impact": e.impact}
                for e in result_events
            ],
            "blame_pool": {
                "total_impact": pool.total_impact,
                "event_count": pool.event_count,
            },
        }, indent=2, ensure_ascii=False, default=str)
    except Exception as e:
        _logger.exception("Closure error")
        return json.dumps({"error": str(e)})


@mcp.tool(
    name="normcode_run_blame_on_blackboard",
    description="Convert a blackboard's history to events and compute blame",
)
def run_blame_on_blackboard(blackboard_json: str) -> str:
    """Convert a blackboard inference history to Events and compute the BlamePool.

    Args:
        blackboard_json: JSON dict with a ``history`` key mapping
            flow_index → ``{"status": "completed"|"failed", "cycle": int}``.

    Returns:
        JSON with events and blame pool.
    """
    try:
        blackboard = json.loads(blackboard_json)
    except json.JSONDecodeError as e:
        return json.dumps({"error": f"Invalid blackboard_json: {e}"})

    try:
        events, pool = _bridge.run_closure_on_blackboard(blackboard)
        return json.dumps({
            "events": [
                {"year": e.year, "description": e.description, "impact": e.impact}
                for e in events
            ],
            "blame_pool": {
                "total_impact": pool.total_impact,
                "event_count": pool.event_count,
            },
        }, indent=2, ensure_ascii=False, default=str)
    except Exception as e:
        _logger.exception("Blame error")
        return json.dumps({"error": str(e)})


# =========================================================================
# ORCHESTRATOR TOOLS
# =========================================================================


@mcp.tool(
    name="normcode_orch_load_plan",
    description="Load a .ncd plan file and build repos for orchestration",
)
def orch_load_plan(path: str, spec_registry: Optional[str] = None) -> str:
    """Parse a .ncd plan file, build ConceptRepo + InferenceRepo, and load
    an Orchestrator.  Returns a ``plan_id`` (UUID) for subsequent tool calls.

    Args:
        path: Path to the .ncd plan file.
        spec_registry: Optional JSON file path with additional CortexSpecs
            to register.

    Returns:
        JSON with ``plan_id`` and summary.
    """
    from infra._orchest._orchestrator import Orchestrator
    from infra._orchest._repo import ConceptRepo, InferenceEntry, ConceptEntry
    from infra._core import Concept

    # Parse the plan file
    if NormCodeParser is None:
        return json.dumps({"error": "NormCodeParser not available"})

    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        return json.dumps({"error": f"File not found: {path}"})
    except Exception as e:
        return json.dumps({"error": str(e)})

    ext = os.path.splitext(path)[1].lstrip(".").lower()
    fmt = ext if ext in ("ncd", "ncn", "ncdn", "ncds") else "ncdn"

    parser = NormCodeParser()
    result = parser.parse(content, fmt)
    if not result.success:
        return json.dumps({"error": f"Parse failed: {result.errors}"})

    parsed_lines = result.lines
    _plan_store[path] = {"lines": parsed_lines, "format": fmt}

    # Build minimal repos from parsed lines
    from uuid import uuid4
    plan_id = str(uuid4())

    # Create an Orchestrator
    # NOTE: For a full implementation, we'd need to build proper ConceptRepo
    # and InferenceRepo from the parsed data. For now, we store the parsed
    # data and return the plan_id. The user can then run normcode_orch_run_all
    # with a fully-built plan.
    orch = Orchestrator(run_id=plan_id)
    _orch_store[plan_id] = {
        "orchestrator": orch,
        "parse_result": parsed_lines,
        "format": fmt,
        "path": path,
    }

    inference_count = sum(1 for l in parsed_lines if isinstance(l, dict) and l.get("type") == "main")

    return json.dumps({
        "plan_id": plan_id,
        "path": path,
        "format": fmt,
        "inference_count": inference_count,
        "total_lines": len(parsed_lines),
    }, indent=2, ensure_ascii=False)


@mcp.tool(
    name="normcode_orch_get_state",
    description="Get the current execution state of a plan",
)
def orch_get_state(plan_id: str) -> str:
    """Get the full execution state of a running plan.

    Args:
        plan_id: Plan ID returned by ``normcode_orch_load_plan``.

    Returns:
        JSON with status, current_flow_index, cycle, waitlist, history, etc.
    """
    store = _orch_store.get(plan_id)
    if store is None:
        return json.dumps({"error": f"Plan '{plan_id}' not found"})

    orch = store.get("orchestrator")
    if orch is None:
        return json.dumps({"error": f"Plan '{plan_id}' has no orchestrator"})

    try:
        return json.dumps({
            "status": getattr(orch, "status", "unknown"),
            "run_id": getattr(orch, "run_id", plan_id),
            "cycle": getattr(orch.tracker, "cycle_count", 0) if hasattr(orch, "tracker") else 0,
        }, indent=2, ensure_ascii=False, default=str)
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool(
    name="normcode_orch_stop",
    description="Stop plan execution gracefully",
)
def orch_stop(plan_id: str) -> str:
    """Stop a running plan gracefully.

    Args:
        plan_id: Plan ID from ``normcode_orch_load_plan``.

    Returns:
        JSON with confirmation.
    """
    store = _orch_store.get(plan_id)
    if store is None:
        return json.dumps({"error": f"Plan '{plan_id}' not found"})

    orch = store.get("orchestrator")
    if orch is not None and hasattr(orch, "stop"):
        try:
            orch.stop()
        except Exception:
            pass

    return json.dumps({"status": "stopped", "plan_id": plan_id})


# =========================================================================
# Minimal Concept stub (for lift_inference when no real Concept object)
# =========================================================================

class _MinimalConcept:
    """Minimal Concept-like object for bridge tools."""
    def __init__(self, name: str = "unknown", coupling_signature: Optional[str] = None):
        self.name = name
        self.coupling_signature = coupling_signature


# =========================================================================
# Entry point
# =========================================================================

def main():
    _logger.info("Starting NormCode MCP server ...")
    _logger.info("  FastMCP transport: stdio")
    _logger.info(f"  NormCodeParser: {'available' if NormCodeParser is not None else 'UNAVAILABLE'}")
    _logger.info(f"  Registry bound: {_bridge.registry.bound}")
    _logger.info(f"  Seed specs: {len(SEED_REGISTRY.specs)}")
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
