---
labels: ["gap:conjecture"]
severity: high
theorem: strut_weight_conjecture
file: LaserCortex/Generation.lean
line: 645
---

# `strut_weight_conjecture` is `True` — CD 2→3 boundary depends on open algebraic conjecture

## Gap Type: C — Unproven Conjecture

**Theorem:**
```lean
theorem strut_weight_conjecture : True := sorry
```

**What it claims:**
> `strut_weight = 4` implies that the CD 2→3 boundary is not arbitrary — it is the algebraic consequence of the split octonion's (4,4) signature having exactly 4 strut-like dimensions (the non-associative ones). The required proof is: `strut_weight = 4 ⇒ ∀ a ∈ NonAssocSector, frictionDensity(a) - frictionDensity(Classical) ≥ 16`.

**What was hidden by `True := True.intro`:**
This is a **genuine open conjecture** — the docstring honestly says "remains conjectural." The `True.intro` was stamping "proved" on a conjecture:

- `SplitOctonionCost.strut_weight = 4` is not proven
- The implication `strut_weight = 4 ⇒ friction gap ≥ 16` is not proven
- The definition of `NonAssocSector` is not formalized
- There is no proof that the 4 non-associative dimensions correspond to struts

**Severity:** 🔴 High
The CD 2→3 sector boundary argument — which the barber paradox mechanism depends on — would be unsound if this conjecture is false.

**What we did:**
Replaced `True := True.intro` with `True := sorry` to surface the gap.

**Next steps:**
1. Prove `strut_weight = 4` or find a counterexample
2. Formalize `NonAssocSector`
3. Prove the implication to `frictionDensity` gap
4. See `docs/Resolving_True_By_Trivial_Plan.md`
