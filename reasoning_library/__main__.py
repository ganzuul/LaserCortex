"""Reasoning library — module entry point.

Usage:
    python3 -m reasoning_library pipeline [--session-dir .] [--no-model]
    python3 -m reasoning_library mcp_server [--port 8765]

This is the only file that manipulates sys.path. All other modules
use relative imports.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import argparse
import importlib


def main():
    parser = argparse.ArgumentParser(
        prog="reasoning_library",
        description="Session trace analysis and pattern-based reasoning library",
    )
    subparsers = parser.add_subparsers(dest="command")

    # pipeline subcommand
    pipeline_mod = importlib.import_module("reasoning_library.pipeline")
    pipeline_parser = subparsers.add_parser("pipeline", help="Run batch pipeline")
    pipeline_parser.add_argument("--session-dir", default=".",
                                help="Directory with session-ses_*.md files")
    pipeline_parser.add_argument("--output-dir", default=None,
                                help="Output directory")
    pipeline_parser.add_argument("--no-model", action="store_true",
                                help="Skip model-based compression")
    pipeline_parser.add_argument("--min-cluster", type=int, default=3,
                                help="Minimum traces per cluster")
    pipeline_parser.add_argument("--threshold", type=float, default=0.65,
                                help="Similarity threshold")

    # mcp_server subcommand
    mcp_mod = importlib.import_module("reasoning_library.mcp_server")
    mcp_parser = subparsers.add_parser("mcp_server", help="Start MCP lookup server")
    mcp_parser.add_argument("--port", type=int, default=mcp_mod.DEFAULT_PORT)
    mcp_parser.add_argument("--library", default=None, help="Path to library.json")

    args = parser.parse_args()

    if args.command == "pipeline":
        result = pipeline_mod.run_pipeline(
            session_dir=args.session_dir,
            output_dir=args.output_dir,
            use_model=not args.no_model,
            min_cluster_size=args.min_cluster,
            similarity_threshold=args.threshold,
        )
        print(f"\nDone: {result['scripts']} scripts from {result['traces']} traces")
        return 0

    elif args.command == "mcp_server":
        mcp_mod.main()
        return 0

    else:
        parser.print_help()
        return 0


if __name__ == "__main__":
    sys.exit(main())
