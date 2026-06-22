#!/usr/bin/env python3
"""
Run the certification loop on a test set.

This is the modest self-improvement loop MVP:
  1. Load traces from a test set (or the reasoning library)
  2. For each trace: detect zero divisors, certify via CortexBridge
  3. Write rejection/confirmation feedback back to the reasoning library
  4. Print a summary report

The zero divisor is the formal reason for rejection: when incompatible
types are put in partial order across the CD 2→3 boundary, the
associator defect activates and the friction barrier (strut_weight²=16)
makes contraction impossible. The Lean theorem friction_barrier_across_cd23
is the proof term the rejection witness carries.

Usage:
    python scripts/run_certification_loop.py [--test-set FILE] [--library FILE]

Options:
    --test-set FILE   Curated test set JSON (default: scripts/test_certification_loop.json)
    --library FILE    Reasoning library JSON for feedback (default: .open-notebook/reasoning_library.json)
    --dry-run         Don't write feedback to the library, just report
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
from typing import Any, Dict, List, Optional, Tuple

# ── Path setup ─────────────────────────────────────────────────────────
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

from scripts.certification_loop import (
    ZDWitness,
    CertificationResult,
    detect_zd,
    detect_actual_cdstep,
    edge_type_to_cdstep,
    format_rejection_trace,
    format_cert_rejection_trace,
    format_certified_trace,
    certify_trace_via_bridge,
    process_trace,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


# ── Colors for terminal output ─────────────────────────────────────────

class C:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    END = "\033[0m"


# ── Loaders ────────────────────────────────────────────────────────────

def load_test_set(path: str) -> List[Dict[str, Any]]:
    """Load traces from a curated test set JSON file."""
    with open(path) as f:
        data = json.load(f)
    traces = data.get("traces", [])
    logger.info(f"Loaded {len(traces)} traces from {path}")
    return traces


def load_library(path: str) -> Dict[str, Any]:
    """Load the reasoning library JSON."""
    if not os.path.exists(path):
        logger.warning(f"Library file {path} not found — feedback will be printed only")
        return {"version": 2, "scripts": {}, "hardcoded": [], "traces": {}, "saved_at": time.time()}
    with open(path) as f:
        return json.load(f)


def save_library(path: str, library: Dict[str, Any]) -> None:
    """Save the reasoning library JSON with updated traces."""
    library["saved_at"] = time.time()
    with open(path, "w") as f:
        json.dump(library, f, indent=2, ensure_ascii=False)
    logger.info(f"Saved library to {path}")


# ── Report ─────────────────────────────────────────────────────────────

def print_report(
    results: List[Tuple[Dict, CertificationResult, Optional[Dict]]],
    zd_witnesses: List[ZDWitness],
) -> None:
    """Print a summary report of the certification loop."""
    certified = [(t, r, f) for t, r, f in results if r.certified]
    zd_rejected = [(t, r, f) for t, r, f in results if r.zd_witness is not None]
    other_rejected = [
        (t, r, f) for t, r, f in results
        if not r.certified and r.zd_witness is None
    ]

    print()
    print(f"{C.BOLD}{'═' * 72}{C.END}")
    print(f"{C.BOLD}  CERTIFICATION LOOP — SUMMARY REPORT{C.END}")
    print(f"{C.BOLD}{'═' * 72}{C.END}")
    print()

    # Summary counts
    total = len(results)
    print(f"  Total traces processed: {total}")
    print(f"  {C.GREEN}Certified:              {len(certified)}{C.END}")
    print(f"  {C.RED}ZD rejected:            {len(zd_rejected)}{C.END}")
    print(f"  {C.YELLOW}Other rejected:         {len(other_rejected)}{C.END}")
    print()

    # Certified traces
    if certified:
        print(f"{C.GREEN}{C.BOLD}  CERTIFIED{C.END}")
        print(f"  {'─' * 68}")
        for trace, result, feedback in certified:
            pair = trace.get("pair_key", "?")[:50]
            edge = (trace.get("result") or {}).get("edge_type", "?")
            logic = result.logic_type or "?"
            print(f"  {C.GREEN}✓{C.END} {pair:50s} [{edge:14s}] → {logic}")
        print()

    # ZD rejections
    if zd_rejected:
        print(f"{C.RED}{C.BOLD}  ZERO DIVISOR REJECTIONS{C.END}")
        print(f"  {'─' * 68}")
        for trace, result, feedback in zd_rejected:
            pair = trace.get("pair_key", "?")[:50]
            w = result.zd_witness
            if w is None:
                continue
            edge = w.claimed_edge_type
            print(f"  {C.RED}✗{C.END} {pair:50s} [{edge:14s}]")
            print(f"      {C.CYAN}Boundary:{C.END} {w.boundary}")
            print(f"      {C.CYAN}Claimed CD:{C.END} {w.claimed_cdstep} → {C.CYAN}Actual CD:{C.END} {w.actual_cdstep}")
            print(f"      {C.CYAN}Barrier:{C.END}   strut_weight² = {w.strut_weight_sq}  (friction ratio = {w.friction_ratio})")
            print(f"      {C.CYAN}Pattern:{C.END}   '{w.matched_pattern}'")
            print(f"      {C.CYAN}Proof:{C.END}     {w.barrier_theorem}")
            print()

    # Other rejections
    if other_rejected:
        print(f"{C.YELLOW}{C.BOLD}  OTHER REJECTIONS{C.END}")
        print(f"  {'─' * 68}")
        for trace, result, feedback in other_rejected:
            pair = trace.get("pair_key", "?")[:50]
            reason = (result.rejection_reason or "?")[:60]
            print(f"  {C.YELLOW}✗{C.END} {pair:50s} — {reason}")
        print()

    # Expected vs actual comparison (if test set has _expected field)
    expected_matches = 0
    expected_total = 0
    for trace, result, feedback in results:
        expected = trace.get("_expected")
        if expected:
            expected_total += 1
            actual = (
                "CERTIFY" if result.certified
                else "ZD_REJECT" if result.zd_witness
                else "OTHER_REJECT"
            )
            if actual == expected or (expected == "CERTIFY" and actual == "OTHER_REJECT"):
                # CERTIFY expected but got OTHER_REJECT is still a valid
                # certification attempt (ZD check passed, bridge may have issues)
                if actual == "CERTIFY":
                    expected_matches += 1
            if actual == expected:
                expected_matches += 1 if actual != "CERTIFY" else 0
                if actual == "ZD_REJECT":
                    expected_matches += 1

    # Simpler expected match logic
    expected_matches = 0
    for trace, result, feedback in results:
        expected = trace.get("_expected")
        if not expected:
            continue
        if expected == "CERTIFY" and result.certified:
            expected_matches += 1
        elif expected == "ZD_REJECT" and result.zd_witness is not None:
            expected_matches += 1

    if expected_total > 0:
        pct = (expected_matches / expected_total) * 100
        color = C.GREEN if pct == 100 else C.YELLOW if pct >= 80 else C.RED
        print(f"  {C.BOLD}Expected match rate:{C.END} {color}{expected_matches}/{expected_total} ({pct:.0f}%){C.END}")
        print()

    # Feedback traces
    feedback_count = sum(1 for _, _, f in results if f is not None)
    print(f"  Feedback traces generated: {feedback_count}")
    print()
    print(f"{C.BOLD}{'═' * 72}{C.END}")


# ── Main loop ──────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Run the certification loop")
    parser.add_argument(
        "--test-set",
        default=os.path.join(os.path.dirname(__file__), "test_certification_loop.json"),
        help="Path to curated test set JSON",
    )
    parser.add_argument(
        "--library",
        default=os.path.join(_PROJECT_ROOT, ".open-notebook", "reasoning_library.json"),
        help="Path to reasoning library JSON for feedback",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Don't write feedback to the library, just report",
    )
    args = parser.parse_args()

    # Load test set
    traces = load_test_set(args.test_set)

    # Load library
    library = load_library(args.library)
    library_traces = library.get("traces", {})
    if not isinstance(library_traces, dict):
        library_traces = {}

    # Initialize bridge (shared across all traces)
    bridge = None
    try:
        from infra._cortex._bridge import NormCodeCortexBridge
        bridge = NormCodeCortexBridge()
        logger.info("CortexBridge initialized")
    except Exception as e:
        logger.warning(f"Could not initialize CortexBridge: {e} — ZD detection only")

    # Process each trace
    results: List[Tuple[Dict, CertificationResult, Optional[Dict]]] = []
    zd_witnesses: List[ZDWitness] = []
    feedback_traces: List[Dict] = []

    for i, trace in enumerate(traces):
        pair_key = trace.get("pair_key", f"trace_{i}")
        logger.info(f"Processing [{i+1}/{len(traces)}] {pair_key}")

        cert_result, feedback = process_trace(trace, bridge)
        results.append((trace, cert_result, feedback))

        if cert_result.zd_witness:
            zd_witnesses.append(cert_result.zd_witness)
            logger.info(f"  → ZD REJECTED: {cert_result.zd_witness.boundary}")
        elif cert_result.certified:
            logger.info(f"  → CERTIFIED: {cert_result.logic_type}")
        else:
            logger.info(f"  → REJECTED: {cert_result.rejection_reason}")

        if feedback is not None:
            feedback_traces.append(feedback)

    # Write feedback to library
    if not args.dry_run and feedback_traces:
        for ft in feedback_traces:
            library_traces[ft["pair_key"]] = ft
        library["traces"] = library_traces
        save_library(args.library, library)
        logger.info(f"Wrote {len(feedback_traces)} feedback traces to library")
    elif args.dry_run:
        logger.info(f"Dry run — {len(feedback_traces)} feedback traces not written")

    # Print report
    print_report(results, zd_witnesses)

    # Save ZD witnesses as a separate file for audit
    if zd_witnesses:
        zd_path = os.path.join(_PROJECT_ROOT, "results", "zd_witnesses.json")
        os.makedirs(os.path.dirname(zd_path), exist_ok=True)
        with open(zd_path, "w") as f:
            json.dump([w.to_dict() for w in zd_witnesses], f, indent=2)
        logger.info(f"Saved {len(zd_witnesses)} ZD witnesses to {zd_path}")


if __name__ == "__main__":
    main()
