#!/usr/bin/env python3
"""
Generate octolinear lattice data for Tamari T₄ with tube coordinates.

Each node has exact (x, y) coordinates from the covector projection:
  x = t.size + assocDefect(cd)
  y = leftWeight(t) - rightWeight(t)

Edges are classified by angle:
  - 90° (axis-aligned): even-only or odd-only component changes
  - 45° (diagonal): mixed even+odd changes
"""

import json
import sys
from collections import defaultdict

sys.path.insert(0, '/home/nos/labware/LaserCortex/scripts')
from tube_map_calibrate import (
    all_trees, contracts_one_successors,
    left_weight, right_weight, assoc_defect
)


def tube_coord(cd: int, t) -> tuple[int, int]:
    """Compute tube coordinates: (size + assocDefect, lw - rw)."""
    x = t.size() + assoc_defect(cd)
    y = left_weight(t) - right_weight(t)
    return (x, y)


def classify_edge(t, s) -> str:
    """Classify edge angle based on component changes.
    
    Even components: size (a), assocDefect (d)
    Odd components: leftWeight (b), rightWeight (c)
    
    Returns: '90' for axis-aligned, '45' for diagonal
    """
    # For now, assume same CD level (cd doesn't change in contracts_one)
    # So assocDefect doesn't change
    a_change = abs(t.size() - s.size()) != 0
    d_change = False  # Same CD level
    b_change = abs(left_weight(t) - left_weight(s)) != 0
    c_change = abs(right_weight(t) - right_weight(s)) != 0
    
    even_change = a_change or d_change
    odd_change = b_change or c_change
    
    if even_change and odd_change:
        return '45'  # Diagonal
    else:
        return '90'  # Axis-aligned


def generate_octolinear_lattice(max_size: int = 4, cd: int = 0):
    """Generate octolinear lattice data for Tamari T_1..T_n at CD level cd."""
    # Generate trees of all sizes from 1 to max_size
    trees = []
    for size in range(1, max_size + 1):
        trees.extend(all_trees(size))
    
    # Build nodes with exact coordinates
    nodes = []
    node_map = {}  # repr -> node
    for t in trees:
        t_repr = repr(t)
        x, y = tube_coord(cd, t)
        node = {
            'id': t_repr,
            'label': t_repr,
            'x': x,
            'y': y,
            'size': t.size(),
            'lw': left_weight(t),
            'rw': right_weight(t),
        }
        nodes.append(node)
        node_map[t_repr] = node
    
    # Build edges with angle classification
    edges = []
    for t in trees:
        t_repr = repr(t)
        for s in contracts_one_successors(t):
            s_repr = repr(s)
            angle = classify_edge(t, s)
            edges.append({
                'from': t_repr,
                'to': s_repr,
                'angle': angle,
            })
    
    return {
        'nodes': nodes,
        'edges': edges,
        'cd': cd,
        'stats': {
            'num_nodes': len(nodes),
            'num_edges': len(edges),
            'edges_90': sum(1 for e in edges if e['angle'] == '90'),
            'edges_45': sum(1 for e in edges if e['angle'] == '45'),
            'x_range': [min(n['x'] for n in nodes), max(n['x'] for n in nodes)],
            'y_range': [min(n['y'] for n in nodes), max(n['y'] for n in nodes)],
        }
    }


def main():
    # Generate for Tamari T₄ at CD level 0
    data = generate_octolinear_lattice(4, 0)
    
    # Write to JSON
    output_path = '/home/nos/labware/LaserCortex/canvas_app/frontend/public/octolinear_T4.json'
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"Generated {output_path}")
    print(f"  Nodes: {data['stats']['num_nodes']}")
    print(f"  Edges: {data['stats']['num_edges']}")
    print(f"    90° (axis-aligned): {data['stats']['edges_90']}")
    print(f"    45° (diagonal): {data['stats']['edges_45']}")
    print(f"  X range: {data['stats']['x_range']}")
    print(f"  Y range: {data['stats']['y_range']}")


if __name__ == '__main__':
    main()
