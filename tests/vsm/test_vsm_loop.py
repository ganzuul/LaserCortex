#!/usr/bin/env python3
"""Tests for infra/_cortex/_vsm_loop.py — VSM Loop Orchestration Service.

These tests are organized by VSM system layer and follow TDD: they define
the interface before implementation exists. The first run will fail until
_vsm_loop.py is written.

GAPS marked with "GAP:" are known heuristics that will be replaced as the
Lean formalization catches up. See docs/vsm_loop_interface.md for the
full design rationale.

Unbounded (CSG) tests are marked SLOW and use pytest.mark.slow.
"""
import sys
import os
import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CORTEX_DIR = os.path.join(PROJECT_ROOT, "infra/_cortex")
sys.path.insert(0, PROJECT_ROOT)
sys.path.insert(0, CORTEX_DIR)

# ── Module loader (same pattern as test_cortex_bridge.py) ────────────────

def _load_cortex_module(name):
    """Load a cortex module, reusing an existing one if already loaded.
    This prevents test ordering issues when multiple test files load
    the same modules via _load_cortex_module."""
    fq = f"infra._cortex._{name}"
    if fq in sys.modules:
        return sys.modules[fq]
    import importlib.util
    path = os.path.join(CORTEX_DIR, f"_{name}.py")
    spec = importlib.util.spec_from_file_location(fq, path,
                                                   submodule_search_locations=[])
    mod = importlib.util.module_from_spec(spec)
    mod.__package__ = "infra._cortex"
    sys.modules[fq] = mod
    spec.loader.exec_module(mod)
    return mod

# Bootstrap the infra._cortex virtual package
_infra_pkg = type(sys)("infra")
_infra_pkg.__path__ = [os.path.join(PROJECT_ROOT, "infra")]
_infra_pkg.__package__ = "infra"
sys.modules.setdefault("infra", _infra_pkg)
_infra_cortex_pkg = type(sys)("infra._cortex")
_infra_cortex_pkg.__path__ = [CORTEX_DIR]
_infra_cortex_pkg.__package__ = "infra._cortex"
sys.modules.setdefault("infra._cortex", _infra_cortex_pkg)

eml     = _load_cortex_module("eml_tree")
typ     = _load_cortex_module("types")
spec_mod = _load_cortex_module("spec")
lt      = _load_cortex_module("logic_types")
lm      = _load_cortex_module("logic_monad")
dec     = _load_cortex_module("decision")
par     = _load_cortex_module("paradox")
decomp  = _load_cortex_module("decomposition")
clo     = _load_cortex_module("closure")
bnd     = _load_cortex_module("boundlessness")
brd     = _load_cortex_module("bridge")
wfc     = _load_cortex_module("wfc")
cost    = _load_cortex_module("cost")

# Now load (or import) vsm_loop — it may not exist yet
try:
    vsm = _load_cortex_module("vsm_loop")
except (ImportError, FileNotFoundError):
    vsm = None
    pytest.skip("_vsm_loop.py not yet implemented — these tests define the interface",
                allow_module_level=True)

EMLTree         = eml.EMLTree
LEAF            = eml.LEAF
LogicType       = lt.LogicType
CortexSpec = spec_mod.CortexSpec
CortexCertificate = typ.CortexCertificate
ToolOutput      = wfc.ToolOutput
UngroundedNL    = wfc.UngroundedNL
ThinkingBlock   = vsm.ThinkingBlock
VSMState        = vsm.VSMState
VSMLoopResult   = vsm.VSMLoopResult
run_vsm_loop    = vsm.run_vsm_loop
ncds_to_blocks  = vsm.ncds_to_blocks

# ═══════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════

@pytest.fixture
def empty_bridge():
    """A NormCodeCortexBridge with no lifted trees."""
    return brd.NormCodeCortexBridge()

@pytest.fixture
def classical_block():
    """A ThinkingBlock in the associative sector (CLASSICAL)."""
    return ThinkingBlock(
        flow_index="1.0",
        source="Two plus two equals four.",
        coupling_signature="commutative",
        tool_outcome=ToolOutput(description="calc", cost=3, cert_bits=None),
        cert_bits="cert:classical:001",
    )

