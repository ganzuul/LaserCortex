#!/usr/bin/env python3
"""
ple_io.py — executable specification for the PLE-I/O channel.

Standalone Python mirror of the machine-checked Lean certificates in
LaserCortex/ConditionalMemory/GramDictionary.lean (namespaces omitted here),
extended with the softplus "commutator" write gate certified as Mamba-2/GDN's
contribution (see docs review §E1: softplus gates the commutative WRITE bags;
the write-gate centering fix from the pentagonator review §4 is applied:
a zero raw-logit must mean zero commit).

Base-architecture provenance (verified in this environment, Sep 2026):
  - qwen4exp family is the open implementation with BOTH certified properties
    working LOCALLY: gram dictionary (read channel) + softplus-gated delta-rule
    recurrence. Implementations: SGLang (Apache-2.0)
    models/qwen4_exp.py + layers/n_gram_embedding.py +
    kernels/ops/speculative/ngram_embedding.py, and the llama.cpp fork (MIT).
  - DeepSeek-V4.1-Flash (MIT weights) = the production-validated BLUEPRINT:
    Engram conditional memory (layers [1,14], max_ngram 4, 8 heads × 16M
    buckets × 256 dims ≈ 196B — arithmetic self-consistency certified in
    cert_v41_profile_consistency), mHC Sinkhorn residual mixer (hc_mult 4,
    hc_sinkhorn_iters 20 — same fields as sglang configs/deepseek_v4.py:109),
    scoring_func "sqrtsoftplus" (the softplus commutator ALREADY shipping in
    production MoE routing; sglang layers/moe/hash_topk.py:43 defaults to it),
    engram_pad_token_id 2 (validates the R2 windowing-convention finding).
    Support gap: model_type `deepseek_v41` not yet in local sglang/
    transformers 5.12.1 (which has deepseek_v4); MIT license makes vendoring
    trivial when needed.
  - Model-weight licenses vary per model; this module needs only the certified
    ARITHMETIC, so it is architecture-portable. The real arrays below are the
    served qwen4exp model's public GGUF metadata constants; V4.1-Flash
    constants live in the V41 profile below.

Run:  python3 ple_io.py   → executes all certificates; exits nonzero on failure.
"""
from __future__ import annotations

import itertools
import math
import random
from collections import Counter

# ---------------------------------------------------------------------------
# Real-model constants (GGUF `qwen4exp.ple.*`, certified in Lean §4)
# ---------------------------------------------------------------------------
VOCAB = 248_320
EOS = 248_044
NGRAM_SIZE = 3            # window max length w = 3 (orders {2,3})
HEADS_PER_NGRAM = 8
HEAD_MODS = [
    20000003, 20000023, 20000033, 20000047, 20000059, 20000063, 20000069,
    20000077, 20000081, 20000093, 20000107, 20000147, 20000153, 20000159,
    20000161, 20000171,
]


# ---------------------------------------------------------------------------
# 1. gramVal / gramKey / windowAt — 1:1 with Lean
# ---------------------------------------------------------------------------
def gram_val(V: int, window_newest_first: list[int]) -> int:
    """gramVal (x :: l) = x + V * gramVal l, newest token first (Lean)."""
    acc = 0
    for x in reversed(window_newest_first):
        acc = x + V * acc
    return acc


def gram_key(V: int, m: int, window_newest_first: list[int]) -> int:
    return gram_val(V, window_newest_first) % m


def window_at(w: int, tokens: list[int], i: int) -> list[int]:
    """Lean `windowAt`: newest-first, length ≤ w, start-truncated."""
    seg = tokens[: i + 1]
    start = max(0, len(seg) - w)
    return list(reversed(seg[start:]))


def window_at_eos(w: int, tokens: list[int], i: int, eos: int) -> list[int]:
    """Kernel semantics (ngram_embedding.cuh): context does not cross EOS,
    except that EOS itself may be the current token (j == 0)."""
    out = []
    j = 0
    while j < w and i - j >= 0:
        t = tokens[i - j]
        if j > 0 and t == eos:
            break
        out.append(t)
        j += 1
    return out


