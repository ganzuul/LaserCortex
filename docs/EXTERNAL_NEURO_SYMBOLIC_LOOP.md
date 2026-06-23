# External Neuro-Symbolic Self-Improvement Loop with Formal Firebreak

## Summary

We present an architecture that makes large language model reasoning
cheaper and more reliable by externalizing the reasoning process into a
persistent, compressible, formally certified library. The system
combines three components: (1) a reasoning compression engine that
distills repeated LLM thinking traces into reusable system prompts,
(2) a Lean4 formal bridge that rejects impossible logic-type
compositions with a proved theorem, and (3) a self-improvement loop
connecting them. The architecture is task-agnostic and replicable with
any reasoning model and any theorem prover. We demonstrate it on
cross-layer dependency discovery in a 1400-module codebase.

## 1. Reasoning Compression

Reasoning models (e.g. DeepSeek-R1, Qwen3-A3B) generate an internal
thinking trace before producing output. Analysis of 200 verification
traces from a cross-layer dependency task shows that approximately
87% of generated tokens are reusable boilerplate: the model re-derives
the evaluation strategy, deliberates over the edge-type taxonomy, and
performs self-correction on every invocation. Only ~13% of tokens
(~350 of ~2700) are specific to the input pair.

The MetaCompressor collects N traces from the same reasoning cluster
(same task, same layer pair, same output type), sends them to the
reasoning model with a meta-prompt asking it to extract the common
strategy, and distills the result into a ~2800-character system
prompt. Subsequent invocations route to the matching script via
bge-m3 embedding similarity against the script centroid. This reduces
per-pair cost from ~2700 tokens to ~350 tokens — a 7.7x speedup —
without fine-tuning. The compressed scripts persist across sessions
and model versions.

The library is self-improving: each run produces new traces, which
either refine existing scripts or create new ones for novel patterns.
Outlier pairs (no centroid within threshold) fall back to full
reasoning, and their traces expand the library — shrinking the outlier
fraction for the next run.

## 2. The Formal Firebreak

The CortexBridge connects LLM reasoning traces to a Lean4 formal
layer. When a trace claims a logic type in the associative regime
(Cayley-Dickson step k <= 2) but structural resolution from the
module's properties places it in the non-associative regime (k >= 3),
the bridge detects a zero divisor: the composition is impossible
because the cost of reconciliation exceeds the maximum allowable
friction.

The bound is a proved theorem. The Friction Lagrangian
Γ_k = k + strut_weight * assocDefect(k) gives the energy density at
each Cayley-Dickson level. The associator defect is zero for k <= 2
and equals strut_weight = 4 for k >= 3. The theorem
`friction_barrier_across_cd23` states:

    For k1 <= 2 and k2 >= 3:  Γ_k2 - Γ_k1 >= strut_weight^2 = 16

The discontinuity ratio Γ_3 / Γ_2 = 19/2 = 9.5 is the maximum
allowable in the CD tower — it appears exactly once, at the
split-octonion boundary, fixed by strut_weight = 4.

When the bridge detects this boundary crossing, it emits a ZDWitness
carrying the claimed and structural LogicTypes, the CD steps, the
barrier constant (strut_weight^2 = 16), the friction ratio (9.5), and
the proof term (`FrictionLagrangian.friction_barrier_across_cd23`).
This is a formal certificate of rejection, not a heuristic guardrail.

Validation: 10/10 on a curated test set (6 certified, 4 ZD-rejected)
and 131/131 on organic data with 0 false positives.

## 3. The Loop

The three components form a closed loop:

    35B generates traces
        -> compressor distills scripts
        -> router dispatches new pairs
        -> bridge certifies or rejects
        -> traces refine the library

The symbolic state (the reasoning library) is external to the model
weights. It persists across sessions, across model versions, and
across runs. The system gets cheaper and more accurate with use
without any fine-tuning or weight updates.

The formal firebreak and the reasoning cache reinforce each other:
the bridge provides mathematical certainty where the CD boundary is
crossed; the cache provides statistical acceleration where reasoning
patterns repeat. The loop connects them — the bridge's verdicts
become traces in the library, and the library's scripts route pairs
to the bridge for certification.

## 4. Replicability and Limitations

The architecture is a pattern, not a model. The TaskConfig +
ReasoningLibrary framework generalizes to any structured
classification task with repeated reasoning patterns: swap the config
and the same compression-routing-certification loop applies. The
formal bridge requires a theorem prover that can express the
composition-cost bound; we use Lean4, but any proof assistant with
arithmetic reasoning suffices.

Limitations:
- Cold start: the library requires seed traces before compression
  can begin. Our 200-trace seed run took ~3.5 hours on a single
  35B model (RTX 2070 SUPER, 8 GB VRAM).
- Tractable logic only: the formal firebreak catches what the
  theorem prover can prove. Logic outside the CD tower is not
  covered.
- Centroid routing requires an embedding model (we use bge-m3,
  1024-dim, CPU).
- The compression quality depends on trace diversity within each
  cluster; homogeneous traces compress well, heterogeneous ones
  may need sub-clustering.

## 5. Implementation

The system is implemented in the LaserCortex repository:

- `scripts/reasoning_library/` — the library, compressor, and router
  (task-agnostic, ~1000 lines)
- `scripts/phase5_cross_layer_discovery.py` — the cross-layer
  dependency task that seeds and uses the library
- `LaserCortex/FrictionLagrangian.lean` — the formal firebreak
  (the `friction_barrier_across_cd23` theorem)
- `infra/_cortex/_bridge.py` — the CortexBridge with ZD detection
  via dual LogicType resolution
- `.open-notebook/reasoning_library.json` — the accumulated library
  (5 scripts, 200 traces, 128 verified edges)

Current library state: 5 reasoning scripts at confidence 1.0,
covering 5 of 7 trace clusters (2 clusters had <3 traces). The
scripts range from 2392 to 3186 characters. Centroids are 1024-dim
vectors computed from 3-39 source traces per script.

---

*The moat is not the architecture — anyone with a reasoning model and
a theorem prover can build this. The moat is the accumulated trace
library, which has a 7.7x compounding advantage over starting from
scratch.*
