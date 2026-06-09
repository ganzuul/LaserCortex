import LaserCortex.EMLRegistry

open EMLRegistry

namespace Decomposition

/-- A witness path through the Tamari lattice: a sequence of contraction steps
  from source to target. -/
inductive Path : EMLTree → EMLTree → Type where
  | nil  {t : EMLTree} : Path t t
  | cons {a b c : EMLTree} : contracts_one a b → Path b c → Path a c

theorem Path.to_contracts_to {s t : EMLTree} (p : Path s t) : contracts_to s t := by
  induction p with
  | nil => exact contracts_to.refl _
  | cons h_one h_path ih => exact contracts_to.step _ _ _ h_one ih

def Path.length {s t : EMLTree} (p : Path s t) : Nat :=
  match p with
  | .nil => 0
  | .cons _ p' => 1 + p'.length

def Path.append {s t u : EMLTree} (p₁ : Path s t) (p₂ : Path t u) : Path s u :=
  match p₁ with
  | .nil => p₂
  | .cons h_one h_path => .cons h_one (h_path.append p₂)

/-- Generate all immediate predecessors of a tree under `contracts_one`.
  Soundness: each predecessor `s` satisfies `contracts_one s t`.
  Completeness: every `s` with `contracts_one s t` is in this list.
  This is the core de-composition primitive: given an outcome, what could
  have immediately preceded it? -/
def reverse_one : EMLTree → List EMLTree
  | .Leaf => []
  | .Node l (.Node r1 r2) =>
    EMLTree.Node (EMLTree.Node l r1) r2 ::
    (reverse_one l).map (λ l' => EMLTree.Node l' (EMLTree.Node r1 r2)) ++
    (reverse_one (EMLTree.Node r1 r2)).map (λ r' => EMLTree.Node l r')
  | .Node l r =>
    (reverse_one l).map (λ l' => EMLTree.Node l' r) ++
    (reverse_one r).map (λ r' => EMLTree.Node l r')

