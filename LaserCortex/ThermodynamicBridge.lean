import Mathlib
import LaserCortex.Friction
import LaserCortex.SubdivisionClosure
import LaserCortex.FreeEnergy

/-!
# Thermodynamic Bridge — CALPHAD ↔ LaserCortex

A *local* structural mapping between CALPHAD thermodynamic free energy and
the LaserCortex coherence free energy. Not a physical equivalence.

## Why "local"? — the runway is short

A prior version of this file defined an unconditional `BridgeMap` and
left two `sorry` proofs: `energy_bound` and `preserves_equilibrium`.
Both are mathematically false on the assumptions they were stated under;
treating them as axioms makes any theorem follow (a false premise proves
anything). The three structural asymmetries
that doom the naive bridge are:

1. **Excess vs total energy.** LC's `Φ` is already an *excess*,
   because `Φ_min = 0` (the right comb carries zero dcStep).
   CALPHAD's Gibbs `G` is a *total* energy with `G_min ≠ 0`; the
   "excess" / driving force `DF = μ*·x − G` is a subtraction. Bridging
   `Φ ↔ G` directly conflates an excess with a total. We bridge
   *excess ↔ excess* (`BridgeMap.excess_bound`) instead.

2. **Linear vs quadratic.** A true CALPHAD Gibbs is locally convex in
   the composition distance — `½ G'' (x − x*)²` to second order. LC's `Φ`
   is *linear* in the discrete flip count `dcStep`. No constant `C`
   satisfies `O(n²) ≤ O(n) + C` for all `n`. We therefore use a CALPHAD
   *driving-force form* `DF(T, x) = (T + 1) · x`, which is exactly the
   near-equilibrium linearisation `μ* · (x − x*)` of the Gibbs energy
   (Taylor expansion around the common-tangent point). This is the form
   that CALPHAD itself uses when it speaks of "driving force".

3. **Control dependence of equilibrium.** In real CALPHAD, the
   equilibrium composition `x*` depends on `T` (the solvus line).  In
   LC, the equilibrium is the right-comb normal form, which is
   *independent* of the control parameter `cd` (`Φ(cd, rightComb n) =
   0` for every `cd` and `n`).  We make the toy CALPHAD equilibrium
   `(0, 0)` control-independent so that `preserves_equilibrium` is
   actually true.

After these three honest design choices, the bridge is *still* only
valid in the non-associative regime `cd ≥ 3`.  In the associative regime
(`cd ≤ 2`), LC's friction density `frictionDensity(cd) ∈ {0,1,2}` is
*genuinely smaller* than the CALPHAD compositional slope `(cd + 1) ∈
{1,2,3}`, so `CalphadFE.excess ≤ LCFreeEnergySpace.excess` is false.
This is a real physical asymmetry, not a missing detail: at low
friction LC has *less* distinguishability debt than CALPHAD has
compositional driving force.  The LC → CALPHAD direction therefore uses
`LocalBridgeMap`, which restricts `excess_bound` to `cd ≥ criticalPoint`
— the same `criticalPoint = 3` where `revise` (Generation.lean) and
the phase change already single out the non-associative regime.  The
reverse direction is unconditional (`calphadToLcMap : BridgeMap`):
LC's rightComb is `Φ = 0`, so its excess is always ≤ anything.

So the runway is not miles long — it is short — but it is real, and it
lands precisely in LC's non-associative regime.

## The shared skeleton

Both frameworks have:
- a **state space**        (CALPHAD: (T, composition);  LC: (cd, EMLTree))
- a **free energy**        (CALPHAD: G;                  LC: Φ)
- an **equilibrium**       (CALPHAD: x*;                 LC: rightComb)
- an **excess / DF**       (CALPHAD: DF;                 LC: ΔΦ)
- a **phase transition**   (CALPHAD: first-order in real Gibbs — NOT
  modelled by the toy; LC: CD 2→3)

## Key definitions

- `FreeEnergySpace`     — abstract variational skeleton
- `CalphadFE`           — abstract CALPHAD driving-force instance (linear)
- `LCFreeEnergySpace`   — LaserCortex instance (wraps `FreeEnergy.lean`)
- `BridgeMap`           — excess bridge, valid in *all* regimes
- `LocalBridgeMap`       — excess bridge, valid only above `criticalPoint`

## Cross-refs

