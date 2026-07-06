# Lab Note 023: `CDHomotopyPath` vs Sonnet 5's "Height Function"

**2026-07-06**

## Sources

- Old code at commit `dec4d8c`, `LaserCortex/CayleyDickson.lean` lines 556–581
- Sonnet 5 on discrete-continuous: `docs/sonnet-5_on_discrete-continuous.md` (esp. the last `---` section from line 77)
- Lab Protocol v0.3: `docs/lab_protocol.md`

## 1. What `CDHomotopyPath` Was

```lean
structure CDHomotopyPath where
  start  : CDParameter := .split    -- α = +1 (indefinite, ZDs at step ≥ 3)
  target : CDParameter := .compact  -- α = -1 (definite, no ZDs ever)
  step   : ℚ := 0                   -- interpolation parameter t ∈ [0,1]
```

The homotopy `α(t) : [0,1] → {+1, -1}` continuously deforms the split branch
into the compact branch. The `value` function:

```lean
def CDHomotopyPath.value (h : CDHomotopyPath) : CDParameter :=
  if h.step ≤ 0 then .split
  else if h.step ≥ 1 then .compact
  else .split
```

This is essentially a **step function**, not a genuine interpolation — for any
`0 < t < 1` it returns `.split`. The ℚ parameter was allocated but never
connected to any actual computation or theorem. No downstream code used it.

### What it was trying to model

The CD parameter `α` in `Q' = Q ⊕ α·Q` determines the quadratic form on the
new coordinate. The homotopy represents a continuous deformation that changes
the algebra's signature from (k,k) to (2k,0) — i.e., from split to compact.

### What it was NOT

- It was **not** connected to any height function, cost value, or KKT coefficient
- It was **not** integrated with the Φ cost landscape or frictionDensity model
- It was **not** used to derive discrete combinatorial structure (no wall-crossing,
  no chamber decomposition, no triangulation flip)

---

## 2. What Sonnet 5 Describes (last `---`, line 77 onward)

Sonnet 5 describes the **GKZ regular subdivisions / secondary polytopes**
framework (Gelfand–Kapranov–Zelevinsky). The key claims:

### 2a. The associahedron IS the secondary polytope of a polygon

> "for points arranged around a convex polygon, the polytope whose vertices are
> exactly the triangulations, and whose edges are exactly the flips, is the
> associahedron."

### 2b. Continuous heights → discrete triangulations via lower convex hull

> "Take a set of points and give each one a real-number 'height'. Lift each
> point up by its height, take the lower convex hull of the lifted points, and
> project back down — the shadow of that hull's faces gives you a triangulation."

The continuous data (the height assignment) determines a discrete combinatorial
object (the triangulation). Different heights → different triangulations.
Most heights lie in a "chamber" (producing the same triangulation). A measure-zero
set of heights lie on "walls" between chambers (where two triangulations tie).

### 2c. Wall-crossing = the discrete flip

> "a continuous nudge of the points crosses a threshold where the discrete choice
> flips"

The sign-cocycle φ from alternativity is reinterpreted: it's not a separate rule
bolted on — it's the answer to "which side of which wall am I on."

### 2d. Concrete next move

> "pick the KKT/covector coefficients you're already computing per tree and ask
> whether they behave like a height function — does the discrete bracketing/flip
> your code selects change exactly at the loci where two of those covector values
> become equal?"

This is the **circumcircle test**: the Delaunay condition says a flip occurs
exactly when four points become cocircular (the lifted points are coplanar).
If the KKT/covector coefficients are the height data, then the ZD boundary
(cdStep 3) is the wall where two covector values cross.

---

## 3. Is `CDHomotopyPath` What Sonnet 5 Was Describing?

**No — they're different levels of structure.**

| Aspect | `CDHomotopyPath` | Sonnet 5's height function |
|--------|------------------|---------------------------|
| Domain | One binary choice (split vs compact) | Many points (all trees in a triangulation) |
| Continuous parameter | Single ℚ value (0 ≤ t ≤ 1) | A height for EACH point (n-dimensional) |
| Discrete output | A CDParameter (2 values) | A triangulation (Catalan-many) |
| Wall | t = 0 or t = 1 (endpoints) | Where two covector values become equal |
| Connected to cost? | No | Yes (KKT coefficients from Chu pairing) |
| Connected to flips? | No | Yes (triangulation flip = associativity step) |

`CDHomotopyPath` is at best a **1-dimensional slice** of what Sonnet 5
describes. The homotopy only interpolates between two fixed endpoints (split
and compact). Sonnet 5's framework assigns a *separate* continuous height to
each point (each tree/vertex), and the discrete structure that emerges is the
*entire triangulation* — not just a binary label.