theorem reverse_one_sound (t : EMLTree) (s : EMLTree) (h : s ∈ reverse_one t) : contracts_one s t := by
  induction t generalizing s with
  | Leaf =>
    simp [reverse_one] at h
  | Node l r ih_l ih_r =>
    match r with
    | .Leaf =>
      have h_list : reverse_one (EMLTree.Node l .Leaf) = (reverse_one l).map (λ l' => EMLTree.Node l' .Leaf) := by
        simp [reverse_one]
      rw [h_list] at h
      rcases List.mem_map.mp h with ⟨l', hl', hs⟩
      subst hs
      exact contracts_one.left _ _ _ (ih_l _ hl')
    | .Node r1 r2 =>
      have h_list : reverse_one (EMLTree.Node l (EMLTree.Node r1 r2)) =
        EMLTree.Node (EMLTree.Node l r1) r2 :: ((reverse_one l).map (λ l' => EMLTree.Node l' (EMLTree.Node r1 r2)) ++ (reverse_one (EMLTree.Node r1 r2)).map (λ r' => EMLTree.Node l r')) := rfl
      rw [h_list] at h
      rcases List.mem_cons.mp h with (h_eq | h_rest)
      · subst h_eq
        exact contracts_one.rotate l r1 r2
      · rcases List.mem_append.mp h_rest with (h_l | h_r)
        · rcases List.mem_map.mp h_l with ⟨l', hl', hs⟩
          subst hs
          exact contracts_one.left _ _ _ (ih_l _ hl')
        · rcases List.mem_map.mp h_r with ⟨r', hr', hs⟩
          subst hs
          have h1 : contracts_one r' (EMLTree.Node r1 r2) := ih_r r' hr'
          exact contracts_one.right l r' (EMLTree.Node r1 r2) h1

theorem reverse_one_complete (s t : EMLTree) (h : contracts_one s t) : s ∈ reverse_one t := by
  induction h with
  | rotate a b c =>
    simp [reverse_one]
  | left l l' r h_cont ih =>
    match r with
    | .Leaf =>
      have h_mem : EMLTree.Node l .Leaf ∈ (reverse_one l').map (λ l'' => EMLTree.Node l'' .Leaf) :=
        List.mem_map.mpr ⟨l, ih, rfl⟩
      simpa [reverse_one] using h_mem
    | .Node r1 r2 =>
      have h_mem_map : EMLTree.Node l (EMLTree.Node r1 r2) ∈ (reverse_one l').map (λ l'' => EMLTree.Node l'' (EMLTree.Node r1 r2)) :=
        List.mem_map.mpr ⟨l, ih, rfl⟩
      have h_mem_append : EMLTree.Node l (EMLTree.Node r1 r2) ∈ ((reverse_one l').map (λ l'' => EMLTree.Node l'' (EMLTree.Node r1 r2)) ++ (reverse_one (EMLTree.Node r1 r2)).map (λ r'' => EMLTree.Node l' r'')) :=
        List.mem_append.mpr (Or.inl h_mem_map)
      have h_mem_full : EMLTree.Node l (EMLTree.Node r1 r2) ∈ (EMLTree.Node (EMLTree.Node l' r1) r2 :: ((reverse_one l').map (λ l'' => EMLTree.Node l'' (EMLTree.Node r1 r2)) ++ (reverse_one (EMLTree.Node r1 r2)).map (λ r'' => EMLTree.Node l' r''))) :=
        List.mem_cons.mpr (Or.inr h_mem_append)
      simpa [reverse_one] using h_mem_full
  | right l r r' h_cont ih =>
    match r' with
    | .Leaf =>
      cases h_cont
    | .Node r1 r2 =>
      have h_mem_map : EMLTree.Node l r ∈ (reverse_one (EMLTree.Node r1 r2)).map (λ r'' => EMLTree.Node l r'') :=
        List.mem_map.mpr ⟨r, ih, rfl⟩
      have h_mem_append : EMLTree.Node l r ∈ ((reverse_one l).map (λ l'' => EMLTree.Node l'' (EMLTree.Node r1 r2)) ++ (reverse_one (EMLTree.Node r1 r2)).map (λ r'' => EMLTree.Node l r'')) :=
        List.mem_append.mpr (Or.inr h_mem_map)
      have h_mem_full : EMLTree.Node l r ∈ (EMLTree.Node (EMLTree.Node l r1) r2 :: ((reverse_one l).map (λ l'' => EMLTree.Node l'' (EMLTree.Node r1 r2)) ++ (reverse_one (EMLTree.Node r1 r2)).map (λ r'' => EMLTree.Node l r''))) :=
        List.mem_cons.mpr (Or.inr h_mem_append)
      simpa [reverse_one] using h_mem_full

/-- A Decomposition of a target tree: a source tree and a proof that the source
  contracts to the target. This is the **ontological unit** of de-composition:
  an outcome (target) together with a specific prior configuration (source)
  that could have produced it. -/
structure Decomposition (target : EMLTree) where
  source : EMLTree
  proof  : contracts_to source target

theorem leftComb_size (n : Nat) : (leftComb n).size = n := by
  induction n with
  | zero => simp [leftComb, EMLTree.size]
  | succ n ih => simp [leftComb, EMLTree.size, ih, Nat.add_comm]

theorem rightComb_size (n : Nat) : (rightComb n).size = n := by
  induction n with
  | zero => simp [rightComb, EMLTree.size]
  | succ n ih => simp [rightComb, EMLTree.size, ih, Nat.add_comm]

theorem rightComb_ne_leftComb (n : Nat) (hn : n ≥ 2) : rightComb n ≠ leftComb n := by
  induction n with
  | zero => exact absurd hn (Nat.not_succ_le_zero 1)
  | succ n ih =>
    cases n with
    | zero =>
      have h1le0 : 1 ≤ 0 := Nat.le_of_succ_le_succ hn
      exact absurd h1le0 (Nat.not_succ_le_zero 0)
    | succ n =>
      intro h_eq
      have h_right : rightComb (n.succ) = .Leaf := by
        have h_right' := congrArg (λ t : EMLTree => match t with | .Node _ r => r | _ => .Leaf) h_eq
        simpa [rightComb, leftComb] using h_right'
      have h_sz : (rightComb (n.succ)).size = n.succ := rightComb_size (n.succ)
      have h_sz0 : (rightComb (n.succ)).size = 0 := by
        simp [h_right, EMLTree.size]
      rw [h_sz] at h_sz0
      exact Nat.succ_ne_zero n h_sz0

/-- For the equilibrium target `rightComb n` with n ≥ 2, there exist at least
  two distinct source trees that contract to it. This is the core ontological
  result: the past is underdetermined by the present — the same outcome admits
  multiple evidential histories. -/
theorem non_unique_decomposition (n : Nat) (hn : n ≥ 2) :
    ∃ (d₁ d₂ : Decomposition (rightComb n)), d₁.source ≠ d₂.source := by
  let d1 : Decomposition (rightComb n) := {
    source := rightComb n
    proof := contracts_to.refl _
  }
  let d2 : Decomposition (rightComb n) := {
    source := leftComb n
    proof := by
      have h_size : (leftComb n).size = n := leftComb_size n
      simpa [h_size] using contracts_to_rightComb (leftComb n)
  }
  have h_ne : rightComb n ≠ leftComb n := rightComb_ne_leftComb n hn
  exact ⟨d1, d2, h_ne⟩

/-- There exist two distinct paths between the same source-target pair.
  This proves that multiple reasoning chains can connect the same evidence
  to the same verdict — intent is not uniquely determined by outcome. -/
theorem path_diversity : ∃ (s t : EMLTree) (p₁ p₂ : Path s t), p₁ ≠ p₂ := by
  -- Use the T₃ example: leftComb 3 → rightComb 3 has two distinct paths
  let a : EMLTree := .Leaf
  let b : EMLTree := .Leaf
  let c : EMLTree := .Leaf
  let d : EMLTree := .Leaf
  -- t1 = ((ab)c)d = leftComb 3
  let t1 : EMLTree := EMLTree.Node (EMLTree.Node (EMLTree.Node a b) c) d
  -- t2 = (a(bc))d
  let t2 : EMLTree := EMLTree.Node (EMLTree.Node a (EMLTree.Node b c)) d
  -- t3 = (ab)(cd)
  let t3 : EMLTree := EMLTree.Node (EMLTree.Node a b) (EMLTree.Node c d)
  -- t4 = a((bc)d)
  let t4 : EMLTree := EMLTree.Node a (EMLTree.Node (EMLTree.Node b c) d)
  -- t5 = a(b(cd)) = rightComb 3
  let t5 : EMLTree := EMLTree.Node a (EMLTree.Node b (EMLTree.Node c d))
  -- Path 1: t1 → t2 → t4 → t5
  have step1_2 : contracts_one t1 t2 :=
    contracts_one.left (EMLTree.Node (EMLTree.Node a b) c) (EMLTree.Node a (EMLTree.Node b c)) d
      (contracts_one.rotate a b c)
  have step2_4 : contracts_one t2 t4 :=
    contracts_one.rotate a (EMLTree.Node b c) d
  have step4_5 : contracts_one t4 t5 :=
    contracts_one.right a (EMLTree.Node (EMLTree.Node b c) d) (EMLTree.Node b (EMLTree.Node c d))
      (contracts_one.rotate b c d)
  let path1 : Path t1 t5 :=
    .cons step1_2 (.cons step2_4 (.cons step4_5 .nil))
  -- Path 2: t1 → t3 → t5
  have step1_3 : contracts_one t1 t3 :=
    contracts_one.rotate (EMLTree.Node a b) c d
  have step3_5 : contracts_one t3 t5 :=
    contracts_one.rotate a b (EMLTree.Node c d)
  let path2 : Path t1 t5 :=
    .cons step1_3 (.cons step3_5 .nil)
  have h_len_ne : path1.length ≠ path2.length := by
    simp [path1, path2, Path.length]
  have h_ne : path1 ≠ path2 := by
    intro h
    have : path1.length = path2.length := by rw [h]
    exact h_len_ne this
  exact ⟨t1, t5, path1, path2, h_ne⟩

/-- The immediate predecessor sources of a target tree, as a plain list.

  This is the local, one-step lookup. Soundness is maintained as a separate
  theorem: `predecessors_sound`. -/
def predecessors (t : EMLTree) : List EMLTree :=
  reverse_one t

theorem predecessors_sound (t s : EMLTree) (h : s ∈ predecessors t) : contracts_one s t :=
  reverse_one_sound t s h

/-- A finite chain of contraction steps from an ancestor to a target.
  Unlike the length-indexed `View`, `Chain` terminates at any depth.

  `Chain.tip` is the empty chain at any node (the present moment without
  a reconstructed past). `Chain.link` prepends a contraction step. -/
inductive Chain : EMLTree → Type where
  | tip (t : EMLTree) : Chain t
  | link {s t : EMLTree} (h : contracts_one s t) (rest : Chain s) : Chain t
  deriving Nonempty

/-- Enumerate all ancestors up to depth `n` via DFS, returning a list of
  source trees at each depth.

  This is the **hypercomputer in function form**: the infinite tree of all
  possible pasts is present as the *limit* of `ancestorsUpTo t n` as `n → ∞`.
  No single data structure holds the whole tree; instead the recursion is
  explicit in the function, and every finite approximation is immediately
  available. "Instant lookup" = calling this function with any depth. -/
partial def ancestorsUpTo (t : EMLTree) : Nat → List EMLTree
  | 0 => []
  | n + 1 =>
    let cur := predecessors t
    let rec go : List EMLTree → List EMLTree
      | [] => []
      | (s :: ss) => ancestorsUpTo s n ++ go ss
    cur ++ go cur

/-- Extract a **DFS view** (single lineage, committed, narrative) by always
  following the first predecessor at each step.

  Returns a finite chain (may end at any depth). -/
partial def viewDFS (t : EMLTree) : Chain t :=
  match h : reverse_one t with
  | [] => Chain.tip t
  | (s :: _) =>
    have hmem : s ∈ reverse_one t := by
      rw [h]
      simp
    have h_sound : contracts_one s t := reverse_one_sound t s hmem
    Chain.link h_sound (viewDFS s)

end Decomposition
