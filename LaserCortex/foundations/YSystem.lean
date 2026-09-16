import Mathlib

/-!
# The A₂ Y-system, period-5 closure, and the log-domain (pentagonator) form

Machine-checked companion to the numerical results in
`ftq-recipe/docs/2026-09-16-pentagonator-softmax-associator-softplus-commutator.md`
(§3 E2, T2).

The **multiplicative Y-map** on pairs,

    T (X, Y) = (Y, (1 + Y) / X)

is the A₂ Zamolodchikov recurrence `Y_{t+1} Y_{t−1} = 1 + Y_t`. It is **exactly
5-periodic** (`T_period5`).

The **centered log-domain (pentagonator) map**, with `sp y = log (1 + exp y)`
(softplus),

    S_β (a, b) = (b, sp(β·b)/β − a)

is the Y-system written in variables `Y = exp(β·x)`: conjugate to `T` through the
pair map `E_β = (exp(β·), exp(β·))`. Hence `S_β` is 5-periodic for **every** β ≠ 0
and **every** real seed (`S_beta_period5`) — the β-invariance observed numerically,
now a theorem. The pentagon holds identically through the whole max↔mean
interpolation; there is no β where it bends. (The tropical limit map
`x ↦ max(0, x) − x_prev` is piecewise; numerically 5-periodic, not formalized.)