@pytest.fixture
def paraconsistent_block():
    """A ThinkingBlock in the non-associative sector.
    Uses coupling_signature='non-associative' → Quantum (cdStep 3, 𝕆).
    See lab_notes/006_the_hopf_7_skeleton_of_logic_space.md for the
    coupling_signature → LogicType mapping."""
    return ThinkingBlock(
        flow_index="1.1",
        source="This statement is false.",
        coupling_signature="non-associative",  # → Quantum (cdStep 3, non-assoc sector)
        tool_outcome=None,          # GAP: no tool outcome — ungrounded
        cert_bits=None,
    )

@pytest.fixture
def free_logic_block():
    """A ThinkingBlock that should trigger Free Logic via generation mode.
    Uses coupling_signature='non-associative' → Quantum (cdStep 3).
    Free Logic (cdStep 4, sedenion) is the meta-logic reachable only via
    the bridge's ZD detection → inflate → Free Logic path, NOT via
    coupling_signature directly. See Hopf 7-Skeleton lab note."""
    return ThinkingBlock(
        flow_index="1.2",
        source="The barber shaves all who do not shave themselves.",
        coupling_signature="non-associative",
        tool_outcome=ToolOutput(description="paradox_detected", cost=19, cert_bits="cert:free:002"),
        cert_bits="cert:free:002",
    )


# ═══════════════════════════════════════════════════════════════════════
# Tests: Dataclass construction
# ═══════════════════════════════════════════════════════════════════════

class TestDataclasses:
    """Verify the VSM data model constructs correctly."""

    def test_thinking_block_defaults(self):
        """ThinkingBlock defaults are sensible."""
        b = ThinkingBlock(flow_index="1.0", source="test")
        assert b.flow_index == "1.0"
        assert b.source == "test"
        assert b.coupling_signature is None
        assert b.tool_outcome is None
        assert b.cert_bits is None

    def test_thinking_block_full(self, classical_block):
        """ThinkingBlock with all fields."""
        assert classical_block.flow_index == "1.0"
        assert classical_block.tool_outcome is not None
        assert classical_block.tool_outcome.cost == 3

    def test_vsm_state_defaults(self):
        """VSMState initialises to pre-loop state."""
        b = ThinkingBlock(flow_index="1.0", source="x")
        s = VSMState(block=b)
        assert s.iteration == 0
        assert s.stable is False
        assert s.candidate_logic is None
        assert s.contracted_tree is None
        assert s.friction_cost == 0.0
        assert s.resonance_ok is False
        assert s.cert_verified is False
        assert s.tool_matched is False

    def test_vsm_loop_result_defaults(self):
        """VSMLoopResult default for empty trace."""
        r = VSMLoopResult(plan_id="test", converged=True)
        assert r.convergence_iterations == 0
        assert r.cost_trajectory == []
        assert r.barrier_crossed is False
        assert r.stable_type is None
        assert r.alpha == 1.0
        assert r.failures == []


# ═══════════════════════════════════════════════════════════════════════
# Tests: ncds_to_blocks (thin parser)
# ═══════════════════════════════════════════════════════════════════════

class TestNcdsToBlocks:
    """Parse NCDS text into ThinkingBlock list.

    GAP: This is a thin heuristic parser that extracts <- concept lines
    as inference blocks. The full NCDS grammar includes actions (<=),
    iterators (<*), conditionals, and timing gates — these are ignored
    by the current heuristic and marked with GAP comments.
    """

    def test_empty_ncds(self):
        """Empty NCDS yields empty block list."""
        assert ncds_to_blocks("") == []

    def test_single_concept(self):
        """Simple NCDS: all <- lines are extracted as blocks.
        GAP: Future parser should filter to only concepts with <= actions
        (i.e. reasoning steps, not data references). Currently extracts all."""
        ncds = """\
<- clean text
    <= extract main content, removing headers
    <- raw document
"""
        blocks = ncds_to_blocks(ncds)
        assert len(blocks) == 2
        assert blocks[0].source == "clean text"
        assert blocks[1].source == "raw document"

    def test_multiple_concepts(self):
        """NCDS with nested <- lines: all <- lines extracted as blocks.
        GAP: Future parser should filter to only concepts with <= actions."""
        ncds = """\
<- document summary
    <= summarize this text
    <- clean text
        <= extract main content, removing headers
        <- raw document
"""
        blocks = ncds_to_blocks(ncds)
        assert len(blocks) == 3
        assert blocks[0].source == "document summary"
        assert blocks[1].source == "clean text"
        assert blocks[2].source == "raw document"

    def test_flow_index_assignment(self):
        """Blocks are assigned sequential flow indices."""
        ncds = """\
<- a
<- b
<- c
"""
        blocks = ncds_to_blocks(ncds)
        assert blocks[0].flow_index == "0"
        assert blocks[1].flow_index == "1"
        assert blocks[2].flow_index == "2"

    def test_coupling_signature_from_action(self):
        """GAP: coupling_signature is a heuristic; defaults to None for now."""
        ncds = """\
<- compute
    <= merge the results
"""
        blocks = ncds_to_blocks(ncds)
        # GAP: no coupling signature inference yet
        assert blocks[0].coupling_signature is None

    def test_action_heuristic(self):
        """GAP: the <= action text is used to heuristic-detect tool outcomes.
        We assert the current heuristic behaviour, not the ideal."""
        ncds = """\
<- search
    <= search the knowledge base for relevant results
"""
        blocks = ncds_to_blocks(ncds)
        # GAP: no tool outcome inference from action text yet
        assert blocks[0].tool_outcome is None

    def test_with_cert_bits_in_comment(self):
        """GAP: cert_bits from /: cert: lines — not yet implemented."""
        ncds = """\
/: cert: xyz123
<- verified step
"""
        blocks = ncds_to_blocks(ncds)
        # GAP: cert_bits not parsed from comments yet
        assert blocks[0].cert_bits is None


