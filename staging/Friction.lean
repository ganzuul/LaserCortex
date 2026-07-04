import Mathlib
import LaserCortex.staging.Algebra
import LaserCortex.staging.Tamari

/-!
# Friction Lagrangian — Cost Landscape

The cost landscape connecting Cayley-Dickson algebra to Tamari trees.

## Key definitions
- `assocDefect` — 0 for cdStep ≤ 2 (associative), strut_weight for cdStep ≥ 3
- `frictionDensity` — cost per Tamari step
- `layerCost` — total cost of a tree contraction
- `frictionLagrangian` — action functional over the cost landscape

## Key theorems
- `assocDefect_phase_change` — phase change at cdStep 2→3
- `frictionDensity_monotone` — frictionDensity is monotone with cdStep
- `heightMap_discontinuity` — discontinuity at the associative/non-associative boundary
- `frictionLagrangian_continuous` — continuity of the Lagrangian (research gap)
-/
