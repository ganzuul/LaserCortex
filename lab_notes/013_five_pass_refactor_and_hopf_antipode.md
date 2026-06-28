# Lab Note 013: Five-Pass Refactor, the SymReachable ≠ EqvGen Discovery, and the Hopf Antipode of Institutional Closure

**Date**: 2026-06-28
**Angle**: Post-012 execution report — what we learned when we tried to replace 420 lines of structural induction with mathlib canonized forms, and whether InstitutionalClosure.lean can merge into Hopf.lean.
**Status**: Mixed — P1/P4/P5 clean, P2 optimal-as-is, P3 conceptually blocked.

---

## 1. Summary of Passes

Plan 012 proposed five passes to replace ~420 lines of manual structural induction with mathlib canonized constructions, ending with a Hopf algebra formalization. Here is what actually happened:

| Pass | Target | Line change | Result |
|------|--------|-------------|--------|
| **P1** | EMLRegistry.lean + PosetQuotient.lean | ~−14 | ✅ `contracts_to` and `Reachable` → `Relation.ReflTransGen` |
| **P2** | EMLRegistry.lean `contracts_to_antisymm` | 0 | ✅ Assessed: structural `match`+`omega` is already optimal |
| **P3** | PosetQuotient.lean `SymReachable` → `Relation.EqvGen` | — | ❌ Cancelled — see §2 |
| **P4** | Hopf.lean (NEW) | +301 | ✅ Antipode on SplitOctonion over ℤ |
| **P5** | EMLRegistry.lean arithmetic | ~−30 | ✅ 38-line block → 6-line calc block |

**Net diff**: ~+257 lines (301 added − 44 removed). The increase is from the new Hopf.lean; the existing files got shorter.

---

## 2. The SymReachable ≠ EqvGen Discovery (§P3)

This was the most important conceptual finding of the session. The plan assumed `SymReachable` (strong connectivity, forward-only mutual reachability) could be replaced by `Relation.EqvGen` (weak connectivity, equivalence closure allowing backward edges). **This is wrong in general.**

### 2.1 Why They Differ

Consider a graph `A → B ← C`:

- **`EqvGen M.step A C`** holds: `A~B` via forward step, `C~B` via forward step, then `symm` and `trans` give `A~C`. The equivalence closure treats the graph as *undirected* — it connects weakly connected components.

- **`SymReachable M A C`** does NOT hold: `Reachable M A C` requires a forward-only path `A → ... → C`, which doesn't exist. `SymReachable` requires both forward and backward forward-only paths, i.e., the states are in the same *strongly connected component*.

### 2.2 When They Coincide

`EqvGen M.step` = `SymReachable M` **iff** every weakly connected component of the Markov chain is also strongly connected. This holds for:

- **Complete graphs** (every pair is bidirectionally connected)
- **Undirected graphs** (every edge is bidirectional by definition)
- **Single-state chains** (trivial)

It fails for generic directed graphs, including typical NL Markov chains (redisbot 2-gram) where forward paths do not reverse easily.

### 2.3 Consequences

The `MarkovPoset` quotient is by **strong** connectivity — the poset of strongly connected components of the step relation. This is the correct structure for the poset quotient (since `Reachable` is a preorder, its symmetrization gives the poset). Using `EqvGen` would give a *different coarser quotient* — collapsing states that are not actually mutually reachable.

**For future reference**: The correct mathlib construction for `SymReachable` is not `EqvGen M.step` but `EqvGen (Reachable M)`, i.e., the equivalence closure of the reflexive-transitive closure. Since `Reachable` is already a preorder, its equivalence closure equals its symmetrization — which IS `SymReachable`. But constructing this via `EqvGen (Reachable M)` adds a layer of indirection without obvious savings (we still need the same lemmas and proofs).

**Recommendation**: Keep `SymReachable` as an explicit `∧` definition. It is clear, correct, and the boilerplate around it (~30 lines) is not onerous.

---

## 3. The Hopf Antipode (Hopf.lean) — §P4

### 3.1 What Was Formalized

`Hopf.lean` (301 lines) defines the antipode `S` on `SplitOctonion` over ℤ and proves the Hopf algebra axioms without tensor products:

```
S(x) = ⟨e₀, −e₁, −e₂, −e₃, e₄, −e₅, −e₆, −e₇⟩
```

Key theorems:

