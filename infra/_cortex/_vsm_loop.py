"""VSM Loop Orchestration Service — the Eigenstate oracle.

This module implements the Viable Systems Model loop that determines whether
a session trace is "garbage" or "data" by measuring convergence through the
S4→S3→S2→S3*→S1→S5 cycle.

Mirror of Generation.lean Section 12 (ViableSystem, free_is_viable) and
InstitutionalClosure.lean (closure_is_fixed_point).

GAP markers identify heuristics that will be replaced by Lean proofs as the
formalization catches up. See docs/vsm_loop_interface.md for the full design.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from infra._cortex._bridge import CortexBridge, NormCodeCortexBridge
from infra._cortex._eml_tree import EMLTree
from infra._cortex._types import CortexCertificate
from infra._cortex._wfc import (
    ToolOutput,
    can_coexist,
    friction_density,
)

# ── Constants ────────────────────────────────────────────────────────────

DEFAULT_MAX_ITERATIONS: int = 7
"""Max VSM cycles per block before declaring failure.

7 is the number of non-associative CD steps in the Split Octonion (e₄-e₇ →
4 steps of associator defect, plus the 3 pre-barrier steps). A block that
cannot stabilize within 7 cycles has exhausted its algebraic wiggle room.
"""

DEFAULT_BARRIER: int = 16
"""strut_weight² — the cost threshold for the CD 2→3 boundary.

