import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes

namespace Cost

/-- Node cost parameters for a logic type.
    Interprets the EML operator eml(x,y) = exp(x) - ln(y) in discrete ℕ arithmetic:
    leftWeight amplifies the left subtree cost (exp-like),
    rightDiv compresses the right subtree cost (ln-like),
    bias adds the distinguished constant 1 from the EML grammar. -/
structure NodeCost where
  leftWeight : Nat
  rightDiv : Nat
  bias : Nat

/-- Apply node cost parameters to combine left and right subtree costs. -/
def NodeCost.apply (c : NodeCost) (a b : Nat) : Nat :=
  c.bias + c.leftWeight * a + (b / c.rightDiv.succ)

/-- Node cost parameters for each logic type.
    Each logic type defines its own friction regime for combining subtrees,
    reflecting how cross-impact propagates through the lattice under that logic.
    The left-right asymmetry mirrors eml(x,y) = exp(x) - ln(y):
    leftWeight > 1 amplifies the left subtree (exp-like blowup),
    rightDiv > 1 compresses the right subtree (ln-like saturation). -/
def nodeParam (L : LogicTypes.LogicType) : NodeCost :=
  match L with
  | .Classical      => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Fuzzy          => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .ManyValued     => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Paraconsistent => { leftWeight := 2, rightDiv := 1, bias := 1 }
  | .Temporal       => { leftWeight := 2, rightDiv := 1, bias := 1 }
  | .Deontic        => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .Epistemic      => { leftWeight := 1, rightDiv := 2, bias := 1 }
  | .Quantum        => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Intuitionistic => { leftWeight := 1, rightDiv := 0, bias := 1 }
  | .Relevance      => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Free           => { leftWeight := 1, rightDiv := 0, bias := 1 }
  | .Infinitary     => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Modal          => { leftWeight := 1, rightDiv := 1, bias := 1 }
  | .Spacetime      => { leftWeight := 2, rightDiv := 1, bias := 1 }

theorem nodeParam_bias_one (L : LogicTypes.LogicType) : (nodeParam L).bias = 1 := by
  cases L <;> rfl

theorem nodeParam_leftWeight_ge_one (L : LogicTypes.LogicType) : 1 ≤ (nodeParam L).leftWeight := by
  cases L <;> decide

/-- Cross-impact cost of an EML tree under a given logic type. -/
def Φ (L : LogicTypes.LogicType) : EMLRegistry.EMLTree → Nat
  | .Leaf => 0
  | .Node l r => (nodeParam L).apply (Φ L l) (Φ L r)

theorem Φ_Leaf (L : LogicTypes.LogicType) : Φ L .Leaf = 0 := rfl

theorem Φ_Node (L : LogicTypes.LogicType) (l r : EMLRegistry.EMLTree) :
    Φ L (.Node l r) = (nodeParam L).apply (Φ L l) (Φ L r) := rfl

/-- Recurrence for right-comb cost. -/
theorem Φ_rightComb_succ (L : LogicTypes.LogicType) (n : Nat) :
    Φ L (EMLRegistry.rightComb (n + 1)) = (nodeParam L).bias + Φ L (EMLRegistry.rightComb n) / (nodeParam L).rightDiv.succ := by
  simp [Φ, EMLRegistry.rightComb, nodeParam, NodeCost.apply]

/-- For logics with rightDiv = 0 (denominator 1), cost of rightComb n is n. -/
theorem Φ_rightComb_classical (L : LogicTypes.LogicType) (n : Nat) (hD : (nodeParam L).rightDiv = 0) :
    Φ L (EMLRegistry.rightComb n) = n := by
  induction n with
  | zero => simp [Φ, EMLRegistry.rightComb]
  | succ n ih =>
    rw [Φ_rightComb_succ L n]
    have hbias : (nodeParam L).bias = 1 := nodeParam_bias_one L
    have hden : (nodeParam L).rightDiv.succ = 1 := by omega
    rw [hbias, hden, ih]
    omega

/-- Right-comb cost is bounded by n. -/
theorem Φ_rightComb_le_n (L : LogicTypes.LogicType) (n : Nat) : Φ L (EMLRegistry.rightComb n) ≤ n := by
  induction n with
  | zero => simp [Φ, EMLRegistry.rightComb]
  | succ n ih =>
    rw [Φ_rightComb_succ L n]
    rw [nodeParam_bias_one L]
    have hdiv : Φ L (EMLRegistry.rightComb n) / (nodeParam L).rightDiv.succ ≤ Φ L (EMLRegistry.rightComb n) :=
      Nat.div_le_self _ _
    omega

/-- Right-comb cost is positive for positive n. -/
theorem Φ_rightComb_pos (L : LogicTypes.LogicType) (n : Nat) (hn : 0 < n) : 0 < Φ L (EMLRegistry.rightComb n) := by
  induction n with
  | zero => exact absurd hn (Nat.lt_irrefl _)
  | succ n ih =>
    rw [Φ_rightComb_succ L n]
    rw [nodeParam_bias_one L]
    simpa [Nat.add_comm] using Nat.succ_pos (Φ L (EMLRegistry.rightComb n) / (nodeParam L).rightDiv.succ)

/-- For logics with rightDiv = 0, Φ equals tree size. -/
theorem Φ_eq_size_classical (L : LogicTypes.LogicType) (t : EMLRegistry.EMLTree) (hD : (nodeParam L).rightDiv = 0) :
    Φ L t = t.size := by
  induction t with
  | Leaf => simp [Φ, EMLRegistry.EMLTree.size]
  | Node l r ih_l ih_r =>
    rw [Φ_Node, NodeCost.apply, nodeParam_bias_one L]
    have hden : (nodeParam L).rightDiv.succ = 1 := by omega
    rw [hden]
    have hw : (nodeParam L).leftWeight = 1 := by
      cases L <;> simp [nodeParam] at hD ⊢
    rw [hw, ih_l, ih_r, EMLRegistry.EMLTree.size]
    simp

/-- Cost is preserved by Tamari rotation for logics with rightDiv = 0. -/
theorem Φ_contracts_one_eq_classical (L : LogicTypes.LogicType) {s t : EMLRegistry.EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (h : EMLRegistry.contracts_one s t) : Φ L s = Φ L t := by
  have hΦs : Φ L s = s.size := Φ_eq_size_classical L s hD
  have hΦt : Φ L t = t.size := Φ_eq_size_classical L t hD
  have hsize : s.size = t.size := EMLRegistry.contracts_one_size_eq h
  calc
    Φ L s = s.size := hΦs
    _ = t.size := hsize
    _ = Φ L t := Eq.symm hΦt

/-- Cost is preserved by multi-step paths for logics with rightDiv = 0. -/
theorem Φ_contracts_to_eq_classical (L : LogicTypes.LogicType) {s t : EMLRegistry.EMLTree}
    (hD : (nodeParam L).rightDiv = 0) (h : EMLRegistry.contracts_to s t) : Φ L s = Φ L t := by
  have hΦs : Φ L s = s.size := Φ_eq_size_classical L s hD
  have hΦt : Φ L t = t.size := Φ_eq_size_classical L t hD
  have hsize : s.size = t.size := EMLRegistry.contracts_to_size_eq h
  calc
    Φ L s = s.size := hΦs
    _ = t.size := hsize
    _ = Φ L t := Eq.symm hΦt

end Cost
