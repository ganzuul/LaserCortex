"""
toy/train.py — stage-1 mechanism run (ConditionalMemory/EXPERIMENTS.md).

Trains three ablations of the same tiny trunk:
  kv          — attention-only baseline (must search L for membership)
  gram_closed — gram channel present but commit rate pinned 0 (capacity control)
  gram        — the PLE-I/O channel: delta bag + centered-softplus commit gate
Then evaluates membership accuracy across stream lengths L (train at small L,
eval extrapolated): the claim is FLAT accuracy at CONSTANT per-token cost for
the gram arm, degradation for kv as L exceeds what attention can search.
"""
from __future__ import annotations

import argparse
import json
import time

import torch
import torch.nn.functional as F

from model import PleLM, make_batch


def evaluate(model, lengths, bs, K, vocab, device, steps=8):
    model.eval()  # otherwise trunk dropout (p=0.1) is ACTIVE during eval
    gen = torch.Generator(device="cpu").manual_seed(999)
    out = {}
    for L in lengths:
        accs = []
        bs_eff = max(1, min(bs, 2**25 // (L * L)))   # cap fp32 attention
        for _ in range(steps):
            ids, spans, labels = make_batch(bs_eff, L, K, vocab, gen, device)
            with torch.no_grad():
                logits = model(ids, spans)
            accs.append((logits.argmax(-1) == labels).float().mean().item())
        out[L] = sum(accs) / len(accs)
    return out


def train_one(ablate, args, device):
    torch.manual_seed(args.seed)
    gen = torch.Generator().manual_seed(args.seed)
    model = PleLM(vocab=args.vocab, d=args.d, layers=args.layers,
                  heads=args.theads, max_len=args.max_len, ablate=ablate,
                  gram_heads=args.gram_heads,
                  gram_target=args.gram_target).to(device)
    opt = torch.optim.AdamW(model.parameters(), lr=args.lr)
    t0 = time.time()
    for step in range(args.steps):
        L = int(torch.randint(args.Lmin, args.Lmax + 1, (1,),
                              generator=gen).item())
        ids, spans, labels = make_batch(args.bs, L, args.K, args.vocab,
                                        gen, device)
        logits = model(ids, spans)
        loss = F.cross_entropy(logits, labels)
        opt.zero_grad()
        loss.backward()
        opt.step()
        if step % max(1, args.steps // 5) == 0 or step == args.steps - 1:
            with torch.no_grad():
                acc = (logits.argmax(-1) == labels).float().mean().item()
            rate = (model.channel.commit_rate().mean().item()
                    if ablate != "kv" else float("nan"))
            print(f"[{ablate}] step {step:5d} loss {loss.item():.3f} "
                  f"acc {acc:.2f} commit_rate {rate:.3f}")
    evals = evaluate(model, args.eval_lengths, args.eval_bs, args.K,
                     args.vocab, device)
    print(f"[{ablate}] eval acc by L: " +
          "  ".join(f"L={k}:{v:.2f}" for k, v in evals.items()) +
          f"  ({time.time() - t0:.0f}s)")
    return {"train_loss": loss.item(), "eval_acc_by_L": evals}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", type=int, default=1500)
    ap.add_argument("--bs", type=int, default=64)
    ap.add_argument("--lr", type=float, default=3e-4)
    ap.add_argument("--d", type=int, default=128)
    ap.add_argument("--layers", type=int, default=2)
    ap.add_argument("--vocab", type=int, default=4096)
    ap.add_argument("--K", type=int, default=8, help="needle/span length")
    ap.add_argument("--Lmin", type=int, default=48)
    ap.add_argument("--Lmax", type=int, default=128, help="train stream max")
    ap.add_argument("--max_len", type=int, default=4200)
    ap.add_argument("--theads", type=int, default=4, help="trunk attention heads")
    ap.add_argument("--gram-heads", type=int, default=4)
    ap.add_argument("--gram-target", type=int, default=65536,
                    help="prime table modulus target (~1e6 for V4.1-scale keys)")
    ap.add_argument("--eval-lengths", type=int, nargs="+",
                    default=[128, 512, 1024, 2048])
    ap.add_argument("--eval-bs", type=int, default=16)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--ablations", nargs="+",
                    default=["kv", "gram_closed", "gram"])
    ap.add_argument("--device", default="auto")
    ap.add_argument("--out", default="results_stage1.json")
    args = ap.parse_args()
    device = ("cuda" if torch.cuda.is_available() else "cpu") \
        if args.device == "auto" else args.device
    print(f"device: {device}")

    results = {}
    for ablate in args.ablations:
        results[ablate] = train_one(ablate, args, device)
    with open(args.out, "w") as fh:
        json.dump({"args": vars(args), "results": results}, fh, indent=1)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
