#!/usr/bin/env python3
"""Pacing audit — density-variance pass over docs/primer/.

Computes, per section:
  - words, sentences, words/sentence
  - Flesch reading ease (approximate; syllables via vowel-group heuristic,
    identifiers counted as one word with per-syllable estimate)
  - term density: known technical terms per 100 words
  - code density: `code` tokens per 100 words
  - connective density: valley-filling phrases per 100 words
  - PEAK score = term+code density - connective density
  - first-use-without-gloss report for each technical term

This is a heuristic instrument, not a verdict: it locates candidates for
human/LLM reading. Peaks (terse+technical) need exposition; valleys (long+
light) need cutting or conversion to marginalia.

Usage: python3 scripts/pacing_audit.py [--json]
"""
from __future__ import annotations
import os, re, sys, json, math

HERE = os.path.dirname(os.path.abspath(__file__))
PRIMER = os.path.join(HERE, "..", "docs", "primer")

VOCAB = [
    "associator", "alternativity", "alternating", "Cayley", "octonion",
    "octonions", "sedenion", "sedenions", "quaternion", "quaternions",
    "Tamari", "associahedron", "geodesic", "Bellman", "cocycle",
    "cohomology", "coboundary", "differential form", "Stokes", "G2",
    "pentagon", "lifting", "wavelet", "low-pass", "high-pass", "detail",
    "coarse", "subband", "F-move", "Fibonacci", "flux", "frozen-in",
    "reconnection", "resistivity", "Lorentz", "Poynting", "solenoidal",
    "monopole", "curl", "divergence", "rotational transform", "isodynamic",
    "quasisymmetry", "Boozer", "island", "islands", "VMEC", "DESC",
    "SIMSOPT", "SPEC", "magnetohydrodynamic", "magnetohydrodynamics",
    "MHD", "equilibrium", "confinement", "tokamak", "stellarator",
    "rate-distortion", "quantization", "coefficient", "Landauer",
    "Boltzmann", "Catalan", "transformation", "chirality", "orientation",
    "eigenstate", "isometry", "norm", "signature", "bivector", "grade",
    "involution", "antipode", "Clifford", "pseudospectral",
]
CODES = {
    "associator_tensor","left_alternative","right_alternative",
    "associator_antisymm_left","strut_weight_eq_four","gamma_increment",
    "gamma_only_jump_at_cd2_3","contracts_one_leftWeight_decreases",
    "dcStep","rightSpine","frictionDensity","weightedCost","assocDefect",
    "commDefect","dcStep_node_compose","dcStep_eq_geodesic",
    "dcStep_is_maximal_potential","dcStep_contracts_one_le","looseCost",
    "looseCost_linear_in_trust","boundary_retreat_linear_in_load",
    "weightedCost_edge_lipschitz","SplitOctonion","split_oct_mul",
    "transitCoord","kktMultiplier","rightComb","EMLTree","contracts_one",
    "octonion_norm","rescue_envelope_bounded_by_coupling",
}
CONNECTIVES = [
    "in other words", "for example", "for instance", "that is", "i.e.",
    "note that", "this means", "which is to say", "the point is",
    "why this matters", "intuitively", "roughly", "think of",
    "the idea is", "loosely", "concretely", "what does this mean",
    "put differently", "to see why", "the reason", "so that", "because",
    "which says", "this is the", "here is why",
]
GLOSS_MARKERS = ["—", "(", "i.e.", "that is", "means", "namely",
                 "which is", "defined as", "refers to", "the idea",
                 "this is the"]

def split_sections(path):
    txt = open(path, encoding="utf-8").read()
    lines = txt.splitlines()
    secs, cur = [], ("(front matter)", [])
    for ln in lines:
        m = re.match(r"^## (.*)", ln)
        if m:
            secs.append(cur)
            cur = (m.group(1).strip(), [])
        else:
            cur[1].append(ln)
    secs.append(cur)
    return [(name, "\n".join(b)) for name, b in secs if "\n".join(b).strip()]

def syllables(word):
    w = word.lower()
    w = re.sub(r"[^a-z]", "", w)
    if not w:
        return 1
    runs = len(re.findall(r"[aeiouy]+", w))
    runs = max(1, runs)
    if w.endswith("e") and runs > 1 and not w.endswith(("ee", "ye", "oe")):
        runs -= 1
    return runs

def ident_syllables(name):
    return max(2, sum(syllables(p) for p in name.split("_") if p))

