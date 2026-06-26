"""Tests for reasoning_library.parser.

Required: ≥ 10 test cases
"""

import sys
from pathlib import Path

import pytest

REASONING_LIB = Path(__file__).parent.parent
if str(REASONING_LIB) not in sys.path:
    sys.path.insert(0, str(REASONING_LIB))

from reasoning_library.parser import (
    parse_session_file,
    parse_all_sessions,
    detect_outcome,
    _classify_intent,
)


# ── parse_session_file tests ──────────────────────────────────────────

class TestParseSessionFile:
    """Tests for parse_session_file."""

    def test_parses_standard_session(self, session_short_path):
        """Parses standard session → correct number of thinking blocks."""
        traces = parse_session_file(str(session_short_path))
        assert len(traces) == 3, f"Expected 3 thinking blocks, got {len(traces)}"
        assert traces[0].session_id == "ses_test_001"
        assert traces[0].intent_category == "docker_lifecycle"

    def test_parses_session_with_no_tools(self, session_minimal_path):
        """Parses session with no tools → thinking block still extracted."""
        traces = parse_session_file(str(session_minimal_path))
        assert len(traces) == 1
        assert traces[0].tools_used == []
        assert traces[0].tools_chain == ""
        assert traces[0].intent_category == "general_problem_solving"

    def test_parses_missing_metadata(self, session_weird_path):
        """Parses session with missing metadata → graceful fallback (filename as ID)."""
        traces = parse_session_file(str(session_weird_path))
        assert len(traces) == 1
        # Should fall back to filename stem as ID
        assert traces[0].session_id == "session_weird"
        assert traces[0].session_title == "Weird Session"

    def test_consecutive_thinking_blocks(self, session_short_path):
        """Session with consecutive _Thinking:_ blocks → each extracted correctly."""
        traces = parse_session_file(str(session_short_path))
        assert len(traces) == 3
        # First block has read tool
        assert "read" in traces[0].tools_used
        # Second block has bash and edit tools
        assert "bash" in traces[1].tools_used
        assert "edit" in traces[1].tools_used
        # Third block has no tools
        assert traces[2].tools_used == []

    def test_normcode_format_returns_zero(self, tmp_path):
        """Session with normcode format → 0 blocks returned (not crash)."""
        normcode_md = tmp_path / "normcode.md"
        normcode_md.write_text(
            "# NormCode Plan\n"
            "```ncdn\n"
            "flow: test\n"
            "concept: TestConcept\n"
            "```\n"
        )
        traces = parse_session_file(str(normcode_md))
        assert len(traces) == 0

    def test_session_title_extraction(self, session_short_path):
        """Session title is extracted from the # heading."""
        traces = parse_session_file(str(session_short_path))
        assert traces[0].session_title == "Test Session"

    def test_assistant_duration_extracted(self, session_short_path):
        """Duration is extracted from the assistant header."""
        traces = parse_session_file(str(session_short_path))
        assert traces[0].assistant_duration == "10.0s"
        assert traces[1].assistant_duration == "5.0s"
        assert traces[2].assistant_duration == "3.0s"


# ── detect_outcome tests ──────────────────────────────────────────────

class TestDetectOutcome:
    """Tests for detect_outcome."""

    def test_detects_success(self):
        """detect_outcome correctly marks success."""
        traces = [
            SessionReasoningTrace(
                session_id="s1", session_file="/tmp/s.md", session_title="Test",
                thinking_block_index=0, thinking_block="Everything is done and working.",
            ),
        ]
        result = detect_outcome(traces)
        assert result[0].outcome == "success"

    def test_detects_failure(self):
        """detect_outcome correctly marks failure."""
        traces = [
            SessionReasoningTrace(
                session_id="s1", session_file="/tmp/s.md", session_title="Test",
                thinking_block_index=0, thinking_block="The command failed with an error.",
            ),
        ]
        result = detect_outcome(traces)
        assert result[0].outcome == "failure"

    def test_detects_deferred(self):
        """detect_outcome correctly marks deferred."""
        traces = [
            SessionReasoningTrace(
                session_id="s1", session_file="/tmp/s.md", session_title="Test",
                thinking_block_index=0, thinking_block="Todo: follow up later.",
            ),
        ]
        result = detect_outcome(traces)
        assert result[0].outcome == "deferred"

    def test_no_matching_keywords(self):
        """No matching keywords → deferred (default)."""
        traces = [
            SessionReasoningTrace(
                session_id="s1", session_file="/tmp/s.md", session_title="Test",
                thinking_block_index=0, thinking_block="Just talking about nothing.",
            ),
        ]
        result = detect_outcome(traces)
        assert result[0].outcome == "deferred"


# ── _classify_intent tests ────────────────────────────────────────────

class TestClassifyIntent:
    """Tests for _classify_intent."""

    def test_classifies_docker_lifecycle(self):
        """_classify_intent correctly classifies known keywords."""
        intent, tags = _classify_intent(
            "Tuning the Docker container memory limits for optimal performance",
            ["bash", "read"],
        )
        assert intent == "docker_lifecycle"
        assert "Docker" in tags

    def test_classifies_docker_memory(self):
        """Classifies memory-debug keywords."""
        intent, tags = _classify_intent(
            "oom error in the container, checking rss and swap usage",
            ["bash"],
        )
        assert intent == "memory_debug"

    def test_classifies_script_development(self):
        """Classifies edit+read as script development."""
        intent, tags = _classify_intent(
            "writing a new module",
            ["edit", "read"],
        )
        assert intent == "script_development"

    def test_returns_general_for_gibberish(self):
        """_classify_intent returns general_problem_solving for gibberish."""
        intent, tags = _classify_intent(
            "xyz qwr plm zxc blah",
            [],
        )
        assert intent == "general_problem_solving"

    def test_classifies_lean_theorem(self):
        """Classifies Lean theorem keywords."""
        intent, tags = _classify_intent(
            "proving a new theorem with tactics",
            ["read", "edit"],
        )
        assert intent == "module_refactoring"
        assert "Lean" in tags

    def test_classifies_debug_troubleshoot(self):
        """Classifies bash+error keywords."""
        intent, tags = _classify_intent(
            "running the debug command to troubleshoot the issue",
            ["bash"],
        )
        assert intent == "debug_troubleshoot"


# ── Relative path resolution (P3) ─────────────────────────────────────

class TestRelativePathResolution:
    """Tests for relative path resolution."""

    def test_session_file_is_absolute(self, session_short_path):
        """Relative paths in session_file output are resolved to absolute."""
        traces = parse_session_file(str(session_short_path))
        for t in traces:
            assert Path(t.session_file).is_absolute(), \
                f"Expected absolute path, got {t.session_file}"
