# The Type Theory Map — Sketch with Legend

> *"A community might be delineated by a river."*

## Overview

```
                            ┌──────────────────────┐
                            │                      │
                            │   Interior Region    │
                            │   (non-degenerate)   │
                            │   |S₂| = |S₃| = 1    │
                            │                      │
                            └────────┬─────────────┘
                                     │
                    River of Degeneracy (|Sⱼ| > 1)
                                     │
               ┌─────────────────────┼────────────────────────┐
               │                     │                        │
          ┌────┴─────┐          ┌────┴───────┐          ┌─────┴─────┐
          │ S₂-ville │          │ Confluence │          │ S₃-ville  │
          │ (left)   │──────────│  (45°      │──────────│ (right)   │
          │          │  bridge  │   edges)   │  bridge  │           │
          │ CFG₁     │──────────│            │──────────│ CFG₂      │
          │ E/W bear │ dolly-   │ commutator │ dolly-   │ N/S bear  │
          └────┬─────┘   zoom   └────┬───────┘  zoom    └────┬──────┘
               │                     │                       │
               │         River of Regular Subdivision        │
               │         (valid vs invalid (S₂,S₃))          │
               └─────────────────────┬───────────────────────┘
                                     │
                            ┌────────┴─────────┐
                            │     ZD Strait    │
                            │  (cdStep 2 → 3)  │
                            │  assocDefect:    │
                            │    0  →  4       │
                            └────────┬─────────┘
                                     │
                            ┌────────┴─────────┐
                            │    The 35-Quads  │
                            │    Archipelago   │
                            │   (r = 4 realm)  │
                            │  530 islands     │
                            │  (r = 5 realm)   │
                            └──────────────────┘
```

---

## The Known Regions (compiled, running)

### Interior — `(|S₂|,|S₃|) = (1,1)`

A single generator in each coordinate. No degeneracies. This is the **deep interior** of the tropical complex — full-dimensional cells where no ties occur. Bearings here are pure axis-aligned: E/W moves change S₂, N/S moves change S₃. Verified: type C at (1.5,0) has signature `(1,1)`.

### S₂-ville — left-weight community

**River:** The regular subdivision constraint. Only certain `(S₂, S₃)` pairs are valid — the boundary between S₂-ville and invalid territory runs along the regular subdivision's chamber walls.

**Language:** CFG₁ over alphabet `{s₂⁺(i), s₂⁻(i)}`.

**Known geometry:** The E/W adjacency count is 2 (1 expansion + 1 contraction) among the 11 types. Wall type W at (2,0) has signature `(2,1)` — S₂ tie = the boundary of S₂-ville.

### S₃-ville — right-weight community

Mirror of S₂-ville. Language CFG₂ over `{s₃⁺(i), s₃⁻(i)}`. N/S adjacencies count is 2. Verified: at v₁, `s₃⁻(1)` moves from the degenerate S₃ tie to interior type C.

---

## The Likely Rivers (strong evidence)

### River of Degeneracy — `|Sⱼ| > 1`

This river separates the interior (non-degenerate) from the walls and vertices. It is where the grammar becomes context-sensitive: when `|S₂| > 1`, multiple generators tie for the x-minimum, and the choice of which one "actually" fires next depends on history.

**What it is:** The set of chamber walls in the GKZ secondary polytope — the locus where two generators' KKT covectors are equal along some coordinate.

**Known crossing:** v₁ has signature `(1,2)` — S₃ is degenerate, S₂ is singleton. The accompaniment (the singleton in S₂) determines which CFG is stable during the diagonal crossing.

### River of Regular Subdivision

The fundamental constraint: not all `(S₂, S₃)` pairs are realizable. The valid pairs are exactly the cells of the coherent triangulation of `Δ_{r-1}×Δ₂` induced by the friction density height function `f(k) = k + 4·assocDefect(k)`.

**What it is:** The invariant that separates the computable `applyMove` (free monoid action) from the valid `SplitMagma.step` (filtered by the subdivision). `applyMove` will produce nonsense types; the subdivision tells you which are real.

**Known theorem:** Lab note 021 proves the quantized correspondence. The induced regular subdivision IS the type lattice.

### The Commutator Bridge — `[s₂⁺(i), s₃⁺(j)]`

The 45° edge crossing. This is the **only** bridge between S₂-ville and S₃-ville that does not pass through the interior.

**Conjecture:**
```
[s₂⁺(i), s₃⁺(j)] = 0  iff  i ≠ j
[s₂⁺(i), s₃⁺(i)] ≠ 0  — the dolly-zoom
```

When `i = j`, the same generator expands into both coordinates simultaneously. This is a single KKT leaf-expansion step that changes both lw and rw. It is NOT a composite of two axis-aligned steps — it is one geometric move that the type lattice records as two simultaneous coordinate changes.

