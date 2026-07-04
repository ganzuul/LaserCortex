#!/usr/bin/env python3
r"""
tube_map_render.py — render the Tamari lattice as a London Underground style tube map

Three CD-tower islands (horizontal bands):
    Island Red    = SplitComplex (cd=0, associative,  2D)
    Island Blue   = SplitQuat    (cd=1, associative,  4D)
    Island Green  = SplitOctonion(cd=3, non-assoc,    8D, assocDefect=4)

Stations = EMLTree configurations. Edges = contracts_one (Tamari rotation).
Edge colour = marginal cost (Δy = 2·size(b) for the rotated subtree).

Output: plots/tube_map.png
"""

import itertools
import math
import os
import sys
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import numpy as np

# Prepend repo root for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from scripts.tube_map_calibrate import (
    all_trees, contracts_one_successors,
    tube_coord, assoc_defect,
    left_weight, right_weight,
    tree_label, EMLTree, LEAF, NODE,
    right_comb, left_comb,
)

PLOT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "plots")
os.makedirs(PLOT_DIR, exist_ok=True)


# ═══════════════════════════════════════════════════════════════════════
# 1. Island model
# ═══════════════════════════════════════════════════════════════════════

CD_ISLANDS = [
    ("SplitComplex",  0, "#e6194b"),   # Red
    ("SplitQuat",     1, "#3b75af"),   # Blue
    ("SplitOctonion", 3, "#44aa44"),   # Green
]

def edge_cost(s: EMLTree, t: EMLTree, cd: int) -> float:
    """Marginal cost = Δy = y_source - y_target = 2·size(b) for rotation."""
    _, ys = tube_coord(cd, s)
    _, yt = tube_coord(cd, t)
    return ys - yt  # always positive


# ═══════════════════════════════════════════════════════════════════════
# 2. Layout geometry
# ═══════════════════════════════════════════════════════════════════════

def build_tube_map_data(max_size: int = 4) -> dict:
    """Build all data needed for the tube map.

    Returns nested dict:
        islands[cd] = {
            'name': str,
            'color': str,
            'stations': [(tree_idx, tree, x, y, label, lw, rw), ...],
            'edges': [(s_tree, t_tree, s_x, s_y, t_x, t_y, cost), ...],
        }
    """
    islands = {}
    all_trees_by_size = {}
    for sz in range(1, max_size + 1):
        all_trees_by_size[sz] = all_trees(sz)

    for name, cd, color in CD_ISLANDS:
        stations = []
        tree_to_idx = {}
        idx = 0
        for sz in range(1, max_size + 1):
            for t in all_trees_by_size[sz]:
                x, y = tube_coord(cd, t)
                lw = left_weight(t)
                rw = right_weight(t)
                lbl = tree_label(t)
                stations.append((idx, t, x, y, lbl, lw, rw))
                tree_to_idx[t] = idx
                idx += 1

        edges = []
        for sz in range(1, max_size + 1):
            for s in all_trees_by_size[sz]:
                xs, ys = tube_coord(cd, s)
                for t in contracts_one_successors(s):
                    if t in tree_to_idx:
                        xt, yt = tube_coord(cd, t)
                        cost = edge_cost(s, t, cd)
                        edges.append((s, t, xs, ys, xt, yt, cost))

        islands[cd] = {
            'name': name,
            'color': color,
            'stations': stations,
            'edges': edges,
        }
    return islands


def station_bbox(label: str) -> Tuple[float, float]:
    """Estimate bounding box of a station label in data coordinates."""
    # Rough estimate: ~0.45 per char width, 0.4 height
    return (len(label) * 0.38, 0.5)


def _route_edges(edges: list) -> Dict[Tuple[int, int, int], list]:
    """Group edges by (x_level, source_y, target_y) for parallel routing."""
    groups = defaultdict(list)
    for s, t, xs, ys, xt, yt, cost in edges:
        key = (int(xs), int(ys), int(yt))
        groups[key].append((s, t, xs, ys, xt, yt, cost))
    return dict(groups)


