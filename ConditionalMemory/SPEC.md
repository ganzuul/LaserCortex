# PLE-I/O Architecture Spec — v0 (derived: #1 → #2 → formulation → #1)

Pipeline: read DeepSeek's MIT Engram reference (**#1**) → certify its semantics
in Lean (**#2**, `EngramReference.lean`) → formulate PLE-I/O from the certified
pieces (§F there) → project back onto #1's code blocks (this table) → the
architecture below. Executable twin: `ple_io.py` (12 cert groups, all pass).

## 1. Semantic map — Lean ↔ reference (#1) ↔ V4.1 config ↔ served qwen4exp

| concept | Lean (`EngramReference` unless noted) | reference block (`engram_demo_v1.py`) | V4.1 config.json | served stack (sglang) |
|---|---|---|---|---|
| token canonicalization | *(open — weights artifact)* | `CompressedTokenizer` L60, `_build_lookup_table` L84 | `engram_compressed_vocab_size: 99092` ✓ derived count | — (raw vocab) |
| pad-filled window | `tokAt`, `refWindow`; head-vs-trunc `example`s | `shift_k` + `np.pad(constant_values=pad_id)` (L268-277) | `engram_pad_token_id: 2` ✓ | `ngram_embedding.cuh`: **truncate** at start, **cut at EOS** (different convention!) |
| fold | `refHash` + `xor_swap` | `_get_ngram_hashes` L262: `⊕_k t_{i−k}·m_k mod p` | — | `oe_weights = pow(V,δ,mod)`: **polynomial** fold (GramDictionary `gramVal/gramKey`) |
| per-position multipliers | *(opaque — RNG)* | `__init__` L216-233: `rng(seed+10007·layer)` → `r*2+1` odd int64 | not published | GGUF `ple.layer_multipliers` = 3 published odd int64 (≈2^43–2^45, within the RNG's `half_bound` ⇒ likely same scheme, *published* not re-seeded) |
| per-head moduli | `nextPrime`,`collectHeads`,`layerTotal`; **`v41_table_recon`** (native_decide) | `find_next_prime` L181 + `calculate_vocab_size_across_layers` L235, global distinct `seen_primes` | `engram_num_embeddings = [384006168, 384016682]` — **reproduced exactly** (residues = prime overshoots) | 16 odd (near-)coprime composites ≈20M (`head_vocab_sizes`, certified `headMods_pairwise_coprime`-style) |
| content addressing | `jointKey` + ple_io CRT bound (`2^63 < 16_000_003^8`) | residues → `MultiHeadEmbedding` L305 | 8 heads/order ⇒ joint vector injective on any int64 mix | same tiling, certified `offsets_eq_scanl`, `headWindows_disjoint` |
| table layout | `headOffsets` (scanl) | L311-314 exclusive cumulative offsets | `Σ primes` per layer ✓ | scanl tiling ✓ |
| injection gate | `gate_range` (0<σ<1) | `Engram.forward` L358: `sigmoid(sign√-compress(⟨norm(key), norm(q)⟩/√D))` per hc stream | `hc_mult: 4` ⇒ 4 key_projs | static `layer_multipliers` (no query gate) |
| local dynamics | *(not yet formalized)* | `ShortConv` L123, depthwise, kernel 4, **dilation = max_ngram** | — | `ple.conv_kernel: 4` ✓ |
| bag channel | `GramDictionary.writes_perm / noInterference / selfPresence` | additive `engram(...) + hidden_states` | — | ✓ certified for served fold |
| edit locality | **`refHash_congr_one_edit`** (axiom-clean) | (implicit in their shift design) | ⇒ ≤144 keys/edit | ⇒ ≤40 keys/edit |

## 2. What the formulation licenses (and forbids)

1. **Two fold families, one bag algebra.** Reference = XOR of position-colored
   products; served qwen4exp = positional polynomial. Both fold a multiset of
   (position, token) products through a commutative operator; the write path
   must key on the family actually deployed — keys are NOT portable across
   families (asserted divergence: ple_io `cert_reference_fold`).
2. **R2 is closed, not open:** production Engram *left-pads* (`pad_id`,
   remapped through the compressed table); serving qwen4exp *truncates* and
   *cuts at EOS*. A writer targeting both must parameterize the convention;
   anchored complete windows are the family-agnostic sound subset (§1 here,
   ple_io §R2 certs).
3. **Deterministic addressing is provable, not aspirational:** pairwise-coprime
   prime moduli + int64 products ⇒ the 8-residue joint vector *uniquely*
   determines the mix (CRT; `2^63 < Πp`). Write keys are collision-free by
   construction — the formal ground of the paper's prefetch claim, and the
   invariant our delta-table relies on.
4. **Delta cost is bounded by construction:** one edited token ⇒ ≤ Σ_orders n
   × 8 heads × layers keys (40 served / 144 V4.1-class) — Lean
   `refHash_congr_one_edit`, ple_io locality spot-suite.

## 3. Derived architecture (component provenance)

```
prompt ──[REUSE demo L60] CompressTokenizer──▶ canonical ids
       ──[REUSE demo L262 ≡ Lean refHash] windows(order n, pad-convention τ) ─▶ XOR-mix
       ──[REUSE demo L181/L235 ≡ Lean v41_table_recon] prime per-head moduli
       ──▶ jointKey vector (CRT-injective content address)
       ──[NEW] CommitGate: centered-softplus rate  g = softplus(a)−log2, clamp≥0
       ──[NEW] DeltaTable := GramDictionary.Table writes (bag; writes_perm)
       ──[REUSE demo L358 pattern] read: σ(⟨k,q⟩) ⊙ value_proj(emb) + ShortConv(Δ=4,k=4)
       ──▶ residual stream (additive, commutative channel)
frozen base Engram table: reads unaffected on disjoint support (noInterference)
```
**NEW blocks are exactly two:** the commit gate and the delta table —
everything else is #1 reused with Lean-pinned semantics. Output side
(PLE-format I/O, rung 3) stays research (SPEC v1+).

## 4. Open semantics (next reads of #1/weights)
- multiplier provenance: published GGUF arrays vs RNG-seeded recompute (np
  Generator stability across numpy versions ⇒ publish or pin).
- Does V4.1's inference kernel pad or truncate at heads (demo pads; served
  qwen4exp truncates) — read `DeepSeek-V4.1-Flash/inference/`.
- EOS handling in the reference (absent) vs serving kernel (hard cut).
- `compressed_vocab` artifact: extractable from weights? (determines keys!).

## 5. Implementation queue
1. torch toy (no engine): synthetic vocab, demo-faithful blocks + the two NEW
   components → needle-membership eval, delta-vs-KV at equal memory (Stage 1).
2. Stage-0 real probe: tokenizer + reconstructed prime tables → compression &
   co-occurrence curves (keys cross-checked against `ple_io`/golden vectors).
3. Lean: R5 general CRT, R6 Sinkhorn formal, R3 de Bruijn chaining.