def head_offsets(mods: list[int]) -> list[int]:
    """Lean `offsets_eq_scanl`: offsets = cumulative sums of moduli."""
    return [0, *itertools.accumulate(mods)]


def embed_key(tokens: list[int], i: int, order: int, h: int,
              mods: list[int], offsets: list[int]) -> int:
    """Absolute bucket id for (order ∈ {2,3}, head h ∈ [0,8)) at position i."""
    idx = (order - 2) * HEADS_PER_NGRAM + h
    return gram_key(VOCAB, mods[idx], window_at(order, tokens, i)) + offsets[idx]


# ---------------------------------------------------------------------------
# 2. The bag channel (E1 spine): DeltaTable = commutative accumulation
# ---------------------------------------------------------------------------
class DeltaTable:
    """Finsupp ℕ →₀ ℤ mirror: key → multiplicity accumulation."""

    def __init__(self) -> None:
        self._counts: Counter[int] = Counter()

    def write(self, key: int) -> None:
        self._counts[key] += 1

    @classmethod
    def writes(cls, keys) -> "DeltaTable":
        t = cls()
        for k in keys:
            t.write(k)
        return t

    def merge(self, other: "DeltaTable") -> "DeltaTable":
        """Bag union: commutative + associative (Table addition)."""
        t = DeltaTable()
        t._counts = self._counts + other._counts
        return t

    def read(self, key: int) -> int:
        return self._counts[key]

    @property
    def support(self):
        return {k for k, c in self._counts.items() if c != 0}


# ---------------------------------------------------------------------------
# 3. The commutator: softplus-gated writes (Mamba-2/GDN contribution)
#    Lean-adjacent facts (this session): dt = softplus(proj + bias);
#    GDN: g = -exp(A_log) * softplus(a + dt_bias). Centered per review §4:
#    a zero raw logit must commit nothing  (softplus(x) - softplus(0)).
# ---------------------------------------------------------------------------
def softplus(x: float) -> float:
    return x + math.log1p(math.exp(-abs(x))) if x > 0 else math.log1p(math.exp(x))


def centered_softplus(x: float) -> float:
    """φ̃(x) = softplus(x) − softplus(0): zero at 0, positive beyond, C¹.
    This is the write-rate gate: how much of a gram is committed to the table."""
    return softplus(x) - math.log(2.0)


def decay_of(logit: float, A: float) -> float:
    """Mamba-2/GDN decay Ā = exp(A · softplus(logit+bias)), A = -exp(A_log) < 0.
    Returns retention factor in (0, 1]. (bias folded into logit here.)"""
    return math.exp(A * softplus(logit))


# ---------------------------------------------------------------------------
# 4. Certificates (each mirrors a Lean theorem; fail loud)
# ---------------------------------------------------------------------------
def _coprime(a: int, b: int) -> bool:
    return math.gcd(a, b) == 1


def cert_head_arithmetic() -> None:
    # Lean: headMods_pairwise_coprime / offsets_eq_scanl / headWindows_disjoint
    for a, b in itertools.combinations(HEAD_MODS, 2):
        assert _coprime(a, b), "moduli not pairwise coprime"
    offs = head_offsets(HEAD_MODS)
    assert offs[: len(_REAL_OFFS)] == _REAL_OFFS, "offsets ≠ scanl of mods"
    # scanl tiles EXACTLY (stronger than the Lean ≤ statement):
    assert all(offs[i] + HEAD_MODS[i] == offs[i + 1] for i in range(len(HEAD_MODS)))


_REAL_OFFS = [
    0, 20000003, 40000026, 60000059, 80000106, 100000165, 120000228,
    140000297, 160000374, 180000455, 200000548, 220000655, 240000802,
    260000955, 280001114, 300001275,
]


def cert_golden_vectors() -> None:
    """Lean §5 golden vectors (native_decide'd): the probe contract R4."""
    l = [5, 9, 13]
    assert window_at(2, l, 2) == [13, 9]
    assert window_at(3, l, 1) == [9, 5]
    assert gram_key(248320, 20000003, window_at(2, l, 2)) == (13 + 248320 * 9) % 20000003
    assert gram_key(248320, 20000081, window_at(3, l, 2)) == (
        13 + 248320 * 9 + 248320**2 * 5
    ) % 20000081


