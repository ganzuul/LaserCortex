# LaserCortex — Architectural Decisions

## RouterIndex: The Legislative Docket

### What is a RouterIndex?

A `RouterIndex` is a bounded natural number `Fin n` — a unique address in `[0, n)`.
Every item in NC's `Waitlist` receives one at creation time, sorted by flow index.

```python
flow=1        -> RouterIndex(index=0, bound=8)
flow=1.1      -> RouterIndex(index=1, bound=8)
flow=1.1.1    -> RouterIndex(index=2, bound=8)
...
```

### The Societal Analogy

The waitlist is a **legislative docket**. Each RouterIndex is a **bill number**:

| Concept | NC Concept | LC Analogue | Societal Parallel |
|---------|-----------|-------------|-------------------|
| Queue position | `flow_index` string | `RouterIndex (Fin n)` | A bill's docket number |
| Logical structure | `EMLTree` | `TypeRegistry` mapping | The bill's text |
| Uniqueness guarantee | — | Injectivity check | Constitutional rule: no two bills may be identical |

A parliament assigns every bill a unique docket number. The `TypeRegistry`
enforces **injectivity**: if two different RouterIndexes map to the same
`EMLTree` (the same logical structure), the registry rejects the duplicate.
This is not a procedural rule — it is a **semantic** one: the system
recognises that they *are the same thing* and refuses to pretend otherwise.

### Why This Matters for Accountability

A `RouterIndex` creates an **auditable binding** between:

1. **NC's operational state** — a waitlist item executing an inference
2. **LC's formal layer** — an EMLTree that has been normalised, contracted,
   and checked for paradox
3. **The neural bridge** — a future neural binding address for the LLM fine-tune

When a user asks "why did inference 1.1.2 produce this result?", the answer
is not a heuristic — it is a **proof trace**:

1. Look up `RouterIndex(3, 8)` in the TypeRegistry → get the `EMLTree`
2. Run `logic_normal_form()` on that tree → get the canonical form
3. Check `contracts_to(tree, LEAF)` → was this node redundant?
4. Check `rightComb(tree)` → does this node produce a paradox?
5. Trace the supporting items via flow index hierarchy → reconstruct the
   entire dependency graph as a **contraction tree**

### The Bigger World Model

Before RouterIndex, a flow index `"1.1.2"` was an opaque string — only the
Orchestrator knew what it meant, and only at runtime. Now it is a **position
in a formal semantic space**. LC can answer questions NC never thought to ask:

- **Which flow indices are logically redundant?** — `contracts_to(eml, LEAF)`
- **Does this waitlist contain a self-contradiction?** — `rightComb(tree)`
  detects paradox across the entire docket
- **What is the minimal set of inferences needed?** — contraction paths
  collapse dependent bills into their support tree
- **Where does this spec appear in other runs?** — RouterIndex is invariant
  across runs with the same waitlist structure

### Implementation

Defined in `infra/_cortex/_types.py`:

```python
@dataclass(frozen=True)
class RouterIndex:
    index: int          # 0 <= index < bound
    bound: int          # Total number of items in the waitlist

    def to_flow_string(self) -> str:
        return str(self.index + 1)   # 1-indexed display
```

Assigned in `infra/_orchest/_waitlist.py`:

```python
def assign_router_indices(self):
    bound = len(self.items)
    for i, item in enumerate(self.items):
        item.router_index = RouterIndex(i, bound)
```

Consumed by `TypeRegistry`:

```python
registry.register(router_index, eml_tree)
# Raises if injectivity is violated
```

### Future: Web UI / Internal Wiki

When the web UI renders a run, every node in the inference graph should
display its RouterIndex alongside the flow index. Hovering shows the
EMLTree normal form; clicking opens the proof trace — the contraction
path, the paradox check result, and the coupling signature. This is not
debugging output. It is the **explanation** that LC was built to provide.

---

## CortexCertificate: The Wax Seal

### The Societal Analogy

A completed orchestration run is a **voyage**. The port authority stamps
the ship's manifest when it docks; that **wax seal** (`CortexCertificate`)
authenticates everything that happened during the voyage.

