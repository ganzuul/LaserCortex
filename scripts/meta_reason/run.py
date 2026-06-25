#!/usr/bin/env python3
"""
Standalone meta-reasoning loop for LaserCortex.

V1 — Explore: Analyze each Lean file for scaffolding patterns
V2 — Aggregate: Synthesize V1 outputs to detect systemic voids
V3 — Self-Improve: Critique and refine the analysis

No LangChain. No Open Notebook dependency. Direct HTTP to llama.cpp (35B).

Usage:
    python3 scripts/meta_reason/run.py                    # Full run (all files)
    python3 scripts/meta_reason/run.py --quick             # 5 files only
    python3 scripts/meta_reason/run.py --force             # Re-run even cached
    python3 scripts/meta_reason/run.py --v1-only           # Skip V2/V3
    python3 scripts/meta_reason/run.py --summary-only      # Just show last results
"""

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, UTC
from pathlib import Path
from typing import Optional

import httpx

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
LASERCORTEX_DIR = REPO_ROOT / "LaserCortex"
MODEL_ENDPOINT = os.environ.get("MODEL_ENDPOINT", "http://localhost:8080/v1/chat/completions")
MODEL_NAME = os.environ.get("MODEL_NAME", "Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf")
OUTPUT_DIR = Path(__file__).resolve().parent / "output"
PROMPTS_DIR = REPO_ROOT / ".open-notebook" / "prompts"

# Files to exclude from analysis
EXCLUDE_FILES = {
    "LaserCortex.lean",   # Top-level import file
    "Main.lean",          # Entry point
    "EMLRegistry_test.lean",  # Test file
}

# ---------------------------------------------------------------------------
# Prompt loading
# ---------------------------------------------------------------------------
PROMPT_FILES = {
    "v1": "01_exploration_criteria.md",
    "v2": "02_aggregation_metareasoning.md",
    "v3": "03_self_improving_loop.md",
}


def load_prompt(name: str) -> str:
    path = PROMPTS_DIR / PROMPT_FILES[name]
    if not path.exists():
        print(f"  [WARN] Prompt file not found: {path}")
        return ""
    return path.read_text().strip()


# ---------------------------------------------------------------------------
# Source file discovery
# ---------------------------------------------------------------------------
def discover_lean_files(quick: bool = False) -> list[Path]:
    """Discover Lean files in LaserCortex directory."""
    files = []
    for p in sorted(LASERCORTEX_DIR.rglob("*.lean")):
        rel = p.relative_to(LASERCORTEX_DIR)
        if rel.name in EXCLUDE_FILES:
            continue
        files.append(p)

    if quick:
        # Take a representative sample: core + 2 paradox + 2 other
        priority = [
            "Generation.lean",
            "FrictionLagrangian.lean",
            "Problem.lean",
            "LiarParadox.lean",
            "BornTest.lean",
            "Cost.lean",
            "InstitutionalClosure.lean",
            "LogicTypes.lean",
        ]
        prioritized = []
        for name in priority:
            match = [f for f in files if f.name == name]
            prioritized.extend(match)
        # Deduplicate
        seen = set()
        result = []
        for f in prioritized:
            if f.name not in seen:
                result.append(f)
                seen.add(f.name)
        # Add remaining up to 5
        for f in files:
            if f.name not in seen and len(result) < 5:
                result.append(f)
                seen.add(f.name)
        files = result[:5]

    return files


def read_file_content(path: Path) -> str:
    """Read a Lean file's content."""
    try:
        content = path.read_text()
        # Truncate very long files to avoid context overflow
        max_chars = 15000
        if len(content) > max_chars:
            content = content[:max_chars] + f"\n-- ... [truncated from {len(content)} chars]"
        return content
    except Exception as e:
        print(f"  [ERROR] Reading {path}: {e}")
        return ""