def cert_collision_regime() -> None:
    """Lean gramKey_inj: with m ≥ V^w the key is injective on same-length
    windows; the served regime (m ≪ V²) must collide — certify both sides."""
    V, w = 4, 2                       # toy alphabet
    m = V**w                          # collision-free boundary: 16 ≥ 16 ✓
    seen: dict[int, tuple] = {}
    windows = [list(p) for p in itertools.product(range(V), repeat=w)]
    for win in windows:
        k = gram_key(V, m, win)
        assert seen.setdefault(k, tuple(win)) == tuple(win), "expected injective"
    # served regime: order-2 space V² ≫ m ⇒ injectivity must FAIL (pigeonhole)
    assert VOCAB**2 > HEAD_MODS[0]
    rng = random.Random(1)
    found = False
    seen2: dict[int, tuple] = {}
    for _ in range(100_000):
        win = [rng.randrange(VOCAB), rng.randrange(VOCAB)]
        k = gram_key(VOCAB, HEAD_MODS[0], win)
        if k in seen2 and tuple(seen2[k]) != tuple(win):
            found = True
            break
        seen2[k] = tuple(win)
    assert found, "expected collisions in the served regime"


def cert_bag_channel() -> None:
    """writes_perm / selfPresence / noInterference (Lean)."""
    rng = random.Random(7)
    for _ in range(50):
        keys = [rng.randrange(1000) for _ in range(rng.randrange(0, 12))]
        a = DeltaTable.writes(keys)
        shuffled = keys[:]
        rng.shuffle(shuffled)
        assert a._counts == DeltaTable.writes(shuffled)._counts   # writes_perm
        if keys:
            k = rng.choice(keys)
            assert a.read(k) > 0                       # selfPresence
        outside = next(x for x in range(2000) if x not in set(keys))
        base = DeltaTable()
        base.write(outside)
        assert base.merge(a).read(outside) == base.read(outside)  # noInterference


def cert_eos_boundary() -> None:
    """Kernel rule (ngram_embedding.cuh): context never crosses EOS; EOS may
    itself be the current token (j == 0)."""
    toks = [5, 7, EOS, 11]
    assert window_at_eos(3, toks, 3, EOS) == [11]           # stops at EOS behind
    assert window_at_eos(3, toks, 2, EOS) == [EOS, 7, 5]    # j=0: EOS as current ok
    assert window_at_eos(2, toks, 1, EOS) == [7, 5]


def cert_r2_padding_finding() -> None:
    """Lean roadmap R2 finding, executable — three parts, sharpened by the
    DeepSeek-V4.1-Flash config (`engram_pad_token_id: 2`):
    (a) naive standalone-needle window membership has FALSE NEGATIVES;
    (b) a sentinel left-pad on both sides does NOT fix it (padded needle heads
        get PAD context; a mid-host occurrence has real left context — the
        windows differ).  Production's pad token serves the TRUE head only;
    (c) sound (though merely NECESSARY) test: anchored complete w-windows of
        the needle ⊆ complete w-windows of the host; sufficiency needs window
        CHAINING — the de Bruijn continuity test (Lean roadmap R3). A decoy
        witness proves the gap is real."""
    w = 3
    haystack = [11, 22, 33, 44, 55]

    # (a) false negative: needle occurs at offset 1 but its standalone
    #     truncated windows are absent from the host's truncated windows.
    needle = [22, 33]
    hs_keys = {tuple(window_at(w, haystack, i)) for i in range(len(haystack))}
    naive = {tuple(window_at(w, needle, i)) for i in range(len(needle))}
    assert naive - hs_keys, "expected naive false negative"

    # (b) sentinel padding both sides does NOT rescue set-inclusion:
    SENT = -1
    hp = [SENT] * (w - 1) + haystack
    npp = [SENT] * (w - 1) + needle
    hs2 = {tuple(window_at(w, hp, i)) for i in range(len(hp))}
    n2 = {tuple(window_at(w, npp, i)) for i in range(len(npp))}
    assert n2 - hs2, "padding alone must NOT certify: needle head sees PAD, host occurrence sees true left context"

    # (c) anchored complete-window test: sound necessary condition…
    needle3 = [22, 33, 44]
    host_full = {tuple(haystack[i - w + 1:i + 1]) for i in range(w - 1, len(haystack))}
    needle_full = {tuple(needle3[j - w + 1:j + 1]) for j in range(w - 1, len(needle3))}
    assert needle_full <= host_full and needle3 in _substrings(haystack, len(needle3))
    # …NOT sufficient: this decoy's windows all exist in the host, unchained.
    host2 = [9, 1, 2, 3, 8, 2, 3, 9]
    decoy = [1, 2, 3, 9]                       # windows (1,2,3),(2,3,9) both present
    hf2 = {tuple(host2[i - w + 1:i + 1]) for i in range(w - 1, len(host2))}
    df2 = {tuple(decoy[j - w + 1:j + 1]) for j in range(w - 1, len(decoy))}
    assert df2 <= hf2, "decoy windows must all be present"
    assert decoy not in _substrings(host2, len(decoy)), "decoy must NOT occur contiguously"
    #  → sufficiency needs chain continuity: Lean roadmap R3 (k-spectrum).