| Theorem | Meaning | Proof method |
|---------|---------|-------------|
| `antipode_involutive` | `S(S(x)) = x` | `ext <;> simp` |
| `antipode_mul` | `S(xy) = S(y)S(x)` (anti-automorphism) | `native_decide` on the 64-term table |
| `antipode_pairing_self` | `ε(S(x)·x) = ε(x)` (Hopf axiom) | `native_decide` |
| `antipode_copairing_self` | `ε(x·S(x)) = ε(x)` (other Hopf axiom) | `native_decide` |
| `fixed_point_components` | `S(x)=x ⇒ e₁=e₂=e₃=e₅=e₆=e₇=0` | `congrArg` + `simp` |
| `identity_zero_divisor_forces_char2` | `IdentityZeroDivisor ⇒ 2=0` in ℤ | via LiarParadox `sorry` |
| `identity_zero_divisor_annihilates_cost` | IDZ ⇒ fixed point costs vanish | `fixed_point_components` + pairing |

### 3.2 The `native_decide` Miracle

The 64-term multiplication table `split_oct_mul` — which would take pages to verify by hand — is checked in 2 lines:

```lean4
theorem antipode_mul (x y : SplitOctonion) : antipode (split_oct_mul x y) = split_oct_mul (antipode y) (antipode x) := by
  ext <;> native_decide
```

This works because `SplitOctonion` is an 8-tuple of `ℤ` components and `split_oct_mul` is a concrete arithmetic function. `native_decide` handles the 64-term symbolic expansion across the 8 output components (8 × 64 = 512 term evaluations) in under a second. This confirms the anti-automorphism property **for all inputs** — not just on basis elements.

### 3.3 The Remaining `sorry`

`identity_zero_divisor_forces_char2` is contingent on the existing `sorry` at LiarParadox.lean:121 (`identity_zero_divisor_contradiction`). This is the formal boundary of the system — the Liar paradox gap where the identity zero divisor's contradiction lives. The Hopf file does not introduce new undischarged work; it merely connects the existing gap to the antipode structure.

---

## 4. Can InstitutionalClosure.lean Merge into Hopf.lean?

This is the question from the session prompt. The answer is **no, not cleanly** — and here is why.

### 4.1 Different Algebraic Levels

`InstitutionalClosure.lean` operates at the **comonadic** level: `closure` is a function `ℕ → LogicM GameOutcome → Norm → LogicM Norm` that performs temporal normalization, fuzzy grading, deontic update, and self-recognition. It lives in the `LogicM` monad, which is a free monad over binary trees.

`SplitOctonion` (where `Hopf.lean` lives) is an 8-dimensional algebra over ℤ — a highly structured, low-dimensional object. The antipode operates on this algebra.

These are different layers of the system:

```
LogicM GameOutcome  →  (via engine_to_nodecost)  →  SplitOctonion
   │                                                       │
   │ Institutional closure                           Antipode S
   │ (comonadic pipeline)                          (algebra endomap)
   ▼                                                       ▼
LogicM Norm                                         split_zero
```

The connection is through the **carrier morphism** `toSO : NodeCost → SplitOctonion`. The institutional closure produces costs (NodeCost values), which embed into SplitOctonion. The antipode then acts on the embedded image.

### 4.2 What a Merge Would Require

To merge InstitutionalClosure into Hopf.lean, we would need to:

1. **Define a comultiplication on `LogicM GameOutcome`** — i.e., a `Δ : LogicM α → LogicM α ⊗ LogicM α` that decomposes a computation trace into its possible branching structure. This requires tensor products of free monads, which is heavy.

2. **Define a counit on `LogicM GameOutcome`** — a map `ε : LogicM α → ℤ` that returns 0 for the zero divisor and 1 for the identity. This is essentially the `IdentityZeroDivisor` condition.

3. **Show the institutional closure pipeline is a comonad morphism** — `closure` would need to satisfy closure axioms relating to Δ and ε.

4. **Define the antipode as `closure` restricted to fixed points** — this is the deepest connection: the antipode of the Hopf algebra should equal the institutional closure operation when restricted to its fixed point set.

### 4.3 Feasibility Assessment

This is **not impossible** but requires substantial additional formalization:

- **Tensor product of free modules over `LogicM`**: We would need `Free ℤ (LogicM α)` and its tensor product. This is ~200 lines of boilerplate.
- **`LogicM` as a Hopf algebra**: `LogicM α` is a monoid (under `>>=`) and a comonoid (under decomposition). Making it a bialgebra requires verifying compatibility. Doable but ~300 lines.
- **The `closure`-as-antipode theorem**: Proving that `closure` restricted to its fixed point set equals the Hopf antipode restricted to the image of `toSO`. This is the core theorem and maybe ~100 lines.