# ---------------------------------------------------------------------------
# 35B API call
# ---------------------------------------------------------------------------
async def call_35b(
    messages: list[dict],
    max_tokens: int = 8192,
    temperature: float = 0.1,
    label: str = "",
) -> dict:
    """Make a direct HTTP call to the 35B (llama.cpp server).

    Returns dict with keys: content, reasoning_content, model, usage, duration_s
    """
    headers = {"Content-Type": "application/json"}
    payload = {
        "model": MODEL_NAME,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
    }

    if label:
        print(f"  [{label}] Sending request ({len(messages)} messages)...", flush=True)

    t0 = time.time()
    async with httpx.AsyncClient(timeout=600) as client:
        try:
            resp = await client.post(
                MODEL_ENDPOINT, json=payload, headers=headers
            )
            resp.raise_for_status()
        except httpx.HTTPStatusError as e:
            print(f"  [{label}] HTTP error: {e.response.status_code} {e.response.text[:300]}")
            return {"error": str(e), "content": "", "reasoning_content": ""}
        except httpx.RequestError as e:
            print(f"  [{label}] Request failed: {e}")
            return {"error": str(e), "content": "", "reasoning_content": ""}

    t1 = time.time()
    duration = round(t1 - t0, 1)

    data = resp.json()
    choice = data.get("choices", [{}])[0]
    message = choice.get("message", {})
    usage = data.get("usage", {})

    content = message.get("content") or ""
    reasoning = message.get("reasoning_content") or ""

    # Fallback: parse <think> tags if reasoning_content not provided separately
    if not reasoning:
        m = re.search(r"<think>(.*?)</think>", content, re.DOTALL)
        if m:
            reasoning = m.group(1).strip()
            content = re.sub(r"<think>.*?</think>", "", content, flags=re.DOTALL).strip()

    result = {
        "content": content,
        "reasoning_content": reasoning,
        "model": data.get("model", MODEL_NAME),
        "usage": usage,
        "duration_s": duration,
        "finish_reason": choice.get("finish_reason", ""),
    }

    print(f"  [{label}] Done in {duration}s — content={len(content)}ch, reasoning={len(reasoning)}ch")
    return result


# ---------------------------------------------------------------------------
# V1 — Per-file exploration
# ---------------------------------------------------------------------------
def get_v1_prompt(file_path: Path, file_content: str) -> str:
    """Build the V1 prompt for a single file."""
    prompt = load_prompt("v1")
    return f"""{prompt}

## File to Analyze

**Path**: {file_path.relative_to(LASERCORTEX_DIR)}

```lean
{file_content}
```

Analyze this file according to the criteria above. Output structured JSON."""


async def run_v1_on_file(
    file_path: Path,
    force: bool = False,
) -> Optional[dict]:
    """Run V1 exploration on a single Lean file."""
    rel = str(file_path.relative_to(LASERCORTEX_DIR))
    label = f"V1:{rel}"

    # Check cache
    cache_path = OUTPUT_DIR / "v1" / f"{rel.replace('/', '_')}.json"
    if cache_path.exists() and not force:
        print(f"  [{label}] Cached — skipped ({cache_path.name})")
        try:
            return json.loads(cache_path.read_text())
        except Exception:
            pass

    content = read_file_content(file_path)
    if not content:
        return None

    v1_prompt = get_v1_prompt(file_path, content)
    messages = [
        {"role": "system", "content": v1_prompt},
        {"role": "user", "content": f"Analyze file: {rel}"},
    ]

    result = await call_35b(messages, label=label)
    if "error" in result:
        return result

    result["file"] = rel
    result["analyzed_at"] = datetime.now(UTC).isoformat()

    # Cache result
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(result, indent=2))
    print(f"  [{label}] Saved to {cache_path}")

    return result