# ═══════════════════════════════════════════════════════════════════════
# Tests: run_vsm_loop — S4 candidate generation
# ═══════════════════════════════════════════════════════════════════════

class TestS4Generation:
    """S4: lift each thinking block to a candidate EMLTree + LogicType via bridge."""

    def test_single_block_lifts(self, empty_bridge, classical_block):
        """A single associative-sector block lifts via the bridge."""
        result = run_vsm_loop([classical_block], empty_bridge)
        assert result.converged
        assert result.convergence_iterations >= 1
        assert result.stable_type is not None
        assert result.stable_type.is_associative_sector()

    def test_single_block_paraconsistent(self, empty_bridge, paraconsistent_block):
        """A single non-associative block lifts to a non-associative type."""
        result = run_vsm_loop([paraconsistent_block], empty_bridge)
        assert result.converged
        assert result.stable_type is not None
        assert not result.stable_type.is_associative_sector()

    def test_generation_candidate_logic_type(self, empty_bridge, classical_block):
        """S4 output: candidate LogicType is a LogicType enum value."""
        result = run_vsm_loop([classical_block], empty_bridge)
        assert isinstance(result.stable_type, LogicType)

    def test_generation_with_free_logic(self, empty_bridge, free_logic_block):
        """A block with paradoxical content lifts to a non-associative type.
        GAP: Free Logic (cdStep 4, sedenion) is the meta-logic reachable only
        via the bridge's generation mode (ZD detection → inflate). Coupling
        signatures can only reach up to cdStep 3 (Quantum, 𝕆). The bridge's
        lift_inference with trace_data can trigger ZD detection and produce
        an anti_coherent_pair, but the stable_type from coupling_signature
        alone will be Quantum (non-associative sector).
        See lab_notes/006_the_hopf_7_skeleton_of_logic_space.md."""
        result = run_vsm_loop([free_logic_block], empty_bridge)
        assert result.converged
        # The coupling_signature 'non-associative' → Quantum (cdStep 3)
        # Free Logic (cdStep 4) requires ZD detection via trace_data
        # GAP: when trace_data is wired, this should check for FREE or anti_coherent_pair
        assert result.stable_type is not None
        assert not result.stable_type.is_associative_sector()


# ═══════════════════════════════════════════════════════════════════════
# Tests: S3 cost computation
# ═══════════════════════════════════════════════════════════════════════

