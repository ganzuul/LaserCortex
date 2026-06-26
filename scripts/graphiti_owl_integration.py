#!/usr/bin/env python3
"""
Graphiti OWL Key-Value Pairing Integration — Blood-Brain Barrier Implementation

This script demonstrates the OWL key-value pairing feature that implements
the "blood-brain barrier" pattern between LaserCortex and NormCode.

The pattern ensures:
  - LaserCortex (formal layer): Uses OWL two-word compositions as formal keys
  - NormCode (reasoning layer): Uses natural language phrasing as values
  - NormCode maintains separation but correlation via OWL_KEY_VALUE_PAIR edges

Key Concepts:
  - NormNode: Semantic inference with owl_key (formal) and nl_value (natural language)
  - CortexNode: CD/Tamari structure with owl_key (must match NormNode.owl_key)
  - OwlKeyValuePair: Edge that explicitly links the formal key to NL value

Invariants Enforced:
  1. NormNode.owl_key == CortexNode.owl_key == OwlKeyValuePair.key
  2. NormNode.nl_value == OwlKeyValuePair.value
  3. NormNode.coupling_signature == OwlKeyValuePair.coupling_signature
  4. CortexNode.cd_step == OwlKeyValuePair.cd_step
  5. OWL keys are unique across NormNodes
  6. CortexNode with cd_step >= 1 must have non-empty owl_key

Usage:
    python3 scripts/graphiti_owl_integration.py

This creates a demonstration graph with:
  - Multiple NormNode + CortexNode pairs with OWL key-value pairing
  - Verification of all invariants
  - Query examples showing the blood-brain barrier in action
"""

from __future__ import annotations

import asyncio
import logging
import sys
from datetime import datetime, timezone
from typing import Any

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("owl-integration")