def _substrings(seq: list[int], k: int) -> list[list[int]]:
    return [seq[i:i + k] for i in range(len(seq) - k + 1)]


def cert_commutator_gates() -> None:
    """centered softplus gate + Mamba-2 decay sanity (0<Ā≤1, Ā(0)=e^{A·ln2}∈(0,1))."""
    assert abs(centered_softplus(0.0)) < 1e-15
    assert centered_softplus(3.0) > 0 and centered_softplus(-3.0) < centered_softplus(0.0) + 1e-9
    A = -math.exp(0.4)
    for logit in (-5.0, 0.0, 0.0, 2.0, 9.0):
        g = decay_of(logit, A)
        assert 0.0 < g <= 1.0


# ---------------------------------------------------------------------------
# V4.1-Flash profile constants (HF config.json, fetched this session, MIT)
# ---------------------------------------------------------------------------
V41 = {
    "V": 129_280, "EOS": 1, "PAD": 2,
    "engram_max_ngram_size": 4,        # orders {2,3,4}
    "engram_n_heads": 8,               # like qwen4exp
    "engram_vocab_size": 16_000_000,   # buckets per head (vs qwen4exp 20M)
    "engram_head_dim": 256,
    "engram_layer_ids": [1, 14],       # injection layers (qwen4exp: ple.layers [1])
    "engram_num_embeddings": [384_006_168, 384_016_682],
    "hc_mult": 4, "hc_sinkhorn_iters": 20,
    "scoring_func": "sqrtsoftplus",
}


def cert_v41_profile_consistency() -> None:
    """Config self-consistency of the Engram blueprint (the '196B conditional
    memory' claim): slots = orders×heads×table must match engram_num_embeddings
    up to a small special-token tail; params = layers×slots×head_dim ≈ 196B."""
    orders = V41["engram_max_ngram_size"] - 1            # grams 2..4 → 3
    slots = orders * V41["engram_n_heads"] * V41["engram_vocab_size"]
    assert abs(slots - V41["engram_num_embeddings"][0]) < 10_000, slots
    assert abs(V41["engram_num_embeddings"][1] - V41["engram_num_embeddings"][0]) < 20_000
    params = len(V41["engram_layer_ids"]) * slots * V41["engram_head_dim"]
    assert abs(params - 196.6e9) / 196.6e9 < 0.01, params
    # collision regime, same shape as the served model's check:
    assert V41["V"] ** 2 > V41["engram_vocab_size"]      # multi-head remains load-bearing
    assert V41["PAD"] == V41["EOS"] + 1                  # pad token is global pad (2)
    # NOTE (open, verify on tokenizer): is pad actually IN gram windows (R2
    # convention) or does the kernel truncate like the sglang one? config alone
    # cannot distinguish — check the MIT reference inference code.


