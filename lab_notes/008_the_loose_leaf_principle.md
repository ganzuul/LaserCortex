# Lab Note 008: The Loose Leaf Principle

**Date**: 2026-06-25
**Angle**: Gap D Phase A implementation — replacing the `normalizeAcross` placeholder in `LogicMonad.lean`
**Status**: Discovery — explains how to use the framework

---

## The Discovery

When we implemented `normalizeAcross` — the normalization function that contracts
an arbitrary `LogicM α` tree to rightComb canonical form — we discovered that
**the leaf values (α) are automatically preserved**. This is not a design choice
we made. It is not a feature we added. It is structurally forced by the free
monad's definition.

The reshaping function `toRightComb`:

```lean4
private partial def toRightComb {α : Type} : LogicM α → LogicM α
  | .pure a => .pure a
  | .node l r => appendRightComb (toRightComb l) (toRightComb r)
```

has **no mechanism** to modify values of type `α`. It operates on tree structure
only. The leaf values pass through unchanged because the function doesn't know
what `α` is — and cannot, since `α` is universally quantified.

This is the free monad's universality property manifesting as a practical
guarantee: **structure normalizes, content persists.**

## The Name

### The Loose Leaf Principle

A `LogicM α` tree carries two layers:

1. **Structure** (the binary tree shape, mapped to `EMLTree`) — this can and
   does collapse to canonical rightComb form via Tamari contraction.
2. **Content** (the leaf values of type `α`) — these are structurally
   inaccessible to reshaping functions and therefore survive normalization.

The leaf values are "loose" in the sense that they are not fixed by the
normalization — they are the underdetermined question, the variable part that
triggers another round of generation in the Witness-Skeptic game.

## The Angle

We arrived at this by **closing Gap D Phase A**: replacing the `normalizeAcross`
placeholder that just returned `m` unchanged with a real implementation returning
`CortexCertificate × LogicM α`.

The expectation was that we would need to *design* leaf-value preservation —
explicitly extracting and re-inserting values. Instead, the implementation wrote
itself:

1. `leafValues` — extracts α values in depth-first order (trivial)
2. `appendRightComb` — structurally recursive merge of rightComb trees (trivial)
3. `toRightComb` — tree reshaping that passes α through (trivial)

Each function was forced by the types. There was exactly one way to write each
of them that type-checked. The difficulty wasn't in the implementation — it was
in **realizing that there was nothing to implement.**

## Why This Matters

### For the Eigenstate Collapse Model

The Eigenstate carries its SO coordinate as a set of scalar leaf values. The
Tamari tree collapse rule determines *which structural rearrangements are
permitted* at each collapse depth. The Loose Leaf Principle guarantees that:

- The Eigenstate's α-values (its "personality") survive collapse
- Only the tree structure (the "relationship between questions") normalizes
- The certificate proves the structural part is done; the content part is what
  drives the next generation round

### For Using the Framework

This is the central design principle: **separate structure from content, then
normalize structure while preserving content.**

Any computation that operates on tree shape (`toEMLTree`, `size`,
`contracts_to`, `rightComb`) is safe to apply — it cannot corrupt the α values.
Any computation that operates on α values (`map`, `bind`, leaf extraction) is
independent of the logic-parametric normalization layer.

The framework enforces this separation at the type level. You cannot accidentally
erase a loose leaf because the function that would do so cannot be written.

### For Phase B

Phase B (cdStep-aware differentiation) must follow the same principle:

- cdStep should constrain *which structural rearrangements* are permitted
- It should not touch the α values
- The differentiation mechanism is a pre-normalization filter on `contracts_to`,
  not a modification of `toRightComb`

This means Phase B's design is also forced by the types: we cannot make
Intuitionistic logic lose leaf values that Classical logic preserves, because
`toRightComb` doesn't know which logic it's in. The differentiation must happen
at the permission level (which contractions are allowed), not at the execution
level (how contraction works).

## Mathematical Core

The Loose Leaf Principle can be stated as a theorem:

> For any type `α`, any tree `t : LogicM α`, and any function
> `f : LogicM α → LogicM α` that is a natural transformation of the free monad
> (i.e., commutes with `map` for all `g : α → β`), `f` preserves the multiset
> of leaf values of `t`.

`toRightComb` satisfies this condition: it is natural in `α` because it never
inspects or constructs `α` values — it only rearranges the tree skeleton.

This means **the loose leaf theorem is a corollary of the free monad's
universality**, not an independent design achievement.

---

## Related

- `LogicMonad.lean` — implementation of `leafValues`, `appendRightComb`,
  `toRightComb`, and `normalizeAcross`
- `EMLRegistry.lean` — `contracts_to_rightComb` theorem, `CortexCertificate`
- `lab_notes/006_the_hopf_7_skeleton_of_logic_space.md` — tree shapes as logic
  space coordinates
- `lab_notes/007_the_so_carrier_morphism.md` — the carrier morphism that makes
  the Eigenstate model possible
