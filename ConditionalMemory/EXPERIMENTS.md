# PLE-I/O — Validation Ladder & LUMI-G Experiment Plan

Goal (per SPEC.md): validate the conditional-memory **write path** —
frozen gram dictionary + [NEW] test-time delta table + [NEW] centered-softplus
commit gate — on rented GPUs first, then scale on **LUMI-G** (EuroHPC/CSC,
AMD MI250X) under a compute grant. Everything here is plain PyTorch:
device-strings `cuda` work unchanged on ROCm builds (LUMI-G), and **no custom
kernels** is a deliberate portability constraint.

The experiment is novel-by-construction: Engram/Nemotron-H/qwen4exp all treat
the gram table as **train-time, read-only** ([REUSE blocks, SPEC §3]); the
inference-time *writer* + delta table is the piece none of them has — and the
piece our Lean certificates pin (bag commutativity `writes_perm`, isolation
`noInterference`, CRT addressing `v41_table_recon` + joint-injectivity bound,
edit locality `refHash_congr_one_edit`).

## Hypotheses

| # | claim | evidence today | stage that decides it |
|---|---|---|---|
| H1 | A gram-channel answer is **length-invariant at constant write/read cost** (≤ Σ_orders n × heads keys/token; certified) where a small KV trunk degrades as L grows | toy (this dir) | S1 |
| H2 | Delta writes give **zero-shot knowledge acquisition** (needle/NIAH/MQAR) without weight updates, at host-memory cost ≪ KV replay | Engram paper shows *static* table frees attention for global context (NIAH 84→97); ours extends to *new* facts | S2 |
| H3 | The **commit gate** (centered softplus, init-closed) learns when to write: rate ≈ 0 on boilerplate, ↑ on high-surprise grams; gated writes beat ungated on noisy streams | review §4 (centering), Mamba-2/GDN precedent | S2 |
| H4 | Capacity allocation follows an **Engram-style U-curve** when the memory is writable (delta table vs frozen base vs KV) | Engram 27B iso-param/iso-FLOPs method | S3 |

## Stages

### S0 — semantics lock (DONE, no GPU)
`ConditionalMemory/ple_io.py` (12 groups green) + Lean certs (propext-clean
except flagged `native_decide` table reconstruction). Every implementation
stage must keep passing these as regression tests.

### S1 — mechanism validation (rented single GPU; smoke runs here on a 2070S)
`toy/train.py` — tiny trunk, three arms: `kv` | `gram_closed` (dead channel,
capacity control) | `gram`. Task: gram-membership (needle inserted in random
stream; query span: present?). Train at L ∈ [48,128], **eval at L ∈ {128 …
2048}** (attention must search; channel cost flat). Pass criteria: gram arm
acc ≥ 0.95 across lengths incl. extrapolated; `kv` arm collapses beyond train
lengths; learned `commit_rate` visibly rises from 0.
**S1 PASS (smoke, 2026-09-17, 2070S):** gram = 1.00/1.00/1.00 @ L
96/512/2048, rate 0→0.006 (self-opening); kv = 0.44/0.49/0.51. Design note
from the smoke: the gate must be centered-softplus WITHOUT clamp_min —
clamped-at-0 init is gradient-dead and keeps the channel permanently shut.
**S1 FULL MATRIX PASS (rental RTX 3090 @ $0.192/h, 2026-09-17, ~9 min,
~$0.03):** 3 seeds × {kv, gram_closed, gram} × 1500 steps — gram = **1.00 at
every L ∈ {96,512,1024,2048,4096}, every seed**; control arms chance
(0.42–0.57) at all lengths; gate self-opens 0→0.031–0.034 then loss→0.000.
Artifacts + root-cause of the two harness bugs the rental exposed (missing
`model.eval()`; untrained-position `N(0,1)` embedding noise out-scaling the
channel — fixed by zero-init embeddings) in `toy/rental_3090/` +
toy/README.md. Both lessons are now S2 code-review checklist items.
Rental budget: ~2–8 GPUh, any 24GB card. Also: real-tokenizer variant
(Qwen3 tokenizer, wiki streams, 32k vocab) as S1.5.
**S1-LARGE (W2) PASS (rental 3090, 2026-09-17, commit a2517f6+):** ~100M
trunk, vocab 64k, V4.1-scale prime tables (~8.4M/table) — gram arm 1.00 at
every seed × every L∈{1024,2048,4096,8192}; controls chance. **W1 cost model
(`toy/ple_bench.py`, rental_3090/ple_bench_3090.json):** read path 0.036
µs/token FLAT 0.25→16GB tables; pinned host-RAM tables 0.26 µs/token (7×
HBM, still L-invariant); fp32 attention OOMs at 32k where the channel is
linear — this is the S3 capacity-curve data at single-GPU scale.

### S2 — knowledge-injection scale (multi-GPU rental → LUMI-G dev allocation)
Backbone: hybrid ~400M–1B (GDN or Mamba-2 trunk — the softplus commutator,
MHA layers, 64–512-way MoE-lite) trained ≤ 2B tokens for coherence, then:
- freeze weights; attach frozen gram table (train-time part) + delta table
  (host DRAM; addressing = `head_primes`, certified disjoint tiling);
