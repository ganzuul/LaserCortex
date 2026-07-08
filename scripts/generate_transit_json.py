#!/usr/bin/env python3
r"""
generate_transit_json.py — generate d3-tube-map JSON from EMLTree calibration data

Three transit lines = Three CD tower islands:
  SplitComplex (Red)   — cd=0, associative,     2D
  SplitQuat     (Blue)  — cd=1, associative,     4D
  SplitOctonion (Green) — cd=3, non-associative,  8D

Layout: three parallel horizontal lines (one per CD level).
Stations (trees) ordered by y = lw-rw within each line.
Interchanges = same tree appears at multiple CD levels.

Output: plots/transit_map.json
"""

import json
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from scripts.tube_map_calibrate import (
    all_trees, contracts_one_successors,
    tube_coord, assoc_defect,
    left_weight, right_weight,
    tree_label, EMLTree, LEAF, NODE,
)

PLOT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "plots")
os.makedirs(PLOT_DIR, exist_ok=True)


# ═══════════════════════════════════════════════════════════════════════
# 1. Compact tree label (station name / label)
# ═══════════════════════════════════════════════════════════════════════

def compact_tree_label(t: EMLTree) -> str:
    """Short structural label for a tree.

    Uses a canonical naming scheme:
      L                         → leaf (size 0, internal only)
      N(L,L)                    → P (pair, size 1)
      N(L,N(L,L))               → NP (size 2, right comb)
      N(N(L,L),L)               → PN (size 2, left comb)
      N(N(L,L),N(L,L))          → PP (size 3, balanced)
      etc.
    """
    def _encode(node: EMLTree) -> str:
        if node.is_leaf:
            return ""
        left_s = _encode(node.left)
        right_s = _encode(node.right)
        # Merged encoding for compactness
        return f"({left_s},{right_s})"
    s = _encode(t)
    if not s:
        return "L"
    return s


# ═══════════════════════════════════════════════════════════════════════
# 2. Island / line definitions
# ═══════════════════════════════════════════════════════════════════════

CD_LINES = [
    {"id": "split-complex",   "label": "SplitComplex",   "color": "#e6194b", "cd": 0, "y_base": 0},
    {"id": "split-quat",      "label": "SplitQuat",      "color": "#3b75af", "cd": 1, "y_base": 7},
    {"id": "split-octonion",  "label": "SplitOctonion",  "color": "#44aa44", "cd": 3, "y_base": 14},
]


# ═══════════════════════════════════════════════════════════════════════
# 3. Collect all trees with their characteristics
# ═══════════════════════════════════════════════════════════════════════

TreeInfo = dict  # {id, tree, size, lw, rw, y, repr}

def collect_trees(max_size: int = 4) -> list[TreeInfo]:
    """Collect all trees sorted by (size, y = lw-rw)."""
    trees = []
    for sz in range(1, max_size + 1):
        for t in all_trees(sz):
            trees.append({
                "id": compact_tree_label(t),
                "tree": t,
                "size": sz,
                "lw": left_weight(t),
                "rw": right_weight(t),
                "y": left_weight(t) - right_weight(t),
                "repr": repr(t),
            })
    return trees


# ═══════════════════════════════════════════════════════════════════════
# 4. Build stations dictionary
# ═══════════════════════════════════════════════════════════════════════

def build_stations(tree_infos: list[TreeInfo]) -> dict:
    stations = {}
    for ti in tree_infos:
        sid = ti["id"]
        # Use the formal repr as the station label
        label = ti["repr"]
        stations[sid] = {
            "name": sid,  # Required by d3-tube-map (matches station key)
            "label": label,
            "size": ti["size"],
            "y": ti["y"],
        }
    return stations


# ═══════════════════════════════════════════════════════════════════════
# 5. Build line routes
# ═══════════════════════════════════════════════════════════════════════