| Concept | NC Name | LC / Societal Name |
|---------|---------|-------------------|
| Completion event | `on_plan_complete` | **`stamp_seal`** — the port authority stamps the manifest |
| Checkpoint event | `on_checkpoint` | **`stamp_checkpoint`** — a log entry at an intermediate port |
| Certificate object | `CortexCertificate` | **Wax seal** — authenticates source→target with proof path |
| Run identifier | `run_id` | **Voyage number** — unique per sailing |
| Orchestration end | `return final_concepts` | **Docking** — the ship ties up; seal is applied |

### What the Seal Contains

A `CortexCertificate` holds:

```
source: EMLTree      — The full composite EMLTree of the voyage
target: EMLTree      — The rightComb normal form (equilibrium)
path:   List[EMLTree] — The contraction sequence [source, ..., target]
```

The `verify()` method replays each contraction step — the **Skeptic** check.
Anyone can verify the seal without trusting the issuer:

```python
cert = bridge.get_certificate(run_id)
assert cert.verify()        # replay every step
```

### Why This Matters for Explainability

Without the seal, a user asking "did run X actually complete?" gets a
procedural answer: "yes, the tracker says so." With the seal, they get a
**mathematical answer**:

1. Retrieve the certificate for voyage `run_id`
2. `cert.verify()` replays every contraction — if any step fails, the seal
   is fraudulent
3. Inspect `cert.source` for the full composite tree of all inferences
4. Inspect `cert.target` for the maximal contracted form (canonical)
5. Run `certify()` on any subtree for a sub-seal (partial voyage)

The seal is **portable**: it can be stored, transmitted, or displayed on the
web UI as a verifiable badge: "Voyage #abc123 — Seal: ✅ Verified".

### Naming Decision

The method was renamed from `on_plan_complete` to `stamp_seal` to encode
the semantic role: the bridge doesn't merely *record* completion — it
*authenticates* it. A future `SealRegistry` can index seals by voyage
number, source hash, or target normal form, enabling cross-voyage queries:

- "Which voyages produced the same equilibrium as voyage #abc123?"
- "Show me all seals issued for docket of size n=8."

### Implementation

Defined in `infra/_cortex/_types.py`:

```python
def certify(t: EMLTree) -> CortexCertificate:
    target = rightComb(t.size())
    path = _build_contraction_path(t, target)
    return CortexCertificate(source=t, target=target, path=path)
```

Issued in `infra/_cortex/_bridge.py`:

```python
def stamp_seal(self, run_id: str) -> Optional[CortexCertificate]:
    trees = [v.eml_tree for k, v in self._lift_cache.items()
             if k.startswith(f"{run_id}:")]
    composite = combine_all(trees)
    cert = certify(composite)
    self._certificates[run_id] = cert
    return cert
```

Wired in `infra/_orchest/_orchestrator.py` — called at the end of `run()`:

```python
if self.cortex_bridge:
    self.cortex_bridge.stamp_seal(self.run_id)
```

---

## Checkpoint Verification: The Purser's Inspection

### The Societal Analogy

A `stamp_seal` authenticates the voyage end-to-end. But a voyage has
intermediate ports. At each port, the **purser** inspects the cargo
manifest: does the seal match the actual cargo? If the hatch covers
have been tampered with between ports, the purser's inspection catches
it — the seal on the manifest won't match the cargo in the hold.

`verify_checkpoint(run_id, cycle)` is the **purser's inspection**:
it recomputes the seal from the checkpoint state and checks it against
the stored seal. If they match, the cargo is as-recorded between ports.

| Concept | NC / LC Name | Societal Name |
|---------|-------------|---------------|
| Seal at intermediate port | `stamp_checkpoint()` | **Log entry** |
| Cargo at dock | Checkpoint state | **Cargo manifest** |
| Verification | `verify_checkpoint()` | **Purser's inspection** |
| Proof for third parties | `cert.verify()` + state hash | **Sealed bill of lading** |

### Why This Matters for Smart Contracts

A smart contract does not trust us. It trusts `cert.verify()` — the
Skeptic replays every contraction step. The checkpoint verification
adds a second guarantee: **the seal commits to a specific state**.

Given a checkpoint proof `(run_id, cycle, state_hash, certificate)`:

1. The contract calls `certificate.verify()` — does the math check out?
2. The contract computes `hash(state) == state_hash` — is this the
   right cargo?
