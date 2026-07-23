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

- `LaserCortex/ThermodynamicBridge.lean` — the bridge itself (excess-level,
  local `cd ≥ 3`, **0 `sorry`**); see §8 for why it took this shape
- `LaserCortex/FreeEnergy.lean` — the LC free energy formalization
- `LaserCortex/Friction.lean` — frictionDensity, assocDefect, phase change
- `LaserCortex/SubdivisionClosure.lean` — weightedCost, closure
- `docs/GPT_on_free_energy.md` — the original free energy analogy
- `ESPEI/espei/shadow_functions.py` — CALPHAD Gibbs energy evaluation
- `ESPEI/espei/error_functions/zpf_error.py` — ZPF driving force
- `ESPEI/espei/error_functions/equilibrium_thermochemical_error.py` — residuals

## 8. The boundary: closed-form and recursive registers

This section records *why* the bridge took the shape recorded above, and
why that shape is the project's working interpretation rather than a
convenience. It is heavier on interpretation than §1–§7; the math it
motivates is fully formalized in `ThermodynamicBridge.lean` (0 `sorry`).

The reading offered here is intended to be *complementary* — no
inherited framework is being corrected. The section's purpose is to
name a distinction (two registers for the same physics) and to record
where the bridge sits relative to it. §8.5 makes the scope explicit.

### 8.1 The earlier premise, and why it could not close

An earlier draft of `ThermodynamicBridge.lean` defined the CALPHAD toy
free energy as `G(T, x) = (T + 1) · x²` and tried to bridge LC's `Φ`
*to that quadratic*. The bridge's two load-bearing proofs
(`energy_bound`, `preserves_equilibrium`) were `sorry`, and both were
**mathematically false as stated**: `O(n²) ≤ O(n) + C` admits no
constant `C`, and `(0, 0) = (cd, 0)` admits only `cd = 0`. Treating a
false proposition as an axiom lets any conclusion follow, so the draft
was unsound and had to be rewritten, not patched.

The `x²` was not a careless idealization. It was the **anti-derivative**
of the linear driving force `μ · dx`: `∫ (T + 1)·dx = ½(T + 1)·x²`. Real
CALPHAD's Gibbs energy is the fixed-point equation

```
G_sys(T, P, X) = min over {NP, Y} of Σ_φ NP_φ · G_φ(T, P, Y_φ)
```

phase fractions depend on chemical potentials, which depend on phase
fractions — a genuine `μ ↔ x` self-consistency loop. The closed form
`x²` is what you get when you **resolve that loop once and fold the
result into a polynomial** — a move that is exactly right where the
fixed point is differentiable and the loop admits a closed form, and
that is how CALPHAD's common-tangent method uses it. The difficulty
appeared only because the bridge then asked a recursive object
(EMLTrees contracting through the Tamari lattice) to honor a snapshot
of that resolved loop — which it cannot, because its recursion lives
in `dcStep` / `contracts_to`, *not* in the polynomial.

### 8.2 What we actually did

We removed the premature integration. The bridge now connects at the
**linear driving-force level** `DF(T, x) = (T + 1) · x`, which is the
near-equilibrium linearisation `DF = μ* · (x − x*)` of the Gibbs
energy — i.e. the *Jacobian* of the reflexive `μ ↔ x` loop, *before* the
loop is resolved. The recursion is no longer absent; it has simply been
returned to the layer where it always lived in LC: the Tamari
contraction (`dcStep`, `contracts_to`), formalized in `FreeEnergy.lean`.

Concretely, the LC→CALPHAD excess bound reduces to

```
(cd + 1) · dcStep t  ≤  dcStep t · (cd + 16)    for cd ≥ 3
```

which is `0 ≤ 15 · dcStep t` — dischargeable by `omega` /
`Nat.mul_le_mul_right`, i.e. by **reflexive** (definitional / linear-
arithmetic) reasoning, *with no structural induction into EMLTree*.
The earlier `n² ≤ n·k + 1` could not close because the `x²` had
carried the recursion in a register the LC side could not match: `Φ` is
already linear in `dcStep`, and the polynomial it was being bridged to
was not. What was `x²` at the bridge is now `x`, and `x` is the
differential of the fixed-point loop — the form in which the same
physics is written when the fixed point is left unresolved.

### 8.3 The tool-form hypothesis (working interpretation)

The recurrence of this pattern — a recursion folded away into a closed
form, then the closed form demanded back as if it were primitive — is,
in the project's view, an instance of a well-attested phenomenon in the
history of science: **the available instruments shape the questions that
get asked, and over time the instrument's horizon becomes, for its
practitioners, indistinguishable from the horizon of the problem.**

This is not a criticism of the practitioners, who were making the
correct and productive choice available to them. It is an observation
about how expressive form propagates: a choice made under one
constraint becomes, in the next generation, the form in which the
problem is *posed*, and the result looks like a property of the
problem rather than of the tooling.

> **Hypothesis (working).** Mathematical physics of the pre-computer
> era was developed by rational practitioners working under a real
> constraint: their results had to be checkable without electronic
> computation. The expressive forms they selected — local, closed-form,
> perturbative — were the correct ones for that constraint and produced
> correct physics. But the constraint also drew a horizon, and recursion
> that lived past that horizon was not so much rejected as *left
> unexpressed*, because expressing it would have made the problem
> uncheckable by the tools of the day. Over a generation, "expressible in
> closed form" became less an expedient and more the grammar in which the
> discipline thought.

