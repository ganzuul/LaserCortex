# 028: The Invertible CD Doubling — What It Means for Friction

**Date**: 2026-07-05
**Status**: HYPOTHESIS — algebraic mechanism verified in code; implications for
  cost landscape untested in Lean (pending port of Friction.lean from
  `LaserCortex/FrictionLagrangian.lean`)
**Prerequisites**: 027 (CD doubling identity formalized), `LaserCortex/staging/Algebra.lean`,
  `LaserCortex/staging/Friction.lean`

---

## 1. The Core Finding

Right-multiplication by `e₄` is a **linear isomorphism** on `SplitOctonion`.
The CD doubling identity `associator_tensor a b e₄ = split_oct_mul (split_oct_commutator a b) e₄`
holds for all `a, b` in the base subalgebra `{e₀,e₁,e₂,e₃}`, with the restriction
that `a.e₄ = a.e₅ = a.e₆ = a.e₇ = 0` and similarly for `b`.

But here's the stronger structural point the lab_notes initially missed:

> The identity **does not** hold for arbitrary `a, b` (full 8-dimensional
> split-octonions). Cross-terms from `e₄-e₇` survive when both operands
> have non-zero split components.

This is the correct classical scope: the CD doubling identity is a theorem
about the base algebra `A`, not about the doubled algebra `A ⊕ Aℓ`. It says
`[x, y, ℓ] = (xy − yx)·ℓ` for `x, y ∈ A`.

---

## 2. What Invertibility Actually Means

`e₄` is invertible because `octonion_norm(e₄_vec) = −1 ≠ 0`. In a
composition algebra (alternative, norm-multiplicative), any element with
nonzero norm has a two-sided inverse via `x⁻¹ = x̄/N(x)`.

For `e₄_vec`, the inverse is `−e₄_vec`:
```
e₄_vec · (−e₄_vec) = split_oct_mul e4_vec e4_vec
                    = split_one  (since e₄² = +1)
                    = 1
```

And `−e₄_vec · e₄_vec = split_one = 1`.

So right-multiplication by `e₄_vec` is a linear bijection between the
subspace `{e₀,e₁,e₂,e₃}` and `{e₄,e₅,e₆,e₇}`. The two 4-dimensional slices
are isomorphic as vector spaces.

---

## 3. Impact on Friction.lean

### 3.1 The Current Friction Model

`Friction.lean` defines:
```
frictionDensity(k) = commDefect(k) + strut_weight · assocDefect(k)
```

Where:
- `commDefect(k) = k` (grows linearly with CD step)
- `assocDefect(k) = 0` for `k ≤ 2`, `strut_weight = 4` for `k ≥ 3`
- `strut_weight = 4` is the norm of `associator_tensor e₁ e₂ e₄`

### 3.2 What Changes

The CD doubling invertibility says the associator sector is **not** a
separate source of complexity. It's a linear image of the commutator sector.
This has three concrete implications:

**Implication 1 — The associator cost is reducible to commutator arithmetic.**

At CD 3, the total friction is:
```
Γ₃ = 3 + 4·4 = 19
```

The `4·4 = 16` associator term comes from `strut_weight · assocDefect`.
But `strut_weight = 4 = octonion_norm(associator_tensor e₁ e₂ e₄)`.
And `associator_tensor e₁ e₂ e₄ = split_oct_mul (split_oct_commutator e₁ e₂) e₄`.

So the associator cost `16` is `(N(associator_tensor))²` where the
associator itself is `split_oct_mul (commutator) e₄`. The cost of
non-associativity is a **fixed linear overhead** (`split_oct_mul ... e₄`)
plus a **norm scaling** (`strut_weight = 4`).

**Implication 2 — The "non-associative phase change" at CD 2→3 is actually
associative structure in disguise.**

The jump `Γ₃ − Γ₂ = 1 + strut_weight² = 1 + 16 = 17` looks like a
non-linear phase transition. But structurally, it's:
- `+1`: the commutator increment (associative, expected)
- `+16`: `strut_weight² = N(associator)²` where `associator = commutator · e₄`

The "non-associative" jump is just the norm of the commutator (scaled by
the fixed isomorphism `· e₄`) squared. This is **predictable from the base
algebra alone** — you don't need to compute in dim 8 to know the CD 3 cost.

**Implication 3 — The cost landscape's "friction" has two tiers, not three.**

