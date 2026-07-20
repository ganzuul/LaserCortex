# CALPHAD-LaserCortex Free Energy Bridge

A formal structural mapping between CALPHAD thermodynamic free energy
and the LaserCortex coherence free energy. Not a physical equivalence —
an observation that both frameworks are instances of the same abstract
variational structure.

## 1. Abstract Free Energy Structure

Both CALPHAD and LaserCortex share this skeleton:

```
FreeEnergySpace = (State, FreeEnergy, Equilibrium, Excess, Susceptibility)
```

where:

- **State** — a type of configurations
- **FreeEnergy** — a scalar functional `F : State → ℝ`
- **Equilibrium** — a subset `State* ⊆ State` where F attains its minimum
- **Excess** — `ΔF(s) = F(s) - min(F)` — distance from equilibrium
- **Susceptibility** — a derivative of F w.r.t. a control parameter, measuring
  how sensitive the energy landscape is to external conditions

The variational principle in both cases:

> *Physical/mathematical evolution drives the system toward states that
> minimize the free energy.*

## 2. Instantiation: CALPHAD

### State space

```
State_CAL = (T, P, X)
```

where `T : ℝ⁺` (temperature), `P : ℝ⁺` (pressure), `X ∈ Δⁿ⁻¹` (composition
simplex over n components). Internal degrees of freedom are site fractions
`Y(phase, sublattice, species)`.

### Free energy

The Gibbs energy of phase φ at state (T, P, Y):

```
G_φ(T, P, Y) = G_ref + G_ideal_mixing + G_excess + G_magnetic
```

System-level:

```
G_sys(T, P, X) = min over {NP, Y} of Σ_φ NP_φ · G_φ(T, P, Y_φ)
```

subject to `Σ NP = 1`, mass balance constraints.

### Equilibrium

The minimum of G is characterized by the **common tangent condition**:

```
μ_i^α = μ_i^β = μ_i    for all coexisting phases α, β and components i
```

where `μ_i = ∂G/∂X_i` is the chemical potential.

### Excess (driving force)

The **ZPF driving force** for a phase at composition x relative to the
tangent hyperplane μ*:

```
DF(x) = μ* · x - G(T, P, x)
```

At equilibrium, `DF = 0` for all coexisting phases. Positive DF means
the phase is thermodynamically stable and should be present.

### Susceptibility

- **Heat capacity**: `Cp = -T · ∂²G/∂T²` — second derivative w.r.t. temperature
- **Compositional susceptibility**: `∂μ_i/∂X_j` — response of chemical
  potentials to composition changes
- **Phase boundary sensitivity**: how the equilibrium phase assemblage
  changes with T, P

### Phase transitions

At a first-order phase transition, two phases have equal G at the transition
temperature. The driving force is discontinuous — the system jumps from one
minimum to another.

## 3. Instantiation: LaserCortex

### State space

```
State_LC = (cd, EMLTree)
```

where `cd : ℕ` (Cayley-Dickson step, the "computational temperature") and
`t : EMLTree` (binary tree, the "configuration").

### Free energy

The coherence potential:

```
Φ(cd, t) = dcStep(t) × frictionDensity(cd)
```

where `dcStep(t)` counts remaining Tamari flips (distance to normal form)
and `frictionDensity(cd)` is the per-flip cost (jumps at CD 2→3).

### Equilibrium

The unique minimum is the right-comb normal form:

```
Φ(cd, rightComb n) = 0    for all cd, n
```

Every EMLTree contracts to its rightComb via the Tamari lattice.

### Excess (distinguishability debt)

```
ΔΦ(cd, t) = Φ(cd, t) - Φ(cd, rightComb t.size)
           = dcStep(t) × frictionDensity(cd)
```

At rightComb, `ΔΦ = 0`. For any other tree, `ΔΦ > 0` — the position
carries latent distinguishability that has not yet been resolved.

### Susceptibility

The **distinguishability density**:

```
η(cd, t) = dcStep(t) / frictionDensity(cd)
```

measures recoverable work per unit friction. High density → cheap flips
(associative regime). Low density → expensive flips (non-associative regime).

The derivative w.r.t. cd captures how sensitive the energy landscape is
to the CD step — the "computational heat capacity."

### Phase transition

At CD 2→3, `frictionDensity` jumps from 2 to 19 (ratio 9.5×). The
associator barrier activates, making contraction fundamentally more
expensive. This is the LaserCortex analogue of a first-order phase
transition: the energy landscape is discontinuous at the critical point.

