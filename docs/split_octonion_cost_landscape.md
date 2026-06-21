# Split-Octonion Cost Landscape: From Calibration to Proof

**Date:** 2026-06-21  
**Status:** Research document — conceptual framework, not yet formalized

## The Argument in One Paragraph

Split-quaternions ℍ̃ were **calibration**: they confirmed that zero divisors and
non-associativity are independent structural features (associative + zero divisors
is possible). Split-octonions 𝕆ˢ are **proof**: they are the minimal algebra where
all three structural features that map to our cost parameters coexist —
non-associativity (→ `coupling`), zero divisors from the (4,4) signature (→ `satCap`),
and the norm form that distinguishes time-like from space-like vectors (→
`leftWeight`/`rightDiv`). The Born rule y² doesn't come from split-quaternions; it
**emerges from the split-octonion projection** when the space-like sector's norm
contribution is squared before compression. This is Wigner's coinpurse: the
split-octonion norm form N(x) = x₀² + x₁² + x₂² + x₃² − x₄² − x₅² − x₆² − x₇²
is the coin, and the bounded null cone N(x) = 0 is the purse.

---

## 1. From Split-Quaternions to Split-Octonions: What Changes

### What we verified with ℍ̃ (split-quaternions, dim 4, (2,2) signature)

| Property | ℍ̃ result | Cost class mapping |
|----------|-----------|-------------------|
| Fully associative | All 64 basis triples: |assoc| = 0 | `coupling = 0` |
| Zero divisors from metric | (1+j)(1-j) = 0 | `rightDiv = 0` (flat landscape) |
| Norm multiplicativity | N(ab) = N(a)N(b) | Composition algebra verified |
| Null cone | 24 isotropic vectors | Balanced logics (time ≈ space) |
| **Independence** | Associativity ≠ zero divisors | `coupling` and `rightDiv` are independent parameters |

### What changes with 𝕆ˢ (split-octonions, dim 8, (4,4) signature)

| Property | 𝕆ˢ result | Cost class mapping |
|----------|-----------|-------------------|
| **Non-associative** | Max |assoc| = 4.0 at (e₁,e₂,e₄) | `coupling > 0` |
| Zero divisors from metric | 8-dim null cone (richer than ℍ̃) | `satCap > 0` (bounded null cone) |
| **Norm NOT multiplicative** in general | Composition algebra only on the null cone | Degenerate cost paths |
| Null cone is 8-dimensional | Cross-sector isotropic vectors | `coupling` cross-term |
| Anti-commutativity of split basis | e₄ anticommutes with e₁,e₂,e₃ | Mirror flag (left/right swap) |

The critical new structure in 𝕆ˢ is **non-associativity with a maximum associator
norm of 4.0** at the triple (e₁, e₂, e₄) — which crosses the associative/split
boundary. This is the structural precursor to the `coupling` parameter.

---

## 2. The (4,4) Projection: How 𝕆ˢ Maps to NodeCost

The split-octonion has 8 basis elements with a (4,4) signature:

```
N(x) = x₀² + x₁² + x₂² + x₃² − x₄² − x₅² − x₆² − x₇²
        ↑ time-like (positive)      ↑ space-like (negative)
```

The cost function Φ projects this 8-dimensional structure onto a scalar:

```
Φ(L, Node l r) = bias + leftWeight · Φ(l) + Φ(right)/(rightDiv+1) + coupling · Φ(l) · Φ(r) / denom
                  ↑                    ↑                        ↑
                  offset from e₀      associative sector      split sector
                  (always present)    (e₀-e₃ time-like)       (e₄-e₇ space-like)
```

But this is a **depth-1 projection** — it sees the algebra through a single
layer. The depth-2 extensions reveal structure that depth-1 misses:

| Depth-2 feature | 𝕆ˢ structure it captures | NodeCost field |
|-----------------|--------------------------|---------------|
| **maxSem** (Φ = height) | The depth of the algebraic nesting, not its size | `maxSem : Bool` |
| **satCap** (Φ bounded) | The null cone is bounded — N(x) = 0 constrains cost | `satCap : Nat` |
| **Born squaring** (y²) | The space-like norm squares before projection | `rightExponent : Nat` (deferred) |
| **Mirror** (left/right swap) | The e₄ sector anticommutes with e₁-e₃ | `mirror : Bool` |

---

## 3. Why Born Squaring Emerges from 𝕆ˢ, Not ℍ̃

The Born rule says: probabilities come from squared amplitudes. In quantum
mechanics, this is |ψ|². In the EML framework, the analogue is squaring the
space-like subtree cost: Φ(r)² instead of Φ(r).

**Why this can't come from ℍ̃:** Split-quaternions are associative. The
squaring operation y → y² is compatible with any algebra — it doesn't reveal
new structure in an associative setting. In ℍ̃, N(ab) = N(a)N(b) guarantees
that squaring a norm-1 element stays norm-1. There's no structural reason to
square *before* projecting — you get the same result either way.

**Why it must come from 𝕆ˢ:** Split-octonions are non-associative. When you
project from 8 dimensions to a scalar cost, the projection **does not commute
with squaring**:

```
[N(a·b)]² ≠ N(a)² · N(b)²    (in general)
```

because associator(a,b,c) ≠ 0 means the way you group the product changes the
norm. Squaring the space-like component *before* projection (Born rule) gives a
qualitatively different landscape than squaring *after* projection (doubling).
In continuous arithmetic: ln(y²) = 2·ln(y). In discrete ℕ arithmetic: Φ(r)² ≠
2·Φ(r).

**The key structural insight:** The Born rule is the projection artifact that
arises when you first take the norm in the split-octonion (ε₀-ε₃ minus ε₄-ε₇)
and then square the negative-norm sector before compressing it. This is a
specific operation on the split-octonion that has no analogue in the
split-quaternion because the split-quaternion's associativity makes the
grouping irrelevant.

### Explicit calculation

Take a generic split-octonion element with both sectors active:

```
x = a₀e₀ + a₁e₁ + a₂e₂ + a₃e₃   (time-like, positive norm)
  + b₄e₄ + b₅e₅ + b₆e₆ + b₇e₇   (space-like, negative norm)
```

Its norm is:
```
N(x) = a₀² + a₁² + a₂² + a₃² − b₄² − b₅² − b₆² − b₇²
```

Depth-1 projection (our current Φ):
```
Φ = bias + leftWeight · Φ(time) + Φ(space)/(rightDiv+1) + coupling · Φ(time) · Φ(space) / denom
```

Born-squared projection (deferred `rightExponent = 2`):
```
Φ = bias + leftWeight · Φ(time) + Φ(space)²/(rightDiv+1) + coupling · Φ(time) · Φ(space) / denom
```

The squaring applies to the **space-like sector before compression**. This is
exactly the Born rule: square the probability amplitudes (the b₄-b₇ components)
before converting to real observables (the cost).

---

## 4. The Cauldron ↔ Coinpurse Identification

### The cauldron is the EML landscape

From `CoertxCertificate.md`:

> The log-exp cauldron has non-constant curvature. Near the bottom of the trough
> at Φ* the geometry is approximately flat. Moving outward toward the rim the
> curvature increases — the exponential blow-up. But the rim is not a boundary.
> It is a threshold. Beyond it is a new associahedron K_{n+1}.

The cauldron is defined by the cost function:
- **Trough** (Φ ≈ Φ*): Low curvature, cheap rotations, classical regime
- **Rim** (Φ → ∞): High curvature, expensive rotations, quantum regime
- **Beyond rim**: Phase 5 — associahedron expansion

### Wigner's coinpurse is the phase-space projection

Wigner's quasi-probability W(x,p) has three structural regions:
1. **Positive interior** (W > 0): Classical probability regime — the coin
2. **Negative oscillations** (W < 0): Quantum interference — the purse opening
3. **Decay** (W → 0 at boundary): The purse closing — the clasp

### The identification

| Cauldron region | Coinpurse region | 𝕆ˢ structure | Cost function |
|----------------|-----------------|-------------|--------------|
| Trough (Φ ≈ Φ*) | Positive interior (W > 0) | Time-like sector N > 0 | `satCap` inactive, `coupling = 0` |
| Rim (Φ → ∞) | Negative oscillations (W < 0) | Cross-sector (N₀ > 0, N₄ < 0) | `coupling > 0`, `leftWeight > 1` |
| Horizon (satCap) | Boundary closure | Null cone (N = 0) | `satCap > 0` |
| Beyond horizon | Beyond clasp | Split sector pure (N < 0) | `maxSem = true` or `rightExponent = 2` |

The **null cone** is where the identification happens. In the split-octonion,
vectors on the null cone satisfy N(x) = 0 — they are neither time-like (N > 0)
nor space-like (N < 0). In the cost function, `satCap > 0` bounds the null cone
— it says the cost cannot grow beyond a threshold, which is the structural
analogue of the coinpurse closing.

The **Born rule** makes the coinpurse close *faster* because Φ(space)² grows
quadratically rather than linearly. This is the purse closing — the Wigner
function goes negative more quickly (the oscillations are stronger) because the
space sector's contribution is amplified by squaring.

---

## 5. The Bounded Null Cone: Why the Coin Has a Purse

In flat Minkowski spacetime (Special Relativity), the null cone extends to
infinity. There is no bound — light can travel forever. The Wigner function
of a free particle has infinite support.

In our framework, the null cone is **bounded by the topology of the
associahedron**:

1. **Fuzzy** (satCap = 5): The null cone closes at degree 5. Φ cannot exceed 5.
   This is a **hard boundary** — the coinpurse has a hard clasp.

2. **Intuitionistic** (maxSem): The null cone narrows logarithmically. Φ grows
   as tree height, not tree size. This is a **soft boundary** — the coinpurse
   closes gradually, like a drawstring.

3. **Quantum** (rightExponent = 2, deferred): The null cone doesn't close, but
   its cross-section grows quadratically. The coinpurse nose-dives but never
   fully closes. This matches the Wigner function of a quantum harmonic
   oscillator — infinite support, but the oscillations decay (Gaussian envelope).

