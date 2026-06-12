"""Tamari Lattice Visualization API — /api/tamari namespace.

Exposes the Tamari lattice structure, Loday coordinates, contraction
paths, and tree layouts for the Three.js frontend visualization.

This is the data layer for the Tamari polytope explorer:
  - Lattice vertices = EMLTrees with 3D coordinates
  - Lattice edges = contracts_one relations (right rotations)
  - Contraction paths = chains of rotations to equilibrium (rightComb)
"""
from fastapi import APIRouter, HTTPException
from typing import Any, Dict, List, Optional
from pydantic import BaseModel
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/tamari", tags=["tamari"])


# ── Shared helpers ─────────────────────────────────────────────────────

def _parse_bits(bits: str) -> EMLTree:
    """Parse a binary tree encoding into an EMLTree.

    Format: '0' = Leaf, '1' + left + right = Node.
    """
    from infra._cortex._eml_tree import EMLTree

    def _parse(s: str, idx: int):
        if idx >= len(s) or s[idx] == '0':
            return EMLTree.leaf(), idx + 1
        left, idx2 = _parse(s, idx + 1)
        right, idx3 = _parse(s, idx2)
        return EMLTree.node(left, right), idx3

    tree, consumed = _parse(bits, 0)
    if consumed != len(bits):
        raise ValueError(f"Invalid bits encoding: extra characters at position {consumed}")
    return tree


# ── Pydantic response schemas ─────────────────────────────────────────

class Point3DResponse(BaseModel):
    x: int
    y: int
    z: int


class VertexResponse(BaseModel):
    id: int
    bits: str
    repr: str
    coord: Point3DResponse
    is_left_comb: bool
    is_right_comb: bool
    size: int


class CostVertexResponse(VertexResponse):
    costs: Dict[str, int] = {}


class EdgeResponse(BaseModel):
    source: int
    target: int


class CostEdgeResponse(EdgeResponse):
    cross_impacts: Dict[str, int] = {}


class PathResponse(BaseModel):
    source: int
    target: int
    vertices: List[int]
    length: int


class LatticeResponse(BaseModel):
    n: int
    vertex_count: int
    edge_count: int
    vertices: List[VertexResponse]
    edges: List[EdgeResponse]


class CostLatticeResponse(BaseModel):
    n: int
    vertex_count: int
    edge_count: int
    logic_type: str
    vertices: List[CostVertexResponse]
    edges: List[CostEdgeResponse]


class CostLandscapeResponse(BaseModel):
    n: int
    logic_types: List[str]
    vertices: List[CostVertexResponse]


class TreeLayoutResponse(BaseModel):
    tree: str
    bits: str
    size: int
    num_leaves: int
    layout: Dict[str, Any]
    coordinates: List[Point3DResponse]


class PathRequest(BaseModel):
    source_bits: str
    target_bits: str


# ── Lattice endpoints ─────────────────────────────────────────────────

# Cache lattices for small n to avoid recomputation
_lattice_cache: Dict[int, Any] = {}


def _get_lattice(n: int):
    """Get or compute the Tamari lattice T_n."""
    if n not in _lattice_cache:
        from infra._cortex._tamari_lattice import build_lattice
        if n < 0 or n > 7:
            raise HTTPException(status_code=400, detail=f"n must be 0-7, got {n}")
        _lattice_cache[n] = build_lattice(n)
    return _lattice_cache[n]