## 4. The Mapping

### State space correspondence

| CALPHAD | LaserCortex | Interpretation |
|---------|-------------|----------------|
| T (temperature) | cd (CD step) | Control parameter that sets the energy scale |
| X (composition) | EMLTree (tree shape) | Internal configuration to be optimized |
| Phase fraction NP | — (single tree) | LC has no multi-phase coexistence (yet) |
| Y (site fractions) | tree weights (lW, rW) | Sub-tree composition measures |

### Energy correspondence

| CALPHAD | LaserCortex | Structure |
|---------|-------------|-----------|
| G(T, P, X) | Φ(cd, t) | Scalar free energy on state space |
| G_min = 0 at equilibrium | Φ_min = 0 at rightComb | Unique global minimum |
| μ = ∂G/∂X | frictionDensity(cd) | "Cost gradient" of configuration |
| Cp = -T · ∂²G/∂T² | ∂η/∂cd | Sensitivity to control parameter |

### Excess correspondence

| CALPHAD | LaserCortex | Structure |
|---------|-------------|-----------|
| Driving force DF = μ·x - G | Excess ΔΦ = Φ - Φ_min | Distance from equilibrium |
| DF = 0 at equilibrium | ΔΦ = 0 at rightComb | Minimum condition |
| DF > 0 → phase stable | ΔΦ > 0 → work remains | Residual potential |

### Susceptibility correspondence

| CALPHAD | LaserCortex | Structure |
|---------|-------------|-----------|
| Cp (heat capacity) | η (density) | Response to control parameter |
| Cp → ∞ at critical point | η → 0 at CD 2→3 (density drops) | Phase transition signature |
| Phase boundary slope dT/dX | φ.monotone_cd | How energy scales with control |

### Phase transition correspondence

| CALPHAD | LaserCortex | Structure |
|---------|-------------|-----------|
| First-order: G_α = G_β | CD 2→3: friction jumps 2→19 | Discontinuous energy landscape |
| Latent heat | strut_weight² = 16 | Energy cost of the transition |
| Coexistence curve | assocDefect threshold | Boundary between regimes |

## 5. What This Is Not

This mapping does **not** claim:

- That EMLTrees are compositions (they're binary trees, not simplex vectors)
- That CD steps are temperatures (there's no thermal bath, no Boltzmann distribution)
- That Φ is measured in joules (it's a dimensionless ℕ-valued functional)
- That LaserCortex predicts phase diagrams (it predicts which trajectories survive)

It **does** claim:

- Both frameworks minimize a scalar free energy functional over a state space
- Both have excess/debt functionals that vanish at equilibrium
- Both have susceptibility measures that capture phase transition behavior
- Both exhibit discontinuous energy landscapes at critical parameter values
- The abstract structure `FreeEnergySpace` is a useful common language

## 6. Open Questions

1. **Is there a functor?** Can we define structure-preserving maps between
   `State_CAL → State_LC` that commute with the free energy functionals?
   Or is the correspondence purely analogical?

2. **Can CALPHAD predict LC behavior?** If we treat the Tamari lattice as
   a "phase space" and Φ as a "Gibbs energy," does CALPHAD equilibrium
   analysis (common tangent, driving force) give predictions about which
   Tamari contraction paths are "thermodynamically favored"?

3. **Can LC predict CALPHAD behavior?** If we treat composition space as
   a tree of compositional decisions, does the LC variational principle
   (minimize ΔΦ) predict anything about which compositions are stable?

4. **Multi-phase LC?** The LC framework currently has a single EMLTree.
   If we allowed superpositions of trees (multiple "phases" coexisting),
   would the equilibrium conditions resemble the CALPHAD common tangent?

## 7. File References

- `LaserCortex/FreeEnergy.lean` — the LC free energy formalization
- `LaserCortex/Friction.lean` — frictionDensity, assocDefect, phase change
- `LaserCortex/SubdivisionClosure.lean` — weightedCost, closure
- `docs/GPT_on_free_energy.md` — the original free energy analogy
- `ESPEI/espei/shadow_functions.py` — CALPHAD Gibbs energy evaluation
- `ESPEI/espei/error_functions/zpf_error.py` — ZPF driving force
- `ESPEI/espei/error_functions/equilibrium_thermochemical_error.py` — residuals