def _compute_edge_offset(groups: dict) -> Dict[Tuple, float]:
    """Compute radial offsets for parallel edges to avoid overlap."""
    offsets = {}
    for key, edges in groups.items():
        n = len(edges)
        if n == 1:
            offsets[key] = [0.0]
        else:
            # Spread evenly: -0.12, -0.06, 0.0, 0.06, 0.12 for n=5
            spacing = 0.10
            start = -(n - 1) * spacing / 2
            offsets[key] = [start + i * spacing for i in range(n)]
    return offsets


# ═══════════════════════════════════════════════════════════════════════
# 3. Drawing functions
# ═══════════════════════════════════════════════════════════════════════

def draw_island(ax, data: dict, cd: int, island_y: float):
    """Draw one CD island as a horizontal tube-map band."""
    stations = data['stations']
    edges = data['edges']
    color = data['color']
    name = data['name']

    if not stations:
        return

    # Group edges by (x, source_y, target_y) for parallel routing
    edge_groups = _route_edges(edges)
    edge_offsets = _compute_edge_offset(edge_groups)

    # ── Draw edges (train lines) ──────────────────────────────
    # Colour = cost (Δy). Use a colormap that goes from thin/light to thick/dark.
    for key, group in edge_groups.items():
        x_lvl, ys, yt = key
        offsets = edge_offsets[key]
        for (s, t, xs, ys_v, xt, yt_v, cost), rad in zip(group, offsets):
            # Colormap: cost 1→min (light grey), cost 4→max (bold color)
            cmap = plt.cm.Reds if cd == 0 else (plt.cm.Blues if cd == 1 else plt.cm.Greens)
            norm_cost = min(cost / 4.0, 1.0)  # 4 = max possible Δy
            edge_color = cmap(0.3 + 0.7 * norm_cost)

            # Line width proportional to cost
            lw = 0.8 + 1.6 * norm_cost

            # Draw as curved arc — tube map style uses parallel octolinear lines
            # We use FancyArrowPatch with an arc for the parallel effect
            ax.annotate(
                "", xy=(xt, island_y + yt_v),
                xytext=(xs, island_y + ys_v),
                arrowprops=dict(
                    arrowstyle="-",
                    color=edge_color,
                    lw=lw,
                    connectionstyle=f"arc3,rad={rad}",
                    alpha=0.85,
                ),
            )

    # ── Draw stations ────────────────────────────────────────
    for idx, t, x, y, lbl, lw, rw in stations:
        sx = x
        sy = island_y + y

        # Station dot
        ax.plot(sx, sy, 'o', color=color, markersize=7, zorder=5,
                markeredgecolor='white', markeredgewidth=1.2)

        # Label above/below station depending on y position within island
        va = 'bottom' if y >= 0 else 'top'
        offset_y = 0.3 if y >= 0 else -0.3
        # Show tree label in small font
        ax.text(sx, sy + offset_y, lbl, fontsize=5.5,
                ha='center', va=va, color='#222222',
                bbox=dict(boxstyle='round,pad=0.15', fc='white',
                          ec='none', alpha=0.7),
                zorder=6)

        # Show (lW,rW) in even smaller font below/above
        off2 = 0.55 if y >= 0 else -0.55
        ax.text(sx, sy + off2, f"({lw},{rw})", fontsize=4.5,
                ha='center', va=va, color='#888888', zorder=4)

    # ── Island label ─────────────────────────────────────────
    # Place island name on the left side
    y_center = island_y
    x_min = min(s[2] for s in stations) - 0.5
    ax.text(x_min - 0.3, y_center, name, fontsize=9, fontweight='bold',
            color=color, ha='right', va='center', rotation=0,
            bbox=dict(boxstyle='round,pad=0.2', fc='white', ec=color, lw=1.2))


def draw_connectome(ax, islands_data: dict, max_size: int):
    """Draw inter-island connectome: same tree across different CD levels.

    Shows vertical connector lines between the same tree at different cds,
    colored by assocDefect shift.
    """
    # For each tree, connect its positions across the three islands
    all_trees_by_size = {}
    for sz in range(1, max_size + 1):
        all_trees_by_size[sz] = set(all_trees(sz))

    # Map trees to their station data in each island
    for sz in range(1, max_size + 1):
        for t in all_trees_by_size[sz]:
            points = {}
            for cd in [0, 1, 3]:
                data = islands_data[cd]
                for idx, st, sx, sy, lbl, lw, rw in data['stations']:
                    if st == t:
                        if cd == 0:
                            x0, y0_v = sx, sy
                            island_y0 = 0.0
                        points[cd] = (sx, sy)
                        break

            if len(points) >= 2:
                # Draw faint vertical connector between islands
                for (cd1, (x1, y1)), (cd2, (x2, y2)) in itertools.combinations(points.items(), 2):
                    # Map island_y offsets
                    iy1 = {0: 0.0, 1: -6.0, 3: -12.0}[cd1]
                    iy2 = {0: 0.0, 1: -6.0, 3: -12.0}[cd2]
                    ax.plot([x1, x2],
                            [iy1 + y1, iy2 + y2],
                            '-', color='#cccccc', lw=0.4, alpha=0.3, zorder=1)


