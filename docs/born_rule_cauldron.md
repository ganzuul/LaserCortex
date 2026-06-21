# Born Rule, Wigner Coinpurse, and the Cauldron

**Date:** 2026-06-21  
**Status:** Motivation document (no implementation yet)

## The Question

Why does the EML cost function need a `y²` (Born squaring) term, and how does
it connect to the cauldron geometry and the null cone?

---

## 1. The Cauldron Geometry

The log-exp cost function `eml(x, y) = exp(x) - ln(y)` naturally produces a
**cauldron-shaped** landscape (CoertxCertificate.md, line 21):

- **Trough** (Φ*): The stable equilibrium where the Witness does productive
  work. Near the bottom, the geometry is approximately flat — low curvature,
  cheap Tamari rotations.
- **Rim**: The exponential blow-up of Regime III. The curvature increases as
  you move outward.
- **Beyond the rim**: Not a boundary — it is a threshold. Crossing it spawns
  a new associahedron K_{n+1}. The horizon is Phase 5 discovery.

The cauldron is a **warped product geometry**: the fiber at each radius Φ is an
associahedron K_n, and the warping function is `f(Φ)` itself. Radially (along Φ),
the geometry curves by the activation function; angularly (around the
associahedron), by the Tamari rotation costs.

### Key property: the cauldron is bounded in one direction, unbounded in the other

The log term `-ln(y)` provides the **bounded** direction: as `y → 0⁺`, the cost
diverges to +∞. The trough exists because `exp(x)` grows and `-ln(y)` shrinks,
and they balance at Φ*. This is the *exponential* direction — the time axis,
where costs amplify.

The exp term `exp(x)` provides the **unbounded** direction: as `x → ∞`, the
cost grows without bound. This is the *logarithmic* direction — the space axis,
where costs compress.

### The null cone is where these balance

When `time_weight = space_weight` (i.e., `leftWeight = 1/(rightDiv+1)`), the
projection lands on the **null cone** — the interface where zero-divisor channels
open. This is exactly the balanced condition: Boolean, Intuitionistic, and Free
all have `time_weight = space_weight = 1`, which is the null cone of the (4,4)
signature.

---

## 2. Wigner's Coinpurse

Wigner's quasi-probability distribution W(x, p) is a real-valued function on
phase space that represents quantum states. It has a distinctive shape:

- **Near the origin**: W is positive — the "coin" part. This is where classical
  probability interpretation holds.
- **At intermediate radii**: W oscillates and can go negative — the "purse"
  part. These negative regions are quantum interference, the hallmark of
  non-classical behavior.
- **Far from the origin**: W decays — the "clasp" that closes the purse.

The structure is a **coinpurse**: a round, positive interior that narrows and
closes at the boundary, with oscillations (interference fringes) in the
transitional region.

### The coinpurse ↔ cauldron identification

| Wigner coinpurse feature | EML cauldron feature | Structural role |
|---------------------------|---------------------|----------------|
| Positive interior | Φ* trough (low cost) | Classical regime, low curvature |
| Negative oscillations | Regime III (exponential blow-up) | Quantum interference, high curvature |
| Boundary closure | Phase 5 horizon (new associahedron) | Phase transition boundary |
| Probability normalization | satCap (Fuzzy saturation bound) | Born rule projection |

The key insight: **Wigner's coinpurse IS the cauldron viewed from phase space**.
The cauldron's trough corresponds to the positive region of Wigner's function
where classical probability interpretation holds (Boolean/Free regime). The
cauldron's rim corresponds to the oscillatory region where quantum interference
creates negative quasi-probabilities (Paraconsistent/Quantum regime). The
cauldron's horizon (Phase 5) corresponds to the boundary of the coinpurse where
the distribution closes.

---

## 3. The Null Cone and the Born Rule

### The null cone does not expand forever

In flat Minkowski spacetime (Special Relativity), the null cone extends to
infinity. Light rays travel forever without bound. This is the **unbounded null
cone** — no saturation, no cap, no maximum cost.

But in our framework, the null cone is **bounded**. The satCap parameter bounds
the maximum cost that any subtree can accumulate. This is not a numerical
approximation — it is a structural feature:

- **Fuzzy** satCap = 5: The null cone closes after degree 5. Beyond that, all
  trees cost exactly 5, regardless of their structure. The coinpurse clasp
  has closed; the distribution is flattened.

- **Unbounded logics** (satCap = 0): The null cone extends without limit.
  Classical, Spacetime, Quantum all have uncapped costs. The coinpurse never
  closes — the distribution has infinite support.

- **Intuitionistic** maxSem: Not a cap, but a different kind of bound. The cost
  is bounded by tree height (log₂ growth), not tree size (linear growth). The
  null cone narrows logarithmically — each additional subtree contributes
  `max(a,b) + 1`, not `a + b + 1`. This is a **soft clasp**: the coinpurse
  closes gradually, not abruptly.

### The Born rule is the y² squaring that makes the coinpurse close

In the continuous EML formula:

```
eml(x, y) = exp(x) - ln(y)
```

If we replace `y` with `y²` (Born squaring):

```
eml(x, y²) = exp(x) - ln(y²) = exp(x) - 2·ln(y)
```

In the continuous case, this is **just doubling the logarithm** — a
reparametrization of the same EML, not a new function. The cauldron gets deeper
(the trough has twice the curvature) but its topology doesn't change.

**But in the discrete case (ℕ-arithmetic), y² is genuinely quadratic:**

```
Φ(r)² ≠ 2·Φ(r)    (for Φ(r) ≥ 2)
```

A tree of size 3 has Φ(r) = 3. With y², the contribution is 9, not 6. This is
the structural difference: squared costs grow **quadratically**, not linearly.
The coinpurse closes **faster** — the cauldron has steeper walls.

### Why y², not 2y?

| Formula | Continuous | Discrete (Φ=3) | Cauldron effect |
|---------|-----------|----------------|-----------------|
| `eml(x, y)` | `exp(x) - ln(y)` | `1 + a + b/2` | Standard rim |
| `eml(x, y²) = exp(x) - 2·ln(y)` | Double logarithm | `1 + a + b²/2` | Steeper walls, faster clasp |
| `2·eml(x, y)` | `2·exp(x) - 2·ln(y)` | `2 + 2a + b` | Scaled cauldron, same shape |

The Born rule gives `y²` (squaring), not `2y` (doubling). Squaring makes the
right subtree's contribution grow quadratically — this is the hallmark of
quantum probability, where probabilities come from squared amplitudes.

In the cauldron geometry: **the Born rule makes the walls of the cauldron
steeper, but it does not change the depth of the trough.** The trough is still
at Φ*, but the gradient away from Φ* is quadratic (Born) rather than linear
(well-tempered). The coinpurse closes faster with Born squaring because the
right-subtree costs pile up quadratically.

---

## 4. The Bounded Null Cone → Cauldron → Coinpurse

This is the structural chain:

```
Bounded null cone     →  Cauldron geometry      →  Wigner coinpurse
(satCap, maxSem)         (eml landscape)           (phase-space distribution)

Flat (Φ*)          ↔  Positive region          ↔  Classical probability
Steep (Φ**)        ↔  Oscillatory region       ↔  Quantum interference
Clasp (satCap)     ↔  Horizon/new associahedron ↔  Distribution boundary closure
```

The **bounded null cone** is what makes the cauldron a cauldron rather than
an infinite hyperbolic funnel. In flat Minkowski space, costs can grow without
bound — the geometry is open. But in our framework:

1. **Fuzzy** bounds costs at satCap = 5. The null cone closes at degree 5.
   The cauldron has a **hard wall**. The coinpurse has a **hard clasp**.

2. **Intuitionistic** bounds costs by tree height (logarithmic). The null cone
   narrows logarithmically. The cauldron has a **soft wall**. The coinpurse
   closes **gradually**.

3. **Quantum** (with Born squaring) makes the walls quadratic. The null cone
   doesn't close, but the curvature increases quadratically. The cauldron has
   **steep but unbounded walls**. The coinpurse nose-dives but never fully
   closes.

4. **Classical/Spacetime** (no bound, no squaring) are the flat cases. The null
   cone is unbounded. The cauldron is an **infinite funnel**. The coinpurse
   **never closes** — the distribution has infinite support.

