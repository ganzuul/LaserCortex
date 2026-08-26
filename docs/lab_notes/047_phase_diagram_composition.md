# Lab Note 047 — Composing Phase Diagrams: The Coupling Law

**Date**: 2026-08-26 (overnight session)
**Follows**: 046_hopf_logic_temperature_map.md, 031_ic_is_regular_subdivision.md
**Status**: PROVEN + MIRRORED

## 1. Question

Lab note 046 gave every named logic a temperature (the algebra axis).
`SubdivisionClosure.lean` gives every *tree* an energy
(`weightedCost cd t = dcStep(t) × frictionDensity(cd)`). Do phase diagrams
compose? I.e., when two subsystems are grafted into one, what law relates
the composite phase point to the parts?

## 2. The discovery: an exact composition law

Numerical exploration (exhaustive to size 5, plus 20k random pairs to size 9)
revealed that the flip count obeys a clean three-term law:

    dcStep(Node l r) = dcStep l + dcStep r + rightSpine l        (*)

where `rightSpine l` is the depth of the rightmost leaf of `l`. This is now
theorem `SubdivisionClosure.dcStep_node_compose`, proven by structural
induction — the coupling term telescopes exactly through the rotation
recursion. Verified in the mirror at 64/64 pairs.

## 3. Reading it physically

The energy functional has equation-of-state shape **extensive × intensive**:

    E(cd, t) = N(t) · γ(cd),   N = dcStep (flips needed), γ = frictionDensity

Law (*) says composition of subsystems gives:

    E(composite) = E₁ + E₂ + rightSpine(l) · γ(cd)

- **Extensive part**: flip counts add.
- **Coupling term**: proportional to how deep the *left* subsystem's output
  chain (`rightSpine`) extends. Composition is free iff the left system is
  the vacuum (`Leaf`) — proven as `dcStep_node_eq_iff_left_leaf`.

Corollaries (all proven, axiom-clean):

1. `dcStep_node_superadditive` / `weightedCost_node_superadditive` /
   `treeTemp_node_superadditive`: **energy and temperature are
   superadditive** under grafting. A composite is never cooler than the sum
   of its parts; the excess is pure coupling heat.
2. `weightedCost_mixed_dominance`: composing systems living at different CD
   steps evaluates at the hotter algebra — **mixing can only heat up**. The
   phase of the composite is the max of the phases; split-sector components
   dominate associative ones.

## 4. How phase diagrams compose

Given the energy surface E(cd, n) = n·γ(cd) over (algebra cd, structure n):

- **Axes**: horizontal = algebraic regime (temperature source, intensive);
  vertical = subdivision depth (structure, extensive).
- **Phases**: vacuum line n=0 (absolute zero everywhere); associative wedge
  cd ≤ 2 with slope γ = cd; critical vertical at cd = 3 (unique jump,
  lab note 046 §4); split region slope γ = cd + 16.
- **Composition rule** (new): to merge two diagrams, add the extensive
  coordinates, take the max of the intensive coordinates, and pay coupling
  `rightSpine(l₁) · γ(max)`. Phase boundaries therefore compose by
  inheritance: the composite diagram's boundary set is the union of the
  parts' boundaries shifted by the coupling offset.

This is precisely Gibbs-style composition: extensive variables add,
intensive variables equalize at the dominant value.

## 5. Why rightSpine?

The rotation recursion `Node(Node a b) r → Node a (Node b r)` moves material
rightward; each application consumes one node off the left spine. When
grafting `l` onto `r`, every node along `l`'s right spine must eventually be
rotated past the graft point — that traversal count IS the right-spine depth.
The coupling term is not ad hoc; it is forced by the recursion.

## 6. Artifacts

- `LaserCortex/SubdivisionClosure.lean` §9: `rightSpine`,
  `dcStep_node_compose`, `dcStep_node_superadditive`,
  `dcStep_node_eq_iff_left_leaf`, `weightedCost_node_superadditive`,
  `frictionDensity_le_max`, `weightedCost_mixed_dominance`, `treeTemp`,
  `treeTemp_node_superadditive`. All axiom-checked ([propext,
  Classical.choice, Quot.sound] only); builds clean (8 541 jobs).
- `scripts/logical_temperature.py`: `run_composition_law_check()` —
  exhaustive mirror verification, prints with the ladder.
- False lead recorded: the tempting bound
  `dcStep(Node a b) ≤ 1 + dcStep a + dcStep b` is FALSE (counterexamples from
  size 3 up); the correct law (*) supersedes it.

## 7. Follow-ups

1. Left-graft dual: what does `Node` on the other side cost? (Symmetric
   question — expect leftSpine coupling.)
2. Coupling heat as an observable: can `treeTemp(Node t₁ t₂) − treeTemp(t₁)
   − treeTemp(t₂)` be measured in the WFC layer?
3. Multi-way composition: associativity of the coupling term (graft order
   independence) — likely reduces to rightSpine additivity along spines.