def build_lines(tree_infos: list[TreeInfo], stations: dict) -> list:
    """Build three parallel horizontal transit lines.

    Each CD level is a horizontal line at a different y.
    Stations are ordered by (size, y = lw-rw) and spaced by X_STEP.
    Since the order is the same for all three lines, stations
    at the same x are at the same position vertically (interchanges).
    """
    X_STEP = 4         # horizontal spacing between stations
    X_START = 1        # starting x position
    LABEL_OFFSET_X = 3 # how far labels shift horizontally

    # Global ordering of stations
    sorted_infos = sorted(tree_infos, key=lambda ti: (ti["size"], ti["y"]))

    lines = []
    for line_cfg in CD_LINES:
        cd = line_cfg["cd"]
        y_base = line_cfg["y_base"]

        nodes = []
        for idx, ti in enumerate(sorted_infos):
            sid = ti["id"]
            sx = X_START + idx * X_STEP
            sy = y_base

            # Label position: alternate to avoid overlap
            # Even idx → above line (S), Odd idx → below line (N)
            # Wait — S means south = below the node, N means north = above
            if idx % 2 == 0:
                label_pos = "S"   # label below the node
            else:
                label_pos = "N"   # label above the node

            # Determine if two consecutive stations have same y value
            # (meaning they'd collide in the interchanges rendering)
            # For d3-tube-map: a station name appearing on multiple lines
            # will automatically get an interchange marker.

            node = {
                "coords": [sx, sy],
                "name": sid,
                "labelPos": label_pos,
            }
            nodes.append(node)

        lines.append({
            "name": line_cfg["id"],
            "color": line_cfg["color"],
            "shiftCoords": [0, 0],
            "nodes": nodes,
        })

    # The d3-tube-map library renders interchanges automatically when
    # a station name appears on multiple lines. Since each station
    # appears on all three lines, every station is an interchange.
    # This is visually correct: it shows the three CD levels as
    # three different transit lines with the same set of stations
    # connected vertically.

    return lines


# ═══════════════════════════════════════════════════════════════════════
# 6. Connectome river layer
# ═══════════════════════════════════════════════════════════════════════

def _leaf_paths(t: EMLTree, prefix: str = "") -> list[str]:
    """Return all L/R paths to leaves in t."""
    if t.is_leaf:
        return [prefix]
    return _leaf_paths(t.left, prefix + "L") + _leaf_paths(t.right, prefix + "R")


def _expand_leaf(t: EMLTree, path: str) -> EMLTree:
    """Replace the leaf at the given L/R path with N(L,L)."""
    if not path:
        return NODE(LEAF, LEAF)
    head, rest = path[0], path[1:]
    if head == "L":
        return NODE(_expand_leaf(t.left, rest), t.right)
    else:
        return NODE(t.left, _expand_leaf(t.right, rest))