GAP: This should be derived from FrictionLagrangian.lean's
`friction_barrier_across_cd23` theorem, not hardcoded.
"""


# ── Data Model ──────────────────────────────────────────────────────────

@dataclass
class ThinkingBlock:
    """A single thinking step from session data, fed into the VSM loop.

    This is the bridge between raw NCDS format and the LC type system.
    Each block represents one inference step in the session trace.

    Fields:
        flow_index: Hierarchical position in the NC flow space (e.g. "1.2.3").
        source: The NL content of the thinking block.
        coupling_signature: Optional coupling signature identifying the
            structural shape ("commutative", "non-commutative",
            "non-associative", "commutative-associative").
        tool_outcome: Optional ToolOutput from the actual tool call
            (S1 ground truth from the session).
        cert_bits: Optional certificate verification string
            (S3* artifact if present in the session).
    """
    flow_index: str
    source: str
    coupling_signature: Optional[str] = None
    tool_outcome: Optional[ToolOutput] = None
    cert_bits: Optional[str] = None


@dataclass
class VSMState:
    """Accumulated state across VSM loop iterations for one block.

    This is the **Eigenstate carrier** — it holds the current iteration's
    S4/S3/S2/S3*/S1 outputs and tracks S5 stability.

    Fields:
        block: The ThinkingBlock being processed.
        candidate_logic: The LogicType produced by S4 (lift_inference).
        contracted_tree: The EMLTree from S4's lift result.
        friction_cost: The S3 friction density cost of the candidate LogicType.
        resonance_ok: Whether S2's canCoexist check passed with previous block.
        cert_verified: Whether S3* independent verification passed.
        tool_matched: Whether S1's tool outcome cost ≤ barrier.
        iteration: How many VSM cycles this block required.
        stable: Whether S5 logic stability converged.
        prev_candidate_logic: LogicType from the previous iteration
            (for S5 stability comparison).
    """
    block: ThinkingBlock
    candidate_logic: Any = None          # LogicType (avoid circular type ref)
    contracted_tree: Optional[EMLTree] = None
    friction_cost: float = 0.0
    resonance_ok: bool = False
    cert_verified: bool = False
    tool_matched: bool = False
    iteration: int = 0
    stable: bool = False
    prev_candidate_logic: Any = None     # LogicType (avoid circular type ref)


@dataclass
class VSMLoopResult:
    """The verdict of running the VSM loop on a session trace.

    Fields:
        plan_id: Identifier for the session / plan being evaluated.
        converged: True if all blocks reached S5 stability.
        convergence_iterations: Total S4→S3→S2→S3*→S1→S5 cycles.
        cost_trajectory: Friction cost per block.
        barrier_crossed: True if any block's cost exceeded strut_weight².
        stable_type: The LogicType S5 settled on for the final block.
        alpha: Convergence confidence (0.0 - 1.0).
        failures: List of flow_index values that never converged.
    """
    plan_id: str
    converged: bool
    convergence_iterations: int = 0
    cost_trajectory: List[float] = field(default_factory=list)
    barrier_crossed: bool = False
    stable_type: Any = None              # Optional[LogicType]
    alpha: float = 1.0
    failures: List[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════

def run_vsm_loop(
    blocks: List[ThinkingBlock],
    bridge: NormCodeCortexBridge,
    max_iterations: int = DEFAULT_MAX_ITERATIONS,
    barrier: int = DEFAULT_BARRIER,
) -> VSMLoopResult:
    """Run the VSM loop over a list of thinking blocks.

    For each block, iterates the S4→S3→S2→S3*→S1→S5 cycle until either
    the LogicType stabilises (S5) or ``max_iterations`` is reached.

    Args:
        blocks: The thinking blocks to evaluate (one per session step).
        bridge: A NormCodeCortexBridge with state (lift_cache, certificates).
        max_iterations: Max VSM cycles per block (default 7).
        barrier: Cost threshold for the CD 2→3 boundary (default 16).

    Returns:
        A VSMLoopResult with convergence verdict and metrics.
    """
    # ── Empty trace: immediately converged ──
    if not blocks:
        return VSMLoopResult(
            plan_id="vsm_loop",
            converged=True,
            convergence_iterations=0,
            cost_trajectory=[],
            barrier_crossed=False,
            stable_type=None,
            alpha=1.0,
            failures=[],
        )

    total_iterations: int = 0
    cost_trajectory: List[float] = []
    barrier_crossed: bool = False
    prev_stable_type: Any = None   # LogicType from the previous block
    failures: List[str] = []

    for block in blocks:
        state = VSMState(block=block)

        while not state.stable and state.iteration < max_iterations:
            # ── S4: Generate candidate LogicType via bridge lift ──────────
            # GAP (issue #vsm-2): The bridge's lift_inference is deterministic
            # for identical inputs. The loop relies on the bridge's internal
            # generation mode (anti_coherent_pair inflation on ZD detection)
            # to produce a different LogicType on subsequent calls. For cases
            # without ZD, the loop converges in 1 iteration by definition.
            lift = bridge.core.lift_inference(
                flow_index=block.flow_index,
                concept_name=block.source,
                sequence_type="sequential",
                coupling_signature=block.coupling_signature,
                # GAP: trace_data not provided — structural LogicType
                # resolution via source/target layers not available from NCDS
            )

            state.candidate_logic = lift.logic_type
            state.contracted_tree = lift.eml_tree

            # ── S3: Compute friction cost ────────────────────────────────
            # GAP (issue #vsm-1): Uses friction_density on LogicType only.
            # The Lean version uses contracts_to_with_cost which computes
            # cost from the actual contraction path, not just the type.
            state.friction_cost = float(friction_density(lift.logic_type))
            if state.friction_cost > barrier:
                barrier_crossed = True

            # ── S2: Coordination — canCoexist with previous block ────────
            # GAP (issue #vsm-1): Uses Python can_coexist which is a
            # sector-membership check. The Lean Resonates inductive also
            # requires Tamari ancestor (contracts_to) between trees.
            if prev_stable_type is not None:
                state.resonance_ok = can_coexist(prev_stable_type, lift.logic_type)
            else:
                state.resonance_ok = True

            # If S2 fails and the bridge detected a ZD, the anti_coherent_pair
            # provides a new candidate for the next iteration.
            if not state.resonance_ok and lift.anti_coherent_pair is not None:
                # GAP (issue #vsm-2): Inflation gives us a different LogicType
                # to try on the next iteration. Currently this is implicit —
                # the bridge's next call to lift_inference with the same
                # inputs may produce a different result due to state changes
                # in the bridge's cached inflation. This is fragile.
                pass  # next iteration will attempt S4 again

            # ── S3*: Audit — verify certificate if present ──────────────
            # GAP (issue #vsm-3): cert_bits is a string heuristic.
            # The actual certificate verification happens on CortexCertificate.
            if block.cert_bits is not None and lift.certificate is not None:
                state.cert_verified = lift.certificate.verify()
            else:
                state.cert_verified = False

            # ── S1: Operations — tool outcome match ─────────────────────
            if block.tool_outcome is not None:
                state.tool_matched = block.tool_outcome.cost <= barrier
            else:
                state.tool_matched = False

            # ── S5: Identity — check LogicType stability ────────────────
            if (state.prev_candidate_logic is not None
                    and state.candidate_logic == state.prev_candidate_logic):
                state.stable = True
            else:
                state.prev_candidate_logic = state.candidate_logic
                state.iteration += 1

        # ── Per-block accounting ──────────────────────────────────────────
        total_iterations += state.iteration
        cost_trajectory.append(state.friction_cost)

        if state.stable:
            prev_stable_type = state.candidate_logic
        else:
            failures.append(block.flow_index)

    # ── Compute alpha ─────────────────────────────────────────────────────
    n = len(blocks)
    alpha = _compute_alpha(total_iterations, n, max_iterations, barrier_crossed)

    # ── Determine stable_type (last stable block's LogicType) ────────────
    stable_type = prev_stable_type

    return VSMLoopResult(
        plan_id="vsm_loop",
        converged=(len(failures) == 0),
        convergence_iterations=total_iterations,
        cost_trajectory=cost_trajectory,
        barrier_crossed=barrier_crossed,
        stable_type=stable_type,
        alpha=alpha,
        failures=failures,
    )


def ncds_to_blocks(ncds_text: str) -> List[ThinkingBlock]:
    """Parse NCDS text into a list of ThinkingBlocks.

    GAP (issue #vsm-5): This is a thin heuristic that extracts ``<-``
    (concept) lines as individual thinking blocks. The full NCDS grammar
    includes actions (``<=``), iterators (``<*``), conditionals (``<= if``),
    timing gates, and I/O markers — these are ignored by the current parser.

    The NCDS format is an indentation-based tree notation for NormCode
    Derivations. Each ``<- concept`` line represents a concept declaration
    at a specific depth in the derivation tree.

    Args:
        ncds_text: Raw NCDS text content.

    Returns:
        List of ThinkingBlocks, one per ``<-`` line, with sequential
        flow_index values.
    """
    blocks: List[ThinkingBlock] = []
    if not ncds_text or not ncds_text.strip():
        return blocks

    # GAP: Only extracts <- concept lines.
    # Does not parse:
    #   - <= actions (coupling_signature inference)
    #   - <* iterators (flow index hierarchy)
    #   - <= if conditionals (branching structure)
    #   - /: comments with cert: tags
    #   - :>(chat): I/O markers
    concept_pattern = re.compile(r'^\s*<-\s+(.+)$', re.MULTILINE)

    for idx, match in enumerate(concept_pattern.finditer(ncds_text)):
        concept_text = match.group(1).strip()
        block = ThinkingBlock(
            flow_index=str(idx),
            source=concept_text,
            # GAP: coupling_signature is None — not inferred from action text.
            # Future: examine subsequent <= lines to detect "merge"/"combine"
            # (commutative) vs "sequence"/"order" (non-commutative) patterns.
            coupling_signature=None,
            # GAP: tool_outcome is None — not inferred from action text.
            # Future: parse tool call results from the NCDS tree structure.
            tool_outcome=None,
            # GAP: cert_bits is None — not parsed from /: comments.
            # Future: look for /: cert: <key> lines.
            cert_bits=None,
        )
        blocks.append(block)

    return blocks


# ═══════════════════════════════════════════════════════════════════════
# Internal helpers
# ═══════════════════════════════════════════════════════════════════════

def _compute_alpha(
    total_iterations: int,
    n_blocks: int,
    max_iterations: int,
    barrier_crossed: bool,
) -> float:
    """Compute the convergence confidence alpha.

    GAP (issue #vsm-4): The ``0.5`` barrier penalty is a heuristic. The Lean
    ``free_is_viable`` theorem should supply the correct penalty based on the
    friction ratio Γ_k₂ / Γ_k₁ for the crossing blocks.

    Formula::
        alpha = 1.0 - (total_iterations / (n_blocks * max_iterations)) * penalty

    where ``penalty = 0.5 if barrier_crossed else 0.0``.
    """
    if n_blocks == 0:
        return 1.0

    penalty = 0.5 if barrier_crossed else 0.0
    raw = 1.0 - (total_iterations / (n_blocks * max_iterations)) * penalty
    return max(0.0, min(1.0, raw))