def stats_for(body):
    # strip section heading line & blockquote markers for prose stats
    # count code tokens separately
    # table detection: sections dominated by '|' lines are reference matter,
    # not prose — Flesch/peak on a table measures the table, not the reading
    table_lines = sum(1 for l in body.splitlines() if l.strip().startswith("|"))
    all_lines = max(1, len([l for l in body.splitlines() if l.strip()]))
    is_table = table_lines / all_lines > 0.5
    prose_body = "\n".join(l for l in body.splitlines()
                           if not l.strip().startswith("|"))   # drop table rows
    code_tokens = re.findall(r"`([A-Za-z0-9_]+)`", prose_body)
    ncode = len(code_tokens)
    prose = re.sub(r"`[^`]+`", " ", prose_body)  # code removed
    prose = re.sub(r"[*_#>|]", " ", prose)          # markup removed
    words = re.findall(r"[A-Za-zÀ-ÿΓ-Ωα-ω0-9'\-\u2011]+", prose)
    nw = len(words)
    nsent = max(1, len(re.findall(r"[.!?](?:\s|$)", prose)))
    syl = sum(syllables(w) for w in words)
    for c in code_tokens:
        syl += ident_syllables(c)
    total = nw + ncode if nw else 1
    flesch = 206.835 - 1.015 * (total / nsent) - 84.6 * (syl / max(total, 1))
    low = prose.lower()
    terms = sum(low.count(v.lower()) for v in VOCAB)
    conn = sum(low.count(c) for c in CONNECTIVES)
    return dict(words=total, sentences=nsent, wps=total / nsent,
                flesch=flesch, table=is_table,
                term_d=100.0 * terms / total,
                code_d=100.0 * ncode / total,
                conn_d=100.0 * conn / total,
                peak=(100.0 * (terms + ncode) / total) - 100.0 * conn / total)

def main():
    files = sorted(f for f in os.listdir(PRIMER)
                   if re.match(r"\d\d_", f))
    rows = []
    first_use = {}
    order = []
    for fn in files:
        path = os.path.join(PRIMER, fn)
        for name, body in split_sections(path):
            rows.append((fn, name, stats_for(body)))
            low = re.sub(r"`[^`]+`", " ", body.lower())
            for v in VOCAB:
                if v.lower() in low and v not in first_use:
                    idx = low.find(v.lower())
                    window = low[max(0, idx - 200): idx + 300]
                    has_gloss = any(g in window for g in GLOSS_MARKERS)
                    first_use[v] = (fn, name, has_gloss)
                    order.append(v)
    if "--json" in sys.argv:
        print(json.dumps([{**{"file": r[0], "section": r[1]}, **r[2]}
                          for r in rows], indent=1))
        return
    print(f"{'file':22s} {'section':34s} {'wds':>5s} {'w/s':>5s} {'Flesch':>7s} "
          f"{'term%':>6s} {'code%':>6s} {'conn%':>6s} {'PEAK':>6s}")
    for fn, name, s in rows:
        if s["words"] < 8: continue
        tag = " [tbl]" if s.get("table") else ""
        print(f"{fn:22s} {name[:33]:34s} {s['words']:5d} {s['wps']:5.1f} "
              f"{s['flesch']:7.1f} {s['term_d']:6.1f} {s['code_d']:6.1f} "
              f"{s['conn_d']:6.1f} {s['peak']:6.1f}{tag}")
    print("\n=== first uses WITHOUT a nearby gloss (define earlier or add one) ===")
    for v in order:
        fn, name, ok = first_use[v]
        if not ok:
            print(f"  {v:24s} first at {fn} / {name[:28]}")
    prose_rows = [r for r in rows if r[2]['words'] >= 25 and not r[2].get('table')]
    print("\n=== top PEAK candidates (terse + technical - connective) [prose only] ===")
    peaks = sorted(prose_rows, key=lambda r: -r[2]['peak'])[:10]
    for fn, name, s in peaks:
        print(f"  {s['peak']:5.1f}  {fn} :: {name[:40]}")
    print("\n=== top VALLEY candidates (long, low content load) [prose only] ===")
    valleys = sorted([r for r in prose_rows if r[2]['words'] >= 60],
                     key=lambda r: (r[2]['term_d'] + r[2]['code_d']
                                    - 0.5 * r[2]['conn_d']))[:8]
    for fn, name, s in valleys:
        print(f"  {s['term_d'] + s['code_d']:5.1f}  {fn} :: {name[:40]}")
    # distribution of reading ease (prose only)
    fs = [s['flesch'] for _, _, s in prose_rows]
    if fs:
        print(f"\nFlesch across prose sections: min {min(fs):.0f}  max {max(fs):.0f} "
              f" spread {max(fs)-min(fs):.0f}  (target: spread < 15)")

if __name__ == "__main__":
    main()
