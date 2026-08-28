# Chapter 3 — The algebraic substrate: the Cayley–Dickson tower

*Where conventional physics grounds in ℝ³, this primer grounds in the CD
tower. This chapter is the tower itself.*

## 3.1 The tower

- Doubling: ℝ → ℂ → ℍ → 𝕆 → 𝕊, each step doubling dimension and losing one
  law: commutativity (first lost at ℍ), associativity (at 𝕆), alternativity
  (at 𝕊). **[std]**
- The split forms (split-quaternion, split-octonion) with indefinite norm;
  zero divisors appear. **[std]**
- `SplitOctonion` over ℤ: the 8-component structure and the Cayley–Dickson
  product (`split_oct_mul`) — the substrate of every Part II computation.
  **[def]**; `strut_weight_eq_four` is the first theorem it yields. **[P]**

## 3.2 The associator and the defect functions

- `associator_tensor a b c = (ab)c − a(bc)`. **[def]** (`foundations/Algebra.lean`)
- `assocDefect k = 0` for k ≤ 2, `strut_weight` for k ≥ 3: the associator's
  onset as a step function. **[def]** (`Friction.lean`)
- `frictionDensity k = commDefect k + strut_weight · assocDefect k`
  (`Friction.lean`): the per-flip weight, linear plus one strut. **[def]**

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
