# Plan: Uplifting Coherent Error → Tool Success Patterns

**Status**: Draft (Refinement Phase)  
**Created**: 2025-01-XX  
**Owner**: NormCode + LaserCortex Integration  
**Related**: Graphiti Integration (`graphiti-integration` branch)  

---

## 1. Executive Summary

### Problem Statement

In reasoning-trace → tool-use cycles, we observe a **learning trajectory pattern** where:
1. Initial tool use attempts are broad/imprecise and fail
2. Error messages contain **semantically coherent** signals (not random noise)
3. The model incorporates error feedback into subsequent reasoning
4. Through iteration, tool use **hones in** on success
5. The error→correction→success trajectory **teaches** the model how to achieve goals

This pattern is currently **implicit** in session traces. We need to **explicitly capture, store, and query** it to enable:
- Reuse of successful error-recovery strategies
- Routing based on error patterns
- Measurement of model learning trajectories
- Cross-session transfer of error-handling knowledge

### Success Criteria

| ID | Criterion | Metric | Target |
|---|---|---|---|
| S1 | Error patterns are extractable from traces | % of traces with identifiable error→success | >80% |
| S2 | Error→success recipes are queryable | Query latency | <100ms |
| S3 | Error routing improves success rate | Success rate delta | +15% |
| S4 | Patterns generalize across sessions | Cross-session reuse rate | >40% |

---

## 2. Pattern Definition

### 2.1 Coherent Error Characteristics

A **coherent error** has these properties:

| Property | Description | Example |
|---|---|---|
| **Actionable** | Error message contains information usable for correction | `FileNotFoundError: /path/to/missing/file` → try `/path/to/correct/file` |
| **Semantically Stable** | Error type is consistent across similar attempts | Always `SyntaxError` for malformed JSON, not random errors |
| **Progressive** | Each error brings the model closer to success | First: wrong directory, Second: wrong filename, Third: success |
| **Context-Preserving** | Error relates to the same underlying intent | All errors are about accessing the same logical resource |

### 2.2 Error→Success Trajectory Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    ERROR→SUCCESS TRAJECTORY                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ReasoningTrace─┬─thinks: "I need to read the config file"──────► ToolUse1 │
│                 │         command: "cat /etc/config"                    │
│                 └─ENCOUNTERS_ERROR─► ErrorNode1                        │
│                                   error: "No such file or directory"   │
│                                   type: "FileNotFoundError"             │
│                                   iteration: 1                          │
│                                                                     │
│  ReasoningTrace─┬─thinks: "Maybe it's in a different location"────► ToolUse2 │
│                 │         command: "cat /opt/app/config"               │
│                 └─ENCOUNTERS_ERROR─► ErrorNode2                        │
│                                   error: "Permission denied"            │
│                                   type: "PermissionError"              │
│                                   iteration: 2                          │
│                                                                     │
│  ReasoningTrace─┬─thinks: "Let me try with sudo"─────────────────► ToolUse3 │
│                 │         command: "sudo cat /opt/app/config"         │
│                 └─ACHIEVES_SUCCESS─► SuccessNode                       │
│                                   result: "{setting: value}"          │
│                                   iteration: 3                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────────────┐
                    │   ErrorSuccessRecipe    │
                    │  (Compressed Pattern)   │
                    │                         │
                    │  error_pattern: "File.*" │
                    │  initial: "cat /etc/..."│
                    │  final: "sudo cat ..."  │
                    │  error_count: 2         │
                    │  success_rate: 0.85     │
                    │  semantic_shift: 0.42    │
                    └─────────────────────────┘
```

### 2.3 Coherence Metrics

We quantify "coherence" using:

```python
# Semantic coherence: error messages are semantically related
def semantic_coherence(errors: list[str]) -> float:
    embeddings = embedder.embed(errors)
    pairwise_similarities = cosine_similarity(embeddings)
    return pairwise_similarities.mean()

# Progressive coherence: each step reduces distance to success
def progressive_coherence(
    reasoning_states: list[str],
    success_state: str
) -> float:
    distances = [cosine_distance(embed(r), embed(success_state)) 
                 for r in reasoning_states]
    # Should be monotonically decreasing
    return -np.mean(np.diff(distances))  # Positive = improving

