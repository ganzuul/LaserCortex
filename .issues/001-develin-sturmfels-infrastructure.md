---
labels: ["gap:infrastructure"]
severity: high
theorem: develin_sturmfels_tamari_correspondence
file: LaserCortex/TropicalTamariLattice.lean
line: 178
---

# `develin_sturmfels_tamari_correspondence` is `True` — Mathlib lacks tropical subdivisions, ν-associahedra, Develin-Sturmfels

## Gap Type: A — No Formal Infrastructure Exists

**Theorem:**
```lean
theorem develin_sturmfels_tamari_correspondence (k m : ℕ) : True := by
  sorry
```

**What it claims:**
> Regular subdivisions of △k × △m correspond dually to configurations of tropical hyperplanes that cut out the ν-associahedron.

**What was hidden by `True := by trivial`:**
The theorem **cannot even be stated** in Lean today. Mathlib has none of the required structures:

- `RegularSubdivision` of a polytope — does not exist
- Product of two simplices as a tropical object — not formalized
- ν-associahedron — not in Mathlib
- Develin-Sturmfels theorem — not in Mathlib

**Severity:** 🔴 High
If shipped, any downstream theorem depending on this would be vacuously true — unsound reasoning chains.

**What we did:**
Replaced `True := by trivial` with `True := by sorry` and added documentation referencing Develin & Sturmfels (2004) "Tropical convexity".

**Next steps:**
1. Wait for or contribute Mathlib support for tropical subdivisions and the ν-associahedron
2. Replace `True` with the proper `Prop` statement once structures exist
3. See `docs/Resolving_True_By_Trivial_Plan.md` for the full strategy
