import Mathlib.Data.Real.Basic
import Mathlib.Data.Complex.Basic
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Ring
import Mathlib.Tactic.FieldSimp
import Mathlib.Analysis.Real.Sqrt

-- We can use ℝ and ℂ from mathlib
example : (0 : ℝ) < 1 := by norm_num

-- Complex.normSq is defined as re*re + im*im
example (z : ℂ) : Complex.normSq z = z.re * z.re + z.im * z.im :=
  Complex.normSq_apply z

-- The Born rule: probability = normSq(amplitude)
def born_probability (amplitude : ℂ) : ℝ := Complex.normSq amplitude

-- Born probability is non-negative (directly from normSq definition)
example (z : ℂ) : born_probability z ≥ 0 := by
  unfold born_probability
  rw [Complex.normSq_apply]
  apply add_nonneg
  · exact mul_self_nonneg z.re
  · exact mul_self_nonneg z.im

-- Born rule total probability = 1 for normalized amplitudes
example (z : ℂ) (h : Complex.normSq z = 1) : born_probability z = 1 := by
  unfold born_probability
  exact h

-- Real.sqrt of normSq = magnitude
example (z : ℂ) : Real.sqrt (Complex.normSq z) = Real.sqrt (z.re * z.re + z.im * z.im) := by
  rw [Complex.normSq_apply]