- `FreeEnergy.lean`     — LC free energy formalization
- `Friction.lean`       — frictionDensity, assocDefect, strut_weight
- `docs/calphad_bridge.md` — the full mathematical mapping
- `docs/GPT_on_free_energy.md` — the original analogy
-/

open SubdivisionClosure EMLTree

-- ============================================================================
-- SECTION 1: Abstract Free Energy Space
-- ============================================================================

/--
A free energy space is the abstract variational skeleton shared by
CALPHAD and LaserCortex.

- `State`        — a type of configurations
- `ControlParam` — a type of control parameters (temperature, CD step)
- `freeEnergy`   — a scalar functional `κ → σ → ℕ`
- `equilibrium`  — the canonical minimum-energy state at a control param
- `excess`       — `freeEnergy κ σ − freeEnergy κ (equilibrium κ)` (default)
- `criticalPoint` — the control parameter where a regime change occurs

This structure does **not** include a `phaseChangeRatio` field. The
abstract skeleton is too thin to enforce "the energy landscape is
discontinuous at the critical point" — that is a *theorem* one proves
for an instance (as `Friction.lean` proves it for LCFreeEnergySpace),
not a definitional field. Storing a hand-picked ratio in the structure
lets any convex toy claim a phase transition by fiat, which is the
kind of over-claiming that made an earlier `BridgeMap` unsound.
-/
structure FreeEnergySpace where
  State : Type
  ControlParam : Type
  freeEnergy : ControlParam → State → ℕ
  equilibrium : ControlParam → State
  excess (κ : ControlParam) (σ : State) : ℕ :=
    freeEnergy κ σ - freeEnergy κ (equilibrium κ)
  equilibrium_min : ∀ κ σ, freeEnergy κ (equilibrium κ) ≤ freeEnergy κ σ
  equilibrium_excess_zero : ∀ κ, excess κ (equilibrium κ) = 0
  criticalPoint : ControlParam

-- ============================================================================
-- SECTION 2: CALPHAD Instance (driving-force form)
-- ============================================================================

/--
The CALPHAD driving-force instance — an abstract scaler with the shape
of the *excess* Gibbs, not the total Gibbs.

`freeEnergy t x = (t + 1) * x` is the near-equilibrium linearisation of
the true CALPHAD Gibbs via the common-tangent construction: the driving
force `DF = μ*·x − G(T, x)` reduces to `μ*·(x − x*)` near equilibrium,
which is `(T + 1)·x` for this toy (the chemical-potential slope `μ*`
grows with `T`, and the equilibrium composition is `x* = 0`).

It is **not** a full CALPHAD model — no Redlich-Kister excess
polynomials, no sublattice models, no magnetic contributions, and no
real phase diagram. In particular, the toy has *no* phase transition:
the slope `T + 1` is smooth in `T`, unlike real CALPHAD where a
discontinuous tangent shift at a first-order transition changes the
slope abruptly. A real phase change would need to be modelled as a
non-smooth `freeEnergy`, after which a phase-change *theorem* could be
proved; encoding a hand-picked `phaseChangeRatio` in the structure (as
the prior commit did) would merely declare one by fiat.

Two design choices matter for the bridge:

- `freeEnergy` is **linear** in `x`, so we bridge LC's
  linear-in-`dcStep` excess to CALPHAD's near-equilibrium driving force
  (not to a quadratic Gibbs, which the bound `O(n²) ≤ O(n) + C`
  cannot satisfy).
- `equilibrium _ := (0, 0)` is **control-param independent**, matching
  LC's `rightComb` equilibrium (which is also control-independent:
  `Φ(cd, rightComb n) = 0` for every `cd` and `n`).
-/
abbrev CalphadFE : FreeEnergySpace where
  State := ℕ × ℕ
  ControlParam := ℕ
  freeEnergy t x := (t + 1) * x.2
  equilibrium _ := (0, 0)
  equilibrium_min t x := by
    show (t + 1) * 0 ≤ (t + 1) * x.2
    omega
  equilibrium_excess_zero t := by
    show (t + 1) * 0 - (t + 1) * 0 = 0
    omega
  criticalPoint := 3

-- ============================================================================
-- SECTION 3: LaserCortex Instance
-- ============================================================================

/--
The LaserCortex free energy space — wrapping `FreeEnergy.lean`.

- `State = EMLTree`, `ControlParam = ℕ` (CD step)
- `freeEnergy = Φ(cd, t) = dcStep(t) × frictionDensity(cd)`
- `equilibrium _ := .Leaf` — the canonical zero-cost state.

