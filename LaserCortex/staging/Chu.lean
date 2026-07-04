import Mathlib
import LaserCortex.staging.Algebra

/-!
# Chu Pairing — Duality on Split Algebras

The Chu pairing: a bilinear form on split octonions connecting
associative and non-associative sectors.

## Key definitions
- `splitQuatPairing` — ℤ-valued bilinear form SplitOctonion × SplitOctonion → ℤ
- `splitQuatPairing_nondegenerate` — the pairing is nondegenerate

## Key theorems
- `splitQuatPairing_nondegenerate` — nondegeneracy of the Chu pairing
- `splitQuatPairing_assoc_sector` — pairing behavior on associative sector (cdStep ≤ 2)
- `splitQuatPairing_nonassoc_sector` — pairing behavior on non-associative sector (cdStep ≥ 3)
-/