def cert_sqrtsoftplus_router() -> None:
    """PRODUCTION commutator: DeepSeek-V4.1 config `scoring_func:
    "sqrtsoftplus"`; sglang layers/moe/hash_topk.py:43 defaults to it.
    The MoE router score is sqrt(softplus(logit)) — a softplus-family gate
    is ALREADY shipping as the expert-selection commutator."""
    f = lambda x: math.sqrt(softplus(x))
    assert abs(f(0.0) - math.sqrt(math.log(2.0))) < 1e-12   # uniform init scale
    xs = [-20.0, -1.0, 0.0, 1.0, 8.0, 40.0]
    assert all(f(a) < f(b) for a, b in zip(xs, xs[1:]))      # strictly increasing
    assert all(f(x) >= 0.0 for x in xs)
    assert abs(f(1e6) - math.sqrt(1e6)) < 1e-3               # → sqrt(x) growth


def _sinkhorn(a: list[list[float]], iters: int = 200) -> list[list[float]]:
    for _ in range(iters):
        a = [[x / sum(r) for x in r] for r in a]
        cs = [sum(r[j] for r in a) for j in range(len(a))]
        a = [[a[i][j] / cs[j] for j in range(len(a))] for i in range(len(a))]
    return a


def cert_sinkhorn_mixer() -> None:
    """mHC commutator: DeepSeek-V4.1 config hc_mult=4, hc_sinkhorn_iters=20
    (same fields as sglang configs/deepseek_v4.py:109; qwen4exp hc_count=4).
    Sinkhorn's limit is DOUBLY STOCHASTIC = a mixture of permutations
    (Birkhoff–von Neumann) — the commutative mixer over residual streams.
    Certify: row/col sums → 1, and permutation-equivariance of the result."""
    a = [[2.0, 1.0, 1.0], [1.0, 3.0, 1.0], [1.0, 1.0, 4.0]]
    s = _sinkhorn(a)
    tol = 1e-6
    assert all(abs(sum(r) - 1) < tol for r in s)
    assert all(abs(sum(s[i][j] for i in range(3)) - 1) < tol for j in range(3))
    p = (2, 0, 1)
    pa = [[a[p[i]][p[j]] for j in range(3)] for i in range(3)]
    sp = _sinkhorn(pa)
    assert all(abs(sp[i][j] - s[p[i]][p[j]]) < tol for i in range(3) for j in range(3))


# ---------------------------------------------------------------------------
# Reference semantics: deepseek-ai/Engram `engram_demo_v1.py` (Apache-2.0)
# ---------------------------------------------------------------------------
def _is_prime(n: int) -> bool:
    if n < 2:
        return False
    if n % 2 == 0:
        return n == 2
    d = 3
    while d * d <= n:
        if n % d == 0:
            return False
        d += 2
    return True


def _next_prime(start: int, seen: set) -> int:      # find_next_prime, demo L181
    c = start + 1
    while not (_is_prime(c) and c not in seen):
        c += 1
    return c


def _collect_heads(seen: set, start: int, heads: int) -> list[int]:
    ps = []
    for _ in range(heads):
        start = _next_prime(start, seen)
        seen.add(start)
        ps.append(start)
    return ps


def _layer_total(V: int, orders: int, heads: int, seen: set) -> int:
    total = 0
    for _ in range(orders):
        total += sum(_collect_heads(seen, V - 1, heads))
    return total


def ref_tok(tokens: list[int], i: int, k: int, pad: int) -> int:
    """shift_k with LEFT-PAD (the R2-resolving semantics): k > i ⇒ pad."""
    return tokens[i - k] if k <= i else pad


def ref_window(tokens: list[int], i: int, n: int, pad: int) -> list[int]:
    return [ref_tok(tokens, i, k, pad) for k in range(n)]


def ref_hash(tokens: list[int], i: int, n: int, mults: list[int],
             p: int, pad: int) -> int:
    """NgramHashMapping._get_ngram_hashes (demo L262): XOR-mix then prime mod."""
    mix = 0
    for k in range(n):
        mix ^= mults[k] * ref_tok(tokens, i, k, pad)
    return mix % p


