# Reinforcement Type Discovery Plan

**Goal**: discover a compositional grammar of *reinforcement types* that maps
natural-language reasoning traces to tool-call chains. The grammar will be
expressed as `OWL-A * OWL-B` pairs extracted by NMF from multiple orthogonal
ontology projections.

**Context**: In LaserCortex a *reinforcement type* describes how a piece of
reasoning is reinforced (or not) into an executable action. Early in the
project the concept was first-class; `CortexCertificate` is the natural place
to decode it. The six example categories used so far
(temporalMonad, computationAction, scope, exploration,
idempotentTarget, certifiedGeometry) are only *examples*, not ground truth.

**Research principle**: research first, then formalize in Lean, then let Lean
be the blueprint for adapting NormCode for LaserCortex.

---

## 1. Deliverables

1. A vocabulary of single-word ontology atoms from local sources.
2. A trace × atom activation matrix.
3. A sweep of NMF component counts `k = 4 … 2000` (capped) with reconstruction
   error and knee detection.
4. Candidate `OWL-A * OWL-B` reinforcement types from each `k`.
5. Tool-chain prediction baselines using the discovered components.
6. A report mapping strong reinforcement types to the Hopf 7-logic / coupling
   signature / `cd_step` framework.
7. (If Milestone 4 succeeds): a design for adding a contraction-path trace to
   `CortexCertificate` that acts as shorthand for the reasoning trace.

---

## 2. Milestones

### Milestone 0 — Bootstrap Single-Word Ontology Atoms

**Inputs**:
- `reasoning_library/traces.jsonl` (758 traces, 635 CFG, 123 CSG).
- `/usr/share/man/man1/` (section 1 manpages).
- NLTK FrameNet 1.7 and VerbNet corpora.
- PROV-O and P-PLAN OWL files (already downloaded).

**Steps**:
1. Install NLTK and download `framenet_v17` and `verbnet`.
2. Extract verbs from each `thinking_block`.
3. For each verb:
   - Look up FrameNet frames: `nltk.corpus.framenet.frames(verb)`.
   - Look up VerbNet classes: `nltk.corpus.verbnet.classids(verb)`.
4. Collect unique atoms as `frame:<FrameName>`, `verbnet:<ClassID>`.
5. Mine manpage `NAME` / one-line descriptions for tools appearing in traces:
   `bash`, `edit`, `read`, `write`, `grep`, `todowrite`, `question`, and
   any others found in `tools_used`.
6. Add PROV-O classes/properties and P-PLAN classes/properties as seed atoms.

**Output**:
- `data/reinforcement_atoms.json` — list of atoms with source ontology.

---

### Milestone 1 — Build Trace × Atom Activation Matrix

**Steps**:
1. For each thinking block compute:
   - Dense embedding with local bge-m3 (1024-dim).
   - Sparse TF-IDF vector over content words.
2. For each atom compute a match score against the block:
   - Frame atoms: cosine of block embedding to the frame definition.
   - VerbNet atoms: exact verb-class membership or class description cosine.
   - Tool atoms: cosine of block embedding to the manpage description.
   - PROV-O / P-PLAN atoms: cosine of block embedding to class/property
     definition.
3. Normalize each atom column (z-score or L2) and build matrix
   `T × A` where `T` is traces and `A` is atoms.

**Output**:
- `data/trace_atom_matrix.npz`
- `data/trace_atom_metadata.json` (trace IDs, atom labels, sources).

---

### Milestone 2 — NMF Sweep to Discover `OWL-A * OWL-B` Reinforcement Types

**Steps**:
1. Run Non-negative Matrix Factorization on `T × A` for many component counts:
   `k ∈ {4, 6, 8, 12, 20, 30, 50, 80, 120, 200, 350, 500, 800, 1200, 1600,
   2000}`.
2. For each `k`, record:
   - reconstruction error,
   - Frobenius norm of the residual,
   - component coherence (mean pairwise cosine of component vectors),
   - number of components with at least two strong atoms whose source ontologies
     differ.
3. Extract the top two atoms from each component. A component is a candidate
   reinforcement type if its top atoms come from **different orthogonal
   ontologies** (e.g., `frame:INVESTIGATION * tool:read`).
4. Detect the **knee** where increasing `k` stops producing clearly separated
   cross-ontology pairs and starts producing noise.
5. **Perturbation analysis**: subsample traces, shuffle atom labels, and
   re-run NMF for a handful of `k` values. Compare reconstruction error and
   component stability to distinguish signal from overfitting.

**Output**:
- `data/nmf_sweep_knee_report.json`
- `data/discovered_reinforcements_k*.json` for each tested `k`.

---

### Milestone 3 — Tool-Chain Prediction Baseline

**Steps**:
1. Use NMF component activations as features.
2. Train scikit classifiers:
   - Logistic regression (multinomial, one-vs-rest) on top `m` components.
   - k-NN in component space.
   - Small linear SVM.
3. Evaluate on a stratified test split:
   - top-1 tool-chain accuracy,
   - top-3 tool-chain accuracy,
   - CSG/CFG binary classification accuracy,
   - macro-averaged precision/recall per tool chain.
4. Compare against majority-class baseline and against a simple TF-IDF baseline.

**MVP gate**: continue only if a model using discovered two-word reinforcement
features beats the TF-IDF baseline on top-3 tool-chain prediction. Otherwise
revisit atom extraction, NMF regularization, or ontology coverage.

**Output**:
- `data/reinforcement_predictor_report.html` or `.md`.

---

