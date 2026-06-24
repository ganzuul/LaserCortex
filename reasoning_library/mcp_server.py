"""MCP server for reasoning library pattern lookup.

Start: python3 -m reasoning_library.mcp_server --port 8765
       cd reasoning_library && python3 mcp_server.py --port 8765

API:
  POST /lookup  {"query_text": "...", "threshold": 0.60}
  GET  /health
  GET  /library
"""


from __future__ import annotations
import sys, os
if __package__ is None:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import argparse
import json
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse


_script_dir = Path(__file__).parent
if str(_script_dir) not in sys.path:
    sys.path.insert(0, str(_script_dir))

from embedder import _embed_batch
from models import ScriptMatch

DEFAULT_PORT = 8765
DEFAULT_SIMILARITY_THRESHOLD = 0.60
LIBRARY_PATH = Path(__file__).parent / "library.json"


def load_library(path=None):
    path = path or LIBRARY_PATH
    with open(path, "r") as f:
        return json.load(f)


def lookup_pattern(query_text, library, threshold=DEFAULT_SIMILARITY_THRESHOLD):
    if "scripts" not in library or not library["scripts"]:
        return ScriptMatch()

    try:
        query_emb = _embed_batch([query_text])[0]
    except Exception:
        return ScriptMatch()

    best_match = None
    best_sim = 0.0

    for script in library["scripts"]:
        centroid = script.get("centroid", [])
        if not centroid:
            continue
        from embedder import cosine_similarity
        sim = cosine_similarity(query_emb, centroid)
        if sim > best_sim:
            best_sim = sim
            best_match = script

    if best_match and best_sim >= threshold:
        return ScriptMatch(
            matched=True,
            script_id=best_match.get("id", ""),
            priming_prompt=best_match.get("priming_prompt", ""),
            debug_runbook=best_match.get("debug_runbook", ""),
            tool_chain=best_match.get("tool_chain", ""),
            domain_tags=best_match.get("domain_tags", []),
            intent_category=best_match.get("intent_category", ""),
            similarity=best_sim,
            confidence=best_match.get("confidence", 0.0),
        )

    return ScriptMatch()


class MCPRequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/lookup":
            self._send_json(404, {"error": "Not found"})
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else b"{}"

        try:
            request = json.loads(body.decode())
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON"})
            return

        query_text = request.get("query_text", "")
        threshold = float(request.get("threshold", DEFAULT_SIMILARITY_THRESHOLD))

        if not query_text:
            self._send_json(400, {"error": "query_text is required"})
            return

        try:
            library = load_library()
        except Exception as e:
            self._send_json(500, {"error": f"Failed to load library: {e}"})
            return

        match = lookup_pattern(query_text, library, threshold)

        self._send_json(200, {
            "matched": match.matched,
            "script_id": match.script_id,
            "priming_prompt": match.priming_prompt,
            "debug_runbook": match.debug_runbook,
            "tool_chain": match.tool_chain,
            "domain_tags": match.domain_tags,
            "intent_category": match.intent_category,
            "similarity": round(match.similarity, 4),
            "confidence": match.confidence,
        })

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send_json(200, {"status": "ok"})
        elif parsed.path == "/library":
            try:
                library = load_library()
                self._send_json(200, {
                    "version": library.get("version"),
                    "trace_count": library.get("trace_count"),
                    "cluster_count": library.get("cluster_count"),
                    "script_count": library.get("script_count"),
                })
            except Exception as e:
                self._send_json(500, {"error": str(e)})
        else:
            self._send_json(404, {"error": "Not found"})

    def _send_json(self, status, data):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())


def main():
    parser = argparse.ArgumentParser(description="Reasoning library MCP server")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--library", default=None)
    args = parser.parse_args()

    if args.library:
        global LIBRARY_PATH
        LIBRARY_PATH = Path(args.library)

    server = HTTPServer(("0.0.0.0", args.port), MCPRequestHandler)
    print(f"Reasoning library MCP server on http://0.0.0.0:{args.port}")
    print(f"  POST /lookup  - Look up patterns")
    print(f"  GET  /health  - Health check")
    print(f"  GET  /library - Library info")
    print(f"  Library: {args.library}")
    print()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.server_close()


if __name__ == "__main__":
    main()
