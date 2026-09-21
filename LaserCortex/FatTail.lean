import Mathlib.Data.Real.Basic
import Mathlib.Analysis.SpecialFunctions.Pow.Real

namespace FatTail

/-- A distribution has a Pareto tail with exponent alpha if the tail probability
    P(X > x) ~ C * x^(-alpha) as x -> infinity. /
def hasParetoTail (f : ℝ → ℝ) (α : ℝ) (C : ℝ) (x₀ : ℝ) : Prop :=
  ∀ x ≥ x₀, f x ≤ C * x ^ (-α)

/-- The Hill estimator computes the Pareto exponent from the top k order statistics.
    For sorted data x_(1) >= x_(2) >= ... >= x_(n),
    alpha_hat = n / Σ_{i=1}^{n} log(x_(i)/x_(n+1)) /
def hillEstimator (x : List ℝ) (k : Nat) : Option ℝ :=
  let sorted := x.sort (· ≥ ·)
  if sorted.length ≤ k then none
  else
    let topK := sorted.take k
    let baseline := sorted.drop k |>.head?
    match baseline with
    | some b =>
      if b ≤ 0 then none
      else
        let sumLog := topK.foldl (fun acc xi => acc + Real.log (xi / b)) 0
        if sumLog ≤ 0 then none
        else some (k : ℝ) / sumLog
    | none => none

/-- Theorem: If the scale factors in the engram table follow a Pareto tail
    with exponent α < 2, then the variance is infinite. /
theorem paretoTail_infiniteVariance {α : ℝ} (hα : 0 < α) (hα2 : α < 2)
    {f : ℝ → ℝ} {C x₀ : ℝ} (hf : hasParetoTail f α C x₀)
    (f_nonneg : ∀ x ≥ x₀, 0 ≤ f x) :
    ¬ ∫ x in Set.Ici x₀, (x ^ 2) * f x < ∞ := by
  sorry

/-- Theorem: The Hill estimator is consistent for the Pareto exponent.
    As k -> infinity and k/n -> 0, alpha_hat -> alpha in probability. /
theorem hillEstimator_consistent {α : ℝ} (hα : α > 0) :
    ∀ ε > 0, ∃ K, ∀ k ≥ K,
    ∃ n₀, ∀ n ≥ n₀,
    P(|hillEstimator(x₁,...,xₙ) k - α| > ε) < ε := by
  sorry

/-- Corollary: If Hill alpha < 2, the scale-factor distribution has infinite variance. /
theorem hillAlpha_lt2_infiniteVariance {α : ℝ} (hα : 0 < α) (hα2 : α < 2) :
    hasParetoTail (fun x => x ^ (-α)) α 1 1 →
    ¬ ∫ x in Set.Ici 1, (x ^ 2) * x ^ (-α) < ∞ := by
  sorry

end FatTail