# Intent coherence: all errors relate to same underlying goal
def intent_coherence(
    initial_intent: str,
    errors: list[str],
    success: str
) -> float:
    intent_embedding = embed(initial_intent)
    all_embeddings = [intent_embedding] + embed(errors) + [embed(success)]
    return 1.0 - cosine_distance_matrix(all_embeddings).max()
```

---

## 3. Architecture

### 3.1 Component Model

```
┌─────────────────────────────────────────────────────────────────┐
│                        GRAPHITI GRAPH                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │ Reasoning    │     │   Error      │     │  Success     │    │
│  │   Trace      │────►│    Node      │────►│    Node      │    │
│  └──────────────┘     └──────────────┘     └──────────────┘    │
│         │                   │                   │              │
│         │ ENCOUNTERS_ERROR  │ CORRECTS_TO       │              │
│         ▼                   ▼                   ▼              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │  ToolUse     │     │  Correction   │     │   ToolUse    │    │
│  │  (failing)   │     │    Step       │     │  (succeeding)│    │
│  └──────────────┘     └──────────────┘     └──────────────┘    │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    ErrorSuccessRecipe                      │    │
│  │  (Compressed from multiple Error→Correction→Success paths) │    │
│  └─────────────────────────────────────────────────────────┘    │
│                         │                                          │
│                         ▼                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    ErrorRoutingPolicy                       │    │
│  │  (Routes based on error patterns to appropriate recipes)  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Node Types

#### ErrorNode (→ EntityNode)

| Field | Type | Description |
|---|---|---|
| `error_message` | `str` | Raw error message text |
| `error_type` | `str` | Classified error category (FileNotFoundError, SyntaxError, etc.) |
| `error_code` | `int` | HTTP status code or exit code |
| `iteration` | `int` | Which attempt in the sequence (1-indexed) |
| `time_to_correction` | `float` | Seconds until next tool use |
| `semantic_fingerprint` | `list[float]` | Embedding of error message |
| `coherence_score` | `float` | How coherent this error is with trajectory (0.0-1.0) |

#### SuccessNode (→ EntityNode)

| Field | Type | Description |
|---|---|---|
| `result` | `str` | Output from successful tool use |
| `iteration` | `int` | Final attempt number |
| `total_time` | `float` | Total seconds from first attempt to success |
| `semantic_fingerprint` | `list[float]` | Embedding of success result |

#### ErrorSuccessRecipeNode (→ RecipeNode, extends base)

| Field | Type | Description |
|---|---|---|
| `error_pattern` | `str` | Regex pattern matching error type |
| `initial_command` | `str` | First (failing) command template |
| `final_command` | `str` | Successful command template |
| `error_count` | `int` | Typical number of errors in trajectory |
| `correction_steps` | `list[str]` | List of reasoning adjustments |
| `semantic_shift` | `float` | Embedding distance from first error to success |
| `success_rate` | `float` | Historical success rate (0.0-1.0) |
| `cd_step` | `int` | CD step where this pattern emerges |
| `coherence_score` | `float` | Average coherence across instances |

#### ErrorRoutingPolicyNode (→ PolicyNode, extends base)

| Field | Type | Description |
|---|---|---|
| `error_type` | `str` | Error category this policy handles |
| `error_pattern` | `str` | Regex pattern for matching errors |
| `confidence` | `float` | Confidence in this routing (0.0-1.0) |
| `cooccurrence_count` | `int` | How many times we've seen this pattern |
| `last_activated` | `str` | ISO timestamp of last use |
| `average_iterations` | `float` | Average iterations to success |

### 3.3 Edge Types

#### ENCOUNTERS_ERROR (ReasoningTrace → ErrorNode)

```python
class EncountersErrorAttrs(BaseModel):
    """Edge: ReasoningTrace → ErrorNode"""
    tool_name: str = ""           # Which tool was used
    command: str = ""             # The command that failed
    exit_code: int = 0            # Exit code from tool
    timestamp: str = ""           # When the error occurred
```

#### CORRECTS_TO (ErrorNode → SuccessNode or ErrorSuccessRecipeNode)