def cert_reference_fold() -> None:
    """Cross-language tie to EngramReference.lean: pad-fill windows, XOR bag
    commutativity, locality (R1), head-vs-truncate divergence (R2)."""
    # interior agreement with the serving-kernel truncation:
    assert ref_window([5, 9, 13], 2, 3, 2) == window_at(3, [5, 9, 13], 2)
    # head divergence — the two conventions genuinely differ:
    assert ref_window([5, 9], 1, 3, 2) == [9, 5, 2]
    assert window_at(3, [5, 9], 1) == [9, 5]
    # XOR bag commutativity (lean `xor_swap`): folding order is irrelevant
    m = [8052911324071, 20109073645365, 23703573157769]   # served GGUF multipliers
    prods = [m[0] * 13, m[1] * 9, m[2] * 5]
    import functools
    import operator
    mix = functools.reduce(operator.xor, prods)
    assert mix == functools.reduce(operator.xor, prods[::-1])
    # locality (lean `refHash_congr_one_edit`): edit at q₀ moves hashes only
    # inside [q₀, q₀+n−1]:
    rng = random.Random(11)
    for _ in range(30):
        toks = [rng.randrange(5000) for _ in range(40)]
        q0, n = rng.randrange(5, 30), 3
        mults = [rng.randrange(1, 1 << 40) | 1 for _ in range(n)]
        p = 16_000_019
        toks2 = toks[:]
        toks2[q0] = rng.randrange(5000)
        assert toks2[q0] != toks[q0]
        for i in range(40):
            if not (q0 <= i <= q0 + n - 1):
                assert ref_hash(toks, i, n, mults, p, 2) == ref_hash(toks2, i, n, mults, p, 2), \
                    "locality violated outside the window"


def cert_v41_prime_reconstruction() -> None:
    """**Reconstruction**: the reference prime search (find_next_prime +
    globally-distinct seen_primes) at V4.1 parameters reproduces BOTH
    `engram_num_embeddings` EXACTLY — Lean twin `v41_table_recon`.
    Residues 6,168 / 16,682 = accumulated prime overshoots; layer 14's
    larger total = inherited seen-set."""
    seen: set = set()
    l1 = _layer_total(16_000_000, 3, 8, seen)      # orders{2,3,4} × 8 heads
    l14 = _layer_total(16_000_000, 3, 8, seen)
    assert (l1, l14) == (384_006_168, 384_016_682), (l1, l14)
    # CRT content-address bound: an int64 mix is uniquely determined by the
    # 8 prime residues of one (layer, order) — collision-free addressing:
    assert 2**63 < 16_000_003**8


def main() -> None:
    cert_head_arithmetic()
    cert_golden_vectors()
    cert_collision_regime()
    cert_bag_channel()
    cert_eos_boundary()
    cert_r2_padding_finding()
    cert_commutator_gates()
    cert_sqrtsoftplus_router()
    cert_sinkhorn_mixer()
    cert_v41_profile_consistency()
    cert_reference_fold()
    cert_v41_prime_reconstruction()
    print("ple_io: ALL CERTIFICATES PASS")
    print("  · head arithmetic (16 odd coprime moduli, exact tiling)")
    print("  · Lean golden vectors (probe contract R4)")
    print("  · collision-free regime (toy) + served-regime collisions (real)")
    print("  · bag channel: perm-invariance, self-presence, non-interference")
    print("  · R2: naive AND both-side-padded membership unsound; anchored")
    print("    windows sound-but-necessary (decoy witnessed → R3 chaining)")
    print("  · centered softplus write gate + Mamba-2 decay bounds")
    print("  · sqrtsoftplus production router (V4.1 / sglang hash_topk)")
    print("  · Sinkhorn mHC mixer: doubly stochastic + permutation-equivariant")
    print("  · V4.1-Flash Engram profile self-consistency (196B arithmetic)")
    print("  · reference fold: pad-fill windows, XOR bag, locality, R2 split")
    print("  · V4.1 engram_num_embeddings EXACT reconstruction (prime search)")


if __name__ == "__main__":
    main()
