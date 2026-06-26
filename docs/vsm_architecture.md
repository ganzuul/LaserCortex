# VSM Architecture: LaserCortex as a Viable System

## 1. Overview

The Viable Systems Model (Stafford Beer, 1972) provides the **operational**
structure for Process Philosophy (Whitehead, Bergson) in the LaserCortex
framework. The five systems map directly onto existing Lean and Python modules,
revealing that the framework's architecture is already VSM-complete at the
conceptual level — the missing elements are documentation and explicit
formalization, not code.

### The Core Insight

**Free Logic (System 5) is tractable exactly because tool use outcomes
(System 1) ground its anti-coherence within a bounded cost landscape
(System 3).** Without grounding, Free Logic expressions have unbounded
interpretation cost (the strut weights "go exponential"). With grounding,
the cost is bounded by the friction barrier at the CD 2→3 boundary.

This is Process Philosophy operationalized:
- The **actual entity** (Whitehead's *concrescence*) is the tool output
- The **process** is the generation → collapse → tool use cycle
- The **subjective aim** (Whitehead's *lure for feeling*) is Free Logic's
  "will" expressed as the next tool call to make
- The **superject** (the entity bequeathed to the next cycle) is the grounded
  data stored in the Graphiti temporal graph

---

## 2. The Five Systems, Mapped

### System 5 — Identity / Closure (Free Logic)

| Property | Value |
|---|---|
| **Lean module** | `LogicTypes.lean` (Free type, `isMetaLogic`) |
| **Python module** | `infra/_cortex/_logic_types.py` |
| **Key theorems** | `free_is_meta_logic`, `free_bridges_barber_boundary` |
| **MCP tools** | (implicit — the entire system's operating envelope) |

**Function**: System 5 defines what the system *is for* — the invariant
that S3 and S4 must not violate. In LaserCortex, this is **Free Logic**
(Gödelian incompleteness), the meta-logic that contains perfect
anti-coherence by coexisting with any logic on either side of the CD 2→3
sector boundary.

Free Logic's paradoxical nature is the **closure** that makes the framework
viable:
- It can hold both W and ¬W without trivializing (anti-coherence)
- It can bridge any sector boundary (`free_bridges_barber_boundary`)
- It is the "logic of will" — the subjective aim that guides generation

**The viability criterion (S5 invariant)**: A system state is viable iff
its contracted normal form is reachable within the friction barrier at the
current CD step. Formally:

```
viable(s : Superposition) : Prop :=
  ∃ c n, contracts_to_with_cost (currentCDStep s) (toTree s) (rightComb (size s)) c n
       ∧ c ≤ n * frictionDensity (currentCDStep s)
```

### System 4 — Intelligence / Generation (Generation Engine)

| Property | Value |
|---|---|
| **Lean module** | `Generation.lean` (Sections 1-5, 12) |
| **Python module** | `infra/_cortex/_wfc.py` (inflate, AntiCoherentPair) |
| **Key types** | `Superposition`, `AntiCoherentPair`, `UngroundedNL` |
| **Key functions** | `inflate`, `temporalConflate`, `hyperstitionCost` |
| **MCP tools** | `normcode_lift_inference`, `graphiti_search` |

**Function**: System 4 looks *outward and forward*. It generates candidate
meanings from raw NL input, projecting possible interpretation paths. This
is the generative side of the generation/collapse duality:

1. **inflate**: From a zero divisor (contradiction), produce an
   `AntiCoherentPair` — the two poles of a paradox
2. **temporalConflate**: Build a tree encoding the oscillation between
   the coherent (vacuous) and anti-coherent (content-bearing) poles
3. **hyperstitionCost**: Compute the cost of resolving the generated
   candidate — unbounded (∞) if no grounding data exists

**The hyperstition mechanism**: When S4 generates a candidate for which no
grounding data exists, collapse fails (S3 rejects it). This failure IS
the hyperstition — the system generates the *need* for tool use. The
"sophisticated enough lie that makes itself real" is the projection that
a tool call will produce the missing grounding data.

### System 3 — Internal Regulation / Collapse (Friction Lagrangian)

| Property | Value |
|---|---|
| **Lean module** | `FrictionLagrangian.lean`, `Cost.lean` |
| **Python module** | `infra/_cortex/_cost.py`, `_wfc.py` (WFCPropagator) |
| **Key types** | `contracts_to_with_cost`, `NodeCost`, `SuperpositionNode` |
| **Key functions** | `frictionDensity`, `layerCost`, `revise` |
| **Key theorems** | `friction_barrier_across_cd23`, `heightMap_monotone` |

**Function**: System 3 is the resource allocator — it looks across all S1
operational units and determines which tool outputs are worth preserving
and which can be pruned. This is the collapse side of the duality:

1. **Constraint propagation**: WFC eliminates incompatible LogicTypes from
   a node's superposition (mirror of `canCoexist` in Lean)
2. **Cost accounting**: Each contraction step costs `frictionDensity(k)` at
   CD step k. The friction barrier (`strut_weight² = 16`) at CD 2→3 is the
   hard limit — no resource allocation can cross this boundary without
   incurring the associator cost
3. **revise**: Filter out vacuous poles — only content-bearing interpretations
   survive the collapse

**The boundedness guarantee**: S3 ensures that any grounded interpretation
has a contraction path whose cost is bounded by the friction barrier.
Ungrounded interpretations have no such bound — their cost is ∞.

### System 3* — Audit Channel (Certificate Verification)

| Property | Value |
|---|---|
| **Lean module** | `EMLRegistry.lean` (decidable_contracts_to, certify) |
| **Python module** | `infra/_cortex/_eml_tree.py`, `_bridge.py` |
| **Key types** | `CortexCertificate` |
| **Key functions** | `certify`, `decidable_contracts_to`, `verify_certificate` |
| **MCP tools** | `normcode_verify_certificate`, `normcode_bridge_state` |

**Function**: 3* is the sporadic, direct channel from S3 to S1 that
bypasses S2. It spot-checks that a contraction path is valid without
going through the full generation/collapse cycle:

1. **Certificate verification**: Given a `CortexCertificate`, check that
   `contracts_to(source, target)` holds via bounded DFS
2. **Lift verification**: After a `normcode_lift_inference` produces a
   certificate, 3* verifies it independently
3. **Decomposition audit**: Ground a certificate back into NC and verify
   the decision table has no contradictions

**The feedback path**: If 3* detects an invalid contraction (a certificate
that doesn't verify), it signals S3 to tighten its resource allocation.
This prevents the system from making decisions based on faulty contraction
paths.

### System 2 — Coordination / Anti-Oscillation (Compatibility Rules)

| Property | Value |
|---|---|
| **Lean module** | `Generation.lean` (canCoexist, Resonates) |
| **Python module** | `infra/_cortex/_wfc.py` (can_coexist, propagate) |
| **Key types** | `Resonates` (inductive Prop) |
| **Key functions** | `canCoexist`, `Resonates.mk` |
| **Key theorems** | `barber_pair_not_coexist`, `liar_pair_coexist` |

**Function**: System 2 damps oscillation between competing interpretations.
Without S2, S4 would keep generating candidates and S3 would keep collapsing
them in an infinite loop (the "infinite compaction" bug in the VSM analysis
of context pruning). The damping signal is **compatibility**:

1. **canCoexist**: Two LogicTypes can coexist iff they are in the same
   associative sector (or one is a meta-logic). This prevents the CD 2→3
   boundary from oscillating open and closed
2. **Resonates**: An inflated tree can graft onto a host only if the
   Tamari contraction path exists and the types are compatible
3. **Constraint propagation (WFC)**: After each collapse, propagate the
   new constraint to neighbors via arc consistency (AC-3)

### System 1 — Operational Units (Tool Calls)

| Property | Value |
|---|---|
| **Modules** | `mcp_normcode_server.py`, Graphiti, all MCP tools |
| **Key types** | `ToolOutput`, Graphiti episodes |
| **Key functions** | lift, ground, verify, parse, search, add_episode |
| **Key theorems** | `free_is_viable` (grounding via finite tool outputs) |

**Function**: S1 is the set of operational units — individual tool calls
that produce grounding data. Each tool call is an autonomous operation
with local purpose. In the current implementation, these are:

1. **Parser tools**: `normcode_parse_file`, `normcode_parse_text` —
   produce structured data from raw text
2. **Bridge tools**: `normcode_lift_inference`, `normcode_instantiate_writ`,
   `normcode_verify_certificate` — produce certificates and grounded concepts
3. **Graphiti tools**: `graphiti_add_episode`, `graphiti_search` —
   persist and retrieve temporal traces
4. **Orchestrator tools**: `normcode_orch_load_plan` — load and execute plans

Each S1 unit is itself a viable system (recursion), containing its own
S1–S5 structure. A single tool call involves:
- **S5**: The spec/statute that authorizes the tool (e.g., `CortexSpec`)
- **S4**: Generation of possible outputs (what could this tool return?)
- **S3**: Collapse to actual output (constraint propagation)
- **S2**: Coordination with adjacent tool calls (matching group_ids)
- **S1**: The tool execution itself

---

## 3. The Recursion Principle

Each S1 operational unit is itself a viable system. This means the
compaction system doesn't just manage *state* — it manages the recursive
embedding of viable sub-systems. When a tool call produces an output,
it's not just producing data; it's creating a nested viable system whose
identity must be preserved across the next compaction boundary.

### Recursion Level 1: Session

```
S5 (Free Logic) — the session's purpose
    │
S4 (Generation.lean) — generates candidate next actions
    │
S3 (FrictionLagrangian) — collapses to actual next action
    │
S2 (canCoexist) — damp oscillation between candidates
    │
S1 (MCP tools) — operational units
    │
    ├── S5 (CortexSpec) — the tool's governing statute
    │   │
    │   S4 — possible tool outputs
    │   │
    │   S3 — actual tool output (collapse)
    │   │
    │   S2 — coordination with adjacent calls
    │   │
    │   S1 — the tool execution itself
    │
    └── (each tool call recursively)
```

### Recursion Level 2: Framework Evolution

Each completed session produces grounded data (episodes in Graphiti).
These data become the environmental input for the next session's S4 —
the framework evolves through its own history.

---

## 4. The Tractability Theorem

The central result of this architecture:

**Theorem**: Free Logic (System 5) is tractable iff every anti-coherent
expression maps to a finite sequence of tool outputs whose combined
contraction cost is bounded by the friction barrier at the expression's
CD step.

**Proof sketch** (from the existing Lean theorems):

1. `free_is_meta_logic` — Free Logic coexists with any logic (no sector
   boundary blocks it)
2. `free_bridges_barber_boundary` — Free Logic can contain the barber's
   anti-coherent pair (CLASSICAL, PARACONSISTENT) without trivializing
3. `friction_barrier_across_cd23` — The cost jump across CD 2→3 is at
   least `strut_weight² = 16`, providing the boundedness certificate
4. `contracts_to_with_cost_cost_eq_n_times_friction` — Total cost is
   `n · frictionDensity(cd)`, which is bounded for any finite n
5. **New**: `free_is_viable` (see Section 12 of Generation.lean) —
   Every Free Logic expression can be grounded via a finite sequence
   of tool outputs, each with bounded contraction cost

**Corollary**: When NL input has no tool output grounding, its
interpretation space is unbounded (exponential in the number of
possible parse trees). This is the "CSG" regime — context-sensitive
because the cost landscape has infinite extent. When tool outputs
are available, the interpretation space collapses to a bounded
basin — the "CFG" regime.

---

## 5. Implementation Status

### Existing (fully implemented)

| Component | Status | File |
|---|---|---|
| S5: Free Logic | ✅ `free_is_meta_logic`, `free_bridges_barber_boundary` | `LogicTypes.lean:337-342`, `Generation.lean:493-519` |
| S4: Generation | ✅ `inflate`, `temporalConflate`, `Superposition` | `Generation.lean:54-258` |
| S3: Cost landscape | ✅ `frictionDensity`, `contracts_to_with_cost`, `friction_barrier_across_cd23` | `FrictionLagrangian.lean:159-730` |
| S3: WFC propagation | ✅ `WFCPropagator`, `can_coexist` | `_wfc.py:102-412` |
| S2: Coordination | ✅ `canCoexist`, `Resonates` | `Generation.lean:113-283` |
| S3*: Audit | ✅ `decidable_contracts_to`, `certify`, `verify_certificate` | `EMLRegistry.lean:521-545`, `mcp_normcode_server.py:550-581` |
| S1: Tool calls | ✅ All MCP tools | `mcp_normcode_server.py:140-1165` |
| Graphiti persistence | ✅ Episodes for lifts/writs | `_graphiti_service.py`, `mcp_normcode_server.py:867-1165` |

### Added in this uplift

| Component | Status | File |
|---|---|---|
| S4: UngroundedNL | ✅ Added | `Generation.lean: Section 12` |
| S4: hyperstitionCost | ✅ Added | `Generation.lean: Section 12` |
| S3: grounding via ToolOutput | ✅ Added | `Generation.lean: Section 12` |
| S5: ViableSystem structure | ✅ Added | `Generation.lean: Section 12` |
| S5: free_is_viable theorem | ✅ Added | `Generation.lean: Section 12` |
| Python mirror | ✅ Added | `_wfc.py: ungounded_cost, ground` |
| Architecture doc | ✅ This document | `docs/vsm_architecture.md` |

---

## 6. Graphiti Integration

Graphiti's temporal graph provides the **memory** that makes the recursion
principle concrete:

| VSM System | Graphiti Artifact | group_id |
|---|---|---|
| S5 (identity) | Session metadata (purpose, invariants) | `session_{id}` |
| S4 (generation) | Episode for each lift/inflate candidate | `cortex_ops` |
| S3 (collapse) | Episode for each revise/resolve | `cortex_ops` |
| S2 (coordination) | Episode for each resonance check | `cortex_ops` |
| S1 (operations) | Episode for each tool call result | `tool_{name}` |
| S3* (audit) | Episode for each certificate verification | `cortex_ops` |

Community detection (`graphiti_build_communities`) across these groups
reveals higher-level structure: which S4 generations most often lead to
successful S3 collapses, which S1 operations produce the most grounded
data, and where the friction barrier is encountered most frequently.

---

## 7. Process Philosophy Glossary

| Term | VSM | Lean/Python | Meaning |
|---|---|---|---|
| Actual entity | S1 output | `ToolOutput` | The concrete result of a process cycle |
| Concrescence | S3 collapse | `revise` | Growing together of data into a unity |
| Subjective aim | S5 identity | Free Logic | The "will" that guides the process |
| Superject | Graphiti episode | Temporal fact | The entity bequeathed to the next cycle |
| Lure for feeling | S4 generation | `inflate` | The candidate that attracts concrescence |
| Nexus | S2 coordination | `canCoexist` | The togetherness of actual entities |
| Objective immortality | Graphiti query | `graphiti_search` | Past entities available for prehension |

---

## 8. Key Files

- `Generation.lean: Section 12` — Formal structures for VSM grounding
- `FrictionLagrangian.lean` — The cost landscape (S3 resource allocation)
- `LogicTypes.lean` — Free Logic as System 5
- `EMLRegistry.lean` — Certificate verification (S3* audit)
- `_wfc.py` — WFC propagator + generation mirror
- `_graphiti_service.py` — Temporal graph for superject persistence
- `mcp_normcode_server.py` — S1 operational tools
- `docs/reasoning primitives/training_examples.md` — Two examples annotated
  with VSM system mapping