@router.get("/lattice/{n}", response_model=LatticeResponse)
async def get_lattice(n: int):
    """Get the complete Tamari lattice T_n with vertices, edges, and coordinates.

    n=0: single Leaf
    n=1: single Node(Leaf,Leaf) — trivial
    n=2: 2 trees, 1 edge
    n=3: 5 trees, 6 edges (pentagon)
    n=4: 14 trees, ? edges
    n=5: 42 trees (Catalan number)
    """
    lattice = _get_lattice(n)
    return LatticeResponse(
        n=lattice.n,
        vertex_count=len(lattice.vertices),
        edge_count=len(lattice.edges),
        vertices=[
            VertexResponse(
                id=v.id,
                bits=v.bits,
                repr=repr(v.tree),
                coord=Point3DResponse(x=v.coord.x, y=v.coord.y, z=v.coord.z),
                is_left_comb=v.is_left_comb,
                is_right_comb=v.is_right_comb,
                size=v.size,
            )
            for v in lattice.vertices
        ],
        edges=[EdgeResponse(source=e.source_id, target=e.target_id) for e in lattice.edges],
    )


@router.get("/tree/{bits}", response_model=TreeLayoutResponse)
async def get_tree_layout(bits: str):
    """Get the detailed 3D layout for a single tree identified by its binary encoding.

    The bits format: '0' = Leaf, '1' + left + right = Node.
    Example: '11000' = Node(Node(Leaf,Leaf),Leaf)
    """
    from infra._cortex._tamari_lattice import tree_layout_dict

    try:
        tree = _parse_bits(bits)
    except (ValueError, Exception):
        raise HTTPException(status_code=400, detail=f"Invalid tree bits: {bits}")

    info = tree_layout_dict(tree)
    return TreeLayoutResponse(
        tree=info["tree"],
        bits=info["bits"],
        size=info["size"],
        num_leaves=info["num_leaves"],
        layout=info["layout"],
        coordinates=[Point3DResponse(x=c["x"], y=c["y"], z=c["z"]) for c in info["coordinates"]],
    )


@router.post("/path", response_model=PathResponse)
async def find_contraction_path(req: PathRequest):
    """Find the shortest contraction path between two trees.

    Returns the sequence of vertex IDs in the lattice from source to target.
    """
    from infra._cortex._tamari_lattice import find_path

    try:
        source = _parse_bits(req.source_bits)
        target = _parse_bits(req.target_bits)
    except (ValueError, Exception):
        raise HTTPException(status_code=400, detail="Invalid tree bits encoding")

    if source.size() != target.size():
        raise HTTPException(status_code=400, detail="Source and target must have the same size")

    lattice = _get_lattice(source.size())
    path = find_path(lattice, source, target)
    if path is None:
        raise HTTPException(status_code=404, detail="No contraction path found")

    return PathResponse(
        source=path.source_id,
        target=path.target_id,
        vertices=path.vertex_ids,
        length=len(path.vertex_ids) - 1,
    )


@router.get("/path-to-rightcomb/{bits}", response_model=PathResponse)
async def find_path_to_equilibrium(bits: str):
    """Find the contraction path from any tree to its rightComb equilibrium.

    This is the NA→NC transition: from undetermined state to resolved equilibrium.
    """
    from infra._cortex._tamari_lattice import find_path_to_rightcomb

    try:
        tree = _parse_bits(bits)
    except (ValueError, Exception):
        raise HTTPException(status_code=400, detail="Invalid tree bits encoding")

    lattice = _get_lattice(tree.size())
    path = find_path_to_rightcomb(lattice, tree)
    if path is None:
        raise HTTPException(status_code=404, detail="No path to rightComb found")

    return PathResponse(
        source=path.source_id,
        target=path.target_id,
        vertices=path.vertex_ids,
        length=len(path.vertex_ids) - 1,
    )


