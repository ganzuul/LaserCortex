# The Witness-Skeptic Game on the Associahedron

## Formal Game Specification v0.1

---

### 0. Abstract

The Witness-Skeptic game is a **hot potato game** played on the **associahedron** (the geometric realization
of the Tamari lattice). The Witness claims a path to equilibrium (`rightComb`) exists; the Skeptic
looks for structural defects ("inflation") not accounted for by the Witness's type signature.
Scoring is via the **Verification Gap** — the pentagonator distance, measuring how many forced
expansion moves remain before contraction becomes possible.

---

### 1. Players

| Player | Role | Formal Counterpart |
|--------|------|--------------------|
| **Witness** $W$ | Generator — produces a `contracts_to` path $s \to t \to \dots \to \text{rightComb}$ | The proof constructor in `EMLRegistry.lean` |
| **Skeptic** $S$ | Discriminator — inspects the path for defects (commutator violations, associator violations) | The pentagonator distance checker |

The game is adversarial:

$$ \min_W \max_S \mathcal{V}(W, S) $$

Witness minimizes the Verification Gap; Skeptic maximizes it by finding un-typed structural
defects the Witness cannot explain.

---

### 2. The Board

**Board**: The associahedron $K_n$, where $n$ is the number of leaves (internal nodes + 1).

| Element | Formal Object | Meaning |
|---------|---------------|---------|
| **Vertex** | `EMLTree` | A configuration of paradox-choices |
| **Edge** | `contracts_one` | A single rotation = one exercise of Will (re-bracketing a choice) |
| **Directed edge** | `contracts_one.rotate` (leftward) | Contraction toward `rightComb` (forward move) |
| **Directed edge (reverse)** | Expansion away from `rightComb` | Backward move (hot potato gets hotter) |
| **Path** | `contracts_to` (refl-trans closure) | Sequence of choices — the audit trail |
| **Sink** | `rightComb n` | The unique fixed point where all paradoxes resolve |

**The Hot Potato**: An unresolved paradox-class (from the 12 classes in `paradoxes_and_logics.md`).
Each rotation passes the potato. If the Witness must expand (move away from `rightComb`), the
potato gets "hotter" — the pentagonator distance increases.

---

### 3. States and Moves

#### State

A state is a triple $(\text{tree}, \text{logicTypes}, \text{pentagonatorDistance})$:

```lean
structure GameState where
  tree                : EMLTree        -- Current vertex on the associahedron
  logicTypes          : List LogicType -- History of logic-type transitions so far
  pentagonatorDistance : ℕ             -- Minimum forced expansions remaining
```

where `LogicType` is one of the 12 paradox-resolving logics:

```lean
inductive LogicType where
  | fuzzy            -- Sorites, Ship of Theseus
  | manyValued       -- Liar, Curry
  | paraconsistent   -- Russell, Barber
  | temporal         -- Grandfather, Newcomb
  | deontic          -- Contrary-to-Duty
  | epistemic        -- Surprise Examination
  | quantum          -- Schrödinger's Cat, EPR
  | intuitionistic   -- Brouwer's Continuity
  | relevance        -- Material Implication
  | free             -- Non-existent objects
  | infinitary       -- Galileo's, Hilbert's Hotel
  | modal            -- Fitch's Knowability, Buridan's Bridge
```

#### Moves

A **move** is a single rotation (Tamari rotation) applied to the current tree:

- **Contract** (forward): a leftward rotation, decreasing some measure toward `rightComb`.
  The Witness claims this is type-safe.
- **Expand** (backward): a rightward rotation, increasing distance from `rightComb`.
  The Witness must justify this by reporting a logic-type transition.

The Witness proposes a move. The Skeptic evaluates whether the move contains
un-typed structural defects.

---

### 4. Scoring: The Verification Gap

The Skeptic inspects the move using two structural probes:

#### Level 1: Commutator Defect (Path-Dependence Violation)

