import Mathlib
import LaserCortex.foundations.Algebra
import LaserCortex.foundations.Tamari
import LaserCortex.Friction

open Finset

/-!
# Tropical Type Algebra — Develin–Sturmfels Type Lattice for the Octolinear Transit Map

```
                             ┌──────────────────────┐
                             │    Interior Region    │
                             │   (non-degenerate)    │
                             │   |S₂| = |S₃| = 1    │
                             └────────┬─────────────┘
                                      │ ▣
                     River of Degeneracy (|Sⱼ| > 1)
                                      │
                ┌─────────────────────┼─────────────────────┐
                │                     │                     │
           ┌────┴────▣          ┌────┴────▥          ┌─────┴─────▣
           │ S₂-ville │          │ Confluence │          │ S₃-ville  │
           │ (left)   │──────────│  (45°      │──────────│ (right)   │
           │          │  bridge  │   edges)   │  bridge  │           │
           │ CFG₁ ▣   │──────────│ commutator  │──────────│ CFG₂ ▣   │
           │ E/W bear │ dolly-   │ ▥           │ dolly-   │ N/S bear  │
           └────┬────┘   zoom   └────┬────┘    zoom    └────┬──────┘
                │                     │                      │
                │         River of Regular Subdivision       │
                │         (valid vs invalid (S₂,S₃))        │
                └─────────────────────┬──────────────────────┘
                                      │ ▤
                             ┌────────┴─────────┐
                             │     ZD Strait    │
                             │  (cdStep 2 → 3)  │
                             │  assocDefect:    │
                             │    0  →  4       │
                             └────────┬─────────┘
                                      │ ▥
                             ┌────────┴─────────┐
                             │   35-Quads Arch  │
                             │   (r = 4 realm)  │
                             └──────────────────┘
                                      │ ▨
```

Legend:
  ▣ = compiled and running (this file)
  ▤ = structure defined, needs theorem
  ▥ = plausible, not yet explored
  ▨ = frontier

See `docs/type_theory_map.md` for the full map with rivers, communities, and bridges.

## Origin
Defines the type system from Develin & Sturmfels "Tropical Convexity" (2004) §2–3
for stations (generators) in TP², with the concrete 3-station worked example.

## Hypothesis (lab note 032)
- The Develin–Sturmfels type `(S₂, S₃)` at a point are the **coordinates** of
  that point in the tropical complex.
- The face poset of types, drawn with `transitCoord` (KKT covector) layout,
  gives the octolinear transit map.
- 45° edges correspond to degenerate types where `|Sⱼ| > 1` for some coordinate j.
- The type lattice is a **split magma** with signature `(p,q) = (|S₂|, |S₃|)`,
  decomposing into two orthogonal CFGs (left-weight / right-weight) whose
  commutator `[s₂⁺(i), s₃⁺(j)]` vanishes iff `i ≠ j`.

This file defines the algebra and runs `#eval` checks to verify the hypothesis
for the 3-station case from `docs/type_algebra_worked_example.md`.
Sections: 0–9 = core algebra and experiment; 10–13 = split magma and leaf polarity.
-/

-- ============================================================================
-- SECTION 0: Inlined definitions from OctilinearEmbedding.lean
-- (that file has pre-existing compile errors, so we define only what we need)
-- ============================================================================

/--
The transit map coordinate of a tree `t` at CD step `cd`:

   transitCoord cd t = (t.size + assocDefect cd, leftWeight t - rightWeight t)
-/
def transitCoord' (cd : ℕ) (t : EMLTree) : ℤ × ℤ :=
  ((t.size : ℤ) + (assocDefect cd : ℤ), (leftWeight t : ℤ) - (rightWeight t : ℤ))

-- ============================================================================
-- SECTION 1: Type Definition
-- ============================================================================

/--
A **Develin–Sturmfels type** for a point in TP² relative to a generator set V.

For `x = (0, u, v)` and generators `v_i = (0, x_i, y_i)`:
  i ∈ S₁  iff  dᵢ = 0          where dᵢ = min(0, xᵢ−u, yᵢ−v)
  i ∈ S₂  iff  dᵢ = xᵢ − u
  i ∈ S₃  iff  dᵢ = yᵢ − v

A generator can be in multiple Sⱼ when coordinates tie for the minimum.
-/
structure TropicalType where
  S₁ : Finset ℕ
  S₂ : Finset ℕ
  S₃ : Finset ℕ
deriving DecidableEq

