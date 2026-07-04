import Mathlib
import LaserCortex.staging.Algebra
import LaserCortex.staging.Tamari

/-!
# Composition Guard — Logic Composition

Type-theoretic composition guard for the QuantizedType factory.
Prevents invalid compositions across the associative/non-associative boundary.

## Key definitions
- `QuantizedType` — the composition type at a given cdStep
- `CompositionSpec` — specification of a valid composition
- `free_not_quantized` — Gödelian incompleteness is not quantized

## Key theorems
- `free_not_quantized` — Free Logic cannot be quantized (counterexample)
- `CompositionSpec_valid` — CompositionSpec enforces valid compositions
- `quantized_types_are_exactly_non_meta_logics` — characterization theorem
-/