- eval: **zero-shot fact recall** (inject N facts as documents into delta, QA
  without the docs in context), NIAH variants, MQAR; baselines: (a) KV-context
  replay of the same corpus, (b) frozen-table-only (Engram parity), (c) no
  memory. Metrics: recall vs N (capacity), per-token compute (FLOPs), host
  bytes, edit cost via locality bound.
- ablations: gate on/off, ungated vs centered-softplus, pad-fill vs
  truncate-window writer conventions (both certified; which generalizes?).
Compute sketch: 1B×2B tok ≈ 3–6k A100h rental or ~same on 8×MI250X node-weeks;
apply **LUMI-G dev/Q3-style allocation** with S1 results as feasibility proof.

### S3 — allocation study (LUMI-G grant main act)
Iso-parameter / iso-FLOPs curves per Engram's U-law, with **delta capacity**
as the third axis (frozen base table size × delta size × KV budget) at
0.5–3B: the write-path analogue of `calculate_vocab_size_across_layers` scale
logic. Deliverable: "how much writable gram memory buys what KV recompute" —
the cost-model pitch for grant reviewers (host RAM on LUMI-G nodes is the
resource the addressing certs are designed for). Budget tier: 30–60k
MI250X GPUh → EuroHPC "Access to Exascale Computers"/CSC call; PRACE/Finnish
national as fallback routes.

## Evidence status — 2026-09-17 evening (post W1–W4, all rental 3090, ~$1.10 total)

| rung | artifact | verdict |
|---|---|---|
| S1 mechanism | `rental_3090/results_s1_*` (9 jsons, 3 arms × 3 seeds) | gram 1.00 @ all L∈{96…4096}; controls chance |
| S1-LARGE (W2) | `results_large_*` (~100M trunk, 64k vocab, t≈8.4M) | gram 1.00 @ every seed × L up to 8192 (10.7× extrap) |
| W1 cost model | `ple_bench_3090.json` | 0.035 µs/token gather FLAT 0.25→16GB; host-RAM table 0.26 µs/token; fp32 attention OOMs at 32k |
| W3 real text (H2-baby) | `results_w3_*.json` (WikiText-103 × GPT-2 vocab) | gram {p .80→.99, **a 1.00, m 1.00**}; kv present-collapse .06→.01; closed arm unstable — trunk-only solutions vary wildly by init, gram's zero-false-presence is the only stable corner |
| W4 modulus sweep | `results_w4_t*.json` | NULL as run (28M trunk never learned readout — scale cliff, not collision); re-derivation corrected the theory: collision floor is **three-phase** and ~4 orders lower than assumed — per-window spurious rate λ=L_seq/t, false-present ≈ λ^40 (absent, breaks t≲512) / λ^3 (mutated canary, t≲16k) / 0 (present, count≥2 guaranteed). V4.1-scale tables sit 3 orders above any failure ⇒ host-RAM budget can shrink drastically. v2 design recorded (toy/README). |
| CPU parity | `results_cpu_parity.json` | gram arm 1.00 @ all L on pure CPU — the certified path is backend-agnostic (ROCm itself still un-run: claim it as shown on CPU, pending MI250X) |
| Portability constraint | repo-wide | plain PyTorch, zero custom kernels, `cuda` device-strings → ROCm unchanged |

**What this buys for the application**: W1+W3 together answer the committee's
two real questions — *"is the big HBM actually the bottleneck?"* (measured
cost, flat in table size; the OOM wall is attention's quadratic scores, not
memory) and *"does the cert mean anything at the noise floor?"* (W3: on real
English, collision-noise rejection is exact at t≈8.4M, and corrected theory
now predicts WHERE it breaks, falsifiably, for t≈512–16k). The scale cliff
(28M fails, 47M learns readout) is itself S3-relevant: readout learning is a
capacity threshold we can now place between two measured points.

**Remaining before "apply"**: (1) S2 pilot — hybrid GDN/Mamba-2 trunk
400M–1B with frozen gram + delta tables and zero-shot fact injection;
rental economics put it at 3–6k A100h ≈ **$5–18k cash vs $0 on a dev
allocation** — the grant is a hard requirement, not an ambition; (2) first
actual MI250X/ROCm run (trivial expected, but say "measured" not
"should work"); (3) R3 de Bruijn-chaining theory work-package written in
Lean; (4) human logistics (affiliation/eligibility, PI letter, timeline) —
none of it code.

## Why this reads well to a GPU-allocation committee

1. Every design decision is **pre-certified** (Lean) — the failure modes
   (key collisions, write interference, edit blast-radius) have proven bounds,
   not vibes; S2/S3 measure where the bounds bite in practice.
2. The mechanism is **cheap to run**: the expensive object (gram table) is
   host-DRAM-resident with deterministic addressing — exactly the HBM-for-RAM
   exchange LUMI-G's node topology (8× MI250X/64GB each + large host memory)
   is built for.
3. Clear go/no-go at each rung; S1 artifact already exists in-repo.

## Risks / open semantics (carried from SPEC §4)
- multiplier provenance & compressed-vocab artifact (MIT `inference/` read);
- V4.1 pad-vs-truncate (both implemented; choose empirically at S2);
- delta eviction policy at scale (LRU vs count-recycle) — unproven; S2 ablation;
- membership vs *ordering*: bag answers "was X seen", not "in what order" —
  R3 (de Bruijn chaining) is the formal follow-up that upgrades membership to
  sequence reconstruction; grant proposal should list it as theory work-package.