# ---------------------------------------------------------------------------
# V2 — Aggregation
# ---------------------------------------------------------------------------
async def run_v2(v1_results: list[dict], force: bool = False) -> Optional[dict]:
    """Run V2 aggregation over all V1 results."""
    cache_path = OUTPUT_DIR / "v2.json"
    if cache_path.exists() and not force:
        print("  [V2] Cached — skipped")
        return json.loads(cache_path.read_text())

    if not v1_results:
        print("  [V2] No V1 results to aggregate — skipping")
        return None

    prompt = load_prompt("v2")

    # Build aggregated context from V1 outputs
    aggregated = []
    for r in v1_results:
        file = r.get("file", "?")
        content = r.get("content", "")
        reasoning = r.get("reasoning_content", "")
        aggregated.append(f"=== {file} ===\nOutput:\n{content[:2000]}\n\nReasoning:\n{reasoning[:1000]}")

    context = "\n\n".join(aggregated)

    system_msg = f"""{prompt}

## Aggregated Explorer Notes

{context}

Synthesize these per-file analyses into an aggregated meta-analysis. Output structured JSON."""

    messages = [
        {"role": "system", "content": system_msg},
        {"role": "user", "content": "Produce aggregated meta-analysis across all analyzed files."},
    ]

    result = await call_35b(messages, max_tokens=8192, label="V2")
    if "error" in result:
        return result

    result["v1_files_count"] = len(v1_results)
    result["analyzed_at"] = datetime.now(UTC).isoformat()

    cache_path.write_text(json.dumps(result, indent=2))
    print(f"  [V2] Saved to {cache_path}")
    return result


# ---------------------------------------------------------------------------
# V3 — Self-Improving
# ---------------------------------------------------------------------------
async def run_v3(v2_result: Optional[dict], force: bool = False) -> Optional[dict]:
    """Run V3 self-improving critique."""
    cache_path = OUTPUT_DIR / "v3.json"
    if cache_path.exists() and not force:
        print("  [V3] Cached — skipped")
        return json.loads(cache_path.read_text())

    if not v2_result or not v2_result.get("content"):
        print("  [V3] No V2 result to improve upon — skipping")
        return None

    prompt = load_prompt("v3")
    v2_content = v2_result.get("content", "")
    v2_reasoning = v2_result.get("reasoning_content", "")

    system_msg = f"""{prompt}

## Previous Analysis (V2 — Aggregation)

Output:
{v2_content[:3000]}

Reasoning trace:
{v2_reasoning[:2000]}

Critique the aggregation above. What did it miss? What patterns emerged that weren't detected? 
What would you do differently in the next pass? Be specific."""

    messages = [
        {"role": "system", "content": system_msg},
        {"role": "user", "content": "Critique the aggregation pass and suggest improvements."},
    ]

    result = await call_35b(messages, max_tokens=8192, label="V3")
    if "error" in result:
        return result

    result["analyzed_at"] = datetime.now(UTC).isoformat()
    cache_path.write_text(json.dumps(result, indent=2))
    print(f"  [V3] Saved to {cache_path}")
    return result


# ---------------------------------------------------------------------------
# Summary & Comparison
# ---------------------------------------------------------------------------
def format_size(n: int) -> str:
    if n > 1000:
        return f"{n // 1000}k"
    return str(n)


