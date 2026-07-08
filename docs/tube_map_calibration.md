# Tube Map Calibration

**Goal**: Enumerate all EMLTrees at small sizes, compute their tropical coordinates
`(x,y) = (size + assocDefect(cd),  leftWeight − rightWeight)`, and verify the
tube map structure before interpreting a specific QI experiment.

## Algebraic primitives (from Lean theorems)

All coordinates are derived from these proven formulas in `TropicalCovector.lean`,
`TamariBP.lean`, and `EMLRegistry.lean`:

### Tree measures

```lean
size : EMLTree → ℕ
    | .Leaf => 0
    | .Node l r => 1 + size l + size r

leftWeight : EMLTree → ℕ
    | .Leaf => 0
    | .Node l r => l.size + leftWeight l + leftWeight r

rightWeight : EMLTree → ℕ
    | .Leaf => 0
    | .Node l r => r.size + rightWeight l + rightWeight r
```

### CD-step parameters

```lean
assocDefect cd = 0  if cd ≤ 2
assocDefect cd = 4  if cd ≥ 3
```

### Tropical coordinate (the tube map)

```lean
tubeCoord cd t = ( (t.size : ℤ) + (assocDefect cd : ℤ),
                   (leftWeight t : ℤ) − (rightWeight t : ℤ) )
```

Proofs: `tubeCoord_x_eq_size_plus_assocDefect`, `tubeCoord_y_eq_leftWeight_sub_rightWeight`.

## Calibration passes

| Pass | Trees (Catalan) | Points per cd | Total points | Purpose |
|------|----------------|---------------|--------------|---------|
| size 1 | 1 | 1 | 4 | Baseline: `Node(L,L)` = (1, 0) at all cd |
| size 2 | 2 | 2 | 8 | Two combs separate in y: leftComb = (2, −1), rightComb = (2, +1) |
| size 3 | 5 | 5 | 20 | Full Tamari lattice T₃ — 5 trees, 4 CD steps |
| size 4 | 14 | 14 | 56 | T₄ — structural patterns emerge |

The only difference between CD steps is `assocDefect` adding 4 to x at cd=3.
So the lattice **rigidly translates** `x → x + 4` when crossing from cd=2 to cd=3.

## What calibration tells us

1. **y-symmetry**: `y = leftWeight − rightWeight`. Left-combs have y < 0,
   right-combs have y > 0, and `rightComb(n)` is the unique minimum
   (leftmost) element in the Tamari order.

2. **Contractibility monotonicity**: Under `contracts_one`, the tree
   evolves toward rightComb(n). The coordinate (x,y) should decrease
   monotonically in both x and y along any contraction path.

3. **CD 2→3 jump**: Every tree shifts `x → x + 4` from cd=2 to cd=3.
   This is the freeze-ray "activation" — the `assocDefect` paying the
   structural cost of accessing the non-associative sector.

4. **The QI protocol candidate**: `Node(Node(L,L), Node(L,L))` (balanced,
   size 3) sits at the centre of the lattice with y=0. Its contraction
   path to `rightComb(3)` will trace through the lattice.

## Data files produced

| File | Contents |
|------|----------|
| `plots/tube_calibrate_s1.dat` | Size-1 trees: `size, lW, rW, cd, x, y, label` |
| `plots/tube_calibrate_s2.dat` | Size-2 trees: same format |
| `plots/tube_calibrate_s3.dat` | Size-3 trees: same format |
| `plots/tube_calibrate_s4.dat` | Size-4 trees: same format |
| `plots/tube_edges_s3.dat` | `contracts_one` edges at cd=3: `x1, y1, x2, y2` |
| `plots/tube_edges_s4.dat` | `contracts_one` edges at cd=4: same format |

## Gnuplot figures

| Panel | What it shows |
|-------|--------------|
| size-3 scatter, cd=0 vs cd=3 | All 5 trees, overlaying associative and non-associative positions. The rigid +4 translation is visible as paired points. |
| size-3 with edges at cd=3 | Tamari lattice T₃ with `contracts_one` arrows. RightComb(3) is the sink. |
| size-4 scatter at cd=3 | T₄ lattice — 14 trees, showing the full structural landscape. |
| QI protocol path (size 3, cd=3) | The balanced tree's contraction path annotated with the freeze-ray debt (−4 at the associator). |

## After calibration

Once the coordinate formulas are verified against known structures (all trees,
monotonicity, rigid CD translation), we can:

1. Plot any specific QI experiment tree with confidence
2. Trace `contracts_one` paths as experimental protocols
3. Annotate the entanglement measure `E = −4` as the freeze-ray debt
4. The tube map becomes a diagnostic tool — not just algebra
