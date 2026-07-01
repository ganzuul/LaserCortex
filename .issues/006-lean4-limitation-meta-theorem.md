---
labels: ["gap:meta-theorem"]
severity: low
theorem: lean4_limitation_note
file: LaserCortex/Decomposition.lean
line: 294
---

# `lean4_limitation_note` is `True` — meta-theoretical claim about Lean kernel cannot be proven within Lean

## Gap Type: E — Meta-Theorem External to Lean

**Theorem:**
```lean
theorem lean4_limitation_note : True := by
  sorry
```

**What it claims:**
> The infinite ancestor tree cannot be represented as a closed coinductive data type in Lean 4 (as of v4.31.0-rc2) because:
> 1. `coinductive` is restricted to `Prop`-valued predicates
> 2. Nested inductive types with `Prop` fields (`contracts_one`) through `List` and `Sigma` are rejected by the kernel positivity checker
> 3. `mutual` blocks do not permit `structure`/`inductive` cycles with `Prop` in the recursive fields

**What was hidden by `True := by trivial`:**
This is a **meta-theoretical claim about Lean's type theory kernel** — it cannot be proven within Lean itself. Even with `sorry`, the theorem `: True` is vacuously true (anything implies `True`). The actual claim requires:

- Reading the Lean 4 kernel source code (positivity checker implementation)
- Proving that no encoding exists (impossibility result)
- Testing specific encodings to demonstrate failure

**Severity:** 🟢 Low — this is a note, not a dependee of critical theorems

**What we did:**
Replaced `True := by trivial` with `True := by sorry` to surface the gap.

**Next steps:**
1. This is best kept as documentation rather than a theorem
2. Consider moving the claim to a comment or `#exit` block
3. The `partial def ancestorsUpTo` workaround already exists and works