Why `.Leaf` and not `rightComb t.size`?  The `FreeEnergySpace` signature
`equilibrium : ControlParam → State` can only depend on the control
parameter, not on the input state.  In LC the true minimum is
`rightComb t.size`, which depends on the starting tree, so it does not
fit the signature. Every tree with `dcStep = 0` (right-comb normal form
of *any* size) gives `Φ = 0`, so `.Leaf` (which is `rightComb 0`) is a
canonical representative of the *equivalence class* of zero-cost
states.  The numeric `excess` is therefore `Φ(cd, t) - Φ(cd, .Leaf) =
Φ(cd, t)`, which equals `excessPotential cd t` of `FreeEnergy.lean`
(because `Φ(cd, rightComb t.size) = 0` too).  See
`LCFreeEnergySpace.excess_eq` below.

- `criticalPoint := 3` — the associative/non-associative boundary.
-/
abbrev LCFreeEnergySpace : FreeEnergySpace where
  State := EMLTree
  ControlParam := ℕ
  freeEnergy cd t := coherencePotential cd t
  equilibrium _ := .Leaf
  equilibrium_min cd t := by
    simp [coherencePotential, weightedCost, dcStep]
  equilibrium_excess_zero cd := by
    show coherencePotential cd .Leaf - coherencePotential cd .Leaf = 0
    omega
  criticalPoint := 3

-- ============================================================================
-- SECTION 4: Shared Structural Theorems
-- ============================================================================

/-- In any free energy space, excess is non-negative. -/
theorem excess_nonneg (FE : FreeEnergySpace) (κ : FE.ControlParam) (σ : FE.State) :
    FE.excess κ σ ≥ 0 := by
  unfold FreeEnergySpace.excess
  have h := FE.equilibrium_min κ σ
  omega

/-- In any free energy space, the equilibrium state minimizes excess. -/
theorem equilibrium_minimizes_excess (FE : FreeEnergySpace)
    (κ : FE.ControlParam) (σ : FE.State) :
    FE.excess κ (FE.equilibrium κ) ≤ FE.excess κ σ := by
  have h := FE.equilibrium_min κ σ
  have hz : FE.excess κ (FE.equilibrium κ) = 0 := FE.equilibrium_excess_zero κ
  omega

/-- The CALPHAD excess has the explicit linear form `(T + 1)·x.2`
    (driving force form, control-independent equilibrium). -/
theorem CalphadFE.excess_eq (t : ℕ) (x : ℕ × ℕ) :
    CalphadFE.excess t x = (t + 1) * x.2 := by
  show (t + 1) * x.2 - (t + 1) * 0 = (t + 1) * x.2
  omega

/-- The LC excess has the explicit form `dcStep(t) · frictionDensity(cd)`.

    This equals the `excessPotential cd t` of `FreeEnergy.lean` numerically
    because `coherencePotential cd .Leaf = 0` (`.Leaf` has `dcStep = 0`)
    and `coherencePotential cd (rightComb t.size) = 0` (rightComb has
    `dcStep = 0`); both reference states give zero, so the choice of
    reference state does not change the excess. -/
theorem LCFreeEnergySpace.excess_eq (cd : ℕ) (t : EMLTree) :
    LCFreeEnergySpace.excess cd t = dcStep t * frictionDensity cd := by
  show dcStep t * frictionDensity cd - coherencePotential cd .Leaf
    = dcStep t * frictionDensity cd
  have : coherencePotential cd .Leaf = 0 := by
    simp [coherencePotential, weightedCost, dcStep]
  simp [this]

-- ============================================================================
-- SECTION 5: Bridge Maps
-- ============================================================================

/--
A **bridge map** between two free energy spaces: a structure-preserving
pair of maps that **bridges excesses** (driving force / debt), not totals.

The bound says: mapping a state from `FE₁` to `FE₂` and computing its
*excess* gives ≤ the original excess plus a constant `C`.

We bridge excess, not `freeEnergy`, because LC's `Φ` is *already* an
excess (`Φ_min = 0`), while CALPHAD's `G` is a total (`G_min ≠ 0`);
bridging totals conflates two different structural objects. -/
structure BridgeMap (FE₁ FE₂ : FreeEnergySpace) where
  stateMap : FE₁.State → FE₂.State
  controlMap : FE₁.ControlParam → FE₂.ControlParam
  excess_bound : ∃ C : ℕ, ∀ κ σ,
    FE₂.excess (controlMap κ) (stateMap σ) ≤ FE₁.excess κ σ + C
  preserves_equilibrium : ∀ κ,
    stateMap (FE₁.equilibrium κ) = FE₂.equilibrium (controlMap κ)