---

## 5. Implementation Path (Deferred)

The `rightExponent` field on `NodeCost` would capture the Born squaring:

```lean
structure NodeCost where
  leftWeight : Nat
  rightDiv : Nat
  bias : Nat
  mirror : Bool := false
  coupling : Nat := 0
  denom : Nat := 10
  maxSem : Bool := false      -- depth-2: Φ = max(l, r) + bias (Intuitionistic)
  satCap : Nat := 0           -- depth-2: Φ ≤ satCap (Fuzzy)
  rightExponent : Nat := 1    -- depth-2: right subtree squared (Quantum Born)
```

When `rightExponent = 2`, the right subtree cost is squared before compression:

```
Φ(Node l r) = bias + leftWeight·Φ(l) + Φ(r)^rightExponent/(rightDiv+1) + coupling·Φ(l)·Φ(r)/denom
```

For Quantum with `rightExponent = 2, coupling = 1, denom = 10`:

```
Φ(Node l r) = 1 + Φ(l) + Φ(r)²/2 + Φ(l)·Φ(r)/10
```

This is the structural bridge to Wigner's function: the y² term is the Born
projection from complex amplitudes to real observables, and it makes the
coinpurse close faster (quadratic walls instead of linear).

**Why this is deferred:**
- The continuous EML simplification `ln(y²) = 2·ln(y)` suggests the Born
  rule might be captured by reparametrization rather than a new operation.
- In ℕ-arithmetic, Φ(r)² is genuinely quadratic (different from 2·Φ(r)),
  but the calibration target (split-octonion cost landscape) has not yet been
  tested with this formula.
- The coupling sweep needs to be re-run with depth-2 parameters before
  adding more depth-2 features.
- Intuitionistic and Fuzzy depth-2 behaviors need experimental validation
  against the associahedron geometry before adding Born squaring.

**When to implement:**
After running the coupling sweep with depth-2 Intuitionistic/Fuzzy parameters
and verifying that the cauldron geometry matches the Wigner coinpurse shape
for these two logics first.

---

## 6. Structural Summary

| Concept | Algebraic | Geometric | Cost function |
|---------|-----------|-----------|---------------|
| Null cone | a² − b² = 0 | Light cone | `leftWeight = 1/(rightDiv+1)` (balance) |
| Bounded null cone | |satCap| < ∞ | Hard cauldron wall | `satCap > 0` (Fuzzy) |
| Logarithmic bound | max(a,b) + 1 | Soft cauldron wall | `maxSem = true` (Intuitionistic) |
| Born squaring | y² before ln(y) | Quadratic cauldron wall | `rightExponent = 2` (Quantum) |
| Cauldron trough | Φ* equilibrium | Low-curvature region | `bias = 1` (all logics) |
| Cauldron rim | Regime III blow-up | High-curvature region | `leftWeight > 1` (Paraconsistent) |
| Phase 5 horizon | |K_{n+1}| transition | New associahedron | Discovery of new LogicType |

The **cauldron** is the geometric shape that emerges from any positive monotone
EML cost function. The **coinpurse** is what you see when you project it onto
phase space. The **null cone** is the set of directions where costs don't
grow — the balanced condition where the time and space contributions cancel.

The Born rule (y²) makes the coinpurse close faster because it squares the
space-direction contribution before compressing it. This is the algebraic
mechanism behind Wigner's negative quasi-probabilities: the quadratic growth
in the space direction creates regions where the Wigner function goes negative,
which are exactly the regions of quantum interference.

---

## References

- `docs/CoertxCertificate.md` — Cauldron geometry description (lines 21-38)
- `docs/calibration_results.md` — Sector weights, null cone classification
- `docs/lab_protocol.md` — (4,4) signature model, quench-collapse as zero-divisor
- `docs/critical_corrections.md` — Born rule discussion (lines 3828-3978)
- `LaserCortex/Cost.lean` — `NodeCost` structure with `maxSem`, `satCap`
- `infra/_cortex/_cost.py` — Python mirror with depth-2 parameters
- `infra/tests/test_depth2_cost.py` — 29 tests verifying depth-2 behavior