# Lab Note 012: Structural Proof Uplift to Mathlib

**Date**: 2026-06-28
**Angle**: Replace ~420 lines of manual structural induction with mathlib's `Relation.ReflTransGen`, `Relation.EqvGen`, `PartialOrder`, and `HopfAlgebra` — ending with the antipode of institutional closure canonized as a Hopf algebra on `LogicM`.
**Status**: Plan — ready for `/lean4:golf` and `/lean4:refactor` passes, all revertable.

---

## 1. Motivation

The LaserCortex formalization (3,437 lines across 6 core `.lean` files) contains several independently re-invented wheels:

- **Two** reflexive-transitive closures: `contracts_to` (EMLRegistry.lean) and `Reachable` (PosetQuotient.lean), both isomorphic to mathlib's `Relation.ReflTransGen`
- **Two** equivalence relations: `SymReachable` (PosetQuotient.lean) and its associated `setoid`, both isomorphic to `Relation.EqvGen`
- **One** manual partial-order proof via a custom `leftWeight` well-founded measure (EMLRegistry.lean), where mathlib's `WellFounded` + `Measure` provides the framework
- **One** free monad (`LogicM`) manually defined with monad laws proved by structural induction, which could become a `HopfAlgebra` instance connecting the antipode of institutional closure to mathlib's ring theory
- **One** remaining sorry (`identity_zero_divisor_contradiction` in LiarParadox.lean:121) — the formal boundary where the antipode fixed point (`e₀ = 0`) lives

Each of these manual constructions was written for good reason during early development: they minimized cross-package dependencies and kept the build fast. Now that the framework is stable (single sorry, zero axiom leaks), we have a window to **uplift to canonized mathlib** — replacing hand-rolled structural proofs with mathlib's well-maintained, community-vetted alternatives.

