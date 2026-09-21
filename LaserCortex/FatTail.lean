import Mathlib.Data.Real.Basic

namespace FatTail

/-- A distribution has a Pareto tail with exponent alpha. /
def hasParetoTail (f : ℝ → ℝ) (α : ℝ) (C : ℝ) (x₀ : ℝ) : Prop :=
  ∀ x ≥ x₀, f x ≤ C * x ^ (-α)

/-- The Hill estimator computes the Pareto exponent. /
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

/-- Theorem: If the scale factors follow a Pareto tail with exponent α < 2,
    then the variance is infinite. /
theorem paretoTail_infiniteVariance {α : ℝ} (hα : 0 < α) (hα2 : α < 2)
    {f : ℝ → ℝ} {C x₀ : ℝ} (hf : hasParetoTail f α C x₀)
    (f_nonneg : ∀ x ≥ x₀, 0 ≤ f x) :
    ¬ (∫ x in Set.Ici x₀, (x ^ 2) * f x) < infinity := by
  sorry

/-- Corollary: If Hill alpha < 2, the scale-factor distribution has infinite variance. /
theorem hillAlpha_lt2_infiniteVariance {α : ℝ} (hα : 0 < α) (hα2 : α < 2) :
    hasParetoTail (fun x => x ^ (-α)) α 1 1 →
    ¬ (∫ x in Set.Ici 1, (x ^ 2) * x ^ (-α)) < infinity := by
  sorry

end FatTail

