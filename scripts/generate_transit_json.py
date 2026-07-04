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

def build_river(tree_infos: list[TreeInfo], cd: int = 0) -> dict | None:
    """Build a river layer showing contracts_one edges at a given CD level.

    Each edge in the connectome is a segment from source to target node,
    colored by Δy = 2·size(b) (the cost).

    Since d3-tube-map only supports a single river with a single color,
    we use different rivers for different cost levels.
    Instead, for the first version, we skip the river and show
    the connectome in a separate overlay.
    """
    return None


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

    transit_data = {
        "stations": stations,
        "lines": lines,
    }

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
