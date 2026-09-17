"""
toy/ple_bench.py — W1: production-form PLE-I/O cost model on one GPU.

Answers three grant-relevant questions with measured numbers:
 (A) Is the gram read path really O(1) per token in table size and L?
     (gather from fp16 head tables à la V4.1: heads × N_hash × 256)
 (B) What does the certified deterministic addressing buy when tables live
     in HOST RAM (pinned) instead of HBM — i.e. the LUMI-G config?
     (serial copy-through vs one-step-ahead pipelined prefetch)
 (C) The contrast: per-token attention cost as L grows (O(L) per token).

Device-agnostic plain torch; run small here, big on the rental.
"""
from __future__ import annotations

import argparse
import json
import time

import torch


def timeit(fn, warmup=2, iters=6):
    for _ in range(warmup):
        fn()
    if torch.cuda.is_available():
        torch.cuda.synchronize()
    t0 = time.perf_counter()
    for _ in range(iters):
        fn()
    if torch.cuda.is_available():
        torch.cuda.synchronize()
    return (time.perf_counter() - t0) / iters


def bench_gather(device, rows_list, heads, dim, batch, seq, dtype):
    """(A) HBM gather cost per token vs table row count."""
    out = {}
    n_tok = batch * seq
    for rows in rows_list:
        try:
            tables = [torch.randn(rows, dim, device=device, dtype=dtype)
                      for _ in range(heads)]
        except torch.cuda.OutOfMemoryError:
            out[rows] = "OOM"
            continue
        keys = [torch.randint(0, rows, (n_tok,), device=device,
                              dtype=torch.int64) for _ in range(heads)]

        def step():
            acc = tables[0].index_select(0, keys[0])
            for h in range(1, heads):
                acc = acc + tables[h].index_select(0, keys[h])
            return acc

        dt = timeit(step)
        gbs = n_tok * heads * dim * tables[0].element_size() / dt / 2**30
        out[rows] = {"us_per_token": round(dt / n_tok * 1e6, 3),
                     "effective_GBs": round(gbs, 1),
                     "table_GB": round(heads * rows * dim * 2 / 2**30, 2)}
        del tables, keys
        if device == "cuda":
            torch.cuda.empty_cache()
    return out


def bench_sort(device, ns):
    """(B1) write path: per-step radix sort of int64 keys (prefix counts)."""
    out = {}
    for n in ns:
        keys = torch.randint(0, 2**20, (n,), device=device, dtype=torch.int64)
        dt = timeit(lambda: torch.sort(keys, stable=True))
        out[n] = round(dt / n * 1e9, 1)          # ns/key
        del keys
    return out


def bench_host_table(device, rows, heads, dim, batch, seq):
    """(B2) pinned host table: serial vs pipelined deterministic prefetch."""
    if device != "cuda":
        return {}
    table = torch.randn(rows * heads, dim, dtype=torch.float16).pin_memory()
    n_tok = batch * seq
    key = torch.randint(0, rows * heads, (n_tok,), device="cpu",
                        dtype=torch.int64)
    key_next = torch.randint(0, rows * heads, (n_tok,), device="cpu",
                             dtype=torch.int64)

    def serial():                       # gather on CPU, blocking copy
        g = table.index_select(0, key.to(torch.int64))
        g.to(device, non_blocking=False)

    s = torch.cuda.Stream()

    def pipelined():
        # keys are deterministic: next step's gather can be issued one step
        # ahead on a side stream while the compute stream runs step t
        with torch.cuda.stream(s):
            g_next = table.index_select(0, key_next).to(device,
                                                        non_blocking=True)
        g = table.index_select(0, key).to(device, non_blocking=True)
        torch.cuda.current_stream().wait_stream(s)
        return g, g_next

    dt_ser = timeit(serial)
    dt_pipe = timeit(pipelined)
    del table
    return {"bytes": n_tok * dim * 2,
            "serial_us": round(dt_ser / n_tok * 1e6, 2),
            "pipelined_us": round(dt_pipe / n_tok * 1e6, 2)}


def bench_attention(device, Ls, heads, hd, batch, dtype):
    """(C) fp16 attention cost per token vs L (the thing the channel skips)."""
    out = {}
    q = lambda L: torch.randn(batch, heads, L, hd, device=device, dtype=dtype)
    for L in Ls:
        try:
            qk = q(L)
            dt = timeit(lambda: torch.matmul(qk, qk.transpose(-1, -2))
                        .softmax(-1), warmup=1, iters=3)
            out[L] = round(dt / (batch * L) * 1e3, 3)   # ms/token/layer
            del qk
            if device == "cuda":
                torch.cuda.empty_cache()
        except torch.cuda.OutOfMemoryError:
            out[L] = "OOM"
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--heads", type=int, default=8)
    ap.add_argument("--dim", type=int, default=256)
    ap.add_argument("--batch", type=int, default=64)
    ap.add_argument("--seq", type=int, default=8192)
    ap.add_argument("--rows", type=int, nargs="+",
                    default=[65536, 1048576, 4194304])
    ap.add_argument("--attn-L", type=int, nargs="+",
                    default=[2048, 4096, 8192, 16384, 32768])
    ap.add_argument("--sort-n", type=int, nargs="+",
                    default=[524288, 4194304])
    ap.add_argument("--out", default="ple_bench.json")
    args = ap.parse_args()
    dev = args.device if torch.cuda.is_available() else "cpu"
    dt = torch.float16
    res = {}
    res["gather_hbm_us_per_token"] = bench_gather(
        dev, args.rows, args.heads, args.dim, args.batch, args.seq, dt)
    res["sort_ns_per_key"] = bench_sort(dev, args.sort_n)
    res["host_table_pinned"] = bench_host_table(dev, 1048576, args.heads,
                                                args.dim, args.batch,
                                                min(args.seq, 2048))
    res["attention_ms_per_token_layer"] = bench_attention(
        dev, args.attn_L, 12, 64, 1, dt)
    print(json.dumps(res, indent=1))
    with open(args.out, "w") as fh:
        json.dump(res, fh, indent=1)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
