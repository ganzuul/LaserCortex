"""
Tamari lattice builder with Φ cost data for all 14 logic types.

Generates:
  - All EMLTrees of size n (Catalan(n) vertices)
  - Edges: contracts_one relation (right rotations)
  - 3D positions from Loday coordinates
  - Φ cost for each logic type per vertex
  - crossImpact cost per edge
  - associatorCost per pair of adjacent edges (pentagon defect)
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

from ._eml_tree import (
    EMLTree, LEAF, rightComb, leftComb,
    contracts_one, contracts_one_successors, contracts_to,
)
from ._cost import phi, NODE_PARAM
from ._logic_types import LogicType


# ── Coordinate helpers ───────────────────────────────────────────────

@dataclass
class Coord3:
    x: int = 0
    y: int = 0
    z: int = 0

    def to_tuple(self) -> Tuple[int, int, int]:
        return (self.x, self.y, self.z)


def num_leaves(t: EMLTree) -> int:
    if t.is_leaf:
        return 1
    return num_leaves(t.left) + num_leaves(t.right)


def loday_coord(t: EMLTree) -> List[int]:
    if t.is_leaf:
        return []
    return [num_leaves(t.left)] + loday_coord(t.left) + loday_coord(t.right)


def tree_position(t: EMLTree) -> Coord3:
    """3D position from Loday coordinates.
    x = first coord, y = sum of remaining, z = 0 (cost is separate).
    """
    coords = loday_coord(t)
    if not coords:
        return Coord3(0, 0, 0)
    x = coords[0]
    y = sum(coords[1:]) if len(coords) > 1 else 0
    return Coord3(x, y, 0)


# ── Tree enumeration ──────────────────────────────────────────────────

def all_trees(n: int) -> List[EMLTree]:
    """Generate all EMLTrees with n internal nodes (Catalan(n))."""
    if n == 0:
        return [LEAF]
    result: List[EMLTree] = []
    for i in range(n):
        for left in all_trees(i):
            for right in all_trees(n - 1 - i):
                result.append(EMLTree.node(left, right))
    return result


# ── Lattice data types ────────────────────────────────────────────────

@dataclass
class Vertex:
    id: int
    tree: EMLTree
    bits: str
    coord: Coord3
    is_left_comb: bool
    is_right_comb: bool
    size: int
    costs: Dict[str, int] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "bits": self.bits,
            "repr": repr(self.tree),
            "coord": {"x": self.coord.x, "y": self.coord.y, "z": self.coord.z},
            "is_left_comb": self.is_left_comb,
            "is_right_comb": self.is_right_comb,
            "size": self.size,
            "costs": self.costs,
        }


@dataclass
class Edge:
    source_id: int
    target_id: int
    cross_impacts: Dict[str, int] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "source": self.source_id,
            "target": self.target_id,
            "cross_impacts": self.cross_impacts,
        }


@dataclass
class Lattice:
    n: int
    vertices: List[Vertex]
    edges: List[Edge]
    logic_types: List[str]


def build_lattice(n: int) -> Lattice:
    """Build the Tamari lattice T_n with cost data."""
    trees = all_trees(n)
    tree_to_id: Dict[EMLTree, int] = {}
    vertices: List[Vertex] = []

    logic_names = sorted(lt.value for lt in LogicType)

    for i, t in enumerate(trees):
        pos = tree_position(t)
        v = Vertex(
            id=i,
            tree=t,
            bits=t.to_bits(),
            coord=pos,
            is_left_comb=t == leftComb(n) if n > 0 else True,
            is_right_comb=t == rightComb(n) if n > 0 else True,
            size=n,
            costs={},
        )
        for lt in LogicType:
            v.costs[lt.value] = phi(lt, t)
        tree_to_id[t] = i
        vertices.append(v)

    edges: List[Edge] = []
    for s in trees:
        sid = tree_to_id[s]
        for t in contracts_one_successors(s):
            tid = tree_to_id[t]
            e = Edge(source_id=sid, target_id=tid)
            # cross-impact for each logic type
            for lt in LogicType:
                ci = abs(phi(lt, s) - phi(lt, t))
                e.cross_impacts[lt.value] = ci
            edges.append(e)

    return Lattice(n=n, vertices=vertices, edges=edges, logic_types=logic_names)


# ── Path finding ──────────────────────────────────────────────────────

@dataclass
class LatticePath:
    source_id: int
    target_id: int
    vertex_ids: List[int]

    def to_dict(self) -> dict:
        return {
            "source": self.source_id,
            "target": self.target_id,
            "vertices": self.vertex_ids,
            "length": len(self.vertex_ids) - 1,
        }


def find_path(lattice: Lattice, source: EMLTree, target: EMLTree) -> Optional[LatticePath]:
    """BFS shortest path in the lattice."""
    from collections import deque

    tree_to_id = {v.tree: v.id for v in lattice.vertices}
    if source not in tree_to_id or target not in tree_to_id:
        return None

    start_id = tree_to_id[source]
    end_id = tree_to_id[target]

    visited = {start_id}
    queue = deque([(start_id, [start_id])])

    while queue:
        cur_id, path = queue.popleft()
        if cur_id == end_id:
            return LatticePath(source_id=start_id, target_id=end_id, vertex_ids=path)

        for e in lattice.edges:
            if e.source_id == cur_id and e.target_id not in visited:
                visited.add(e.target_id)
                queue.append((e.target_id, path + [e.target_id]))
            if e.target_id == cur_id and e.source_id not in visited:
                visited.add(e.source_id)
                queue.append((e.source_id, path + [e.source_id]))

    return None


def find_path_to_rightcomb(lattice: Lattice, tree: EMLTree) -> Optional[LatticePath]:
    target = rightComb(lattice.n) if lattice.n > 0 else LEAF
    return find_path(lattice, tree, target)


def tree_layout_dict(tree: EMLTree) -> dict:
    """Layout info for a single tree."""
    coords = loday_coord(tree)
    return {
        "tree": repr(tree),
        "bits": tree.to_bits(),
        "size": tree.size(),
        "num_leaves": num_leaves(tree),
        "layout": {"loday": coords},
        "coordinates": [{"x": c, "y": 0, "z": 0} for c in coords],
    }


# ── Coupling sweep / decay chart ──────────────────────────────────────


def count_local_minima(costs: Dict[int, int], edges: List[Edge]) -> int:
    """Number of trees whose cost is ≤ all neighbors (local minima)."""
    minima = 0
    for v_id, c in costs.items():
        is_min = True
        for e in edges:
            neighbor = None
            if e.source_id == v_id:
                neighbor = e.target_id
            elif e.target_id == v_id:
                neighbor = e.source_id
            if neighbor is not None:
                if costs.get(neighbor, 0) < c:
                    is_min = False
                    break
        if is_min:
            minima += 1
    return minima


def total_pentagon_defect(
    costs: Dict[int, int],
    edges: List[Edge],
    vertices: List[Vertex],
) -> float:
    """Sum of |Φ(a) + Φ(b) - Φ(compose(a,b))| across all K₄ faces.

    A simplified proxy: for each K₄ face (a pentagon of 5 vertices),
    sum the absolute cost differences around the cycle. High defect
    means the associator is not coherent — Lagrangian friction is high.
    """
    # Build adjacency
    adj: Dict[int, List[int]] = {v.id: [] for v in vertices}
    for e in edges:
        adj.setdefault(e.source_id, []).append(e.target_id)
        adj.setdefault(e.target_id, []).append(e.source_id)

    # Find all 5-cycles (K₄ faces) — brute force for small n
    pentagons: List[List[int]] = []
    visited: set = set()
    for start_id in adj:
        # DFS for cycles of length 5
        def dfs(path: List[int]) -> None:
            if len(path) == 5:
                if start_id in adj.get(path[-1], []):
                    cycle = tuple(sorted(path))
                    if cycle not in visited:
                        visited.add(cycle)
                        pentagons.append(list(path))
                return
            for nb in adj.get(path[-1], []):
                if nb not in path and (len(path) > 1 or nb > path[0]):
                    dfs(path + [nb])

        dfs([start_id])

    defect = 0.0
    for pent in pentagons:
        # Cost around the pentagon cycle
        cycle_costs = [costs.get(v_id, 0) for v_id in pent]
        # Simple defect: sum of absolute differences between adjacent costs
        for i in range(5):
            defect += abs(cycle_costs[i] - cycle_costs[(i + 1) % 5])

    return defect


def coupling_decay(
    n: int,
    logic: str,
    couplings: List[int],
    denom: int = 10,
) -> dict:
    """Sweep coupling values and return decay metrics.

    For each coupling value:
      - cost per tree
      - number of local minima
      - pentagon defect (proxy for Lagrangian friction)
      - rightComb cost
      - min / max / mean cost
    """
    from ._cost import phi_coupled
    from ._logic_types import LogicType

    lt = LogicType(logic)
    trees = all_trees(n)
    edges_raw: List[Edge] = []
    tree_list: List[EMLTree] = list(trees)

    # Build adjacency once (edges are independent of coupling)
    for s in trees:
        sid = tree_list.index(s)
        for t in contracts_one_successors(s):
            tid = tree_list.index(t)
            edges_raw.append(Edge(source_id=sid, target_id=tid))

    rc = rightComb(n) if n > 0 else LEAF
    rc_idx = tree_list.index(rc)

    sweep_points: List[dict] = []
    for k in couplings:
        costs_map: Dict[int, int] = {}
        for i, t in enumerate(tree_list):
            costs_map[i] = phi_coupled(lt, t, coupling=k, denom=denom)

        num_min = count_local_minima(costs_map, edges_raw)
        penta = total_pentagon_defect(costs_map, edges_raw, [
            Vertex(id=i, tree=t, bits="", coord=Coord3(0, 0, 0),
                   is_left_comb=False, is_right_comb=False, size=n)
            for i, t in enumerate(tree_list)
        ])
        vals = list(costs_map.values())
        rc_cost = costs_map[rc_idx]

        sweep_points.append({
            "coupling": k,
            "num_local_minima": num_min,
            "pentagon_defect": round(penta, 1),
            "right_comb_cost": rc_cost,
            "min_cost": min(vals),
            "max_cost": max(vals),
            "mean_cost": round(sum(vals) / max(len(vals), 1), 1),
            "costs": [costs_map[i] for i in range(len(tree_list))],
        })

    return {
        "n": n,
        "logic_type": logic,
        "couplings": couplings,
        "sweep": sweep_points,
    }