**More precisely:** `CDHomotopyPath` treats the CD parameter α as a *global*
continuous parameter that applies to the whole algebra at once. Sonnet 5's
picture treats each tree's cost/KKT coefficient as an *individual* height that
collectively determines the local bracketing choice. These are different
objects at different scales.

### But there IS a connection at the threshold level

The wall in Sonnet 5's picture — where two covector values become equal and
the discrete flip occurs — is structurally analogous to the **ZD boundary at
cdStep 3**:

| Wall in GKZ | ZD boundary at cdStep 3 |
|-------------|------------------------|
| Two heights cross | `frictionDensity` jumps from `k` to `k+16` |
| Flip in triangulation | Associator becomes active |
| Degenerate (cocircular) points | Null vectors (zero-norm elements) appear |

The `CDHomotopyPath.step` parameter could be reinterpreted as controlling
*which side of the ZD boundary* the system is on:
- `step = 0` → below boundary (associative regime, no ZDs)
- `step = 1` → above boundary (non-associative regime, ZDs exist)

But this is just the binary split/compact distinction, not the full
multi-dimensional height space that determines which *specific* bracketing
is selected at each node of each tree.

---

## 4. What Would Need to Be True for Sonnet 5's Picture to Connect to Our Model

### 4a. The KKT/covector coefficients must BE height functions

Sonnet 5's concrete next move: "pick the KKT/covector coefficients you're
already computing per tree and ask whether they behave like a height function."

In our framework, the natural candidates are:

- **`frictionDensity cd`** per logic type (a single number per cdStep)
- **`layerCost lt`** = `frictionDensity lt.cdStep` (cost per layer)
- **`splitQuatPairing y z`** — the Chu pairing that gives the KKT multipliers
- **`weightedCost cd t`** = `dcStep t × frictionDensity cd` (cost per tree)

The "covector coefficients" are the **Lagrange multipliers** from the Chu
embedding's KKT stationarity condition (`chu_embed_mul`). These are the
elements of `SplitQuat` that serve as dual variables adjusting the SMul
structure.

**To be a height function in the GKZ sense**, these coefficients must satisfy:
1. Each tree (or basis element) is assigned a real (or ℤ) value
2. The discrete bracketing choice at a node changes exactly when two such
   values become equal
3. The lower convex hull of lifted points reproduces the Tamari lattice

### 4b. The circumcircle test

The concrete experiment: for a pair of trees that differ by a single
`contracts_one` rotation, compute the two covector values on either side
of the rotation. Are they equal exactly at the ZD boundary (cdStep 3)?

If yes: the ZD boundary is literally a wall in the secondary polytope of
the Cayley-Dickson tower, and `frictionDensity` is the height function.

### 4c. The homotopy would be a path through height-space

If the above holds, then `CDHomotopyPath` would not be a single ℚ parameter
but a **path through the space of height assignments** — i.e., a family of
cost functions `Φ_L(t)` indexed by a continuous parameter t, where
`Φ_L(0)` is the split regime and `Φ_L(1)` is the compact regime, and the
walls crossed along the path correspond to the ZD boundaries at various
cdSteps.

This is a much richer object than the old `CDHomotopyPath` — it would be a
**homotopy of cost landscapes**, not just a binary label.

---

## 5. Verdict

| Question | Answer |
|----------|--------|
| Is `CDHomotopyPath` what Sonnet 5 described? | **No** — different scale and dimension |
| Could it be generalized to fit? | **Yes** — if reinterpreted as a 1D slice through height-space |
| What's the next concrete step? | **The circumcircle test**: check if KKT/covector coefficients from `splitQuatPairing` behave like heights (equal at flip boundaries) |
| Should we keep `CDHomotopyPath`? | **No** — too naive, not connected to any actual computation. Replace with the GKZ picture if the circumcircle test passes. |

### Recommendation

1. **Drop** `CDHomotopyPath` — it's dead code that doesn't capture Sonnet 5's insight
2. **Do not add back** `CDParameter` or related old definitions
3. **If pursuing Sonnet 5's direction**: implement the circumcircle test in Python
   (compute covector coefficients per tree, check equality at flip boundaries)
   before formalizing anything in Lean
4. **For the Lean path**: the existing `frictionDensity` threshold at cdStep 3
   already captures the ZD wall location — Sonnet 5's framework would explain
   WHY it's there (it's where the regular subdivision's wall-crossing occurs)
