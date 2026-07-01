#!/usr/bin/env python3
"""
Graphiti Single Entry Report Tool

This script retrieves and reports a single entry (NormNode + CortexNode + OWL_KEY_VALUE_PAIR triplet)
from the Graphiti database to investigate what representation is needed for correct graphing
of the relationships in the database.
"""

from __future__ import annotations

import asyncio
import logging
import sys
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("owl-report")


from infra._graphiti_service import GraphitiService
from infra._graphiti_models import (
    NormNodeAttrs,
    CortexNodeAttrs,
    OwlKeyValuePairAttrs,
)


async def generate_single_entry_report(service: GraphitiService, group_id: str, owl_key: str = "ReserveGuard"):
    """Generate a report of a single entry (NormNode + CortexNode + OWL_KEY_VALUE_PAIR triplet) from the database."""
    print("\n" + "=" * 80)
    print("GRAPHITI SINGLE ENTRY REPORT")
    print(f"Group ID: {group_id}")
    print(f"OWL Key: {owl_key}")
    print("=" * 80)

    driver = service.driver

    # 1. Retrieve NormNode by OWL key
    print("\n--- 1. NormNode Data ---")
    norm_result = await driver.execute_query(
        "MATCH (n:NormNode) WHERE n.owl_key = $owl_key "
        "RETURN n.uuid as uuid, n.owl_key as owl_key, n.nl_value as nl_value, "
        "n.coupling_signature as coupling_signature, n.alpha_features as alpha_features, "
        "n.inference_units as inference_units, n.created_at as created_at",
        owl_key=owl_key,
        group_id=group_id,
    )
    
    if norm_result and norm_result[0]:
        for record in norm_result[0]:
            print(f"  UUID: {record.get('uuid')}")
            print(f"  OWL Key: {record.get('owl_key')}")
            print(f"  NL Value: {record.get('nl_value')}")
            print(f"  Coupling Signature: {record.get('coupling_signature')}")
            print(f"  Alpha Features: {record.get('alpha_features')}")
            print(f"  Inference Units: {record.get('inference_units')}")
            print(f"  Created At: {record.get('created_at')}")
    else:
        print("  No NormNode found with OWL key: {owl_key}")

    # 2. Retrieve CortexNode by OWL key
    print("\n--- 2. CortexNode Data ---")
    cortex_result = await driver.execute_query(
        "MATCH (c:CortexNode) WHERE c.owl_key = $owl_key "
        "RETURN c.uuid as uuid, c.owl_key as owl_key, c.cd_step as cd_step, "
        "c.eml_tree as eml_tree, c.tamari_path as tamari_path, c.assoc_defect as assoc_defect, "
        "c.pentagonator_distance as pentagonator_distance, c.created_at as created_at",
        owl_key=owl_key,
        group_id=group_id,
    )
    
    if cortex_result and cortex_result[0]:
        for record in cortex_result[0]:
            print(f"  UUID: {record.get('uuid')}")
            print(f"  OWL Key: {record.get('owl_key')}")
            print(f"  CD Step: {record.get('cd_step')}")
            print(f"  EML Tree: {record.get('eml_tree')}")
            print(f"  Tamari Path: {record.get('tamari_path')}")
            print(f"  Assoc Defect: {record.get('assoc_defect')}")
            print(f"  Pentagonator Distance: {record.get('pentagonator_distance')}")
            print(f"  Created At: {record.get('created_at')}")
    else:
        print("  No CortexNode found with OWL key: {owl_key}")

    # 3. Retrieve OWL_KEY_VALUE_PAIR edge
    print("\n--- 3. OWL_KEY_VALUE_PAIR Edge Data ---")
    edge_result = await driver.execute_query(
        "MATCH (n:NormNode)-[e:OWL_KEY_VALUE_PAIR]->(c:CortexNode) "
        "WHERE n.owl_key = $owl_key "
        "RETURN e.uuid as edge_uuid, e.key as key, e.value as value, "
        "e.coupling_signature as coupling_signature, e.cd_step as cd_step, "
        "e.created_at as created_at, "
        "n.uuid as norm_uuid, c.uuid as cortex_uuid",
        owl_key=owl_key,
        group_id=group_id,
    )
    
    if edge_result and edge_result[0]:
        for record in edge_result[0]:
            print(f"  Edge UUID: {record.get('edge_uuid')}")
            print(f"  Key: {record.get('key')}")
            print(f"  Value: {record.get('value')}")
            print(f"  Coupling Signature: {record.get('coupling_signature')}")
            print(f"  CD Step: {record.get('cd_step')}")
            print(f"  Created At: {record.get('created_at')}")
            print(f"  NormNode UUID: {record.get('norm_uuid')}")
            print(f"  CortexNode UUID: {record.get('cortex_uuid')}")
    else:
        print("  No OWL_KEY_VALUE_PAIR edge found for OWL key: {owl_key}")

    # 4. Graph representation (Cypher path)
    print("\n--- 4. Graph Representation (Path) ---")
    path_result = await driver.execute_query(
        "MATCH path = (n:NormNode)-[e:OWL_KEY_VALUE_PAIR]->(c:CortexNode) "
        "WHERE n.owl_key = $owl_key "
        "RETURN path",
        owl_key=owl_key,
        group_id=group_id,
    )
    
    if path_result and path_result[0]:
        for record in path_result[0]:
            path = record.get('path')
            if path:
                print(f"  Path type: {type(path).__name__}")
                # In FalkorDB/Neo4j, path is typically a Path object with nodes and relationships
                print(f"  Path representation: {path}")
    else:
        print("  No path found for OWL key: {owl_key}")

    # 5. Invariant verification
    print("\n--- 5. Invariant Verification ---")
    verification = await service.verify_owl_invariants(group_id)
    print(f"  NormNodes: {verification['norm_nodes_count']}")
    print(f"  CortexNodes: {verification['cortex_nodes_count']}")
    print(f"  OWL_KEY_VALUE_PAIR edges: {verification['owl_edges_count']}")
    print(f"  All invariants passed: {verification['all_passed']}")
    if verification["violations"]:
        print(f"  Violations found: {len(verification['violations'])}")
        for v in verification["violations"]:
            print(f"    - {v}")
    else:
        print("  No violations found.")

    await driver.close()


async def main():
    """Run the single entry report."""
    # Initialize service
    service = GraphitiService(db_path="data/owl_demo.db")

    try:
        await service.start()
        logger.info("GraphitiService started")

        # Generate report for a sample OWL key
        # Use the first demo pair from the integration script
        await generate_single_entry_report(service, group_id="owl_demo", owl_key="ReserveGuard")

    except Exception as e:
        logger.error(f"Error during report generation: {e}")
        import traceback
        traceback.print_exc()
        return 1

    finally:
        await service.stop()
        logger.info("GraphitiService stopped")

    return 0


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)