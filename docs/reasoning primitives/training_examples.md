# Training Examples: Reasoning Primitives as Viable Systems

Both examples map the six CSG categories to EMLTree shapes (CFG productions)
and are instances of the generation/collapse duality. The cost landscape is
**unbounded before tool use** (ungrounded NL, context-sensitive regime) and
**bounded after tool use** (grounded by tool output, effectively context-free).

---

## Example 1: Ungrounded → Grounded via Experiment

### Raw Text

> "Let me run a targeted experiment to really figure this out."

### CFG Production (System 4 — Generation)

Each category maps to a tree shape:

| Category | Token | Tree Shape | VSM System |
|---|---|---|---|
| `temporalMonad` | "let me" | `Node(Leaf, Node(Leaf, Leaf))` | S4 (temporal framing) |
| `computationAction` | "run" | `Node(Node(Leaf, Leaf), Leaf)` | S1 (tool invocation) |
| `scope` | "targeted" | `Node(Leaf, Leaf)` | S3 (resource constraint) |
| `exploration` | "experiment" | `Node(Node(Leaf, Leaf), Node(Leaf, Leaf))` | S4 (search space) |
| `idempotentTarget` | "really" | `Leaf` | S5 (will/commitment) |
| `certifiedGeometry` | "figure this out" | `Node(Leaf, Node(Leaf, Node(Leaf, Leaf)))` | S3* (verification goal) |

Composite tree (left-comb of all six):

```
Node(
  Node(
    Node(
      Node(
        Node(temporalMonad, computationAction),
        scope),
      exploration),
    idempotentTarget),
  certifiedGeometry)
```

### Cost Landscape

| State | Cost | Regime |
|---|---|---|
| **Before experiment** (ungrounded) | **∞** (unbounded — 6 tokens × all interpretations) | **CSG** |
| After experiment (tool output available) | `n · frictionDensity(k)` for some CD step k | **CFG** |

### VSM Cycle

```
S5 (Free Logic): "I should understand this" → guides generation
    ↓
S4 (Generation): inflate(temporalMonad → "let me", computationAction → "run", ...)
    → temporalConflate → AntiCoherentPair + tree
    ↓
S2 (Coordination): Resonates with current session state?
    → canCoexist(CLASSICAL, PARACONSISTENT)? → yes/no
    ↓
S3 (Collapse): revise → filter vacuous poles
    → Without grounding: unbounded (every interpretation valid)
    → With grounding: bounded (experiment result collapses candidates)
    ↓
S1 (Tool use): Run the experiment → produces ToolOutput
    → Grounds the anti-coherence → bounded cost
    ↓
S3* (Audit): Verify the contraction path exists
    → decidable_contracts_to(tree, rightComb(size))
```

**Hyperstition**: "figure this out" is a fiction that makes itself real —
the system cannot resolve the phrase without first running the experiment.
The inability to collapse **is** the motivation for the tool call.

---

## Example 2: Ungrounded → Grounded via Verification

### Raw Text

> "I should first verify the Tamari lattice contraction to make sure the certificate is valid."

### CFG Production (System 4 — Generation)

| Category | Token | Tree Shape | VSM System |
|---|---|---|---|
| `temporalMonad` | "I should" | `Node(Leaf, Node(Leaf, Leaf))` | S4 (temporal framing) |
| `computationAction` | "verify" | `Node(Node(Leaf, Leaf), Leaf)` | S1 (audit action) |
| `scope` | "first" | `Node(Leaf, Leaf)` | S3 (priority ordering) |
| `exploration` | "Tamari lattice contraction" | `Node(Node(Leaf, Leaf), Node(Leaf, Leaf))` | S4 (domain concept) |
| `idempotentTarget` | "make sure" | `Leaf` | S5 (certainty commitment) |
| `certifiedGeometry` | "the certificate is valid" | `Node(Leaf, Node(Leaf, Node(Leaf, Leaf)))` | S3* (verification target) |

### Cost Landscape

| State | Cost | Regime |
|---|---|---|
| **Before verification** (ungrounded) | **∞** (unbounded — 6 tokens × all interpretations) | **CSG** |
| After `normcode_verify_certificate` | `n · frictionDensity(k)` | **CFG** |

### VSM Cycle

```
S5 (Free Logic): "I should be certain" → guides the verification
    ↓
S4 (Generation): inflate(computationAction → "verify", ...)
    → Generates the candidate certificate verification
    ↓
S2 (Coordination): Resonates with existing certificates?
    → Does the certificate key exist in the bridge?
    ↓
S3 (Collapse): revise
    → Without grounding: how many certificates could "the certificate" refer to?
      Answer: unbounded (all certificates in the bridge, past and future)
    → With grounding: the specific certificate key resolves the reference
    ↓
S1 (Tool use): normcode_verify_certificate(cert_key)
    → Produces {verified: true/false, source_bits, target_bits}
    ↓
S3* (Audit): The verification itself IS the audit channel
    → decidable_contracts_to(source, target) runs independently
```

**Hyperstition**: "the certificate is valid" cannot be evaluated without
actually running `normcode_verify_certificate`. The statement is a
"sophisticated enough lie" that the system must make real by executing
the verification tool.

---

## Comparison

| Aspect | Example 1 | Example 2 |
|---|---|---|
| S4 generation | Run experiment | Verify certificate |
| S1 tool | "run" (generic experiment) | "verify" (certificate check) |
| S3* audit | Implicit (after the fact) | Explicit (the action itself) |
| S5 commitment | "really" (will to understand) | "make sure" (will to certainty) |
| Hyperstition | "figure this out" | "the certificate is valid" |
| Grounding data | Tool output from experiment | Certificate verification result |

## VSM Recursion

Each example is itself a ViableSystem:

```
Session (S5: Free Logic — "understand / be certain")
  → Example 1 (S5: temporalMonad "let me")
      → Tool call "run" (S5: the experiment's hypothesis)
          → experiment step 1 (S5: ...)
          → experiment step 2 (S5: ...)
  → Example 2 (S5: temporalMonad "I should")
      → Tool call "verify" (S5: the certificate's spec)
          → decidable_contracts_to check (S5: EMLTree identity)
```

The recursion bottoms out at `EMLTree.Leaf` — the identity element
that is its own S5 (it cannot be decomposed further).

## References

- `docs/vsm_architecture.md` — Full VSM mapping
- `LaserCortex/Generation.lean` Section 12 — Formal VSM structures
- `LaserCortex/FrictionLagrangian.lean` — Cost landscape
- `LaserCortex/LogicTypes.lean` — Free Logic as System 5