```python
class CorrectsToAttrs(BaseModel):
    """Edge: ErrorNode → SuccessNode or RecipeNode"""
    correction_method: str = ""    # How the error was addressed
    reasoning_delta: str = ""      # Change in reasoning approach
    cd_step_delta: int = 0         # Change in CD step complexity
    semantic_distance: float = 0.0 # Embedding distance overcome
```

#### ACHIEVES_SUCCESS (ReasoningTrace → SuccessNode)

```python
class AchievesSuccessAttrs(BaseModel):
    """Edge: ReasoningTrace → SuccessNode"""
    tool_name: str = ""
    command: str = ""
    exit_code: int = 0
    timestamp: str = ""
    total_attempts: int = 1
```

#### COMPRESSES_FROM (ErrorSuccessRecipeNode → ErrorNode, SuccessNode)

```python
class CompressesFromAttrs(BaseModel):
    """Edge: RecipeNode → ErrorNode/SuccessNode (source instances)"""
    compression_ratio: float = 0.0
    instance_count: int = 0
    last_compressed: str = ""
```

#### ROUTES_ERROR (ErrorRoutingPolicyNode → ErrorSuccessRecipeNode)

```python
class RoutesErrorAttrs(BaseModel):
    """Edge: PolicyNode → RecipeNode (error routing)"""
    routing_frequency: int = 0
    last_routed: str = ""
    success_rate: float = 0.0
```

### 3.4 Edge Type Restriction Map (Additions)

```python
# New entries for error→success pattern
EDGE_TYPE_MAP_UPDATE = {
    ("ReasoningTrace", "ErrorNode"): ["ENCOUNTERS_ERROR"],
    ("ReasoningTrace", "SuccessNode"): ["ACHIEVES_SUCCESS"],
    ("ErrorNode", "SuccessNode"): ["CORRECTS_TO"],
    ("ErrorNode", "ErrorSuccessRecipeNode"): ["CORRECTS_TO"],
    ("ErrorSuccessRecipeNode", "ErrorNode"): ["COMPRESSES_FROM"],
    ("ErrorSuccessRecipeNode", "SuccessNode"): ["COMPRESSES_FROM"],
    ("ErrorRoutingPolicyNode", "ErrorSuccessRecipeNode"): ["ROUTES_ERROR"],
    ("ErrorNode", "ErrorNode"): ["PRECEDES"],  # For error sequences
}
```

---

## 4. Implementation Phases

### Phase 1: Data Extraction (Week 1)

**Goal**: Extract error→success patterns from existing reasoning traces.

**Tasks**:
1. [ ] Create `scripts/extract_error_patterns.py`
   - Parse `reasoning_library/traces.jsonl`
   - Identify tool use sequences with errors followed by success
   - Extract error messages, commands, iterations
   - Calculate coherence scores

2. [ ] Define error classification taxonomy
   - File system errors (FileNotFoundError, PermissionError, etc.)
   - Syntax errors (JSONDecodeError, SyntaxError, etc.)
   - Logical errors (AssertionError, ValueError, etc.)
   - Network errors (ConnectionError, TimeoutError, etc.)

3. [ ] Create `ErrorClassifier` using embedding similarity
   - Classify errors into categories
   - Detect coherent error sequences

**Deliverables**:
- `data/error_patterns.jsonl` - Extracted error→success trajectories
- `scripts/extract_error_patterns.py` - Extraction script
- Error classification taxonomy

**Success Metrics**:
- Number of error→success trajectories extracted
- Classification accuracy (manual review of sample)

---

### Phase 2: Graph Schema (Week 2)

**Goal**: Add error→success node/edge types to Graphiti integration.

**Tasks**:
1. [ ] Add new models to `infra/_graphiti_models.py`
   - `ErrorNodeAttrs`
   - `SuccessNodeAttrs`
   - `ErrorSuccessRecipeAttrs` (extends `RecipeNodeAttrs`)
   - `ErrorRoutingPolicyAttrs` (extends `PolicyNodeAttrs`)
   - Edge attribute models

2. [ ] Update `EDGE_TYPE_MAP` in models and tests

3. [ ] Add ingestion methods to `infra/_graphiti_service.py`
   - `add_error_trajectory()`
   - `add_error_success_recipe()`
   - `add_error_routing_policy()`