**Why now**: The last commit (24afc15) canonized `IdentityZeroDivisor` and filled `OWLAtom.le_antisymm`. The remaining sorry is a design choice (the Liar's self-referential gap). No new structural work is pending — the architecture is stable. Golfing now means cleaner cross-refs when we add Hopf algebra structure for the antipode of institutional closure.

## 2. The Five Passes

### Pass 1: `ReflTransGen` migration

**Files**: `EMLRegistry.lean` (~80 lines removed), `PosetQuotient.lean` (~200 lines removed)

| Current definition | mathlib replacement |
|---|---|
| `contracts_to` (inductive, refl+step) | `Relation.ReflTransGen contracts_one` |
| `contracts_to_trans` (8-line proof) | `Relation.ReflTransGen.trans` |
| `contracts_to_node_left`/`right` (30 lines each) | `Relation.ReflTransGen` mono lifting |
| `Reachable` (inductive, refl+step) | `Relation.ReflTransGen M.step` |
| `Reachable.transitive` (10-line proof) | `Relation.ReflTransGen.trans` |
| `SymReachable` (definition) | `Relation.SymmGen` |
| `setoid` (construction) | `Relation.EqvGen` |

The base relations (`contracts_one` and `M.step`) stay — they carry domain semantics. Only the RTC boilerplate vanishes.

**Risk**: Low. `ReflTransGen` uses `tail` (last step appended) where our definitions use `step` (first step prepended). This flips the induction direction, but `ReflTransGen` provides a symmetric lemma `head` (from `Relation.lean`:

```lean4
theorem head (h : r a b) (h₂ : ReflTransGen r b c) : ReflTransGen r a c := ...
```

so the translation is a one-line `have` per use.

### Pass 2: `PartialOrder` via `WellFounded`

**Files**: `EMLRegistry.lean` (~10 lines removed)

`contracts_to_antisymm` (EMLRegistry:289) currently:

```lean4
theorem contracts_to_antisymm {s t : EMLTree} (h₁ : contracts_to s t) (h₂ : contracts_to t s) : s = t := by
  induction h₁ with
  | refl t => rfl
  | step s x t h_one h_to ih =>
    have h_decr : leftWeight s > leftWeight x := contracts_one_leftWeight_decreases h_one
    have h_path : contracts_to x s := contracts_to_trans h_to h₂
    have h_lw_ge : leftWeight x ≥ leftWeight s := contracts_to_leftWeight_ge h_path
    omega
```

After Pass 1, `contracts_to` is `ReflTransGen`. The antisymm proof can use `WellFounded` directly:

```lean4
have h_wf : WellFounded (λ s t : EMLTree => contracts_one s t) :=
  Measure.wf leftWeight (by
    intro s t h; have := contracts_one_leftWeight_decreases h; omega)
-- then antisymm via h_wf + ReflTransGen
```

The core lemma `contracts_one_leftWeight_decreases` stays — it's the physics (the Tamari rotation strictly reduces left-nesting). The golf is in how we *use* it.

### Pass 3: Quotient API

**Files**: `PosetQuotient.lean` (~100 lines removed)

With Pass 1 done, the entire `MarkovPoset` construction becomes:

```lean4
def MarkovPoset (M : MarkovChain S) : Type :=
  Quotient (Relation.EqvGen M.step)

instance (M : MarkovChain S) : PartialOrder (MarkovPoset M) := by
  -- derived from ReflTransGen preorder + EqvGen quotient
```

This removes the manual `SymReachable.setoid`, `mk`, `LE`, `le_refl`, `le_trans`, `le_antisymm` construction (~100 lines). The `π` map, monotonicity, surjectivity, and non-injectivity theorems all become derived lemmas.

### Pass 4: Hopf Algebra — The Antipode of Institutional Closure

**Files**: New `Hopf.lean` (~150 lines), touches `LogicMonad.lean` and `InstitutionalClosure.lean`

This is the conceptual prize. The **antipode of institutional closure** is the dual of the closure pipeline:

```
closureₖ   = selfRecognize ∘ deonticUpdate ∘ fuzzyGradeByCdStep k ∘ temporalNormalize
antipodeₖ = reverseNormalize ∘ reverseGrade ∘ reverseDeontic ∘ reverseRecognize
```

Mathlib's `RingTheory.HopfAlgebra.Basic` provides:

```lean4
class HopfAlgebra (R : Type u) (A : Type v) [CommSemiring R] [Semiring A]
    extends HopfAlgebraStruct R A where
  mul_antipode_rTensor_comul : ...  -- S(x₁)x₂ = ηε(x)
  mul_antipode_lTensor_comul : ...  -- x₁S(x₂) = ηε(x)
```

The plan for `Hopf.lean`:

1. **`LogicM` as a bialgebra** — The free monad `LogicM` over a commutative semiring `R` (or `ℕ`, or `ℤ` for the split-octonion context) carries:
   - **Multiplication** (μ): `LogicM.bind` — monadic composition of trees
   - **Unit** (η): `LogicM.pure` — embed a value as a leaf
   - **Comultiplication** (Δ): decompose a tree into its root and subtrees (the coalgebra structure of the free monad)
   - **Counit** (ε): extract leaf values (the "loose leaves")

2. **The antipode** (S): the reversal of the closure path. If `closureₖ` sends a history tree to a norm (future-directed contraction), the antipode sends a norm back to the superposition of histories that could have produced it (past-directed expansion). The antipode axiom:
   ```
   S(closureₖ(history)) · norm  →  ηε(closureₖ(history))
   ```
   says: applying the antipode to a closed norm and then binding gives the scalar counit — the norm is a fixed point.

3. **IdentityZeroDivisor as antipode fixed point**: When the Reserve is exhausted (`e₀ = 0`), the antipode becomes identity: `S(x) = x`. This is exactly the IdentityZeroDivisor — two identity markers that cannot be distinguished because the `e₀` axis is zero. The `identity_zero_divisor_contradiction` (the sorry) IS the boundary of this fixed point.

4. **Connection to the (4,4) signature** (lab_protocol §8): The split-octonion antipode is `e₀ → e₀, eᵢ → -eᵢ` for the split sector (e₄-e₇). The `+1` in `dcStep` being `e₀` as a multiplier (lab_note 011) means the ReserveGuard detects when `e₀ = 0` — i.e., when the antipode's fixed point is reached. The mod-16 invariant (`strut_weight² = 16`) ensures the antipode's square (`S² = id`) holds modulo the (4,4) signature's combinatorial period.

### Pass 5: Arithmetic Tidying

**Files**: `EMLRegistry.lean` (~30 lines removed)

The `node_of_rightCombs_contracts_to_rightComb` proof (EMLRegistry:364) has ~50 lines of `omega`/`simp`/`Nat.add_assoc` rewriting for what reduces to:

```lean4
have h_target : rightComb (1 + (a + 1) + b) = EMLTree.Node .Leaf (rightComb (1 + a + b)) := by
  ring
  simp [rightComb]
```

A `/lean4:golf` pass can:
- Replace the multi-branch `h₁`/`h₂`/`h₃` blocks with `ring` or `omega`
- Remove the redundant `try omega` fallthroughs (vestiges from incremental proving)
- Use `calc` blocks with `ring` for readability

## 3. Expected Outcome

| Pass | File | Lines removed | New lines | Net |
|------|------|-------------|-----------|-----|
| Pass 1 | EMLRegistry.lean | ~80 | ~30 | −50 |
| Pass 1 | PosetQuotient.lean | ~200 | ~40 | −160 |
| Pass 2 | EMLRegistry.lean | ~10 | ~3 | −7 |
| Pass 3 | PosetQuotient.lean | ~100 | ~30 | −70 |
| Pass 4 | New `Hopf.lean` | 0 (new) | ~150 | +150 |
| Pass 5 | EMLRegistry.lean | ~30 | ~10 | −20 |
| **Total** | | **~420** | **~263** | **−157** |

The codebase shrinks by ~157 lines while *gaining* a connection to mathlib's Hopf algebra theory. The remaining sorry count stays at 1 (deliberately).

## 4. Cross-Layer Impact

Each pass is independently revertable and independently verifiable (`lake build` after each). The dependency order is:

```
P1 (ReflTransGen) ─▶ P2 (antisymm golf) ─▶ P3 (Setoid quotient)
                                                    │
                                                    ▼
                                              P4 (Hopf algebra)
                                              P5 (omega cleanup) ─ independent
```

- P1 affects `EMLRegistry.lean` and `PosetQuotient.lean` — both heavily imported. A `lake build` after P1 tests the entire dependency chain.
- P2 depends on P1 (uses `ReflTransGen` antisymm).
- P3 depends on P1 (uses `ReflTransGen` for the quotient).
- P4 depends on P1 and P3 (needs the stable RTC and quotient types).
- P5 is independent and can run any time.

## 5. Connection to Lab Protocol

From `docs/lab_protocol.md`:

| Protocol term | How this plan touches it |
|---------------|--------------------------|
| Timespace decomposition (§1) | P4's antipode formalizes the time-reversal (closure → deconstruction) |
| Quench-collapse as zero-divisor (§3) | P4 connects `IdentityZeroDivisor` to the antipode fixed point |
| Pentagonator → order (§4) | P1+2's `ReflTransGen` is the directed path space of covering relations |
| Radon → pentagonator (§5) | P4's comultiplication is the Radon decomposition of a tree into projections |
| Non-violent = non-Newtonian (§6) | P4's antipode axiom is the algebraic constraint that prevents chaotic collapse |
| (4,4) signature (§8) | P4 anchors the antipode in the split-octonion algebra, connecting closure's `e₀` to the Hopf unit |

## 6. Plan of Record

1. `/lean4:refactor` on `EMLRegistry.lean` — replace `contracts_to` with `Relation.ReflTransGen`
2. `/lean4:refactor` on `PosetQuotient.lean` — replace `Reachable` with `Relation.ReflTransGen`, `SymReachable` with `Relation.SymmGen`/`Relation.EqvGen`
3. `/lean4:golf` on `EMLRegistry.lean` — `contracts_to_antisymm` via `WellFounded`
4. `/lean4:refactor` on `PosetQuotient.lean` — `MarkovPoset` via `Quotient` + `PartialOrder`
5. Write `Hopf.lean` — antipode of institutional closure as `HopfAlgebra` on `LogicM`
6. `/lean4:golf` on `EMLRegistry.lean` — arithmetic tidying (`ring`/`omega`)

Each step produces a clean `lake build` before proceeding.

---

## References

- `lab_notes/011_e0_multiplier_reserveguard.md` — the `+1` as `e₀`, mod-16 invariant, ReserveGuard as zero-divisor annihilator
- `docs/lab_protocol.md` — (4,4) signature, timespace decomposition, quench-collapse
- `LaserCortex/EMLRegistry.lean` — Tamari lattice contraction (the P1/P2 target)
- `LaserCortex/PosetQuotient.lean` — blood-brain barrier poset quotient (the P1/P3 target)
- `LaserCortex/LogicMonad.lean` — `LogicM` free monad (the P4 carrier)
- `LaserCortex/InstitutionalClosure.lean` — the closure pipeline whose antipode we formalize (P4)
- `LaserCortex/LiarParadox.lean` — `IdentityZeroDivisor`, the canonized sorry (P4 fixed point)
- `LaserCortex/SplitOctonionCost.lean` — (4,4) algebra, `Q44` integration point (P4 anchor)
- `Mathlib/RingTheory/HopfAlgebra/Basic.lean` — `HopfAlgebra`, `antipode`, antipode axioms
- `Mathlib/Logic/Relation.lean` — `ReflTransGen`, `SymmGen`, `EqvGen` (P1 replacements)
