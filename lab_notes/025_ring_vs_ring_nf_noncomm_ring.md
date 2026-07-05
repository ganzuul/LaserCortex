# 025: ring vs ring_nf vs noncomm_ring — Why We Need Non-Commutative Polynomial Tactics for Cl11

**Date**: 2026-07-05
**Status**: IN PROGRESS — hypothesis documented; proof technique being validated
**Prerequisites**: 024 (Chu embedding is algebra homomorphism), `LaserCortex/staging/Chu.lean`

---

## 1. The Problem

We are proving polynomial identities in the Clifford algebra `Cl11` = `Cl(1,1)`
over `ℤ`. This algebra has generators `e₀'`, `e₁'` satisfying:

```
e₀'² = 1
e₁'² = -1
e₀'e₁' + e₁'e₀' = 0
```

The algebra is **non-commutative**: `e₀'e₁' ≠ e₁'e₀'`.

We need to prove identities like:

```lean4
example (a b c d a' b' c' d' : ℤ) :
    ((a : Cl11) + (b : Cl11) * e₁' + (c : Cl11) * e₀' + (d : Cl11) * (e₁' * e₀')) *
    ((a' : Cl11) + (b' : Cl11) * e₁' + (c' : Cl11) * e₀' + (d' : Cl11) * (e₁' * e₀')) =
    ((a*a' - b*b' + c*c' + d*d' : ℤ) : Cl11) + ... := by
  -- what tactic closes this?
```

---

## 2. Three Tactics, Three Behaviors

| Tactic | Type class | Assumes commutativity? | Behavior on `Cl11` |
|--------|-----------|----------------------|---------------------|
| `ring` | `CommSemiring` | YES | Fails: "ring_nf made no progress" |
| `ring_nf` | `Semiring` | NO | Expands both sides; leaves Clifford relations as subgoals |
| `noncomm_ring` | `NoncommRing` | NO | Expands products; designed for non-commutative polynomial identities |

### 2.1 `ring` — CommSemiring Only

`ring` works on `CommSemiring` (commutative semirings). It normalizes
polynomials by sorting monomials alphabetically — this requires commutativity.

When applied to `Cl11`:
- It recognizes `Cl11` is a `Semiring` but NOT a `CommSemiring`
- It fails with `ring_nf made no progress` because it cannot assume
  `e₁' * e₀' = e₀' * e₁'`
- The error message: "Note that `ring` works primarily in *commutative* rings.
  If you have a noncommutative ring, abelian group or module, consider using
  `noncomm_ring`, `abel` or `module` instead."

**Key point**: `ring` does not fail due to infinite recursion or complexity.
It fails because it **refuses** to work on non-commutative structures.

### 2.2 `ring_nf` — Semiring (Non-Commutative)

`ring_nf` (ring normal form) works on `Semiring`. It computes the normal form
of polynomial expressions without assuming commutativity:
- Treats non-commuting variables as **atoms** (indivisible symbols)
- Does NOT sort `e₁' * e₀'` to `e₀' * e₁'`
- Expands both sides of an equation to their normal forms
- Leaves any remaining algebraic relations as subgoals

When applied to `Cl11`, it expands both sides and leaves the Clifford relations
as subgoals. This is the **correct first step** for non-commutative polynomial
identities.

### 2.3 `noncomm_ring` — NoncommRing

`noncomm_ring` is specifically designed for `NoncommRing` (non-commutative
rings). It:
- Expands products in non-commutative polynomial rings
- Applies no commutativity assumptions
- Is the direct analogue of `ring` for non-commutative settings

`noncomm_ring` should work where `ring_nf` works, but may have different
performance characteristics.

---

## 3. Why `ring` Fails: The Commutativity Wall

The failure of `ring` on `Cl11` is **structural**, not computational.

When `ring` encounters:
```
((a : Cl11) + (b : Cl11) * e₁') * ((a' : Cl11) + (b' : Cl11) * e₁')
```

It tries to expand this to:
```
a*a' + a*b'*e₁' + b*e₁'*a' + b*e₁'*b'*e₁'
```

But then it attempts to sort `b*e₁'*a'` using commutativity:
- `ring` assumes `e₁'*a' = a'*e₁'` (commutativity of scalars with everything)
- But `ring` also assumes `b*e₁' = e₁'*b` (full commutativity)

In `Cl11`, **scalars commute with everything** (they are in the center), but
**`e₁'` does NOT commute with `e₀'`**. `ring` cannot distinguish these cases
because it only has one "commutativity" flag.

The `ring` tactic in mathlib4 is monolithic — it does not have a mechanism to
say "scalars commute but generators don't". This is why `ring_nf` and
`noncomm_ring` exist as separate tactics.

---

## 4. Why `ring_nf` Succeeds: The Non-Commutative Normal Form

`ring_nf` succeeds because it uses a **different normalization strategy**:

1. **No sorting**: Non-commuting variables stay in their original order
2. **Flattening**: `a * (b * c)` becomes `a * b * c` (modulo associativity)
3. **Coefficient collection**: Scalars are pulled to the left of each monomial
   using `Algebra.smul_def` (which says `r • x = (algebraMap R A r) * x`)
