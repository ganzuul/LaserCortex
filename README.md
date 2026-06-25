# LaserCortex

## The logic scaling law

Composing logical operations is not free. The cheaper the algebra you
build on, the more depth you get before composition stops commuting;
each additional doubling (Cayley–Dickson step) buys stronger
expressivity at the price of losing another algebraic identity.

| cdStep | Algebra              | Keeps             | Loses           | Composition |
|--------|----------------------|-------------------|-----------------|-------------|
| 0      | ℝ, ℂ                 | commutativity     | —               | associative |
| 1      | ℍ̃ (split ℂ)         |                   | commutativity   | associative |
| 2      | Cl(1,1) ≅ ℍ̃          |                   |                 | associative |
| 3      | 𝕎ˢ (split octonions) |                   | associativity   | **non-assoc** |
| 4      | sedenions            |                   | alternativity   | **non-altern** |

This is a quantitative, not just qualitative, claim. The LaserCortex
formalization measures it concretely:

- **`strut_weight = 4`** — the unit cost of *one* non-associative step,
  verified by computation from the split-octonion associator tensor
  `(e₁, e₂, e₄)` (`SplitOctonionCost.lean:198`).
- **`assocDefect(k) = if k ≤ 2 then 0 else strut_weight`** — the
  associator defect jumps from 0 to 4 exactly at the CD 2→3 boundary
  (`FrictionLagrangian.lean:159`).
- **`frictionDensity(k) = k + strut_weight · assocDefect(k)`** — the phase
  transition is discontinuous: `Γ(2) = 2`, `Γ(3) = 3 + 16 = 19`, a jump
  of 17 dominated by `strut_weight² = 16`
  (`FrictionLagrangian.lean:181`, proven in
  `friction_barrier_at_least_strut_weight_squared`).
- **`pentagon_defect(e₁,e₂,e₄,e₁) ≤ 10`** — the Mac Lane pentagon
  coherence bound, computed (not axiomatic)
  (`SplitOctonionCost.lean:206`).

The Friction Lagrangian is the height map. A system composed of
*different* logics pays a cost to compose them that is the sum of
per-layer friction densities. Cheap logic scales deep; rich logic scales
shallow. There is a structural ceiling on how much a civilization —
tech stack, agent, protocol stack — can compose before the cost of
re-associating contradictions exceeds what the system can afford. That
is the scaling law, and it is a theorem, not an opinion.

## What Stereoscopic listening is for

The scaling law puts a hard ceiling on associative composition. But
*real* reasoning happens in the non-associative regime: deontic,
paraconsistent, quantum logics, the things that actually model conflict.
You cannot synthesize them into one canon without paying `strut_weight`
per re-association. Friction kills you before you reach the synthesis
that would settle the conflict.

