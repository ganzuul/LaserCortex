# Seminar Talk Outline — Math Faculty (30 min)

**Title** (sober): *"A graded cost function on the Tamari lattice of
Cayley–Dickson composition, formalized in Lean"*
**Subtitle** (only if asked): *a thermomechanical reading of non-associative syntax*
**Audience:** pure/applied math faculty. Assume comfort with lattices and
binary trees; do NOT assume Cayley–Dickson familiarity.

---

## Slide 1 — The object (2 min)

One picture: a binary tree = the syntax of a bracketed product
`((ab)c)` vs `(a(bc))`. Define `EMLTree`, the rotation
`Node (Node a b) c ↦ Node a (Node b c)`, and the **right comb** as the normal
form. State plainly: *this is the Tamari lattice / associahedron skeleton.*

## Slide 2 — The question (2 min)

*"How much does it cost to re-associate?"* Define `dcStep t` = number of
rotations to the right comb = number of inversions = **the rank** in the
Tamari lattice. Cite: gradedness is classical; I am not claiming it.

## Slide 2b — Why now: the quantum substrate (2 min)

One slide, three bullets, each one sentence (full argument in
`quantum_relevance.md`):
- **Topological QC:** fusion of non-abelian anyons is non-associative up to an
  F-matrix; the pentagon equation *is* the associahedron, and re-association
  cost = F-move depth.
- **Compilation:** re-bracketing a gate product to match couplings is synthesis
  overhead; `dcStep` is its lower bound.
- **Octonions:** the tower reaches them at CD 3 — exactly where our cost jumps.
Say explicitly: *"this is motivation; the theorems I prove are combinatorics."*

## Slide 3 — The friction functional Γ (3 min)

Define `frictionDensity k`, the per-rotation weight at Cayley–Dickson level k.
State the sequence and **the single jump at k = 3** (Γ₂=2 → Γ₃=19), tied to
the associator turning on at the split octonions. This is the talk's pivot:
one clean, checkable fact.

## Slide 4 — THE COMPOSITION LAW (4 min) ★

Statement: `dcStep (Node l r) = dcStep l + dcStep r + rightSpine l`.
Read it out loud in English: *cost is additive in the parts, plus a coupling
term equal to the right-spine depth of the left subsystem.* Show the Lean
statement (2-line induction, no `sorry`). Emphasize the corollary
`weightedCost_mixed_dominance`: mixing two regimes evaluates at the hotter one.

## Slide 5 — What is new vs. known (2 min) ★★ HONESTY SLIDE

Two columns. **Known:** Tamari gradedness, right comb uniqueness, associahedron
combinatorics. **New here:** (i) the exact composition identity with the
coupling term, machine-checked; (ii) the Γ functional with the CD-3 critical
point; (iii) the potentiality theorem (Slide 8); (iv) the whole thing is
*formalized* — every theorem is a Lean certificate. Say the sentence:
*"The physical story motivates the definitions; the theorems are pure
combinatorics."*

## Slide 6 — Regime collapse (3 min)

`weightedCost` = Γ · dcStep collapses to two closed forms:
`cd·dcStep` (associative band) and `(cd+16)·dcStep` (non-associative band),
monotone in cd, zero iff right comb. One line each in Lean.

## Slide 7 — The critical point, sharpened (3 min)

The jump at CD 3 is robust: modal logic sits *exactly* at CD 3; paraconsistency
(CD 4) requires the 4159 K barrier. Frame as: **the non-associative transition
is a first-order discontinuity in a single integer parameter.**

## Slide 8 — The potentiality theorem (4 min) ★

**Theorem** (`TamariMetric.dcStep_eq_geodesic`): `dcStep t` is the minimal
number of rotations to reach the right comb — the greedy count *is* geodesic.
**Proof sketch:** each rotation drops `dcStep` by at most 1
(`dcStep_contracts_one_le`), so any path needs ≥ `dcStep` steps; the greedy
recursion realizes exactly that many. Two lines of Lean once the one bound is
in hand. The exhaustive check (196 trees, size ≤ 6) is a *confirmation*.

## Slide 9 — A lightcone inversion at CD 3 (3 min)

**Figure:** `plots/lightcone_census.png` (and `plots/friction_barrier.png` for
the Γ jump). The census (all 196 size-6 routes classified against
⟨dcStep,dcStep⟩ = dcStep² − γ²): at cd ≤ 2 routes are mostly timelike; at cd ≥ 3
the entire population is spacelike. The critical point reappears as a
**population-wide lightcone inversion** — independent evidence the distance
layer and the mass-classification layer describe one geometry.

## Slide 10 — Open problems (3 min)

1. C5 minimality/uniqueness: any C2-satisfying metric is dominated by d.
2. Formalize C2 (graded-lattice argument).
3. Strain/stress dictionary: strain = Tamari distance, stress = friction work.
4. Does the coupling term `rightSpine l` have an invariant (geometric) meaning?
5. **Formalize the anyon correspondence** — state `contracts_one` = F-move
   against a concrete fusion-category model (e.g. Fibonacci anyons) and audit
   the pentagon identity against the Tamari rotation in Lean.

## Slide 11 — Why Lean (1 min)

The failure mode here is an off-by-one in the recursion. The checker is the
referee for the tedious cases. 8,500-line build, axiom-clean.

---

**Appendix slides (have ready, show only if asked):** loose-coupling Hooke
law, the AMM market invariants, the full temperature map. Do NOT put them in
the main line — they are the interpretive layer.

**Key discipline:** never say "temperature of logic" in the main line; if the
word "heat" appears it is only as the motivating analogy on Slide 3. And never
let the anyon/compilation mapping (Slide 2b) be stated as a result — it is a
hypothesis with a formalization path, and you must say so the moment you state
it.