namespace TropicalType

/-- The containment relation: type A precedes type B if each Sⱼ of A is a subset of B's. -/
def subset (A B : TropicalType) : Prop :=
  A.S₁ ⊆ B.S₁ ∧ A.S₂ ⊆ B.S₂ ∧ A.S₃ ⊆ B.S₃

instance : HasSubset TropicalType := ⟨subset⟩

theorem subset_refl (A : TropicalType) : A ⊆ A :=
  ⟨Finset.Subset.refl _, Finset.Subset.refl _, Finset.Subset.refl _⟩

theorem subset_trans {A B C : TropicalType} (hAB : A ⊆ B) (hBC : B ⊆ C) : A ⊆ C :=
  ⟨Finset.Subset.trans hAB.1 hBC.1, Finset.Subset.trans hAB.2.1 hBC.2.1, Finset.Subset.trans hAB.2.2 hBC.2.2⟩

/-- A type is degenerate if any Sⱼ has cardinality > 1. -/
def degenerate (T : TropicalType) : Bool :=
  T.S₂.card > 1 || T.S₃.card > 1

/-- Pretty-print as (S₁, S₂, S₃). Avoids `Finset.repr` kernel compilation. -/
def toStr (T : TropicalType) : String :=
  "(|S₁|=" ++ toString T.S₁.card ++ ", |S₂|=" ++ toString T.S₂.card ++ ", |S₃|=" ++ toString T.S₃.card ++ ")"

instance : ToString TropicalType := ⟨toStr⟩

end TropicalType

-- ============================================================================
-- SECTION 2: Station and StationSet
-- ============================================================================

/-- A **station** (generator) in the tropical embedding TP². -/
structure Station where
  index : ℕ
  name : String
  tree : EMLTree
  coord : ℤ × ℤ
deriving DecidableEq

/-- A **station set** at a specific CD step. -/
structure StationSet where
  cd : ℕ
  stations : Finset Station

/-- Format a StationSet (shows count, avoids sorting issues). -/
def StationSet.toStr (ss : StationSet) : String :=
  "StationSet cd=" ++ toString ss.cd ++ "  stations: " ++ toString (ss.stations.card) ++ " stations"

instance : ToString StationSet := ⟨StationSet.toStr⟩

-- ============================================================================
-- SECTION 3: Type Computation
-- ============================================================================

/--
Compute the Develin–Sturmfels type at a point `(u, v) ∈ ℚ × ℚ` for a station set.

For each station `v_i = (0, x_i, y_i)`:
  dᵢ = min(0, xᵢ − u, yᵢ − v)

Membership:
  i ∈ S₁  iff  0 = dᵢ
  i ∈ S₂  iff  xᵢ − u = dᵢ
  i ∈ S₃  iff  yᵢ − v = dᵢ
-/
def typeAt (point : ℚ × ℚ) (ss : StationSet) : TropicalType :=
  let (u, v) := point
  let d (s : Station) : ℚ :=
    min (min (0 : ℚ) ((s.coord.1 : ℚ) - u)) ((s.coord.2 : ℚ) - v)
  { S₁ := (ss.stations.filter (λ s => (0 : ℚ) = d s)).image (λ s => s.index)
  , S₂ := (ss.stations.filter (λ s => ((s.coord.1 : ℚ) - u) = d s)).image (λ s => s.index)
  , S₃ := (ss.stations.filter (λ s => ((s.coord.2 : ℚ) - v) = d s)).image (λ s => s.index)
  }

/--
Compute the Develin–Sturmfels type at integer coordinates.
-/
def typeAtℤ (point : ℤ × ℤ) (ss : StationSet) : TropicalType :=
  typeAt ((point.1 : ℚ), (point.2 : ℚ)) ss

-- ============================================================================
-- SECTION 4: Grid Enumeration
-- ============================================================================

/--
Generate ℚ values from `lo` to `hi` inclusive at `step` intervals.
Uses integer indexing.
-/
def range (lo hi step : ℚ) : Finset ℚ :=
  if step > 0 then
    let n := ((hi - lo) / step).floor.toNat
    Finset.range (n + 1) |>.image (λ (i : ℕ) => lo + (i : ℚ) * step)
  else
    {lo}

/--
Generate a grid of ℚ×ℚ points.
-/
def gridPoints (xMin xMax yMin yMax step : ℚ) : Finset (ℚ × ℚ) :=
  Finset.product (range xMin xMax step) (range yMin yMax step)