/--
A **local** bridge map — the `excess_bound` holds only above the
source's `criticalPoint`. Used when the two spaces have asymmetric phase
regimes: in LC, `frictionDensity` `cd ≤ 2` ∈ {0,1,2} is *smaller* than
CALPHAD's driving-force slope `(cd + 1) ∈ {1,2,3}`, so the bound is
honestly false below the regime change. Anything below `cd = 3` lives
outside this bridge, exactly as LC's own `revise` step throws out the
vacuous `cd = 0` pole.

The `beyondCritical` predicate replaces a `[LE ControlParam]` typeclass:
`FreeEnergySpace.ControlParam` is an opaque def-projection that Lean
cannot unfold during typeclass synthesis, so we carry the comparison
explicitly. -/
structure LocalBridgeMap (FE₁ FE₂ : FreeEnergySpace) where
  stateMap : FE₁.State → FE₂.State
  controlMap : FE₁.ControlParam → FE₂.ControlParam
  beyondCritical : FE₁.ControlParam → Prop
  excess_bound : ∃ C : ℕ, ∀ κ σ, beyondCritical κ →
    FE₂.excess (controlMap κ) (stateMap σ) ≤ FE₁.excess κ σ + C
  preserves_equilibrium : ∀ κ,
    stateMap (FE₁.equilibrium κ) = FE₂.equilibrium (controlMap κ)

-- ============================================================================
-- SECTION 6: LC → CALPHAD Bridge (local: cd ≥ 3)
-- ============================================================================

/--
The local bridge from LaserCortex to CALPHAD.

- CD step → temperature index (identity)
- EMLTree `t` → `(0, dcStep t)` — tree excess work maps to composition distance

Equilibrium preservation: `rightComb` (dcStep = 0) maps to `(0, 0)`.

The bound holds only in the non-associative regime (`cd ≥ 3`):
LC's friction `cd + 16` then **dominates** CALPHAD's slope `cd + 1`,
so CALPHAD's driving force is ≤ LC's distinguishability debt (with C = 0).
Below `cd = 3`, CALPHAD's slope exceeds LC's friction, the inequality
reverses, and the bridge does not apply — see the module doc. -/
def lcToCalphadMap : LocalBridgeMap LCFreeEnergySpace CalphadFE where
  stateMap t := (0, dcStep t)
  controlMap cd := cd
  beyondCritical cd := 3 ≤ cd
  excess_bound := by
    -- Want, for cd ≥ 3, all t:
    --   CalphadFE.excess cd (0, dcStep t) ≤ LCFreeEnergySpace.excess cd t
    -- i.e. (cd + 1) * dcStep t ≤ dcStep t * frictionDensity cd
    -- For cd ≥ 3, frictionDensity cd = cd + strut_weight * strut_weight
    --                  = cd + 16  (strut_weight = 4, see Algebra.lean)
    -- so we need (cd + 1) * n ≤ n * (cd + 16), i.e. 15 * n ≥ 0, trivial.
    use 0
    intro cd t hcd
    rw [CalphadFE.excess_eq, LCFreeEnergySpace.excess_eq,
        frictionDensity_eq_k_plus_16_for_k_ge_3 cd hcd]
    simp only [strut_weight_eq_four]
    -- Goal: (cd + 1) * dcStep t ≤ dcStep t * (cd + 16)
    rw [Nat.mul_comm (dcStep t) (cd + 16)]
    exact Nat.mul_le_mul_right _ (by omega)
  preserves_equilibrium := by
    intro cd
    show (0, dcStep .Leaf) = ((0 : ℕ), (0 : ℕ))
    simp [dcStep]

-- ============================================================================
-- SECTION 7: CALPHAD → LC Bridge (unconditional)
-- ============================================================================

/--
The reverse bridge: CALPHAD → LaserCortex.

- Temperature index → CD step (identity)
- `(T, X) → rightComb X` — composition distance maps to a tree at normal form

The bound is trivial: `rightComb X` has `dcStep = 0`, so `Φ(cd,
rightComb X) = 0`, whose excess is 0; this is ≤ CALPHAD's excess
`(T + 1) · X` for any `T, X`. So `C = 0`.