3. The contract checks that the certificate's seal key matches
   `hash(run_id, cycle)` — is this the right port?

If all three pass, the contract can release funds, mint a token, or
record an attestation. No trusted third party required.

This is how we deliver **paydata**: the system produces a proof that a
specific computation happened at a specific checkpoint, verifiable
by anyone with access to the Lean certificate semantics.

### Implementation

```python
def verify_checkpoint(
    self, run_id: str, cycle: int
) -> Tuple[bool, Optional[CortexCertificate]]:
    """Purser's inspection: verify a checkpoint seal."""
    cert = self._certificates.get(f"{run_id}:checkpoint:{cycle}")
    if cert is None:
        return False, None
    return cert.verify(), cert

def checkpoint_proof(
    self, run_id: str, cycle: int
) -> Optional[Dict[str, Any]]:
    """Package a checkpoint proof for smart contract consumption."""
    ok, cert = self.verify_checkpoint(run_id, cycle)
    if not ok or cert is None:
        return None
    return {
        "run_id": run_id,
        "cycle": cycle,
        "source": repr(cert.source),
        "target": repr(cert.target),
        "path_len": len(cert.path),
        "verified": True,
    }
```

The smart contract side (future, not in this file) would verify:

```solidity
function verifySeal(bytes32 stateHash, bytes memory certData) returns (bool) {
    // Call into Lean-verified verification oracle
    return LeanVerifier.verify(certData) && keccak256(stateHash) == stateHash;
}
```

---

## Spec Browser UI: The Reading Room

### The Societal Analogy

The Reading Room is where advocates browse the statute book. Every
sealed writ, every certificate, every spec definition is on open
shelves. The purser, the judge, the clerk, and the public all consult
the same shelves. No special access.

| Concept | NC / LC Name | Societal Name |
|---------|-------------|---------------|
| Spec list endpoint | `GET /api/cortex/specs` | **Shelf list** |
| Spec detail endpoint | `GET /api/cortex/specs/{name}` | **Volume on shelf** |
| Certificate viewer | `GET /api/cortex/certificates/{key}` | **Seal inspection** |
| Spec browser panel | `SpecBrowserPanel` | **Reading Room window** |
| Instantiate a spec | `POST /api/cortex/instantiate` | **Issue a writ** |

### Implementation

The Reading Room is a split-panel React component:
- **Left pane**: scrollable list of all 10 seed specs, each with a
  logic-type badge (blue CLASSICAL, amber TEMPORAL, purple QUANTUM)
  and its axes.
- **Right pane**: full detail for the selected spec — coupling
  signature, witness type, shape, magnitude contract bounds,
  expandable worked examples, plus a toggle for the default payload.

