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

**Implication 1 — The associator cost is reducible to commutator arithmetic.
And it's even stronger than initially claimed.**

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

Critically: the identity `associator_tensor a b e₄ = split_oct_mul (commutator a b) e₄`
requires both arguments in the `{e₀,e₁,e₂,e₃}` subalgebra (base of the
CD doubling). The restriction is load-bearing — cross-terms survive in
`.e0` when one argument has non-zero `e₄-e₇` components (verified:
`a=e₁_vec, b=e₅_vec` differ by `2` in `.e0`). The mixed case `(a, x, e₄)`
with `x ∈ Aℓ` also does not work.

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

**The restriction is load-bearing.** The identity does not hold for
arbitrary `a, b` (counterexample: `a=e₁_vec, b=e₅_vec` differ by `2`
in `.e0`). The base-subalgebra hypothesis is not an artifact of a
first attempt — it's required.

**"Faithfully encoded" / "not lossy" is narrower than it reads.**
What's proven: for `a, b` both in the `{e₀,e₁,e₂,e₃}` subalgebra, and
for the doubling generator `e₄`, the associator `[a, b, e₄]` equals the
commutator `[a, b]` right-multiplied by `e₄`. And `*e₄` is invertible
(norm = −1). So you have a faithful round-trip **for this specific
three-argument shape with base arguments** — associator against the
generator, where both operands live in the base of the doubling.

The general associator `[a, b, c]` for arbitrary `c` (not just `e₄`)
or `a, b` outside the base still involves genuine non-associativity of
the doubled algebra. This result does not extend to the mixed case
`(a, x, e₄)` with `x ∈ Aℓ` (counterexample above).

**The mixed case `(a, x, e₄)` where `a` is base and `x` has non-zero
`e₄-e₇`** was proposed as the "cheaper intermediate check" but turns
out to also fail: cross-terms survive in `.e0` (verified:
`a=e₁_vec, b=e₅_vec`). So the maximal true statement is the
base-restricted one: `[x, y, ℓ] = (xy − yx)·ℓ` for `x, y ∈ A`,
the classical scope from Baez §2.2. The question of what happens
when you stop restricting to the tidiest slot — `(a, x, e₄)` for
`x ∈ Aℓ`, or `(a, b, c)` for arbitrary `c` — remains open. Both
are natural next steps, but the mixed case is the smaller one (no
new code architecture needed) and should be tested first.

**"Linear isomorphism between sectors" does more work than the proof supports.**
What's shown: a bijection between `commutator(SplitOctonion, SplitOctonion)`
(the full commutator subspace) and its image under right-multiplication by
`e₄` (a subspace of `Aℓ`). Invertibility of `e₄` gives injectivity of `·e₄`
on all of `SplitOctonion`, but does not by itself show the commutator
spans all of `Aℓ`. The `e₄-e₇` sector might be larger than the image of
the commutator — the invertibility says you won't lose information going
`commutator → associator`, but you haven't shown the map is onto the
whole split sector.

**The mixed case `(a, x, e₄)` where `a` is base and `x` has non-zero
`e₄-e₇`** — this was the "cheaper intermediate check" proposed as the
next step. But it turns out `ring` also closes this: the identity holds
for `a ∈ A` (base) paired with arbitrary `x` (including those with
non-zero `e₄-e₇`), as long as the *other* argument is `e₄`. This is
the natural next test: does the clean "commutator × e₄" picture survive
when one argument comes from `Aℓ`?

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

3. **Test the general associator at dim 8** — evaluate
   `associator_tensor a b c` for arbitrary `c` (not just `e₄`). This is
   the true open question: whether the clean "commutator × e₄"
   picture generalizes beyond pairing against the doubling generator.
   This requires the full Schafer formula with conjugation terms and
   is the natural bridge to the dim-16 question (doubling sedenions).

---

## 8. Summary

| Claim | Status | Evidence |
|-------|--------|----------|
| CD doubling: `[x,y,e₄] = (xy−yx)·e₄` | **Proven for base subalgebra** `x,y ∈ {e₀,e₁,e₂,e₃}` | `ring` closes with `a.e4=...=0` hypotheses |
| Invertibility of `e₄` | **Verified** | `octonion_norm(e₄) = −1 ≠ 0` |
| Identity holds for arbitrary `a,b` | **False** | Counterexample: `a=e₁, b=e₅` differ by `2` in `.e0` |
| Mixed case `(a, x, e₄)` `x ∈ Aℓ` | **False** | Same counterexample; cross-terms survive |
| General associator `[a,b,c]` arbitrary `c` | **Unknown** | Not tested; open question |
| Non-associative complexity snowballs | **Unknown** | Needs dim-16 or general-associator formula |

**Key structural insight**: The CD doubling gives a **linear isomorphism**
between the commutator (base subalgebra) and its image under
right-multiplication by `e₄` (associator sector). This means the
pairing-against-the-generator associator carries no new information
beyond the commutator — it's a change of coordinates via an invertible
linear map. Whether the same holds for pairing against arbitrary `c`
(rather than just `e₄`) or for mixed-case arguments is the open question.
The identity does **not** extend to arbitrary `a,b` or to the mixed
case `(a, x, e₄)` with `x ∈ Aℓ` — the restriction to the base
subalgebra is load-bearing, not an artifact of an early attempt.

**Magnitude**: Medium. The isomorphism is a concrete algebraic fact (Baez
§2.2, one line), but it corrects a significant misconception in the codebase:
the pentagon_defect was malformed for 7 commits, and the CD doubling
identity was initially stated too strongly (claiming it holds for arbitrary
elements when it only holds for base elements). The fix is small but the
correction to the structural narrative is large.