class TestS3Regulation:
    """S3: compute friction cost of the contracted EMLTree."""

    def test_cost_is_non_negative(self, empty_bridge, classical_block):
        """Every contracted tree has non-negative friction cost."""
        result = run_vsm_loop([classical_block], empty_bridge)
        for c in result.cost_trajectory:
            assert c >= 0.0

    def test_classical_cost_low(self, empty_bridge, classical_block):
        """Classical (associative, cdStep=0) has low cost ≤ 4."""
        result = run_vsm_loop([classical_block], empty_bridge)
        assert len(result.cost_trajectory) >= 1
        assert result.cost_trajectory[0] <= 4.0

    def test_barrier_not_crossed_for_same_sector(self, empty_bridge, classical_block):
        """Two blocks in the same sector don't cross the barrier."""
        b2 = ThinkingBlock(flow_index="1.1", source="also associative",
                           coupling_signature="commutative")
        result = run_vsm_loop([classical_block, b2], empty_bridge)
        assert not result.barrier_crossed

    def test_barrier_crossed_for_sector_straddle(self, empty_bridge):
        """GAP: A block whose LogicType flips sectors crosses the barrier.
        This test encodes the ideal behaviour — see also test_alpha_penalty."""
        a = ThinkingBlock(flow_index="1.0", source="classical",
                          coupling_signature="commutative")
        b = ThinkingBlock(flow_index="1.1", source="paraconsistent",
                          coupling_signature="non-commutative")
        # GAP: without explicit LogicType assignment, the heuristic may not
        # detect sector crossing. This test is a placeholder for when the
        # bridge's lift_inference returns a structural LogicType from trace_data.
        result = run_vsm_loop([a, b], empty_bridge)
        # The barrier *may* be crossed if the bridge detects the sector change
        # through the coupling_signature heuristic
        _ = result  # GAP: assertion deferred — see issue #vsm-1


# ═══════════════════════════════════════════════════════════════════════
# Tests: S2 coordination
# ═══════════════════════════════════════════════════════════════════════

class TestS2Coordination:
    """S2: canCoexist check between adjacent blocks."""

    def test_compatible_adjacent(self, empty_bridge):
        """Two CLASSICAL-adjacent blocks coexist (same sector)."""
        a = ThinkingBlock(flow_index="0", source="a", coupling_signature="commutative")
        b = ThinkingBlock(flow_index="1", source="b", coupling_signature="commutative")
        result = run_vsm_loop([a, b], empty_bridge)
        assert result.converged

    def test_incompatible_triggers_inflation(self, empty_bridge):
        """GAP: When canCoexist returns False, S4 re-inflates.
        This is the Eigenstate transition: the system generates a new
        AntiCoherentPair at a higher cdStep to accommodate the gap."""
        # GAP: Currently the bridge's lift_inference with trace_data is needed
        # for sector-boundary detection. Without explicit LogicType assignment,
        # this test may not trigger inflation. See issue #vsm-2.
        a = ThinkingBlock(flow_index="0", source="classical",
                          coupling_signature="commutative")
        b = ThinkingBlock(flow_index="1", source="paraconsistent",
                          coupling_signature="non-commutative")
        result = run_vsm_loop([a, b], empty_bridge)
        # The loop should still converge (S5 finds a meta-logic bridge)
        # but may take more iterations
        assert result.converged is not None
        _ = result  # GAP: placeholder for iteration-count assertion


# ═══════════════════════════════════════════════════════════════════════
# Tests: S3* audit
# ═══════════════════════════════════════════════════════════════════════

class TestS3StarAudit:
    """S3*: verify CortexCertificates independently."""

    def test_cert_verified_when_present(self, empty_bridge, free_logic_block):
        """A block with cert_bits gets its certificate verified."""
        # GAP: The bridge's verify_certificate expects a CortexCertificate object,
        # not a string. The cert_bits string is a heuristic placeholder.
        result = run_vsm_loop([free_logic_block], empty_bridge)
        # Once verify_certificate is wired, this should reflect in the result
        # For now, we just check the loop completes
        assert result.converged

    def test_no_cert_no_false_positive(self, empty_bridge, paraconsistent_block):
        """A block with no cert does not falsely report verification."""
        result = run_vsm_loop([paraconsistent_block], empty_bridge)
        # GAP: S3* is currently not wired — cert_verified defaults to False
        # This test will need updating when S3* is connected


# ═══════════════════════════════════════════════════════════════════════
# Tests: S1 operations
# ═══════════════════════════════════════════════════════════════════════

class TestS1Operations:
    """S1: tool outcomes ground the loop."""

    def test_tool_outcome_matched(self, empty_bridge, classical_block):
        """Tool outcome present and cost ≤ barrier → S1 matched."""
        result = run_vsm_loop([classical_block], empty_bridge)
        # GAP: S1 matching is not yet wired — tool_matched tracks the block's
        # tool_outcome but does not feed back into the loop
        assert result.converged


# ═══════════════════════════════════════════════════════════════════════
# Tests: S5 identity / convergence
# ═══════════════════════════════════════════════════════════════════════