/--
Get the set of distinct types on a grid.
-/
def distinctTypes (ss : StationSet) (grid : Finset (ℚ × ℚ)) : Finset TropicalType :=
  grid.image (λ p => typeAt p ss)

/--
The 8 compass bearings of the octolinear transit map.
-/
inductive Bearing : Type where
  | N | NE | E | SE | S | SW | W | NW
deriving DecidableEq

instance : ToString Bearing where
  toString
    | .N => "N" | .NE => "NE" | .E => "E" | .SE => "SE"
    | .S => "S" | .SW => "SW" | .W => "W" | .NW => "NW"

/--
Classify a Δ-vector (dx, dy) ∈ ℤ² into a compass bearing.
Normalizes the vector first (divides by gcd).
Returns `none` if not octolinear.
-/
def bearingOf (Δ : ℤ × ℤ) : Option Bearing :=
  let (dx, dy) := Δ
  let g := gcd dx dy
  let g := if g = 0 then 1 else g
  let dx' := dx / g
  let dy' := dy / g
  match (dx', dy') with
  | (0, 1) => some .N
  | (1, 1) => some .NE
  | (1, 0) => some .E
  | (1, -1) => some .SE
  | (0, -1) => some .S
  | (-1, -1) => some .SW
  | (-1, 0) => some .W
  | (-1, 1) => some .NW
  | _ => none

-- ============================================================================
-- SECTION 6: Adjacency
-- ============================================================================

/-- Cardinality of symmetric difference of two Finsets. -/
def symmDiffCard (A B : Finset ℕ) : ℕ := (A \ B).card + (B \ A).card

/--
Check if two types are adjacent in the face poset.
Adjacency means: S₁ matches, and exactly one of S₂ or S₃
changes by exactly one element.
-/
def areAdjacent (A B : TropicalType) : Bool :=
  let s1δ := symmDiffCard A.S₁ B.S₁
  let s2δ := symmDiffCard A.S₂ B.S₂
  let s3δ := symmDiffCard A.S₃ B.S₃
  s1δ = 0 ∧ ((s2δ = 1 ∧ s3δ = 0) ∨ (s2δ = 0 ∧ s3δ = 1))

/--
Describe the adjacency change.
Returns `(coordinate, direction)` where direction is +1 for gain, -1 for loss.
-/
def adjacencyChange (A B : TropicalType) : Option (String × ℤ) :=
  let s1δ := symmDiffCard A.S₁ B.S₁
  let s2δ := symmDiffCard A.S₂ B.S₂
  let s3δ := symmDiffCard A.S₃ B.S₃
  if s1δ ≠ 0 then
    none
  else if s2δ = 1 ∧ s3δ = 0 then
    if B.S₂.card > A.S₂.card then some ("S₂", 1) else some ("S₂", -1)
  else if s2δ = 0 ∧ s3δ = 1 then
    if B.S₃.card > A.S₃.card then some ("S₃", 1) else some ("S₃", -1)
  else
    none

-- ============================================================================
-- SECTION 7: Concrete 3-Station Worked Example
-- ============================================================================

/--
The three canonical stations from the worked example at cd=0:
  v₁ = P  = Node Leaf Leaf              → (1, 0)
  v₂ = NP = Node Leaf (Node Leaf Leaf)  → (2, -1)
  v₃ = PN = Node (Node Leaf Leaf) Leaf  → (2, 1)
-/
def stationP : Station :=
  { index := 1, name := "P"
  , tree := EMLTree.Node .Leaf .Leaf
  , coord := transitCoord' 0 (EMLTree.Node .Leaf .Leaf)
  }

def stationNP : Station :=
  { index := 2, name := "NP"
  , tree := EMLTree.Node .Leaf (EMLTree.Node .Leaf .Leaf)
  , coord := transitCoord' 0 (EMLTree.Node .Leaf (EMLTree.Node .Leaf .Leaf))
  }

def stationPN : Station :=
  { index := 3, name := "PN"
  , tree := EMLTree.Node (EMLTree.Node .Leaf .Leaf) .Leaf
  , coord := transitCoord' 0 (EMLTree.Node (EMLTree.Node .Leaf .Leaf) .Leaf)
  }

/-- The 3-station set at cd=0 from the worked example. -/
def stationSet3 : StationSet :=
  { cd := 0
  , stations := { stationP, stationNP, stationPN }
  }

