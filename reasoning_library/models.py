"""Core data structures for session-based reasoning library.

Extends the existing reasoning_library.models with session-specific types.
Session traces are natural-language thinking blocks from opencode sessions,
distilled into reusable reasoning scripts (priming prompts, debug runbooks,
tool-use chains).
"""

from __future__ import annotations
from dataclasses import dataclass, field, asdict
from typing import Any
import time
import hashlib


# ── Archiving Schema (domain taxonomy) ──────────────────────────────

ARCHIVING_SCHEMA: dict[str, list[str]] = {
    "lean_formalization": [
        "module_refactoring",
        "type_error_debug",
        "theorem_proving",
        "import_analysis",
        "logic_type_investigation",
    ],
    "infra_operational": [
        "server_tuning",
        "memory_debug",
        "docker_lifecycle",
        "swap_analysis",
        "resource_constraints",
    ],
    "research_exploration": [
        "literature_review",
        "concept_clarification",
        "pattern_identification",
        "planning_design",
    ],
    "pipeline_work": [
        "batch_processing",
        "script_development",
        "config_management",
        "index_pipeline",
    ],
    "normcode_cortex": [
        "tree_mapping",
        "certificate_operations",
        "orchestration",
        "cortex_specs",
    ],
    "general_problem_solving": [
        "decision_tradeoff",
        "self_correction",
        "verification",
        "debug_troubleshoot",
        "dependency_analysis",
    ],
}


# ── SessionReasoningTrace (raw material) ─────────────────────────────

@dataclass
class SessionReasoningTrace:
    """A single thinking block extracted from an opencode session.

    Raw thinking content is preserved; metadata is extracted on parse.
    After distillation, this trace is linked to a ReasoningScript.
    """
    # Source (required)
    session_id: str                        # e.g. "ses_106533eb2ffeRQz9pVC6puIKnN"
    session_file: str                      # Path to session markdown file
    session_title: str                     # e.g. "llama-server 8GB VRAM constraints"
    thinking_block_index: int              # Which thinking block within session
    thinking_block: str                    # The _Thinking: content

    # Optional metadata (defaults)
    assistant_duration: str | None = None  # e.g. "358.8s"
    intent_category: str = ""              # e.g. "server_tuning", "type_error_debug"
    domain_tags: list[str] = field(default_factory=list)
    tools_used: list[str] = field(default_factory=list)
    tools_chain: str = ""                  # e.g. "read -> bash -> read -> edit"
    outcome: str = ""                      # "success" | "failure" | "deferred"
    outcome_detail: str = ""
    embedding: list[float] | None = None
    script_id: str | None = None
    confidence: float = 0.0
    timestamp: float = 0.0

    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = time.time()

    def embed_text(self) -> str:
        """Text to embed — weighted toward intent and tags."""
        parts = [self.intent_category] + self.domain_tags
        parts.append(self.thinking_block[:300])
        return " | ".join(p for p in parts if p)

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        if d.get("embedding") and len(d["embedding"]) > 3:
            d["_embedding_prefix"] = str(d["embedding"][:3])
            d["_embedding_len"] = len(d["embedding"])
        return d


# ── SessionReasoningScript (compressed) ─────────────────────────────

@dataclass
class SessionReasoningScript:
    """A distilled reasoning strategy from N similar traces.

    Three formats cover the main use cases:
    - priming_prompt: mental framework to apply before reasoning
    - debug_runbook: diagnostic procedure for error scenarios
    - tool_chain: recommended tool sequence for efficiency
    """
    id: str
    session_id: str = ""                   # Originating session (for reference)

    # Three script formats
    priming_prompt: str = ""
    debug_runbook: str = ""
    tool_chain: str = ""

    # Metadata
    intent_category: str = ""
    domain_tags: list[str] = field(default_factory=list)
    centroid: list[float] = field(default_factory=list)

    # Quality
    source_trace_count: int = 0
    confidence: float = 0.0
    version: int = 1
    created_at: float = 0.0

    def __post_init__(self):
        if not self.created_at:
            self.created_at = time.time()


# ── Routing Decision ────────────────────────────────────────────────

@dataclass
class ScriptMatch:
    """Result of pattern lookup for a user request."""
    matched: bool = False
    script_id: str = ""
    priming_prompt: str = ""
    debug_runbook: str = ""
    tool_chain: str = ""
    domain_tags: list[str] = field(default_factory=list)
    intent_category: str = ""
    similarity: float = 0.0
    confidence: float = 0.0


# ── Serialization ───────────────────────────────────────────────────

def trace_to_jsonl_line(t: SessionReasoningTrace) -> str:
    """Serialize a trace as a single JSON line."""
    import json
    return json.dumps(t.to_dict())


def traces_from_jsonl(path: str) -> list[SessionReasoningTrace]:
    """Deserialize traces from JSONL file."""
    import json
    traces: list[SessionReasoningTrace] = []
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            traces.append(SessionReasoningTrace(**{
                k: v for k, v in d.items() if not k.startswith("_")
            }))
    return traces
