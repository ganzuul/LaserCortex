# 030: The Mixed-Case CD Doubling Identity — Scope Limit Confirmed

**Date**: 2026-07-05
**Status**: SOLVED — negative result; identity does NOT extend to mixed base/split
  arguments; scope restriction is load-bearing at the mixed level too
**Prerequisites**: 027 (CD doubling identity formalized), 028 (invertibility impact),
  029 (verification summary); `LaserCortex/staging/Algebra.lean`
**Source**: `LaserCortex/staging/Algebra.lean` lines 263-292 (cd_doubling_identity),
  new theorem attempted at lines 296-320 (removed), residual comment at line 296

---

## 1. The Question

The CD doubling identity `associator_tensor a b e4_vec = split_oct_mul (split_oct_commutator a b) e4_vec`
has been proven for `a, b` both in the base subalgebra `{e₀, e₁, e₂, e₃}` (lines 263-292).

The natural extension: does it hold when **one** argument is in the base and the
**other** has non-zero split components `{e₄, e₅, e₆, e₇}`? This is the "mixed case"
proposed in lab_notes/028 as the "cheaper intermediate check" before constructing
full sedenions.

The question is load-bearing: if the identity held for mixed arguments, the
associator would be reducible to commutator arithmetic for a much larger slice
of the algebra, with implications for how much of the non-associative complexity
is actually "demotable" to the associative sector.

---

## 2. The Test

**Hypotheses:**
- `a` in base: `a.e₄ = a.e₅ = a.e₆ = a.e₇ = 0`
- `b` in split: `b.e₀ = b.e₁ = b.e₂ = b.e₃ = 0`

**Theorem attempted** (now removed — see Algebra.lean lines 296-320):
```lean
theorem cd_doubling_identity_mixed (a b : SplitOctonion)
    (ha : a.e4 = 0) (ha' : a.e5 = 0) (ha'' : a.e6 = 0) (ha''' : a.e7 = 0)
    (hb : b.e0 = 0) (hb' : b.e1 = 0) (hb'' : b.e2 = 0) (hb''' : b.e3 = 0) :
    associator_tensor a b e4_vec = split_oct_mul (split_oct_commutator a b) e4_vec
```

**Method:** `SplitOctonion.ext_components` (8 components) with `ring` on each.

---

## 3. The Result

**FALSE.** `ring` fails on all 8 components. The residual cross-terms are:

| Component | Residual expression | Non-zero terms |
|-----------|-------------------|----------------|
| `.e₀` | `-(a.e1*b.e5*2) - a.e2*b.e6*2 - a.e3*b.e7*2` | `a₁b₅, a₂b₆, a₃b₇` |
| `.e₁` | `a.e1*b.e4*2` | `a₁b₄` |
| `.e₂` | `a.e2*b.e4*2` | `a₂b₄` |
| `.e₃` | `a.e3*b.e4*2` | `a₃b₄` |
| `.e₅` | `a.e1*b.e7*2 - a.e3*b.e5*2` | `a₁b₇, a₃b₅` |
| `.e₆` | `-(a.e1*b.e6*2) + a.e2*b.e5*2` | `a₁b₆, a₂b₅` |
| `.e₇` | `a.e1*b.e5*2 - a.e2*b.e4*2` | `a₁b₅, a₂b₄` |

Every residual is a product of one component from `{e₁, e₂, e₃}` and one from
`{e₄, e₅, e₆, e₇}`. The pattern is identical to the unrestricted case: cross-terms
need one "outside the base" factor and one from `{e₁, e₂, e₃, e₄}`.

---

## 4. Scope Analysis

The identity holds exactly at the classical scope: `[x, y, ℓ] = (xy − yx)·ℓ`
for `x, y ∈ A` (the base algebra). Two relaxation attempts both fail:

```
Relaxation 1 (unrestricted):  [a, b, e₄] = commutator(a,b)·e₄  for all a,b ∈ SplitOctonion
  → FALSE. Counterexample: a=e₁_vec, b=e₅_vec differ by 2 in .e₀.

Relaxation 2 (mixed case):     [a, b, e₄] = commutator(a,b)·e₄  for a∈A, b∈SplitOctonion
  → FALSE. Cross-terms survive in all 8 components.
```

The maximal true statement remains the base-restricted one. This matches the
classical Cayley-Dickson literature exactly (Baez, *The Octonions*, §2.2):
the identity is a theorem about the base algebra `A`, not about the doubled
algebra `A ⊕ Aℓ`.

---

## 5. What This Means

### 5.1 The Associator Is Not Fully Reducible

The associator against `e₄` is reducible to commutator arithmetic **only** when
both arguments live in the `{e₀, e₁, e₂, e₃}` subalgebra. As soon as one argument
has non-zero split components, genuine non-associativity appears.

### 5.2 The Split Sector Carries Independent Information

