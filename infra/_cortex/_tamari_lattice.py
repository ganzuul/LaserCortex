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