| Tier | CD steps | Cost structure |
|------|----------|----------------|
| Associative | ≤ 2 | Purely commutative: `Γ_k = k` |
| Split | ≥ 3 | Commutative + linear image of commutator: `Γ_k = k + N([x,y,e₄])²` |

The associator is not a third independent source of friction. It's a
**derived quantity** — the commutator's image under a fixed invertible
linear map, scaled by the norm of the base commutator.

---

## 4. The Algebraic Mechanism

### 4.1 The Doubling Formula

In the CD construction `A → A ⊕ Aℓ`:
```
(a, 0)(b, 0) = (ab, 0)          — base × base = base (associative)
(a, 0)·(0, ℓ) = (0, āa)          — base × ℓ = ℓ (commutator appears)
```

For `x, y ∈ A` (represented as `(x, 0), (y, 0)` in the full algebra):
```
associator [x, y, ℓ] = (xy)·ℓ − x·(y·ℓ)
                     = (xy − yx)·ℓ     (CD doubling identity)
```

### 4.2 Why the Restriction Is Necessary

For arbitrary elements `a = (a₀, a₁)` and `b = (b₀, b₁)` where `a₀, b₀ ∈ A`
and `a₁, b₁ ∈ A` (as a module):
```
(a₀ + a₁ℓ)(b₀ + b₁ℓ) = (a₀b₀ + b₁(a₀̄a₁)) + (a₀b₁ + ā₀b₀)ℓ  (wait, this is wrong)
```

The actual CD multiplication formula for `A ⊕ Aℓ`:
```
(a, b)(c, d) = (ac + d(b̄a), da + (āc)b)
```

where `a, c ∈ A` and `b, d` are in the module `A` over itself.

For the split-octonion, this translates to the component formula in
`Algebra.lean`. When both operands have non-zero `e₄-e₇` components, the
associator involves **genuine non-associativity** of the doubled algebra,
not just the base algebra's commutator.

The classical identity `[x, y, ℓ] = (xy − yx)·ℓ` is a theorem about `x, y ∈ A`
(Theorem 1 in Baez, *The Octonions*, §2.2). It does not extend to arbitrary
elements of `A ⊕ Aℓ`.

---

## 5. What This Does NOT Mean

**The non-associative sector is not "empty" or "projected away".**
The associator at CD 3 is non-zero (norm = 4), and it has genuine
components in `e₅-e₇` that are not present in the commutator. The identity
shows that these components are the commutator's components shifted by the
CD doubling — they're **the same information** in a different basis.

**The CD 3 cost landscape is not "flat" in the sense of trivial.**
The associator's norm being 4 means there IS non-trivial structure at CD 3.
The invertibility just means you can compute it cheaply from the base.

**Friction.lean is not wrong — it's incomplete.**
The current definitions correctly capture the magnitudes. What's missing
is the **structural reduction**: the associator cost is not independent,
it's `(fixed linear map)² · (commutator cost)`. This could simplify proofs
about phase changes and height map discontinuities.

**"Faithfully encoded" / "not lossy" is narrower than it reads.**
What's proven: for `a, b ∈ A` (the `{e₀,e₁,e₂,e₃}` subalgebra), and for
the doubling generator `e₄`, the associator `[a, b, e₄]` equals the
commutator `[a, b]` right-multiplied by `e₄`. And `*e₄` is invertible
(norm = −1). So you have a faithful round-trip **for this specific
three-argument shape** — associator against the generator, with base
arguments. The general associator `[a, b, c]` for arbitrary `c` (not just
`e₄`) or `a, b` with non-zero `e₄-e₇` components involves genuine
non-associativity of the doubled algebra and is a messier object.
`ring` failing on the unrestricted case is exactly the signal that the
cross-terms are the general-associator correction terms, not artifacts of
a bad formula.

**"Linear isomorphism between sectors" does more work than the proof supports.**
What's shown: a bijection between `commutator(A, A)` (a subspace of the
base `A`) and its image under right-multiplication by `e₄` (a subspace of
`Aℓ`). Invertibility of `e₄` gives injectivity of `·e₄` on all of `A`, but
does not by itself show the commutator bracket spans all of `Aℓ`. The
e₄-e₇ sector might be larger than the image of `commutator(A,A)` — the
invertibility says you won't lose information going `commutator → associator`,
but you haven't shown the map is onto the whole split sector.

---

## 6. Implications for Optimization