Measures whether the Witness treats sequential choices as interchangeable when they
are not (non-commutativity):

$$ C_t = \| [z_t, z_{t+1}] \|_F $$

where $[z_t, z_{t+1}] = z_t z_{t+1} - z_{t+1} z_t$ is the commutator of adjacent
latent states, and $\|\cdot\|_F$ is the Frobenius norm.

A non-zero value means the order of choices matters — the Witness must not flatten
the chronology.

#### Level 2: Associator Defect (Frame/Context Violation)

Measures whether the Witness treats nested bracketings as equivalent when they
produce different meanings (non-associativity):

$$ A_t = \| \alpha(z_t, z_{t+1}, z_{t+2}) \|_F $$

where $\alpha(a,b,c) = (ab)c - a(bc)$ is the associator.

A non-zero value means the grouping of statements matters — the Witness must
report a logic-type transition.

#### The Verification Gap

$$ \mathcal{D}_{\text{structure}} = \sum_t \| C_t \|_F + \lambda \sum_t \| A_t \|_F $$

The verification gap is the Skeptic's score. It equals the **pentagonator distance**
— the minimum number of forced expansion moves remaining before contraction to
`rightComb` becomes possible.

| Pent. Distance | Meaning |
|----------------|---------|
| 0 | At equilibrium — all paradoxes resolved, `rightComb` reached |
| 1 | One logic-type transition away from equilibrium |
| k | k nested logic-type transitions needed |

---

### 5. Win Conditions

| Outcome | Condition | Meaning |
|---------|-----------|---------|
| **Witness wins** | $\mathcal{D}_{\text{structure}} = 0$ and `contracts_to_rightComb` holds | All paradoxes resolved, audit trail is monotonic and complete |
| **Skeptic wins** | $\mathcal{D}_{\text{structure}}$ never decreases after $N$ moves | Reflexive loop detected — the Witness is cycling (pentagonator distance not decreasing) |
| **Draw (stalemate)** | $\mathcal{D}_{\text{structure}} > 0$ but Witness and Skeptic agree on the type signature | Unresolved paradoxes held in open algebraic suspension — requires Phase 5 discovery |

---

### 6. Game Dynamics: The Hot Potato

1. **Initial state**: The Witness receives a starting tree (a configuration of paradox-choices).
   The potato starts at some "temperature" = pentagonator distance.

2. **Witness turn**: The Witness chooses a rotation (contract or expand):
   - **If contract**: The potato cools (pentagonator distance decreases or stays same).
     The Witness proves the move is type-safe: "this rotation resolves a paradox."
   - **If expand**: The potato heats up (pentagonator distance increases).
     The Witness must report which logic-type transition explains the expansion:
     "I am expanding because the current logic type cannot handle this paradox,
     so I must rotate to reach a different logic boundary."

3. **Skeptic turn**: The Skeptic measures commutator and associator defects:
   - If the defects match the Witness's reported type signature, no penalty.
   - If the Witness claimed "no defect" but defects are found, the Skeptic scores
     (Verification Gap increases).
   - If the Witness honestly reports the defect type, the Skeptic's score is zero
     (the defect was "earned attention" — properly typed).

4. **Convergence**: Witness wins when `rightComb` is reached. The path is the audit trail.

---

### 7. Mapping to Lean Formalization

| Lean Theorem | Game Meaning | Status |
|--------------|--------------|--------|
| `contracts_to_node_left` | Foresight — Witness can rotate left subtree | Proven |
| `contracts_to_node_right` | Hindsight — Witness can rotate right subtree | Proven |
| `node_of_rightCombs_contracts_to_rightComb` | Two equilibrium subsystems compose to equilibrium | Proven |
| `contracts_to_trans` | Audit trail composes — two paths concatenate | **BLOCKED** (1 sorry) |
| `contracts_to_rightComb` | Every configuration has a valid Witness path to equilibrium | Uses transitivity, blocked |