4. [ ] Update test suite
   - Add tests for new models
   - Add invariant tests for error patterns
   - Update edge map tests

**Deliverables**:
- Updated `infra/_graphiti_models.py`
- Updated `infra/_graphiti_service.py`
- Updated test suite (100% pass rate)

**Success Metrics**:
- All existing tests still pass
- New tests cover all new functionality

---

### Phase 3: Ingestion Pipeline (Week 3)

**Goal**: Automatically ingest error→success patterns into Graphiti.

**Tasks**:
1. [ ] Create `scripts/ingest_error_patterns.py`
   - Read extracted error patterns
   - Create ErrorNode, SuccessNode, edges
   - Ingest into Graphiti with proper group isolation

2. [ ] Add to `scripts/graphiti_bootstrap.py`
   - Ingest error patterns as part of bootstrap
   - Create initial ErrorSuccessRecipe nodes

3. [ ] Create MCP tools for error pattern management
   - `graphiti_add_error_trajectory`
   - `graphiti_query_error_patterns`
   - `graphiti_get_error_recipe`

**Deliverables**:
- `scripts/ingest_error_patterns.py`
- Updated `scripts/graphiti_bootstrap.py`
- MCP tool extensions

**Success Metrics**:
- Error patterns ingested into Graphiti
- MCP tools functional

---

### Phase 4: Compression & Routing (Week 4)

**Goal**: Compress error→success trajectories into reusable recipes and policies.

**Tasks**:
1. [ ] Create `scripts/compress_error_patterns.py`
   - Cluster similar error trajectories
   - Create ErrorSuccessRecipe nodes
   - Calculate success rates, coherence scores

2. [ ] Create `scripts/generate_error_policies.py`
   - Analyze which recipes work for which error types
   - Create ErrorRoutingPolicy nodes
   - Set up ROUTES_ERROR edges

3. [ ] Add compression to VSM loop
   - Integrate with existing MetaCompressor
   - Error patterns as input to compression

**Deliverables**:
- `scripts/compress_error_patterns.py`
- `scripts/generate_error_policies.py`
- VSM loop integration

**Success Metrics**:
- Number of ErrorSuccessRecipe nodes created
- Number of ErrorRoutingPolicy nodes created
- Compression ratio achieved

---

### Phase 5: Query & Application (Week 5)

**Goal**: Enable querying and applying error→success patterns.

**Tasks**:
1. [ ] Create query examples in `scripts/`
   - Find error patterns by type
   - Find most successful recipes for an error
   - Find policies that route specific errors

2. [ ] Create `scripts/error_router.py`
   - Given a new error, find matching recipes
   - Route to appropriate ErrorSuccessRecipe
   - Track routing success

3. [ ] Add to reasoning library
   - Hook into tool use error handling
   - Suggest corrections based on error patterns
   - Log error→success outcomes

**Deliverables**:
- Query example scripts
- `scripts/error_router.py`
- Reasoning library integration

**Success Metrics**:
- Query latency <100ms
- Error routing accuracy >70%
- Integration with reasoning library

---

### Phase 6: Learning & Improvement (Week 6+)

**Goal**: Close the loop - use error patterns to improve model behavior.

**Tasks**:
1. [ ] Create feedback mechanism
   - Track when error recipes succeed/fail
   - Update success rates dynamically
   - Retire low-success recipes

2. [ ] Create learning metrics dashboard
   - Error pattern emergence rate
   - Recipe success rate trends
   - Cross-session generalization

3. [ ] Research: Tamari lattice mapping
   - Map error trajectories to Tamari paths
   - Calculate strut costs for error corrections
   - Explore CD step correlations

**Deliverables**:
- Feedback mechanism
- Learning metrics
- Research notes on Tamari mapping

**Success Metrics**:
- Recipe success rates improving over time
- Cross-session reuse rate >40%
- Research insights documented

---

## 5. Invariants

### 5.1 Structural Invariants