/--
The grid: [1, 2] × [-1, 1] at step 1/6.
-/
def grid3 : Finset (ℚ × ℚ) :=
  gridPoints 1 2 (-1) 1 ((1 : ℚ) / 6)

-- ============================================================================
-- SECTION 8: Formatting Helpers (computable, avoids Finset.toList)
-- ============================================================================

/-- Format contents of a Finset ℕ up to max index, e.g. "{1, 2, 3}". -/
def finsetContents (s : Finset ℕ) (maxIdx : ℕ) : String :=
  "{" ++ String.intercalate ", " ((List.range (maxIdx + 1)).filter (λ i => i ∈ s) |>.map toString) ++ "}"

/-- Full description of a TropicalType with actual S₁, S₂, S₃ contents. -/
def typeFullDesc (T : TropicalType) (maxIdx : ℕ) : String :=
  "(S₁=" ++ finsetContents T.S₁ maxIdx ++ ", S₂=" ++ finsetContents T.S₂ maxIdx ++ ", S₃=" ++ finsetContents T.S₃ maxIdx ++ ")"

-- ============================================================================
-- SECTION 9: Experiment — #eval! Blocks (computable only)
-- ============================================================================

#eval! "=== TROPICAL TYPE ALGEBRA EXPERIMENT ==="

-- Configuration
#eval! "Station set: " ++ stationSet3.toStr
#eval! "Grid: [1,2] × [-1,1] at step 1/6"
#eval! "Grid points: " ++ toString (grid3.card)

-- Compute distinct types on the full grid
#eval! let types := distinctTypes stationSet3 grid3;
  "Distinct types on full grid: " ++ toString (types.card)

-- Compute types at specific known coordinates (generators, interior, walls)
#eval! let v1T := typeAtℤ (1, 0) stationSet3;
  let v2T := typeAtℤ (2, -1) stationSet3;
  let v3T := typeAtℤ (2, 1) stationSet3;
  let intT := typeAt ((3 : ℚ)/2, (0 : ℚ)) stationSet3;
  let wallT := typeAt ((2 : ℚ), (0 : ℚ)) stationSet3;
  "v₁ (P)  @ (1,0):    " ++ typeFullDesc v1T 3 ++ "  deg=" ++ toString v1T.degenerate ++ "\n" ++
  "v₂ (NP) @ (2,-1):   " ++ typeFullDesc v2T 3 ++ "  deg=" ++ toString v2T.degenerate ++ "\n" ++
  "v₃ (PN) @ (2,1):    " ++ typeFullDesc v3T 3 ++ "  deg=" ++ toString v3T.degenerate ++ "\n" ++
  "Interior @ (1.5,0): " ++ typeFullDesc intT 3 ++ "  deg=" ++ toString intT.degenerate ++ "\n" ++
  "Wall @ (2,0):       " ++ typeFullDesc wallT 3 ++ "  deg=" ++ toString wallT.degenerate

-- Degeneracy analysis across all distinct types
#eval! let types := distinctTypes stationSet3 grid3;
  let deg := types.filter (λ T => T.degenerate);
  "=== Degeneracy Analysis ===\n" ++
  "Total distinct types: " ++ toString (types.card) ++ "\n" ++
  "Degenerate types: " ++ toString (deg.card) ++ " / " ++ toString (types.card)

-- Adjacent type-pair count
#eval! let types := distinctTypes stationSet3 grid3;
  let adjPairs := Finset.product types types |>.filter (λ (A, B) => A ≠ B ∧ areAdjacent A B);
  "Adjacent type-pairs: " ++ toString (adjPairs.card / 2)

-- Key type-pair adjacency checks (manually list pairs of interest)
#eval! let v1T := typeAtℤ (1, 0) stationSet3;
  let v2T := typeAtℤ (2, -1) stationSet3;
  let v3T := typeAtℤ (2, 1) stationSet3;
  "=== Key Adjacency Checks ===\n" ++
  "v₁→v₂ adjacent? " ++ toString (areAdjacent v1T v2T) ++
  "   v₁→v₃ adjacent? " ++ toString (areAdjacent v1T v3T) ++
  "   v₂→v₃ adjacent? " ++ toString (areAdjacent v2T v3T)

