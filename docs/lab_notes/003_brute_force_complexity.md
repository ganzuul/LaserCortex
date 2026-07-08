# 003: Brute Force Complexity — 3900X Bounds

## Date
2026-06-11

## Machine
- CPU: Ryzen 3900X (12 cores, 24 threads), ~3.8 GHz
- RAM: 24 GB
- Lean 4.31.0-rc2 VM (bytecode interpreter)

## Empirical Benchmarks (from `report n`)

| n | Catalan(n) | Time | Growth Factor |
|---|---|---|---|
| 12 | 208,012 | 102 s | — |
| 13 | 742,900 | 387 s | 3.8× |
| 14 | 2,674,440 | ~23 min (est.) | ~3.6× |
| 15 | 9,694,845 | ~1.4 h (est.) | ~3.6× |
| 16 | 35,357,670 | ~5 h (est.) | ~3.6× |
| 17 | 129,644,790 | ~19 h (est.) | ~3.7× |
| 18 | 477,638,700 | ~3 d (est.) | ~3.7× |

n=14 was killed after 10 min timeout, consistent with ~23 min estimate.
n=12–13 verified with wall-clock times.

## Algorithmic Complexity

### allTrees (current: `partial def`, NO memoization)
- `allTrees(n+1)` calls `allTrees(i)` and `allTrees(n-i)` for each `i` in `0..n`
- Without memoization, this gives T(n) = 3^n total recursive calls
- **O(3^n)** in call count, **O(C_n)** in output size (Catalan(n) ≈ O(4^n / n^{3/2}))

### report(n)
- Calls `allTrees n` once → O(3^n) work
- 14 logics × 3 passes (minCost, maxCost, rightCombIsMin) = 42 Φ evaluations per tree
- Each Φ is O(n) tree traversal
- Total: **O(14 · n · C_n)** in output work, but **O(3^n)** dominated by allTrees recursion

### Memory
- Each EMLTree: ~(2n+1) `Node`/`Leaf` objects, ~32 bytes each in Lean VM
- n=13: 743K trees × ~27 nodes = ~20M objects → ~640 MB
- n=14: 2.67M trees × ~29 nodes = ~77M objects → ~2.5 GB
- n=15: 9.7M trees × ~31 nodes = ~300M objects → ~9.6 GB
- n=16: 35.4M trees × ~33 nodes = ~1.2B objects → **~38 GB ⚠ (exceeds RAM)**

## Practical Bounds on 3900X / 24 GB

| n | Feasible | Barrier |
|---|---|---|
| ≤ 7 | Sub-second | — |
| 8–11 | Sub-second (Catalan ≤ 58K) | — |
| 12 | ~1.7 min | — |
| 13 | ~6.5 min | — |
| 14 | ~23 min (est.) | Time (sub-30 min) |
| 15 | ~1.4 h (est.) | Time |
| 16 | ~5 h (est.) | **Memory** (38 GB > 24 GB) |
| ≥ 17 | Impractical | Both time + memory |

**Practical limit: n ≈ 15** (9.7M trees, ~1.4 h, ~10 GB RAM).

## Max-Cost Formula (leftWeight=2 logics)

Paraconsistent / Temporal / Spacetime max cost at n = **2^n - 1**.

- n=10: 1023
- n=11: 2047
- n=12: 4095
- n=13: 8191

The maximizing tree is the maximally left-branching comb:
```
Node (Node (Node ... (Node Leaf Leaf) ... Leaf) Leaf) Leaf
```

## Key Insight
The `partial def` without memoization means `allTrees` does **O(3^n)** call work despite outputting only **O(C_n)** trees. With memoization (e.g. caching `allTrees(i)` results), the generation cost drops to **O(C_n)**, extending the feasible range by ~2–3 n. Still, the 24 GB RAM hard-wall at n=16 means n=15 is the practical limit for the current Lean VM.

## Recommendations

1. **Memoize `allTrees`** for immediate ~3–5× speedup (cuts 3^n → C_n)
2. **Move brute force to Python** for n ≥ 14 (NumPy iteration is 10–100× faster than Lean VM)
3. **If n ≥ 16 needed**: port to compiled language (Rust/C), use subset-sum style DP instead of tree enumeration, or sample random trees with MCMC
4. **Z3 threshold**: Catalan(15) = 9.7M and Catalan(16) = 35M — our original estimate of Z3 needed at n=15 was conservative; real bottleneck is memory before search complexity

## Files
- `LaserCortex/Candidates.lean`: current brute force implementation
- `infra/_cortex/_cost.py`, `_amm.py`: Python mirror — candidate for optimized brute force