| ID | Invariant | Description |
|---|---|---|
| I1 | Error→Success Order | `ErrorNode.iteration < SuccessNode.iteration` |
| I2 | Coherence Threshold | `ErrorNode.coherence_score >= 0.7` for inclusion |
| I3 | Recipe Source | Every `ErrorSuccessRecipeNode` has `COMPRESSES_FROM` edges to source nodes |
| I4 | Policy Routing | Every `ErrorRoutingPolicyNode` has `ROUTES_ERROR` to at least one recipe |

### 5.2 Semantic Invariants

| ID | Invariant | Description |
|---|---|---|
| I5 | Error Type Consistency | All errors in a trajectory have same `error_type` or semantically similar |
| I6 | Intent Preservation | All nodes in a trajectory preserve the original intent |
| I7 | Progressive Improvement | `semantic_distance` decreases with each iteration |

### 5.3 Temporal Invariants

| ID | Invariant | Description |
|---|---|---|
| I8 | Temporal Order | `ErrorNode.timestamp < SuccessNode.timestamp` |
| I9 | Iteration Monotonicity | Iteration numbers are sequential and increasing |

---

## 6. Query Patterns

### 6.1 Basic Queries

```cypher
# Find all error→success trajectories for a specific error type
MATCH (e:ErrorNode {error_type: 'FileNotFoundError'})-[:CORRECTS_TO]->(s:SuccessNode)
RETURN e.error_message, e.iteration, s.result, s.total_time
ORDER BY s.total_time

# Find the most successful recipe for an error type
MATCH (r:ErrorSuccessRecipeNode {error_pattern: 'File.*'})
RETURN r.success_rate, r.error_count, r.final_command
ORDER BY r.success_rate DESC
LIMIT 1

# Find all error patterns that took exactly 2 iterations to resolve
MATCH (e1:ErrorNode)-[:CORRECTS_TO]->(e2:ErrorNode)-[:CORRECTS_TO]->(s:SuccessNode)
WHERE e1.iteration = 1 AND e2.iteration = 2 AND s.iteration = 3
RETURN e1.error_message, e2.error_message, s.result
```

### 6.2 Advanced Queries

```cypher
# Find error patterns with high coherence scores
MATCH (r:ErrorSuccessRecipeNode)
WHERE r.coherence_score > 0.8
RETURN r.error_pattern, r.success_rate, r.coherence_score
ORDER BY r.coherence_score DESC

# Find policies that route to high-success recipes
MATCH (p:ErrorRoutingPolicyNode)-[:ROUTES_ERROR]->(r:ErrorSuccessRecipeNode)
WHERE r.success_rate > 0.8
RETURN p.error_type, p.confidence, r.success_rate
ORDER BY r.success_rate DESC

# Find error trajectories that crossed CD step boundaries
MATCH (e:ErrorNode)-[c:CORRECTS_TO]->(s:SuccessNode)
WHERE c.cd_step_delta != 0
RETURN e.error_message, c.cd_step_delta, s.result
```

### 6.3 Learning Queries

```cypher
# Find recipes whose success rate is improving
MATCH (r:ErrorSuccessRecipeNode)
WHERE r.success_rate > 0.5
WITH r, datetime() as now
MATCH (r)<-[:COMPRESSES_FROM]-(e:ErrorNode)
WHERE e.timestamp > now - duration('P30D')  # Last 30 days
RETURN r.error_pattern, r.success_rate, count(e) as recent_uses
ORDER BY recent_uses DESC

# Find error types with emerging patterns (new recipes being created)
MATCH (r:ErrorSuccessRecipeNode)
WHERE r.created_at > datetime() - duration('P7D')
RETURN r.error_pattern, r.success_rate, r.cooccurrence_count
ORDER BY r.cooccurrence_count DESC
```

---

## 7. Integration Points

### 7.1 Reasoning Library Integration

```python
# In reasoning_library/trace_processor.py

class ErrorPatternExtractor:
    def __init__(self, graphiti_service: GraphitiService):
        self.service = graphiti_service
        
    async def process_trace(self, trace: dict) -> list:
        """Extract error→success patterns from a reasoning trace."""
        patterns = []
        
        # Find tool use sequences
        tool_uses = self._extract_tool_uses(trace)
        
        # Group into trajectories
        trajectories = self._group_into_trajectories(tool_uses)
        
        for trajectory in trajectories:
            if self._is_coherent(trajectory):
                pattern = self._create_error_success_pattern(trajectory)
                patterns.append(pattern)
                
                # Ingest into Graphiti
                await self._ingest_pattern(pattern)
        
        return patterns
```