4. **Comparison**: Normal forms are compared; if identical, the goal is closed

For `Cl11`, after `ring_nf`:
- LHS expands to a sum of monomials in `{1, e₁', e₀', e₁'*e₀'}`
- RHS expands to the same sum (if the identity holds)
- The Clifford relations `e₀'²=1`, `e₁'²=-1`, `e₀'e₁'+e₁'e₀'=0` are left
  as subgoals because `ring_nf` does not know about them

---

## 5. The Correct Proof Pattern for Cl11 Polynomial Identities

Based on testing with `Cl11` = `CliffordAlgebra Q11`:

```lean4
-- Step 1: Expand both sides using ring_nf (non-commutative)
ring_nf

-- Step 2: Apply Clifford relations using simp
-- (without mul_assoc to avoid infinite loops; use simp only)
simp only [e0_sq', e1_sq', anticommute']

-- Step 3: Compare scalar coefficients using ring (commutative)
ring
```

### Why This Works

| Step | Tactic | What it does | Why it works |
|------|--------|-------------|--------------|
| 1 | `ring_nf` | Expands products in `Cl11` without assuming commutativity | `Cl11` is a `Semiring`, not a `CommSemiring`; `ring_nf` handles this |
| 2 | `simp only [e0_sq', e1_sq', anticommute']` | Resolves `e₀'²`, `e₁'²`, `e₀'e₁'+e₁'e₀'` | These are explicit rewrite rules; `simp only` applies them once forward |
| 3 | `ring` | Compares integer coefficients | After Clifford reduction, all remaining terms are scalar multiples of basis elements; scalar arithmetic IS commutative |

### Why Not `ring` for Step 1?

`ring` fails because `Cl11` is not a `CommSemiring`. The error is immediate
and structural — it does not depend on the size or complexity of the goal.

### Why Not `simp` Instead of `simp only`?

`simp` (without `only`) adds `mul_assoc` to the simp set, which causes
infinite recursion with `mul_intCast_eq_intCast_mul` (see `lab_notes/011`).
`simp only` applies each lemma exactly once in the forward direction, avoiding
this problem.

### Why `ring` for Step 3?

After Clifford reduction, both sides are of the form:
```
A + B*e₁' + C*e₀' + D*(e₁'*e₀') = A' + B'*e₁' + C'*e₀' + D'*(e₁'*e₀')
```
where `A, B, C, D, A', B', C', D'` are explicit integer expressions in `ℤ`.
Since `ℤ` IS commutative, `ring` can compare them.

---

## 6. Hypothesis: The `ring`/`ring_nf` Distinction Is Fundamental for the CD Tower

### Claim

The `Cl11` Clifford algebra is **not** a `CommSemiring`. The `ring` tactic
cannot work on it. We must use `ring_nf` or `noncomm_ring` for any polynomial
identity in `Cl11`.

### Implications

1. **`chu_embed_mul`**: Must use `ring_nf`, not `ring`
2. **`Chu_distributor`**: Must use `ring_nf` on `ℤ` after expanding projections
3. **Any future `Cl11` identity**: Use `ring_nf` + Clifford relations + `ring`
4. **The CD tower**: Each layer `Cl(n,n)` is a non-commutative algebra.
   `ring` will fail on ALL of them. `ring_nf` is the correct tool.

### Conjecture

For the split-octonion `Cl11` = `Cl(1,1)` and its higher-dimensional analogues
`Cl(n,n)`, the correct polynomial tactic is:

```
ring_nf → simp (Clifford relations) → ring (scalar coefficients)
```

This pattern generalizes to all `Cl(p,q)` algebras in the Cayley-Dickson
construction. The `ring` tactic is only appropriate for the **scalar ring**
`ℤ` (or `ℚ`, `ℝ`, `ℂ`), never for the Clifford algebra itself.

### Why This Matters for LaserCortex

The entire LaserCortex theory is built on non-commutative algebras:
- SplitQuat multiplication: non-commutative
- SplitOctonion multiplication: non-commutative, non-associative
- Chu tensor product: non-commutative
- Composition of logic types: non-commutative

Every polynomial identity in these structures requires `ring_nf` or
`noncomm_ring`, not `ring`. The `ring` tactic is appropriate only for
integer coefficient arithmetic after the non-commutative structure has been
resolved.

---

## 7. Summary

| Question | Answer |
|----------|--------|
| Why does `ring` fail on `Cl11`? | `ring` assumes `CommSemiring`; `Cl11` is only `Semiring` (non-commutative) |
| What is the correct first step? | `ring_nf` — expands non-commutative polynomial products |
| What about Clifford relations? | `simp only [e0_sq', e1_sq', anticommute']` — forward rewrite only |
| What about scalar coefficients? | `ring` — scalar arithmetic IS commutative |
| Does this generalize to higher CD layers? | Yes — all `Cl(p,q)` are non-commutative; `ring_nf` is the correct tool |

**Magnitude**: Medium-High. This is a **proof engineering finding** that
unblocks the `chu_embed_mul` and `Chu_distributor` proofs. It also provides
a clear tactic recipe for all future non-commutative polynomial identities
in the CD tower.
