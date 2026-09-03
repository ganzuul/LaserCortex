import Mathlib

/-!
# Plasma Ball — the geometric skeleton (3-D, sphere `S²`)

Lean-first formalization of the plasma-globe demo
(`webgpu/plasma_globe.html`). The globe is a sphere; its glowing filaments
are radial rays from a central electrode (radius `r₀`) out to the glass wall
(radius `R`). The rendered ray-marcher computes exactly these facts:

* the wall and the electrode are the spheres `{p | ‖p‖ = R}` and
  `{p | ‖p‖ = r₀}`, where `‖·‖` is the Euclidean norm — the shader's
  `length(p)`;
* a filament is a **unit direction** `u` scaled along `t ∈ [r₀, R]`, so its
  two endpoints lie on the two spheres and every intermediate point lies on
  the sphere of radius `t` (a radial field line);
* the filament **roots** are the equal-area (golden-angle) points
  `(√(1−z²)·cos α, √(1−z²)·sin α, z)`, which lie on the unit sphere for
  every latitude `z ∈ [−1,1]` and azimuth `α` — the golden angle fixes the
  *distribution* of the roots, not their membership on `S²`.

We work with the squared norm (sum of squares), so every statement is
polynomial arithmetic (`ring`/`nlinarith`) rather than analytic-norm
machinery — this is the shader's `length(p)` up to the harmless square root.
The sphere `S²` here is the plasma globe's wall; in the project's `(4,4)`
frame it is the surface whose rulings the octonion structure describes
(`research_questions.md`, rulings-as-species). -/

namespace PlasmaBall

/-- A point of `ℝ³` (the plasma globe's ambient space), matching the shader's
`vec3`. -/
structure Point where
  x : ℝ
  y : ℝ
  z : ℝ

/-- Squared Euclidean norm: `‖p‖² = x² + y² + z²`. The sphere of radius `R`
is `{p | sqNorm p = R²}` — the shader's `length(p) == R`. -/
def sqNorm (p : Point) : ℝ := p.x ^ 2 + p.y ^ 2 + p.z ^ 2

/-- Scaling a point by `c` (the shader's `c * p`). -/
def scale (c : ℝ) (p : Point) : Point := ⟨c * p.x, c * p.y, c * p.z⟩

/-- The unit sphere `S²` (the globe wall at radius 1, before scaling to `R`). -/
def onSphere (p : Point) : Prop := sqNorm p = 1

/-- Homogeneity: scaling by `c` scales the squared norm by `c²`. This is the
algebraic form of `‖c·p‖ = |c|·‖p‖`, used every time the shader places a
filament vertex at `radius * direction`. -/
theorem sqNorm_scale (c : ℝ) (p : Point) : sqNorm (scale c p) = c ^ 2 * sqNorm p := by
  simp [sqNorm, scale]
  ring

/-- A unit direction scaled to radius `R` lies on the sphere of radius `R`:
the filament endpoint on the glass wall (`R`) or the electrode sphere (`r₀`). -/
theorem scaled_on_sphere_of_unit (R : ℝ) (u : Point) (hu : sqNorm u = 1) :
    sqNorm (scale R u) = R ^ 2 := by
  rw [sqNorm_scale, hu]
  ring

/-- Both endpoints of a filament along the unit direction `u`: the electrode
at radius `r₀` and the wall at radius `R` lie on their respective spheres —
the plasma ball is a shell between two concentric spheres, and each filament
is a radial segment crossing it. -/
theorem filament_endpoints_on_spheres (u : Point) (hu : sqNorm u = 1) (r₀ R : ℝ) :
    sqNorm (scale r₀ u) = r₀ ^ 2 ∧ sqNorm (scale R u) = R ^ 2 := by
  constructor <;> rw [sqNorm_scale, hu] <;> ring

/-- An equal-area (golden-angle) point on `S²`: latitude via `z` (so `√(1−z²)`
is the equatorial radius), azimuth `α`. The golden-angle spiral chooses
`z, α` per root; membership only needs Pythagoras, so it holds for every
`z ∈ [−1,1]` and `α` — the spiral fixes the *distribution*, not the sphere. -/
noncomputable def root (z α : ℝ) : Point :=
  ⟨Real.sqrt (1 - z * z) * Real.cos α, Real.sqrt (1 - z * z) * Real.sin α, z⟩

/-- Every root of the equal-area spiral lies on the unit sphere `S²`: the
filament roots are exactly the points of the plasma globe's wall. -/
theorem root_on_sphere (z α : ℝ) (hz : 0 ≤ 1 - z * z) : onSphere (root z α) := by
  unfold onSphere
  simp only [root, sqNorm]
  have hsq : Real.sqrt (1 - z * z) ^ 2 = 1 - z * z := Real.sq_sqrt hz
  rw [mul_pow, mul_pow]
  rw [hsq]
  nlinarith [Real.cos_sq_add_sin_sq α]

/-- The radial field `p ↦ p / ‖p‖` (the shader's `normalize(p)`): its value at
any nonzero point lies on the unit sphere. This is *why* a filament is a unit
direction `u` — the direction field of the plasma globe is normalized, so
"filaments follow the radial field" is well-defined. -/
noncomputable def normalized (p : Point) : Point := scale (1 / Real.sqrt (sqNorm p)) p

/-- The normalized radial field is a unit vector field: `‖p / ‖p‖‖ = 1` for
every nonzero `p` — i.e. the filament direction is always a point of `S²`. -/
theorem normalized_unit (p : Point) (hp : sqNorm p ≠ 0) :
    sqNorm (normalized p) = 1 := by
  have hs : 0 ≤ sqNorm p := by
    unfold sqNorm
    nlinarith [sq_nonneg p.x, sq_nonneg p.y, sq_nonneg p.z]
  have hsq : Real.sqrt (sqNorm p) ^ 2 = sqNorm p := Real.sq_sqrt hs
  have hden : Real.sqrt (sqNorm p) ≠ 0 := by
    intro h0
    have hzero : sqNorm p = 0 := by rw [← hsq, h0]; ring
    exact hp hzero
  have hinv : (1 / Real.sqrt (sqNorm p)) ^ 2 = 1 / sqNorm p := by
    rw [div_pow, one_pow, hsq]
  rw [normalized, sqNorm_scale, hinv, one_div]
  exact inv_mul_cancel₀ hp

end PlasmaBall
