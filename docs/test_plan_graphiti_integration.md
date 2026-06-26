# Test Plan: Graphiti Integration for LaserCortex + NormCode + Reasoning Library

## Test Architecture

Six levels, bottom-up:

```
┌─────────────────────────────────────────────┐
│  Level 6: End-to-End Integration            │  e2e
│  (trace → graphiti → search → recipe)       │
├─────────────────────────────────────────────┤
│  Level 5: Cross-Layer Integration           │  cross_layer
│  (bridge→graphiti, NormCode→graphiti)       │
├─────────────────────────────────────────────┤
│  Level 4: Graphiti Integration              │  integration
│  (custom types, temporal query, provenance) │
├─────────────────────────────────────────────┤
│  Level 3: Migration Correctness             │  migration
│  (old pipeline output == new graph output)  │
├─────────────────────────────────────────────┤
│  Level 2: Property-Based Invariants         │  unit
│  (CD monotonic, temporal consistency, etc.) │
├─────────────────────────────────────────────┤
│  Level 1: Unit Models                       │  unit
│  (Pydantic types, edge map, constraints)    │
└─────────────────────────────────────────────┘
```

**Stateful and resource-intensive tests are ordered last**. Any test in Levels
3–6 may depend on the FalkorDB Lite database being available; tests in Levels
1–2 are pure and run in <10 ms each.

---

## Level 1: Unit — Data Model Validation

Tests that custom Pydantic types enforce their contracts. Pure, no external deps,
no database.

| # | Test | File Tag | What It Covers |
|---|------|----------|----------------|
| 1.1 | `test_normnode_rejects_invalid_coupling` | `test_01_models` | `coupling_signature` outside allowed set raises `ValidationError` |
| 1.2 | `test_cortexnode_rejects_out_of_range_cd` | `test_01_models` | `cd_step` outside 0..4 raises `ValidationError` |
| 1.3 | `test_cortexnode_rejects_negative_pentagonator` | `test_01_models` | Negative `pentagonator_distance` raises `ValidationError` |
| 1.4 | `test_certificatenode_default_validity` | `test_01_models` | `validity` defaults to `False` |
| 1.5 | `test_compositionevent_empty_inputs_valid` | `test_01_models` | Empty `input_node_uuids` does not raise (edge case) |
| 1.6 | `test_tamarirotation_strut_cost_quantum` | `test_01_models` | `strut_cost` must be 0.0 or 4.0; any other value raises |
| 1.7 | `test_recipenode_success_rate_clamped` | `test_01_models` | `success_rate < 0` or `> 1` raises |
| 1.8 | `test_reasoningsimilarity_weight_default` | `test_01_models` | `weight` defaults to 0.0 |
| 1.9 | `test_all_entity_types_have_required_fields` | `test_01_models` | Every Pydantic model has `name` and `uuid` at minimum |
| 1.10 | `test_liftstostructure_defaults` | `test_01_models` | `LiftsToStructure` defaults match expected values |

### Edge map completeness

| # | Test | File Tag | What It Covers |
|---|------|----------|----------------|
| 1.11 | `test_edge_type_map_key_format` | `test_01_edge_map` | Every key is a `(str, str)` tuple of existing type names |
| 1.12 | `test_edge_type_map_value_format` | `test_01_edge_map` | Every value is a list of strings |
| 1.13 | `test_edge_type_map_no_dangling_types` | `test_01_edge_map` | Every type name referenced in the map has a corresponding Pydantic model |
| 1.14 | `test_edge_type_map_bidirectional_pairs` | `test_01_edge_map` | For every forward edge `(A, B) → [type]`, if `type` has a semantic inverse, `(B, A)` also has an entry |

---

## Level 2: Property-Based Invariants

Critical invariants that must hold for all valid graph states. Use `hypothesis`
for generative testing over random EMLTrees, temporal orderings, and coupling
signatures.

