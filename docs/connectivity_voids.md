# Connectivity Voids — Next Dev Targets

Identified from dependency graph analysis (Phase 2 completion check).

## 1. 🟥 `heightMap_monotone` sorry (FrictionLagrangian.lean:397)

The **only active `sorry`** in the Lean codebase. `frictionDensity` is the cost function used across the entire framework — the Python WFC propagator mirrors it in `friction_density()`. Without this proof:

- The barrier theorem `friction_barrier_across_cd23` (line 439) has no grounding: it uses `assocDefect_zero_up_to_cd2` and `assocDefect_positive_for_cd3plus` which are proven from the definition, but the *global* monotonicity that justifies treating `frictionDensity` as a height map is missing.
- The WFC module's weight function `_logic_weight(lt) = exp(-friction_density(lt))` is empirically correct but formally unconnected to the Lean side.
- The continuous→discrete dictionary (Section 9) remains a comment, not a theorem.

**Fix**: Case analysis on (j ≤ 2, k ≤ 2, j ≥ 3, k ≥ 3) with `omega`. See `docs/connectivity_voids.md` for proof sketch.

**Status**: 🟡 In progress.

---

## 2. 🟡 `normalizeAcross` and `temporalNormalize` are identity functions

- `LogicMonad.lean:222` — `normalizeAcross` returns input unchanged
- `InstitutionalClosure.lean:111` — `temporalNormalize` returns input unchanged

Together these mean the **institutional closure pipeline** (Temporal → Fuzzy → Deontic) is scaffolded but not operational. The BlamePool from `blackboard_to_events` is a commutative sum with:
- No temporal ordering (temporalNormalize is identity)
- No fuzzy grading (fuzzyGrade doesn't exist yet)
- No deontic update (deonticUpdate doesn't exist yet)

Related: `SplitQuaternionClifford.lean:206` — the deferred `Mul` instance and `norm_mul` proof. The split quaternion algebra Cl(1,1) that underlies temporal normalization isn't fully wired — its multiplication and norm properties are placeholders.

**Fix path**: Prove `norm_mul` for Cl(1,1) → implement `temporalNormalize` as `contracts_to_rightComb` under Temporal → implement `normalizeAcross` as multi-logic normalization.

**Status**: 🔴 Deferred (depends on Cl(1,1) algebra being complete).

---

## 3. 🟡 `WrappedProblem.proof` is type-level placeholder

`Problem.lean:83`: `proof : LogicContraction lt tree target`

But `LogicContraction` is defined as `EMLRegistry.contracts_to` for all 15 logic types (LogicTypes.lean:198-213). There are no logic-specific contraction relations. Every WrappedProblem carries the same proof type — "it contracts in the Tamari lattice" — regardless of which logic supposedly resolves it.

This means:
- The cost field is the only distinguishing factor between logic resolutions
- The proof field carries no logic-specific information
- The `liarCost`-style functions are hand-mapped numbers, not derived from contraction structure

**Fix path**: Define logic-specific contraction relations (at least for Classical/temporal/paraconsistent) and prove they differ. This is the work deferred in LogicTypes.lean Section 10 (commented-out "Future Extensions").

**Status**: 🔴 Deferred (major undertaking — essentially Phase 3).

---

## 4. 🟡 Generation.lean not in librarian index

The dependency graph has 137 modules but `Generation` (and `FrictionLagrangian`, `SplitOctonionCost`, `SplitQuaternionClifford`) are absent. The index wasn't refreshed after Phase 2. Cross-layer queries (e.g. "which module proves the emptiness roundtrip?") return nothing.

On the Python side, `_bridge.py` has generation fields in `LiftResult` but:

- `generation_summary` is human-readable only — not consumed by any downstream
- `temporal_tree` is built but never fed back into the NormCode orchestrator
- The loop ZD → inflate → temporal_conflate → revise → re-collapse is **not closed**

**Fix path**: Re-run the pipeline (just pipeline-incremental LaserCortex) to index the new modules. Then wire `temporal_tree` as a suggestion to the orchestator for the next inference cycle.

**Status**: 🟡 Quick fix (pipeline re-index) + medium fix (close the loop).

---

## 5. 🟢 `inflate` default case masks unclassified problems

`Generation.lean:218`: `| _ => ⟨.Classical, .Classical⟩`

7 of 13 ProblemClasses produce the trivial pair (both poles Classical). These include:
- vagueness (should be Fuzzy)
- deontic conflict (should be Deontic)
- empty reference (should be Free — already defined!)
- infinity (should be Infinitary)
- modality (should be Modal)
- constructive (should be Intuitionistic)
- metaParadox (should be... meta — Free or Classical?)

The trivial pair means `revise` produces an empty Superposition (zero divisor) for these cases — no content-bearing pole survives.

**Fix path**: Fill in each case with the correct native logic type, mirroring the ProblemClass specification. `Free` for `emptyReference` is already mapped in LogicTypes; the fix is just adding the case.

**Status**: 🟢 Low-hanging fruit (one line per case).

---

## Priority

| # | Target | Effort | Impact | Why now |
|---|--------|--------|--------|---------|
| 1 | `heightMap_monotone` proof | ~30 min | Framework-wide | Unblocks the only `sorry` |
| 2 | Re-index librarian | ~5 min | Tooling | Makes Phase 2 visible |
| 3 | `inflate` default cases | ~15 min | Surface area | 7 problems currently produce trivial pairs |
| 4 | Close generation loop | Half day | Core loop | Completes the generation/collapse duality |
| 5 | `normalizeAcross` identity | Days | Closure pipeline | Depends on Cl(1,1) algebra |
| 6 | Logic-specific contractions | Weeks | Deep formalization | Phase 3 scope |