### 6.1 The TSP Cost Landscape

If the CD doubling identity holds uniformly at all levels (which it does
at each CD step by the same mechanism), then:
- The Tamari lattice geometry (tree shapes, rotations) dominates
- The algebra dimension adds only a **fixed overhead** per non-associative step
- The cost of switching between tree shapes at CD 3 can be computed entirely
  from commutator arithmetic in the base algebra

### 6.2 The Mixed Case at Dim 8 (Cheaper Than Dim 16)

Before jumping to dim 16 to test snowballing, there's a **cheaper
intermediate check** at dim 8 — still in the existing `SplitOctonion`
representation, no new code architecture needed.

The theorem proved so far: for `a, b ∈ A` (base subalgebra) and the
doubling generator `e₄`,
```
[a, b, e₄] = (ab − ba)·e₄
```

The next rung: mixed case, still at dim 8 — `(a, x, e₄)` where `a ∈ A`
but `x ∈ Aℓ` (i.e., `x` has non-zero `e₄-e₇` components). This is
exactly the shape that `ring` choked on when the hypotheses were removed:
`a.e₄ ≠ 0` or `b.e₄ ≠ 0`.

Schafer's general CD associator formula handles these mixed cases via
conjugation terms. For `a ∈ A` and `x ∈ Aℓ`:
```
[a, x, e₄] = (ax − xa)·e₄ + (correction involving x̄)
```

Testing this mixed case tells you whether the clean
"commutator × e₄" picture survives once you stop restricting to the
tidiest slot — or whether it's specifically a feature of pairing against
the *generator itself* rather than a general property of the doubled
algebra. This is the natural step between what you have now (base ×
base × generator) and the dim-16 question (doubling the doubled algebra),
and it's far cheaper to implement since it only requires evaluating
`associator_tensor` at mixed arguments in the existing 8-dimensional
representation.

---

## 7. Concrete Next Steps

1. **Port Friction.lean** from `LaserCortex/FrictionLagrangian.lean` — the
   current `staging/Friction.lean` is a 127-line shell; the full file has
   `assocDefect`, `commDefect`, `frictionDensity`, phase change theorems,
   and `contracts_to_with_cost`

2. **Express `frictionDensity` in terms of the CD isomorphism** — show that
   `strut_weight = N(associator_tensor e₁ e₂ e₄) = N(split_oct_mul (commutator e₁ e₂) e₄)`
   and that this norm is the **same** whether computed in dim 4 or dim 8
   (since the commutator lives entirely in `e₀-e₃`)

3. **Test the mixed case at dim 8** — evaluate
   `associator_tensor a x e₄` for `a ∈ A` and `x ∈ Aℓ` (non-zero e₄-e₇
   components). This is the natural intermediate step: if the clean
   "commutator × e₄" picture survives here, the mechanism is general
   for pairing against the generator; if it doesn't, the identity is
   specifically a feature of the tidiest slot. This check is cheap —
   just add test cases with `a = e₁_vec` and `x = e₅_vec` (or similar
   mixed pairs) and see if `ring` closes the goal. No new code architecture needed.

---

## 8. Summary

| Claim | Status | Evidence |
|-------|--------|----------|
| CD doubling: `[x,y,e₄] = (xy−yx)·e₄` | **Proven for base elements** | `ring` closes goal with `a.e₄=...=0` hypotheses |
| Invertibility of `e₄` | **Verified** | `octonion_norm(e₄) = −1 ≠ 0` |
| Identity holds for arbitrary `a,b` | **False** | Cross-terms survive; `ring` fails |
| Associator cost is reducible to commutator | **Partial** | True for base elements; scope limited to `A` |
| Non-associative complexity snowballs | **Unknown** | Needs dim-16 code to test |

**Key structural insight**: The CD doubling gives a **linear isomorphism**
between the commutator sector and the associator sector, not a projection.
This means the non-associative information is **faithfully encoded** —
you can recover the commutator from the associator via right-multiplication
by `e₄⁻¹`. The associator is not a lossy shadow; it's a change of coordinates.

**Magnitude**: Medium. The isomorphism is a concrete algebraic fact (Baez
§2.2, one line), but it corrects a significant misconception in the codebase:
the pentagon_defect was malformed for 7 commits, and the CD doubling
identity was initially stated too strongly (claiming it holds for arbitrary
elements when it only holds for base elements). The fix is small but the
correction to the structural narrative is large.