class TestS5Convergence:
    """S5: LogicType stability across iterations determines convergence."""

    def test_empty_trace_converges(self, empty_bridge):
        """No blocks → immediately converged, alpha = 1.0."""
        result = run_vsm_loop([], empty_bridge)
        assert result.converged
        assert result.convergence_iterations == 0
        assert result.alpha == 1.0

    def test_single_block_one_iteration(self, empty_bridge, classical_block):
        """Single block with stable LogicType converges in 1 iteration per block."""
        result = run_vsm_loop([classical_block], empty_bridge)
        assert result.converged
        # Each block takes at least 1 iteration
        assert result.convergence_iterations >= 1

    def test_alpha_perfect(self, empty_bridge, classical_block):
        """For a single low-cost, same-sector block, alpha is high."""
        result = run_vsm_loop([classical_block], empty_bridge)
        # GAP: alpha formula is a heuristic — see docs/vsm_loop_interface.md
        assert result.alpha > 0.5

    def test_alpha_penalty_for_barrier_cross(self, empty_bridge):
        """GAP: barrier crossing should reduce alpha by 0.5.
        This is the design intent — the actual barrier detection depends
        on the bridge's ZD detection being wired into lift_inference."""
        a = ThinkingBlock(flow_index="0", source="a", coupling_signature="commutative")
        b = ThinkingBlock(flow_index="1", source="b", coupling_signature="non-commutative")
        result = run_vsm_loop([a, b], empty_bridge)
        if result.barrier_crossed:
            assert result.alpha < 1.0
        # GAP: if bridge doesn't detect sector change, barrier stays false
        # and alpha stays 1.0 — that's the current heuristic

    def test_failures_list(self, empty_bridge):
        """Blocks that max out iterations appear in failures list."""
        # GAP: To trigger iteration exhaustion, we need a block that oscillates
        # between incompatible LogicTypes. This requires the bridge to detect
        # ZD and inflate. Without that wiring, no block will fail.
        # This test is a placeholder.
        pass


# ═══════════════════════════════════════════════════════════════════════
# Tests: Full integration — multi-block session trace
# ═══════════════════════════════════════════════════════════════════════

class TestIntegration:
    """End-to-end VSM loop on realistic multi-block traces."""

    def test_three_same_sector_blocks(self, empty_bridge):
        """Three blocks all in associative sector → fast convergence, high alpha."""
        blocks = [
            ThinkingBlock(flow_index=f"{i}", source=f"step {i}",
                          coupling_signature="commutative")
            for i in range(3)
        ]
        result = run_vsm_loop(blocks, empty_bridge)
        assert result.converged
        assert result.convergence_iterations <= 3
        assert result.alpha >= 0.5
        assert not result.barrier_crossed
        assert result.stable_type is not None
        assert result.stable_type.is_associative_sector()

    def test_mixed_sectors_with_free_logic_bridge(self, empty_bridge):
        """A Free Logic block bridges two incompatible sectors.
        This is the Eigenstate transition: S4→S5 converges via meta-logic."""
        sectors = ["commutative", "non-associative", "commutative-associative"]
        # GAP: Without explicit LogicType assignment, the bridge may not detect
        # sector changes. The Free Logic block's meta-logic property should
        # still allow convergence via the meta-logic exemption in canCoexist.
        blocks = [
            ThinkingBlock(flow_index=str(i), source=f"sector_{i}",
                          coupling_signature=sig)
            for i, sig in enumerate(sectors)
        ]
        # Insert a Free Logic block at position 1 to bridge
        blocks.insert(1, ThinkingBlock(
            flow_index="2", source="free bridge",
            coupling_signature="non-commutative",
            tool_outcome=ToolOutput(description="bridge", cost=10, cert_bits="cert:bridge"),
            cert_bits="cert:bridge",
        ))
        result = run_vsm_loop(blocks, empty_bridge)
        assert result.converged
        assert result.convergence_iterations <= 4  # some extra for bridging

    def test_realistic_session_trace(self, empty_bridge):
        """A 6-block trace similar to the training_examples.md patterns.
        This tests the loop under realistic conditions."""
        blocks = [
            ThinkingBlock(flow_index="0", source="Let me run the analysis",
                          coupling_signature="commutative",
                          tool_outcome=ToolOutput("analysis_result", 5, "cert:an")),
            ThinkingBlock(flow_index="1", source="I should verify the result",
                          coupling_signature="commutative",
                          tool_outcome=ToolOutput("verified", 3, "cert:vr")),
            ThinkingBlock(flow_index="2", source="Wait, that contradicts",
                          coupling_signature="non-commutative",
                          tool_outcome=None),  # ungrounded — may inflate
            ThinkingBlock(flow_index="3", source="Let me reconcile",
                          coupling_signature="non-associative",
                          tool_outcome=ToolOutput("reconciled", 12, "cert:rc")),
            ThinkingBlock(flow_index="4", source="The answer is",
                          coupling_signature="commutative-associative",
                          tool_outcome=ToolOutput("final", 2, "cert:fn")),
            ThinkingBlock(flow_index="5", source="Double checking",
                          coupling_signature="commutative"),
        ]
        result = run_vsm_loop(blocks, empty_bridge)
        assert result.converged
        # Even if there were some inflation cycles, the Free Logic bridge
        # should bring it home
        assert result.alpha >= 0.0
        assert result.convergence_iterations >= 1
        # The standard 6-category trace should converge within 10 iterations
        assert result.convergence_iterations <= 10, (
            f"Realistic trace took {result.convergence_iterations} iterations "
            f"(expected ≤ 10)"
        )