def print_summary(v1_results: list[dict], v2_result: Optional[dict], v3_result: Optional[dict]):
    """Print a human-readable summary of the meta-reasoning run."""
    print()
    print("=" * 70)
    print("  META-REASONING SUMMARY")
    print("=" * 70)
    print()

    # V1 stats
    v1_success = [r for r in v1_results if not r.get("error") and r.get("content")]
    v1_failed = [r for r in v1_results if r.get("error") or not r.get("content")]

    print(f"  V1 — Files analyzed: {len(v1_success)}/{len(v1_results)}")
    for r in v1_success[:5]:
        print(f"    {r.get('file','?'):40s} {format_size(len(r.get('content',''))):>6s}ch  reasoning: {format_size(len(r.get('reasoning_content',''))):>6s}ch")
    if len(v1_success) > 5:
        print(f"    ... and {len(v1_success) - 5} more")
    if v1_failed:
        print(f"    Failed: {[r.get('file','?') for r in v1_failed]}")

    print()

    # V2 stats
    if v2_result and v2_result.get("content"):
        print(f"  V2 — Aggregation: {format_size(len(v2_result['content']))}ch output, "
              f"{format_size(len(v2_result.get('reasoning_content','')))}ch reasoning")
        # Count findings in V2
        v2_text = v2_result["content"]
        void_count = v2_text.count("void_id") + v2_text.count('"severity"')
        print(f"       Detected voids/issues: ~{void_count} mentions")
    else:
        print("  V2 — Not run or failed")

    print()

    # V3 stats
    if v3_result and v3_result.get("content"):
        print(f"  V3 — Self-improvement: {format_size(len(v3_result['content']))}ch output, "
              f"{format_size(len(v3_result.get('reasoning_content','')))}ch reasoning")
    else:
        print("  V3 — Not run or failed")

    print()

    # Cross-level comparison
    print("  --- Cross-level Comparison ---")
    print()

    # Count unique terms per level
    def extract_terms(text: str) -> set[str]:
        # Simple heuristic: extract quoted "finding" patterns and key terms
        terms = set()
        # Find JSON-like patterns
        for m in re.finditer(r'"(severity|category|void_id|finding)"\s*:\s*"([^"]+)"', text):
            terms.add(m.group(2))
        # Find key phrases
        for m in re.finditer(r'(?:critical|major|dead_leaf|placeholder|bridge_gap|migration_artifact)', text.lower()):
            terms.add(m.group())
        return terms

    # Collect V1 terms across all files
    v1_combined_terms = set()
    v1_reasoning_lengths = []
    for r in v1_success:
        v1_combined_terms |= extract_terms(r.get("content", ""))
        if r.get("reasoning_content"):
            v1_reasoning_lengths.append(len(r["reasoning_content"]))

    v2_terms = extract_terms(v2_result.get("content", "")) if v2_result else set()
    v3_terms = extract_terms(v3_result.get("content", "")) if v3_result else set()

    print(f"  V1 unique findings/terms across all files: {len(v1_combined_terms)}")
    print(f"  V2 unique findings/terms:                  {len(v2_terms)}")
    print(f"  V3 unique findings/terms:                  {len(v3_terms)}")

    if v1_reasoning_lengths:
        avg_v1_reasoning = sum(v1_reasoning_lengths) / len(v1_reasoning_lengths)
        print(f"  Avg V1 reasoning trace length:              {avg_v1_reasoning:.0f} chars")
    if v2_result and v2_result.get("reasoning_content"):
        print(f"  V2 reasoning trace length:                   {len(v2_result['reasoning_content'])} chars")
    if v3_result and v3_result.get("reasoning_content"):
        print(f"  V3 reasoning trace length:                   {len(v3_result['reasoning_content'])} chars")

    print()

    # Intersection: terms V2 found that V1 missed
    v2_only = v2_terms - v1_combined_terms
    v3_only = v3_terms - v1_combined_terms

    if v2_only:
        print(f"  Terms V2 found that V1 missed ({len(v2_only)}):")
        for t in sorted(v2_only)[:10]:
            print(f"    - {t}")
    if v3_only:
        print(f"  Terms V3 found that V1 missed ({len(v3_only)}):")
        for t in sorted(v3_only)[:10]:
            print(f"    - {t}")

    print()
    print("=" * 70)