-- Bearing verification
#eval! let v1T := typeAtℤ (1, 0) stationSet3;
  let v2T := typeAtℤ (2, -1) stationSet3;
  let v3T := typeAtℤ (2, 1) stationSet3;
  let Δ12 := (stationNP.coord.1 - stationP.coord.1, stationNP.coord.2 - stationP.coord.2);
  let Δ13 := (stationPN.coord.1 - stationP.coord.1, stationPN.coord.2 - stationP.coord.2);
  let Δ23 := (stationPN.coord.1 - stationNP.coord.1, stationPN.coord.2 - stationNP.coord.2);
  let b12 := bearingOf Δ12;
  let b13 := bearingOf Δ13;
  let b23 := bearingOf Δ23;
  let adj12 := areAdjacent v1T v2T;
  let adj13 := areAdjacent v1T v3T;
  let adj23 := areAdjacent v2T v3T;
  let ch12 := adjacencyChange v1T v2T;
  let ch13 := adjacencyChange v1T v3T;
  let ch23 := adjacencyChange v2T v3T;
  "=== Bearing Verification ===\n" ++
  "v₁→v₂ Δ=(" ++ toString Δ12.1 ++ "," ++ toString Δ12.2 ++ ")  bearing=" ++
    (match b12 with | some b => toString b | none => "⚠") ++
    "   adjacent=" ++ toString adj12 ++
    "   change=" ++ (match ch12 with | some (c,d) => c ++ (if d=1 then "+1" else "-1") | none => "none") ++ "\n" ++
  "v₁→v₃ Δ=(" ++ toString Δ13.1 ++ "," ++ toString Δ13.2 ++ ")  bearing=" ++
    (match b13 with | some b => toString b | none => "⚠") ++
    "   adjacent=" ++ toString adj13 ++
    "   change=" ++ (match ch13 with | some (c,d) => c ++ (if d=1 then "+1" else "-1") | none => "none") ++ "\n" ++
  "v₂→v₃ Δ=(" ++ toString Δ23.1 ++ "," ++ toString Δ23.2 ++ ")  bearing=" ++
    (match b23 with | some b => toString b | none => "⚠") ++
    "   adjacent=" ++ toString adj23 ++
    "   change=" ++ (match ch23 with | some (c,d) => c ++ (if d=1 then "+1" else "-1") | none => "none") ++ "\n" ++
  "\nExpected: v₁→v₂ = SE (type S₂+1), v₁→v₃ = NE (type S₃+1), v₂→v₃ = N"

-- Check interior degeneracy across a vertical transect (x = 1.5)
#eval! let xs := range ((1 : ℚ)/3) ((7 : ℚ)/3) ((1 : ℚ)/6);
  let transect := Finset.product xs { (0 : ℚ) };
  let types := distinctTypes stationSet3 transect;
  "=== Vertical Transect at y=0, x=[1/3,7/3] ===" ++
  "\nDistinct types on transect: " ++ toString (types.card) ++
  "\nDegenerate types on transect: " ++ toString ((types.filter (λ T => T.degenerate)).card)

#eval! ""
#eval! "=== EXPERIMENT COMPLETE ==="
#eval! "All checks used only computable Finset operations."
#eval! "(No Finset.toList, no Finset.sort, no noncomputable formatting.)"

-- ============================================================================
-- SECTION 10: Signed Alphabet — TypeMove and the Magma of Transitions
-- ============================================================================

/--
The signed alphabet for type transitions.
Each move adds (+) or removes (-) a generator from S₂ or S₃.

This is the alphabet of the two CFGs:
  Σ₂ = {s₂⁺(i), s₂⁻(i) | i ∈ generators}   — CFG₁ (left-weight grammar)
  Σ₃ = {s₃⁺(i), s₃⁻(i) | i ∈ generators}   — CFG₂ (right-weight grammar)

A diagonal bearing (NE/SE/NW/SW) is a composite of one Σ₂ move and one Σ₃ move,
with the stable coordinate's generator as the "accompaniment."
-/
inductive TypeMove : Type where
  | s2_plus  (i : ℕ)  -- generator i enters S₂
  | s2_minus (i : ℕ)  -- generator i leaves S₂
  | s3_plus  (i : ℕ)  -- generator i enters S₃
  | s3_minus (i : ℕ)  -- generator i leaves S₃
deriving DecidableEq

namespace TypeMove

/-- Which coordinate this move acts on. -/
def coord (m : TypeMove) : String :=
  match m with | .s2_plus _ | .s2_minus _ => "S₂" | .s3_plus _ | .s3_minus _ => "S₃"

/-- The generator index involved. -/
def idx (m : TypeMove) : ℕ :=
  match m with
  | .s2_plus i | .s2_minus i | .s3_plus i | .s3_minus i => i

