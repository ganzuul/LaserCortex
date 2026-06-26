#!/usr/bin/env python3
"""Milestone 0: Bootstrap a cross-ontology atom vocabulary.

Reads reasoning traces, extracts verbs, looks them up in local FrameNet and
VerbNet corpora, mines manpage descriptions for the tools that appear in
traces, and parses PROV-O + P-PLAN class/property definitions.

Outputs data/reinforcement_atoms.json — a catalogue of single-word atoms that
will become the columns of the trace × atom activation matrix in Milestone 1.

Each atom is NMF-friendly: it carries a unique id, a source ontology, a label,
and a textual description used for embeddings and human inspection.

Usage (must be run inside the project venv so nltk/rdflib are available):

    .venv/bin/python scripts/m0_bootstrap_atoms.py
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import nltk
from nltk.corpus import framenet as fn
from nltk.corpus import verbnet as vn
from nltk.corpus import wordnet as wn
from nltk.stem import WordNetLemmatizer
from nltk.tag import pos_tag
from nltk.tokenize import word_tokenize
from rdflib import Graph, Namespace, RDF, RDFS, OWL

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
DATA_DIR.mkdir(exist_ok=True)

TRACES_PATH = PROJECT_ROOT / "reasoning_library" / "traces.jsonl"
OUTPUT_PATH = DATA_DIR / "reinforcement_atoms.json"

PROVO_PATH = Path("/tmp/prov-o.owl")
PPLAN_PATH = Path("/tmp/p-plan.owl")

# ═══════════════════════════════════════════════════════════════════════
# Verb extraction helpers
# ═══════════════════════════════════════════════════════════════════════

_lemmatizer = WordNetLemmatizer()

# Penn Treebank → WordNet POS
_PTB2WN = {"J": wn.ADJ, "V": wn.VERB, "N": wn.NOUN, "R": wn.ADV}


def extract_verbs(text: str) -> Set[str]:
    """Extract lemma-tized verbs from a thinking block."""
    tokens = word_tokenize(text)
    tagged = pos_tag(tokens)
    verbs = set()
    for word, tag in tagged:
        if not word.isalpha():
            continue
        wn_pos = _PTB2WN.get(tag[0])
        if wn_pos == wn.VERB:
            lemma = _lemmatizer.lemmatize(word.lower(), pos=wn.VERB)
            verbs.add(lemma)
    return verbs


# ═══════════════════════════════════════════════════════════════════════
# Ontology lookup helpers
# ═══════════════════════════════════════════════════════════════════════

def lookup_framenet(verb: str) -> List[Tuple[str, str]]:
    """Return (frame_name, frame_definition) for frames matching a verb."""
    results = []
    try:
        # FrameNet API accepts regex; wrap verb in word boundary.
        frames = fn.frames(r"(?i)\b" + re.escape(verb) + r"\b")
        for frame in frames:
            name = frame.name
            definition = frame.definition or ""
            if name and definition:
                results.append((name, definition.strip()))
    except Exception:
        pass

    # Also try direct lexical unit lookup, e.g. "search.v".
    for pos in ["v", "n"]:
        lu_name = f"{verb}.{pos}"
        try:
            lu = fn.lu(lu_name)
            frame = lu.frame
            if frame.name and frame.definition:
                results.append((frame.name, frame.definition.strip()))
        except Exception:
            pass
    return results


def format_verbnet_frame(frame: Dict[str, Any]) -> List[str]:
    """Convert a VerbNet frame dict into readable text fragments."""
    pieces = []
    desc = frame.get("description", {})
    primary = desc.get("primary", "")
    secondary = desc.get("secondary", "")
    if primary:
        pieces.append(f"frame {primary}")
    if secondary:
        pieces.append(f"({secondary})")

    example = frame.get("example", "")
    if example:
        pieces.append(f"example: {example}")

    # Syntax: build a string like NP[Agent] VERB NP[Predicate +np_omit_ing]
    syntax_parts = []
    for syn in frame.get("syntax", []):
        pos = syn.get("pos_tag", "")
        mods = syn.get("modifiers", {})
        value = mods.get("value", "") if isinstance(mods, dict) else ""
        restraints = []
        if isinstance(mods, dict):
            for sr in mods.get("selrestrs", []):
                restraints.append(f"{sr.get('value', '')}{sr.get('type', '')}")
            for sr in mods.get("synrestrs", []):
                restraints.append(f"{sr.get('value', '')}{sr.get('type', '')}")
        if value or restraints:
            inner = value
            if restraints:
                inner += " " + " ".join(restraints)
            syntax_parts.append(f"{pos}[{inner.strip()}]")
        else:
            syntax_parts.append(pos)
    if syntax_parts:
        pieces.append("syntax: " + " ".join(syntax_parts))

    # Semantics: predicates and arguments
    sem_parts = []
    for sem in frame.get("semantics", []):
        pred = sem.get("predicate_value", "")
        args = [a.get("value", "") for a in sem.get("arguments", [])]
        if pred:
            neg = "not " if sem.get("negated") else ""
            sem_parts.append(f"{neg}{pred}({', '.join(args)})")
    if sem_parts:
        pieces.append("semantics: " + "; ".join(sem_parts))

    return pieces


def lookup_verbnet(verb: str) -> List[Tuple[str, str, List[str]]]:
    """Return (class_id, rich_description, member_verbs) for VerbNet classes."""
    results = []
    seen = set()
    try:
        class_ids = vn.classids(verb)
        for cid in class_ids:
            if cid in seen:
                continue
            seen.add(cid)

            members = vn.lemmas(cid)
            themroles = vn.themroles(cid)

            role_parts = []
            for role in themroles:
                rtype = role.get("type", "")
                mods = role.get("modifiers", [])
                mod_strs = [f"{m.get('value', '')}{m.get('type', '')}" for m in mods]
                if mod_strs:
                    role_parts.append(f"{rtype}[{' '.join(mod_strs)}]")
                else:
                    role_parts.append(rtype)

            frame_parts = []
            for frame in vn.frames(cid):
                frame_text = "; ".join(format_verbnet_frame(frame))
                if frame_text:
                    frame_parts.append(frame_text)

            description = (
                f"Verb class {cid} includes verbs: {', '.join(members)}. "
                f"Thematic roles: {', '.join(role_parts)}. "
                f"Frames: {' | '.join(frame_parts)}"
            )
            results.append((cid, description, members))
    except Exception:
        pass
    return results


# ═══════════════════════════════════════════════════════════════════════
# Manpage mining
# ═══════════════════════════════════════════════════════════════════════

def tool_description(tool: str) -> Optional[str]:
    """Fetch one-line description of a tool from manpages/whatis."""
    try:
        # Try whatis first.
        proc = subprocess.run(
            ["whatis", tool],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if proc.returncode == 0 and proc.stdout:
            # whatis can return multiple matches; take first.
            line = proc.stdout.strip().splitlines()[0]
            # Format: "tool (section) - description"
            if " - " in line:
                return line.split(" - ", 1)[1].strip()
            return line.strip()
    except Exception:
        pass

    # Fallback: run man and take the NAME line.
    try:
        proc = subprocess.run(
            ["man", "-P", "cat", tool],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if proc.returncode == 0 and proc.stdout:
            match = re.search(r"NAME\s*(.+?)(?:\n\n|\n[A-Z])", proc.stdout, re.DOTALL)
            if match:
                return re.sub(r"\s+", " ", match.group(1)).strip()
    except Exception:
        pass

    return None


# ═══════════════════════════════════════════════════════════════════════
# OWL ontology parsing
# ═══════════════════════════════════════════════════════════════════════

def parse_ontology(owl_path: Path, ns_prefix: str, format_hint: str) -> List[Dict[str, Any]]:
    """Parse an OWL file and extract named classes and properties with definitions."""
    atoms = []
    if not owl_path.exists():
        print(f"  [WARN] {owl_path} not found; skipping.")
        return atoms

    g = Graph()
    try:
        g.parse(owl_path, format=format_hint)
    except Exception as e:
        # Fall back to letting rdflib guess.
        print(f"  [WARN] Failed to parse {owl_path} as {format_hint}: {e}")
        try:
            g.parse(owl_path)
        except Exception as e2:
            print(f"  [ERROR] Could not parse {owl_path}: {e2}")
            return atoms

    # Discover the target namespace from declared prefixes.
    ns_map = {prefix: str(uri) for prefix, uri in g.namespaces()}
    target_ns = None
    for prefix, uri in ns_map.items():
        if ns_prefix.lower() in prefix.lower() or uri.lower().endswith(ns_prefix.lower() + "#"):
            target_ns = Namespace(uri)
            break
    if target_ns is None:
        # Fallback: look for known URIs.
        for prefix, uri in ns_map.items():
            if "prov" in uri or "p-plan" in uri:
                target_ns = Namespace(uri)
                break

    if target_ns is None:
        print(f"  [WARN] Could not determine namespace for {owl_path}")
        return atoms

    PROVO_DEF = Namespace("http://www.w3.org/ns/prov#")["definition"]

    def get_description(s) -> str:
        """Collect labels, definitions, and comments for a resource."""
        labels = list(g.objects(s, RDFS.label))
        comments = list(g.objects(s, RDFS.comment))
        definitions = list(g.objects(s, PROVO_DEF))
        # Try SKOS definition if available.
        try:
            from rdflib import SKOS
            skos_defs = list(g.objects(s, SKOS.definition))
        except Exception:
            skos_defs = []
        descs = definitions + skos_defs + comments + labels
        return " ".join(str(d) for d in descs if d).strip()

    def is_in_namespace(uri: str) -> bool:
        return uri.startswith(str(target_ns))

    def add_atom(s, rdf_type, name_override: Optional[str] = None):
        uri = str(s)
        if not is_in_namespace(uri):
            return
        name = name_override or uri.replace(str(target_ns), "")
        if not name or name.startswith("_"):
            return
        description = get_description(s) or name
        atom_type = (
            "class" if rdf_type == OWL.Class
            else "property" if rdf_type in (OWL.ObjectProperty, OWL.DatatypeProperty)
            else "other"
        )
        atoms.append({
            "name": name,
            "description": description,
            "uri": uri,
            "rdf_type": atom_type,
        })

    for s in g.subjects(RDF.type, OWL.Class):
        add_atom(s, OWL.Class)

    for prop_type in (OWL.ObjectProperty, OWL.DatatypeProperty, OWL.AnnotationProperty):
        for s in g.subjects(RDF.type, prop_type):
            add_atom(s, prop_type)

    return atoms


# ═══════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("Milestone 0: Bootstrap cross-ontology atoms")
    print("=" * 70)

    if not TRACES_PATH.exists():
        print(f"[ERROR] Traces not found: {TRACES_PATH}")
        sys.exit(1)

    # ── Load traces ───────────────────────────────────────────────────
    print("\nLoading traces...")
    traces = []
    all_tools: Set[str] = set()
    with TRACES_PATH.open() as f:
        for line in f:
            d = json.loads(line)
            traces.append(d)
            tools = d.get("tools_used", [])
            if isinstance(tools, list):
                all_tools.update(tools)
    print(f"  Loaded {len(traces)} traces")
    print(f"  Unique tools in traces: {sorted(all_tools)}")

    # ── Extract verbs from thinking blocks ────────────────────────────
    print("\nExtracting verbs from thinking blocks...")
    verb_counter: Dict[str, int] = defaultdict(int)
    for d in traces:
        text = d.get("thinking_block", "") or ""
        verbs = extract_verbs(text)
        for v in verbs:
            verb_counter[v] += 1

    # Keep verbs seen more than once (reduce noise).
    frequent_verbs = {v for v, c in verb_counter.items() if c >= 2}
    print(f"  Unique verbs: {len(verb_counter)}")
    print(f"  Frequent verbs (>=2 occurrences): {len(frequent_verbs)}")

    atoms: List[Dict[str, Any]] = []

    # ── FrameNet atoms ────────────────────────────────────────────────
    print("\nLooking up FrameNet frames...")
    seen_frames: Set[str] = set()
    frame_hits = 0
    for verb in sorted(frequent_verbs):
        for name, definition in lookup_framenet(verb):
            if name in seen_frames:
                continue
            seen_frames.add(name)
            frame_hits += 1
            atoms.append({
                "atom_id": f"frame_{name}",
                "source": "framenet",
                "label": name,
                "description": definition,
                "aliases": [],
                "atom_type": "frame",
            })
    print(f"  Found {frame_hits} unique frames for frequent verbs")

    # ── VerbNet atoms ─────────────────────────────────────────────────
    print("\nLooking up VerbNet classes...")
    seen_vn: Set[str] = set()
    vn_hits = 0
    for verb in sorted(frequent_verbs):
        for class_id, description, members in lookup_verbnet(verb):
            if class_id in seen_vn:
                continue
            seen_vn.add(class_id)
            vn_hits += 1
            atoms.append({
                "atom_id": f"verbnet_{class_id}",
                "source": "verbnet",
                "label": class_id,
                "description": description,
                "aliases": members,
                "atom_type": "verb_class",
            })
    print(f"  Found {vn_hits} unique VerbNet classes for frequent verbs")

    # ── Tool / manpage atoms ──────────────────────────────────────────
    print("\nMining manpage descriptions for tools...")
    tool_hits = 0
    for tool in sorted(all_tools):
        desc = tool_description(tool)
        if desc:
            tool_hits += 1
            atoms.append({
                "atom_id": f"tool_{tool}",
                "source": "manpage",
                "label": tool,
                "description": desc,
                "aliases": [],
                "atom_type": "tool",
            })
        else:
            # Still add the tool with a generic description so it can appear in
            # the activation matrix, even without a manpage hit.
            atoms.append({
                "atom_id": f"tool_{tool}",
                "source": "manpage",
                "label": tool,
                "description": f"Tool '{tool}' observed in reasoning traces.",
                "aliases": [],
                "atom_type": "tool",
            })
            tool_hits += 1
    print(f"  Added {len(all_tools)} tool atoms ({tool_hits} with manpage descriptions)")

    # ── PROV-O atoms ──────────────────────────────────────────────────
    print("\nParsing PROV-O ontology...")
    provo_atoms = parse_ontology(PROVO_PATH, "prov", "turtle")
    for a in provo_atoms:
        atoms.append({
            "atom_id": f"provo_{a['name']}",
            "source": "prov-o",
            "label": a["name"],
            "description": a["description"],
            "aliases": [a["uri"]],
            "atom_type": "class" if "Property" not in str(a["description"]) else "property",
        })
    print(f"  Added {len(provo_atoms)} PROV-O atoms")

    # ── P-PLAN atoms ──────────────────────────────────────────────────
    print("\nParsing P-PLAN ontology...")
    pplan_atoms = parse_ontology(PPLAN_PATH, "p-plan", "xml")
    for a in pplan_atoms:
        atoms.append({
            "atom_id": f"pplan_{a['name']}",
            "source": "p-plan",
            "label": a["name"],
            "description": a["description"],
            "aliases": [a["uri"]],
            "atom_type": "class" if "Property" not in str(a["description"]) else "property",
        })
    print(f"  Added {len(pplan_atoms)} P-PLAN atoms")

    # ── Metadata and write ────────────────────────────────────────────
    output = {
        "generated_from": str(TRACES_PATH),
        "trace_count": len(traces),
        "unique_verbs": len(verb_counter),
        "frequent_verbs": len(frequent_verbs),
        "unique_tools": len(all_tools),
        "atoms": atoms,
        "source_counts": defaultdict(int),
    }
    for atom in atoms:
        output["source_counts"][atom["source"]] += 1
    output["source_counts"] = dict(output["source_counts"])

    with OUTPUT_PATH.open("w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\nWrote {len(atoms)} atoms to {OUTPUT_PATH}")
    print("  Source counts:", output["source_counts"])
    print("=" * 70)


if __name__ == "__main__":
    main()
