# Chapter 3 — The algebraic substrate: the Cayley–Dickson tower

*Where conventional physics grounds in ℝ³, this primer grounds in the CD
tower. This chapter is the tower itself.*

## 3.1 The tower

- Doubling: ℝ → ℂ → ℍ → 𝕆 → 𝕊, each step doubling dimension and losing one
  law: commutativity (first lost at ℍ), associativity (at 𝕆), alternativity
  (at 𝕊). **[std]**
- The split forms (split-quaternion, split-octonion) with indefinite norm;
  zero divisors appear. **[std]**
- **Why this structure.** We need a concrete algebra that can *lose*
  associativity without losing everything else — the split-octonions over the
  integers provide it. `SplitOctonion` is the 8-component type and
  `split_oct_mul` its Cayley–Dickson product. **[def]** Every Part II theorem
  unpacks to polynomial identities in those eight integer components, which is
  why the substrate earns its keep; `strut_weight_eq_four` is the first such
  identity. **[P]**

## 3.2 The associator and the defect functions

- **What failure looks like.** `associator_tensor a b c = (ab)c − a(bc)`
  measures the defect of associativity at a triple — zero when associativity
  holds, nonzero when it does not. **[def]** (`foundations/Algebra.lean`)
  In English: it is the vector by which the two bracketings disagree.
- **Compressing the defect to a scalar.** `assocDefect k` is 0 for k ≤ 2 and
  `strut_weight` for k ≥ 3 — a step function that says *when* the
  associator turns on. **[def]** (`Friction.lean`) It is the switch that
  Chapter 4's handedness will flip.
- **Pricing the flip.** `frictionDensity k = commDefect k + strut_weight ·
  assocDefect k` (`Friction.lean`) **[def]** is the per-flip weight, linear
  in `k` plus one strut. In English: the cost grows by one each rung, *plus*
  sixteen once the bracket can twist.

## 3.3 The critical point

- Γ₀..Γ₇ = 0, 1, 2, 19, 20, 21, 22, 23. **[V]** (computed from the definition;
  matches `scripts/logical_temperature.py`)
- The jump 2 → 19 at CD 3 is the *only* jump. **[P]** (`gamma_increment`,
  `gamma_only_jump_at_cd2_3`)
- CD 3 = split octonions: the associator turns on. **[def]** via `assocDefect`;
  the underlying alternativity is proven at CD 3 and below (Chapter 4). **[P]**
- CD 4 = sedenions: classically, alternativity fails there. **[std]** —
  **this is not in our formalization**: the build contains no Sedenion type, so
  "the polarization breaks at CD 4" (Chapter 5) is a claim about a model we
  have not yet built. Confirm: construct a Sedenion algebra and exhibit a
  triple violating the alternative laws; refute: the construction satisfies
  them (which would surprise the classical account). **[H]**
- The Landauer calibration (T = Γ·T_op·ln 2, unit ≈ 207.9 K; paraconsistency
  barrier ≈ 4159 K). **[def/P]** (`LogicalTemperature.lean`). *Level: analogy —*
  the temperature is a normalization convention (a rescaling of Γ), not an
  observed thermal quantity.

## 3.4 The CD homotopy and the antipode

- The doubling parameter (split/compact) as a homotopy of quadratic forms;
  the Chu pairing as the bridge (`foundations/Chu.lean`). **[std/def]**
- The antipode S as grade involution on the odd sector; the transit map's
  y-coordinate flips under it (Chapter 9). **[P-def]**
  (`foundations/Algebra.lean`, `OctilinearEmbedding.lean`).
  *Level: analogy —* "time-reversal" is a reading of grade involution, not a
  dynamical statement within the formalization.

## Sources

- `LaserCortex/foundations/Algebra.lean`, `foundations/Chu.lean`,
  `LaserCortex/Friction.lean`, `LaserCortex/LogicalTemperature.lean`.
- Notes 017, 023, 027–030, 045–048.
