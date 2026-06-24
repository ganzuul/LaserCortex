# Reasoning Library Pattern Lookup

## Self-Prompting Instruction

When the user's request has room for interpretation, call the reasoning library
MCP to check for matching patterns BEFORE reasoning in detail.

```
ReasoningLibrary.lookup(query="<user request>")
```

If a pattern is matched:
1. Apply the priming_prompt as your mental framework
2. Use the tool_chain to guide your tool selection order
3. Follow the debug_runbook if errors arise
4. Reason within the matched framework

If no pattern is matched, reason from scratch.

## API

The reasoning library runs as an HTTP server (default port 8765).

**Lookup:**
```
POST /lookup
{
    "query_text": "my request here",
    "threshold": 0.60
}

Response:
{
    "matched": true,
    "script_id": "script_42_server_tuning",
    "priming_prompt": "...",
    "debug_runbook": "...",
    "tool_chain": "read -> bash -> edit -> grep -> verify",
    "domain_tags": ["Docker", "memory"],
    "intent_category": "server_tuning",
    "similarity": 0.78,
    "confidence": 0.0
}
```

**Status:**
```
GET /health
GET /library
```

## Starting the Server

```bash
cd LaserCortex/reasoning_library
python3 mcp_server.py --port 8765
```

## Starting the Pipeline (Create Initial Scripts)

```bash
cd LaserCortex/reasoning_library
python3 pipeline.py --session-dir .. [--no-model] [--min-cluster 3] [--threshold 0.65]
```

## Usage in Reasoning

When the user says something like:
> "The server is running slow after a restart"

Call:
```
ReasoningLibrary.lookup(query="server is running slow after a restart")
```

If matched (similarity ≥ 0.60), you'll get back a priming prompt like:
> "When debugging slow server startup: check CUDA cache, verify Docker memory reservation, check swap usage, review parallelism settings"

Apply this framework before detailed reasoning.

## Integration with Opencode

This skill integrates with opencode's reasoning pipeline:
1. Before detailed reasoning, check the library for matching patterns
2. If matched, use the returned priming framework
3. After reasoning completes, the session trace is captured for future pipeline runs