By contrast the **draft-literal map** `D (a, b) = (b, b + sp a)` — the
diffusion-router draft's `y' = y + log(1+eˣ)` read as a state update — is **not**
5-periodic at the seed (1,1) (`draft_no_period5`): the second component always
strictly exceeds the first; numerically the orbit diverges at the golden ratio.

## Results
- `T_period5`        : multiplicative closure, positive seeds (`field_simp` + `ring`).
- `conj_T_S`         : `E_β` conjugates `S_β` to `T`.
- `S_beta_period5`   : main theorem — all β ≠ 0, all real seeds.
- `draft_no_period5` : non-closure witness for the draft-literal form.

## Noncommutative coefficients (numerical, not formalized here)
Transporting `T` to quaternion seeds (right division) **fails to close**: residuals
`|x5−X|, |x6−Y| = O(1–4)` on random seeds. Quaternions are associative (hence alternative),
so Zamolodchikov periodicity requires **commutativity**, not alternativity — Artin's theorem
does not rescue it (the reduction reorders factors). See the review note §3 E2 for the
octonion-program consequences (commutative-tori seeds; q-commutative Y-systems à la
Inoue–Kuniba–Suzuki). A Lean ∃-counterexample over Mathlib's `QuaternionAlgebra` is
norm_num-decidable and left as a follow-up.
-/

namespace LaserCortex.foundations.YSystem

/-- softplus. -/
noncomputable def sp (y : ℝ) : ℝ := Real.log (1 + Real.exp y)

/-- The multiplicative A₂ Y-map: (X, Y) ↦ (Y, (1+Y)/X). -/
noncomputable def T (p : ℝ × ℝ) : ℝ × ℝ := (p.2, (1 + p.2) / p.1)

/-- The centered log-domain (pentagonator) map at scale β:
(a, b) ↦ (b, sp(β·b)/β − a). β = 1 gives the pure softplus second-difference. -/
noncomputable def S (β : ℝ) (p : ℝ × ℝ) : ℝ × ℝ := (p.2, sp (β * p.2) / β - p.1)

/-- The exponential conjugating pair map at scale β. -/
noncomputable def E (β : ℝ) (p : ℝ × ℝ) : ℝ × ℝ :=
  (Real.exp (β * p.1), Real.exp (β * p.2))

/-- The draft-literal map x_{t+1} = x_t + softplus(x_{t−1}). -/
noncomputable def D (p : ℝ × ℝ) : ℝ × ℝ := (p.2, p.2 + sp p.1)

-- ---------------------------------------------------------------------------
-- 1. Multiplicative period-5 closure (Zamolodchikov A₂)
-- ---------------------------------------------------------------------------

/-- **Zamolodchikov A₂ period-5.** Every positive-seed orbit of the Y-map returns
after exactly 5 steps. -/
theorem T_period5 (a b : ℝ) (ha : 0 < a) (hb : 0 < b) : (T)^[5] (a, b) = (a, b) := by
  ext
  · simp only [Function.iterate_succ_apply', Function.iterate_zero_apply, T]
    field_simp (disch := positivity)
    ring
  · simp only [Function.iterate_succ_apply', Function.iterate_zero_apply, T]
    field_simp (disch := positivity)
    ring

-- ---------------------------------------------------------------------------
-- 2. The log-domain form is the Y-system seen through Y = exp(β x)
-- ---------------------------------------------------------------------------

/-- Key identity: `exp(sp y) = 1 + exp y`. -/
theorem exp_sp (y : ℝ) : Real.exp (sp y) = 1 + Real.exp y :=
  Real.exp_log (by positivity)

/-- Conjugacy: `E_β ∘ S_β = T ∘ E_β`. -/
theorem conj_T_S (β : ℝ) (hβ : β ≠ 0) (p : ℝ × ℝ) : E β (S β p) = T (E β p) := by
  have key : Real.exp (β * (sp (β * p.2) / β - p.1))
      = (1 + Real.exp (β * p.2)) / Real.exp (β * p.1) := by
    have arg : β * (sp (β * p.2) / β - p.1) = sp (β * p.2) - β * p.1 := by field_simp
    rw [arg, Real.exp_sub, exp_sp]
  show (Real.exp (β * (S β p).1), Real.exp (β * (S β p).2)) = _
  simp only [S, T, E]
  ext
  · rfl
  · exact key

/-- Iterate transfer along a conjugacy. -/
theorem conj_iterate {α β : Type} (e : α → β) (f : α → α) (g : β → β)
    (h : ∀ p, e (f p) = g (e p)) (n : ℕ) (p) : (g)^[n] (e p) = e ((f)^[n] p) := by
  induction n with
  | zero => rfl
  | succ k ih =>
    simp only [Function.iterate_succ_apply']
    rw [ih, h]

/-- `E_β` is injective for β ≠ 0. -/
theorem E_injective (β : ℝ) (hβ : β ≠ 0) {p q : ℝ × ℝ} (hpq : E β p = E β q) : p = q := by
  apply Prod.ext
  · exact mul_left_cancel₀ hβ (Real.exp_injective (congrArg Prod.fst hpq))
  · exact mul_left_cancel₀ hβ (Real.exp_injective (congrArg Prod.snd hpq))

/-- **Main theorem: pentagonator period-5, for every β ≠ 0 and every seed.**
The centered log-domain recurrence `x ↦ log(1+e^{βx})/β − x_prev` returns to its
seed after 5 steps. Machine-checked version of the T2 finding: the pentagon is
β-invariant because `E_β` is exp-conjugacy to the exact Y-system. -/
theorem S_beta_period5 (β : ℝ) (hβ : β ≠ 0) (a b : ℝ) : (S β)^[5] (a, b) = (a, b) := by
  have hcon : ∀ p : ℝ × ℝ, E β (S β p) = T (E β p) := fun p => conj_T_S β hβ p
  have hT : (T)^[5] (E β (a, b)) = E β (a, b) := by
    have h1 : 0 < (E β (a, b)).1 := by
      show 0 < Real.exp (β * a)
      exact Real.exp_pos _
    have h2 : 0 < (E β (a, b)).2 := by
      show 0 < Real.exp (β * b)
      exact Real.exp_pos _
    exact T_period5 _ _ h1 h2
  have h : E β ((S β)^[5] (a, b)) = E β (a, b) := by
    rw [← conj_iterate (e := E β) (f := S β) (g := T) hcon 5 (a, b), hT]
  exact E_injective β hβ h

/-- Pure softplus (β = 1) at the origin seed. -/
theorem sp_period5_seed : (S 1)^[5] (0, 0) = (0, 0) := S_beta_period5 1 one_ne_zero 0 0

-- ---------------------------------------------------------------------------
-- 3. The draft-literal map: divergence witness
-- ---------------------------------------------------------------------------

/-- softplus is strictly positive. -/
theorem sp_pos (y : ℝ) : 0 < sp y :=
  Real.log_pos (by have := Real.exp_pos y; linarith)

/-- After one D-step the second component strictly exceeds the first. -/
theorem D_snd_gt_fst (p : ℝ × ℝ) : p.2 < (D p).2 :=
  lt_add_of_pos_right _ (sp_pos p.1)

/-- **The draft's literal mutation is not 5-periodic at (1, 1).**
(The quantitative golden-ratio divergence is not formalized here.) -/
theorem draft_no_period5 : (D)^[5] ((1, 1) : ℝ × ℝ) ≠ (1, 1) := by
  intro h
  have hgt : ((D)^[5] ((1, 1) : ℝ × ℝ)).1 < ((D)^[5] ((1, 1) : ℝ × ℝ)).2 := by
    simp only [Function.iterate_succ_apply']
    exact D_snd_gt_fst _
  rw [h] at hgt
  norm_num at hgt

end LaserCortex.foundations.YSystem
