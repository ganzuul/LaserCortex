"""Parser for opencode session markdown files.

Extracts thinking blocks with their associated tool chains from session
markdown files. Produces SessionReasoningTrace objects.

Session format:
  # Title
  **Session ID:** ses_xxx
  **Created:** ...
  
  ## User
  <message>
  
  ## Assistant (Build · <model> · <duration>)
  _Thinking:_
  <thinking content>
  
  **Tool: <name>**
  **Input:** ...
  **Output:** ...
  
  ## Assistant (...)
  _Thinking:_
  <more thinking>
"""


from __future__ import annotations
import sys
import os
if __package__ is None:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import re
from pathlib import Path
from models import SessionReasoningTrace, ARCHIVING_SCHEMA



# ── Regex patterns ───────────────────────────────────────────────────

_SESSION_ID_RE = re.compile(r"\*\*Session ID:\*\*\s*(.+)")
_SESSION_TITLE_RE = re.compile(r"^#\s+(.+)", re.MULTILINE)
_ASSISTANT_RE = re.compile(
    r"## Assistant \((.+?) · (.+?) · (.+?)\)",
    re.MULTILINE
)
_THINKING_RE = re.compile(r"_Thinking:_\s*\n(.*?)(?=\n\*\*Tool:|\n## |\Z)", re.DOTALL)
_TOOL_RE = re.compile(
    r"\*\*Tool:\s*(\w+)\s*\*\*(?:\n\*\*Input:\*\*\s*\n```.*?```\s*\n)?\*\*Output:\*\*\s*\n```.*?```\s*",
    re.DOTALL
)

# Tool name patterns
_TOOL_NAMES = {
    "read", "bash", "edit", "grep", "glob", "task", "question",
    "write", "webfetch", "skill", "todowrite",
}


# ── Intent classification ────────────────────────────────────────────

# Domain-tagging regex patterns: (regex_pattern, output_tag)
_DOMAIN_PATTERNS = [
    (r'\blean\b', 'Lean'),
    (r'\blogic(?:type|m|pipeline)\b', 'LogicType'),
    (r'\btheorem\b', 'theorem'),
    (r'\btactic\b', 'tactic'),
    (r'\bdocker\b', 'Docker'),
    (r'\bcompose\b', 'Docker'),
    (r'\bcontainer\b', 'Docker'),
    (r'\b(vram|ram|memory|swap|rss|heap|oom)\b', 'memory'),
    (r'\b(swappiness|sysctl)\b', 'swap'),
    (r'\bvmtouch\b', 'page_cache'),
    (r'\bembedding\b', 'embedding'),
    (r'\bbge[- ]?m3\b', 'embedding'),
    (r'\bvector\b', 'embedding'),
    (r'\bpipeline\b', 'pipeline'),
    (r'\bphonebook\b', 'phonebook'),
    (r'\blibrarian\b', 'librarian'),
    (r'\bnormcode\b', 'normcode'),
    (r'\bcortex\b', 'cortex'),
    (r'\bcertificate\b', 'certificate'),
    (r'\bwebgpu\b', 'WebGPU'),
    (r'\bshader\b', 'WebGPU'),
    (r'\bbuffer\b', 'WebGPU'),
    (r'\bdjango\b', 'Django'),
    (r'\bapi\b', 'API'),
    (r'\bendpoint\b', 'API'),
    (r'\btypescript\b', 'TypeScript'),
    (r'\bcomponent\b', 'TypeScript'),
    (r'\bstore\b', 'TypeScript'),
    (r'\bpython\b', 'Python'),
]

# Intent keywords mapped to archiving schema categories
_INTENT_MAP = {
    "server_tuning": ["server", "tuning", "tok/s", "latency", "warm", "cold start", "model"],
    "memory_debug": ["oom", "out of memory", "swap", "rss", "heap", "memory", "allocation"],
    "docker_lifecycle": ["docker", "container", "compose", "restart", "health"],
    "module_refactoring": ["refactor", "rename", "move", "import", "module", "theorem"],
    "type_error_debug": ["type error", "type mismatch", "inference failed", "elaboration"],
    "theorem_proving": ["theorem", "proof", "tactic", "goal", "state"],
    "research_exploration": ["explore", "investigate", "understand", "what is"],
    "debug_troubleshoot": ["debug", "troubleshoot", "fix", "broken", "error", "issue"],
    "script_development": ["script", "write", "create", "implement", "build"],
    "planning_design": ["plan", "design", "architecture", "structure", "pipeline"],
    "resource_constraints": ["resource", "constraint", "budget", "limit", "cap"],
    "config_management": ["config", "setting", "parameter", "option"],
    "self_correction": ["actually", "wait", "wrong", "mistake", "correction"],
    "decision_tradeoff": ["tradeoff", "either", "option", "compare", "pros", "cons"],
    "verification": ["verify", "check", "confirm", "validate", "test"],
}