# ---------------------------------------------------------------------------
# Main orchestrator
# ---------------------------------------------------------------------------
async def run_all(
    quick: bool = False,
    force: bool = False,
    v1_only: bool = False,
    summary_only: bool = False,
):
    """Run the full meta-reasoning loop."""
    print(f"LaserCortex Meta-Reasoning Loop")
    print(f"  Model: {MODEL_NAME}")
    print(f"  Endpoint: {MODEL_ENDPOINT}")
    print(f"  Output: {OUTPUT_DIR}")
    print(f"  Quick mode: {'yes' if quick else 'no'}")
    print(f"  Force re-run: {'yes' if force else 'no'}")
    print()

    # Discover files
    files = discover_lean_files(quick=quick)
    print(f"Discovered {len(files)} Lean files:")
    for f in files:
        print(f"  {f.relative_to(LASERCORTEX_DIR)}")
    print()

    if summary_only:
        # Load cached results and print summary
        v1_results = []
        v1_dir = OUTPUT_DIR / "v1"
        if v1_dir.exists():
            for p in sorted(v1_dir.glob("*.json")):
                try:
                    v1_results.append(json.loads(p.read_text()))
                except Exception:
                    pass
        v2_result = None
        v2_path = OUTPUT_DIR / "v2.json"
        if v2_path.exists():
            v2_result = json.loads(v2_path.read_text())
        v3_result = None
        v3_path = OUTPUT_DIR / "v3.json"
        if v3_path.exists():
            v3_result = json.loads(v3_path.read_text())

        print_summary(v1_results, v2_result, v3_result)
        return

    # Phase 1: V1 exploration per file
    print("-" * 70)
    print("  PHASE 1: V1 — Per-file Exploration")
    print("-" * 70)
    print()

    v1_results = []
    for i, file_path in enumerate(files):
        rel = str(file_path.relative_to(LASERCORTEX_DIR))
        print(f"  [{i+1}/{len(files)}] {rel}")
        result = await run_v1_on_file(file_path, force=force)
        if result:
            v1_results.append(result)
            # Brief pause between files to avoid overwhelming the model
            await asyncio.sleep(1)
        print()

    if v1_only:
        print_summary(v1_results, None, None)
        return

    # Phase 2: V2 aggregation
    print("-" * 70)
    print("  PHASE 2: V2 — Aggregation")
    print("-" * 70)
    print()

    v2_result = await run_v2(v1_results, force=force)
    print()

    # Phase 3: V3 self-improving
    print("-" * 70)
    print("  PHASE 3: V3 — Self-Improvement")
    print("-" * 70)
    print()

    v3_result = await run_v3(v2_result, force=force)
    print()

    # Summary
    print_summary(v1_results, v2_result, v3_result)

    # Save combined report
    report = {
        "run_config": {
            "model": MODEL_NAME,
            "endpoint": MODEL_ENDPOINT,
            "quick": quick,
            "files_count": len(files),
        },
        "v1": {
            "files": [r.get("file") for r in v1_results],
            "total_duration_s": sum(r.get("duration_s", 0) for r in v1_results),
        },
        "v2": {
            "content_length": len(v2_result.get("content", "")) if v2_result else 0,
            "reasoning_length": len(v2_result.get("reasoning_content", "")) if v2_result else 0,
        },
        "v3": {
            "content_length": len(v3_result.get("content", "")) if v3_result else 0,
            "reasoning_length": len(v3_result.get("reasoning_content", "")) if v3_result else 0,
        },
    }
    report_path = OUTPUT_DIR / "report.json"
    report_path.write_text(json.dumps(report, indent=2))
    print(f"\nCombined report saved to {report_path}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="LaserCortex Meta-Reasoning Loop")
    parser.add_argument("--quick", action="store_true", help="Only analyze 5 files")
    parser.add_argument("--force", action="store_true", help="Re-run even if cached")
    parser.add_argument("--v1-only", action="store_true", help="Skip V2/V3 phases")
    parser.add_argument("--summary-only", action="store_true", help="Show summary of last run")
    args = parser.parse_args()

    asyncio.run(run_all(
        quick=args.quick,
        force=args.force,
        v1_only=args.v1_only,
        summary_only=args.summary_only,
    ))