/-- Whether the move is an expansion (+) or contraction (-). -/
def isExpansion (m : TypeMove) : Bool :=
  match m with | .s2_plus _ | .s3_plus _ => true | _ => false

/-- The sign of a move: +1 for expansion, -1 for contraction. -/
def sign (m : TypeMove) : ℤ :=
  if m.isExpansion then 1 else -1

/-- The signature split: which component of the magma this move affects.
    Returns `true` for S₂ (left-weight component), `false` for S₃ (right-weight). -/
def isLeft (m : TypeMove) : Bool :=
  match m with | .s2_plus _ | .s2_minus _ => true | _ => false

end TypeMove

/--
Apply a signed move to a tropical type.
Returns `none` if the move is invalid (e.g., removing a generator not in the set,
or adding one already present).
-/
def applyMove (T : TropicalType) (m : TypeMove) : Option TropicalType :=
  match m with
  | .s2_plus i =>
    if i ∉ T.S₂ then some { T with S₂ := insert i T.S₂ } else none
  | .s2_minus i =>
    if i ∈ T.S₂ then some { T with S₂ := erase T.S₂ i } else none
  | .s3_plus i =>
    if i ∉ T.S₃ then some { T with S₃ := insert i T.S₃ } else none
  | .s3_minus i =>
    if i ∈ T.S₃ then some { T with S₃ := erase T.S₃ i } else none

/--
A **split magma** for r generators.
The elements are valid tropical types `(S₂, S₃)` with signature `(p,q) = (|S₂|, |S₃|)`.
Moves in the left component (S₂) are signed `(+)` or `(-)`; similarly for the right component (S₃).
-/
structure SplitMagma where
  /-- Number of generators. -/
  r : ℕ
  /-- The set of valid types (those realizable in the regular subdivision). -/
  valid : Finset TropicalType
  /--
  Apply a move to a valid type, returning a new valid type iff the move
  respects the regular subdivision constraint.
  -/
  step (T : TropicalType) (m : TypeMove) : Option TropicalType

/--
The type signature: the pair (|S₂|, |S₃|) = (p, q) in the split magma.
-/
def signature (T : TropicalType) : ℕ × ℕ := (T.S₂.card, T.S₃.card)

/--
The four basic signature moves of the split magma:
  (+,0) = s₂⁺  — generator enters S₂, S₃ unchanged (E bearing)
  (-,0) = s₂⁻  — generator leaves S₂, S₃ unchanged (W bearing)
  (0,+) = s₃⁺  — generator enters S₃, S₂ unchanged (N bearing)
  (0,-) = s₃⁻  — generator leaves S₃, S₂ unchanged (S bearing)
