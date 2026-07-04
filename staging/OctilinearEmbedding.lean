import Mathlib
import LaserCortex.staging.Algebra
import LaserCortex.staging.Tamari
import LaserCortex.staging.Friction

/-!
# Tube Map — Geometry of Trees in Cost Space

Coordinate embedding of Tamari trees into ℤ² via the KKT multiplier.

## Key definitions
- `kktMultiplier` — projection EMLTree → SplitOctonion (CD covector)
- `covectorProjection` — ℤ-linear projection to tropical coordinates
- `tubeCoord` — (x, y) coordinates in the tube

## Key theorems
- `tubeCoord_cd_diff` — tubeCoord depends on components, not CD step
- `tubeCoord_cd3_signature` — cd3_nonassociative_signature
- `tubeCoord_monotone` — monotonicity along contraction paths
-/
