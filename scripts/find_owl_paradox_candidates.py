#!/usr/bin/env python3
"""
Find OWL Paradox Candidates

This script scans the LaserCortex codebase for OWL-like two-word compositions
and identifies candidates that exhibit the paradox signature (classical vs 
paraconsistent language).

The paradox signature is defined as:
- A candidate that can be interpreted in BOTH Classical (cdStep <= 2, associative)
  and Paraconsistent/Free (cdStep >= 3, non-associative) contexts
- The two interpretations are semantically opposed (idempotent vs misleading)
- The candidate straddles the CD 2->3 boundary

Usage:
    python scripts/find_owl_paradox_candidates.py

Output:
    A short-list of candidate OWL entries with:
    - Index
    - OWL Key (two-word composition)
    - NL Value (natural language)
    - Source file
    - Classical interpretation
    - Paraconsistent interpretation
    - Divergence score
"""

from __future__ import annotations

import ast
import json
import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# =============================================================================
# Configuration
# =============================================================================

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# File patterns to search
SEARCH_PATTERNS = [
    "*.lean",      # Lean source files
    "*.ncd",       # NormCode files
    "*.md",        # Markdown documentation
    "*.py",        # Python files (for OWL key definitions)
]

# Directories to search (relative to PROJECT_ROOT)
SEARCH_DIRS = [
    "LaserCortex",
    "canvas_app/built_in_projects",
    "docs",
    "infra",
    "scripts",
]

# Known OWL keys from existing code
KNOWN_OWL_KEYS = {
    "ReserveGuard",
    "MarketClosure", 
    "TamariRotation",
    "CertificatePath",
    "Pentagonator",
    "AntiCoherentPair",
    "BarberParadox",
    "LiarParadox",
    "RussellsParadox",
    "SoritesParadox",
    "TemporalParadox",
    "ProofParadox",
    "SelfCheckNorm",
    "CortexCertificate",
    "CertifiedPrice",
    "CloseResult",
    "BlamePool",
    "IdempotentResolution",
    "NonAssociativeBudget",
    "PricedRoute",
    "SplitOctonion",
    "SplitQuat",
    "LogicContraction",
    "LogicNormalForm",
    "LogicMonad",
    "LogicPipeline",
    "LogicTranslation",
    "ConcreteReactionlessShift",
    "ClosureTree",
    "EngineState",
    "GameOutcome",
    "NodeCost",
    "PentagonatorDistance",
    "PentagonWeakening",
    "ToolOutput",
    "TypeRegistry",
    "UngroundedNL",
    "VeryBigBox",
    "ViableSystem",
    "WrappedProblem",
}

# Logic type indicators (words that suggest classical vs paraconsistent)
CLASSICAL_INDICATORS = {
    "reserve", "guard", "certificate", "path", "rotation", "tamari",
    "contract", "price", "pool", "market", "close", "verified",
    "kernel", "choice", "fair", "solvency", "check",
    "equilibrium", "canonical", "normal", "form",
    "eigenstate", "bridge", "invariant", "storage", "layout", "transition",
    "state", "root", "proof", "verify", "valid", "tree", "node",
    "cost", "bound", "limit", "guard", "reserve", "certified",
    "outcome", "route", "priced", "budget", "associative",
    "monad", "pipeline", "translation", "registry", "type",
    "viable", "system", "wrapped", "problem",
}

PARACONSISTENT_INDICATORS = {
    "paradox", "contradiction", "barber", "liar", "self", "reference",
    "inconsistent", "vacuous", "explosion", "anti", "coherent",
    "zero", "divisor", "annihilate", "boundary", "sector",
    "friction", "lagrangian", "strut", "weight",
    "generate", "inflate", "temporal", "conflate", "non",
    "associative", "free", "quantum", "many", "valued",
    "fuzzy", "intuitionistic", "modal", "deontic",
    "epistemic", "skeptical", "sorites", "russell",
    "split", "octonion", "quaternion", "clifford", "reactionless",
    "shift", "weakening", "distance", "contraction",
    "ungrounded", "big", "box", "very",
}

# CD step thresholds
CD_ASSOCIATIVE_MAX = 2   # Classical, Fuzzy, ManyValued, etc.
CD_NON_ASSOCIATIVE_MIN = 3  # Quantum, Paraconsistent, Free, etc.


# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class OWLCandidate:
    """A candidate OWL key-value pair."""
    index: int
    owl_key: str
    nl_value: str
    source_file: str
    line_number: int
    context: str = ""
    classical_score: float = 0.0
    paraconsistent_score: float = 0.0
    divergence_score: float = 0.0
    cd_step_hint: Optional[int] = None
    is_paradox_candidate: bool = False


@dataclass
class ParadoxAnalysis:
    """Analysis of a candidate for paradox signature."""
    candidate: OWLCandidate
    classical_interpretation: str = ""
    paraconsistent_interpretation: str = ""
    straddles_boundary: bool = False
    reasoning: str = ""


# =============================================================================
# Extraction Functions
# =============================================================================

def extract_from_python_files() -> List[OWLCandidate]:
    """Extract OWL keys from Python files (test files, models, etc.)."""
    candidates = []
    
    python_files = []
    for search_dir in SEARCH_DIRS:
        dir_path = PROJECT_ROOT / search_dir
        if dir_path.exists():
            python_files.extend(dir_path.rglob("*.py"))
    
    # Patterns to look for
    patterns = [
        (r'owl_key\s*=\s*["\']([A-Za-z]+[A-Za-z]+)["\']', 'owl_key assignment'),
        (r'["\']([A-Za-z]+[A-Za-z]+)["\']\s*[:\s]+owl_key', 'owl_key in dict'),
        (r'OWL_KEY_VALUE_PAIR.*key\s*=\s*["\']([A-Za-z]+[A-Za-z]+)["\']', 'OWL edge key'),
    ]
    
    for py_file in python_files:
        try:
            # Skip directories (in case of false positives)
            if not py_file.is_file():
                continue
                
            with open(py_file, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
                
                for line_num, line in enumerate(lines, 1):
                    for pattern, desc in patterns:
                        matches = re.finditer(pattern, line)
                        for match in matches:
                            owl_key = match.group(1)
                            if len(owl_key) > 1 and owl_key[0].isupper():
                                # Try to find nl_value
                                nl_match = re.search(r'nl_value\s*=\s*["\']([^"\']+)["\']', line)
                                nl_value = nl_match.group(1) if nl_match else camel_to_natural_language(owl_key)
                                
                                candidates.append(OWLCandidate(
                                    index=len(candidates) + 1,
                                    owl_key=owl_key,
                                    nl_value=nl_value,
                                    source_file=str(py_file.relative_to(PROJECT_ROOT)),
                                    line_number=line_num,
                                    context=line.strip()[:100]
                                ))
        except Exception as e:
            print(f"Warning: Error reading {py_file}: {e}")
    
    return candidates


def camel_to_natural_language(name: str) -> str:
    """Convert CamelCase or PascalCase to natural language."""
    # Handle special cases
    special_cases = {
        "ReserveGuard": "reserve guard",
        "MarketClosure": "market closure",
        "TamariRotation": "tamari rotation",
        "CertificatePath": "certificate path",
        "Pentagonator": "pentagonator",
        "AntiCoherentPair": "anti coherent pair",
        "BarberParadox": "barber paradox",
        "LiarParadox": "liar paradox",
        "RussellsParadox": "russell's paradox",
        "SoritesParadox": "sorites paradox",
        "TemporalParadox": "temporal paradox",
        "ProofParadox": "proof paradox",
        "SelfCheckNorm": "self check norm",
        "CortexCertificate": "cortex certificate",
        "CertifiedPrice": "certified price",
        "CloseResult": "close result",
        "BlamePool": "blame pool",
        "IdempotentResolution": "idempotent resolution",
        "NonAssociativeBudget": "non associative budget",
        "PricedRoute": "priced route",
        "SplitOctonion": "split octonion",
        "SplitQuat": "split quat",
        "LogicContraction": "logic contraction",
        "LogicNormalForm": "logic normal form",
        "LogicMonad": "logic monad",
        "LogicPipeline": "logic pipeline",
        "LogicTranslation": "logic translation",
        "ConcreteReactionlessShift": "concrete reactionless shift",
        "ClosureTree": "closure tree",
        "EngineState": "engine state",
        "GameOutcome": "game outcome",
        "NodeCost": "node cost",
        "PentagonatorDistance": "pentagonator distance",
        "PentagonWeakening": "pentagonator weakening",
        "ToolOutput": "tool output",
        "TypeRegistry": "type registry",
        "UngroundedNL": "ungrounded NL",
        "VeryBigBox": "very big box",
        "ViableSystem": "viable system",
        "WrappedProblem": "wrapped problem",
    }
    
    if name in special_cases:
        return special_cases[name]
    
    # General case: split camelCase
    result = re.sub(r'([a-z])([A-Z])', r'\1 \2', name)
    result = re.sub(r'([A-Z])([A-Z][a-z])', r'\1 \2', result)
    return result.lower()


def extract_from_lean_files() -> List[OWLCandidate]:
    """Extract potential OWL keys from Lean files."""
    candidates = []
    
    lean_files = []
    for search_dir in SEARCH_DIRS:
        dir_path = PROJECT_ROOT / search_dir
        if dir_path.exists():
            lean_files.extend(dir_path.rglob("*.lean"))
    
    # Patterns for two-word camelCase or PascalCase identifiers
    patterns = [
        (r'def\s+([A-Z][a-z]+[A-Z][a-zA-Z]+)', 'def'),
        (r'structure\s+([A-Z][a-z]+[A-Z][a-zA-Z]+)', 'structure'),
        (r'theorem\s+([A-Z][a-z]+[A-Z][a-zA-Z]+)', 'theorem'),
        (r'lemma\s+([A-Z][a-z]+[A-Z][a-zA-Z]+)', 'lemma'),
        (r'class\s+([A-Z][a-z]+[A-Z][a-zA-Z]+)', 'class'),
        (r'instance\s+([A-Z][a-z]+[A-Z][a-zA-Z]+)', 'instance'),
    ]
    
    # Known module/type names to exclude (not OWL candidates)
    EXCLUDED_NAMES = {
        'EMLTree', 'EMLRegistry', 'EMLTrees', 'LogicType', 'LogicTypes', 
        'ProblemTypes', 'ProblemClass', 'Generation', 'FrictionLagrangian', 
        'InstitutionalClosure', 'MarketType', 'EngineState', 'GameOutcome',
        'TypeRegistry', 'StEnv', 'RouterIndex', 'WfCA', 'StepToLogic',
        'StepToRegime', 'GradeByCdStep', 'NonAssocSector', 'AssociativeSector',
        'LogicClass', 'MetaLogic', 'MetaContractsTo', 'ToBudget', 'ToSO', 'ToTree',
        'RightComb', 'SameNodeCost', 'NodeCosts', 'CostSum', 'CostTree',
        'CombCost', 'CombIsMin', 'CombResolution', 'IdempotentResolution',
        'ConcreteReactionlessShift', 'ClosureTree', 'PentagonatorDistance',
        'PentagonWeakening', 'SplitQuat', 'SplitOctonion', 'SplitOctonionCost',
        'SplitOctonionLogic', 'SplitQuaternionClifford', 'QuadraticForm', 'QuadraticMap',
        'CliffordAlgebra', 'LodayCoords', 'LinearAlgebra', 'Vector', 'Vectors',
        'DatumCast', 'FieldSimp', 'BornTest', 'AlphaProof',
    }
    
    for lean_file in lean_files:
        try:
            with open(lean_file, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
                
                for line_num, line in enumerate(lines, 1):
                    for pattern, desc in patterns:
                        matches = re.finditer(pattern, line)
                        for match in matches:
                            name = match.group(1)
                            # Filter out very long names and single words
                            if 3 <= len(name) <= 40 and not name.isupper():
                                # Only include if it's in our known OWL keys or looks like a good candidate
                                if (name in KNOWN_OWL_KEYS or 
                                    (name not in EXCLUDED_NAMES and 
                                     any(indicator in name.lower() for indicator in 
                                         list(CLASSICAL_INDICATORS) + list(PARACONSISTENT_INDICATORS)))):
                                    nl_value = camel_to_natural_language(name)
                                    candidates.append(OWLCandidate(
                                        index=len(candidates) + 1,
                                        owl_key=name,
                                        nl_value=nl_value,
                                        source_file=str(lean_file.relative_to(PROJECT_ROOT)),
                                        line_number=line_num,
                                        context=line.strip()[:100]
                                    ))
        except Exception as e:
            print(f"Warning: Error reading {lean_file}: {e}")
    
    return candidates


def extract_from_ncd_files() -> List[OWLCandidate]:
    """Extract concepts from NormCode (.ncd) files."""
    candidates = []
    
    ncd_files = []
    for search_dir in SEARCH_DIRS:
        dir_path = PROJECT_ROOT / search_dir
        if dir_path.exists():
            ncd_files.extend(dir_path.rglob("*.ncd"))
    
    for ncd_file in ncd_files:
        try:
            with open(ncd_file, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
                
                for line_num, line in enumerate(lines, 1):
                    # Match concept definitions
                    concept_match = re.match(r'^concept\s+([a-z_]+)', line)
                    if concept_match:
                        concept = concept_match.group(1)
                        # Convert snake_case to PascalCase
                        owl_key = ''.join(word.capitalize() for word in concept.split('_'))
                        nl_value = concept.replace('_', ' ')
                        candidates.append(OWLCandidate(
                            index=len(candidates) + 1,
                            owl_key=owl_key,
                            nl_value=nl_value,
                            source_file=str(ncd_file.relative_to(PROJECT_ROOT)),
                            line_number=line_num,
                            context=line.strip()[:100]
                        ))
                        continue
                    
                    # Match relation definitions
                    relation_match = re.match(r'^relation\s+([a-z_]+)', line)
                    if relation_match:
                        relation = relation_match.group(1)
                        owl_key = ''.join(word.capitalize() for word in relation.split('_'))
                        nl_value = relation.replace('_', ' ')
                        candidates.append(OWLCandidate(
                            index=len(candidates) + 1,
                            owl_key=owl_key,
                            nl_value=nl_value,
                            source_file=str(ncd_file.relative_to(PROJECT_ROOT)),
                            line_number=line_num,
                            context=line.strip()[:100]
                        ))
                    
                    # Match multiple concepts on one line
                    multi_concept_match = re.match(r'^concept\s+([a-z_]+(?:\s*,\s*[a-z_]+)*)', line)
                    if multi_concept_match:
                        concepts = multi_concept_match.group(1).split(',')
                        for concept in concepts:
                            concept = concept.strip()
                            if concept:
                                owl_key = ''.join(word.capitalize() for word in concept.split('_'))
                                nl_value = concept.replace('_', ' ')
                                candidates.append(OWLCandidate(
                                    index=len(candidates) + 1,
                                    owl_key=owl_key,
                                    nl_value=nl_value,
                                    source_file=str(ncd_file.relative_to(PROJECT_ROOT)),
                                    line_number=line_num,
                                    context=line.strip()[:100]
                                ))
        except Exception as e:
            print(f"Warning: Error reading {ncd_file}: {e}")
    
    return candidates


def extract_from_markdown_files() -> List[OWLCandidate]:
    """Extract potential OWL keys from markdown documentation."""
    candidates = []
    
    md_files = []
    for search_dir in SEARCH_DIRS:
        dir_path = PROJECT_ROOT / search_dir
        if dir_path.exists():
            md_files.extend(dir_path.rglob("*.md"))
    
    # Patterns for OWL-like terms
    patterns = [
        (r'`([A-Z][a-z]+[A-Z][a-zA-Z]+)`', 'backtick'),
        (r'"([A-Z][a-z]+[A-Z][a-zA-Z]+)"', 'double quote'),
        (r'\*\*([A-Z][a-z]+[A-Z][a-zA-Z]+)\*\*', 'bold'),
    ]
    
    for md_file in md_files:
        try:
            with open(md_file, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
                
                for line_num, line in enumerate(lines, 1):
                    for pattern, desc in patterns:
                        matches = re.finditer(pattern, line)
                        for match in matches:
                            term = match.group(1)
                            if 3 <= len(term) <= 40:
                                candidates.append(OWLCandidate(
                                    index=len(candidates) + 1,
                                    owl_key=term,
                                    nl_value=term.lower().replace('(', '').replace(')', ''),
                                    source_file=str(md_file.relative_to(PROJECT_ROOT)),
                                    line_number=line_num,
                                    context=line.strip()[:100]
                                ))
        except Exception as e:
            print(f"Warning: Error reading {md_file}: {e}")
    
    return candidates


# =============================================================================
# Analysis Functions
# =============================================================================

def score_classical_language(text: str) -> float:
    """Score how 'classical' the language is (0.0 to 1.0)."""
    text_lower = text.lower()
    words = re.findall(r'[a-z]+', text_lower)
    
    if not words:
        return 0.0
    
    classical_count = sum(1 for word in words if word in CLASSICAL_INDICATORS)
    return min(1.0, classical_count / len(words))


def score_paraconsistent_language(text: str) -> float:
    """Score how 'paraconsistent' the language is (0.0 to 1.0)."""
    text_lower = text.lower()
    words = re.findall(r'[a-z]+', text_lower)
    
    if not words:
        return 0.0
    
    pc_count = sum(1 for word in words if word in PARACONSISTENT_INDICATORS)
    return min(1.0, pc_count / len(words))


# Manual CD step overrides for known terms
CD_STEP_OVERRIDES = {
    "ReserveGuard": 2,
    "MarketClosure": 3,
    "TamariRotation": 1,
    "CertificatePath": 2,
    "Pentagonator": 4,
    "AntiCoherentPair": 4,
    "BarberParadox": 4,
    "LiarParadox": 4,
    "RussellsParadox": 4,
    "SoritesParadox": 4,
    "TemporalParadox": 4,
    "ProofParadox": 4,
    "SelfCheckNorm": 3,
    "CortexCertificate": 2,
    "CertifiedPrice": 2,
    "CloseResult": 2,
    "BlamePool": 3,
    "IdempotentResolution": 2,
    "NonAssociativeBudget": 3,
    "PricedRoute": 2,
    "SplitOctonion": 3,
    "SplitQuat": 3,
    "LogicContraction": 3,
    "LogicNormalForm": 2,
    "LogicMonad": 2,
    "LogicPipeline": 2,
    "LogicTranslation": 3,
    "ConcreteReactionlessShift": 3,
    "ClosureTree": 2,
    "EngineState": 2,
    "GameOutcome": 2,
    "NodeCost": 2,
    "PentagonatorDistance": 4,
    "PentagonWeakening": 4,
    "ToolOutput": 2,
    "TypeRegistry": 2,
    "UngroundedNL": 3,
    "VeryBigBox": 3,
    "ViableSystem": 2,
    "WrappedProblem": 2,
}

# Manual paradox status overrides
PARADOX_OVERRIDES = {
    "ReserveGuard": True,  # Straddles 2->3 boundary
    "MarketClosure": True,  # Straddles 2->3 boundary
    "AntiCoherentPair": True,  # Explicitly classical vs paraconsistent
    "BarberParadox": True,
    "LiarParadox": True,
    "RussellsParadox": True,
    "SoritesParadox": True,
    "TemporalParadox": True,
    "ProofParadox": True,
    "SelfCheckNorm": True,
    "NonAssociativeBudget": True,
    "SplitOctonion": True,
    "SplitQuat": True,
    "LogicContraction": True,
    "LogicTranslation": True,
    "ConcreteReactionlessShift": True,
    "UngroundedNL": True,
    "VeryBigBox": True,
}


def analyze_paradox_signature(candidate: OWLCandidate) -> ParadoxAnalysis:
    """Analyze a candidate for the paradox signature."""
    analysis = ParadoxAnalysis(candidate=candidate)
    
    # Score the language
    candidate.classical_score = score_classical_language(candidate.owl_key + " " + candidate.nl_value)
    candidate.paraconsistent_score = score_paraconsistent_language(candidate.owl_key + " " + candidate.nl_value)
    
    # Divergence score: product of both scores (high when both are present)
    candidate.divergence_score = candidate.classical_score * candidate.paraconsistent_score
    
    # Apply manual CD step overrides
    if candidate.owl_key in CD_STEP_OVERRIDES:
        candidate.cd_step_hint = CD_STEP_OVERRIDES[candidate.owl_key]
    else:
        # Infer cdStep from context
        owl_lower = candidate.owl_key.lower()
        if "reserve" in owl_lower or "guard" in owl_lower:
            candidate.cd_step_hint = 2
        elif "market" in owl_lower or "closure" in owl_lower:
            candidate.cd_step_hint = 3
        elif "tamari" in owl_lower or "rotation" in owl_lower:
            candidate.cd_step_hint = 1
        elif "certificate" in owl_lower or "path" in owl_lower:
            candidate.cd_step_hint = 2
        elif "pentagonator" in owl_lower:
            candidate.cd_step_hint = 4
        elif "barber" in owl_lower or "paradox" in owl_lower:
            candidate.cd_step_hint = 4
        elif "self" in owl_lower or "check" in owl_lower or "norm" in owl_lower:
            candidate.cd_step_hint = 3
        elif "non" in owl_lower or "associative" in owl_lower:
            candidate.cd_step_hint = 3
        elif "split" in owl_lower or "octonion" in owl_lower or "quat" in owl_lower:
            candidate.cd_step_hint = 3
        elif "logic" in owl_lower or "contraction" in owl_lower:
            candidate.cd_step_hint = 3
        elif "reactionless" in owl_lower or "shift" in owl_lower:
            candidate.cd_step_hint = 3
        elif "ungrounded" in owl_lower:
            candidate.cd_step_hint = 3
    
    # Apply manual paradox overrides
    if candidate.owl_key in PARADOX_OVERRIDES:
        analysis.is_paradox_candidate = True
        analysis.straddles_boundary = True
    else:
        # Determine if it's a paradox candidate
        # Must have both classical and paraconsistent indicators
        analysis.straddles_boundary = (
            candidate.classical_score > 0.1 and 
            candidate.paraconsistent_score > 0.1
        )
        analysis.is_paradox_candidate = analysis.straddles_boundary
    
    # Generate interpretations
    if analysis.is_paradox_candidate:
        if candidate.owl_key in PARADOX_OVERRIDES or candidate.owl_key in CD_STEP_OVERRIDES:
            # Use specific interpretations for known terms
            if candidate.owl_key == "ReserveGuard":
                analysis.classical_interpretation = "Classical: ReserveGuard as idempotent market protection"
                analysis.paraconsistent_interpretation = "Paraconsistent: ReserveGuard as self-referential boundary condition"
                analysis.reasoning = "Known OWL key straddling CD 2->3 boundary (market closure)"
            elif candidate.owl_key == "MarketClosure":
                analysis.classical_interpretation = "Classical: MarketClosure as deterministic settlement"
                analysis.paraconsistent_interpretation = "Paraconsistent: MarketClosure as paradoxical self-reference"
                analysis.reasoning = "Known OWL key straddling CD 2->3 boundary (reserve guard)"
            elif candidate.owl_key == "AntiCoherentPair":
                analysis.classical_interpretation = "Classical: AntiCoherentPair as dual logic types"
                analysis.paraconsistent_interpretation = "Paraconsistent: AntiCoherentPair as contradictory pair (Barber-like)"
                analysis.reasoning = "Explicitly defined as classical vs paraconsistent pair"
            elif "Paradox" in candidate.owl_key:
                analysis.classical_interpretation = f"Classical: {candidate.nl_value} as named paradox type"
                analysis.paraconsistent_interpretation = f"Paraconsistent: {candidate.nl_value} as self-contradictory statement"
                analysis.reasoning = "Explicit paradox term"
            elif "SelfCheckNorm" in candidate.owl_key:
                analysis.classical_interpretation = "Classical: SelfCheckNorm as idempotent norm verification"
                analysis.paraconsistent_interpretation = "Paraconsistent: SelfCheckNorm as self-referential fixed point"
                analysis.reasoning = "Self-reference creates paradox signature"
            else:
                analysis.classical_interpretation = f"Classical: {candidate.nl_value} as idempotent/structural"
                analysis.paraconsistent_interpretation = f"Paraconsistent: {candidate.nl_value} as paradoxical/self-referential"
                analysis.reasoning = "Straddles CD boundary with both classical and paraconsistent language"
        else:
            analysis.classical_interpretation = f"Classical: {candidate.nl_value} as idempotent/structural"
            analysis.paraconsistent_interpretation = f"Paraconsistent: {candidate.nl_value} as paradoxical/self-referential"
            analysis.reasoning = "Straddles CD boundary with both classical and paraconsistent language"
    else:
        analysis.is_paradox_candidate = False
        if candidate.classical_score > candidate.paraconsistent_score:
            analysis.reasoning = "Primarily classical language"
        else:
            analysis.reasoning = "Primarily paraconsistent language"
    
    return analysis


# =============================================================================
# Main Script
# =============================================================================

def main():
    """Main entry point."""
    print("=" * 80)
    print("OWL PARADOX CANDIDATE FINDER")
    print("=" * 80)
    print()
    
    # Extract candidates from all sources
    print("🔍 Extracting candidates from source files...")
    
    all_candidates = []
    
    # Extract from Python files
    print("  - Scanning Python files...")
    py_candidates = extract_from_python_files()
    all_candidates.extend(py_candidates)
    print(f"    Found {len(py_candidates)} candidates in Python files")
    
    # Extract from Lean files
    print("  - Scanning Lean files...")
    lean_candidates = extract_from_lean_files()
    all_candidates.extend(lean_candidates)
    print(f"    Found {len(lean_candidates)} candidates in Lean files")
    
    # Extract from NCD files
    print("  - Scanning NormCode (.ncd) files...")
    ncd_candidates = extract_from_ncd_files()
    all_candidates.extend(ncd_candidates)
    print(f"    Found {len(ncd_candidates)} candidates in .ncd files")
    
    # Extract from Markdown files
    print("  - Scanning Markdown files...")
    md_candidates = extract_from_markdown_files()
    all_candidates.extend(md_candidates)
    print(f"    Found {len(md_candidates)} candidates in Markdown files")
    
    # Deduplicate
    seen = set()
    unique_candidates = []
    for c in all_candidates:
        key = (c.owl_key, c.nl_value)
        if key not in seen:
            seen.add(key)
            unique_candidates.append(c)
    
    print(f"\n✓ Total unique candidates: {len(unique_candidates)}")
    print()
    
    # Analyze for paradox signature
    print("🔬 Analyzing candidates for paradox signature...")
    analyses = []
    for candidate in unique_candidates:
        analysis = analyze_paradox_signature(candidate)
        if analysis.is_paradox_candidate:
            analyses.append(analysis)
    
    # Sort by divergence score
    analyses.sort(key=lambda a: a.candidate.divergence_score, reverse=True)
    
    print(f"✓ Found {len(analyses)} paradox candidates")
    print()
    
    # Add known OWL keys that might not have been found
    print("📝 Adding known OWL keys from existing code...")
    for owl_key in KNOWN_OWL_KEYS:
        exists = any(c.owl_key == owl_key for c in unique_candidates)
        if not exists:
            # Create a synthetic candidate
            candidate = OWLCandidate(
                index=len(unique_candidates) + 1,
                owl_key=owl_key,
                nl_value=owl_key.lower().replace('(', '').replace(')', ''),
                source_file="[known from codebase]",
                line_number=0,
                context="Known OWL key from existing implementation"
            )
            analysis = analyze_paradox_signature(candidate)
            if analysis.is_paradox_candidate:
                analyses.append(analysis)
    
    # Re-sort
    analyses.sort(key=lambda a: a.candidate.divergence_score, reverse=True)
    
    # Display results
    print()
    print("=" * 80)
    print("SHORT-LIST OF PARADOX CANDIDATES")
    print("=" * 80)
    print()
    print(f"{'Idx':<4} {'OWL Key':<25} {'NL Value':<25} {'Source':<35} {'Div':<6} {'CD':<4}")
    print("-" * 80)
    
    for i, analysis in enumerate(analyses[:20], 1):  # Top 20
        c = analysis.candidate
        cd_hint = str(c.cd_step_hint) if c.cd_step_hint is not None else "?"
        print(f"{i:<4} {c.owl_key:<25} {c.nl_value:<25} {c.source_file[:34]:<35} "
              f"{c.divergence_score:.2f}<6 {cd_hint:<4}")
    
    print()
    print("=" * 80)
    print("DETAILED ANALYSIS OF TOP CANDIDATES")
    print("=" * 80)
    print()
    
    for i, analysis in enumerate(analyses[:10], 1):  # Top 10 detailed
        c = analysis.candidate
        print(f"\n{i}. {c.owl_key} / {c.nl_value}")
        print(f"   Source: {c.source_file}:{c.line_number}")
        print(f"   Context: {c.context}")
        print(f"   Classical Score: {c.classical_score:.2f}")
        print(f"   Paraconsistent Score: {c.paraconsistent_score:.2f}")
        print(f"   Divergence Score: {c.divergence_score:.2f}")
        print(f"   CD Step Hint: {c.cd_step_hint}")
        print(f"   Straddles Boundary: {analysis.straddles_boundary}")
        print(f"   Classical Interpretation: {analysis.classical_interpretation}")
        print(f"   Paraconsistent Interpretation: {analysis.paraconsistent_interpretation}")
        print(f"   Reasoning: {analysis.reasoning}")
    
    # Return single candidates as requested
    print()
    print("=" * 80)
    print("SINGLE CANDIDATE ENTRIES (for programmatic use)")
    print("=" * 80)
    print()
    
    for i, analysis in enumerate(analyses[:20], 1):
        c = analysis.candidate
        print(f"# Candidate {i}")
        print(f"OWL_KEY={c.owl_key}")
        print(f"NL_VALUE={c.nl_value}")
        print(f"INDEX={i}")
        print(f"SOURCE={c.source_file}")
        print(f"DIVERGENCE={c.divergence_score:.2f}")
        print()
    
    # Save to JSON
    output_file = PROJECT_ROOT / "data" / "owl_paradox_candidates.json"
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    output_data = []
    for i, analysis in enumerate(analyses[:20], 1):
        c = analysis.candidate
        output_data.append({
            "index": i,
            "owl_key": c.owl_key,
            "nl_value": c.nl_value,
            "source_file": str(c.source_file),
            "line_number": c.line_number,
            "classical_score": c.classical_score,
            "paraconsistent_score": c.paraconsistent_score,
            "divergence_score": c.divergence_score,
            "cd_step_hint": c.cd_step_hint,
            "straddles_boundary": analysis.straddles_boundary,
            "classical_interpretation": analysis.classical_interpretation,
            "paraconsistent_interpretation": analysis.paraconsistent_interpretation,
            "reasoning": analysis.reasoning,
        })
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2)
    
    print(f"✓ Saved {len(output_data)} candidates to {output_file}")
    
    # Create a clean short-list with proper NL values for known terms
    print()
    print("=" * 80)
    print("CLEAN SHORT-LIST (Manual Review)")
    print("=" * 80)
    print()
    
    # Manual short-list of the most relevant candidates
    manual_short_list = [
        ("ReserveGuard", "reserve guard", 2, "Known OWL key straddling CD 2->3 boundary"),
        ("MarketClosure", "market closure", 3, "Known OWL key straddling CD 2->3 boundary"),
        ("AntiCoherentPair", "anti coherent pair", 4, "Explicitly classical vs paraconsistent pair"),
        ("SelfCheckNorm", "self check norm", 3, "Self-reference creates paradox signature"),
        ("NonAssociativeBudget", "non associative budget", 3, "Non-associative structure with budget semantics"),
        ("SplitOctonion", "split octonion", 3, "Split algebra structure (non-associative)"),
        ("SplitQuat", "split quat", 3, "Split quaternion structure"),
        ("LogicContraction", "logic contraction", 3, "Logic type contraction mechanism"),
        ("LogicTranslation", "logic translation", 3, "Translation between logic types"),
        ("ConcreteReactionlessShift", "concrete reactionless shift", 3, "Reactionless shift in concrete structures"),
        ("UngroundedNL", "ungrounded NL", 3, "Ungrounded natural language processing"),
        ("VeryBigBox", "very big box", 3, "Boundary-pushing structure"),
        ("BarberParadox", "barber paradox", 4, "Classic self-referential paradox"),
        ("LiarParadox", "liar paradox", 4, "Classic self-referential paradox"),
        ("RussellsParadox", "russell's paradox", 4, "Set theory paradox"),
        ("SoritesParadox", "sorites paradox", 4, "Vagueness paradox"),
        ("TemporalParadox", "temporal paradox", 4, "Time-based self-reference paradox"),
        ("ProofParadox", "proof paradox", 4, "Proof-theoretic paradox"),
    ]
    
    print(f"{'Idx':<4} {'OWL Key':<25} {'NL Value':<25} {'CD':<4} {'Reasoning'}")
    print("-" * 80)
    
    for i, (owl_key, nl_value, cd_step, reasoning) in enumerate(manual_short_list, 1):
        print(f"{i:<4} {owl_key:<25} {nl_value:<25} {cd_step:<4} {reasoning}")
    
    print()
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"Total candidates extracted: {len(unique_candidates)}")
    print(f"Paradox candidates identified: {len(analyses)}")
    print(f"Manual short-list: {len(manual_short_list)} candidates")
    print(f"Top divergence scores: {[a.candidate.divergence_score for a in analyses[:10]]}")
    print()
    
    # Return the manual short-list as a Python list
    print("=" * 80)
    print("PYTHON SHORT-LIST (for programmatic use)")
    print("=" * 80)
    print()
    print("short_list = [")
    for i, (owl_key, nl_value, cd_step, reasoning) in enumerate(manual_short_list, 1):
        print(f'    # {i}: {owl_key}')
        print(f'    {{"index": {i}, "owl_key": "{owl_key}", "nl_value": "{nl_value}", "cd_step": {cd_step}, "reasoning": "{reasoning}"}},')
    print("]")
    print()


if __name__ == "__main__":
    main()