### 7.2 MCP Server Integration

```python
# In mcp_normcode_server.py

@tool
async def query_error_patterns(error_type: str, limit: int = 10) -> list:
    """Query error→success patterns for a given error type."""
    query = f"""
    MATCH (r:ErrorSuccessRecipeNode)
    WHERE r.error_pattern CONTAINS '{error_type}'
    RETURN r.error_pattern, r.final_command, r.success_rate
    ORDER BY r.success_rate DESC
    LIMIT {limit}
    """
    results = await graphiti_service.driver.execute_query(query)
    return [dict(record) for record in results[0]]

@tool
async def suggest_correction(error_message: str) -> dict:
    """Suggest a correction based on error patterns."""
    # Classify error
    error_type = classify_error(error_message)
    
    # Find matching recipes
    recipes = await query_error_patterns(error_type, limit=1)
    
    if recipes:
        return {
            "error_type": error_type,
            "suggested_command": recipes[0]["final_command"],
            "confidence": recipes[0]["success_rate"],
            "pattern": recipes[0]["error_pattern"]
        }
    return {"error": "No matching pattern found"}
```

### 7.3 VSM Loop Integration

```python
# In scripts/provo_graphiti_schema.py or VSM loop

class ErrorSystem:
    """VSM System S6: Error Pattern Learning"""
    
    def __init__(self):
        self.system_id = "S6"
        self.name = "Error Pattern Learning"
        self.description = "Learns from coherent error→success trajectories"
    
    async def process(self, context: VSMContext) -> None:
        """Process error patterns in the VSM loop."""
        # Extract error patterns from recent episodes
        error_patterns = await self._extract_error_patterns(context)
        
        # Compress into recipes
        recipes = await self._compress_patterns(error_patterns)
        
        # Update routing policies
        await self._update_policies(recipes)
        
        # Store in Graphiti
        await self._store_in_graphiti(context, recipes)
```

---

## 8. Testing Strategy

### 8.1 Unit Tests (Level 1)

| Test ID | Description | File |
|---|---|---|
| T1.1 | ErrorNode model validation | `test_01_models.py` |
| T1.2 | SuccessNode model validation | `test_01_models.py` |
| T1.3 | ErrorSuccessRecipe model validation | `test_01_models.py` |
| T1.4 | ErrorRoutingPolicy model validation | `test_01_models.py` |
| T1.5 | Edge type model validation | `test_01_models.py` |

### 8.2 Invariant Tests (Level 2)

| Test ID | Description | File |
|---|---|---|
| T2.1 | Error iteration < success iteration | `test_02_invariants.py` |
| T2.2 | Coherence score threshold | `test_02_invariants.py` |
| T2.3 | Recipe has source nodes | `test_02_invariants.py` |
| T2.4 | Policy routes to recipes | `test_02_invariants.py` |
| T2.5 | Temporal order preserved | `test_02_invariants.py` |

### 8.3 Integration Tests (Level 4)

| Test ID | Description | File |
|---|---|---|
| T4.1 | Ingest error trajectory | `test_04_graphiti.py` |
| T4.2 | Query error patterns | `test_04_graphiti.py` |
| T4.3 | Compress error patterns | `test_04_graphiti.py` |
| T4.4 | Route errors to recipes | `test_04_graphiti.py` |

### 8.4 Cross-Layer Tests (Level 5)

| Test ID | Description | File |
|---|---|---|
| T5.1 | Error pattern → Recipe → Policy correlation | `test_05_cross_layer.py` |
| T5.2 | Error trajectory as Tamari path | `test_05_cross_layer.py` |

---

## 9. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Error patterns are too specific (low reuse) | Medium | High | Use semantic similarity, not exact matching |
| Error classification is inaccurate | Medium | Medium | Manual review of taxonomy, use embedding similarity |
| Performance overhead from error tracking | Low | Medium | Async ingestion, batch processing |
| Privacy concerns with error messages | Low | High | Anonymize sensitive data in error messages |
| Pattern database grows too large | Medium | Medium | Compression, pruning low-value patterns |

