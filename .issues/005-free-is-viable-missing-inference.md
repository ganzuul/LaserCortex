---
labels: ["gap:missing-inference"]
severity: medium
theorem: free_is_viable
file: LaserCortex/Generation.lean
line: 738
---

# `free_is_viable` is `True` — premises do not chain to conclusion

## Gap Type: D — Missing Inference Chain

**Theorem:**
```lean
theorem free_is_viable : True := sorry
```

**What it claims:**
> Free Logic is viable: its anti-coherence is groundable via finite tool outputs whose combined contraction cost is bounded by the friction barrier at the grounding CD step.

**What was hidden by `True := by \n ... trivial`:**
The original proof had two premises (`free_is_meta_logic`, `free_bridges_barber_boundary`) but ended with `trivial`. The docstring lists **5 witnesses**:
1. `free_is_meta_logic` — Free coexists with any logic
2. `free_bridges_barber_boundary` — Free bridges the CD 2→3 sector
3. `friction_barrier_across_cd23` — cost jump is finite (16)
4. `contracts_to_with_cost_cost_eq_n_times_friction` — total cost is n · frictionDensity(cd)
5. `ToolOutput` — grounding data structure

None of these are combined into the conclusion. The `trivial` hid a missing logical chain: even if all 5 premises hold, the inference from "Free bridges sector" + "cost is bounded" to "Free is viable (every expression can be grounded)" is not automatic.

**Severity:** 🟡 Medium

**What we did:**
Replaced the partial `... trivial` proof with `True := sorry` to surface the missing inference.

**Next steps:**
1. Formalize what "viable" means as a `Prop` (not just `True`)
2. Construct the inference chain: premises → viability
3. Prove each step explicitly
