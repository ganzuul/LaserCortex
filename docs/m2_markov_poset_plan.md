# M2 — Markov Poset for Reinforcement Type Discovery

**Replaces** the NMF sweep originally specified in
`docs/reinforcement_type_discovery_plan.md` § Milestone 2.

## Rationale

The M1 cos-sim activation matrix is 100% dense — every trace activates every
atom, which makes NMF components murky averages rather than clean cross-ontology
pairs. The word-level correspondence (`build_owl_correspondence.py`) revealed
that the real signal is in discrete word→atom matches (NL words matched to OWL
atoms by label or verb member), which is ~1-2% sparse.

The correct structure is a **Markov chain poset** (redisbot pattern):
https://github.com/coleifer/irc/blob/master/bots/redisbot.py

A Markov chain is a poset (partially ordered set) because from a given state
(2-gram of words), multiple next words are possible — a partial order, not a
deterministic linked list. Each trace's thinking block is one walk *through*
the poset. Aggregating 758 traces gives us the full transition poset.

## Data Model

Two parallel sequences, linked at each position:

```
Position:    0          1          2          3          n
NL chain:    w₀   →    w₁   →    w₂   →    w₃   →  ...  wₙ
              ↓          ↓          ↓          ↓
OWL match:  {A, B}    {C}        {A, D}     {E}       ...
```

- **NL chain** (redisbot chain): `P(wᵢ₊₂ | wᵢ, wᵢ₊₁)` — 2-gram Markov model
- **NL→OWL** (match table): `wᵢ → {atom_A, atom_B, ...}` — precomputed per word
- **OWL chain**: implicit from NL chain + NL→OWL — derived, not stored directly

A candidate **reinforcement type** is a maximal-length OWL atom subsequence
whose atoms come from ≥2 ontology sources and whose probability under the chain
exceeds a threshold.

## Data Augmentation Without Blood Crossing

The NL→OWL match table is computed once from the cleaned word→atom index
(label + verb_member only, no description matches). The Markov chain on NL
words generates infinite synthetic word sequences. Each synthetic word maps
back to its pre-computed OWL atoms. Result: synthetic OWL sequences that
reflect real reasoning patterns without ever reading raw trace text.

The blood-brain barrier is structural: generation operates entirely in OWL
space, but the chain was learned FROM traces.

## M2a — Build the Markov Poset (`scripts/build_markov_poset.py`)

**Input**: `reasoning_library/traces.jsonl` (758 traces)

**Steps**:
1. For each trace, extract `thinking_block`, tokenize into words.
2. Lowercase, strip punctuation (as redisbot's `sanitize_message`).
3. Append stop word `\x02` to each trace's word list.
4. For position i from 0 to n-2: record transition `(wᵢ, wᵢ₊₁) → wᵢ₊₂` as a
   **set** of possible continuations (the poset).
5. For each word wᵢ, look up matched OWL atoms from the word→atom index
   (precomputed by `build_owl_correspondence.py`, filtered to label +
   verb_member match types).
6. Store the NL Markov chain as a sparse matrix `states × next_words`.
7. Store the NL→OWL match table as a JSON dict `{word: [atom_id, ...]}`.

**Chain length**: N=2 (bigram). Future work: adaptive N for atomic phrases
("it is what it is") based on frequently observed word sequences.

**Stop word**: `\x02` (ASCII record separator), same as redisbot.

**OWL→OWL edges**: NOT stored in M2. That comes during the NMF phase (M3/M4
territory) as a transcription. OWL→OWL would explode the graph without the
constraint of NMF component boundaries.

### Output files
- `data/nl_markov_chain.npz` — sparse transition matrix (state → next_word)
- `data/nl_markov_metadata.json` — vocabulary, state mapping, trace counts
- `data/nl_to_owl_match.json` — word → list of OWL atom IDs
- `data/markov_poset_stats.json` — unique states, transitions, sparsity, etc.

## M2b — Analyze the Poset (`scripts/analyze_markov_poset.py`)

1. **Stationary distribution** of the NL Markov chain. Tells us which 2-gram
   states are the most stable attractors — these are "anchor compositions"
   that the reasoning loop dwells in.
2. **Top-K frequent paths**: For each trace, re-walk the chain from its start
   state, recording the sequence of matched OWL atoms. Count subsequence
   frequencies. A candidate reinforcement type = a maximal OWL subsequence
   that appears in ≥K traces with ≥2 distinct ontology sources.
3. **Stationary distribution of derived OWL chain**: Project the NL stationary
   distribution through the NL→OWL match table. Tells us which OWL atoms are
   most visited at the fixed point of reasoning.

### Output files
- `data/reinforcement_candidates.json` — candidate types with atom sequences,
  trace support, ontology sources, chain probability.
- `data/owl_stationary_distribution.json` — OWL atom probabilities at the
  chain's fixed point.

## M2c — Data Augmentation (Generation)

Exactly redisbot's `generate_message` pattern:

```
seed_state = random_state_weighted_by_stationary_distribution()
for step in range(max_words):
    emit current word's matched OWL atoms
    next_word = sample_uniform_from_transition_set(state)
    if next_word == STOP: break
    slide: state = (state.word2, next_word)
```

Each generated sequence is a synthetic reasoning trace, expressed as OWL atom
sequences only. The blood-brain barrier is structural: the generation loop
never reads raw trace text. The NL words are just scaffolding for the poset
structure — they never leave the Markov chain.

### Output file
- `data/synthetic_owl_sequences.json` — N generated sequences, each a list of
  [word, [matched OWL atoms], ...] with the match table.

## M2d — Knee / Stability (Renamed from "Perturbation Analysis")

Instead of NMF reconstruction error:
1. **New-transitions curve**: plot `|new_transitions|` per trace. The knee is
   where traces stop enlarging the transition graph. This tells us the minimum
   number of traces needed for a representative poset.
2. **Subsample stability**: randomly subsample 50/75/90% of traces, rebuild the
   transition poset, measure Jaccard similarity of the transition sets. The
   knee is where similarity stabilizes > 0.9.

## M2 → M3 Bridge

The discovered OWL subsequences (reinforcement candidates) become features for
tool-chain prediction (M3). Each trace's feature vector = binary indicators for
which subsequences appear in its OWL atom sequence. This is a natural fit for
logistic regression and directly comparable to the TF-IDF baseline.

## Timeline

| Step | Script | Est. time |
|------|--------|-----------|
| M2a | `build_markov_poset.py` | ~1 session |
| M2b | `analyze_markov_poset.py` | ~2 sessions |
| M2c | (same script as generation) | ~1 session |
| M2d | (analysis, no new script) | ~1 session |

## Libraries

- `numpy`, `scipy.sparse` — sparse transition matrix, eigenvector computation
- `json`, `collections` — transition set storage, word→atom index
- No new installs required. The approach is pure Python dicts + scipy — no
  Redis dependency (unlike redisbot, which used Redis for persistence).