---

## 10. Open Questions

1. **Granularity**: Should we track individual error messages or error types/categories?
   - *Proposal*: Both - store raw messages, classify into types, query by either

2. **Coherence Threshold**: What minimum coherence score for inclusion?
   - *Proposal*: 0.7, configurable

3. **Temporal Window**: How long to wait before considering a trajectory complete?
   - *Proposal*: Session-level (trajectory completes when session ends or success achieved)

4. **Cross-Session Matching**: How to match error patterns across different sessions?
   - *Proposal*: Semantic similarity of error messages + command templates

5. **Tamari Mapping**: Should error trajectories map to Tamari lattice paths?
   - *Proposal*: Yes, as a research direction (Phase 6)

6. **CD Step Correlation**: Do certain error types correlate with CD steps?
   - *Proposal*: Track and analyze, but don't enforce initially

---

## 11. References

- [Graphiti Integration Spec](docs/graphiti_integration_spec.md)
- [Test Plan](docs/test_plan_graphiti_integration.md)
- [OWL Key-Value Pairing](docs/graphiti_integration_spec.md#31-node-types)
- [VSM Loop](scripts/provo_graphiti_schema.py)

---

## 12. Appendix: Example Error→Success Trajectories

### Example 1: File Path Correction

```json
{
  "session_id": "ses_1234",
  "trajectory_id": "file_path_1",
  "intent": "Read configuration file",
  "iterations": [
    {
      "iteration": 1,
      "thinking": "I need to read the config file to understand the settings",
      "command": "cat /etc/myapp/config.json",
      "error": "cat: /etc/myapp/config.json: No such file or directory",
      "error_type": "FileNotFoundError",
      "timestamp": "2025-01-XXT10:00:00Z",
      "time_to_next": 15.2
    },
    {
      "iteration": 2,
      "thinking": "Maybe it's in the home directory",
      "command": "cat ~/myapp/config.json",
      "error": "cat: /home/user/myapp/config.json: Permission denied",
      "error_type": "PermissionError",
      "timestamp": "2025-01-XXT10:00:15Z",
      "time_to_next": 8.7
    },
    {
      "iteration": 3,
      "thinking": "Let me try with sudo",
      "command": "sudo cat /home/user/myapp/config.json",
      "result": "{\"setting1\": \"value1\", \"setting2\": \"value2\"}",
      "timestamp": "2025-01-XXT10:00:24Z",
      "total_time": 23.9
    }
  ],
  "coherence_score": 0.92,
  "semantic_shift": 0.38
}
```

### Example 2: JSON Syntax Correction

```json
{
  "session_id": "ses_5678",
  "trajectory_id": "json_syntax_1",
  "intent": "Parse JSON configuration",
  "iterations": [
    {
      "iteration": 1,
      "thinking": "Let me read the JSON file",
      "command": "python -c "import json; data = json.load(open('config.json'))"",
      "error": "JSONDecodeError: Expecting value: line 1 column 1 (char 0)",
      "error_type": "JSONDecodeError",
      "timestamp": "2025-01-XXT11:00:00Z",
      "time_to_next": 12.5
    },
    {
      "iteration": 2,
      "thinking": "Maybe there's a trailing comma",
      "command": "python -c "import json; data = json.loads(open('config.json').read().rstrip(','))"",
      "error": "JSONDecodeError: Expecting property name enclosed in double quotes",
      "error_type": "JSONDecodeError",
      "timestamp": "2025-01-XXT11:00:13Z",
      "time_to_next": 22.1
    },
    {
      "iteration": 3,
      "thinking": "Let me validate the JSON first",
      "command": "python -m json.tool config.json > config_fixed.json && python -c "import json; data = json.load(open('config_fixed.json'))"",
      "result": "{'key': 'value'}",
      "timestamp": "2025-01-XXT11:00:35Z",
      "total_time": 35.6
    }
  ],
  "coherence_score": 0.87,
  "semantic_shift": 0.52
}
```

---

## Changelog

| Version | Date | Author | Changes |
|---|---|---|---|
| 0.1 | 2025-01-XX | - | Initial draft |
