import LaserCortex.staging.Tamari
import LaserCortex.staging.Generation

/-
# Boundlessness (Staging Port)

Port of `Boundlessness.lean` using `Tamari.EMLTree` instead of
`EMLRegistry.EMLTree`.

## Key definitions

- `IdempotentResolution` — a step function that is idempotent
  (step ∘ step = step) and a limit that is its fixed point
- `rightCombResolution` — the canonical idempotent resolution for Tamari trees
- `VeryBigBox` — packaging of paradox resolutions
-/

-- ============================================================================
-- SECTION 1: IdempotentResolution
-- ============================================================================

/--
An idempotent resolution for a type `α` consists of a regularization
step and a limit such that:
- `step ∘ step = step`: applying the step twice is the same as once
  (the step is idempotent).
- `limit = step ∘ limit`: the limit is reached in one step from anywhere
  in its image; equivalently, `limit` is a fixed point of `step`.

This is the algebraic shape of every regularization in the framework:
contraction to normal form (right-comb is idempotent),
institutional closure (closure ∘ closure = closure), and the terminal
resolution of boundlessness itself.
-/
structure IdempotentResolution (α : Type) where
  step  : α → α
  idemp : step ∘ step = step
  limit : α → α
  factor : limit = step ∘ limit

-- ============================================================================
-- SECTION 2: rightCombResolution
-- ============================================================================

/-- Every tree's contraction to its right-comb normal form is idempotent. -/
def rightCombResolution : IdempotentResolution EMLTree :=
  { step := λ t => rightComb t.size
    idemp := by
      ext t
      simp [rightComb_size]
    limit := λ t => rightComb t.size
    factor := by
      ext t
      simp [rightComb_size]
  }

-- ============================================================================
-- SECTION 3: VeryBigBox
-- ============================================================================

/-- The Very Big Box packages four inhabited problem classes. -/
structure VeryBigBox where
  liar        : IdempotentResolution EMLTree
  sorites     : IdempotentResolution EMLTree
  grandfather : IdempotentResolution EMLTree
  russells    : IdempotentResolution EMLTree

/-- The canonical Very Big Box: each uses rightCombResolution. -/
def veryBigBox : VeryBigBox :=
  { liar        := rightCombResolution
    sorites     := rightCombResolution
    grandfather := rightCombResolution
    russells    := rightCombResolution
  }

-- ============================================================================
-- SECTION 4: Theorems
-- ============================================================================

/-- Meta-idempotence: step ∘ step = step for rightCombResolution. -/
theorem rightComb_meta_idemp :
    (rightCombResolution.step ∘ rightCombResolution.step) = rightCombResolution.step :=
  rightCombResolution.idemp

/-- Terminal idempotence: rightComb of rightComb is rightComb. -/
theorem rightComb_limit_idemp (t : EMLTree) :
    _root_.rightComb (_root_.rightComb t.size).size = _root_.rightComb t.size := by
  simp [rightComb_size]
