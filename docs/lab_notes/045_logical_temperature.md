# Lab Note 045 — Logical Temperature: Formal Grounding and Verdict

**Date**: 2026-08-25
**Status**: RESULT — Boltzmann ensemble formalised in Lean; Landauer-calibrated
Kelvin value derived as an explicitly conditional theorem.

## 1. The question

Can "the temperature of paraconsistent logic" be given formal grounding —
and if so, what is it in Kelvin?

`ThermodynamicBridge.lean` §10 disclaims: *"CD steps are temperatures (no
thermal bath, no Boltzmann distribution)."* This note records the scrutiny
of that disclaimer. Verdict up front: **the disclaimer was right about
physics and too modest about structure.** The Boltzmann distribution was
already present in the codebase, unnamed.

## 2. The audit (Phase 1)

Two parallel friction implementations existed:

| Source | Definition | Γ₄ (Paraconsistent) |
|---|---|---|
| `Friction.lean` / `_cd_step_friction_density` | Γ_k = k + strut²·[k≥3] | **20** |
| `_wfc.py::friction_density(lt)` | dimension_index proxy: min(dim,7)+16 | up to 23 |

**Decision**: the CD-step Γ is authoritative. Every proven theorem
(`potential_phase_change_ratio`, both bridge maps, the AMM factorisation)
is stated in terms of it, and it derives from the algebra
(strut_weight = 4 from the (e₁,e₂,e₄) associator norm). The
dimension_index version is a labelling heuristic for LogicType-tagged
nodes and remains flagged as a known divergence in `_wfc.py`.

## 3. What was formalised (`LaserCortex/LogicalTemperature.lean`)

Three distinct quantities, now named and never conflated:

1. **Control temperature** = CD step. Plays exactly T's variational role:
   scales the excess slope without moving the equilibrium (identity
   `controlMap`, ThermodynamicBridge).
2. **Logical energy** = Γ_k. Γ₀=0, Γ₁=1, Γ₂=2, Γ₃=19, Γ₄=20.
3. **Ensemble temperature** = β⁻¹ of the Boltzmann ensemble below.

### Theorems proven (all axiom-checked: propext + Classical.choice + Quot.sound only)

- `weight_ground_state` — **Classical logic has unit weight under every β**.
  Boolean logic does not pretend T = 0; it *is* the zero-energy vacuum.
- `sum_boltzmannProb_eq_one`, `weight_pos` — the ensemble is a genuine
  probability distribution over CD steps {0..K}.
- `lower_energy_more_probable` — exponential suppression at positive β.
- `beta_identifiable` — **β is uniquely determined by any observed
  frequency ratio between two logics.** Temperature is measurable, not
  posited. This is the theorem that elevates the analogy to structure:
  if you can sample logic choices, you can read a thermometer off them.
- `paraconsistent_supercritical` — CD 4 > critical point 3. Paraconsistent
  logic operates above the *proven* phase transition
  (`potential_phase_change_ratio`: Φ jumps by factor > 9).
- `paraconsistent_friction` — Γ₄ = 4 + strut_weight² = 20, exactly.
- `classical_absolute_zero` — under any Landauer calibration,
  `T(Classical) = 0 K`.
- `paraconsistent_barrier_temperature` — conditional on an explicit
  `LandauerCalibration` hypothesis: **T_para = 20 · T_op · ln 2**.

## 4. The number

Under the Landauer anchor (1 friction unit ≡ 1 bit-erasure ≡ k_B·T_op·ln 2
joules), at T_op = 300 K (`scripts/logical_temperature.py`):

| cd | Regime | Γ_k | P(k) at β=1 | T_barrier |
|----|--------|-----|-------------|-----------|
| 0 | Classical (vacuum) | 0 | 0.665 | **0 K** |
| 1 | Fuzzy | 1 | 0.245 | ≈ 208 K |
| 2 | Intuitionistic | 2 | 0.090 | ≈ 416 K |
| 3 | Quantum (critical) | 19 | 5.6×10⁻⁹ | ≈ 3 951 K |
| **4** | **Paraconsistent** | **20** | **2.1×10⁻⁹** | **≈ 4 159 K** |

**T(paraconsistent) ≈ 4 158.88 K** — barrier energy ≈ 0.358 eV, about 31%
of silicon's bandgap (13 200 K). Hot enough to melt every metal an alchemist
had; cold enough that digital computation's own thermodynamic margin dwarfs
it by a factor of three.

At the WFC's implicit β = 1, classical logic is ~4.9 × 10⁸ times more
probable than paraconsistent logic per sample. Paraconsistency is not
merely expensive; at room ensemble temperature it is *thermodynamically
invisible* unless propagation eliminates all associative candidates first
— which is precisely what the WFC constraint propagator does.

## 5. What it means (dealing with the disclaimer)

1. **The identity control map is vindicated, not weakened.** The bridge's
   `controlMap cd := cd` claimed cd plays T's role; `beta_identifiable`
   shows the ensemble built on that identification has a measurable
   parameter. The correspondence is now a statistical-mechanical object,
   not just a variational pun.
2. **LC's logical temperature is richer than physical temperature at one
   point**: it has a proven critical point (CD 2→3, ratio 9.5) where the
   toy CALPHAD model provably has none. We have a temperature whose phase
   transition is machine-checked.
3. **The Kelvin figure is honest but conditional.** Change the anchor and
   the number moves; every ratio (Γ₄/Γ₂ = 10, the ladder spacings, the
   supercriticality relation) survives unchanged. The Lean module keeps
   this separation syntactically: no Kelvin claim exists outside a
   `LandauerCalibration` hypothesis.
4. **Physical prediction available if wanted**: if some substrate (an LLM's
   sampling logits over reasoning modes, a p-bit array, a VSM loop) samples
   logic regimes with frequencies f_i, then β̂ = ln(f_c/f_p)/(Γ_p − Γ_c)
   estimates its logical temperature. A system that frequently "goes
   paraconsistent" is measurably hotter than one that never does. This is
   falsifiable in the only sense available to us: run the sampler, check
   the ratios are exponential in Γ.

## 6. Known issues / follow-ups

- **Pre-existing build breakage** (unrelated, exposed by toolchain change):
  `SplitQuaternionClifford.lean` (invalid import position) and
  `CayleyDickson.lean` (unknown identifiers `add_eq_sca`, `mul_eq_scm`)
  fail under lean v4.31.0-rc1 + current Mathlib cache. The umbrella
  `lake build LaserCortex` target therefore fails even though
  `LaserCortex.LogicalTemperature` and its dependency chain build clean.
- Toolchain realigned to Mathlib's pin (`v4.31.0-rc1`); `mathlib4 → mathlib`
  symlink restored; `require mathlib` moved last in `lakefile.toml` per
  cache-tool requirement.
- `_wfc.py`'s dimension_index proxy vs CD-step Γ divergence: unresolved by
  design (runtime behaviour change out of scope); flagged inline.
- Open question for a future note: is there a *thermal bath* analogue? The
  WFC candidate set under propagation constraints may play the reservoir;
  if so, fluctuation-dissipation-style identities could be sought between
  acceptance-rate variance and β.

## Cross-refs

- `LaserCortex/LogicalTemperature.lean` — the formalisation
- `scripts/logical_temperature.py` — numerical mirror & ladder
- `docs/gemini-flash-3-7_on_logic_temperature.md` — E = k_B T recipe,
  bandgap/Landauer anchors
- `ThermodynamicBridge.lean` §10 — the disclaimer under scrutiny
- Lab note 038 — the original cd-as-control-temperature correspondence
