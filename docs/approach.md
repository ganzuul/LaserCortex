# Approach to Geometry and Motion

## Overview

We formalize the **Tamari lattice** as the rewrite system for multi-hop AMM
routing, where each EML tree encodes a swap decomposition and Tamari rotation
`contracts_to` reorders execution hops. The **cost function Φ**, parameterized
by 14 logic types, assigns a discrete cross-impact to each decomposition —
essentially the discrete ℕ analogue of the continuous EML operator
`eml(x,y) = exp(x) − ln(y)`.

## Geometry: Tamari lattice as routing space

- **EMLTree** nodes `∙(a,b)` represent a swap pair; `Leaf` marks the base.
  A tree `(a∙b)∙c` means "swap a with b, then swap the result with c";
  the right-comb `a∙(b∙c)` means "swap b with c first, then swap a with the
  result". These are the two extreme execution orders for three hops.

- **Tamari rotation** `contracts_one` rewrites `(a∙b)∙c → a∙(b∙c)`. This is
  exactly the familiar associativity move of the Tamari lattice. The transitive
  closure `contracts_to` is the partial order of the lattice — every route
  decomposition is comparable to every other via a sequence of rotations.

- The **rightComb** (the right-rotated normal form) is the universal sink:
  every tree can be rotated into a unique rightComb. This corresponds to the
  optimal (lowest cross-impact) execution order for classical-like logics.

## Motion: Cost Φ as cross-impact

- **Φ(Leaf) = 0**, and for a node `(l,r)`:
  ```lean
  Φ(∙(l,r)) = bias + leftWeight·Φ(l) + Φ(r)/rightDiv.succ
  ```
  The asymmetry mirrors the EML operator: `exp(x)` amplifies the left argument
  (like `leftWeight > 1` blows up the left subtree's contribution), while
  `ln(y)` compresses the right argument (like `rightDiv > 1` shrinks the right
  subtree's contribution via integer division).

- For **Classical-like logics** (rightDiv = 0 → denominator 1), cost is
  preserved by rotation: Φ(s) = Φ(t) whenever `contracts_to s t`. This means
  all decompositions of the same set of hops incur the same cross-impact —
  execution order does not matter.

- For **non-Classical logics** (rightDiv > 0), cost can change under rotation.
  This is the key geometric insight: **different logics assign different costs
  to the same sequence of hops depending on execution order**. The Tamari
  lattice becomes *curved* — the cost function defines a discrete metric on
  the lattice that reflects the logic's asymmetry.

## The 14 logic types

Each logic type defines a distinct friction regime:

| rightDiv | leftWeight | Logic Types                | Behavior                               |
|----------|------------|----------------------------|----------------------------------------|
| 0        | 1          | Intuitionistic, Free       | Classical — Φ = size, rotation-invariant |
| 1        | 1          | Classical, ManyValued, …   | Balanced — right ÷ 2                   |
| 2        | 1          | Fuzzy, Deontic, Epistemic  | Right-compressed — right ÷ 3           |
| 1        | 2          | Paraconsistent, Temporal, Spacetime | Left-amplified               |

The **Spacetime logic** (14th type, leftWeight=2, rightDiv=1) captures the
geometric/spatiotemporal dimension — its cost doubly penalizes depth in the
left subtree, mirroring how spacetime curvature concentrates in the
gravitational (left) direction while spreading evenly (right ÷ 2) in the
orthogonal direction.

## Connection to AMM routing

- A **Route** in `AMM.lean` is a sequence of pool swaps. `routeToTree` converts
  it to an EMLTree decomposition.
- The **cost Φ** of that tree is the cross-impact cost of executing the route
  in that order.
- The **optimal route** for a given logic type is the one whose tree has
  minimal Φ, which (for classical-like logics) is always the rightComb.
- For non-classical logics, the optimal path may differ, and the Tamari lattice
  provides the search space.

The routing graph inherits the Tamari lattice structure as its "geodesic"
backbone. Cross-impact propagates along edges defined by `contracts_to`,
and the pentagon defect from `unified_spacetime_engine_explicit.lean` provides
the continuous bounding strategy for the discrete floor errors in Φ.
