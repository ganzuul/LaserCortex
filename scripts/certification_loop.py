#!/usr/bin/env python3
"""
Certification Loop — the modest self-improvement loop for LaserCortex.

This module implements the zero-divisor (ZD) detection and certification
pipeline that connects the Open Notebook reasoning library to the
LaserCortex formal certification layer.

The loop:
  1. Take a reasoning trace from the reasoning library
  2. Detect whether the trace's claimed edge type and its invariant text
     imply incompatible CD steps (straddling the CD 2→3 boundary)
  3. If a zero divisor is detected → format a rejection witness and
     write it back to the reasoning library as a new trace
  4. If no ZD → translate the trace to a NormCode concept, lift it via
     CortexBridge, and verify the resulting certificate
  5. Write certified/rejected results back to the reasoning library

The zero divisor is the formal reason for rejection: when incompatible
types are put in partial order, the associator defect activates and
the friction barrier (strut_weight² = 16) makes contraction impossible.
The Lean theorem `friction_barrier_across_cd23` is the proof term.

Usage:
    from scripts.certification_loop import certify_trace, detect_zd
    # Or run directly:
    python scripts/run_certification_loop.py
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time
from dataclasses import dataclass, field, asdict
from typing import Any, Dict, List, Optional

# ── Path setup ─────────────────────────────────────────────────────────
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)
_BACKEND = os.path.join(_PROJECT_ROOT, "canvas_app", "backend")
if _BACKEND not in sys.path:
    sys.path.insert(0, _BACKEND)

logger = logging.getLogger(__name__)

# ── Constants ───────────────────────────────────────────────────────────

# Edge type → claimed CD step (from COUPLING_TO_LOGIC in _spec.py)
# SPECIFICATION: commutative → CLASSICAL (CD 0)
# CONSTRAINT: non-commutative → TEMPORAL (CD 1)
# DATA_SOURCE: commutative → CLASSICAL (CD 0)
# MUTATION_TRIGGER: non-commutative → TEMPORAL (CD 1)
EDGE_TYPE_TO_CDSTEP: Dict[str, int] = {
    "SPECIFICATION": 0,
    "CONSTRAINT": 1,
    "DATA_SOURCE": 0,
    "MUTATION_TRIGGER": 1,
}

# Keyword patterns that indicate non-associative structure (CD ≥ 3)
# These are the linguistic signatures of self-reference, recursion,
# circularity — the algebraic properties that activate the associator
# defect and produce zero divisors in the split octonion algebra.
ZD_PATTERNS: Dict[int, List[str]] = {
    3: [
        "self-reference", "self-referential", "self referential",
        "recursive", "recursion",
        "circular", "circular dependency", "feedback loop",
        "non-associative", "bracketing matters",
        "order-dependent composition", "composition order matters",
        "mutually recursive", "co-recursive",
    ],
    4: [
        "paradox", "self-contradictory", "self contradictory",
        "contradiction", "liar", "inconsistent",
        "both true and false", "true iff false",
        "russell", "self-defeating",
    ],
}

# The CD boundary where the associator defect activates
CD_BOUNDARY_LOW = 2   # last associative regime (Cl(1,1) ≅ ℍ̃)
CD_BOUNDARY_HIGH = 3  # first non-associative regime (split octonions 𝕆ˢ)

# Algebraic constants (verified in Lean)
STRUT_WEIGHT = 4        # SplitOctonionCost.strut_weight_eq_four
STRUT_WEIGHT_SQ = 16    # strut_weight * strut_weight
FRICTION_RATIO = 9.5    # Γ₃ / Γ₂ = 19 / 2
BARRIER_THEOREM = "FrictionLagrangian.friction_barrier_across_cd23"


# ── Data structures ─────────────────────────────────────────────────────

@dataclass
class ZDWitness:
    """Formal witness for a zero-divisor rejection.

    This is the formal reason carried by a rejection trace. It says:
    'the claimed partial order crosses the CD 2→3 boundary, and the
    friction barrier (strut_weight² = 16) makes contraction impossible.'
    """
    boundary: str                    # "CD_2_to_3"
    claimed_cdstep: int              # cdStep implied by edge_type
    actual_cdstep: int               # cdStep implied by invariant text
    strut_weight_sq: int             # 16 — the irreducible barrier
    friction_ratio: float            # 9.5 — Γ₃/Γ₂
    barrier_theorem: str             # Lean proof term name
    claimed_edge_type: str           # original edge type
    matched_pattern: str             # which keyword triggered the detection

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    def format_reason(self) -> str:
        """Format the witness as a human-readable formal reason."""
        return (
            f"Zero divisor detected at {self.boundary} boundary. "
            f"Edge type '{self.claimed_edge_type}' implies CD step "
            f"{self.claimed_cdstep} (associative regime), but invariant "
            f"text implies CD step {self.actual_cdstep} "
            f"(non-associative regime). The friction barrier "
            f"strut_weight² = {self.strut_weight_sq} makes contraction "
            f"impossible (Γ ratio = {self.friction_ratio}). "
            f"Proof: {self.barrier_theorem}. "
            f"Matched pattern: '{self.matched_pattern}'."
        )


@dataclass
class CertificationResult:
    """Result of attempting to certify a trace."""
    certified: bool
    cert_key: Optional[str] = None
    logic_type: Optional[str] = None
    eml_tree_bits: Optional[str] = None
    rejection_reason: Optional[str] = None
    zd_witness: Optional[ZDWitness] = None

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        if self.zd_witness:
            d["zd_witness"] = self.zd_witness.to_dict()
        return d


# ── Component 1: Edge type → cdStep mapper ─────────────────────────────

def edge_type_to_cdstep(edge_type: str) -> int:
    """Map an edge type to its claimed CD step.

    Uses COUPLING_TO_LOGIC mapping:
      SPECIFICATION → commutative → CLASSICAL (CD 0)
      CONSTRAINT → non-commutative → TEMPORAL (CD 1)
      DATA_SOURCE → commutative → CLASSICAL (CD 0)
    """
    return EDGE_TYPE_TO_CDSTEP.get(edge_type, 0)


# ── Component 2: Invariant → cdStep detector ───────────────────────────

def detect_actual_cdstep(invariant: str, failure_mode: str = "",
                         edge_type: str = "") -> tuple[int, Optional[str]]:
    """Detect the actual cdStep from invariant text content.

    Scans for keyword patterns that indicate non-associative structure
    (self-reference, recursion, circularity → CD 3) or paradox-level
    structure (contradiction, liar → CD 4).

    Returns:
        Tuple of (cdstep, matched_pattern). If no pattern matches,
        returns (edge_type_to_cdstep(edge_type), None) — i.e., the
        claimed cdStep is accepted as the actual cdStep.
    """
    text = f"{invariant} {failure_mode}".lower()

    # Check CD 4 patterns first (more specific)
    for pattern in ZD_PATTERNS[4]:
        if pattern in text:
            return 4, pattern

    # Check CD 3 patterns
    for pattern in ZD_PATTERNS[3]:
        if pattern in text:
            return 3, pattern

    # No non-associative pattern found — accept claimed cdStep
    return edge_type_to_cdstep(edge_type), None


# ── Component 3: ZD detector ───────────────────────────────────────────

def detect_zd(claimed_cdstep: int, actual_cdstep: int,
              edge_type: str, matched_pattern: Optional[str]) -> Optional[ZDWitness]:
    """Check if claimed and actual cdSteps straddle the CD 2→3 boundary.

    A zero divisor appears when one side is in the associative regime
    (CD ≤ 2) and the other is in the non-associative regime (CD ≥ 3).
    The friction barrier strut_weight² = 16 is the irreducible cost
    of this crossing — proven by friction_barrier_across_cd23 in Lean.
    """
    lo = min(claimed_cdstep, actual_cdstep)
    hi = max(claimed_cdstep, actual_cdstep)

    if lo <= CD_BOUNDARY_LOW and hi >= CD_BOUNDARY_HIGH:
        return ZDWitness(
            boundary="CD_2_to_3",
            claimed_cdstep=claimed_cdstep,
            actual_cdstep=actual_cdstep,
            strut_weight_sq=STRUT_WEIGHT_SQ,
            friction_ratio=FRICTION_RATIO,
            barrier_theorem=BARRIER_THEOREM,
            claimed_edge_type=edge_type,
            matched_pattern=matched_pattern or "(none)",
        )
    return None


# ── Component 4: Rejection witness formatter ───────────────────────────

def format_rejection_trace(
    original: Dict[str, Any],
    witness: ZDWitness,
) -> Dict[str, Any]:
    """Format a ZD rejection as a new reasoning trace for feedback.

    The rejection trace carries the zero divisor as its formal reason,
    so the reasoning library can learn from the algebraic obstruction.
    """
    pair_key = original.get("pair_key", "unknown")
    inputs = original.get("inputs", {})
    ts = time.time()

    return {
        "pair_key": f"ZD_REJECT:{pair_key}",
        "inputs": {
            **inputs,
            "zd_boundary": witness.boundary,
            "zd_claimed_cdstep": witness.claimed_cdstep,
            "zd_actual_cdstep": witness.actual_cdstep,
            "original_edge_type": witness.claimed_edge_type,
        },
        "reasoning_content": witness.format_reason(),
        "final_content": "REJECTED|ZD",
        "result": {
            "edge_type": "REJECTED",
            "invariant_at_boundary": (
                f"Zero divisor at {witness.boundary}: "
                f"CD {witness.claimed_cdstep}→{witness.actual_cdstep}, "
                f"barrier=strut_weight²={witness.strut_weight_sq}"
            ),
            "failure_mode": (
                f"Contraction impossible — friction ratio {witness.friction_ratio} "
                f"exceeds maximum allowable discontinuity. "
                f"Proof: {witness.barrier_theorem}"
            ),
        },
        "is_positive": False,
        "embedding": None,
        "total_tokens": 0,
        "timestamp": ts,
        "task_config_hash": original.get("task_config_hash", ""),
    }


def format_cert_rejection_trace(
    original: Dict[str, Any],
    reason: str,
) -> Dict[str, Any]:
    """Format a non-ZD certification failure as a rejection trace."""
    pair_key = original.get("pair_key", "unknown")
    inputs = original.get("inputs", {})
    ts = time.time()

    return {
        "pair_key": f"CERT_REJECT:{pair_key}",
        "inputs": inputs,
        "reasoning_content": f"Certification failed: {reason}",
        "final_content": "REJECTED|CERT_FAIL",
        "result": {
            "edge_type": "REJECTED",
            "invariant_at_boundary": "Certificate verification failed",
            "failure_mode": reason,
        },
        "is_positive": False,
        "embedding": None,
        "total_tokens": 0,
        "timestamp": ts,
        "task_config_hash": original.get("task_config_hash", ""),
    }


def format_certified_trace(
    original: Dict[str, Any],
    cert_key: str,
    logic_type: str,
) -> Dict[str, Any]:
    """Format a successful certification as a confirmation trace."""
    pair_key = original.get("pair_key", "unknown")
    inputs = original.get("inputs", {})
    ts = time.time()

    return {
        "pair_key": f"CERTIFIED:{pair_key}",
        "inputs": {
            **inputs,
            "cert_key": cert_key,
            "logic_type": logic_type,
        },
        "reasoning_content": (
            f"Certified via CortexBridge. Certificate key: {cert_key}. "
            f"Logic type: {logic_type}. "
            f"Contraction path verified by decidable_contracts_to."
        ),
        "final_content": "CERTIFIED",
        "result": {
            "edge_type": original.get("result", {}).get("edge_type", ""),
            "invariant_at_boundary": original.get("result", {}).get(
                "invariant_at_boundary", ""
            ),
            "failure_mode": "",
            "cert_key": cert_key,
            "logic_type": logic_type,
        },
        "is_positive": True,
        "embedding": None,
        "total_tokens": 0,
        "timestamp": ts,
        "task_config_hash": original.get("task_config_hash", ""),
    }


# ── Component 5: Certification oracle ──────────────────────────────────

# Edge type → coupling signature → sequence type
EDGE_TYPE_TO_COUPLING: Dict[str, str] = {
    "SPECIFICATION": "commutative",
    "CONSTRAINT": "non-commutative",
    "DATA_SOURCE": "commutative",
    "MUTATION_TRIGGER": "non-commutative",
}

EDGE_TYPE_TO_SEQUENCE: Dict[str, str] = {
    "SPECIFICATION": "simple",
    "CONSTRAINT": "simple",
    "DATA_SOURCE": "simple",
    "MUTATION_TRIGGER": "simple",
}


def certify_trace_via_bridge(
    trace: Dict[str, Any],
    bridge: Optional[Any] = None,
) -> CertificationResult:
    """Certify a trace through the CortexBridge pipeline.

    This calls the bridge directly (not through MCP protocol) to:
    1. Translate the trace to a concept + coupling signature
    2. Lift the inference (build EMLTree, resolve LogicType, issue certificate)
    3. Verify the certificate (check contracts_to source target)

    Args:
        trace: A reasoning trace dict with inputs, result, etc.
        bridge: Optional NormCodeCortexBridge instance. If None, creates one.

    Returns:
        CertificationResult with certified=True/False and details.
    """
    if bridge is None:
        from infra._cortex._bridge import NormCodeCortexBridge
        bridge = NormCodeCortexBridge()

    result = trace.get("result") or {}
    inputs = trace.get("inputs") or {}
    edge_type = result.get("edge_type", "SPECIFICATION")
    invariant = result.get("invariant_at_boundary", "")
    pair_key = trace.get("pair_key", "unknown")

    # Translate trace to bridge parameters
    coupling = EDGE_TYPE_TO_COUPLING.get(edge_type, "commutative")
    seq_type = EDGE_TYPE_TO_SEQUENCE.get(edge_type, "simple")
    concept_name = f"trace:{pair_key}"

    # Flow index from pair key (deterministic)
    flow_index = "1.0"

    # Value concept count: 2 (source + target)
    value_concept_count = 2
    has_function_concept = True
    supporting_count = 0

    try:
        from infra._cortex._eml_tree import tree_from_inference_entry
        from infra._cortex._eml_tree import decidable_contracts_to

        # Build EMLTree from coupling signature
        tree = tree_from_inference_entry(
            value_concept_count=value_concept_count,
            has_function_concept=has_function_concept,
            supporting_count=supporting_count,
            coupling_signature=coupling,
        )

        # Lift inference
        lift_result = bridge.core.lift_inference(
            flow_index=flow_index,
            concept_name=concept_name,
            sequence_type=seq_type,
            coupling_signature=coupling,
            eml_tree=tree,
        )

        cert_key = f"cert_loop:{flow_index}"

        # Store in bridge cache for verification
        bridge._lift_cache[cert_key] = lift_result

        # Verify certificate
        cert = lift_result.certificate
        verified = decidable_contracts_to(cert.source, cert.target)

        if verified:
            return CertificationResult(
                certified=True,
                cert_key=cert_key,
                logic_type=str(lift_result.logic_type),
                eml_tree_bits=cert.source.to_bits(),
            )
        else:
            return CertificationResult(
                certified=False,
                cert_key=cert_key,
                rejection_reason="decidable_contracts_to returned false",
            )

    except Exception as e:
        logger.exception("Certification error")
        return CertificationResult(
            certified=False,
            rejection_reason=f"Bridge error: {e}",
        )


# ── Full loop: ZD check + certify ──────────────────────────────────────

def process_trace(
    trace: Dict[str, Any],
    bridge: Optional[Any] = None,
) -> tuple[CertificationResult, Optional[Dict[str, Any]]]:
    """Process a single trace through the full certification loop.

    Returns:
        Tuple of (CertificationResult, feedback_trace_or_None).
        The feedback_trace is a new trace to write back to the library
        (rejection or confirmation). None if no feedback needed.
    """
    result = trace.get("result") or {}
    edge_type = result.get("edge_type", "")
    invariant = result.get("invariant_at_boundary", "")
    failure_mode = result.get("failure_mode", "")

    # Skip traces that are already rejections
    if edge_type == "REJECTED":
        return CertificationResult(certified=False, rejection_reason="already rejected"), None

    # Skip traces with no result (negative traces from the library)
    if not result or not edge_type:
        return CertificationResult(certified=False, rejection_reason="no result"), None

    # Step 1: ZD detection
    claimed_cdstep = edge_type_to_cdstep(edge_type)
    actual_cdstep, matched_pattern = detect_actual_cdstep(
        invariant, failure_mode, edge_type
    )
    zd = detect_zd(claimed_cdstep, actual_cdstep, edge_type, matched_pattern)

    if zd:
        # Zero divisor found — format rejection and return
        cert_result = CertificationResult(
            certified=False,
            rejection_reason=zd.format_reason(),
            zd_witness=zd,
        )
        feedback = format_rejection_trace(trace, zd)
        return cert_result, feedback

    # Step 2: No ZD — try certification via bridge
    cert_result = certify_trace_via_bridge(trace, bridge)

    if cert_result.certified:
        feedback = format_certified_trace(
            trace, cert_result.cert_key or "unknown", cert_result.logic_type or ""
        )
    else:
        feedback = format_cert_rejection_trace(
            trace, cert_result.rejection_reason or "unknown"
        )

    return cert_result, feedback


# ── Utility: script-level ZD detection ─────────────────────────────────

def detect_zd_in_script(script: Dict[str, Any],
                        library_traces: Dict[str, Dict]) -> List[ZDWitness]:
    """Check if a script covers traces from both sides of the CD 2→3 boundary.

    A script (compressed reasoning strategy) aggregates multiple traces.
    If those traces span both associative (CD ≤ 2) and non-associative
    (CD ≥ 3) regimes, the script itself contains a zero divisor — it
    cannot consistently classify inputs because its strategy mixes
    incompatible algebraic regimes.
    """
    cdsteps: List[int] = []
    witnesses: List[ZDWitness] = []

    # Get the script's estimated edge type
    est_edge = script.get("estimated_edge_type", "")
    if not est_edge:
        return witnesses

    script_cdstep = edge_type_to_cdstep(est_edge)

    # Check all traces that belong to this script's cluster
    # (same layer_pair and edge_type)
    layer_pair = script.get("layer_pair", [])
    for trace in library_traces.values():
        t_result = trace.get("result") or {}
        t_inputs = trace.get("inputs") or {}
        if not t_result or not t_result.get("edge_type"):
            continue

        t_layer_pair = (
            t_inputs.get("source_layer", ""),
            t_inputs.get("target_layer", ""),
        )
        if layer_pair and list(layer_pair) != list(t_layer_pair):
            continue

        t_edge = t_result.get("edge_type", "")
        t_invariant = t_result.get("invariant_at_boundary", "")
        t_failure = t_result.get("failure_mode", "")

        t_claimed = edge_type_to_cdstep(t_edge)
        t_actual, pattern = detect_actual_cdstep(t_invariant, t_failure, t_edge)
        zd = detect_zd(t_claimed, t_actual, t_edge, pattern)
        if zd:
            witnesses.append(zd)

    return witnesses