4. **Classical** (no bound, no squaring): The null cone is unbounded. The
   coinpurse never closes. This matches the Wigner function of a classical
   probability distribution — everywhere non-negative, no oscillations.

The **structural chain** is:

```
(4,4) split-octonion norm     EML cost function          Wigner coinpurse
─────────────────────────────  ────────────────────────  ──────────────────
N(x) > 0 (time-like)    →    leftWeight > 1           →  positive interior (coin)
N(x) = 0 (null cone)    →    satCap boundary           →  clasp (boundary closure)
N(x) < 0 (space-like)   →    rightDiv compression      →  negative oscillations (purse)
|assoc| > 0              →    coupling > 0              →  interference fringes
squaring before N         →    rightExponent = 2         →  Born rule (steeper walls)
```

---

## 6. Why This Needs More Knowledge Work Before Formalization

1. **The projection map is not yet defined.** We know the (4,4) signature maps to
   our cost parameters, but we haven't written down the explicit projection
   P : 𝕆ˢ → NodeCost. This requires specifying how the 8-dimensional norm
   reduces to (leftWeight, rightDiv, coupling, denom, satCap, maxSem, mirror,
   rightExponent) — 8 parameters from 64 multiplication table entries.

2. **The Born rule needs a precise conjecture.** We know that y² ≠ 2y in ℕ
   arithmetic and that squaring makes the coinpurse close faster. But we need
   a precise statement: "For which trees t does Φ(Quantum, t) with rightExponent=2
   equal the Wigner function evaluated at (x = Φ(time), p = Φ(space))?" This
   requires defining what "the Wigner function of an EML tree" means, which
   we haven't done.

3. **The associator-to-coupling map is qualitative, not quantitative.** We
   verified that `max |assoc| = 4.0` at (e₁, e₂, e₄) and that the cost
   classes `coupling = 0, 1` correspond to `|assoc| = 0, >0`. But we haven't
   derived the specific coupling value (1/denom) from the associator norm.
   This requires running the full 64-triple analysis and matching each triple's
   associator norm to a specific cost parameter.

4. **The cauldron geometry needs a coordinate system.** We described it as a
   warped product geometry in `CoertxCertificate.md`, but we haven't defined
   the metric tensor or computed geodesics. This is needed to make precise
  claims about the trough, rim, and horizon.

5. **The Wigner function of an EML tree has not been defined.** W(x,p) is
   defined on phase space (ℝ²), but our trees live on associahedra (discrete
   combinatorial objects). The natural candidate is the Loday coordinate map
   (from `calibration_results.md`), which maps each Tamari vertex to a point
   in ℤⁿ⁻¹. But we haven't shown that the Wigner function on this discrete
   space reproduces the coinpurse shape.

---

## 7. Proposed Research Direction

### Step 1: Define the projection P : 𝕆ˢ → NodeCost explicitly

Map each of the 14 logic types to a vector in the split-octonion that
characterizes their position in the (4,4) signature. This should specify:
- Which basis vectors are "active" for each logic
- The norm of the corresponding vector (= time_weight² − space_weight²)
- Whether the vector is time-like, space-like, or null

### Step 2: Compute the full associator-coupling correspondence

For each of the 64 basis triples (eᵢ, eⱼ, eₖ) in 𝕆ˢ:
- Compute |assoc(eᵢ, eⱼ, eₖ)|
- Map to a specific coupling/denom value
- Verify that the cost classes from step 2 of the Cayley-Dickson ladder
  match the theoretical prediction

### Step 3: Formalize the cauldron metric

Define the cost landscape as a function on the associahedron Kₙ with:
- Radial coordinate: Φ (cost)
- Angular coordinates: Loday coordinates on Kₙ
- Metric tensor derived from NodeCost parameters

Compute the curvature at the trough, rim, and null cone boundary.

### Step 4: Conjecture and test the Born rule projection

State precisely: "For a tree t of size n, the Wigner function W(Φ(t), size(t))
equals [specific formula involving Φ(l), Φ(r), and their interference term]."
Then test this against the actual Φ values for quantum-like logics.

### Step 5: Integrate into Lean

Replace the axiom-heavy `unified_spacetime_engine_explicit.lean` with a verified
`SplitOctonion` structure that computes the multiplication table, associator
norms, and zero divisors — and connects them to `NodeCost` parameters via the
projection P from Step 1.

---

## Files Referenced

- `LaserCortex/unified_spacetime_engine_explicit.lean` — axiom-heavy split-octonion (current)
- `infra/tests/test_cayley_dickson_ladder.py` — Python verification of CD ladder
- `infra/tests/test_split_quaternion_calibration.py` — ℍ̃ calibration (completed)
- `infra/tests/test_torus_knot_calibration.py` — torus knot crossing formula (completed)
- `docs/calibration_results.md` — full calibration tables (v0.4)
- `docs/born_rule_cauldron.md` — Born rule motivation document
- `docs/CoertxCertificate.md` — cauldron geometry description
- `docs/lab_protocol.md` — (4,4) signature model
- `LaserCortex/Cost.lean` — NodeCost with depth-2 extensions
- `LaserCortex/AMM.lean` — crossImpact, associatorCost