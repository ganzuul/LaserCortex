#!/usr/bin/env python3
"""
Generate Tamari lattice data for dagre-d3 visualization.

Outputs JSON with nodes and edges suitable for rendering a Hasse diagram.
"""

import json
import sys
from collections import defaultdict

sys.path.insert(0, '/home/nos/labware/LaserCortex/scripts')
from tube_map_calibrate import all_trees, contracts_one_successors, left_weight, right_weight


def compute_rank(trees):
    """Compute rank of each tree in the Tamari lattice."""
    # Build adjacency
    downward = {repr(t): [] for t in trees}
    for t in trees:
        for s in contracts_one_successors(t):
            downward[repr(t)].append(repr(s))
    
    # Find minimum element (right comb)
    min_elem = 'N(L,N(L,N(L,N(L,L))))'
    
    # Compute rank
    rank = {}
    def compute_rank_recursive(t_repr):
        if t_repr in rank:
            return rank[t_repr]
        if t_repr == min_elem:
            rank[t_repr] = 0
            return 0
        if not downward[t_repr]:
            rank[t_repr] = 0
            return 0
        max_succ_rank = max(compute_rank_recursive(s) for s in downward[t_repr])
        rank[t_repr] = max_succ_rank + 1
        return rank[t_repr]
    
    for t in trees:
        compute_rank_recursive(repr(t))
    
    return rank


def generate_lattice_data(max_size=4):
    """Generate Tamari lattice data for trees of given size."""
    trees = list(all_trees(max_size))
    rank = compute_rank(trees)
    
    # Build nodes
    nodes = []
    for t in trees:
        t_repr = repr(t)
        nodes.append({
            'id': t_repr,
            'label': t_repr,
            'rank': rank[t_repr],
            'y': left_weight(t) - right_weight(t),
        })
    
    # Build edges (covering relations)
    # In Tamari order: if s contracts to t, then s > t
    # So edges go from t to s (upward in the lattice)
    edges = []
    for t in trees:
        t_repr = repr(t)
        for s in contracts_one_successors(t):
            s_repr = repr(s)
            # t contracts to s, so t > s in Tamari order
            # Edge goes from s to t (upward)
            edges.append({
                'from': s_repr,
                'to': t_repr,
            })
    
    return {
        'nodes': nodes,
        'edges': edges,
        'stats': {
            'num_elements': len(nodes),
            'num_edges': len(edges),
            'max_rank': max(rank.values()) if rank else 0,
            'rank_distribution': dict(sorted(
                defaultdict(int, {r: sum(1 for n in nodes if n['rank'] == r) for r in range(max(rank.values()) + 1)}).items()
            )),
        }
    }


def main():
    # Generate data for T₄ (size 4, 14 elements)
    data = generate_lattice_data(4)
    
    # Write to JSON
    output_path = '/home/nos/labware/LaserCortex/canvas_app/frontend/public/tamari_lattice_T4.json'
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"Generated {output_path}")
    print(f"  Nodes: {data['stats']['num_elements']}")
    print(f"  Edges: {data['stats']['num_edges']}")
    print(f"  Max rank: {data['stats']['max_rank']}")
    print(f"  Rank distribution: {data['stats']['rank_distribution']}")


if __name__ == '__main__':
    main()
