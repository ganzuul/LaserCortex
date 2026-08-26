# Lab Note 052 — C2 proven: `dcStep` is the geodesic distance

**Date**: 2026-08-26
**Follows**: 051_right_metric_decision_procedure.md
**Module**: `LaserCortex.TamariMetric.lean` (new)
**Status**: PROVEN — the potentiality conjecture (C2) is now a theorem, not a conjecture.

## 1. What closed

Note 051's headline open problem — *formalize C2 (graded-lattice argument)* — is
done. The claim was:

> `dcStep t` = the minimal number of `contracts_one` rotations to reach the
> right-comb normal form `rightComb t.size`.

This was computationally verified (exhaustive, sizes 1–6) but not proven. It is
now a Lean theorem, with **no `sorry`, no axioms**.

## 2. The key insight (why "at most 1", not "exactly 1")

A `contracts_one` step does **not** always drop `dcStep` by exactly 1. A
rotation in the *left* subtree changes the right spine and can leave `dcStep`
unchanged (e.g. `Node (Node (Node .Leaf .Leaf) .Leaf) .Leaf` and its left
rotation both have `dcStep = 2`). The correct bound is:

**`dcStep_contracts_one_le`** — `contracts_one s t → dcStep s ≤ dcStep t + 1`
(each rotation drops `dcStep` by **at most** 1).

Combined with the pre-existing `dcStep_contracts_one` (drops by at least 0),
every step drops `dcStep` by exactly 0 or 1. Since `dcStep (rightComb n) = 0`,
any path from `t` to the right comb takes at least `dcStep t` steps, and the
greedy recursion realizes exactly `dcStep t` steps. Hence `dcStep` *is* the
geodesic distance.

## 3. The proof structure

All in namespace `TamariMetric`, importing only `LaserCortex.foundations.Tamari`:

**The crux (per-step bound).**
- `dcStep_right_add_one` — right-context propagation with slack 1
  (induction on the wrapper `l`).
- `dcStep_rotate_add_one` — a root rotation increases `dcStep` by *exactly* 1.
- `dcStep_node_left_contracts_le` — left-context propagation (induction on the
  `contracts_one` derivation, using `dcStep_rotate_identity`).
- `dcStep_contracts_one_le` — the "at most 1" bound.

**Step-counted reachability.**
- `ContractsToSteps s t n` — a chain of exactly `n` rotations (`s` to `t`).
- `ContractsToSteps_node_right` — right-context lift preserves the count.

**Minimality and achievability.**
- `dcStep_le_contracts_to_steps` — lower bound: any `n`-step path satisfies
  `dcStep s ≤ dcStep t + n`.
- `dcStep_le_path_to_rightComb` — specialization: any path to the right comb
  needs ≥ `dcStep t` steps.
- `contracts_to_steps_of_dcStep` — achievability: the greedy reduction (a
  well-founded `def` mirroring `dcStep`, terminating on the measure
  `leftWeight t + t.size`) reaches the right comb in exactly `dcStep t` steps.

**The theorem.**
- `minimal_path_length_eq_dcStep` — achievable ∧ lower bound.
- `dcStep_eq_geodesic` — `IsLeast {n | ContractsToSteps t (rightComb t.size) n} (dcStep t)`:
  `dcStep t` is the unique minimal path length.

## 4. What this means for the metric arc

`dcStep` is now certified as the **rank function of the Tamari lattice** — a
graded-lattice invariant, not merely a greedy heuristic. Since
`weightedCost cd t = frictionDensity cd · dcStep t` (SubdivisionClosure), the
γ-weighted cost `weightedCost` is γ times the geodesic distance, exactly as
C2 required. The Tamari graph metric is now grounded in a theorem, and the
computational sweep (note 051) is a *confirmation*, not a substitute.

## 5. Remaining open problems (updated ledger)

| # | Problem | Status |
|---|---|---|
| C2 | `dcStep` = geodesic (graded-lattice argument) | **DONE** (this note) |
| C5 | minimality/uniqueness: any C2-satisfying metric is dominated by `d_γ` | open |
| C3 | restate envelope/Hooke theorems as Lipschitz / ball statements | open |
| — | invariant meaning of `rightSpine l` (survive to higher arities?) | open |
| — | formalize the anyon correspondence (`contracts_one` = F-move) vs Fibonacci fusion | open |

**Next target**: C5 (minimality). With `dcStep` certified as the rank, the
natural statement is a *universal property*: `d_γ` is initial among metrics
making the cost 1-Lipschitz. This is now a Lean theorem in reach, since the
lower-bound machinery (`dcStep_le_contracts_to_steps`) is the exact ingredient.
