---
labels: ["gap:no-target"]
severity: medium
theorem: generation_in_bounded_class
file: LaserCortex/TamariBP.lean
line: 403
---

# `generation_in_bounded_class` returns `True` instead of `BoundednessClass` — wrong return type

## Gap Type: B — No Target Defined (Wrong Return Type)

**Theorem:**
```lean
theorem generation_in_bounded_class (nl : Generation.UngroundedNL)
    (hpos : nl.possibleParsings > 0) : True := by
  sorry
```

**What it claims:**
> Generation.lean at CD 3 is in the bounded class. Every groundable NL input is in `BoundednessClass 19` — BFS is always feasible.

**What was hidden by `True := by trivial \n ... trivial`:**
The `: True` return type is **wrong**. The neighboring theorem `cd3_always_tractable` demonstrates the correct type:

```lean
theorem cd3_always_tractable (nl : Generation.UngroundedNL)
    (hpos : nl.possibleParsings > 0) : BoundednessClass 19 (EMLRegistry.rightComb 3) := by
  have h_dcStep : dcStep (EMLRegistry.rightComb 3) = 0 := dcStep_rightComb 3
  unfold BoundednessClass
  rw [h_dcStep]
  omega
```

The `trivial` hid a type error in the theorem statement — the return type `True` is vacuously true regardless of the actual claim.

**Severity:** 🟡 Medium

**What we did:**
Replaced `True := by ... trivial` with `True := by sorry` and documented the correct type.

**Next steps:**
1. Change return type to `BoundednessClass 19 (EMLRegistry.rightComb 3)`
2. Provide the same proof as `cd3_always_tractable`
3. Consider whether the statement should reference `nl` (currently unused by `cd3_always_tractable` — the dependency on the NL input is not reflected in the type)