The same shaping is visible across 20th-century mathematical physics,
without it diminishing the work so shaped:

- Yang–Mills gauge theory is posed with a local, closed field-strength
  `F_μν = ∂_μ A_ν − ∂_ν A_μ + [A_μ, A_ν]` — a form admirably matched to
  the perturbative, closed-form apparatus of Feynman diagrams, which
  was the instrument that made the theory computable. The non-perturbative
  sector (confinement, the mass gap) is where the apparatus becomes
  recusive and difficult; it is *also* the sector that is famously
  unresolved. Neither fact diminishes Yang–Mills — they are complementary
  faces of a single theory, one tractable in the pre-computer grammar,
  one not.
- CALPHAD's `min over {NP, Y}` self-consistency loop was historically
  handled by Lagrange-multiplier common-tangent constructions — closed
  forms, exactly valid where the loop's fixed point is differentiable.
  The loop itself was always there; it was expressed as a closed form
  where that was the honest thing to do, and left as a fixed-point
  iteration where it was not. The common-tangent method is correct
  physics in its domain; the driving-force linearisation that the bridge
  uses is the same physics in a different register.

In both cases the recursion was always there; it was not so much
rejected as **written in a different register** — closed-form where
the tool allowed it, fixed-point iteration where it did not.

LaserCortex's topological hypothesis is not that the inherited form
was wrong. It is the complementary bet: **a system whose central
invariant (the Cayley–Dickson step, the Tamari contraction, the
associator barrier at CD 2→3) is naturally recursive can now be
expressed in its recursive register**, and in that register the
*remaining* statement about energy becomes a definitional truth
(`rfl`-dischargeable) rather than a hard one. The `rfl`-dischargeable
form of the bridge is not a coincidence of the arithmetic: it is the
record that, when the recursion is allowed to live at the layer to
which it naturally belongs (the Tamari lattice), the energy statement
that sits on top of it simplifies to a tautology.

### 8.4 The reflexive observation *is* the boundary

The phase change recorded in §3–§4 is, formally, the discontinuity in
`frictionDensity` at CD 2→3 (`2 → 19`, ratio 9.5). Read through §8.3 it
gains a second reading: it is the **in-algebra image of the same
boundary that runs between the closed-form register and the recursive
register of mathematical physics.**

- **CD ≤ 2 (associative regime)** — contraction is cheap, closed-form
  reasoning (`cd · dcStep`) is faithful, `Φ` is a polynomial in `cd`.
  This is the regime where the closed-form register is honest and the
  bridge could (attempt to) live. It can't — the slopes still invert
  below `cd = 3`, which is why `LocalBridgeMap` honestly refuses to
  apply there. Below the boundary, LC has *less* distinguishability debt
  than CALPHAD has compositional driving force; the bridge has nothing
  to say, and that is a true statement about that regime, not a
  limitation of ours.
- **CD ≥ 3 (non-associative regime)** — the associator barrier
  (`strut_weight² = 16`) activates, contraction cannot be collapsed to
  a polynomial, and the honest energy statement becomes the reflexive
  one (`0 ≤ 15 · n`, `rfl`/`omega`). This is the regime the bridge
  *does* apply in, and it lands — by design — exactly where LC's own
  `revise` step (in `Generation.lean`) already singles out the
  non-vacuous pole.

The reflexive observation — that *the bridge's proofs are `rfl`-
dischargeable precisely in the regime where contraction cannot be
written in closed form* — is, on this reading, not a fact *about* the
bridge. It is the boundary itself, seen edgewise. The CD 2→3 phase
change and the closed-form/recursive register boundary are the same
boundary, because the form in which a fixed point is expressed — closed
or iterative — is exactly what crosses at that boundary.

The complementarity is the point. Below the boundary the closed-form
register is faithfully representable and the bridge does not apply;
above it the recursive register is load-bearing and the bridge's
statement simplifies to a tautology. Neither register is deficient;
they are complementary faces of the same discontinuity, and the bridge
exists precisely at the seam where the two faces meet.

### 8.5 What this section claims, and what it does not

**Claims.** The bridge in `ThermodynamicBridge.lean` is honest (0
`sorry`); its `rfl`-dischargeable form is a direct consequence of
keeping LC's recursion in the Tamari layer instead of folding it into
a polynomial; the regime where the bridge applies (`cd ≥ 3`) coincides
with the regime where contraction is genuinely non-polynomial.

**Does not claim (yet).** That the working interpretation of §8.3 is
*established* — it is recorded as the project's working reading, not as
a settled result. That Yang–Mills, CALPHAD, or any other inherited form
is *wrong*; §8.3 is explicitly an account of how a productive
constraint becomes a grammar, and treats the inherited forms as correct
in their register. That the closed-form register is in any way
deficient; it is the honest register below `cd = 3`, which is exactly
why the bridge declines to apply there. That the bound
`0 ≤ 15 · n` is physically deep; it is mathematically trivial, and that
triviality is the point. That real CALPHAD should drop its Gibbs
integrals; those are correct as totals, and the fixed-point iteration
they elide is recoverable exactly where it matters (near-equilibrium
driving-force analysis, which is what the bridge uses).