def build_river(tree_infos: list[TreeInfo],
                sorted_infos: list[TreeInfo]) -> list[dict]:
    """Build river segments: true 45° tropical edges via leaf expansion.

    A 45° edge in the tubeCoord coordinate system has |Δx| = |Δy|.
    The correct operation is LEAF EXPANSION at an odd-depth leaf where
    the path has exactly one more L than R (NE, Δy=+1) or one more R
    than L (SE, Δy=-1).

    Replacing such a leaf with N(L,L):
      • Δx = 1  (size increases by 1)
      • Δy = ±1 (y = lw-rw changes by exactly 1)

    This is PROVEN by the recursive formula:
      y(N(a,b)) = size(a) − size(b) + y(a) + y(b)
      → Δy = 2·(left_turns) − leaf_depth
      → |Δy| = 1 exactly when depth is odd and left_turns = (depth±1)/2

    NOT the extension operation t → N(t, Leaf) which gives Δy = size(t)
    (only 45° when size(t)=1).

    Args:
        tree_infos: all trees (for expansion lookups)
        sorted_infos: trees sorted by (size, y) — determines x positions
    """
    X_STEP = 4
    X_START = 1

    # Build indexed position lookup: id → x position
    x_by_id: dict[str, int] = {
        ti["id"]: X_START + idx * X_STEP
        for idx, ti in enumerate(sorted_infos)
    }

    # Quick lookup: does resulting tree exist?
    info_by_id: dict[str, TreeInfo] = {ti["id"]: ti for ti in tree_infos}

    segments: list[dict] = []

    # ═══════════════════════════════════════════════════════════════════
    # (A) True 45° tropical edges — within each CD level
    #     Leaf expansion at balanced odd-depth leaves.
    #     These have |Δx| = |Δy| = 1 in tubeCoord space.
    # ═══════════════════════════════════════════════════════════════════
    for cd_line in CD_LINES:
        y_base = cd_line["y_base"]
        cd = cd_line["cd"]
        color = "#ffa500" if cd < 3 else "#ff69b4"

        for ti in tree_infos:
            t = ti["tree"]
            sid = ti["id"]
            sx = x_by_id.get(sid)
            if sx is None:
                continue

            for path in _leaf_paths(t):
                depth = len(path)
                if depth % 2 == 0:
                    continue  # even depth → Δy=0, not 45°

                left_turns = path.count("L")
                dy = 2 * left_turns - depth  # Δy from the expansion
                if abs(dy) != 1:
                    continue  # |Δy|≠1 → not 45° (e.g. pure-left paths at depth 3)

                t2 = _expand_leaf(t, path)
                t2_id = compact_tree_label(t2)
                if t2_id not in info_by_id:
                    continue
                tx = x_by_id.get(t2_id)
                if tx is None:
                    continue

                dir_label = "NE" if dy > 0 else "SE"
                segments.append({
                    "source": sid,
                    "source_coords": [sx, y_base],
                    "target": t2_id,
                    "target_coords": [tx, y_base],
                    "color": color,
                    "label": f"cd={cd} {dir_label} leaf={path}",
                })

    # ═══════════════════════════════════════════════════════════════════
    # (B) Cross-CD extension edges — connect the SAME tree at adjacent
    #     CD levels. These are VERTICAL in tubeCoord space (Δy=0) but
    #     provide the visual diagonal appearance in the transit map.
    #     They are NOT 45° edges — they're "CD projections".
    # ═══════════════════════════════════════════════════════════════════
    CD_EXT_PAIRS = [
        {"src": CD_LINES[0], "tgt": CD_LINES[1], "color": "#88ccff", "label_base": "cd0→1 proj"},
        {"src": CD_LINES[1], "tgt": CD_LINES[2], "color": "#cc88ff", "label_base": "cd1→3 proj"},
    ]

    for pair in CD_EXT_PAIRS:
        src_y = pair["src"]["y_base"]
        tgt_y = pair["tgt"]["y_base"]
        color = pair["color"]

        for ti in tree_infos:
            sid = ti["id"]
            sx = x_by_id.get(sid)
            if sx is None:
                continue
            segments.append({
                "source": sid,
                "source_coords": [sx, src_y],
                "target": sid,
                "target_coords": [sx, tgt_y],
                "color": color,
                "label": pair["label_base"],
            })

    return segments


# ═══════════════════════════════════════════════════════════════════════
# 7. Main
# ═══════════════════════════════════════════════════════════════════════

def main():
    max_size = 4
    print(f"Building transit map data (trees size 1..{max_size})...")

    tree_infos = collect_trees(max_size)
    print(f"  {len(tree_infos)} total trees")

    stations = build_stations(tree_infos)
    lines = build_lines(tree_infos, stations)
    sorted_infos = sorted(tree_infos, key=lambda ti: (ti["size"], ti["y"]))

    rivers = build_river(tree_infos, sorted_infos)

    transit_data = {
        "stations": stations,
        "lines": lines,
        "rivers": rivers,
    }

    print(f"  River segments: {len(rivers)}")
    for r in rivers:
        print(f"    {r['source']:<25s} → {r['target']:<25s}  {r['label']}")

    outpath = os.path.join(PLOT_DIR, "transit_map.json")
    with open(outpath, "w") as f:
        json.dump(transit_data, f, indent=2)
    print(f"Wrote {outpath}")

    # Stats
    n_lines = len(lines)
    n_nodes = sum(len(l["nodes"]) for l in lines)
    print(f"  Stations: {len(stations)}")
    print(f"  Lines: {n_lines}")
    print(f"  Nodes: {n_nodes}")

    # Validation
    for l in lines:
        for n in l["nodes"]:
            c = n["coords"]
            assert isinstance(c[0], int) and isinstance(c[1], int), \
                f"Non-integer coords in line {l['name']}: {c}"
    print("  All coordinates are integers ✓")

    # Print station ordering
    sorted_infos = sorted(tree_infos, key=lambda ti: (ti["size"], ti["y"]))
    print("\n  Station order (x position →):")
    for idx, ti in enumerate(sorted_infos):
        print(f"    x={1 + idx*4:3d}  {ti['id']:20s}  sz={ti['size']}  y={ti['y']:3d}")


if __name__ == "__main__":
    main()