The backend router (``cortex_router.py``) lazily instantiates a
``NormCodeCortexBridge`` singleton on first request.  The bridge
is the single source of truth for the certificate store, lift cache,
and type registry.

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/cortex/specs` | List all seed specs |
| GET | `/api/cortex/specs/{name}` | Full spec detail |
| GET | `/api/cortex/certificates` | List certificate keys |
| GET | `/api/cortex/certificates/{key}` | Certificate detail + verify |
| POST | `/api/cortex/instantiate` | Issue a writ (instantiate spec) |
| GET | `/api/cortex/bridge/state` | Bridge state snapshot |

### Data Channels

The panel fetches from the bridge via `cortexApi.ts`, which wraps
`fetch()` calls against `/api/cortex/*`.  The bridge singleton
is stateless across requests (the bridge's state lives in memory
in the Python process; restart loses it — persisted storage is a
future concern).

---

## SpecRegistry: The Statute Book

### The Societal Analogy

A legislature cannot simply pass any bill. Each bill must trace its
authority to an **enabling statute** — a law that grants jurisdiction.
The `SpecRegistry` is the **statute book** (code of law). Every
`CortexSpec` is a **statute** — an enumerated power that authorises
a specific kind of inference.

An inference without a matching spec is *ultra vires* (beyond legal
authority). The bridge's job is to check the statute book before
every inference and reject unauthorised ones.

| Concept | NC Name | LC / Societal Name |
|---------|---------|-------------------|
| Registry of specs | `SpecRegistry` | **Statute book** — the code of law |
| A single spec | `CortexSpec` | **Statute** — enumerated power |
| Finding applicable law | `lookup_by_context()` | **Legal research** — which statute covers this case? |
| Pre-filling forms from law | `pre_populate()` | **Clerk's preparation** — fill in the blanks from the statute |
| Unauthorised inference | No matching spec | **Ultra vires** — without legal authority |

### Why This Matters for Governance

Without the statute book, every inference is a **common law** decision —
the bridge makes it up as it goes (the `flow_index_to_tree` heuristic).
With it, every inference is **statutory** — traceable to an enumerated
power that was designed, reviewed, and versioned.

This is what makes the system *governable*:

1. **Audit**: Every seal (certificate) records which statute each
   inference was executed under. A reviewer can ask "was this inference
   actually authorised?"
2. **Amend**: Adding a new spec is a legislative act — you write a new
   statute and register it. No code changes needed.
3. **Repeal**: Removing a spec instantly de-authorises all inferences
   that depended on it. The bridge refuses to lift unregistered patterns.
4. **Precedent**: The same statute book governs across all voyages.
   Voyage #001 and Voyage #100 share the same law.

### The Check: Before the Floor Vote

The flow before Gap #1 was:

```
Bill drafted (WaitlistItem)
  → Floor vote (Inference.execute())
    → Clerk records result (flow_index_to_tree heuristic)
```

The flow after Gap #1 is:

```
Bill drafted (WaitlistItem)
  → Legal research (SpecRegistry.lookup_by_context)
    → Clerk pre-fills forms from statute (pre_populate)
      → Reading clerk checks form validity (validate_typed_form / TVK)
        → Floor vote (Inference.execute())
          → Clerk records result with statute citation (on_inference_complete)
```

The statute citation is the `cortex_name` embedded in the `LiftResult`
so every subsequent certificate and seal references it.

### Implementation

Wired in `infra/_cortex/_bridge.py` — `on_inference_complete` resolves
the spec before lifting:

```python
def on_inference_complete(self, flow_index, concept, sequence_type, run_id):
    # Resolve the applicable statute
    spec = self.resolve_spec(concept)
    # Lift with the statute's authority
    result = self.core.lift_inference(
        flow_index=flow_index,
        concept_name=concept.name,
        sequence_type=sequence_type,
        coupling_signature=concept.coupling_signature,
        concept=concept,
        spec=spec,          # ← statute citation
    )
    self.registry.register(result.router_index, result.eml_tree)
    return result
```

Called from `infra/_orchest/_orchestrator.py` after each successful
inference execution:

```python
if self.cortex_bridge:
    self.cortex_bridge.on_inference_complete(
        flow_index, concept, sequence_type, self.run_id
    )
```

---

## instantiate_spec: The Writ

### The Societal Analogy

A statute is an abstract law. To apply it to a specific case, a **writ**
is issued — a formal instrument that commands an official to act on the
sovereign's authority. The writ cites the statute, names the parties,
and bears the court's seal.

`instantiate_spec(spec, witness_data)` is the bridge's **writ-issuing**
power. It takes an abstract statute (`CortexSpec`) and concrete evidence
(`witness_data`) and produces a certified Concept — a particular finding
under law.

| Concept | NC / LC Name | Societal Name |
|---------|-------------|---------------|
| Abstract law | `CortexSpec` | **Statute** |
| Concrete evidence | `witness_data` | **Facts of the case** |
| Issuing the writ | `instantiate_spec()` | **Clerk issues a writ** |
| Certified output | `Concept + Certificate` | **Sealed writ** |
| Validation | `validate_typed_form` | **Reading clerk's countersignature** |

### Why a Writ Is Not a Statute

A statute says "theft shall be punished." A writ says "John Doe is hereby
summoned to answer for the theft of a horse on 1 June." The statute is
general and enduring. The writ is particular and consumable.

In code terms:

```python
# Statute — general, registered once
SORITES_SPEC = CortexSpec(
    cortex_name="sorites_threshold",
    form_type="threshold_category",
    coupling_signature="commutative",
    default_payload={"category_label": "heap", ...},
)

# Writ — particular, issued per case
concept, cert = bridge.instantiate_spec(
    SORITES_SPEC,
    {"witness": 147, "uncertainty": {"present": True, "score": 0.3}},
)
# concept.category_label == "heap"
# concept.witness == 147
# cert.verify() == True
```

The writ inherits its authority from the statute. If the statute is
repealed (removed from the registry), existing writs remain verifiable
but new ones cannot be issued. This is **non-delegable authority**: the
bridge cannot issue a writ without citing a statute.

### Implementation

The writ-issuing pipeline:

1. Validate `witness_data` against `spec.validation` (type check)
2. Create a `Concept` with the spec's form_type, coupling_signature,
   form_schema_version
3. Merge `spec.default_payload` with `witness_data` into `form_payload`
4. Run `validate_typed_form` — the reading clerk countersigns
5. Build an `EMLTree` from the coupling signature
6. `certify(tree)` — the wax seal is applied
7. Return the sealed `(Concept, CortexCertificate)` pair

Defined in `infra/_cortex/_bridge.py`:

```python
def instantiate_spec(
    self, spec: CortexSpec, witness_data: Dict[str, Any]
) -> Tuple[Concept, CortexCertificate]:
    # 1. Validate witness type
    wt = spec.validation.witness_type
    if wt and wt != type(witness_data.get("witness")).__name__:
        raise TypeError(...)

    # 2. Create concept under the statute
    concept = Concept(
        name=f"writ:{spec.cortex_name}",
        form_type=spec.form_type,
        coupling_signature=spec.coupling_signature,
        form_schema_version=spec.form_schema_version,
    )

    # 3. Populate form payload
    payload = dict(spec.default_payload)
    payload.update(witness_data)
    concept.reference = Reference([], [], form_payload=payload)

    # 4. Reading clerk countersigns
    validate_typed_form(concept)

    # 5. Build tree and certify
    tree = self._coupling_to_tree(spec.coupling_signature)
    cert = certify(tree)

    return concept, cert
```

---

## BlamePool: The Debt Ledger

### The Societal Analogy

A `BlamePool` is a **debt ledger**. Each `Event` records a negative
outcome — a debt incurred. The pool tracks `total_impact` (the sum
of all debts) and `event_count` (the number of debts). That is all.

This is a deliberate choice. A Calvinist view on interest says:
interest (usury) creates a recursive obligation — debt grows over
time, transforming the relationship from commutative (exchange of
equals) to non-commutative (time-bound subordination). Simple debts
do not compound. Complex debts (with interest, with pooling before
threshold) do — and that compounding is *logical work* that must be
fed forward to LC because it changes the coupling signature.

| Concept | LC Name | Societal Name | Coupling |
|---------|---------|--------------|----------|
| A negative outcome | `Event` | **A debt** | — |
| Total of all debts | `BlamePool.total_impact` | **Principal sum** | commutative |
| Number of debts | `BlamePool.event_count` | **Count of obligations** | commutative |
| Debt with interest | *(future)* | **Usury** | non-commutative |
| Pooling before threshold | *(future)* | **Securitisation** | non-associative |

### Why Scaffold the Simple System First

The current `BlamePool` is the simple system:

- No **interest**: blame does not accumulate recursively. Each event
  contributes its impact once. `total_impact = Σ impact_i`.
- No **pooling threshold**: every event is recorded independently.
  The pool does not trigger aggregation at an arbitrary `N`.

This is the **commutative base case**: debts are independent facts.
The order they arrived does not matter. The grouping does not matter.
Σ impact_i is the same regardless.

A `BlamePool(total_impact=30, event_count=3)` means three debts of
10 each — or one debt of 20 and one of 10 — the pool does not
distinguish. That is the *commutative* guarantee.

### When Pooling Becomes Logical Work

If a future system pools debts before they reach a threshold (e.g.,
"wait until 5 debts accumulate, then act on the pool"), that pooling
is a **semantic transformation**, not mere bookkeeping. The act of
grouping changes the logical structure — it creates a *non-associative*
composition where the grouping determines the outcome.

This information must be fed forward to LC because:

1. The coupling signature shifts from `commutative` → `non-associative`
2. The `EMLTree` shape changes from `LEAF` (no structure) to a
   left-leaning tree (grouping matters)
3. The `LogicType` may shift from `CLASSICAL` → `QUANTUM`
4. The certificate path must account for the grouping as logical work

The scaffold exists so this future transformation is *visible* —
the pool is a formal object, not an ad-hoc accumulation, so when
pooling gains structure, LC can track it.

### Implementation

Defined in `infra/_cortex/_closure.py`:

```python
@dataclass(frozen=True)
class Event:
    year: int
    description: str
    impact: int

@dataclass(frozen=True)
class BlamePool:
    total_impact: int
    event_count: int
```

Wired into the bridge as a converter from NC Blackboard state:

```python
def blackboard_to_events(self, blackboard) -> List[Event]:
    """Convert Blackboard inference history to Events."""
    events = []
    for flow_index, item in blackboard.history.items():
        if item.status == "failed":
            events.append(Event(
                year=item.cycle,
                description=f"inference {flow_index} failed",
                impact=1,
            ))
    return events

def compute_blame(self, events: List[Event]) -> BlamePool:
    total = sum(e.impact for e in events)
    return BlamePool(total, len(events))
```

The closure pipeline (`temporal_normalize → fuzzy_grade → deontic_update`)
operates on `LogicM[Event]` — the scaffold lifts Blackboard state into
this monad so that Norms and BlamePools are produced formally, not
heauristically.

---

## The Stable Triangle: Three Absolutes

The bridge's architecture is held stable by three absolutes that mutually
constrain one another. They are not aspirations — they are properties the
code enforces at runtime.

```
                ┌─────────────────┐
                │   Unqualified   │
                │    Absolute     │
                │  (this *is* X)  │
                └────────┬────────┘
                        / \
                       /   \
                      /     \
                     /       \
                    /         \
                   /           \
                  /             \
        ┌────────┴────────┐     ┌┴────────────────┐
        │    Coherent     │     │    Universal     │
        │    Absolute     │     │    Absolute      │
        │ (will composes  │     │ (scope accounts  │
        │  with will)     │     │  for categories) │
        └────────┬────────┘     └────────┬─────────┘
                 └───────────────────────┘
                       proof path
```

### Unqualified Absolute — "This *is* X"

A `RouterIndex(3, 8)` is not "like" a bounded natural — it *is* one.
The `TypeRegistry` does not "warn" about duplicate trees — it raises
`ValueError` because injectivity *is* the law. A `CortexSpec`'s
`coupling_signature` is not a hint — it determines the `LogicType`
unambiguously via `COUPLING_TO_LOGIC`.

There is no `try/except` around "maybe the index is too big." If it
is, `RouterIndexError` propagates. The system fails rather than
qualify.

**Relevant code:**
- `RouterIndex.__post_init__` — raises `RouterIndexError` on OOB
- `TypeRegistry.register` — raises `ValueError` on injectivity violation
- `COUPLING_TO_LOGIC[coupling_signature]` — `KeyError` if unmapped
- `stamp_seal` — `None` if no trees lifted, never a "maybe" seal

### Coherent Absolute — "Will composes with will"

Every inference is a composition of orthogonal wills:

1. **Spec will** → `CortexSpec.form_type` selects which TVK fires
2. **TVK will** → `validate_typed_form` enforces payload schema
3. **Payload will** → schema fields drive `LogicType` resolution
4. **Logic will** → `LogicType` selects contraction/gate pipeline
5. **Contraction will** → `contracts_to` produces the certificate path

If the duck quacks "horse" (a threshold_category spec claims
`witness: string` when the TVK expects `witness: integer`), coherence
fails — the reading clerk rejects it before the floor vote. The proof
path (`contracts_to`) is the formal witness that these wills compose
into a single coherent run.

**Relevant code:**
- `validate_typed_form(concept)` — checks form_type against payload
- `_validate_threshold_category` — checks `witness`, `binary_outcome`,
  `category_label` presence
- `certify(tree)` → `_build_contraction_path(s, t)` — DFS that proves
  source reaches target through valid contraction steps
- `CortexCertificate.verify()` — the Skeptic replays every step

### Universal Absolute — "Scope accounts for categories"

The `SpecRegistry` *is* the scope. It holds exactly the statutes that
exist. An inference whose concept matches none of them is *ultra vires*
— the bridge returns `None` from `resolve_spec`, and `on_inference_complete`
lifts without a `spec_name`. The certificate still seals, but without
statutory authority.

This is the system knowing it is in Rome. It does not try to be Roman.
"10 seed specs" is not a limitation — it is an *honest* accounting of
the category scope. When a new category is needed, a new spec is written
and registered. The bridge does not guess, extrapolate, or hallucinate.

**Relevant code:**
- `SpecRegistry.lookup_by_context(context)` — substring match; returns
  `[]` honestly when nothing matches
- `SpecRegistry.best_match(concept)` — returns `None` when no applicable
  statute exists
- `LiftResult.spec_name` — `None` when no spec authorised the inference
- `SEED_REGISTRY` — the 10 enumerated statutes from the Phase 5 document

### How the Triangle Holds

Each absolute constrains the other two:

| Corner | Constrains | By ensuring that |
|--------|-----------|-----------------|
| **Unqualified** | Coherent | `RouterIndex` *is* `Fin n`, so the TypeRegistry's injectivity check cannot be bypassed with a "close enough" index. The composition is exact or it fails. |
| **Unqualified** | Universal | `SpecRegistry.lookup_by_context` raises no errors — it returns `[]` when out of scope. The absolute truth is "no match found," not a softened "maybe this fits." |
| **Coherent** | Unqualified | The proof path (`contracts_to`) guarantees that unqualified identities compose. The certificate is not a claim — it is a replayable trace. |
| **Coherent** | Universal | A spec that cannot pass its own TVK cannot execute. The scope is self-policing: enumerated statutes that fail their own composition are dead letters. |
| **Universal** | Unqualified | The scope of 10 seed specs means `COUPLING_TO_LOGIC` need only cover those 10. Adding an 11th spec requires an 11th mapping — the triangle refuses incomplete categories. |
| **Universal** | Coherent | An inference matched to the wrong spec by context (e.g. "heap" matched to "blue_eyed") will fail TVK because payload schemas differ. The scope corrects miscomposition. |

### The Triangle in a Single Trace

A user asks: "Why did flow index 1.1.2 produce this result?"

1. **Unqualified**: `RouterIndex(3, 8)` → lookup in TypeRegistry → the
   EMLTree *is* the one registered at that index. Not "similar to" it.
2. **Coherent**: `cert.verify()` replays every contraction step. The
   path from source to target composes without gaps.
3. **Universal**: `LiftResult.spec_name == "sorites_threshold"` — the
   statute that authorised this inference exists in `SEED_REGISTRY`.
   If it didn't, the citation would be `None` and the answer would be
   "no statute authorised this."

All three are either satisfied simultaneously or the trace is
*explanatorily incomplete*. That is the triangle.

---

## Complete Naming Map

| NC concept | LC / Societal name | Defined in |
|-----------|-------------------|-----------|
| `Waitlist` | **Docket** | `_waitlist.py` |
| `WaitlistItem` | **Bill** | `_waitlist.py` |
| `flow_index` | **Docket number** | everywhere |
| `RouterIndex` | **Fin n (bounded address)** | `_types.py` |
| `TypeRegistry` | **Statute-to-tree binding** | `_types.py` |
| `CortexCertificate` | **Wax seal** | `_types.py` |
| `certify()` | **Stamp** (verb) | `_types.py` |
| `on_plan_complete()` → **`stamp_seal()`** | **Port authority stamp** | `_bridge.py` |
| `on_inference_complete()` | **Court clerk recording** | `_bridge.py` |
| `LiftResult.spec_name` | **Statute citation** | `_bridge.py` |
| `instantiate_spec()` | **Writ** | `_bridge.py` |
| `run_id` | **Voyage number** | `_orchestrator.py` |
| `run()` | **Voyage** / **Sailing** | `_orchestrator.py` |
| `SpecRegistry` | **Statute book** | `_spec.py` |
| `CortexSpec` | **Statute** | `_spec.py` |
| `pre_populate()` | **Clerk's pre-filling** | `_spec.py` |
| `Inference.__init__` TVK | **Reading clerk** | `_inference.py` |
| `Inference.execute()` | **Floor vote** | `_inference.py` |
