#!/usr/bin/env python3
"""Schutz audit — expository debt per Bernard Schutz criteria.

Checks:
  A) Equations / code blocks without earning prose before/after
  B) Technical terms / Lean names used before first gloss
  C) Sections where w/s > 25 or PEAK > 12 (terse + technical)
  D) Missing dependency: term used in file N before defined in file < N

Heuristic, not verdict — locates candidates for human reading.
"""
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
PRIMER = os.path.join(HERE, "..", "docs", "primer")

# Lean identifiers that should earn prose
LEAN_NAMES = re.compile(r"`([A-Za-z][A-Za-z0-9_]+)`")
# Display equations: $$, \[ \], or 4-space code blocks with = or |
EQ_BLOCK = re.compile(r"^\s{4,}.*[=|]|^\s*\$\$|^\s*\\\[|^\s*```")

# Terms that must be glossed at first use (subset where Schutz demands it)
MUST_GLOSS = [
    "associator", "alternativity", "alternating", "strut_weight",
    "frictionDensity", "dcStep", "rightSpine", "leftWeight", "rightWeight",
    "friction density", "quasisymmetry", "quasi-isodynamic", "rotational transform",
    "magnetic island", "reconnection", "flux surface", "safety factor",
    "coarse", "detail", "lifting", "cocycle", "G2", "F-move",
]

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
    return [(n, "\n".join(b)) for n,b in secs if "\n".join(b).strip()]

def has_earning_prose(lines, eq_idx):
    # look 3 lines before and 5 lines after for connective / explanatory phrases
    window_before = " ".join(lines[max(0,eq_idx-3):eq_idx]).lower()
    window_after = " ".join(lines[eq_idx+1:eq_idx+6]).lower()
    earning = ["because","since","we need","we define","consider","to see",
               "means","says","tells us","where","so","thus","hence","therefore",
               "i.e.","that is","this is","we call","we say"]
    before_ok = any(p in window_before for p in earning[:7])
    after_ok = any(p in window_after for p in earning[7:])
    return before_ok, after_ok

print("=== SCHUTZ AUDIT — expository debt ===\n")
print("A) Equations / Lean names without earning prose\n")
for fn in sorted(os.listdir(PRIMER)):
    if not re.match(r"\d\d_", fn): continue
    path = os.path.join(PRIMER, fn)
    for name, body in split_sections(path):
        lines = body.splitlines()
        for i, ln in enumerate(lines):
            if LEAN_NAMES.search(ln) or EQ_BLOCK.match(ln):
                # skip table rows
                if ln.strip().startswith("|"): continue
                before_ok, after_ok = has_earning_prose(lines, i)
                if not (before_ok and after_ok):
                    tag = []
                    if not before_ok: tag.append("no before-prose")
                    if not after_ok: tag.append("no after-prose")
                    print(f"  {fn:26s} {name[:30]:30s} L{i+1:2d}: {', '.join(tag):20s} | {ln.strip()[:70]}")

print("\nB) First-use gloss check (must-gloss terms)\n")
seen = set()
for fn in sorted(os.listdir(PRIMER)):
    if not re.match(r"\d\d_", fn): continue
    path = os.path.join(PRIMER, fn)
    for name, body in split_sections(path):
        low = body.lower()
        for term in MUST_GLOSS:
            if term.lower() in low and term not in seen:
                # check 200 chars around first hit for gloss markers
                idx = low.find(term.lower())
                window = low[max(0,idx-200):idx+300]
                has_gloss = any(g in window for g in ["—","(", "i.e.", "that is","means","namely","refers to","called","defined as","is the"])
                seen.add(term)
                mark = "OK" if has_gloss else "NO GLOSS"
                print(f"  {mark:8s} {term:22s} first at {fn:22s} {name[:28]}")

print("\nC) Terse sections (w/s > 22, peak > 10) — from pacing_audit\n")
# reuse pacing logic quickly
import sys
sys.path.insert(0, os.path.join(HERE))
try:
    from pacing_audit import stats_for
    rows=[]
    for fn in sorted(f for f in os.listdir(PRIMER) if re.match(r"\d\d_", f)):
        for name, body in split_sections(os.path.join(PRIMER, fn)):
            s=stats_for(body)
            if s["words"]>=30 and not s.get("table"):
                if s["wps"]>22 or s["peak"]>10:
                    rows.append((fn,name,s))
    rows.sort(key=lambda r: -(r[2]["wps"]+r[2]["peak"]))
    for fn,name,s in rows[:12]:
        print(f"  w/s={s['wps']:4.1f} peak={s['peak']:4.1f}  {fn:26s} {name[:38]}")
except Exception as e:
    print(f"  (could not run pacing stats: {e})")

print("\nDone — review flagged lines above. Every flagged line needs human judgement: is the surrounding prose actually earning it?")
