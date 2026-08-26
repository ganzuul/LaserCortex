# Lab Note 049 — Loose Coupling: the Risk-Taking Window and the Institutional Triad

**Date**: 2026-08-26 (overnight session, continued)
**Follows**: 047_phase_diagram_composition.md, 048_amm_phase_diagram_composable_logics.md
**Motivated by**: `/home/nos/Nextcloud/prompts/Institutional closure.md`
**Status**: PROVEN + COMPUTED

## 1. Question

Strict coupling pays the full coupling tax `rightSpine l · γ` on every
graft. What happens to the phase boundary when the coupling is *loosened*
by a trust coefficient λ = num/den ≤ 1 — and can we prove that loosening
is safe?

The institutional reading: temporal accumulation, fuzzy grading, and
deontic threshold revision are three institutions that must compose.
Their interaction is never strict — it is mediated by trust, forgiveness,
and discretion. Is that mediation *thermodynamically safe*, or does
looseness let paradox leak into previously-certifiable routes?

## 2. The formal object (`SubdivisionClosure` §10)

```
looseCost cd num den l r =
  (dcStep l + dcStep r) · γ(cd) + (num · rightSpine l · γ(cd)) / den
```

λ = num/den discounts only the **coupling term**, never the bulk:
at λ = 1 this is exactly `weightedCost`; at λ = 0 the subsystems do not
interact at all.

New axiom-clean declarations:

| Declaration | Content |
|---|---|
| `discounted_coupling_le` | discounted term ≤ full coupling (needs `0 < den`) |
| `looseCost_le_weightedCost` | loosening never increases cost |
| `looseCost_discount_exact` | strict − loose **=** S − D, S = rightSpine·γ |
| `looseCost_zero_coupling_free` | λ=0 restores §9 composability of equilibria |
| `rightSpine_rightComb` | spine of right-comb n is n (re-homed from AMM) |

## 3. The market-level invariants (`AMM` §9)

| Theorem | Statement |
|---|---|
| `looseMarketType` | same three phases, evaluated at discounted cost |
| `looseMarketType_paradox_iff` | loose-paradox ⇔ cost ≥ B ∧ cost ≠ 0 |
| **`loose_never_damns`** | loose paradox ⇒ strict paradox. Loosening shrinks the paradox region; it never grows into safe territory |
| **`rescue_envelope_bounded_by_coupling`** | strict − loose ≤ rightSpine l · γ — holds *unconditionally* (proved via `Nat.sub_le`; the hp/hc rescue hypotheses were droppable because the exact identity makes them redundant) |
| `institutional_triad_friction` | temporal = fuzzy = deontic at CD 1; friction density = 1. Zero axioms used |
| `closedMarket_monotone_in_reserve` | tightening reserveB only shrinks the liquid phase (deontic revision flows one way) |

## 4. The institutional triad

From *Institutional closure.md*: temporal accumulation (P₂), fuzzy grading
(P₁), deontic threshold revision (P₆). All three host-logics sit at CD 1 ≈
208 K — **same heat, different Hopf direction**. The triad shares one
friction density, so their phase diagrams differ only through route shape,
not temperature. Institutional readings of the Lean objects:

- **blame pool** = temporal accumulation = long right-comb chains
  (`dcStep(rightComb n) = 0`: a closed market's whole friction sits in its
  output chain);
- **graded soundness** = fuzzy layer (CD 1, subcritical band);
- **threshold revision** = time-varying `reserveB`, governed by
  `closedMarket_monotone_in_reserve`.

## 5. Computed sweep (`scripts/logical_temperature.py::run_loose_coupling_sweep`)

reserveB = 10, triad algebra (γ = 1), grafts of long-chain closed markets:

```
    λ |     temporal⊗fuzzy      fuzzy⊗deontic   deontic⊗temporal
   0.00 |                  O                  O                  O
   0.25 |                  C                  C                  C
   0.50 |                  C                  C                  C
   0.75 |                  C                  C                  C
   1.00 |                  P                  C                  P
```

At λ = 1 the long blame chains are damned (paradox); discretion ≤ ¾
certifies them — the risk window is real and asymmetric (the short side
`rc4 ⊗ rc12` stays liquid even strictly).

Exhaustive check over 260 tree pairs × λ ∈ {0, ¼, ½, ¾, 1} (1300 states):

```
    rescues (P→C/O under loosening):        64
    damnation violations (must be 0):       0     ← loose_never_damns
    risk-envelope violations (must be 0):   0     ← rescue_envelope
```

**Rescue without damnation holds empirically and is proven in Lean.**

## 6. Session mechanics / gotchas

1. Three compile errors fixed in SubdivisionClosure §10: (a)
   `Nat.mul_div_cancel_left` needed left-associated `den * (s*g)` — fixed
   via explicit `Nat.mul_assoc` step in h2/h3; (b) unused `hden` in
   `looseCost_zero_coupling_free` — hypothesis dropped entirely
   (numerator 0 needs no positivity); (c) stray anonymous `end` — Lean 4
   requires the NAMED form to close a namespace (`end SubdivisionClosure`);
   anonymous `end` only closes sections.
2. `split_ifs` on an iff goal reduces the if inside the LHS but leaves the
   raw Iff structure — `iff_of_false`/manual `⟨_,_⟩` with known expected
   types beat `iff_of_true` with metavariable `b`.
3. `omega` failed spuriously on the risk envelope (nat-sub of two atoms +
   division atom); the exact identity `looseCost_discount_exact` plus
   `Nat.sub_le` closed it without arithmetic search — prefer rewriting by
   an exact lemma over omega when nat-subtraction of compound terms is
   involved.
4. `lake build LaserCortex.SubdivisionClosure LaserCortex.AMM` succeeds;
   default `lake build` still fails on missing `Main.lean` (pre-existing).
5. Python note: `dcStep(rightComb n) = 0` — demo grafts must use LONG
   chains (n ≥ reserveB) for the strict phase to be paradox.

## 7. Next steps

- Time-varying reserveB as an explicit deontic process: a sequence of
  pools with monotone thresholds and the induced filtration of phase
  diagrams.
- λ not as constant but as *earned* trust: λ(state) driven by accumulated
  blame-pool balance — connects to the temporal logic's accumulation
  operator.
- The zero-axiom proof `institutional_triad_friction` suggests the whole
  CD-1 band might admit rfl-level reasoning; check how much of §9
  survives at `rfl`.