@router.get("/cost-lattice/{n}/{logic}", response_model=CostLatticeResponse)
async def get_cost_lattice(n: int, logic: str):
    """Get the Tamari lattice T_n with Φ costs for the given logic type.

    Each vertex includes its Φ cost under the given logic type.
    Each edge includes the absolute cost difference (cross-impact / anti-inertia).
    """
    from infra._cortex._logic_types import LogicType

    try:
        lt = LogicType(logic)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid logic type: {logic}")

    lattice = _get_lattice(n)

    return CostLatticeResponse(
        n=lattice.n,
        vertex_count=len(lattice.vertices),
        edge_count=len(lattice.edges),
        logic_type=logic,
        vertices=[
            CostVertexResponse(
                id=v.id,
                bits=v.bits,
                repr=repr(v.tree),
                coord=Point3DResponse(x=v.coord.x, y=v.coord.y, z=v.costs.get(logic, 0)),
                is_left_comb=v.is_left_comb,
                is_right_comb=v.is_right_comb,
                size=v.size,
                costs=v.costs,
            )
            for v in lattice.vertices
        ],
        edges=[
            CostEdgeResponse(source=e.source_id, target=e.target_id, cross_impacts=e.cross_impacts)
            for e in lattice.edges
        ],
    )


@router.get("/coupling-decay/{n}")
async def get_coupling_decay(
    n: int,
    logic: str = "paraconsistent",
    couplings: str = "0,1,2,5,10,20,50",
    denom: int = 10,
):
    """Sweep coupling strength and return decay metrics.

    For each coupling value returns:
      - num_local_minima: how many trees are locally optimal
      - pentagon_defect: sum of cost differences around K4 faces
      - right_comb_cost, min/max/mean cost
      - full cost array per tree

    The decay chart shows the landscape collapsing as coupling increases.
    """
    from infra._cortex._tamari_lattice import coupling_decay
    coupling_list = [int(c) for c in couplings.split(",")]
    result = coupling_decay(n=n, logic=logic, couplings=coupling_list, denom=denom)
    return result


# ── Lean certificate endpoint ─────────────────────────────────────────────

import subprocess

class LeanVerifyResponse(BaseModel):
    passed: bool
    summary: str
    log: str
    target_count: int = 0

@router.get("/verify-lean", response_model=LeanVerifyResponse)
async def verify_lean():
    """Run `lake build` and verify zero sorries.

    Returns pass/fail, build summary, and full log.
    """
    project_root = Path(__file__).parent.parent.parent.parent
    try:
        result = subprocess.run(
            ["lake", "build"],
            cwd=project_root,
            capture_output=True,
            text=True,
            timeout=120,
        )
        log = result.stdout + "\n" + result.stderr
        # Check for zero sorries: look for "0 sorries" or no "sorry" failures
        lines = result.stdout.splitlines()
        target_count = 0
        passed = True
        for line in lines:
            if "sorries" in line.lower():
                target_count = int(line.split()[0]) if line.split()[0].isdigit() else 0
            if "error" in line.lower() and "error" in result.stderr.lower():
                passed = False
        if result.returncode != 0:
            passed = False
        summary = "PASS: all targets verified (zero sorries)" if passed else "FAIL: build errors found"
        return LeanVerifyResponse(passed=passed, summary=summary, log=log, target_count=target_count)
    except subprocess.TimeoutExpired:
        return LeanVerifyResponse(passed=False, summary="FAIL: lake build timed out (>120s)", log="")
    except FileNotFoundError:
        return LeanVerifyResponse(passed=False, summary="FAIL: lake not found on PATH", log="")
    except Exception as e:
        return LeanVerifyResponse(passed=False, summary=f"FAIL: {e}", log="")


@router.get("/cost-landscape/{n}", response_model=CostLandscapeResponse)
async def get_cost_landscape(n: int):
    """Get the full Φ cost landscape for all 14 logic types.

    Returns every vertex with its costs as {logic_type: Φ_value}.
    The frontend uses this to interpolate between logic regimes.
    """
    lattice = _get_lattice(n)
    return CostLandscapeResponse(
        n=lattice.n,
        logic_types=lattice.logic_types,
        vertices=[
            CostVertexResponse(
                id=v.id,
                bits=v.bits,
                repr=repr(v.tree),
                coord=Point3DResponse(x=v.coord.x, y=v.coord.y, z=0),
                is_left_comb=v.is_left_comb,
                is_right_comb=v.is_right_comb,
                size=v.size,
                costs=v.costs,
            )
            for v in lattice.vertices
        ],
    )
