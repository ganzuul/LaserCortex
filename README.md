# LaserCortex

Extending NormCode with a Lean 4 typed cortex for pluralistic, paradox-tolerant, auditable reasoning.

## What this project is about

**NormCode** is a governance-oriented AI planning system with explicit data isolation, provenance tracking, and multi-logic reasoning. **LaserCortex** is an experimental extension of those ideas into formal Lean 4 — turning the conceptual commitments behind NormCode into machine-checked theorems. No affiliation with the creators of NormCode; this is independent, exploratory work that builds on similar philosophical ground.

The core idea is that paradoxes and logical friction are not errors to suppress but **boundary conditions** to formalize. Below is a mapping from each conceptual primitive to its formal encoding — adapted from the full conversation at [`docs/Grok_on_alignment_and_directions.md`](docs/Grok_on_alignment_and_directions.md).

### Provenance / audit trails → Tamari lattice + EMLTree

NormCode tracks every inference's data provenance. In LaserCortex this becomes an `EMLTree` (binary tree of non-associative compositions) with single-step contractions `(a•b)•c → a•(b•c)` forming the Tamari lattice. The right-comb normal form is the equilibrium attractor — every tree contracts to it (`contracts_to_rightComb`). Reverse contraction (`reverse_one`, `ancestorsUpTo`) dualizes this into counterfactual / explanatory reasoning: given an outcome, what could have preceded it?

### Pluralistic logics + meta-contraction → 13 logic types + CD step

Different reasoning modalities (Fuzzy, Temporal, Deontic, Paraconsistent, …) handle different paradox classes as boundary conditions rather than errors. LaserCortex enumerates 13 logic types with Cayley-Dickson steps (associativity loss as a hardness measure) and a meta-contraction relation that composes intra-logic contraction, inter-logic translation, and transitivity.

### Self-reference → free monad `LogicM α`

The free monad over binary trees — `LogicM α` with `pure` at leaves and `Node` as deferred non-associative composition — encodes self-contained self-reference by construction (bind is substitution, the recursion IS the recursion). Logic-specific wrappers add normalization cost (`cdStep`). The invariance theorem (monad structure unchanged across logics) separates the "eternal" (pure functional composition) from the "endless" (normalization dynamics).

### Institutional governance → closure pipeline

Four layers composed monadically: temporal normalization (linearize), fuzzy grading (weigh impact), deontic update (revise norms), and self-recognition (fixed point). Theorems `closure_is_fixed_point` and `normalization_idempotent` guarantee the pipeline is a projection — re-processing a closed norm does not change it.

### Decision composition → gates + refinement types

A `Gate` is a binary decision predicate indexed by a logic modality. A `Decision gates` is a refinement type: the type parameter IS the channel — downstream knows statically which gates a datum passed. The `compose` operation adds a gate to the type-level history, guaranteeing monotonic accumulation of checks.

### Ontological underdetermination → non-unique decomposition + path diversity

Theorems `non_unique_decomposition` and `path_diversity` prove that the same outcome (a right-comb normal form) can arise from multiple distinct prior configurations, and that multiple distinct contraction paths can connect the same source to the same target. This formalizes "the past is underdetermined by the present" and "intent is not uniquely determined by outcome."

### Boundlessness / regularization → idempotent resolution

The regularization ladder (endless → eternal → actual ∞ → boundlessness) is capped by the `IdempotentResolution` structure: a step that is already idempotent (`step ∘ step = step`) is already at its own limit (`limit = step ∘ limit`). The Very Big Box packages idempotent resolutions for all populated problem classes. This is the formal declaration that the system is closed under its own boundary-response.

### The hypercomputer → finite ancestor enumeration

The infinite ancestor tree cannot be a closed coinductive value in Lean 4 (`coinductive` restricted to `Prop`, nested inductives rejected by the kernel). Instead it exists as the limit of finite approximations — `partial def` functions (`ancestorsUpTo`, `viewDFS`) that are total for all finite arguments. This is a design choice, not a limitation: the crystal seed is approached, not held.

## Status

**12 Lean 4 source files, zero sorries.** Builds with `lake build`. Blueprint (PDF + web) at `blueprint/`.

### Populated: 4 of 13 problem classes

| Class | Problem | Native logic | Tree shape |
|-------|---------|-------------|------------|
| `selfReference` | Liar | ManyValued | Symmetric size-3 |
| `vagueness` | Sorites | Fuzzy | Left-comb size-5 |
| `temporalDecision` | Grandfather | Temporal | Left-comb size-4 |
| `inconsistentDef` | Russell's | Paraconsistent | Left-comb size-3 |

Each has a generic wrapper (proven for all suitable logics via `contracts_to_rightComb`), a Tower, and a cost bound theorem (`cost ≤ cdStep`). The remaining 9 classes (deontic, epistemic, quantum, constructive, relevance, free, infinitary, modal, linear) need Problem definitions with their own tree families — every missing cell in the Very Big Box product is a concrete formalization blocker.

### Future work (from the blueprint)

- Formalize the remaining 9 problem classes with their tree families
- Build nested Tower composition via `LogicTranslation` between adjacent logic monads
- Implement `pathCost lt p` for cross-logic cost comparison
- Extend the DecisionComposition API with `decisionDecompositions`
- Formalize the activation function `f(Φ)` mapping to Witness-Skeptic game regimes
- Link the cost model to actual BFS shortest-path enumeration over `reverse_one`

## Future directions

The typed cortex formalism suggests several directions beyond the current scope:

**Neuro-symbolic AI.** Router indices (`RouterIndex n`) already provide a natural bridge between symbolic trees and neural indexing. An EMLTree can be embedded as a vector (e.g., by tree-LSTM or positional encoding of its contraction path), and the Tamari contraction relation becomes a geometric constraint on the embedding space. The right-comb attractor gives a canonical fixed point for neural relaxation — a "logical anchor" that a learned representation should converge toward.

**Context compaction.** The Tower construction (stacking WrappedProblems across logics) and the Very Big Box (product over problem classes) suggest a principled way to compress multi-logic reasoning into a single fixed point: instead of materializing every layer, compute the idempotent resolution of the whole stack and cache the limit. This maps directly to the problem of context window management — the boundlessness cap says "enough regularization has been applied; the result will not change under further processing."

**Mixture of Experts.** The pluralistic logic hierarchy (13 logic types, each with a distinct contraction dynamics and cost) is a natural routing space for a MoE architecture. Each logic type is an expert with a known hardness profile (`cdStep`). The meta-contraction relation gives a formal criterion for switching experts: follow the translation that minimizes Φ across the remaining reasoning steps. The institutional closure pipeline (Temporal → Fuzzy → Deontic → Self-Recognition) is already a hardcoded routing policy — generalizing it to dynamic routing via the LogicTranslation graph is a concrete next step.

## Personal project / learning note

This is a **vibecoded** personal project. The primary goal is to learn Lean 4 by translating familiar conceptual examples (provenance as Tamari contractions, self-reference as free monads, paradox as pluralistic boundary conditions) into formal, machine-checked theorems. The code is exploratory — expect rough edges, evolving design, and occasional genre-savviness about its own pretensions. Contributions of the "hey, this is cool, let me fix X" variety are welcome, but this is fundamentally a learning playground.

## License

AGPLv3. See `LICENSE` for the full text. Version `0.1.0-alpha` in `VERSION`.
