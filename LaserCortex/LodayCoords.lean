import LaserCortex.EMLRegistry

open EMLRegistry

namespace LodayCoords

/-- Number of leaves in an EMLTree. -/
def numLeaves : EMLTree → Nat
  | .Leaf => 1
  | .Node l r => numLeaves l + numLeaves r

/-- Number of nodes (Leaves + internal Nodes) in an EMLTree. -/
def numNodes : EMLTree → Nat
  | .Leaf => 1
  | .Node l r => 1 + numNodes l + numNodes r

/-- numLeaves is positive for all trees. -/
theorem numLeaves_pos (t : EMLTree) : 0 < numLeaves t := by
  induction t with
  | Leaf => simp [numLeaves]
  | Node l r ih_l ih_r => simp [numLeaves]; omega

/-- numNodes is positive for all trees. -/
theorem numNodes_pos (t : EMLTree) : 0 < numNodes t := by
  induction t with
  | Leaf => simp [numNodes]
  | Node l r ih_l ih_r => simp [numNodes]; omega

/-- Loday coordinate of a binary tree.
    For a binary tree t with n leaves, produces a list of length n-1 of positive integers.
    Each internal node contributes the number of leaves in its left subtree.
    The coordinates are listed in prefix order (root first, then left child's
    subtree, then right child's subtree recursively). -/
def lodayCoord : EMLTree → List Nat
  | .Leaf => []
  | .Node l r => [numLeaves l] ++ lodayCoord l ++ lodayCoord r

/-- The length of the Loday coordinate list equals numLeaves - 1. -/
theorem lodayCoord_length (t : EMLTree) : (lodayCoord t).length = numLeaves t - 1 := by
  induction t with
  | Leaf => simp [lodayCoord, numLeaves]
  | Node l r ih_l ih_r =>
    simp [lodayCoord, numLeaves, List.length_append, ih_l, ih_r]
    have pos_l : 0 < numLeaves l := numLeaves_pos l
    have pos_r : 0 < numLeaves r := numLeaves_pos r
    omega

private theorem append_inj' {α : Type} {as₁ bs₁ as₂ bs₂ : List α}
    (h : as₁ ++ bs₁ = as₂ ++ bs₂) (hlen : as₁.length = as₂.length) : as₁ = as₂ ∧ bs₁ = bs₂ := by
  induction as₁ generalizing as₂ bs₁ bs₂ with
  | nil =>
    cases as₂ with
    | nil => simp at h; exact ⟨rfl, h⟩
    | cons a as₂ => simp at hlen
  | cons a as₁ ih =>
    cases as₂ with
    | nil => simp at hlen
    | cons a' as₂ =>
      have ha_eq : a = a' := by
        simpa using congrArg (·.head?) h
      have hrest : as₁ ++ bs₁ = as₂ ++ bs₂ := by
        simpa using congrArg List.tail h
      have hlen' : as₁.length = as₂.length := by simpa using hlen
      rcases ih hrest hlen' with ⟨has, hbs⟩
      subst ha_eq; subst has
      exact ⟨rfl, hbs⟩

/-- The Loday coordinate map is injective: distinct trees produce distinct coordinate lists. -/
theorem lodayCoord_injective {t₁ t₂ : EMLTree} (h : lodayCoord t₁ = lodayCoord t₂) : t₁ = t₂ := by
  induction t₁ generalizing t₂ with
  | Leaf =>
    have hnil : lodayCoord t₂ = [] := by simpa [lodayCoord] using h
    cases t₂ with
    | Leaf => rfl
    | Node l r => simp [lodayCoord] at hnil
  | Node l₁ r₁ ih_l ih_r =>
    cases t₂ with
    | Leaf => simp [lodayCoord] at h
    | Node l₂ r₂ =>
      simp [lodayCoord] at h
      rcases h with ⟨hfirst, hrest⟩
      have hlen : (lodayCoord l₁).length = (lodayCoord l₂).length := by
        calc
          (lodayCoord l₁).length = numLeaves l₁ - 1 := lodayCoord_length l₁
          _ = numLeaves l₂ - 1 := by simpa [hfirst]
          _ = (lodayCoord l₂).length := by symm; exact lodayCoord_length l₂
      rcases append_inj' hrest hlen with ⟨hl, hr⟩
      have hl_eq : l₁ = l₂ := ih_l hl
      have hr_eq : r₁ = r₂ := ih_r hr
      simp [hl_eq, hr_eq]

end LodayCoords