def _classify_intent(thinking_block: str, tools: list[str]) -> tuple[str, list[str]]:
    """Classify the intent and domain tags of a thinking block."""
    text = thinking_block.lower()
    tools_set = set(tools)

    # Domain tags via regex matching
    tags: list[str] = []
    for pattern, output_tag in _DOMAIN_PATTERNS:
        if re.search(pattern, text):
            if output_tag not in tags:
                tags.append(output_tag)

    # If no domain tags from text, use tool-based inference
    if not tags:
        if "bash" in tools_set and any(w in text for w in ["sysctl", "swappiness", "docker", "vmtouch"]):
            tags.append("infra")
        if "read" in tools_set and any(w in text for w in ["lean", "theorem", "def", "theorem"]):
            tags.append("Lean")
        if "grep" in tools_set:
            tags.append("code_analysis")

    # Determine intent category by keyword scoring
    best_intent = "general_problem_solving"
    best_score = 0

    for intent, keywords in _INTENT_MAP.items():
        score = sum(1 for kw in keywords if kw in text)
        if score > best_score:
            best_score = score
            best_intent = intent

    # If no keywords matched but tools were used, infer from tools
    if best_score == 0:
        if "edit" in tools_set and "read" in tools_set:
            best_intent = "script_development"
        elif "bash" in tools_set and any(w in text for w in ["command", "run", "execute"]):
            best_intent = "debug_troubleshoot"
        elif "read" in tools_set or "grep" in tools_set:
            best_intent = "dependency_analysis"

    # Validate intent against archiving schema
    valid = False
    for domain_cats in ARCHIVING_SCHEMA.values():
        if best_intent in domain_cats:
            valid = True
            break
    if not valid:
        best_intent = "general_problem_solving"

    return best_intent, tags


# ── Session parsing ──────────────────────────────────────────────────

def parse_session_file(filepath: str) -> list[SessionReasoningTrace]:
    """Parse a single session markdown file into thinking block traces."""
    with open(filepath, "r") as f:
        content = f.read()

    title_match = _SESSION_TITLE_RE.search(content)
    session_title = title_match.group(1).strip() if title_match else Path(filepath).stem

    id_match = _SESSION_ID_RE.search(content)
    session_id = id_match.group(1).strip() if id_match else Path(filepath).stem

    assistant_matches = list(_ASSISTANT_RE.finditer(content))
    traces: list[SessionReasoningTrace] = []
    block_index = 0

    for i, assist_match in enumerate(assistant_matches):
        start = assist_match.end()
        end = assistant_matches[i + 1].start() if i + 1 < len(assistant_matches) else len(content)
        section_text = content[start:end]
        duration = assist_match.group(3).strip()

        thinking_matches = list(_THINKING_RE.finditer(section_text))

        for j, think_match in enumerate(thinking_matches):
            thinking_text = think_match.group(1).strip()

            # Find tools that appear after this thinking block
            if j + 1 < len(thinking_matches):
                relevant_text = section_text[think_match.end():thinking_matches[j + 1].start()]
            else:
                relevant_text = section_text[think_match.end():]

            tools_in_block = []
            for tool_match in re.finditer(r"\*\*Tool:\s*(\w+)\s*\*\*", relevant_text):
                tool_name = tool_match.group(1)
                if tool_name in _TOOL_NAMES:
                    tools_in_block.append(tool_name)

            intent, tags = _classify_intent(thinking_text, tools_in_block)

            trace = SessionReasoningTrace(
                session_id=session_id,
                session_file=filepath,
                session_title=session_title,
                thinking_block_index=block_index,
                assistant_duration=duration,
                thinking_block=thinking_text,
                intent_category=intent,
                domain_tags=tags,
                tools_used=tools_in_block,
                tools_chain=" -> ".join(tools_in_block) if tools_in_block else "",
            )
            traces.append(trace)
            block_index += 1

    return traces


def parse_all_sessions(session_dir: str | Path) -> list[SessionReasoningTrace]:
    """Parse all session files in a directory."""
    session_dir = Path(session_dir)
    session_files = sorted(session_dir.glob("session-ses_*.md"))

    all_traces: list[SessionReasoningTrace] = []
    for sf in session_files:
        try:
            traces = parse_session_file(str(sf))
            all_traces.extend(traces)
            print(f"  Parsed {sf.name}: {len(traces)} thinking blocks")
        except Exception as e:
            print(f"  ERROR parsing {sf.name}: {e}")

    return all_traces


def detect_outcome(traces: list[SessionReasoningTrace]) -> list[SessionReasoningTrace]:
    """Detect outcomes per session from thinking block patterns."""
    sessions: dict[str, list[SessionReasoningTrace]] = {}
    for t in traces:
        sessions.setdefault(t.session_id, []).append(t)

    outcome_keywords = {
        "success": ["done", "complete", "fixed", "working", "successful", "solved"],
        "failure": ["error", "failed", "crashed", "broke", "couldn't", "unable"],
        "deferred": ["todo", "next", "later", "follow up", "pending", "awaiting"],
    }

    for session_id, session_traces in sessions.items():
        last_block = session_traces[-1].thinking_block.lower()
        best_outcome = "deferred"
        best_score = 0

        for outcome, keywords in outcome_keywords.items():
            score = sum(1 for kw in keywords if kw in last_block)
            if score > best_score:
                best_score = score
                best_outcome = outcome

        if best_score > 0:
            for t in session_traces:
                t.outcome = best_outcome

    return traces
