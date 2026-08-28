# Chapter 9 — The reduced lattice

*Anchor F. "What survives if I blur?"*

## 9.1 Conventional grounding: reduced continuum models (draft)

- Equilibrium codes solve a *reduced continuum model*, not particle motion.
- Coarse-graining: many microstates → few macro-observables; slow variables
  survive, fast variables are integrated out.
- Limit shapes: as the system grows, the rescaled empirical measure of a
  combinatorial statistic converges to a deterministic shape.

## 9.2 The transit map: a verified many-to-one collapse (draft)

- `kktMultiplier cd t = (size, leftWeight, rightWeight, assocDefect)` as a
  Clifford number; `transitCoord` projects to ℤ²:
  `(size + assocDefect, leftWeight − rightWeight)`.
- **Verified collapse** (`scripts/metric_sweep.py` / hand-checkable): 5 → 5
  (size 3), 14 → 9, 42 → 19, 132 → 29 (size 6). Micro-states grow
  exponentially (Catalan), macro-states polynomially — the signature of a
  reduced model.

## 9.3 Slow versus fast [P for the key fact] (draft)

- `leftWeight` is a **strict descent** variable along every cover [P:
  `contracts_one_leftWeight_decreases`].
- `dcStep` is *not* strict (the lattice is not graded; T₃ = N₅; a left-context
  rotation can leave it unchanged) [P: the computation, §9.4].
- The reduced model is well-posed on `leftWeight` (the slow variable), not on
  `dcStep` alone: the transit map's y-coordinate is exactly
  `leftWeight − rightWeight`.

## 9.4 The non-gradedness, stated plainly [P] (draft)

- Size 3: five trees; `dcStep` values {0, 1, 1, 2, 2}; `dcStep(leftComb) = 2`
  but the longest cover chain has length 3. The Tamari lattice T₃ is the
  pentagon N₅ — **not graded**.
- Consequence: the cost is a *distance-to-closure* (a one-point potential),
  not a two-point metric; "minimality" is the maximal-potential universal
  property [P: `dcStep_is_maximal_potential`].

## 9.5 The limit shape [C] (draft)

- **[C]** As n → ∞, the empirical measure of transit coordinates (rescaled)
  converges to a continuous limit shape — the "phase diagram of composable
  logics". Unproven; the heavy machinery (concentration) is deferred.
- [Marginalia: this is the passage where the word "continuum" first becomes
  literal rather than aspirational; until §9.5 is proven, the honest name for
  the object in Chapter 10's comparison plan is "the reduced *lattice*
  model".]

## Sources

- `OctilinearEmbedding.lean` (transit map), `TamariMetric.lean` (C5),
  `foundations/Tamari.lean` (leftWeight).
- Notes 051 (sweep), 052 (non-gradedness caveat), 054 (anchor F),
  `scripts/presentation_data.py`.
