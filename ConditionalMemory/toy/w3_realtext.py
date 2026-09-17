"""
toy/w3_realtext.py — W3 / H2-baby: gram-channel membership on REAL text.

Streams: WikiText-103 (train split for train, test split for eval), GPT-2
tokenizer, 12..40-token fact sentences drawn from the VALIDATION split
(article-disjoint from stream text, so exact spans are absent by
construction). Three eval families:
  present   fact spliced into the stream; query = the same fact   -> 1
  absent    query = disjoint fact, never in stream                -> 0
  mutated   query = spliced fact with ONE random interior token
            swapped; lexical near-miss                            -> 0
The `mutated` family is the sharp test: the answer must be the MIN over
fully-interior windows — a single broken window says "not this sentence",
even though almost all other grams are present.

Channel/trunk semantics are imported from model.py (import-time Lean-twin
certificate self-check included) — this file cannot drift from the spec.
"""
from __future__ import annotations

import argparse
import json
import time

import torch
import torch.nn.functional as F

from model import PleLM   # triggers cert self-check

PAD, SEP, QMARK = 0, 1, 2


# ---------------------------------------------------------------------------
# corpora
# ---------------------------------------------------------------------------
def load_wikitext(which):
    from datasets import load_dataset
    from transformers import AutoTokenizer
    tk = AutoTokenizer.from_pretrained("gpt2")
    ds = load_dataset("Salesforce/wikitext", "wikitext-103-raw-v1")

    def flat(split):
        # stream rows in chunks: materializing the whole column or one 28M-
        # char string blew up the 30GB host once (pod OOM-killed gram arm).
        toks, buf = [], []
        for row in ds[split]:
            t = row["text"].strip()
            if not t:
                continue
            buf.append(t)
            if len(buf) >= 5000:
                toks.append(torch.tensor(
                    tk("\n".join(buf), add_special_tokens=False).input_ids,
                    dtype=torch.int32))
                buf = []
        if buf:
            toks.append(torch.tensor(
                tk("\n".join(buf), add_special_tokens=False).input_ids,
                dtype=torch.int32))
        return torch.cat(toks)

    stream = flat(which)
    facts = []
    for row in ds["validation"]:
        s = row["text"].strip()
        if len(s) > 60 and not s.startswith(" ="):
            ids = tk(s, add_special_tokens=False).input_ids
            if 12 <= len(ids) <= 40:
                facts.append(ids)
    del ds
    return stream, facts, tk.vocab_size


def load_localmd(root, k=400):
    """smoke-test corpus: real English from repo .md files, facts = long lines."""
    import glob
    import re
    from transformers import AutoTokenizer
    tk = AutoTokenizer.from_pretrained("gpt2")
    texts, cand_facts = [], []
    for f in glob.glob(f"{root}/**/*.md", recursive=True)[:k]:
        t = open(f, encoding="utf-8", errors="ignore").read()
        texts.append(t)
        for line in re.split(r"(?<=[.!?]) +", t):
            ids = tk(line.strip()).input_ids
            if 12 <= len(ids) <= 40:
                cand_facts.append(ids)
    joined = tk("\n".join(texts), return_tensors="pt")["input_ids"][0]
    mid = joined.shape[0] // 2
    return joined[:mid], cand_facts[::7], tk.vocab_size


# ---------------------------------------------------------------------------
# batcher
# ---------------------------------------------------------------------------
class RealTask:
    def __init__(self, stream_ids, facts, kmax, device):
        self.stream = stream_ids          # keep int32; cast per-batch
        self.device = device
        self.kmax = kmax
        n = len(facts)
        self.lens = torch.tensor([min(kmax, len(f)) for f in facts])
        Lmax = max(self.lens)
        self.padded = torch.full((n, Lmax), PAD, dtype=torch.int64)
        for i, f in enumerate(facts):
            self.padded[i, :self.lens[i]] = torch.tensor(f[:Lmax])
        self.padded = self.padded.to(device)
        self.lens = self.lens.to(device)

    def batch(self, B, L, family, gen):
        # stream slices
        st = torch.randint(0, self.stream.shape[0] - L - 1, (B,),
                           generator=gen)
        rows = st[:, None] + torch.arange(L)
        ids = self.stream[rows].to(torch.int64).to(self.device)
        fi = torch.randint(0, self.lens.shape[0], (B,), generator=gen)
        K = self.lens[fi]                                   # (B,)
        needle = self.padded[fi][:, :int(K.max())]          # (B, <=kmax)
        cols = torch.arange(L, device=self.device)
        if family == "mixed":            # per-sample coin: present/absent/mut
            fam = torch.randint(0, 3, (B,), generator=gen)
            present = (fam == 0).to(self.device)
            splice = (fam != 1).to(self.device)             # present or mut
            domut = (fam == 2).to(self.device)
        else:
            c = torch.full((B,), family == "present",
                           device=self.device)
            present = splice = c
            domut = torch.full((B,), family == "mutated", device=self.device)
        lab = present.long()
        if domut.any():                  # one interior token swap (label 0)
            width = max(1, needle.shape[1] - 4)
            j = (2 + (torch.rand(B, 1, generator=gen) * width).long()
                 ).to(self.device).clamp(max=needle.shape[1] - 3)
            swap = torch.randint(8, 50257, (B, 1), generator=gen) \
                .to(self.device)
            needle = torch.where(domut[:, None], needle.scatter(1, j, swap),
                                 needle)
        if splice.any():                 # splice needle into stream
            offs = torch.randint(0, max(1, L - int(K.max()) - 1), (B,),
                                 generator=gen).to(self.device)
            ins = (cols[None, :] >= offs[:, None]) & \
                  (cols[None, :] < offs[:, None] + K[:, None])
            nf = torch.zeros_like(ids)
            for k in range(needle.shape[1]):
                idx = (offs + k).clamp(max=L - 1)[:, None]
                nf.scatter_(1, idx, needle[:, k:k + 1])
            ids = torch.where(ins & splice[:, None], nf, ids)
        # tail: SEP + needle(padded to kmax) + QMARK ; span covers real tokens
        pad_needle = F.pad(needle, (0, self.kmax - needle.shape[1]),
                           value=PAD)
        tail = torch.cat([torch.full((B, 1), SEP, device=self.device),
                          pad_needle,
                          torch.full((B, 1), QMARK, device=self.device)], 1)
        ids = torch.cat([ids, tail], 1)
        spans = torch.zeros(B, 2, dtype=torch.long, device=self.device)
        spans[:, 0] = L + 1
        spans[:, 1] = L + 1 + K
        return ids, spans, lab


