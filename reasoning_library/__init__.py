"""Reasoning library — session trace analysis and pattern-based reasoning.

Usage:
    # As a library:
    from reasoning_library.parser import parse_all_sessions
    from reasoning_library.embedder import embed_batch
    from reasoning_library.clusterer import cluster_traces
    from reasoning_library.compressor import compress_cluster_via_model
    
    # As a module:
    python3 -m reasoning_library.pipeline
    python3 -m reasoning_library.mcp_server --port 8765
"""

from __future__ import annotations
import sys, os
if __package__ is None:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from models import (
    SessionReasoningTrace,
    SessionReasoningScript,
    ScriptMatch,
    ARCHIVING_SCHEMA,
)
from parser import parse_all_sessions, parse_session_file, detect_outcome
from embedder import embed_batch, cosine_similarity, _embed_batch
from clusterer import cluster_traces, TraceCluster
from compressor import compress_cluster_via_model

__all__ = [
    "SessionReasoningTrace",
    "SessionReasoningScript",
    "ScriptMatch",
    "ARCHIVING_SCHEMA",
    "parse_all_sessions",
    "parse_session_file",
    "detect_outcome",
    "embed_batch",
    "cosine_similarity",
    "_embed_batch",
    "cluster_traces",
    "TraceCluster",
    "compress_cluster_via_model",
]
