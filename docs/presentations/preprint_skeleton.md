# Preprint Skeleton — positioning and novelty claims

**Working title.** *The cost of re-association: a graded lattice invariant of
Cayley–Dickson composition, formalized in Lean*

**Target venues (ranked).** (1) combinatorial algebra / discrete mathematics
(e.g. *Order*, *Electron. J. Combin.*, *J. Symb. Comput.* for the
formalization angle); (2) CS-logic venues for the formal-methods angle;
(3) foundations/philosophy venues only for the interpretive layer (separate
paper or discussion section).

---

## §1 Introduction

- Motivate: non-associative algebra is everywhere in Cayley–Dickson (quaternions,
  octonions, sedenions) but its syntax (bracketing) is rarely given a metric.
- Motivate the *application*: re-association cost is F-move depth in topological
  quantum computation and compilation overhead in circuit synthesis — the same
  combinatorial quantity appears in both (see quantum_relevance.md §1).
- State the three contributions up front, honestly scoped.

## §2 Preliminaries

- `EMLTree`; rotation `contracts_one`; right comb; Tamari lattice, its gradedness
  and rank (cite Knuth / Tonks / associahedron literature).
- Cayley–Dickson tower and the associator's first nontrivial appearance at level 3.

## §3 The cost function and the composition law

- `dcStep`, `rightSpine`; **Theorem** `dcStep (Node l r) = dcStep l + dcStep r +
  rightSpine l` (with proof sketch: the coupling telescopes through the rotation
  recursion).
- Corollaries: superadditivity; equality iff left leaf; `rightSpine (rightComb n)
  = n`.
- **Novelty note:** state explicitly which of these are folklore-but-unrecorded
  and which are new. Do not overclaim.

## §4 The friction functional and the critical point

- `frictionDensity`; the two-regime collapse; monotonicity; the unique jump
  Γ₂→Γ₃ = 2→19.
- **Theorem** `weightedCost_mixed_dominance` (mixing evaluates at the max).
- Locate the critical point against the associator (`associatorCostTree_eq_frictionDensity`).

## §5 The metric conjecture (C2) and computational evidence

- Conjecture: `weightedCost cd t = d(t, rightComb (t.size))`.
- Exhaustive verification (sizes 1–6, 196 trees, Dijkstra); triangle inequality;
  discrimination against discrete/size metrics.
- The lightcone census and the CD-3 inversion.
- **Honesty requirement:** this section is *evidence*, not proof; the graded
  argument is flagged as the path to a formal proof.

## §6 Formalization

- Lean 4, mathlib; statement list; axiom audit (`propext`, `Classical.choice`,
  `Quot.sound` only); build instructions. This is a contribution to reproducible
  combinatorics.

## §7 Quantum-computing applications (motivation, not result)

- F-move depth: `dcStep` = minimal associator applications = fusion overhead in
  a braided fusion category; the pentagon equation = the associahedron coherence.
- Compilation lower bound: `dcStep` bounds re-bracketing overhead in gate
  synthesis; the two-regime collapse (linear in associativity defect) parallels
  the Clifford/non-Clifford split.
- The octonion boundary: CD 3 = the first non-associative level = the octonions;
  Γ₂=2 → Γ₃=19 quantifies the cost step in Landauer units (4159 K barrier).
- **Explicit framing:** these are *correspondences proposed for later
  formalization*, not theorems of this paper. The paper proves the
  combinatorics; this section motivates it.

## §8 Related work

- Tamari lattice / associahedron (classical); tropical geometry (Develin–Sturmfels
  quantized types — see lab notes 019/021); thermodynamics of computation
  (Landauer); metric-space approaches to computation (if any exist, cite);
  topological quantum computation (Kitaev; F-matrix / pentagon coherence);
  black-hole/qubit correspondence (Duff–Stoica et al.).

## §9 Open problems

- C5 minimality/uniqueness; invariant meaning of `rightSpine`; extension to
  higher arities / operads; the physical temperature reading as a genuine
  correspondence (separate, speculative); **formalizing the anyon
  correspondence** (`contracts_one` = F-move) against a concrete fusion model.

**Appendices.** Full Lean statement list; the phase-diagram table; the lightcone
census data.

---

### Novelty ledger (fill honestly before submission)

| Claim | Status | Evidence |
|---|---|---|
| Exact composition identity (coupling = rightSpine) | likely folklore, unrecorded | Lean proof; literature search pending |
| Γ functional with CD-3 jump | new framing of known associator fact | Lean; note 045–048 |
| C2 potentiality (cost = geodesic) | **proven** (Lean, `TamariMetric`) | `dcStep_eq_geodesic`; exhaustive check ≤6 confirms |
| Lightcone inversion at CD 3 | new observation | census; interpretation-bound |
| Full machine-checked formalization | methodological contribution | axiom audit |
| `dcStep` = F-move depth (anyon correspondence) | proposed hypothesis, **not** claimed | quantum_relevance.md §1; formalization open |
