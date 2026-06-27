#!/usr/bin/env python3
"""
Analyze OWL Ontologies for Blood-Brain Barrier Pairings

This script delegates to scripts/build_owl_correspondence.py which uses
actual M0 atom data (from reinforcement_atoms.json) and real trace data
(from reasoning_library/traces.jsonl).

The blood-brain barrier principle:
  BRAIN  = OWL ontology atoms (framenet, verbnet, manpage, prov-o, p-plan)
  BLOOD  = Natural language words from reasoning traces
  BARRIER = Exact/lemmatized match between NL word and atom label/verb member

Usage:
    python scripts/analyze_owl_ontologies.py       # run full analysis
    python scripts/analyze_owl_ontologies.py --help # print this message
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main():
    if "--help" in sys.argv or "-h" in sys.argv:
        print((__doc__ or "").strip())
        return

    script = Path(__file__).resolve().parent / "build_owl_correspondence.py"
    if not script.exists():
        print(f"ERROR: real implementation not found at {script}", file=sys.stderr)
        sys.exit(1)

    print(f"Delegating to {script}...")
    result = subprocess.run([sys.executable, str(script)], cwd=script.parent.parent)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