# ═══════════════════════════════════════════════════════════════════════
# 4. Legend and annotations
# ═══════════════════════════════════════════════════════════════════════

def draw_legend(fig, ax):
    """Add a legend explaining edge colours and island meanings."""
    legend_elements = [
        mpatches.Patch(color='#e6194b', alpha=0.6, label='SplitComplex (cd=0)'),
        mpatches.Patch(color='#3b75af', alpha=0.6, label='SplitQuat (cd=1)'),
        mpatches.Patch(color='#44aa44', alpha=0.6, label='SplitOctonion (cd=3)'),
    ]
    # Cost gradient
    for i, cost in enumerate([1, 2, 3, 4]):
        c = plt.cm.RdYlGn(0.2 + 0.2 * cost)
        legend_elements.append(
            mpatches.Patch(color=c, alpha=0.7,
                           label=f'Cost Δy={cost}  (2·size(b))')
        )

    ax.legend(handles=legend_elements, loc='lower center',
              fontsize=7, ncol=7, framealpha=0.9,
              bbox_to_anchor=(0.5, -0.06))


# ═══════════════════════════════════════════════════════════════════════
# 5. Main
# ═══════════════════════════════════════════════════════════════════════

def main():
    max_size = 4
    print(f"Building tube map data (trees size 1..{max_size})...")
    data = build_tube_map_data(max_size)

    # ── Layout ────────────────────────────────────────────────
    # Three islands stacked vertically with gaps
    # island_y: vertical center of each island band
    island_layout = {
        0: 0.0,    # SplitComplex — top
        1: -6.0,   # SplitQuat — middle
        3: -12.0,  # SplitOctonion — bottom
    }

    # Determine plot bounds from all station positions
    all_x = []
    all_y = []
    for cd, d in data.items():
        for _, _, x, y, _, _, _ in d['stations']:
            all_x.append(x)
            all_y.append(island_layout[cd] + y)

    x_min, x_max = min(all_x) - 2, max(all_x) + 2
    y_min, y_max = min(all_y) - 2, max(all_y) + 2

    # ── Figure ────────────────────────────────────────────────
    fig, ax = plt.subplots(figsize=(18, 12))
    ax.set_xlim(x_min, x_max)
    ax.set_ylim(y_min - 0.5, y_max + 1.5)
    ax.set_aspect('equal')
    ax.axis('off')

    # Background
    ax.set_facecolor('#f8f6f0')
    fig.patch.set_facecolor('#f8f6f0')

    # ── Draw islands ──────────────────────────────────────────
    for cd in [0, 1, 3]:
        island_y = island_layout[cd]
        draw_island(ax, data[cd], cd, island_y)

    # ── Draw connectome ───────────────────────────────────────
    draw_connectome(ax, data, max_size)

    # ── Title ─────────────────────────────────────────────────
    ax.set_title(
        "Tropical Tube Map — Tamari Lattice T₁…T₄  |  "
        "Three CD-Tower Islands connected by contracts_one (Tamari rotation)",
        fontsize=11, fontweight='bold', pad=15
    )

    # ── Legend ────────────────────────────────────────────────
    draw_legend(fig, ax)

    # ── Save ──────────────────────────────────────────────────
    outpath = os.path.join(PLOT_DIR, "tube_map.png")
    fig.savefig(outpath, dpi=200, bbox_inches='tight',
                facecolor=fig.get_facecolor())
    print(f"Wrote {outpath}  ({fig.get_size_inches()} at 200 DPI)")
    plt.close(fig)


if __name__ == "__main__":
    main()
