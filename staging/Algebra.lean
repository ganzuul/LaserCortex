import Mathlib

/-!
# Cayley-Dickson Algebra with Signature (4,4)

Split-octonion algebra over ℤ with signature (4,4):
- Positive square: e₀², ..., e₃² = +1
- Negative square: e₄², ..., e₇² = -1
- Strut weight: strut_weight = 4

## Key definitions
- `SplitOctonion` — the split-octonion algebra over ℤ
- `Q44` — the quadratic form of signature (4,4)
- `ω` — the Cayley-Dickson element (e₄), with ω² = +1
- `antipode` — S(x) = +x for first 4 basis elements, -x for last 4

## Key theorems
- `ω_sq` : ω² = +1
- `antipode_mul_false` : S(xy) ≠ S(y)S(x) in general
- `strut_weight_eq_four` : the norm signature is (4,4)
- `Q44_nondegenerate` : Q44 is nondegenerate
-/
