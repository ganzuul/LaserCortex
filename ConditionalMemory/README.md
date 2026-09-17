# ConditionalMemory — the PLE-I/O program

Lean-first (not Lean-only) research directory: turn the model's own
n-gram/PLE dictionary into a **read–write conditional-memory channel** —
prompts compiled into gram events (test-time writes), and eventually
gram-space encodings at the output side. The algebra was machine-checked
before any engine code was written; the executable spec now mirrors it.

## Layout

| file | role |
|---|---|
| `LaserCortex/ConditionalMemory/GramDictionary.lean` | machine-checked certs: positional fold (`gramVal/gramKey`), collision-free regime, bag channel (`writes_perm`, `noInterference`, `selfPresence`), real-model layout certs, `windowAt` + golden vectors = probe contract (R4) |
| `LaserCortex/ConditionalMemory/YSystem.lean` | pentagonator certs: A₂ period-5 closure (Zamolodchikov), centered log-Y form closed for **all β**, draft-literal divergence, quaternion non-closure + ℂ-plane positive control (commutativity is load-bearing) |
| `ConditionalMemory/ple_io.py` | **executable spec** — mirrors every Lean definition, exits nonzero if any certificate fails: `python3 ple_io.py` |

## Base-architecture survey (Sep 2026)

Properties needed = gram dictionary + softplus-gated linear-memory
("commutator") + MoE + attention, with an OSI code path that works today.

| | qwen4exp (served here) | DeepSeek-V4.1-Flash | Nemotron-H |
|---|---|---|---|
| gram dictionary | PLE: orders {2,3}×8 heads×20M coprime-odd moduli, layer [1] | **Engram**: orders {2..4}×8 heads×16M×256 @ layers [1,14] ≈196B (arithmetic self-consistency certified in spec) | NGramEmbedding (paper) |
| softplus commutator | GDN `g=−exp(A_log)·softplus(a+dt_bias)` (sglang kernel verified) | **`scoring_func: sqrtsoftplus`** — softplus-family gate shipped in the MoE router itself | Mamba-2 `dt_softplus` |
| residual-stream mixer | hyper-connections `hc_count=4` | **mHC + Sinkhorn** (`hc_mult:4, hc_sinkhorn_iters:20`) — doubly stochastic = mixture of permutations (Birkhoff): the commutative mixer | — |
| MoE | 512/10 | 384/6 + 1 shared | ✓ |
| code, local, working | **SGLang Apache-2.0 ✓ (our tree)**; llama.cpp fork MIT | sglang/transformers 5.12.1 have `deepseek_v4`, **not `v41` yet** — MIT weights make vendoring trivial | Megatron/NeMo Apache |
| weights license | community FTQ derivative (upstream Qwen lineage Apache) | **MIT** | NVIDIA Open (not OSI) |
| runs on this 8GB/23GB box | serve path proven (FTQ + `--ngram-ssd`) | no (552B/16B act) | no (weights license + size) |

**Verdict:** V4.1-Flash = MIT production **blueprint** (confirms the
certified structure end-to-end: pad-token windowing `engram_pad_token_id:2`,
multi-head coprime-style buckets, softplus router gating, Sinkhorn residual
mixing). qwen4exp = the **local working instance** for experiments. The
recombination we own: *test-time writes* into a gram delta-table
(roadmap R1/R2) — absent from all three, and the whole point.

## Findings the Lean-first pass produced (all now executable)

1. **R2 windowing convention**: naive standalone-needle membership has false
   negatives; both-side sentinel padding does **not** fix it (decoys + padding
   witnessed in spec); anchored complete windows are sound-but-necessary;
   sufficiency needs chaining → R3. V4.1 shipping a pad token id validates the
   problem exists in production.
2. **Commutativity, not alternativity**, carries Zamolodchikov closure
   (quaternion counterexample certified; Artin insufficient) — so the gram
   bag channel (commutative) is where learned-write algebra is clean.
3. **Sinkhorn = the residual-side commutator** (numerically certified:
   doubly stochastic + permutation-equivariant) — completes the trichotomy:
   dictionary (Engram/PLE, read) · residual mixer (mHC/Sinkhorn, commutative)
   · commit rate (softplus/sqrtsoftplus, gate).
4. **V4.1 profile self-consistency**: 3 orders × 8 heads × 16M = 384.0M slots
   ≈ config's 384,006,168; × 2 layers × 256 dims ≈ 196B — the published
   claim reconstructs from first principles.

## Roadmap (canonical list lives in `GramDictionary.lean` §R)

- **R5** multi-head CRT joint injectivity; **R6** Sinkhorn formal proofs
  (convergence, equivariance, Birkhoff) — next Lean targets
- **R1** delta-write locality bound; **R3** de Bruijn order reconstruction
- Pull the MIT `inference/` + `deepseek-recipe` code → pin Engram's exact
  windowing/moduli semantics (open: pad-in-window question)
- Stage-0 probe: real tokenizer, real V4.1/qwen4exp constants → compression &
  co-occurrence curves (gramdict already matches the golden vectors)
- Toy recombined model (torch, Apache parts): frozen gram table + softplus-gated
  side-table writer + mHC mixer → needle-membership eval vs KV baseline