The LaserCortex answer is **provenance over synthesis**. Instead of
forcing a single orbit, every composition site carries a *provenance
record* — a Tamari tree encoding the history of which brackets were
chosen where. The `CortexCertificate` proves that a given tree contracts
to its canonical rightComb form. The left contra slipstream ("stage
right") is a separate track of the *rejects* — the re-associations that
were rejected on cost grounds but whose structural content must be
preserved for the next round.

This is **stereoscoping**: maintaining multiple bracketing histories in
parallel, listening with two ears, refusing to collapse into a single
perspective. The Tamari lattice is the space of all bracketings; the
forward pass of a reasoning system is a *path* through Tamari space, and
the path — not just its endpoint — is what carries the meaning.

## Three algebraic objects § keep distinct

The framework uses three formally distinct objects that the rhetoric
often conflates. Keeping them separate is load-bearing.

1. **The strut** (`strut_weight = 4`). The associator-tensor component of
   `(e₁, e₂, e₄)`. A *bounded* per-step quantum: "each non-associative
   rebracketing costs 4." It is the atom of the scaling law's force.
2. **Pentagonator distance** (`PentagonatorDistance : ℕ`, `EMLRegistry.lean:499`).
   The *serial* cost of reaching the rightComb fixed point from an
   arbitrary tree. Unbounded. This is what maps to depth — not the strut.
   A shallow wide tower and a deep narrow tower can share the same
   `assocDefect` (both cross CD 3) but have wildly different
   pentagonator distances.
3. **The α-channel**. The leaf values of an EMLTree — the semantic
   content the System is reasoning about. The certificate proves a
   *topological* fact (the tree reaches rightComb); it says nothing
   about the α-values. The Loose Leaf Principle notes that rotations
   *trivially preserve* leaf values (rotations touch only internal
   nodes); it does not *vouch for* them.

The residual stream in a deep network is what keeps `assocDefect = 0`
(associative regime) by making composition *additive*. It absorbs the
strut's defect until it saturates. When it saturates, the system crosses
to CD 3 and the pentagonator goes positive — the system can no longer be
canonicalised in a single step. That is the moment the ceiling bites.

## What the certificate is — and is not

The `CortexCertificate` (`EMLRegistry.lean:533`) is a compact, proof-carrying
audit trail: `source : EMLTree`, `target : EMLTree`, `proof :
contracts_to source target`. Its role is analogous to an ISO-9001
process audit: it vouches that the *process* (normalisation) was followed,
not that the *product* (content) is good. It certifies the **topology**,
not the **content**.

This is a feature, not a bug. For pure logic, the certificate is a
*sufficient* compaction primitive: the logical content lives in the
leaves (the predicates), the tree shape is just associativity, which
classical logic quotiented away centuries ago. The certificate can stand
in for the whole tree.

For natural language, topology is *not* irrelevant: word order is part
of meaning. "the dog bit the man" and "the man bit the dog" share the
same certificate if they have the same tree shape; the certificate
alone cannot disambiguate them. For NL, the certificate is a
*necessary structural precondition* for a separately-certified semantic
channel. The certificate certifies the skeleton; a different mechanism
must vouch for the flesh.

## NormCode — the α-channel

If the certificate cannot carry semantic content, what does? The
answer is **NormCode**: an annotation layer that produces typed cortex
annotations (`PredicateWitness`, monotonicity laws, coupling signatures)
for natural-language fragments. Each annotation is a Tamari tree *plus*
an α-assignment: which leaf carries which predicate.

NormCode is the part of the system that has no formal fallback inside
LaserCortex. The strut, the pentagonator, and the certificate all have
Lean proofs. The α-assignment layer has an encoder (NL→Tamari-with-α)
and an annotator; its canonicity is an external responsibility. This is
the real grounding problem. Phase B of LaserCortex determines which
contractions are *permitted* (a topology question); NormCode determines
which α-values are *assigned* (a content question). The two are
orthogonal: two annotators can produce bit-identical certificates
while encoding entirely different semantics, and topology stability is
neither necessary nor sufficient for semantic canonicity.

Concretely:

- `normcode_parse_file` turns a `.ncd` plan into structured data: a list
  of inferences, each with a coupling signature (`commutative`,
  `non_commutative`, `commutative-associative`, `non-associative`).
- `normcode_lift_inference` turns an inference into a CortexSpec-backed
  pair `(Concept, CortexCertificate)`, instantiating the formal bridge.
- `normcode_ground_certificate` walks a certificate's contraction path
  back into a decision — the bridge from formal proof to concrete action.
- `invoke_market_closure` runs the full pipeline on a Python economic
  model (AMM pool, reserve guard, fair price, certified close).

The coupling signatures determine which cdStep the lifted inference can
legally live in. `non_commutative` routes into the regime where order
matters; `non-associative` routes into the regime where bracketing
matters and where the scaling law starts costing `strut_weight` per step.
NormCode is, in effect, the interface between natural-language plans and
the cdStep permission lattice.

## The Eigenstate bridge

The `Eigenstate` is the structure that carries a contract-level unit of
work across the cdStep boundary. It packages four things:

```
Eigenstate =
  { evm_state_root     : state fingerprint
  , cdStep             : which permission regime we're in
  , contraction_trace  : Tamari path to canonical form
  , invariant_proof    : the CortexCertificate proving the invariant }
```

It is the bridge between an arbitrary EVM smart contract and the Lean
formal layer. The `eigenstate_bridge.ncd` plan specifies the full cycle:

- **lift**: EVM bytecode + state root → Eigenstate (parse storage slots
  into Lean types and methods into transition functions)
- **prove**: Eigenstate + stated invariant → CortexCertificate
- **ground**: Certificate → EVM-compatible proof artefact (Solidity
  verifier bytecode)
- **settle**: certified execution on-chain

The practical import: at cdStep < 2 a contract has no reserve guard at
all and is trivially vulnerable to runaway inflation (unbounded token
supply). At cdStep 2 the reserve guard exists but the contract cannot
*self-certify* it — it relies on an external oracle, creating a latency
window. At cdStep ≥ 3 the contract can produce its own certificate.
The inflation window is precisely the gap between strut-saturation and
pentagonator-equilibrium, and the Eigenstate bridge is what closes that
window by moving the certification into the contract's own self-describing
layer.

## The EML primitive

Beneath the scaling law sits a single binary primitive:
`eml(x, y) = exp(x) − ln(y)`, with terminal constant `1`. Composed into
binary trees, this suffices to express the standard elementary
functions. LaserCortex treats each binary tree as a provenance record of
ordering and coupling choices. A node written `((a • b) • c)` is a
canonical encoding of a ternary interaction `T(a, b, c)`; Tamari
rotations record alternative ternary resolutions. When EML parameters
are non-monotone (left amplification vs right compression), different
bracketings become energetically distinct, turning the Tamari lattice
into a geometry for analysis, optimization, and embedding.

### Key concepts

- **EML**: `eml(x,y) = exp(x) − ln(y)`. Minimal binary primitive.
- **EMLTree**: binary tree grammar `S → 1 | eml(S, S)`. Leaves are
  terminals (1 or variables).
- **Node-as-ternary**: `((a•b)•c)` is a canonical encoding of
  `T(a, b, c)`; Tamari rotations record alternative resolutions.
- **Tamari lattice**: the poset of bracketings under right-rotation
  (`contracts_one` / `contracts_to`). It is the provenance space.
- **Cost Φ**: discrete asymmetric node cost (`leftWeight`, `rightDiv`,
  `bias`) mirroring the exp/ln asymmetry; Φ varies under rotation for
  non-classical parameter regimes.
- **Loday coordinates**: an injective integer coordinate map from trees
  → lists, giving a concrete embedding useful for visualization and
  continuous relaxations.

### Illustration: Log-Exp activation

![Log-Exp activation (1D slice of eml)](docs/logexp_avtivation.png)

A peak followed by a trough and a rapid asymptotic rise. A 1D scalar
projection of the 2-D EML surface can partition inputs into multiple
qualitative regimes; when trees are embedded via Loday coordinates,
discrete `NodeCost` parameters reproduce analogous regime boundaries on
the Tamari lattice.

## What we formalize (Lean 4 core)

- `EMLTree` — binary tree inductive type (`Leaf | Node`).
- `contracts_one` — single Tamari rotation (primitive coupling rewrite).
- `contracts_to` — reflexive-transitive closure (Tamari order; provenance).
- `rightComb` — canonical normal form; theorem that every tree contracts
  to its `rightComb`.
- `LodayCoords` — injective coordinate map `trees → integer lists`.
- `Cost.Φ` — discrete per-node cost parametrized by logic types
  (`nodeParam`), with proven invariants for particular regimes.
- `SplitOctonionCost` — the split-octonion algebra with verified
  `strut_weight = 4`, `pentagon_defect ≤ 10`, `branch_lightening`,
  and the Mathlib `QuadraticForm` integration point `Q44`.
- `FrictionLagrangian` — the height map. `assocDefect`, `commDefect`,
  `frictionDensity`, `layerCost`, and the CD 2→3 phase-transition
  theorems (`friction_barrier_at_least_strut_weight_squared`,
  `assocDefect_zero_up_to_cd2`, `assocDefect_positive_for_cd3plus`).
- `EMLRegistry` — `contracts_to_at_cdStep` (the permission lattice),
  `PentagonatorDistance`, `CortexCertificate`, `certify`, and the
  monotonicity theorems `contracts_to_at_cdStep_monotone` and
  `min_cost_monotone_with_cdStep`.
- `AMM` — the constant-product AMM specification: `Pool`, `swapOut`,
  `reserveGuard`, `certifiedClose`, `CloseResult`.
- `MarketClosure` — `MarketType`, `CertifiedPrice`, `decideMarketType`,
  `marketClosure`, `blameToBudget`.
- `LogicMonad` — the (rent-free) monadic layer; `normalizeAcross` returns
  the `(CortexCertificate × LogicM α)` pair. Cost is external to the
  monad — it is applied at the Eigenstate level, not inside `seq`.

## Practical notes & caveats

- **Syntactic vs topological claims.** Saying EML "reduces 3D→2D" is
  ambiguous. EML is a *syntactic* reduction (many primitives → one
  binary primitive). Do not conflate that with an unqualified
  topological embedding theorem without a formal proof.
- **Branches and partiality.** `ln(y)` requires `y > 0`; many EML
  reconstructions use complex intermediates or branch choices. Numeric
  evaluation and formal verification handle these explicitly.
- **Partition sums & path integrals.** Any path-sum or partition-function
  construction must restrict to finite path families or provide
  convergence arguments.
- **Discrete approximation.** `NodeCost.apply` is an integer
  approximation that captures exp/ln asymmetry qualitatively; it
  smooths singularities (division truncation). Interpret discrete and
  continuous behaviors with care.
- **`assocDefect` is binary.** The current `assocDefect(k) = 0 or 4`
  classifies *whether* a layer is non-associative but does not grade
  *how much*. The continuous associator lives in `associator_tensor`
  (octonion-valued); the ℕ-valued `assocDefect` is its discretized
  projection. For modelling graded accumulation of non-associativity
  (e.g. as a depth model for neural networks), `assocDefect` would
  need to become a graded object. This is a known gap, not a feature.

## Quick start

Prereqs:
- Lean 4 + Lake (see `LEAN_SETUP.md`)
- Python 3.11+, Node 18+, npm 9+ (for the canvas app)

Build the Lean core:
```bash
lake build
```

Run the Canvas visualization:
```bash
cd canvas_app
python launch.py
```

Parse a NormCode plan and lift an inference:
```python
# via the normcode MCP tools (see .agents/skills/normcode/SKILL.md)
normcode_parse_file("LaserCortex/examples/market_closure/market_closure.ncd")
normcode_lift_inference(flow_index="0", concept_name="amm_close",
                        sequence_type="commutative-associative")
```

## Status & roadmap

- **Formal Lean core** (EMLRegistry, LodayCoords, Cost,
  SplitOctonionCost, FrictionLagrangian, AMM, MarketClosure,
  LogicMonad) with many invariants proved. Clean build at cdStep-aware
  permission lattice and cost layer.
- **Phase B complete at framework level.** `contracts_to_at_cdStep`,
  the monotonicity proofs, and `heightMap_monotone_for_path_cost` are
  in place. The Logic Monad stays pure; cost is applied at the
  Eigenstate level.
- **Python bridge** mirrors `AMM.lean` + `MarketClosure.lean`:
  `Pool`, `swap_out`, `reserve_guard`, `certified_close`,
  `decide_market_type`, `market_closure`, `invoke_market_closure`.
  End-to-end on the three market types (open/paradox/closed) across
  CLASSICAL / FUZZY / PARACONSISTENT / INTUITIONISTIC.
- **NormCode plans** for market closure, prediction markets, and the
  Eigenstate EVM↔Lean bridge. Parses and lifts cleanly.
- **Runaway inflation proofs** (planned, see
  `docs/RUNAWAY_INFLATION_PROOF.md`): five targets tying the
  Eigenstate bridge to the institutional closure narrative, from the
  trivial token-printer (cdStep 0) through the PARACONSISTENT
  hidden-inflation case in the e₄ coupling dimension.

### Next priorities

1. **Write the prediction market Solidity contract** — AMM pool with
   on-chain verifier for CortexCertificate proofs.
2. **Runaway inflation proof targets 5a–5e** — starting with the
   token printer base case and the CD 2→3 window.
3. **Graded `assocDefect`** — promote the binary 0/4 defect to a
   saturating accumulator so the scaling law becomes a model rather
   than a classifier.
4. **Eigenstate EVM bridge implementation** — `lift(bytecode)` parser
   mapping EVM storage slots → Lean types.
5. **Canonicity of the NormCode α-channel** — the hard problem: a
   reproducible NL→Tamari-with-α encoder whose α-assignments are
   stable across annotators and annotation runs.

## License

LaserCortex - LaserCortex/`LICENSE`.
Normcode - `LICENSE`.
