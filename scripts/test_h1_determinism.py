#!/usr/bin/env python3
"""
Phase 1 (H1): Determinism Test.

Run 3 diverse files through the 35B at temperature=0, seed=<content_hash[:8]>,
twice each, and compare outputs character-by-character.

Prerequisites:
  - 35B model running on :8080 (llama-server)
  - ON API on :5055

Usage:
  python3 scripts/test_h1_determinism.py
"""

import hashlib
import json
import sys
import time
from pathlib import Path

import requests

REPO_ROOT = Path("/home/nos/labware/LaserCortex")
ON_API = "http://localhost:5055/api"
LLM_URL = "http://localhost:8080"

TRANSFORMATION_ID = "transformation:0tkrn2ru01xj0zd4cp09"
MODEL = "Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf"

# 3 diverse files for testing
TEST_FILES = [
    {
        "label": "FORMALIZATION",
        "path": "LaserCortex/Cost.lean",
        "module": "Cost",
    },
    {
        "label": "API_GATEWAY",
        "path": "infra/_cortex/_cost.py",
        "module": "_cost",
    },
    {
        "label": "PRESENTATION",
        "path": "canvas_app/frontend/src/components/graph/FunctionNode.tsx",
        "module": "FunctionNode",
    },
]

# Cache the prompt
_prompt_cache: str | None = None


def get_transformation_prompt() -> str:
    global _prompt_cache
    if _prompt_cache is not None:
        return _prompt_cache
    r = requests.get(f"{ON_API}/transformations/{TRANSFORMATION_ID}", timeout=30)
    r.raise_for_status()
    _prompt_cache = r.json().get("prompt", "")
    return _prompt_cache


def call_35b(messages: list[dict], seed: int, run_label: str) -> str:
    """Call 35B with temperature=0 and deterministic seed."""
    payload = {
        "model": MODEL,
        "messages": messages,
        "temperature": 0,
        "seed": seed,
        "max_tokens": 12288,  # Extra room for thinking + structured output
        "cache_prompt": False,
    }
    t0 = time.time()
    resp = requests.post(f"{LLM_URL}/v1/chat/completions", json=payload, timeout=600)
    elapsed = time.time() - t0
    resp.raise_for_status()
    msg = resp.json()["choices"][0]["message"]
    # The 35B is a reasoning model: thinking goes to reasoning_content,
    # final output goes to content. We compare content only.
    output = msg.get("content", "") or ""
    reasoning = msg.get("reasoning_content", "") or ""
    print(f"    [{run_label}] {elapsed:.1f}s (reasoning={len(reasoning)} chars, content={len(output)} chars)")
    return output


def main():
    print("=" * 60)
    print("H1 Determinism Test: temperature=0, seed=<content_hash>")
    print("=" * 60)

    # Get the prompt
    print(f"\n[1/2] Fetching transformation prompt...")
    prompt = get_transformation_prompt()
    print(f"  Prompt: {len(prompt)} chars")

    results = {}

    for test_file in TEST_FILES:
        label = test_file["label"]
        path = REPO_ROOT / test_file["path"]
        module = test_file["module"]

        print(f"\n{'─' * 50}")
        print(f"[{label}] {path.name} ({module})")

        # Read file content
        content = path.read_text()
        content_hash = hashlib.sha256(content.encode()).hexdigest()
        seed = int(content_hash[:8], 16)
        print(f"  Content: {len(content)} chars, seed={seed}")

        # Build messages
        messages = [
            {"role": "system", "content": prompt},
            {"role": "user", "content": content},
        ]

        # Run twice (should produce identical output)
        print(f"\n  Run A (temp=0, seed={seed})...")
        output_a = call_35b(messages, seed, "A")
        print(f"  Run B (temp=0, seed={seed})...")
        output_b = call_35b(messages, seed, "B")

        # Character-by-character comparison
        sha_a = hashlib.sha256(output_a.encode()).hexdigest()
        sha_b = hashlib.sha256(output_b.encode()).hexdigest()
        match = output_a == output_b

        print(f"\n  Results:")
        print(f"    Output A: {len(output_a)} chars, SHA256={sha_a[:16]}")
        print(f"    Output B: {len(output_b)} chars, SHA256={sha_b[:16]}")
        print(f"    Identical: {'✅ YES' if match else '❌ NO'}")

        if not match:
            # Find first difference
            min_len = min(len(output_a), len(output_b))
            for i in range(min_len):
                if output_a[i] != output_b[i]:
                    print(f"    First diff at char {i}:")
                    print(f"      A: ...{repr(output_a[max(0,i-20):i+20])}...")
                    print(f"      B: ...{repr(output_b[max(0,i-20):i+20])}...")
                    break
            if len(output_a) != len(output_b):
                print(f"    Length mismatch: A={len(output_a)} vs B={len(output_b)}")
                # Show the tail of each
                tail_len = 100
                print(f"      A tail: {repr(output_a[-tail_len:])}")
                print(f"      B tail: {repr(output_b[-tail_len:])}")

        results[module] = {
            "match": match,
            "len_a": len(output_a),
            "len_b": len(output_b),
            "sha_a": sha_a[:16],
            "sha_b": sha_b[:16],
        }

    # Summary
    print(f"\n{'=' * 60}")
    print("H1 Determinism Test — Summary")
    print(f"{'=' * 60}")
    all_match = True
    for module, r in results.items():
        status = "✅ DETERMINISTIC" if r["match"] else "❌ NON-DETERMINISTIC"
        if not r["match"]:
            all_match = False
        print(f"  {module:30s} | {r['len_a']:5d} chars | {status}")
    print(f"{'─' * 60}")
    if all_match:
        print("H1 PASSED: temperature=0 with content-derived seed produces identical output.")
    else:
        print("H1 FAILED: temperature=0 with content-derived seed does NOT guarantee determinism.")
        print("Possible causes: model running on CPU fallback, GPU non-determinism, or float rounding.")


if __name__ == "__main__":
    main()