| # | Property | File Tag | Formalized As |
|---|----------|----------|---------------|
| 2.1 | **CD monotonicity** | `test_02_invariants` | For any `TamariRotation` edge `u → v`: `u.cd_step ≤ v.cd_step` |
| 2.2 | **Strut cost quantum** | `test_02_invariants` | For any `TamariRotation`: if `assoc_delta > 0` then `strut_cost == 4.0` and if `assoc_delta == 0` then `strut_cost == 0.0` |
| 2.3 | **Provenance temporal order** | `test_02_invariants` | For any entity `e` referenced by edge `r`: `r.valid_at ≥ e.created_at` |
| 2.4 | **No dangling node references** | `test_02_invariants` | Every `source_node_uuid` and `target_node_uuid` in every edge resolves to a node in the same graph |
| 2.5 | **Coupling-CD compatibility** | `test_02_invariants` | `non_commutative` coupling requires `cd_step ≥ 1`; `non_associative` requires `cd_step ≥ 3` |
| 2.6 | **Certificate validity implies normal form** | `test_02_invariants` | If `CertifiesTo` edge has `verified_in_lean == true` then the target `CertificateNode` has `validity == true` |
| 2.7 | **Recipe centroid stability** | `test_02_invariants` | All `CompressesTo` edges targeting the same `RecipeNode` have `feature_signature` vectors within cosine distance ε=0.1 |
| 2.8 | **Policy-recipe consistency** | `test_02_invariants` | If `PolicyNode.selects_recipe_id` points to a `RecipeNode`, that `RecipeNode` exists in the graph |
| 2.9 | **CompositionEvent links resolve** | `test_02_invariants` | All UUIDs in `CompositionEvent.input_node_uuids ∪ output_node_uuids` resolve to existing nodes |

**Hypothesis strategies needed**:

```python
# EMLTree generation (compatible with LaserCortex EMLTree type)
@st.composite
def eml_trees(draw, max_depth=4):
    if max_depth == 0 or draw(st.booleans()):
        return "1"  # leaf
    left = draw(eml_trees(max_depth - 1))
    right = draw(eml_trees(max_depth - 1))
    return f"(eml {left} {right})"

# TamariPath generation (sequence of right/left rotations)
@st.composite
def tamari_paths(draw, max_length=10):
    n = draw(st.integers(1, max_length))
    return draw(st.lists(st.sampled_from(["right", "left"]), min_size=0, max_size=n))

# Temporal values (valid_at before invalid_at)
@st.composite
def temporal_window(draw):
    base = draw(st.datetimes(min_value=datetime(2025,1,1), max_value=datetime(2026,12,31)))
    offset = draw(st.timedeltas(min_days=0, max_days=365))
    return (base, base + offset)
```

---

## Level 3: Migration Correctness

Tests that the Graphiti-based pipeline produces the same results as the existing
JSON/embedding pipeline. Critical for zero-regression migration.

| # | Test | Comparison | Criterion |
|---|------|------------|-----------|
| 3.1 | **Trace ingestion parity** | `parser.parse_session_file()` → `SessionReasoningTrace` vs `EpisodicNode` created from same input | Same `session_id`, `thinking_block`, `intent_category`, `outcome` |
| 3.2 | **Cluster parity** | `clusterer.cluster_traces()` → `TraceCluster[]` vs `build_communities()` after ingesting same traces | Cluster membership overlap ≥ 90% on same 758 traces |
| 3.3 | **Embedding search parity** | `cosine_similarity(query_emb, centroid)` → top-K vs `graphiti.search(query)` → top-K | Top-5 overlap ≥ 80% for same query on same corpus |
| 3.4 | **Three-tier routing parity** | `ReasoningLibrary.route()` with JSON centroids vs with Graphiti centroids | Same `RoutingDecision.kind` and `script_id` for same input |
| 3.5 | **Script compression parity** | `MetaCompressor.compress_cluster()` on cluster vs on Graphiti community members | Same intent, tool chain dedup, outcome distribution (non-deterministic; check structural equality, not exact text) |
| 3.6 | **Bridge lift parity** | `CortexBridge.lift_inference()` without persistence vs same call + `add_episode()` persists result | `EMLTree.serialize()`, `CortexCertificate.uuid`, `cd_step` identical |