### Milestone 4 — Map Strong Reinforcements to Hopf 7-Logic

**Steps**:
1. Take the best `k` from the knee analysis.
2. For each component/reinforcement type, infer algebraic properties from its
   dominant tool chains:
   - single distinct tool → cdStep 0 (commutative-associative),
   - repeated single tool → cdStep 1 (commutative),
   - mixed distinct tools → cdStep 2 (non-commutative / Intuitionistic),
   - mixed tools with repeats → cdStep 3 (non-associative / Quantum),
   - generation/collapse or ZD-detected → cdStep 4 (Free Logic).
3. Check whether the discovered types cover all sectors of the 7D NodeCost
   space defined in `lab_notes/006_the_hopf_7_skeleton_of_logic_space.md`.
4. Compare discovered types to the six historical examples and either:
   - absorb an example into a discovered type,
   - flag it as a composite of two or more discovered types, or
   - mark it as an unsupported gap.
5. If the grammar successfully predicts tool chains and maps cleanly to
   cdSteps, design a contraction-path trace for `CortexCertificate`.

**Contraction-path trace idea**: A successful reasoning trace produces a path
`source EMLTree → ... → target EMLTree` where each contraction step is labelled
with the reinforcement type that authorized it. The certificate's `path` then
reads as shorthand for the reasoning trace.

**Output**:
- `docs/reinforcement_hopf_mapping.md`.
- Draft design for `CortexCertificate.reinforcement_trace`.

---

### Milestone 5 — Lean Formalization

**Research → Formalize → Blueprint**.

After the data-science phase produces a candidate grammar, formalize the
strongest findings in Lean:
- `ReinforcementType` as an inductive type or finite set.
- Composition laws consistent with `FrictionLagrangian` and
  `InstitutionalClosure`.
- Theorem: a reinforcement trace induces a valid `contracts_to` path.

Only after the formalization is stable is it used to adapt NormCode for
LaserCortex.

**Output**:
- New or extended Lean modules in `LaserCortex/`.
- Updated `docs/` reflecting the formal blueprint.

---

### Milestone 6 — NormCode Adaptation

Use the Lean formalization as the blueprint to:
1. Update `CortexCertificate.reinforcement_types` / `reinforcement_trace` in
   `infra/_cortex/_types.py`.
2. Wire reinforcement decoding into `run_vsm_loop` in
   `infra/_cortex/_vsm_loop.py`.
3. Store discovered reinforcements and their traces in Graphiti as typed nodes
   and edges.
4. Update tests and documentation.

---

## 3. Data-Science Toolkit

| Task | Tool |
|---|---|
| Parsing traces | `pandas`, `json` |
| Verb/frame lookup | `nltk.corpus.framenet`, `nltk.corpus.verbnet` |
| Ontology loading | `rdflib` / `owlready2` |
| Embeddings | local bge-m3 (`localhost:8082`) |
| Matrix factorization | `sklearn.decomposition.NMF`, `sklearn.decomposition.MiniBatchNMF` |
| Clustering / PCA | `sklearn.cluster`, `sklearn.decomposition.PCA` |
| Classification | `sklearn.linear_model.LogisticRegression`, `sklearn.svm.LinearSVC` |
| Knee detection | `kneed` (small PyPI package) or manual L-curve analysis |
| Reporting | `matplotlib`, `sklearn.metrics`, markdown/HTML |
| Batch LLM refinement | 35B A3B (one pre-approved batch) |

---

## 4. Resource Gates

1. **Embeddings**: local bge-m3 server on CPU at `:8082`. Use `batch_size=2`,
   `max_length=500` per SAFETY.md INC-1.
2. **NMF sweep**: CPU-bound, but `k=2000` on a sparse 758 × A matrix is modest.
   Cap memory with `ulimit` if needed.
3. **35B batch**: one batch pre-approved. Re-running a failed batch requires
   fresh approval.
4. **Context churn**: per SAFETY.md P5, reads from any text file are limited to
   10 lines per call; bulk ingestion requires explicit permission.

---

## 5. Success Criteria by Phase

| Milestone | Criterion |
|---|---|
| M0 | ≥ 100 distinct cross-ontology atoms (FrameNet + VerbNet + tools + PROV-O/P-PLAN). |
| M1 | Trace × atom matrix covers ≥ 90% of traces with non-zero activations. |
| M2 | A clear knee is found before `k=2000`; stable cross-ontology pairs persist across perturbation runs. |
| M3 | Top-3 tool-chain accuracy exceeds the TF-IDF baseline; per-chain recall is non-trivial for rare chains. |
| M4 | Discovered reinforcement types distribute across ≥ 4 distinct `cd_step` sectors; candidate `CortexCertificate` trace design exists. |
| M5 | Lean theorems compile and link to `FrictionLagrangian` / `InstitutionalClosure`. |
| M6 | VSM loop emits reinforcement traces; tests pass; Graphiti schema updated. |

---

## 6. Open Questions

1. Should the NMF objective also penalize components whose top atoms come from
the *same* ontology, to encourage cross-ontology reinforcement pairs?
   (Soft constraint via post-filtering is simpler; hard constraint may improve
   interpretability.)

2. Should rare tool chains be collapsed into an `other` class for prediction,
or do we keep all 37 chains and accept low recall on rare ones?

3. How should discovered reinforcement types be versioned once they are stored
in Graphiti? They will evolve as more traces are mined.

---

## 7. Next Step

If this plan is approved, the immediate next step is Milestone 0: install NLTK,
download FrameNet and VerbNet, and produce `data/reinforcement_atoms.json`.