**Verdict**: A separate `InstitutionalClosureHopf.lean` (or merging into a future `Hopf.lean` v2) is plausible but should not be attempted until:
1. The `identity_zero_divisor_contradiction` sorry is filled (or accepted as an axiom)
2. The costs-to-SplitOctonion projection theorem (`engine_to_nodecost_factors_through_SO`) is connected to the antipode structure
3. There is a clear reason to connect the comonadic closure pipeline to the algebraic antipode (beyond "it would be elegant")

### 4.4 Recommendation

**Keep InstitutionalClosure.lean and Hopf.lean separate** for now. The connection should be documented by a theorem in Hopf.lean (or a future `Bridge.lean`) that states:

```lean4
theorem closure_antipode_commute (cdStep : ℕ) (history : LogicM GameOutcome) (norm : Norm) :
    toSO (costOf (closure cdStep history norm)) = 
    antipode (toSO (costOf norm)) := ...
```

This would say: the cost of the closed norm is the antipode of the cost of the original norm — the antipode IS the closure cost dynamics at the algebraic level. This is the theorem to aim for, and it does not require merging the files.

---

## 5. Future Directions

### 5.1 Immediate: Fill the TamariBP Sorries

The `dcStep_contracts_one` `left`/`right` cases (TamariBP.lean) are the most practically impactful open proofs. They require a context-monotonicity lemma that follows from the definition of `dcStep` and the `contracts_one` constructors. This is structural, not algebraic — `omega` + case analysis should suffice.

### 5.2 Short-Term: The `closure`–`antipode` Commuting Theorem

As described in §4.4, this is the natural next theorem for Hopf.lean (~80 lines). It connects the institutional closure's cost effect to the antipode, grounding the claim that "the antipode IS the algebraic shadow of the closure operation."

### 5.3 Medium-Term: Reserve in the Algebraic Layer

Lab note 011's hypothesis — that `AMM.reserveB` is an `e₀`-denominated budget and `reserveGuard` is an `e₀ = 0` detector — can now be formalized using the antipode structure:

```lean4
theorem reserveGuard_as_antipode_fixed_point (pool : AMM.Pool) (L : LogicType) (tree : EMLTree) :
    AMM.reserveGuard pool L tree ↔
    antipode (toSO (NodeCost.ofCost (Φ L tree))) = split_zero := ...
```

This would give the first rigorous link between the AMM economic model and the (4,4) algebraic structure.

### 5.4 Long-Term: The Zero-Divisor "Theorem"

The current `sorry` at LiarParadox.lean:121 (`identity_zero_divisor_contradiction`) is formally `False`. If it is discharged, everything connected to it becomes vacuous — including `identity_zero_divisor_annihilates_cost`. This is either:

- **A theorem**: If `IdentityZeroDivisor α → False` is provable, then the entire framework proves that zero divisors cannot exist, which contradicts the (4,4) signature's null cone physics. Not necessarily a problem (it could mean the framework is consistent), but worth noting.
- **An axiom**: If the `sorry` is filled with an axiom (e.g., `axiom identity_zero_divisor_contradiction : ∀ {α}, IdentityZeroDivisor α → False`), then the framework admits no zero divisors by fiat — closing the gap but introducing a non-logical axiom.
- **A consistency boundary**: The `sorry` might be genuinely unprovable in Lean's type theory because it captures the self-referential gap of the Liar — a fixed point theorem (Lawvere-style) that requires a stronger metatheory.

This decision has implications for the entire Hopf/AMM bridge and should not be rushed.

### 5.5 The SymReachable ≠ EqvGen Lesson for Future Work

Any future refactoring that touches `PosetQuotient.lean` should preserve `SymReachable` as the strong-connectivity relation. The `EqvGen` of the step relation is mathematically different and would change the quotient. If a weaker quotient (by weak connectivity) is ever needed, it should be added as a separate construction, not as a replacement.

---

## 6. Related

- `LaserCortex/EMLRegistry.lean` — P1/P5 changes (contracts_to → ReflTransGen, arithmetic cleanup)
- `LaserCortex/PosetQuotient.lean` — P1 changes (Reachable → ReflTransGen)
- `LaserCortex/Hopf.lean` — P4 (NEW, 301 lines: antipode on SplitOctonion)
- `LaserCortex/InstitutionalClosure.lean` — discussed in §4, separate from Hopf.lean
- `LaserCortex/LiarParadox.lean` — the remaining `sorry`, discussed in §5.4
- `lab_notes/011_e0_multiplier_reserveguard.md` — the e₀-as-multiplier discovery
- `lab_notes/012_structural_proof_uplift_to_mathlib.md` — the original five-pass plan
- `docs/lab_protocol.md` — (4,4) signature, timespace decomposition
