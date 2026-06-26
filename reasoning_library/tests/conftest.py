"""Shared fixtures for reasoning library tests."""

import sys
from pathlib import Path

import pytest

# Ensure the reasoning_library package is importable
REASONING_LIB = Path(__file__).parent.parent
if str(REASONING_LIB) not in sys.path:
    sys.path.insert(0, str(REASONING_LIB))

from reasoning_library.models import SessionReasoningTrace, ScriptMatch
from reasoning_library.embedder import cosine_similarity


FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture
def fixture_path():
    """Path to the fixtures directory."""
    return FIXTURES_DIR


@pytest.fixture
def session_short_path(fixture_path):
    return fixture_path / "session_short.md"


@pytest.fixture
def session_minimal_path(fixture_path):
    return fixture_path / "session_minimal.md"


@pytest.fixture
def session_weird_path(fixture_path):
    return fixture_path / "session_weird.md"


@pytest.fixture
def traces_known_path(fixture_path):
    return fixture_path / "traces_known.jsonl"


@pytest.fixture
def sample_traces_with_embeddings():
    """5 traces with known 10-dim embeddings for clustering tests."""
    traces = [
        SessionReasoningTrace(
            session_id="s1", session_file="/tmp/s.md", session_title="Test",
            thinking_block_index=0, thinking_block="Debug Docker memory",
            intent_category="docker_lifecycle", domain_tags=["Docker", "memory"],
            tools_used=["read", "bash"], embedding=[0.9, 0.1, 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        ),
        SessionReasoningTrace(
            session_id="s1", session_file="/tmp/s.md", session_title="Test",
            thinking_block_index=1, thinking_block="Tuning Docker compose",
            intent_category="docker_lifecycle", domain_tags=["Docker", "memory"],
            tools_used=["bash"], embedding=[0.85, 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        ),
        SessionReasoningTrace(
            session_id="s2", session_file="/tmp/s.md", session_title="Test",
            thinking_block_index=2, thinking_block="Writing a Python script",
            intent_category="script_development", domain_tags=["Python"],
            tools_used=["edit", "write"], embedding=[0.1, 0.8, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        ),
        SessionReasoningTrace(
            session_id="s2", session_file="/tmp/s.md", session_title="Test",
            thinking_block_index=3, thinking_block="Implementing a pipeline script",
            intent_category="script_development", domain_tags=["Python", "pipeline"],
            tools_used=["bash", "edit"], embedding=[0.15, 0.75, 0.45, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        ),
        SessionReasoningTrace(
            session_id="s3", session_file="/tmp/s.md", session_title="Test",
            thinking_block_index=4, thinking_block="Refactoring Lean theorem module",
            intent_category="module_refactoring", domain_tags=["Lean", "theorem"],
            tools_used=["read", "edit", "grep"], embedding=[0.92, 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        ),
    ]
    return traces


@pytest.fixture
def traces_no_embeddings():
    """Traces without embeddings (for testing empty-embedding handling)."""
    return [
        SessionReasoningTrace(
            session_id="s1", session_file="/tmp/s.md", session_title="Test",
            thinking_block_index=0, thinking_block="No embedding here",
            intent_category="general_problem_solving",
            embedding=None,
        ),
    ]


@pytest.fixture
def mock_35b_response():
    """A well-formed mock response from the 35B model."""
    return (
        "=== PRIMING ===\n"
        "When debugging Docker memory: check container limits and swap settings.\n\n"
        "=== RUNBOOK ===\n"
        "1. Check docker stats for memory usage\n"
        "2. Verify compose memory reservation\n"
        "3. Check host swap settings\n\n"
        "=== TOOL CHAIN ===\n"
        "read -> bash -> grep\n\n"
        "=== METADATA ===\n"
        "intent: docker_lifecycle\n"
        "tags: Docker, memory\n"
        "version: 1\n"
    )


@pytest.fixture
def mock_35b_malformed_response():
    """A malformed mock response with missing sections."""
    return (
        "Some text without proper sections\n"
        "Just random content\n"
        "No === markers here\n"
    )


@pytest.fixture
def mock_script_match():
    """A ScriptMatch with all fields populated."""
    return ScriptMatch(
        matched=True,
        script_id="script_0_docker_lifecycle",
        priming_prompt="Check container memory limits.",
        debug_runbook="1. Check stats\n2. Verify compose",
        tool_chain="read -> bash",
        domain_tags=["Docker", "memory"],
        intent_category="docker_lifecycle",
        similarity=0.85,
        confidence=0.004,
    )


# ── Cosine similarity helpers ──────────────────────────────────────────

def make_vector(values):
    """Helper to create a float vector."""
    return [float(v) for v in values]


def identical_vectors(n=10):
    """Two identical vectors."""
    v = [0.7] * n
    return v, v


def opposite_vectors(n=10):
    """Two opposite vectors."""
    a = [1.0] * n
    b = [-1.0] * n
    return a, b


def zero_vector(n=10):
    """A zero vector."""
    return [0.0] * n


def non_zero_vector(n=10):
    """A non-zero vector."""
    return [1.0] * n


@pytest.fixture
def identical_vectors_fixture():
    return identical_vectors()


@pytest.fixture
def opposite_vectors_fixture():
    return opposite_vectors()


@pytest.fixture
def zero_vector_fixture():
    return zero_vector()


@pytest.fixture
def non_zero_vector_fixture():
    return non_zero_vector()