Elements of `{e₄, e₅, e₆, e₇}` are not "projections" of base elements — they
are genuinely new directions. The CD doubling identity is a theorem about the
*construction* (how the dim-8 algebra is built from dim-4), not about the
*result* (the full dim-8 algebra).

### 5.3 Implications for Friction

The associator cost `strut_weight = 4` is computed from the **base** commutator
right-multiplied by `e₄`. The cost is well-defined for base-pair associators.
But for mixed-case associators `[a, x, e₄]` with `x` in the split sector,
the cost would need to be computed directly from the full associator norm —
there is no reduction to commutator arithmetic.

This means the "associator cost" in `Friction.lean` is really a commutator-cost
(measured at CD 2), not a mixed-case cost. The associator at CD 3 (split
octonions) activates only for base-pair arguments — the full algebra's
non-associativity is a derived quantity from the base commutator, but only
for the specific shape `[base, base, e₄]`.

### 5.4 Implications for OctilinearEmbedding

The tube coordinates (`kktMultiplier`, `tubeCoord`) embed trees into the
split-quaternion algebra `{e₀, e₁, e₂, e₃}`. Since the CD doubling identity
scope is restricted to this base, the embedding is consistent with the
reductionist picture: the associator information is fully captured by the
base algebra's commutator structure.

---

## 6. The Algebraic Mechanism

### 6.1 CD Doubling Structure

In the CD construction `A → A ⊕ Aℓ` with generator `ℓ`:
```
(a, 0)(b, 0) = (ab, 0)           — base × base = base (associative)
(a, 0)(0, x) = (0, āx)           — base × ℓ-sector = ℓ-sector
(0, x)(a, 0) = (0, xa)           — ℓ-sector × base = ℓ-sector
(0, x)(0, y) = (xȳ + yx̄, 0)    — ℓ-sector × ℓ-sector = base (commutator appears)
```

For `a, b ∈ A`, the associator `[a, b, ℓ] = (ab)·ℓ − a·(b·ℓ)` reduces to
`(ab − ba)·ℓ` because `(a, 0)(0, b) = (0, āb)` and `(a, 0)(b, 0) = (ab, 0)`.

### 6.2 Why Mixed Case Fails

When `b ∈ Aℓ` (represented as `(0, x)` with `x ∈ A`), the associator
`[a, (0,x), ℓ]` involves terms like `(a,0)(0,x)ℓ` and `a(0,x)ℓ`. These don't
reduce to `(a·0x − 0x·a)·ℓ` because `a·(0,x)` involves the full CD multiplication
formula with conjugation terms. The split-sector elements carry genuine
non-associativity that cannot be expressed purely in terms of base commutators.

---

## 7. Verification Summary

| Claim | Status | Evidence |
|-------|--------|----------|
| CD doubling: `[x,y,e₄] = (xy−yx)·e₄` for `x,y ∈ {e₀,e₁,e₂,e₃}` | **PROVEN** | `ring` closes all 8 components |
| Identity holds for arbitrary `a,b` | **FALSE** | Counterexample: `a=e₁, b=e₅` differ by 2 in `.e₀` |
| Mixed case: `[a,x,e₄] = commutator(a,x)·e₄` for `a∈base, x∈split` | **FALSE** | Cross-terms survive: `a₁b₅, a₂b₆, a₃b₇` (coefficient 2) |
| `e₄` is invertible | **VERIFIED** | `octonion_norm(e₄) = −1 ≠ 0` |
| Associator cost reducible to commutator | **PARTIAL** | Only for base-pair shape, not mixed case |

---

## 8. Open Questions

1. **General associator** `[a, b, c]` for arbitrary `c` (not just `e₄`).
   Even less likely to reduce — the associator of three arbitrary elements
   is the full non-associativity of the algebra, not just the commutator
   against the generator.

2. **Dim 16 (sedenions).** The CD doubling mechanism repeats, but the base
   algebra is now 8-dimensional (split-octonions). The mixed case at dim 16
   would test `[a, x, e₈]` for `a ∈ {e₀..e₇}` (base) and `x` in split.
   This requires constructing the sedenion multiplication table first.

3. **Norm preservation.** Prove `octonion_norm(associator_tensor a b e4) = strut_weight`
   for all base pairs `(a,b)`, confirming the associator norm is constant
   across the commutator sector. (Currently only proven for the witness triple.)

---

## 9. Conclusion

The CD doubling identity is a **narrow, scope-limited theorem** about the base
of the doubling, not a property of the full algebra. Both relaxation attempts
(unrestricted and mixed-case) fail with the same pattern: cross-terms from
mixed base/split products survive.

This is the correct mathematical fact (Baez §2.2), but it means the
"associator reducible to commutator" story only holds for the specific shape
`[base, base, generator]`. For mixed shapes, the associator is genuinely
non-associative and carries independent information.

**Magnitude:** Small correction (negative result). The identity's scope was
already known from the classical literature; the Lean verification confirms
the restriction is load-bearing, not an artifact of an incomplete proof.