def evaluate(model, task, L, n, device):
    model.eval()
    gen = torch.Generator().manual_seed(1234)
    bs_eff = max(1, min(16, 2**25 // (L * L)))
    out = {}
    for fam in ("present", "absent", "mutated"):
        accs = []
        for _ in range(max(1, n // bs_eff)):
            ids, spans, lab = task.batch(bs_eff, L, fam, gen)
            with torch.no_grad():
                accs.append((model(ids, spans).argmax(-1) == lab)
                            .float().mean().item())
        out[fam] = round(sum(accs) / len(accs), 3)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", default="wikitext", choices=["wikitext", "localmd"])
    ap.add_argument("--root", default="/workspace")
    ap.add_argument("--steps", type=int, default=2000)
    ap.add_argument("--bs", type=int, default=16)
    ap.add_argument("--lr", type=float, default=3e-4)
    ap.add_argument("--d", type=int, default=512)
    ap.add_argument("--layers", type=int, default=6)
    ap.add_argument("--theads", type=int, default=8)
    ap.add_argument("--Lmin", type=int, default=512)
    ap.add_argument("--Lmax", type=int, default=2048)
    ap.add_argument("--kmax", type=int, default=40)
    ap.add_argument("--gram-heads", type=int, default=8)
    ap.add_argument("--gram-target", type=int, default=8388617)
    ap.add_argument("--eval-lengths", type=int, nargs="+",
                    default=[512, 2048, 4096])
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--out", default="results_w3_gram.json")
    ap.add_argument("--ablate", default="gram")
    args = ap.parse_args()
    dev = args.device if torch.cuda.is_available() else "cpu"

    t0 = time.time()
    stream, facts, vocab = (load_wikitext("train") if args.corpus == "wikitext"
                            else load_localmd(args.root))
    print(f"corpus {args.corpus}: stream {stream.shape[0]} tok, "
          f"{len(facts)} fact sentences, vocab {vocab} ({time.time()-t0:.0f}s)")
    torch.manual_seed(0)
    gen = torch.Generator().manual_seed(0)
    task = RealTask(stream, facts, args.kmax, dev)
    model = PleLM(vocab=vocab, d=args.d, layers=args.layers,
                  heads=args.theads, max_len=4200, ablate=args.ablate,
                  gram_heads=args.gram_heads,
                  gram_target=args.gram_target).to(dev)
    n_par = sum(p.numel() for p in model.parameters()) / 1e6
    print(f"arm={args.ablate} params={n_par:.0f}M")
    opt = torch.optim.AdamW(model.parameters(), lr=args.lr)
    fams = ["mixed"] * 3 + ["mixed"]     # per-sample coins every batch
    for step in range(args.steps):
        L = int(torch.randint(args.Lmin, args.Lmax + 1, (1,),
                              generator=gen).item())
        ids, spans, lab = task.batch(args.bs, L, "mixed", gen)
        logits = model(ids, spans)
        loss = F.cross_entropy(logits, lab)
        opt.zero_grad(); loss.backward(); opt.step()
        if step % max(1, args.steps // 6) == 0 or step == args.steps - 1:
            with torch.no_grad():
                acc = (logits.argmax(-1) == lab).float().mean().item()
            rate = (model.channel.commit_rate().mean().item()
                    if args.ablate != "kv" else float("nan"))
            print(f"[{args.ablate}] step {step:5d} loss {loss.item():.3f} "
                  f"acc {acc:.2f} commit {rate:+.3f}", flush=True)
    res = {}
    for L in args.eval_lengths:
        res[L] = evaluate(model, task, L, 96, dev)
        print(f"[{args.ablate}] L={L}: {res[L]}", flush=True)
    with open(args.out, "w") as fh:
        json.dump({"args": vars(args), "params_M": n_par,
                   "eval": res}, fh, indent=1)
    print(f"wrote {args.out} ({time.time()-t0:.0f}s total)")


if __name__ == "__main__":
    main()