### Test data requirements

- 758 traces from `reasoning_library/traces.jsonl` (primary corpus)
- Pre-computed `reasoning_library/library.json` for cluster centroids
- Pre-computed `reasoning_library/scripts.json` for script comparison
- 3 NormCode `.ncd` plans: `market_closure.ncd`, `prediction_market.ncd`, `eigenstate_bridge.ncd`

---

## Level 4: Graphiti Integration

Tests that use a real FalkorDB Lite instance. These verify the new component
works correctly on its own.

| # | Test | What It Proves |
|---|------|----------------|
| 4.1 | `test_graphiti_init_falkordb_lite` | `Graphiti(graph_driver=FalkorDBLiteDriver(...))` initializes without error |
| 4.2 | `test_add_episode_custom_types` | `add_episode()` with custom `entity_types` and `edge_types` writes to graph |
| 4.3 | `test_add_episode_no_llm` | `add_episode()` with `llm_client=None` and prescribed ontology works (offline mode) |
| 4.4 | `test_search_temporal_filter` | `search()` with `valid_at`/`invalid_at` DateFilter returns only episodes in range |
| 4.5 | `test_search_group_isolation` | `search()` with `group_ids` filter respects group isolation — no cross-group leakage |
| 4.6 | `test_build_communities_nonempty` | `build_communities()` on 50+ ingested traces returns non-empty communities |
| 4.7 | `test_provenance_tracking` | Entity's `episodes` field traces back to source `EpisodicNode` |
| 4.8 | `test_add_episode_bulk_100` | `add_episode_bulk()` with 100 episodes completes in <30s and all are queryable |
| 4.9 | `test_graph_durability` | Graph data persists across `Graphiti` instance destruction and recreation on same DB path |
| 4.10 | `test_clear_group` | `clear_graph(group_id)` removes only that group's data; other groups intact |

### Fixture setup

```python
@pytest.fixture(scope="module")
def graphiti(tmp_path_factory):
    """Single FalkorDB Lite instance per module, destroyed after."""
    db_path = tmp_path_factory.mktemp("graphiti") / "test.db"
    driver = FalkorDBLiteDriver(db=str(db_path))
    g = Graphiti(
        graph_driver=driver,
        llm_client=None,  # No LLM — pure prescribed ontology
        embedder=None,    # No embeddings for basic integration tests
    )
    yield g
    driver.close()
```

---

## Level 5: Cross-Layer Integration

Tests that the pipeline from one layer through Graphiti to another layer works
end-to-end. These require both the LaserCortex bridge and Graphiti.

| # | Test | Flow |
|---|------|------|
| 5.1 | **Trace → Graph → Search** | Parse 5 known traces → ingest → `search("docker container memory")` → returns docker_lifecycle traces in top-3 |
| 5.2 | **NormCode plan → Graph → CD query** | Parse `market_closure.ncd` via bridge → lift each inference → persist CortexNodes → `search({cd_step: 3})` → returns non-assoc inferences |
| 5.3 | **Bridge certify → Graph → provenance** | Lift inference → certify → persist `CertificateNode` → trace `episodes` field back to original `.ncd` file path |
| 5.4 | **Compression → Graph → similarity** | Compress 5 related traces to `RecipeNode` → persist with `REASONING_SIMILARITY` edges → query "find similar recipes" |
| 5.5 | **Tamari lattice → Graph → BFS path** | Build `CortexNode`s for n=4 trees (14 nodes) → add `TAMARI_ROTATION` edges → BFS from leftmost to rightComb → verify path cost == pentagonator_distance |
| 5.6 | **Policy routing → Graph → selection** | Add 5 `RecipeNode`s with varying `success_rate` → add `GENERALIZED_BY` → `PolicyNode` → test that query with `center_node_uuid` returns high-success recipes first |

---

## Level 6: End-to-End

Full-pipeline integration tests from start to finish.

