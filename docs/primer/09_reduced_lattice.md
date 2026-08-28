# Chapter 9 — The reduced lattice

*Anchor F. "What survives if I blur?"*

## 9.1 Conventional grounding: reduced continuum models (draft)

- Equilibrium codes solve a *reduced continuum model*, not particle motion.
- Coarse-graining: many microstates → few macro-observables; slow variables
  survive, fast variables are integrated out.
- Limit shapes: as the system grows, the rescaled empirical measure of a
  combinatorial statistic converges to a deterministic shape.

## 9.2 The transit map: a verified many-to-one collapse

- `kktMultiplier cd t = (size, leftWeight, rightWeight, assocDefect)` as a
  Clifford number; `transitCoord` projects to ℤ²:
  `(size + assocDefect, leftWeight − rightWeight)`. **[def]**
  (`OctilinearEmbedding.lean`)
- **Verified collapse** (`scripts/metric_sweep.py` / hand-checkable): 5 → 5
  (size 3), 14 → 9, 42 → 19, 132 → 29 (size 6). **[V]**
- Growth rates: micro-states are Catalan (exponential, ~4ⁿ/n^{3/2}
  **[std]**); macro-states are polynomially bounded — coordinates lie in
  `{0..n} × [−T_n, T_n]` with `T_n = n(n+1)/2`, so at most O(n³) cells
  **[V/P easy]**. The signature of a reduced model: exponential → cubic.
  **[H, the reading]** that this is *the* reduced lattice (not an
  artifact of coordinate choice): confirm if a coarser compatible observable
  (Chapter 11, item 3) separates strictly fewer trees; refute if some other
  observable separates more while remaining path-compatible.

## 9.3 Slow versus fast

- `leftWeight` is a **strict descent** variable along every cover **[P]**
  (`contracts_one_leftWeight_decreases`, `foundations/Tamari.lean`).
- `dcStep` is *not* strict descent: the cover
  `((ab)c)d → (a(bc))d` (a left-context rotation) has
  `dcStep = 2` on both sides **[V]** — the census of §9.4 and the worked
  example in `TamariMetric.lean`'s header note. (Not yet packaged as a
  counterexample theorem; Chapter 11.)
- The reduced model is well-posed on `leftWeight` (the slow variable), not on
  `dcStep` alone: the transit map's y-coordinate is exactly
  `leftWeight − rightWeight`.

## 9.4 The non-gradedness, stated plainly

- Size 3: five trees; `dcStep` values {0, 1, 1, 2, 2}; `dcStep(leftComb) = 2`
  but the longest cover chain has length 3 **[V]** (both computed by
  `scripts/metric_sweep.py`-style enumeration; the cover set itself is the
  definition of `contracts_one`). The Tamari lattice T₃ is the
  pentagon N₅ — **not graded** **[V/std]**.
- Consequence: the cost is a *distance-to-closure* (a one-point potential),
  not a two-point metric; "minimality" is the maximal-potential universal
  property **[P]** (`dcStep_is_maximal_potential`).

## 9.5 The limit shape **[C]**

- **[C]** As n → ∞, the empirical measure of transit coordinates (rescaled)
  converges to a continuous limit shape — the "phase diagram of composable
  logics". Unproven; the heavy machinery (concentration) is deferred.
  Confirm: a weak-convergence theorem for the rescaled measures (tightness +
  identification of the limit); refute: the rescaled measures fail to be
  Cauchy (e.g. oscillate with n).
- [Marginalia: this is the passage where the word "continuum" first becomes
  literal rather than aspirational; until §9.5 is proven, the honest name for
  the object in Chapter 10's comparison plan is "the reduced *lattice*
  model".]

## Sources

- `OctilinearEmbedding.lean` (transit map), `TamariMetric.lean` (C5),
  `foundations/Tamari.lean` (leftWeight).
- Notes 051 (sweep), 052 (non-gradedness caveat), 054 (anchor F),
  `scripts/presentation_data.py`.
