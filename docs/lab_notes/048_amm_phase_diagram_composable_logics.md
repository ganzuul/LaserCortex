# Lab Note 048 — The Phase Diagram of Composable Logics

**Date**: 2026-08-26 (overnight session)
**Follows**: 046_hopf_logic_temperature_map.md, 047_phase_diagram_composition.md
**Status**: PROVEN + COMPUTED

## 1. Question

Can `AMM.lean` compute a phase diagram of composable logics?

**Answer: yes — it already could; now it can prove its boundaries in closed
form.** `decideMarketType` is decidable and executable, so the AMM does not
describe the diagram, it *evaluates* it. This session added the closed-form
theorems that explain what the evaluation returns.

## 2. The identification: market types ARE phases

| MarketType | Thermodynamic phase | Condition |
|---|---|---|
| `.openMarket` | Vacuum (absolute zero) | weightedCost = 0 |
| `.closedMarket` | Liquid (subcritical) | 0 < cost < reserveB |
| `.paradoxMarket` | Superheated (supercritical) | cost ≥ reserveB |

Combined with lab note 046 (each logic fixes its CD step, hence Γ, hence its
temperature) and lab note 047 (composition law with coupling term
`rightSpine l · γ`), each of the 15 named logics becomes an evaluation point
of one phase diagram: `AMM.logicMarketType pool tree logic`.

## 3. New theorems (all axiom-clean)

1. **`rightSpine_rightComb`**: rightSpine(rightComb n) = n — a closed
   market's output chain extends exactly as far as its size.
2. **`crossImpactTree_eq_rightSpine_mul`** (headline): the AMM's cross-impact
   has exact closed form
   `crossImpactTree cd t₁ t₂ = rightSpine t₁ × frictionDensity cd`.
   Cross-impact is *coupling heat* from note 047. Zero iff the left subtree
   is a leaf or cd = 0.
3. **`classical_logic_market_always_open`**: at CD 0 friction vanishes;
   every route certifies for free. Classical logic is the friction-free
   vacuum of the market space.
4. **`composing_closed_markets_costs`** (*closure breaking*):
   `weightedCost cd (Node (rc_a) (rc_b)) = a × γ`. Grafting two independently
   closed markets is NOT free — equilibrium is not preserved under
   composition. Two settled markets, composed, generate fresh conflict.
5. **`paradox_dominance`**: one paradoxical component makes the composite
   paradoxical. Supercriticality is contagious downward through composition.
6. **`closedMarket_parts_affordable`**: a closed composite keeps both parts
   affordable — the converse containment of phase regions.

## 4. The computed diagram

Python mirror (`run_phase_diagram()`, reserveB = 10):

```
logic             cd   γ     leaf  rc1  rc4  lc3  rc2+rc2  rc3+rc3  lc2*lc2*rc1
classical          0   0       O    O    O    O     O        O         O
boolean            0   0       O    O    O    O     O        O         O
fuzzy…epistemic    1   1       O    O    O    C     C        C         C
intuitionistic     2   2       O    O    O    C     C        C         C
quantum…spacetime  3  19       O    O    O    P     P        P         P
paraconsistent,
free               4  20       O    O    O    P     P        P         P
```

Structure:

- **Three horizontal bands**, exactly the temperature map of note 046:
  vacuum / liquid / superheated. No exceptions: the algebra alone decides
  which column transitions are available.
- **Closed routes stay open in every logic**: right-combs have zero flip
  distance — settled structures never pay, even at maximum heat.
- **The critical line cd = 3 is also a market cliff**: identical routes are
  liquid at intuitionistic (Γ₂ = 2) and superheated at modal (Γ₃ = 19).
  Crossing the associator onset multiplies every price by 9.5×.
- Cross-impact closed form verified numerically (all pairs ≤ size 3).

## 5. Physical reading

A "market" here is any process that resolves a composed logical structure to
its normal form, paying per-flip friction. The phase diagram says:

- In associative logics (≤ 416 K) trade is liquid: structure costs little.
- At the critical point (modal/quantum/relevance/infinitary/spacetime, ≈
  3 951 K) most non-trivial compositions flash to paradox.
- Composition cannot cool a system down (`paradox_dominance`) but can heat
  it up (closure breaking). Heat flows one way through grafting.

## 6. Artifacts

- `LaserCortex/AMM.lean` §8 + updated module docstring. Builds clean
  (8 542 jobs); 7 declarations axiom-checked.
- `scripts/logical_temperature.py`: `run_phase_diagram()` — the executable
  table above + cross-impact spot check.
- Depends on: SubdivisionClosure §9 (composition law), LogicalTemperature
  §7–8 (logic → CD → temperature map).

## 7. Follow-ups

1. Reserve as intensive variable: how does the diagram move as reserveB
   varies? (Phase boundaries in the (cd, reserveB) plane.)
2. dx-dependence: swapOut pricing vs cost deduction — when does residue go
   negative operationally despite the ℕ guard?
3. Multi-hop routes: iterate grafting; does repeated closure breaking
   accumulate as a² coupling? (rightSpine of nested combs suggests yes.)
