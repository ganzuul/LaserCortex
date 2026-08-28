# Chapter 3 — The algebraic substrate: the Cayley–Dickson tower

*Where conventional physics grounds in ℝ³, this primer grounds in the CD
tower. This chapter is the tower itself.*

## 3.1 The tower (draft)

- Doubling: ℝ → ℂ → ℍ → 𝕆 → 𝕊, each step doubling dimension and losing one
  law: commutativity (ℍ), associativity (𝕆), alternativity (𝕊).
- The split forms (split-quaternion, split-octonion) with indefinite norm;
  zero divisors appear.
- `SplitOctonion` over ℤ: the 8-component structure and the Cayley–Dickson
  product (`split_oct_mul`) — the substrate of every Part II computation.
  [P: the multiplication table is the definition; `strut_weight_eq_four` is
  the first theorem it yields.]

## 3.2 The associator and the defect functions (draft)

- `associator_tensor a b c = (ab)c − a(bc)`. [P: defined]
- `assocDefect k = 0` for k ≤ 2, `strut_weight` for k ≥ 3: the associator's
  onset as a step function.
- `frictionDensity k = commDefect k + strut_weight · assocDefect k`
  (`Friction.lean`): the per-flip weight, linear plus one strut.

## 3.3 The critical point (draft)

- Γ₀..Γ₇ = 0, 1, 2, 19, 20, 21, 22, 23: the single jump 2 → 19 at CD 3.
  [P: `gamma_increment`, `gamma_only_jump_at_cd2_3`.]
- CD 3 = split octonions = associator turns on. CD 4 = sedenions =
  alternativity turns off (Chapter 5).
- The Landauer calibration (T = Γ·T_op·ln 2, unit 207.9 K; paraconsistency
  barrier 4159 K). [P: `LogicalTemperature.lean`.]

## 3.4 The CD homotopy and the antipode (draft)

- The doubling parameter (split/compact) as a homotopy of quadratic forms;
  the Chu pairing as the bridge (`foundations/Chu.lean`).
- The antipode S as grade involution / time-reversal on the odd sector; the
  transit map's y-coordinate flips under it (Chapter 9).

## Sources

- `LaserCortex/foundations/Algebra.lean`, `foundations/Chu.lean`,
  `LaserCortex/Friction.lean`, `LaserCortex/LogicalTemperature.lean`.
- Notes 017, 023, 027–030, 045–048.