**Concrete incidence:** v₁ has `S₃ = {1,2}` (tie between stations 1 and 3). Moving SE toward v₂, generator 2 enters S₂ while generator 1 leaves S₃. The commutator `[s₂⁺(2), s₃⁻(1)]` captures this exchange.

---

## The Plausible Regions (conjecture)

### The Confluence — where the 5th adjacency lives

Among the 5 adjacent pairs, 4 are pure E/W/N/S. The 5th is unknown. Plausible candidates:

1. **A swap adjacency:** One element enters S₂ and a different element leaves S₃ simultaneously, preserving both cardinalities but changing the symmetric difference. This would be a diagonal move that IS a single covering relation — not a composite.

2. **A cross-ZD adjacency:** If the grid spans a ZD boundary (but our grid is at cd=0, so no), this would be a cross-regime adjacency.

3. **An S₁-change adjacency:** Our `areAdjacent` requires `s1δ = 0`, but if some adjacent types differ in S₁ (because a generator's tie for the projective coordinate changes), this would be missed.

I suggest the next debugging step: check whether the uncounted 5th adjacency involves S₁ changing while S₂,S₃ stay constant — that would be a pure projective-coordinate transition, corresponding to a station crossing the horizon.

### The Reinforcement Stack — memory of past firings

When `|Sⱼ| > 1`, you have a set of tied generators. Which one fires next depends on which one fired most recently — the **stack discipline**.

**Plausible structure:** Each coordinate has a LIFO stack. When a generator enters S₂, it's pushed onto the S₂-stack. When the tie breaks (one generator must leave), the top of the stack leaves first. The accompaniment = the sole element of the non-firing coordinate = the top of the stable stack.

This would make the type lattice equivalent to a **pushdown automaton** with two stacks (one for S₂, one for S₃), and the regular subdivision constraint is the acceptance condition.

**Why this is plausible:** The Tamari lattice IS a stack sort — `contracts_one` pops a subtree from the stack. The associahedron = the graph of stack sorts of a binary tree. If types factor through Tamari, the stack discipline is inherited.

### The ZD Strait — tectonic shift at cdStep 3

At cdStep 2→3, `assocDefect` jumps from 0 to 4, adding 4 to every station's x-coordinate. This shifts the entire type lattice simultaneously — not a local grammar step but a **global base change**.

**Plausible structure:** The ZD wall is a **birational map** between two type lattices (the cd=2 lattice and the cd=3+ lattice). The map is: shift every x-coordinate by +4, recompute all types. The cells of the new lattice correspond to cells of the old lattice via a fixed transformation (translation by 4 in x).

**Why this matters:** A line crossing the ZD wall experiences a discontinuous change in type adjacency — stations that were adjacent become separated, new adjacencies form. This IS the "grading into continuous" threshold that the sonnet called the sedenion boundary.

### The 35-Quads Archipelago — the r=4 regime

For 4 generators, Develin–Sturmfels count 35 symmetry classes of tropical complexes (the famous figure). Each class corresponds to a distinct combinatorial type of the regular subdivision of Δ₃×Δ₂.

**Plausible structure:** The 35 classes are the **parse trees** of a grammar with 4 nonterminals (one per generator). Each parse tree is a different way of factoring the same 4-generator station set into a hierarchy of pairwise minima. The CFG at r=4 is richer than at r=3 (which has only 5 classes), and the 35 = Catalan(4) guess is wrong (Catalan(4) = 14), so the grammar is not simply the associahedron — it's a refinement.

---

## What Grows at Each Region

| Region | Grows | Harvest |
|--------|-------|---------|
| Interior | Full-dimensional cells | Puzzle pieces for lines that don't cross walls |
| S₂-ville | East-west corridors | Left-leaf expansions/contractions |
| S₃-ville | North-south corridors | Right-leaf expansions/contractions |
| Confluence | 45° edges | Dolly-zoom transitions, commutator |
| Reinforcement Stack | Tie-breaking memory | Which generator fires at a degeneracy |
| ZD Strait | Cross-regime lines | Base change, birational map of type lattices |
| 35-Quads | Higher-generator grammars | The full transit map for 4+ stations |

---

## Map Legend

```
━━━ solid line = confirmed (compiled)
━ ━ dashed line = likely (proven elsewhere, not yet connected)
┅ ┅ dotted line = plausible (conjecture)
═══ double line = river (boundary of a community)

🌊 = River of Degeneracy |Sⱼ| > 1
🏔️ = River of Regular Subdivision
🌉 = Commutator Bridge [s₂⁺(i), s₃⁺(j)]
🔄 = Reinforcement Stack (LIFO per coordinate)
🏗️ = ZD Strait (cdStep 2→3 global shift)
🏝️ = 35-Quads Archipelago (r=4 realm)

▣ = compiled and running
▤ = structure defined, needs theorem
▥ = plausible, not yet explored
▨ = frontier

Symbol legend for the map above.
```