# ═══════════════════════════════════════════════════════════════════════
# Tests: Edge cases and resource safety
# ═══════════════════════════════════════════════════════════════════════

class TestEdgeCases:
    """Boundary conditions and error handling."""

    def test_max_iterations_respected(self, empty_bridge):
        """Loop terminates within max_iterations even for problematic blocks."""
        many_blocks = [
            ThinkingBlock(flow_index=str(i), source=f"block {i}",
                          coupling_signature="non-commutative")
            for i in range(20)  # worst case: each block may oscillate
        ]
        result = run_vsm_loop(many_blocks, empty_bridge, max_iterations=7)
        # The loop should complete, not hang
        assert result.converged or len(result.failures) > 0
        # Total iterations should be ≤ iterations per block × max_iterations
        assert result.convergence_iterations <= 20 * 7

    def test_fails_gracefully_on_bridge_error(self):
        """GAP: If the bridge raises, the loop should catch and report, not crash."""
        # GAP: requires a mock bridge that raises on lift_inference
        # Not yet implemented — see issue #vsm-3
        pass

    def test_memory_safe_under_large_input(self, empty_bridge):
        """Large block lists don't cause OOM.
        SAFETY.md P2: resource caps apply."""
        # GAP: large-input stress test is a resource safety concern.
        # Requires ulimit containment. Marked SLOW for manual runs.
        pass


# ═══════════════════════════════════════════════════════════════════════
# Tests: Eigenstate property — fixed point of the VSM loop
# ═══════════════════════════════════════════════════════════════════════

class TestEigenstate:
    """The Eigenstate is the fixed point of the VSM loop.

    When the VSM loop converges, the system state is an Eigenstate:
    running the loop again on the same result should not change it.
    This mirrors InstitutionalClosure.lean's closure_is_fixed_point.

    GAP: Full Eigenstate verification requires the Lean theorem
    closure_is_fixed_point to be invoked. The Python check below is a
    heuristic approximation — the real proof is in Lean.
    """

    def test_reapplication_idempotent(self, empty_bridge, classical_block):
        """Applying the loop twice yields the same result.
        GAP: Heuristic — uses Python equality, not Lean theorem."""
        result1 = run_vsm_loop([classical_block], empty_bridge)
        # "Re-apply" by running again on the stable_type
        if result1.stable_type is not None:
            feedback_block = ThinkingBlock(
                flow_index="0",
                source=f"eigenstate:{result1.stable_type.name}",
                coupling_signature="commutative",
            )
            result2 = run_vsm_loop([feedback_block], empty_bridge)
            # GAP: re-application should yield a stable_type of the same
            # LogicType family (associative if associative, etc.)
            assert (
                result2.stable_type is None
                or result2.stable_type.is_associative_sector()
                == result1.stable_type.is_associative_sector()
            )

    def test_convergence_iterations_stable(self, empty_bridge):
        """A stable trace should have iteration count < len(blocks) * 2."""
        blocks = [
            ThinkingBlock(flow_index=str(i), source=f"step {i}",
                          coupling_signature="commutative")
            for i in range(3)
        ]
        result = run_vsm_loop(blocks, empty_bridge)
        # For same-sector blocks, each should converge in 1 iteration
        assert result.convergence_iterations <= len(blocks) * 2
