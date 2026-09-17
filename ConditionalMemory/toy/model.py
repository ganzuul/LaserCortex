"""
toy/model.py — PLE-I/O mechanism demo (SPEC §5 item 2): the two NEW components.

Frozen gram table + [NEW] test-time delta-writer (bag commits; certified
commutativity) + [NEW] centered-softplus commit gate (review §4 fix; init 0 ⇒
channel starts CLOSED) on a tiny transformer trunk — vs pure-KV ablations.

Semantics are PINNED, not re-invented: prime moduli via the reference
`find_next_prime` (ple_io), the fold is the reference XOR-mix (Lean `refHash`),
windows are LEFT-PAD (R2 resolution), tables are coprime ⇒ CRT-addressable.
An import-time self-check re-runs the executable-spec certificates, so this
module cannot silently drift from the Lean certs.

Task "gram-membership": a random token stream with an optional inserted
needle span; a query span at the end; predict whether the query span was in
the stream. The delta channel answers via causal prefix counts of the span's
grams (min over positions): cost per token is CONSTANT (one key write/read per
(order,head), independent of stream length L). The KV trunk must instead
search L positions — our claim, length-invariance of accuracy at flat cost.
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import ple_io  # noqa: E402  — the executable spec (Lean-twin semantics)

import torch  # noqa: E402
import torch.nn as nn  # noqa: E402
import torch.nn.functional as F  # noqa: E402

# import-time self-check: fail loudly if the certified fold is broken
ple_io.cert_golden_vectors()
ple_io.cert_reference_fold()
ple_io.cert_v41_prime_reconstruction()

PAD, SEP, QMARK = 0, 1, 2   # special ids; content ids >= 8 (toy pad-fill windows)


# ---------------------------------------------------------------------------
# certified fold primitives, batched
# ---------------------------------------------------------------------------
def head_primes(target: int, orders: int, heads: int) -> list[list[int]]:
    """Per-(order, head) prime moduli via reference find_next_prime, globally
    distinct ⇒ pairwise coprime ⇒ CRT content addressing (SPEC §2.3)."""
    seen: set[int] = set()
    return [ple_io._collect_heads(seen, target - 1, heads)
            for _ in range(orders)]


def odd_multipliers(n: int) -> list[int]:
    """Reference-style odd position multipliers (served GGUF values shifted)."""
    base = [8052911324071, 20109073645365, 23703573157769]
    return [base[i % 3] + 2 * (i // 3) for i in range(n)]


def window_keys(ids: torch.Tensor, order: int, mults: list[int]) -> torch.Tensor:
    """XOR-mix over distance-k shifted tokens, LEFT-PAD (Lean `tokAt`).
    ids (B, L) int64 → mix (B, L) int64."""
    mix = torch.zeros_like(ids)
    for k in range(order):
        tok = ids if k == 0 else F.pad(ids, (k, 0), value=PAD)[:, : ids.shape[1]]
        mix = mix ^ (tok * mults[k])
    return mix


def prefix_counts(keys: torch.Tensor) -> torch.Tensor:
    """counts[b, i] = occurrences of keys[b, i] within keys[b, 0..i]
    (causal bag read). Vectorized across B via one stable sort on
    (batch, key)-combined codes."""
    B, L = keys.shape
    dev = keys.device
    comb = keys * B + torch.arange(B, device=dev).unsqueeze(1)  # unique group code
    flat = comb.reshape(-1)
    order = torch.argsort(flat, stable=True)                    # ties: original order
    sk = flat[order]
    n = sk.numel()
    idx = torch.arange(n, device=dev)
    new = torch.cat([torch.ones(1, dtype=torch.bool, device=dev), sk[1:] != sk[:-1]])
    gid = new.long().cumsum(0) - 1
    firsts = idx[new]
    grp_first = torch.repeat_interleave(firsts, torch.bincount(gid, minlength=gid.max() + 1))
    cnt_sorted = idx - grp_first + 1
    out = torch.empty(n, dtype=torch.long, device=dev).scatter_(0, order, cnt_sorted)
    return out.reshape(B, L)


# ---------------------------------------------------------------------------
# the two NEW components
# ---------------------------------------------------------------------------
class GramChannel(nn.Module):
    """delta-bag writer + centered-softplus commit rate over prime-bucketed
    XOR-fold keys. `membership_features` = per-(order,head) MIN of causal
    prefix counts over the query span — 'every gram of the span was written'."""

    def __init__(self, orders=(2, 3), heads=4, prime_target=65536, d_head=8):
        super().__init__()
        self.orders, self.heads = list(orders), heads
        self.primes = head_primes(prime_target, len(self.orders), heads)
        self.mults = odd_multipliers(max(self.orders))
        self.n_feat = len(self.orders) * self.heads
        # [NEW] centered softplus commit rate: init 0 ⇒ channel starts CLOSED
        self.logit_rate = nn.Parameter(torch.zeros(self.n_feat))
        self.dirs = nn.Parameter(torch.randn(self.n_feat, d_head) * 0.02)
        self.d_head = d_head
        self.d_out = 4 * d_head
        self.out_proj = nn.Linear(self.n_feat * d_head, self.d_out)

    def commit_rate(self) -> torch.Tensor:
        return F.softplus(self.logit_rate) - math.log(2.0)  # zero at init (§4 fix)

    def membership_features(self, ids: torch.Tensor, spans: torch.Tensor) -> torch.Tensor:
        """(B, n_feat) float: MIN over the span's fully-interior windows of the
        causal prefix count (Lean tokAt/refHash semantics, left-pad R2
        convention; boundary-crossing windows skipped via +order-1 offset).
        present ⇒ ≥ 2 (needle + self); absent ⇒ 1 (self only; collisions rare
        on coprime prime buckets)."""
        B, L = ids.shape
        outs = []
        for oi, order in enumerate(self.orders):
            mix = window_keys(ids, order, self.mults)
            for hi in range(self.heads):
                keys = mix % self.primes[oi][hi]
                cnt = prefix_counts(keys).float()          # (B, L)
                s = spans[:, 0] + (order - 1)              # fully-inside windows
                e = spans[:, 1].clamp(1, L)
                mins = torch.stack([cnt[b, int(s[b]):int(e[b])].min()
                                    for b in range(B)])
                outs.append(mins)
        return torch.stack(outs, dim=1)                    # (B, n_feat)


class PleLM(nn.Module):
    """tiny trunk + gram channel. ablate ∈ {'kv', 'gram', 'gram_closed'}:
    KV-only; gram active; dead-channel capacity control (rate forced 0)."""

    def __init__(self, vocab=4096, d=128, layers=2, heads=4, max_len=4200,
                 ablate="gram"):
        super().__init__()
        assert ablate in ("kv", "gram", "gram_closed")
        self.ablate = ablate
        self.tok = nn.Embedding(vocab, d)
        self.pos = nn.Embedding(max_len, d)
        self.channel = GramChannel()
        self.chan_proj = nn.Linear(self.channel.d_out, d)
        blk = nn.TransformerEncoderLayer(d, heads, 4 * d, batch_first=True,
                                         norm_first=True)
        self.trunk = nn.TransformerEncoder(blk, layers)
        self.head = nn.Linear(d, 2)

    def forward(self, ids, spans):
        B, L = ids.shape
        pos = torch.arange(L, device=ids.device).unsqueeze(0).expand(B, L)
        x = self.tok(ids) + self.pos(pos)
        if self.ablate in ("gram", "gram_closed"):
            f = self.channel.membership_features(ids, spans)
            # centered softplus rate, NO clamp: init 0 (closed) yet gradient
            # flows (d/draw softplus = sigmoid(0) = 0.5); negative rates simply
            # invert the learned direction — commitment stays fully learnable.
            rate = (torch.zeros_like(self.channel.commit_rate())
                    if self.ablate == "gram_closed"
                    else self.channel.commit_rate())
            v = self.channel.dirs * (torch.log1p(f) * rate).unsqueeze(-1)
            h = self.chan_proj(self.channel.out_proj(v.reshape(B, -1)))  # (B, d)
            x = x.clone()
            x[:, -1] = x[:, -1] + h                        # inject at query pos
        z = self.trunk(x)
        return self.head(z[:, -1])                         # logits at final pos


# ---------------------------------------------------------------------------
# task: gram-membership
# ---------------------------------------------------------------------------
def make_batch(B, L, K, vocab, gen, device):
    """stream of L random ids (>=8), optional needle inserted at a random
    offset; then SEP, query span (needle or fresh), QMARK at the end.
    label 1 iff query span == inserted needle."""
    stream = torch.randint(8, vocab, (B, L), generator=gen).to(device)
    needle = torch.randint(8, vocab, (B, K), generator=gen).to(device)
    present = (torch.rand(B, generator=gen) > 0.5).to(device)
    offs = torch.randint(0, L - K, (B,), generator=gen).to(device)
    cols = torch.arange(K, device=device).unsqueeze(0).expand(B, K)
    insert = offs[:, None] + cols                       # needle start positions
    ins = torch.zeros_like(stream, dtype=torch.bool).scatter(1, insert, True)
    repl = torch.zeros_like(stream).scatter(1, insert, needle)
    stream = torch.where(present[:, None] & ins, repl, stream)
    fresh = torch.randint(8, vocab, (B, K), generator=gen).to(device)
    query = torch.where(present[:, None], needle, fresh)
    tail = torch.cat([torch.full((B, 1), SEP, device=device), query,
                      torch.full((B, 1), QMARK, device=device)], dim=1)
    ids = torch.cat([stream, tail], dim=1)                 # (B, L+K+2)
    spans = torch.full((B, 2), 0, device=device)
    spans[:, 0] = L + 1
    spans[:, 1] = L + 1 + K
    labels = present.long()
    return ids, spans, labels
