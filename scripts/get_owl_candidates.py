#!/usr/bin/env python3
"""
Get OWL Paradox Candidates - Simple Interface

This script provides a simple interface to retrieve single candidate OWL entries
and their index, as requested in the user's task.

Usage:
    python scripts/get_owl_candidates.py [index]
    
    If no index is provided, returns all candidates.
    If index is provided (1-18), returns that specific candidate.

Examples:
    python scripts/get_owl_candidates.py
    python scripts/get_owl_candidates.py 1
    python scripts/get_owl_candidates.py 3
"""

from typing import Dict, List, Optional
import sys

# Manual short-list of the most relevant paradox candidates
SHORT_LIST = [
    {"index": 1, "owl_key": "ReserveGuard", "nl_value": "reserve guard", "cd_step": 2, "reasoning": "Known OWL key straddling CD 2->3 boundary"},
    {"index": 2, "owl_key": "MarketClosure", "nl_value": "market closure", "cd_step": 3, "reasoning": "Known OWL key straddling CD 2->3 boundary"},
    {"index": 3, "owl_key": "AntiCoherentPair", "nl_value": "anti coherent pair", "cd_step": 4, "reasoning": "Explicitly classical vs paraconsistent pair"},
    {"index": 4, "owl_key": "SelfCheckNorm", "nl_value": "self check norm", "cd_step": 3, "reasoning": "Self-reference creates paradox signature"},
    {"index": 5, "owl_key": "NonAssociativeBudget", "nl_value": "non associative budget", "cd_step": 3, "reasoning": "Non-associative structure with budget semantics"},
    {"index": 6, "owl_key": "SplitOctonion", "nl_value": "split octonion", "cd_step": 3, "reasoning": "Split algebra structure (non-associative)"},
    {"index": 7, "owl_key": "SplitQuat", "nl_value": "split quat", "cd_step": 3, "reasoning": "Split quaternion structure"},
    {"index": 8, "owl_key": "LogicContraction", "nl_value": "logic contraction", "cd_step": 3, "reasoning": "Logic type contraction mechanism"},
    {"index": 9, "owl_key": "LogicTranslation", "nl_value": "logic translation", "cd_step": 3, "reasoning": "Translation between logic types"},
    {"index": 10, "owl_key": "ConcreteReactionlessShift", "nl_value": "concrete reactionless shift", "cd_step": 3, "reasoning": "Reactionless shift in concrete structures"},
    {"index": 11, "owl_key": "UngroundedNL", "nl_value": "ungrounded NL", "cd_step": 3, "reasoning": "Ungrounded natural language processing"},
    {"index": 12, "owl_key": "VeryBigBox", "nl_value": "very big box", "cd_step": 3, "reasoning": "Boundary-pushing structure"},
    {"index": 13, "owl_key": "BarberParadox", "nl_value": "barber paradox", "cd_step": 4, "reasoning": "Classic self-referential paradox"},
    {"index": 14, "owl_key": "LiarParadox", "nl_value": "liar paradox", "cd_step": 4, "reasoning": "Classic self-referential paradox"},
    {"index": 15, "owl_key": "RussellsParadox", "nl_value": "russell's paradox", "cd_step": 4, "reasoning": "Set theory paradox"},
    {"index": 16, "owl_key": "SoritesParadox", "nl_value": "sorites paradox", "cd_step": 4, "reasoning": "Vagueness paradox"},
    {"index": 17, "owl_key": "TemporalParadox", "nl_value": "temporal paradox", "cd_step": 4, "reasoning": "Time-based self-reference paradox"},
    {"index": 18, "owl_key": "ProofParadox", "nl_value": "proof paradox", "cd_step": 4, "reasoning": "Proof-theoretic paradox"},
]


def get_candidate(index: int) -> Optional[Dict]:
    """Get a single candidate by index (1-based)."""
    if 1 <= index <= len(SHORT_LIST):
        return SHORT_LIST[index - 1]
    return None


def get_all_candidates() -> List[Dict]:
    """Get all candidates."""
    return SHORT_LIST


def format_candidate(candidate: Dict) -> str:
    """Format a candidate for display."""
    return f"""Candidate {candidate['index']}:
  OWL_KEY: {candidate['owl_key']}
  NL_VALUE: {candidate['nl_value']}
  CD_STEP: {candidate['cd_step']}
  REASONING: {candidate['reasoning']}
"""


def main():
    """Main entry point."""
    if len(sys.argv) == 1:
        # Return all candidates
        print("OWL PARADOX CANDIDATES - COMPLETE LIST")
        print("=" * 60)
        for candidate in get_all_candidates():
            print(format_candidate(candidate))
    else:
        # Return specific candidate
        try:
            index = int(sys.argv[1])
            candidate = get_candidate(index)
            if candidate:
                print(format_candidate(candidate))
            else:
                print(f"Error: Candidate index {index} not found. Valid range: 1-{len(SHORT_LIST)}")
                sys.exit(1)
        except ValueError:
            print("Error: Please provide a valid integer index.")
            sys.exit(1)


if __name__ == "__main__":
    main()