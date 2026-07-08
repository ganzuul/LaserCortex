#!/usr/bin/env python3
"""
graphiti_to_transit_map.py — embed Graphiti communities in the CD tower transit map.

Given a group_id, queries Graphiti for communities, computes KKT multiplier
components from each community's entity graph, applies the covector projection,
and emits TransitData JSON consumable by transit-entry.tsx.

The KKT mapping (proven in OctilinearEmbedding.lean / GraphitiEmbedding.lean):

    λ_comm = (size, leftWeight, rightWeight, assocDefect) ∈ SplitQuat

    tubeCoord cd comm = (size + assocDefect(cd), leftWeight − rightWeight)

Usage:
    # As a script (requires running GraphitiService):
    python3 scripts/graphiti_to_transit_map.py --group-id default --out plots/transit_map.json

    # As an imported module:
    from scripts.graphiti_to_transit_map import graphiti_to_transit_map
    data = await graphiti_to_transit_map(graphiti_svc, group_id="default")

Output: TransitData JSON matching d3-tube-map format:

    {
      "stations": { "uuid": { "name", "label", "size", "y" }, ... },
      "lines": [
        { "name": "split-complex",   "color": "#e6194b", "nodes": [...], "shiftCoords": [0,0] },
        { "name": "split-quat",      "color": "#3b75af", "nodes": [...], "shiftCoords": [0,7] },
        { "name": "split-octonion",  "color": "#44aa44", "nodes": [...], "shiftCoords": [0,14] },
      ]
    }
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger("graphiti-to-transit-map")

# ═══════════════════════════════════════════════════════════════════════
# Constants — mirror the CD tower lines from generate_transit_json.py
# ═══════════════════════════════════════════════════════════════════════

CD_LINES = [
    {"id": "split-complex",   "label": "SplitComplex",   "color": "#e6194b", "cd": 0, "y_base": 0},
    {"id": "split-quat",      "label": "SplitQuat",      "color": "#3b75af", "cd": 1, "y_base": 7},
    {"id": "split-octonion",  "label": "SplitOctonion",  "color": "#44aa44", "cd": 3, "y_base": 14},
]

X_STEP = 4       # horizontal spacing between community stations
X_START = 1      # starting x position

# ═══════════════════════════════════════════════════════════════════════
# KKT component computation helpers
# ═══════════════════════════════════════════════════════════════════════

def assoc_defect_for_coupling(coupling_signature: str) -> int:
    """Map NormNode coupling signature to assocDefect.
    
    - "commutative" / "commutative-associative" → CD ≤ 2 → assocDefect = 0
    - "non_commutative" → CD 2 → assocDefect = 0
    - "non_associative" → CD ≥ 3 → assocDefect = 4
    
    Mirror of OctilinearEmbedding.lean: assocDefect_zero_up_to_cd2 and
    assocDefect_positive_for_cd3plus.
    """
    if coupling_signature == "non_associative":
        return 4
    return 0


def dominant_coupling(signatures: List[str]) -> str:
    """Determine the dominant coupling regime for a set of signatures.
    
    If any entity is non_associative, the whole community is non_associative
    (the strongest regime dominates). Otherwise, if any is non_commutative,
    the community is non_commutative. Otherwise commutative.
    
    This matches the CD tower logic: CD step increases monotonically
    with the strongest coupling found.
    """
    if "non_associative" in signatures:
        return "non_associative"
    if "non_commutative" in signatures:
        return "non_commutative"
    return "commutative"


def regime_cd_step(signatures: List[str]) -> int:
    """Map a list of coupling signatures to the effective CD step.
    
    non_associative → 3 (or higher, but we use 3 as the SplitOctonion line)
    non_commutative → 2
    commutative     → 0
    """
    dom = dominant_coupling(signatures)
    if dom == "non_associative":
        return 3
    if dom == "non_commutative":
        return 2
    return 0


# ═══════════════════════════════════════════════════════════════════════
# CommunityStats dataclass
# ═══════════════════════════════════════════════════════════════════════

class CommunityStats:
    """KKT multiplier components computed from a Graphiti community.
    
    This is the semantic embedding of a community into the octolinear
    coordinate space.
    """
    def __init__(
        self,
        uuid: str,
        name: str,
        member_count: int,
        left_weight: int,
        right_weight: int,
        coupling_signatures: List[str],
    ):
        self.uuid = uuid
        self.name = name or uuid[:8]
        self.member_count = member_count        # size (a)
        self.left_weight = left_weight           # leftWeight (b) — inbound
        self.right_weight = right_weight          # rightWeight (c) — outbound
        self.coupling_signatures = coupling_signatures
        
        # Derived
        self.assoc_defect = max(
            assoc_defect_for_coupling(s) for s in coupling_signatures
        ) if coupling_signatures else 0
        
        self.dominant_coupling = dominant_coupling(coupling_signatures)
        self.cd_step = regime_cd_step(coupling_signatures)
    
    @property
    def size(self) -> int:
        """KKT component a = member_count."""
        return self.member_count
    
    @property
    def asymmetry(self) -> int:
        """KKT covector y-component = leftWeight − rightWeight."""
        return self.left_weight - self.right_weight
    
    def tube_coord(self, cd: int) -> Tuple[int, int]:
        """Compute tube_coord at a given CD level.
        
        Mirror of tube_map_calibrate.tube_coord and 
        OctilinearEmbedding.lean transitCoord.
        
        x = size + assocDefect(cd)
        y = leftWeight − rightWeight
        
        Note: assocDefect is 0 for CD ≤ 2, 4 for CD ≥ 3 (strut_weight).
        """
        ad = 0 if cd <= 2 else self.assoc_defect
        return (self.size + ad, self.asymmetry)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "uuid": self.uuid,
            "name": self.name,
            "size": self.size,
            "leftWeight": self.left_weight,
            "rightWeight": self.right_weight,
            "assocDefect": self.assoc_defect,
            "asymmetry": self.asymmetry,
            "coupling": self.dominant_coupling,
            "cd_step": self.cd_step,
            "member_count": self.member_count,
        }


# ═══════════════════════════════════════════════════════════════════════
# Cypher queries
# ═══════════════════════════════════════════════════════════════════════

def _build_queries(community_uuid: str) -> Dict[str, str]:
    """Build parameterized Cypher queries for a community."""
    return {
        "member_entities": f"""
            MATCH (c:Community {{uuid: $uuid}})-[e:HAS_MEMBER]->(ent)
            RETURN ent.uuid as uuid, labels(ent) as labels,
                   ent.owl_key as owl_key,
                   ent.coupling_signature as coupling_signature,
                   ent.cd_step as cd_step,
                   ent.assoc_defect as assoc_defect
        """,
        "inbound_edge_count": f"""
            MATCH (c:Community {{uuid: $uuid}})-[mem:HAS_MEMBER]->(ent)
            MATCH (other)-[edge]->(ent)
            WHERE NOT (other)<-[:HAS_MEMBER]-(c)
            RETURN count(DISTINCT edge) as count
        """,
        "outbound_edge_count": f"""
            MATCH (c:Community {{uuid: $uuid}})-[mem:HAS_MEMBER]->(ent)
            MATCH (ent)-[edge]->(other)
            WHERE NOT (other)<-[:HAS_MEMBER]-(c)
            RETURN count(DISTINCT edge) as count
        """,
        "community_name": f"""
            MATCH (c:Community {{uuid: $uuid}})
            RETURN c.name as name, c.summary as summary
        """,
    }


# ═══════════════════════════════════════════════════════════════════════
# Core function: compute community stats from Graphiti
# ═══════════════════════════════════════════════════════════════════════

async def compute_community_stats(
    graphiti_svc,
    group_id: str,
    community_node,
) -> CommunityStats:
    """Compute KKT components for a single community by querying its entity graph.
    
    Args:
        graphiti_svc: A running GraphitiService instance.
        group_id: The group partition (FalkorDB database name).
        community_node: A CommunityNode from build_communities().
    
    Returns:
        CommunityStats with size, leftWeight, rightWeight, assocDefect.
    """
    from infra._graphiti_service import _FalkorDriver as FalkorDriver
    
    uid = community_node.uuid
    driver = FalkorDriver(
        falkor_db=graphiti_svc._falkordb,
        database=group_id,
    )
    try:
        queries = _build_queries(uid)
        
        # 1. Get member entities with their attributes
        member_result = await driver.execute_query(
            queries["member_entities"], params={"uuid": uid}
        )
        members = member_result[0] if member_result else []
        
        # 2. Count inbound edges from outside the community
        in_result = await driver.execute_query(
            queries["inbound_edge_count"], params={"uuid": uid}
        )
        inbound_count = 0
        if in_result and in_result[0]:
            row = in_result[0][0]
            inbound_count = row.get("count", 0) or 0
        
        # 3. Count outbound edges to outside the community
        out_result = await driver.execute_query(
            queries["outbound_edge_count"], params={"uuid": uid}
        )
        outbound_count = 0
        if out_result and out_result[0]:
            row = out_result[0][0]
            outbound_count = row.get("count", 0) or 0
        
        # 4. Get community name
        name_result = await driver.execute_query(
            queries["community_name"], params={"uuid": uid}
        )
        community_name = uid[:8]
        if name_result and name_result[0]:
            row = name_result[0][0]
            community_name = row.get("name") or row.get("summary", "") or uid[:8]
        
        # 5. Extract coupling signatures from member entities
        coupling_signatures = []
        for m in members:
            cs = m.get("coupling_signature")
            if cs:
                coupling_signatures.append(cs)
        
        return CommunityStats(
            uuid=uid,
            name=community_name[:40],
            member_count=len(members),
            left_weight=inbound_count,
            right_weight=outbound_count,
            coupling_signatures=coupling_signatures,
        )
    finally:
        await driver.close()


# ═══════════════════════════════════════════════════════════════════════
# Transit data builder
# ═══════════════════════════════════════════════════════════════════════

def build_transit_data(
    stats_list: List[CommunityStats],
) -> Dict[str, Any]:
    """Build TransitData JSON from a list of community stats.
    
    Creates three parallel lines (one per CD tower island) with stations
    at tube_coord positions computed from the KKT components.
    
    Communities are sorted by (size, asymmetry) for consistent horizontal
    ordering across all three lines — matching the layout in
    generate_transit_json.py.
    """
    # Sort communities by (size, asymmetry) for consistent x ordering
    sorted_stats = sorted(stats_list, key=lambda s: (s.size, s.asymmetry))
    
    # Build stations dict
    stations = {}
    for s in sorted_stats:
        label = f"{s.name} [{s.dominant_coupling}]" if s.assoc_defect > 0 else s.name
        stations[s.uuid] = {
            "name": s.uuid,
            "label": label,
            "size": s.size,
            "y": s.asymmetry,
            # Extra metadata for debugging
            "leftWeight": s.left_weight,
            "rightWeight": s.right_weight,
            "assocDefect": s.assoc_defect,
            "coupling": s.dominant_coupling,
            "memberCount": s.member_count,
        }
    
    # Build lines
    lines = []
    for line_cfg in CD_LINES:
        cd = line_cfg["cd"]
        y_base = line_cfg["y_base"]
        
        nodes = []
        for idx, s in enumerate(sorted_stats):
            sx = X_START + idx * X_STEP
            sy = y_base
            label_pos = "S" if idx % 2 == 0 else "N"
            
            nodes.append({
                "coords": [sx, sy],
                "name": s.uuid,
                "labelPos": label_pos,
            })
        
        lines.append({
            "name": line_cfg["id"],
            "color": line_cfg["color"],
            "shiftCoords": [0, 0],
            "nodes": nodes,
        })
    
    return {
        "stations": stations,
        "lines": lines,
    }


# ═══════════════════════════════════════════════════════════════════════
# Top-level pipeline
# ═══════════════════════════════════════════════════════════════════════

async def graphiti_to_transit_map(
    graphiti_svc,
    group_id: str = "default",
) -> Dict[str, Any]:
    """Main pipeline: build communities → compute KKT stats → emit TransitData.
    
    Args:
        graphiti_svc: A running GraphitiService instance.
        group_id: Group partition to process.
    
    Returns:
        TransitData JSON dict.
    
    Raises:
        RuntimeError: If GraphitiService is not started.
    """
    logger.info("Building communities for group '%s' ...", group_id)
    communities = await graphiti_svc.build_communities(group_id=group_id)
    logger.info("Found %d communities", len(communities))
    
    if not communities:
        logger.warning("No communities found — emitting empty transit data")
        return {"stations": {}, "lines": []}
    
    # Compute KKT stats for each community
    stats_list = []
    for i, community in enumerate(communities):
        logger.info("  [%d/%d] Processing community %s ...", i + 1, len(communities), community.uuid[:8])
        try:
            stats = await compute_community_stats(
                graphiti_svc, group_id, community
            )
            stats_list.append(stats)
            logger.info("    → size=%d  lW=%d  rW=%d  assocDefect=%d  coupling=%s",
                       stats.size, stats.left_weight, stats.right_weight,
                       stats.assoc_defect, stats.dominant_coupling)
        except Exception as e:
            logger.error("    ✗ Failed to process community %s: %s", community.uuid[:8], e)
            # Continue with other communities — don't let one failure block the whole pipeline
    
    # Build transit data
    transit_data = build_transit_data(stats_list)
    
    # Print summary
    print(f"\n{'='*60}")
    print(f"  Graphiti → Transit Map Summary")
    print(f"  Group: {group_id}")
    print(f"  Communities processed: {len(stats_list)}")
    print(f"  Stations in map: {len(transit_data['stations'])}")
    for stats in sorted(stats_list, key=lambda s: (s.size, s.asymmetry)):
        x0, y0 = stats.tube_coord(0)
        x3, y3 = stats.tube_coord(3)
        print(f"    {stats.name:<30s}  sz={stats.size}  lW={stats.left_weight:>3}  "
              f"rW={stats.right_weight:>3}  ad={stats.assoc_defect}  "
              f"cd0=({x0},{y0})  cd3=({x3},{y3})  [{stats.dominant_coupling}]")
    print(f"{'='*60}")
    
    return transit_data


# ═══════════════════════════════════════════════════════════════════════
# Standalone entry point
# ═══════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Embed Graphiti communities in the CD tower transit map",
    )
    parser.add_argument(
        "--group-id", default="default",
        help="Graphiti group partition (FalkorDB database name)",
    )
    parser.add_argument(
        "--out", default=None,
        help="Output path for TransitData JSON (default: plots/transit_map_graphiti.json)",
    )
    parser.add_argument(
        "--db-path", default=None,
        help="Path to FalkorDB Lite RDB file (default: data/graphiti_service.db)",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true",
        help="Enable debug logging",
    )
    args = parser.parse_args()
    
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )
    
    import asyncio
    
    async def run():
        from infra._graphiti_service import GraphitiService
        
        svc = GraphitiService(
            db_path=args.db_path or "",
        )
        async with svc:
            transit_data = await graphiti_to_transit_map(
                svc, group_id=args.group_id,
            )
            
            # Determine output path
            if args.out:
                outpath = args.out
            else:
                outdir = os.path.join(
                    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "plots",
                )
                os.makedirs(outdir, exist_ok=True)
                outpath = os.path.join(outdir, "transit_map_graphiti.json")
            
            with open(outpath, "w") as f:
                json.dump(transit_data, f, indent=2)
            logger.info("Wrote TransitData to %s", outpath)
            
            # Validation
            for line in transit_data.get("lines", []):
                for node in line.get("nodes", []):
                    c = node["coords"]
                    assert isinstance(c[0], int) and isinstance(c[1], int), \
                        f"Non-integer coords in line {line['name']}: {c}"
            logger.info("✓ All coordinates are integers")
    
    asyncio.run(run())


if __name__ == "__main__":
    main()