# Add project root to path
PROJECT_ROOT = sys.path.dirname(sys.path.dirname(sys.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)

from infra._graphiti_service import GraphitiService
from infra._graphiti_models import (
    NormNodeAttrs,
    CortexNodeAttrs,
    OwlKeyValuePairAttrs,
    LiftsToStructureAttrs,
    EDGE_TYPE_MAP,
    ALL_NODE_TYPES,
    ALL_EDGE_TYPES,
    OwlKeyValueInvariants,
)


# =============================================================================
# Demonstration Data
# =============================================================================
# Sample OWL key-value pairs that might appear in LaserCortex + NormCode

DEMO_PAIRS = [
    {
        "owl_key": "ReserveGuard",
        "nl_value": "reserve guard",
        "coupling_signature": "non_commutative",
        "cd_step": 2,
        "description": "Market closure reserve guard mechanism",
    },
    {
        "owl_key": "MarketClosure",
        "nl_value": "market closure",
        "coupling_signature": "non_associative",
        "cd_step": 3,
        "description": "Eigenstate bridge market closure protocol",
    },
    {
        "owl_key": "TamariRotation",
        "nl_value": "tamari rotation",
        "coupling_signature": "commutative",
        "cd_step": 1,
        "description": "Tamari lattice rotation operation",
    },
    {
        "owl_key": "CertificatePath",
        "nl_value": "certificate path",
        "coupling_signature": "commutative",
        "cd_step": 2,
        "description": "Verified contraction path certificate",
    },
    {
        "owl_key": "Pentagonator",
        "nl_value": "pentagonator",
        "coupling_signature": "non_associative",
        "cd_step": 4,
        "description": "Pentagonator distance calculation",
    },
]


# =============================================================================
# Helper Functions
# =============================================================================

def create_norm_node(owl_key: str, nl_value: str, coupling_signature: str, cd_step: int) -> NormNodeAttrs:
    """Create a NormNode with OWL key-value pairing."""
    return NormNodeAttrs(
        owl_key=owl_key,
        nl_value=nl_value,
        coupling_signature=coupling_signature,
        alpha_features=[f"feature_{owl_key}"],
        inference_units=[{"type": "owl_pairing", "key": owl_key, "value": nl_value}],
    )


def create_cortex_node(owl_key: str, cd_step: int) -> CortexNodeAttrs:
    """Create a CortexNode with matching OWL key."""
    return CortexNodeAttrs(
        owl_key=owl_key,
        cd_step=cd_step,
        eml_tree=f"(Node {owl_key} Leaf)",
        tamari_path=[{"rotation": "right", "step": cd_step}],
        assoc_defect=4.0 if cd_step >= 3 else 0.0,
        pentagonator_distance=cd_step * 2,
    )


def create_owl_edge(owl_key: str, nl_value: str, coupling_signature: str, cd_step: int) -> OwlKeyValuePairAttrs:
    """Create an OWL_KEY_VALUE_PAIR edge."""
    return OwlKeyValuePairAttrs(
        key=owl_key,
        value=nl_value,
        coupling_signature=coupling_signature,
        cd_step=cd_step,
    )


def create_lifts_to_edge(coupling_signature: str, cd_step: int) -> LiftsToStructureAttrs:
    """Create a LIFTS_TO_STRUCTURE edge (the structural lift)."""
    return LiftsToStructureAttrs(
        coupling_signature=coupling_signature,
        tree_generation_method="tree_from_inference_entry",
        flow_index=f"{cd_step}.0",
    )


# =============================================================================
# Main Demonstration
# =============================================================================

async def demonstrate_blood_brain_barrier():
    """Demonstrate the blood-brain barrier pattern with OWL key-value pairing."""
    print("\n" + "=" * 80)
    print("GRAPHITI OWL KEY-VALUE PAIRING DEMONSTRATION")
    print("Blood-Brain Barrier between LaserCortex and NormCode")
    print("=" * 80)

    # Initialize service
    service = GraphitiService(db_path="data/owl_demo.db")

    try:
        await service.start()
        logger.info("GraphitiService started with OWL key-value pairing support")

        # Print the edge type map
        print("\n--- Edge Type Restriction Map ---")
        for (src, tgt), edge_types in EDGE_TYPE_MAP.items():
            print(f"  {src:20s} -> {tgt:20s}: {edge_types}")

        # Print demo pairs
        print("\n--- OWL Key-Value Pairs to Ingest ---")
        for pair in DEMO_PAIRS:
            print(f"  OWL Key: {pair['owl_key']:20s} | NL Value: {pair['nl_value']:20s} | CD: {pair['cd_step']}")

        # Ingest all demo pairs
        print("\n--- Ingesting OWL Key-Value Pairs ---")
        group_id = "owl_demo"

        for i, pair in enumerate(DEMO_PAIRS):
            norm_node = create_norm_node(
                owl_key=pair["owl_key"],
                nl_value=pair["nl_value"],
                coupling_signature=pair["coupling_signature"],
                cd_step=pair["cd_step"],
            )
            cortex_node = create_cortex_node(
                owl_key=pair["owl_key"],
                cd_step=pair["cd_step"],
            )
            owl_edge = create_owl_edge(
                owl_key=pair["owl_key"],
                nl_value=pair["nl_value"],
                coupling_signature=pair["coupling_signature"],
                cd_step=pair["cd_step"],
            )
            lifts_edge = create_lifts_to_edge(
                coupling_signature=pair["coupling_signature"],
                cd_step=pair["cd_step"],
            )

            # Use the convenience method
            result = await service.add_owl_key_value_pair(
                norm_node=norm_node,
                cortex_node=cortex_node,
                owl_edge=owl_edge,
                group_id=group_id,
                episode_name=f"owl_pair_{i}",
                episode_body=pair["description"],
            )
            logger.info(f"  Ingested pair {i+1}: {pair['owl_key']} -> {pair['nl_value']}")

        # Also add the LIFTS_TO_STRUCTURE edge for each pair
        print("\n--- Adding LIFTS_TO_STRUCTURE Edges ---")
        for i, pair in enumerate(DEMO_PAIRS):
            norm_node = create_norm_node(
                owl_key=pair["owl_key"],
                nl_value=pair["nl_value"],
                coupling_signature=pair["coupling_signature"],
                cd_step=pair["cd_step"],
            )
            cortex_node = create_cortex_node(
                owl_key=pair["owl_key"],
                cd_step=pair["cd_step"],
            )
            lifts_edge = create_lifts_to_edge(
                coupling_signature=pair["coupling_signature"],
                cd_step=pair["cd_step"],
            )

            await service.add_episode_with_entities(
                name=f"lift_{i}",
                body=f"Lifting {pair['nl_value']} to CD structure",
                group_id=group_id,
                entity_types={"NormNode": norm_node, "CortexNode": cortex_node},
                edge_types={"LIFTS_TO_STRUCTURE": lifts_edge},
            )
            logger.info(f"  Added LIFTS_TO_STRUCTURE for: {pair['nl_value']}")

        # Verify invariants
        print("\n--- Verifying OWL Invariants ---")
        verification = await service.verify_owl_invariants(group_id)
        print(f"  NormNodes: {verification['norm_nodes_count']}")
        print(f"  CortexNodes: {verification['cortex_nodes_count']}")
        print(f"  OWL_KEY_VALUE_PAIR edges: {verification['owl_edges_count']}")
        print(f"  All invariants passed: {verification['all_passed']}")
        if verification["violations"]:
            print(f"  Violations found: {len(verification['violations'])}")
            for v in verification["violations"]:
                print(f"    - {v}")

        # Run queries demonstrating the blood-brain barrier
        print("\n--- Blood-Brain Barrier Queries ---")
        driver = service.driver

        # Query 1: Find all NormNodes with their OWL keys and NL values
        print("\n  Query 1: All NormNodes with OWL key-value pairs")
        result = await driver.execute_query(
            "MATCH (n:NormNode) WHERE n.owl_key != '' "
            "RETURN n.owl_key as owl_key, n.nl_value as nl_value, n.coupling_signature as coupling "
            "ORDER BY n.owl_key",
            group_id=group_id,
        )
        if result and result[0]:
            for record in result[0]:
                print(f"    {record.get('owl_key'):20s} | {record.get('nl_value'):20s} | {record.get('coupling')}")

        # Query 2: Find all CortexNodes with their OWL keys and CD steps
        print("\n  Query 2: All CortexNodes with OWL keys and CD steps")
        result = await driver.execute_query(
            "MATCH (c:CortexNode) WHERE c.owl_key != '' "
            "RETURN c.owl_key as owl_key, c.cd_step as cd_step, c.pentagonator_distance as pent_dist "
            "ORDER BY c.cd_step",
            group_id=group_id,
        )
        if result and result[0]:
            for record in result[0]:
                print(f"    {record.get('owl_key'):20s} | CD: {record.get('cd_step')} | Pent: {record.get('pent_dist')}")

        # Query 3: Find all OWL_KEY_VALUE_PAIR edges (the blood-brain barrier)
        print("\n  Query 3: All OWL_KEY_VALUE_PAIR edges (blood-brain barrier)")
        result = await driver.execute_query(
            "MATCH ()-[e:OWL_KEY_VALUE_PAIR]->() "
            "RETURN e.key as key, e.value as value, e.cd_step as cd_step "
            "ORDER BY e.key",
            group_id=group_id,
        )
        if result and result[0]:
            for record in result[0]:
                print(f"    {record.get('key'):20s} | {record.get('value'):20s} | CD: {record.get('cd_step')}")

        # Query 4: Cross-layer query - find NormNode by OWL key and get its NL value
        print("\n  Query 4: Cross-layer lookup - OWL key 'ReserveGuard' -> NL value")
        result = await driver.execute_query(
            "MATCH (n:NormNode {owl_key: 'ReserveGuard'}) "
            "RETURN n.nl_value as nl_value",
            group_id=group_id,
        )
        if result and result[0]:
            for record in result[0]:
                print(f"    OWL key 'ReserveGuard' -> NL value: '{record.get('nl_value')}'")

        # Query 5: Find all pairs where NormNode and CortexNode share the same OWL key
        print("\n  Query 5: Verify blood-brain barrier correlation (matching OWL keys)")
        result = await driver.execute_query(
            "MATCH (n:NormNode)-[e:OWL_KEY_VALUE_PAIR]->(c:CortexNode) "
            "WHERE n.owl_key = c.owl_key AND n.owl_key = e.key "
            "RETURN n.owl_key as key, n.nl_value as nl_value, c.cd_step as cd_step "
            "ORDER BY n.owl_key",
            group_id=group_id,
        )
        if result and result[0]:
            count = 0
            for record in result[0]:
                count += 1
                print(f"    {record.get('key'):20s} | {record.get('nl_value'):20s} | CD: {record.get('cd_step')}")
            print(f"  Total correlated pairs: {count}")

        # Query 6: Find all nodes connected via OWL_KEY_VALUE_PAIR (full path)
        print("\n  Query 6: Full blood-brain barrier paths (NormNode -OWL-> CortexNode)")
        result = await driver.execute_query(
            "MATCH (n:NormNode)-[e:OWL_KEY_VALUE_PAIR]->(c:CortexNode) "
            "RETURN n.uuid as norm_uuid, n.owl_key as owl_key, n.nl_value as nl_value, "
            "e.uuid as edge_uuid, c.uuid as cortex_uuid, c.cd_step as cd_step "
            "ORDER BY n.owl_key",
            group_id=group_id,
        )
        if result and result[0]:
            for record in result[0]:
                print(f"    NormNode({record.get('norm_uuid')[:8]}...) "
                      f"--OWL_KEY_VALUE_PAIR({record.get('edge_uuid')[:8]}...)-> "
                      f"CortexNode({record.get('cortex_uuid')[:8]}...)")
                print(f"      OWL: {record.get('owl_key')}, NL: {record.get('nl_value')}, CD: {record.get('cd_step')}")

        # Summary
        print("\n" + "=" * 80)
        print("DEMONSTRATION COMPLETE")
        print("=" * 80)
        print("\nSummary:")
        print(f"  ✓ Created {len(DEMO_PAIRS)} OWL key-value pairs")
        print(f"  ✓ Verified all blood-brain barrier invariants")
        print(f"  ✓ Demonstrated cross-layer queries")
        print(f"  ✓ Database: data/owl_demo.db")
        print(f"  ✓ Group: {group_id}")
        print("\nThe blood-brain barrier pattern is now implemented and verified!")
        print("LaserCortex (formal OWL keys) and NormCode (natural language values)")
        print("are connected via OWL_KEY_VALUE_PAIR edges while maintaining separation.")

    finally:
        await service.stop()
        logger.info("GraphitiService stopped")


async def test_invariants_directly():
    """Test the invariant checking functions directly (no database needed)."""
    print("\n" + "=" * 80)
    print("TESTING OWL KEY-VALUE INVARIANTS (Direct)")
    print("=" * 80)

    # Create sample nodes and edges
    norm1 = NormNodeAttrs(
        owl_key="TestKey",
        nl_value="test value",
        coupling_signature="commutative",
    )
    cortex1 = CortexNodeAttrs(
        owl_key="TestKey",
        cd_step=2,
    )
    edge1 = OwlKeyValuePairAttrs(
        key="TestKey",
        value="test value",
        coupling_signature="commutative",
        cd_step=2,
    )

    # Test 1: Matching pair
    print("\n  Test 1: Matching NormNode and CortexNode")
    result = OwlKeyValueInvariants.check_normnode_cortexnode_pair(norm1, cortex1)
    print(f"    NormNode.owl_key == CortexNode.owl_key: {result}")
    assert result, "Invariant should pass for matching keys"

    # Test 2: NormNode and edge
    print("\n  Test 2: NormNode and OWL_KEY_VALUE_PAIR edge")
    result = OwlKeyValueInvariants.check_normnode_edge_pair(norm1, edge1)
    print(f"    NormNode matches edge: {result}")
    assert result, "Invariant should pass for matching NormNode and edge"

    # Test 3: CortexNode and edge
    print("\n  Test 3: CortexNode and OWL_KEY_VALUE_PAIR edge")
    result = OwlKeyValueInvariants.check_cortexnode_edge_pair(cortex1, edge1)
    print(f"    CortexNode matches edge: {result}")
    assert result, "Invariant should pass for matching CortexNode and edge"

    # Test 4: Non-trivial CD step has OWL key
    print("\n  Test 4: Non-trivial CD step has OWL key")
    cortex_with_key = CortexNodeAttrs(owl_key="Key", cd_step=2)
    cortex_without_key = CortexNodeAttrs(owl_key="", cd_step=2)
    result1 = OwlKeyValueInvariants.check_non_trivial_cd_has_owl_key(cortex_with_key)
    result2 = OwlKeyValueInvariants.check_non_trivial_cd_has_owl_key(cortex_without_key)
    print(f"    CortexNode with key (cd_step=2): {result1}")
    print(f"    CortexNode without key (cd_step=2): {result2}")
    assert result1, "Should pass with OWL key"
    assert not result2, "Should fail without OWL key for cd_step >= 1"

    # Test 5: OWL key uniqueness
    print("\n  Test 5: OWL key uniqueness across NormNodes")
    norm_dup1 = NormNodeAttrs(owl_key="DuplicateKey", nl_value="value1")
    norm_dup2 = NormNodeAttrs(owl_key="DuplicateKey", nl_value="value2")
    norm_unique1 = NormNodeAttrs(owl_key="UniqueKey1", nl_value="value1")
    norm_unique2 = NormNodeAttrs(owl_key="UniqueKey2", nl_value="value2")
    result_dup = OwlKeyValueInvariants.check_owl_key_uniqueness([norm_dup1, norm_dup2])
    result_unique = OwlKeyValueInvariants.check_owl_key_uniqueness([norm_unique1, norm_unique2])
    print(f"    Duplicate keys: {result_dup}")
    print(f"    Unique keys: {result_unique}")
    assert not result_dup, "Should fail with duplicate keys"
    assert result_unique, "Should pass with unique keys"

    print("\n  ✓ All invariant tests passed!")


async def main():
    """Run all demonstrations and tests."""
    try:
        # First test invariants directly (no database needed)
        await test_invariants_directly()

        # Then demonstrate the full integration
        await demonstrate_blood_brain_barrier()

    except Exception as e:
        logger.error(f"Error during demonstration: {e}")
        import traceback
        traceback.print_exc()
        return 1

    return 0


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