| # | Test | Description |
|---|------|-------------|
| 6.1 | **Bootstrap E2E** | 758 traces → Graphiti ingestion → `build_communities()` → `search` returns cross-session results → provenance traces to source session files |
| 6.2 | **Audit trail E2E** | One NormCode plan inference → `EpisodicNode` → lift → `CortexNode` → certify → `CertificateNode` → query "what was true at time T?" → correct snapshot |
| 6.3 | **Cross-layer discovery** | 10 docker traces + `market_closure.ncd` → search "reserve guard" → returns both docker trace results AND NormCode plan's AMM pool concept (stereoscopic listening) |
| 6.4 | **Contradiction detection** | Two traces with same intent but opposite outcomes → temporal edges show contradiction → community separation reflects unresolved fork |
| 6.5 | **Distillation cycle** | 5 traces → compress `RecipeNode` → add to graph → new trace arrives → `search()` finds recipe → route via recipe → record outcome → `success_rate` updated → policy emerges |

---

## Resource Safety Tests

From `SAFETY.md` — must pass for any bulk operation.

| # | Test | Constraint |
|---|------|------------|
| R.1 | Bulk ingest 758 traces | RSS stays under 1 GB additional |
| R.2 | `build_communities()` on 758-node graph | Completes within 30 seconds |
| R.3 | Concurrent `search()` (3 workers) | RSS increase ≤ 500 MB |
| R.4 | FalkorDB Lite DB file for 758 traces | ≤ 500 MB on disk |

---

## Marker Definitions

Add to `pyproject.toml`:

```toml
[tool.pytest.ini_options]
markers = [
    "unit: Level 1-2 — pure Pydantic + property tests (<10ms each)",
    "migration: Level 3 — parity with existing pipeline outputs",
    "integration: Level 4 — Graphiti with real FalkorDB Lite",
    "cross_layer: Level 5 — bridge + NormCode + Graphiti",
    "e2e: Level 6 — full pipeline from end to end",
    "resource_safety: Resource consumption constraints",
]
```

### CI tiers

| Gate | Markers | Est. time | Frequency |
|------|---------|-----------|-----------|
| PR gate | `unit or migration` | <30 s | Every PR |
| Daily | `unit or migration or integration` | <2 min | Nightly |
| Weekly | `cross_layer or e2e or resource_safety` | <5 min | Weekly |

---

## File Layout

```
tests/graphiti_integration/
├── conftest.py              # Fixtures: FalkorDB Lite, Graphiti, sample data
├── test_01_models.py        # L1: Pydantic type validation (13 tests)
├── test_01_edge_map.py      # L1: Edge map completeness (4 tests)
├── test_02_invariants.py    # L2: Property-based invariants (9 tests)
├── test_03_migration.py     # L3: Migration parity (6 tests)
├── test_04_graphiti.py      # L4: Graphiti integration (10 tests)
├── test_05_cross_layer.py   # L5: Cross-layer (6 tests)
├── test_06_e2e.py           # L6: End-to-end (5 tests)
├── test_99_resource_safety.py  # R: Resource safety (4 tests)
```

Total: **57 tests** across 9 test files.

---

## Dependencies

| Package | Version | Used By | Mandatory? |
|---------|---------|---------|------------|
| `pytest` | ≥7.0 | All | Yes |
| `pytest-cov` | ≥4.0 | Coverage | Yes |
| `hypothesis` | ≥6.0 | Level 2 | Yes |
| `pydantic` | ≥2.0 | All type models | Yes |
| `graphiti-core[falkordblite]` | ≥0.29 | Levels 4-6, R | Yes |
| `psutil` | — | Resource safety | Only R |

---

## Verification Checklist

Before marking the integration as complete:

- [ ] All 57 tests pass with `pytest -v tests/graphiti_integration/`
- [ ] Code coverage ≥90% for `graphiti_integration/` modules
- [ ] Hypothesis finds no counterexamples in 1000 runs per property
- [ ] Migration parity tests pass on full 758-trace corpus
- [ ] Resource safety tests pass under SAFETY.md constraints
- [ ] `pytest -m "unit or migration"` completes in <30 s