Equilibrium preservation: `(T, 0)` → `rightComb 0 = .Leaf`. -/
def calphadToLcMap : BridgeMap CalphadFE LCFreeEnergySpace where
  stateMap x := _root_.rightComb x.2
  controlMap t := t
  excess_bound := by
    use 0
    intro t x
    rw [CalphadFE.excess_eq, LCFreeEnergySpace.excess_eq, dcStep_rightComb]
    -- Goal: 0 * frictionDensity t ≤ (t + 1) * x.2 + 0   — trivially true
    simp
  preserves_equilibrium := by
    intro t
    rfl

-- ============================================================================
-- SECTION 8: Variational Principle Transfer
-- ============================================================================

/-- The LC variational principle: contraction paths decrease excess. -/
theorem lc_variational_principle (cd : ℕ) {s t : EMLTree}
    (h : contracts_to s t) :
    excessPotential cd t ≤ excessPotential cd s :=
  excess_contraction_path cd h

/-- The CALPHAD instance: excess is non-negative. -/
theorem calphad_excess_nonneg (κ : ℕ) (σ : CalphadFE.State) :
    CalphadFE.excess κ σ ≥ 0 :=
  excess_nonneg CalphadFE κ σ

-- ============================================================================
-- SECTION 9: Phase Transition Correspondence
-- ============================================================================

/-- LC phase change: `Φ(3, t) > 9 × Φ(2, t)` for non-trivial trees.
    The friction density jumps from 2 (associative) to 19 (non-associative)
    at the CD 2→3 boundary — `frictionDensity 3 / frictionDensity 2 = 9.5`.

    Proven exactly once, for LC, from the algebra; *not* stored as a
    hand-picked field of the abstract `FreeEnergySpace`. -/
theorem lc_phase_change (t : EMLTree) (h : dcStep t > 0) :
    coherencePotential 3 t > 9 * coherencePotential 2 t :=
  potential_phase_change_ratio t h

/-- The CALPHAD toy has **no** phase transition: the driving-force slope
    `T + 1` is smooth in `T`. A real CALPHAD Gibbs with Redlich-Kister
    excess terms has a non-smooth `freeEnergy` near a first-order
    transition, and a phase-change ratio could be *proved* for such a
    model — but encoding one as a `FreeEnergySpace` field (as the prior
    commit did) merely declares it by fiat. The honest statement for the
    toy is that it has a `criticalPoint := 3` for symmetry-with-LC, but
    nothing discontinuous happens there. -/
theorem CalphadFE.no_phase_change (t : ℕ) (x : ℕ × ℕ) :
    CalphadFE.freeEnergy t x = (t + 1) * x.2 := rfl

-- ============================================================================
-- SECTION 10: Summary
-- ============================================================================

-- ## The Bridge in One Sentence
--
-- Both CALPHAD and LaserCortex are instances of `FreeEnergySpace`, and
-- the *excesses* (driving force / distinguishability debt) admit an
-- additive bridge: the CALPHAD → LC direction unconditionally (LC's
-- equilibrium carries zero excess, so its excess is ≤ anything), and the
-- LC → CALPHAD direction locally, in the non-associative regime `cd ≥ 3`
-- where LC's friction density dominates CALPHAD's compositional slope.
--
-- ## What This Means
--
-- 1. The abstract skeleton `FreeEnergySpace` is too thin to *enforce*
--    a phase change; phase change is a *theorem* about an instance, not
--    a definitional field.
-- 2. Total free energies (LC's `Φ` vs CALPHAD's `G`) are *different
--    kinds of object* — `Φ` is already an excess — so a bridge must
--    operate at the level of `excess`, not `freeEnergy`.
-- 3. The bridge is local, not global: LC's low-friction regime (`cd ≤ 2`)
--    does not bridge to CALPHAD's linear driving force, because the
--    slopes invert.  This asymmetry is real, not a missing proof.
-- 4. The variational principle transfers cleanly: LC's proof that
--    contraction paths decrease `ΔΦ` has the same shape as CALPHAD's
--    observation that the system evolves to minimise `G`.
--
-- ## What This Does Not Mean
--
-- - EMLTrees are compositions (they're binary trees, not simplex vectors)
-- - CD steps are temperatures (no thermal bath, no Boltzmann distribution)
-- - Φ is measured in joules (it's a dimensionless ℕ-valued functional)
-- - The toy CALPHAD model has a phase transition (it does not)
-- - LaserCortex predicts phase diagrams