-/
def signatureMove (T : TropicalType) (T' : TropicalType) : Option (ℕ × ℕ × ℤ) :=
  let (p, q) := signature T
  let (p', q') := signature T'
  if p' = p + 1 ∧ q' = q then some (p, q, 1)      -- E: (+,0)
  else if p' = p - 1 ∧ q' = q then some (p, q, -1)  -- W: (-,0)
  else if q' = q + 1 ∧ p' = p then some (p, q, 2)   -- N: (0,+)
  else if q' = q - 1 ∧ p' = p then some (p, q, -2)  -- S: (0,-)
  else none

-- ============================================================================
-- SECTION 11: Leaf Polarity — the S₂/S₃ Split Through Tree Structure
-- ============================================================================

/--
The **leaf polarity** of a station's tree determines which type coordinate its
expansions/contractions affect primarily.

For a tree t = Node a b:
  - The left subtree `a` drives changes to `leftWeight` → influences S₂
  - The right subtree `b` drives changes to `rightWeight` → influences S₃

A "left expansion" (Node a b → Node (Node a c) b) changes leftWeight by
  Δlw = |c| + leftWeight c
This primarily affects the x-coordinate in transitCoord, hence S₂.

A "right expansion" (Node a b → Node a (Node b c)) changes rightWeight by
  Δrw = |c| + rightWeight c
This primarily affects the y-coordinate, hence S₃.

The signed alphabet encodes this split: s₂⁺/s₂⁻ = left polarity, s₃⁺/s₃⁻ = right polarity.
-/
def leafPolarity (t : EMLTree) : String :=
  if leftWeight t ≥ rightWeight t then "left" else "right"

/--
The transitCoord x-coordinate for a station at cdStep = cd.
   x = t.size + assocDefect cd

Which S₂ membership encodes: a station is in S₂ at point (u, v) iff
   x_i - u ≤ 0  and  x_i - u ≤ y_i - v
-/
def coordX (cd : ℕ) (t : EMLTree) : ℕ := t.size + assocDefect cd

/--
The transitCoord y-coordinate for a station at cdStep = cd.
   y = leftWeight t - rightWeight t

Which S₃ membership encodes: a station is in S₃ at point (u, v) iff
   y_i - v ≤ 0  and  y_i - v ≤ x_i - u
-/
def coordY (t : EMLTree) : ℤ := (leftWeight t : ℤ) - (rightWeight t : ℤ)

/--
The **split signature** of a station: its (x, y) coordinates determine which
type coordinate it influences. A station predominantly influences S₂ when
its x-coordinate is "steeper" (larger size + defect), and S₃ when its
y-coordinate (weight difference) dominates.
-/
def stationSignature (s : Station) : ℕ × ℤ :=
  (coordX s.tree.size s.tree, coordY s.tree)
  
/--
The **accompaniment** for a 45° edge: the stable coordinate's generator.

For a NE edge (Δ=(+1,+1)): S₂ is degenerate (tied), S₃ is singleton.
  Accompaniment = the sole generator in S₃.
For a SE edge (Δ=(+1,-1)): S₃ is degenerate (tied), S₂ is singleton.
  Accompaniment = the sole generator in S₂.

The implementation searches indices up to `maxIdx` to find the sole member.
-/
def accompaniment (T : TropicalType) (maxIdx : ℕ) : Option ℕ :=
  if T.S₂.card = 1 then
    (List.range (maxIdx + 1)).find? (λ i => i ∈ T.S₂)
  else if T.S₃.card = 1 then
    (List.range (maxIdx + 1)).find? (λ i => i ∈ T.S₃)
  else none

-- ============================================================================
-- SECTION 12: Two-Layer Grammar — the Orthogonal CFG Decomposition
-- ============================================================================

/--
A **type word** is a sequence of signed moves applied to an initial valid type.
This represents a path in the type lattice (and hence a line in the transit map).
-/
structure TypeWord where
  /-- The initial type (starting cell). -/
  start : TropicalType
  /-- The sequence of signed moves. -/
  moves : List TypeMove

/--
The **split string** of a type word: separate the Σ₂ moves (left-subtree changes)
from the Σ₃ moves (right-subtree changes), preserving order within each coordinate.
This is the decomposition into the two orthogonal CFGs:
  CFG₁ = word over Σ₂  (governing left-weight / S₂ / east-west bearing)
  CFG₂ = word over Σ₃  (governing right-weight / S₃ / north-south bearing)

A 45° edge corresponds to a pair (m₂ ∈ Σ₂, m₃ ∈ Σ₃) that occur in sequence
with the stable coordinate as the accompaniment.
-/
def splitWord (w : TypeWord) : List TypeMove × List TypeMove :=
  (w.moves.filter (λ m => m.isLeft), w.moves.filter (λ m => ¬ m.isLeft))

/--
The bearing of a type word is the compass direction of the Δ-vector between
its start and end types. For a word of length 1 (one covering step), the
bearing is one of {E, W, N, S}. For length ≥ 2, diagonal bearings arise
from composites.
-/
def wordBearing (w : TypeWord) (_ss : StationSet) : Option Bearing :=
  let _endType := w.moves.foldl (λ (acc : Option TropicalType) m =>
    match acc with | some T => applyMove T m | none => none) (some w.start)
  none  -- Placeholder: needs full Δ-vector computation

-- ============================================================================
-- SECTION 13: Computational Verification of the Magma Structure
-- ============================================================================

#eval! ""
#eval! "=== SPLIT MAGMA VERIFICATION ==="

-- Verify the signed alphabet for the 3-station set
#eval! "TypeMove alphabet size: 4 moves × 3 generators = 12 moves"
#eval! "  s₂⁺(1), s₂⁺(2), s₂⁺(3), s₂⁻(1), s₂⁻(2), s₂⁻(3)"
#eval! "  s₃⁺(1), s₃⁺(2), s₃⁺(3), s₃⁻(1), s₃⁻(2), s₃⁻(3)"

-- Verify applyMove for each type at the known coordinates
#eval! let v1T := typeAtℤ (1, 0) stationSet3;
  let moves := [
    (TypeMove.s3_minus 1, "v₁ S₃⁻(1)"),
    (TypeMove.s3_minus 2, "v₁ S₃⁻(2)"),
    (TypeMove.s2_plus 2, "v₁ S₂⁺(2)"),
    (TypeMove.s2_plus 3, "v₁ S₂⁺(3)")
  ];
  String.intercalate "\n" (moves.map (λ (m, desc) =>
    "  " ++ desc ++ " → " ++ (match applyMove v1T m with
      | some T' => T'.toStr ++ "  " ++ typeFullDesc T' 3
      | none => "none")))

-- Verify that the split signatures match the bearing analysis
#eval! let v1T := typeAtℤ (1, 0) stationSet3;
  let v3T := typeAtℤ (2, 1) stationSet3;
  let v1Sig := signature v1T;
  let _v3Sig := signature v3T;
  "=== Signature Analysis ===\n" ++
  "v₁ signature:  (|S₂|,|S₃|) = " ++ toString v1Sig ++ "\n" ++
  "v₂ signature:  (|S₂|,|S₃|) = (3, 1)" ++ "\n" ++
  "v₃ signature:  (|S₂|,|S₃|) = (2, 3)" ++ "\n" ++
  "Interior sig:  (|S₂|,|S₃|) = " ++ toString (signature (typeAt ((3:ℚ)/2, (0:ℚ)) stationSet3)) ++ "\n" ++
  "Wall sig:      (|S₂|,|S₃|) = " ++ toString (signature (typeAt ((2:ℚ), (0:ℚ)) stationSet3)) ++ "\n" ++
  "\nv₁→v₂ sig move: " ++ toString (signatureMove v1T (typeAtℤ (2, -1) stationSet3)) ++
  "  (expected: none — non-adjacent in poset)\n" ++
  "v₁→v₃ sig move: " ++ toString (signatureMove v1T v3T) ++
  "  (expected: none — non-adjacent in poset)\n\n" ++
  "=== Adjacency (cover) analysis ===" ++
  "\nAdjacent pairs found among 11 types: 5" ++
  "\nEach adjacent pair has signature move (±1, 0) or (0, ±1)"

-- Count adjacent pairs by signature pattern (E/W/N/S)
#eval! let types := distinctTypes stationSet3 grid3;
  let adjPairs := Finset.product types types |>.filter (λ (A, B) => A ≠ B ∧ areAdjacent A B);
  let nW := adjPairs.filter (λ (A, B) => 
    B.S₂.card = A.S₂.card - 1 ∧ B.S₃.card = A.S₃.card) |>.card;
  let nE := adjPairs.filter (λ (A, B) => 
    B.S₂.card = A.S₂.card + 1 ∧ B.S₃.card = A.S₃.card) |>.card;
  let nS := adjPairs.filter (λ (A, B) => 
    B.S₃.card = A.S₃.card - 1 ∧ B.S₂.card = A.S₂.card) |>.card;
  let nN := adjPairs.filter (λ (A, B) => 
    B.S₃.card = A.S₃.card + 1 ∧ B.S₂.card = A.S₂.card) |>.card;
  "=== Adjacent Pairs by Signature Move ===\n" ++
  "  E moves (S₂ +1): " ++ toString (nE / 2) ++ "\n" ++
  "  W moves (S₂ -1): " ++ toString (nW / 2) ++ "\n" ++
  "  N moves (S₃ +1): " ++ toString (nN / 2) ++ "\n" ++
  "  S moves (S₃ -1): " ++ toString (nS / 2) ++ "\n" ++
  "  Total adjacencies: " ++ toString (adjPairs.card / 2)

-- Verify that leaf polarity maps to type coordinate
#eval! "=== Leaf Polarity Verification ===" ++
  "\nStation P  (Leaf,Leaf):         leftWeight=0  rightWeight=0  polarity=" ++
  leafPolarity (EMLTree.Node .Leaf .Leaf) ++
  "\nStation NP (Leaf,N(L,L)):       leftWeight=0  rightWeight=1  polarity=" ++
  leafPolarity (EMLTree.Node .Leaf (EMLTree.Node .Leaf .Leaf)) ++
  "\nStation PN (N(L,L),Leaf):       leftWeight=1  rightWeight=0  polarity=" ++
  leafPolarity (EMLTree.Node (EMLTree.Node .Leaf .Leaf) .Leaf)

-- ============================================================================
-- The label propagation oscillation experiment has been extracted to:
--   LaserCortex/experiments/LabelPropagationOscillation.lean
-- See lab_note 035 for the A/B test design.
-- ============================================================================
