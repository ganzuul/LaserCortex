"""Compression: distill trace clusters into reasoning scripts.

Uses the meta-35B model (via HTTP) to analyze clusters of similar thinking
blocks and produce reusable reasoning scripts in three formats:
1. Priming prompt — mental framework for approaching the task
2. Debug runbook — diagnostic procedure for common errors
3. Tool-use chain — recommended sequence of tools for efficiency
"""


import json
from .models import SessionReasoningScript, SessionReasoningTrace
from .clusterer import TraceCluster


COMPRESS_PROMPT_TEMPLATE = """You are compressing reasoning traces into reusable scripts.

## Cluster Summary
- **Intent:** {intent}
- **Domain tags:** {tags}
- **Trace count:** {n_traces}

## Traces in this cluster
{traces_text}

## Task
Analyze these N reasoning traces and produce a compact reasoning script.

Output exactly FOUR sections in this format:

=== PRIMING ===
<1-3 sentences: the mental framework to apply before reasoning about this type of task>

=== RUNBOOK ===
<step-by-step diagnostic procedure. If errors/warnings appear, follow these steps.
Keep it under 8 steps. Use numbered lists.>

=== TOOL CHAIN ===
<recommended tool sequence. Format: tool1 -> tool2 -> tool3>

=== METADATA ===
intent: <intent category>
tags: <comma-separated tags>
version: 1
"""


def _format_traces_for_compression(traces: list[SessionReasoningTrace]) -> str:
    """Format traces for the compression prompt."""
    lines = []
    for i, t in enumerate(traces[:10]):  # Limit to 10 traces
        preview = t.thinking_block[:200].replace('\n', ' ').strip()
        lines.append(f"  Trace {i+1} [{t.intent_category}]: \"{preview}\"")
        if t.tools_chain:
            lines.append(f"    Tools: {t.tools_chain}")
        lines.append("")
    return "\n".join(lines)


def compress_cluster_via_model(cluster: TraceCluster, traces: list[SessionReasoningTrace],
                                model_url: str = "http://localhost:8080/v1/chat/completions",
                                model_name: str = "Qwen3.6-35B-A3B") -> SessionReasoningScript | None:
    """Use the meta model to compress a cluster into reasoning scripts.

    Returns None if the model call fails or output is malformed.
    """
    cluster_traces = [traces[i] for i in cluster.members]
    tags_str = ", ".join(cluster.domain_tags) if cluster.domain_tags else "general"

    prompt = COMPRESS_PROMPT_TEMPLATE.format(
        intent=cluster.intent_category,
        tags=tags_str,
        n_traces=len(cluster_traces),
        traces_text=_format_traces_for_compression(cluster_traces),
    )

    messages = [
        {"role": "system", "content": "You are a reasoning script compressor. Output ONLY the structured format specified."},
        {"role": "user", "content": prompt},
    ]

    body = {
        "model": model_name,
        "messages": messages,
        "temperature": 0.3,
        "max_tokens": 1500,
    }

    try:
        import http.client
        host = model_url.replace("http://", "").split(":")[0]
        port = int(model_url.split(":")[1])
        conn = http.client.HTTPConnection(host, port, timeout=120)
        headers = {"Content-Type": "application/json"}
        conn.request("POST", "/chat/completions", json.dumps(body), headers)
        resp = conn.getresponse()
        data = json.loads(resp.read().decode())
        conn.close()

        content = data["choices"][0]["message"]["content"]
        return _parse_compression_output(content, cluster)

    except Exception as e:
        print(f"  WARNING: Model compression failed for cluster {cluster.cluster_id}: {e}")
        return None


def _parse_compression_output(raw: str, cluster: TraceCluster) -> SessionReasoningScript:
    """Parse the structured output from the compression prompt."""
    priming = ""
    runbook = ""
    tool_chain = ""

    sections = raw.split("===")
    for section in sections:
        section = section.strip()
        if section.startswith(" PRIMING "):
            priming = section.replace(" PRIMING ", "").strip()
        elif section.startswith(" RUNBOOK "):
            runbook = section.replace(" RUNBOOK ", "").strip()
        elif section.startswith(" TOOL CHAIN "):
            tool_chain = section.replace(" TOOL CHAIN ", "").strip()
        elif section.startswith(" METADATA "):
            for line in section.split("\n"):
                line = line.strip()
                if line.startswith("intent:"):
                    pass  # cluster already has intent_category
                elif line.startswith("tags:"):
                    pass  # cluster already has domain_tags

    # Extract tool chain from runbook if not explicitly provided
    if not tool_chain:
        tool_names = ["read", "bash", "edit", "grep", "glob", "question", "write"]
        found = [t for t in tool_names if t in runbook.lower() or t in priming.lower()]
        if found:
            tool_chain = " -> ".join(found)

    return SessionReasoningScript(
        id=f"script_{cluster.cluster_id}_{cluster.intent_category}",
        priming_prompt=priming,
        debug_runbook=runbook,
        tool_chain=tool_chain,
        intent_category=cluster.intent_category,
        domain_tags=cluster.domain_tags,
        centroid=cluster.centroid,
        source_trace_count=len(cluster.members),
        version=1,
    )