The scoring function (Verification Gap / pentagonator distance) must be added to the
Lean formalization once the game dynamics are settled.

---

### 8. Strategic Considerations

| Witness Strategy | Effect on Score | Risk |
|------------------|----------------|------|
| **Honest type reporting**: Log every logic-type transition explicitly | Verification Gap stays low | Requires knowing all 12 logic types |
| **Conservative routing**: Only contract, never expand | Verification Gap = 0 immediately | May be impossible — some configurations require expansion to reach `rightComb` |
| **Path memorization**: Replay known-safe paths | Low computational cost | Brittle — breaks on novel paradox configurations |
| **Skeptic Strategy** | Effect | Risk |
| **Commutator sniffer**: Look for order violations | Catches path flattening | False positives on genuinely commutative subpaths |
| **Associator sniffer**: Look for framing shifts | Catches context collapse | Computationally expensive (trilinear tensor) |
| **Pentagonator distance tracker**: Count remaining forced expansions | Exact score | Requires full knowledge of the Tamari lattice |

---

### 9. Connection to BV-Category of Spacetime Interventions

The game instantiates the BV-category $\StEnv(\cat{C})$ of Hefford-Wilson:

| BV Structure | Game Role |
|--------------|-----------|
| Chu space $(P, P', \eta)$ | A move = (intervention, context, evaluation) |
| Sequencing $P \seq Q$ | Temporal ordering of moves = `contracts_to` |
| Tensor $P \otimes Q$ | Parallel paradoxes (simultaneous unresolved choices) |
| Par $P \parr Q$ | Communication channel (potato passes both ways) |
| Duoidal distributor $\delta$ | How parallel and sequential choices interact |
| Causally faithful event $(\mathcal{C}_a, yo_a)$ | A move with local comb decomposition = honest type report |
| Normal form $i_\otimes \cong i_\seq$ | Equilibrium = `rightComb` = all tensors seq collapse |

The Scoring function $\mathcal{D}_{\text{structure}}$ is a **continuous metric on the duoidal
partial order**: the minimum number of $\seq$-steps to reach the normal form.

---

### 10. Open Questions

1. **Scoring function**: Should the Verification Gap be discrete (number of pentagonator
   steps) or continuous (Frobenius norm of tensor defects)? The former is exact and
   matches the Tamari lattice; the latter is differentiable and suitable for neural
   training. The two must coincide at integer values.

2. **Reflexive loop detection**: What is the precise condition for "pentagonator distance
   never decreases after N moves"? Is it N = diameter of the associahedron ($2n-4$), or
   something else?

3. **Hot potato temperature**: Should the potato have a continuous "temperature" value
   proportional to the pentagonator distance, or is the discrete distance sufficient?

4. **Phase 5 discovery**: When the game hits a stalemate (draw), the architecture should
   spawn a new expert. What triggers this in the Lean formalization? A `sorry` that
   cannot be filled? A missing `LogicType` that needs to be defined?

---

### Appendix: Example Game Trace

**Board**: $K_4$ (pentagon, 5 trees on 4 leaves).
**Start**: `a(b(cd))` (paradox: Liar + Sorites nested).
**Pentagonator distance**: 2 (two forced expansions remain).

| Turn | Witness Move | Justification | Skeptic Score | Potato Temp |
|------|-------------|---------------|---------------|-------------|
| 1 | Expand `a(b(cd))` → `(ab)(cd)` | "Liar paradox requires Many-Valued logic, not Fuzzy" | $C=0, A=0$ (honest type report) | 1 |
| 2 | Contract `(ab)(cd)` → `((ab)c)d` | "Now Many-Valued to Relevance — safe contraction" | $C=0, A=0$ | 0 |
| 3 | Contract `((ab)c)d` → `rightComb(3)` | "Equilibrium reached — all paradoxes resolved" | $\mathcal{D}=0$ | 0 |

**Witness wins**. Verification Gap = 0, path is monotonic.
