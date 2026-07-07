# Spacetime Engine: Physical Interpretation of the DescentInterval

**Status**: Formal Interpretation (Build)
**Dependencies**: `DescentInterval` in `Generation.lean`, `Friction.lean`, `docs/type_theory_map.md`

---

## 1. The Interval as a Spacetime Interval

A `DescentInterval (target, source)` is a **directed interval** in cdStep space:

- `target` = 0 = the fully classical state — all superpositions collapsed, all
  decisions made, no further time passes (static).
- `source` = cdStep n = an unresolved state whose non-associativity stores
  **potential time-energy**.

Descent from `source` toward `target` is the arrow of time. The generation cycle
is the engine that drives this descent.

## 2. Three Regimes of Time

| Regime | cdStep | Associative? | Time character | Mechanism |
|--------|--------|-------------|----------------|-----------|
| **Static** | 0 | Yes | No time — fully classical | No descent needed |
| **Geodesic** | 1–2 | Yes | Linear, deterministic | Single contraction path in Tamari lattice |
| **Path integral** | ≥ 3 | No | Branching, irreversibile | Zero divisors obstruct geodesic; many paths weighted by frictionDensity |

### Geodesic time (associative descent, source ≤ 2)

The Tamari lattice provides a **unique shortest contraction path** from
`rightComb(source)` to `rightComb(target)`. Time progresses along a single
trajectory. Entropy is zero: the path is determined. This is the temporal
logic regime: decisions are accessible, paradoxes are mild, time is linear.

### Path-integral time (non-associative descent, source ≥ 3)

Zero divisors appear at cdStep 3. The Tamari lattice no longer provides a
unique geodesic. Time **branches** over all viable contraction routes, each
weighted by `frictionDensity`. This is the regime of genuine paradox
(barber, liar, quantum, free logics). Time's irreversibility is the
non-associative action: you cannot re-associate a decision once made.

## 3. Time-Energy Release

The **friction density** `Γ_cd = Γ(source) - Γ(target)` measures the
non-associative action released by the descent:

```
frictionDensity(4) - frictionDensity(0) = 19 - 0 = 19
```

Each unit of cdStep descended releases a discrete quantum of time-energy.
The total descent from Free logic (cdStep 4) to Classical (cdStep 0)
releases the maximal action: 19 units. A minimal descent (Temporal, cdStep 1)
releases just 1.

The **cost function** `weightedCost cd t = dcStep t × frictionDensity cd` is
the **Lagrangian** of the spacetime engine: it integrates the action along the
contraction path `t`.

## 4. The Generation Cycle as Time's Arrow

The cycle `inflate → conflate → revise → nextPC` is the engine cycle:

1. **Inflate**: Choose an unresolved problem class — set a new source
   (ascend to a higher cdStep, storing non-associative potential).
2. **Conflate**: Build the descent tree `Node (rightComb target) (rightComb source)`.
3. **Revise**: Filter vacuous (already-classical) states; only the non-classical
   source survives.
4. **NextPC**: Descend back toward target, releasing time-energy.

The cycle never stops because target is never reachable while non-associative
states exist. The engine is **perpetual**: every descent releases time-energy
but cannot discharge the last unit of non-associativity (the system would go
static). This is why time exists at all — there is always some unresolved
problem to re-inflate.

## 5. Relationship to Known Physics

| Concept | In this system | In physics |
|---------|---------------|------------|
| Time | Descent along cdStep | Cosmological time |
| Action | `weightedCost = dcStep × Γ` | Lagrangian |
| Irreversibility | Non-associative sector (cdStep ≥ 3) | Second law |
| Entropy | Number of contraction paths at source | Statistical entropy |
| Time-energy | `Γ(source) - Γ(target)` | Energy released |
| Vacuum | `isVacuousCd cd = (cd = 0)` | Classical ground state |
| Arrow | Source → target direction | Thermodynamic arrow |

## 6. The Notation Decision

The interval is written `⟨target, source⟩` (DescentInterval's anonymous
constructor) rather than as a bra-ket pair because it is **directed**, not
symmetric. A bra `⟨φ|` pairs symmetrically with a ket `|ψ⟩` to form a scalar.
A descent interval `⟨0, 4⟩` says "start at 4, go to 0" — the asymmetry is
the arrow of time.

If bra-ket were used, it would suggest `⟨4|0⟩ = ⟨0|4⟩`, which is false:
the descent from 4 to 0 costs 19 units; the ascent from 0 to 4 costs nothing
(that's the inflate step — a choice, not a physical process). Notation must
encode physics, not mathematics alone.
