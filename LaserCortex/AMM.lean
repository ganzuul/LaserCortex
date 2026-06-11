import LaserCortex.EMLRegistry

open EMLRegistry

namespace AMM

/-- A constant-product liquidity pool for two tokens.
    Reserves are natural numbers (e.g. wei). Invariant: x * y = k. -/
structure Pool where
  reserveA : Nat
  reserveB : Nat
  hApos : 0 < reserveA
  hBpos : 0 < reserveB
  deriving Repr

/-- The constant product invariant. -/
def k (p : Pool) : Nat := p.reserveA * p.reserveB

/-- k is positive. -/
theorem k_pos (p : Pool) : 0 < k p := by
  dsimp [k]; exact Nat.mul_pos p.hApos p.hBpos

/-- Output of swapping `dx` token A for token B.
    Formula: dy = (reserveB * dx) / (reserveA + dx) (floor division). -/
def swapOut (p : Pool) (dx : Nat) : Nat :=
  (p.reserveB * dx) / (p.reserveA + dx)

/-- After a swap the product never decreases (floor division rounds down,
    so the remainder stays in the pool). -/
theorem swap_preserves_k_bound (p : Pool) (dx : Nat) :
    (p.reserveA + dx) * (p.reserveB - swapOut p dx) ≥ k p := by
  match p with
  | ⟨x, y, hxApos, hxBpos⟩ =>
    have hxpos : 0 < x + dx :=
      Nat.lt_of_lt_of_le hxApos (Nat.le_add_right x dx)
    let q := (y * dx) / (x + dx)
    let r := (y * dx) % (x + dx)
    have hdiv_add_mod : (x + dx) * q + r = y * dx := by
      simpa [q, r] using Nat.div_add_mod (y * dx) (x + dx)
    have h_mul_div : q * (x + dx) ≤ y * dx := by
      simpa [q, Nat.mul_comm] using Nat.mul_div_le (y * dx) (x + dx)
    have hqy : q ≤ y := by
      apply Nat.le_of_not_gt
      intro H
      have h_lt_mul : y * (x + dx) < q * (x + dx) :=
        Nat.mul_lt_mul_of_pos_right H hxpos
      have h_ge : y * dx ≤ y * (x + dx) :=
        Nat.mul_le_mul_left y (Nat.le_add_left dx x)
      have h_contra : y * dx < q * (x + dx) :=
        Nat.lt_of_le_of_lt h_ge h_lt_mul
      exact (Nat.not_lt.mpr h_mul_div) h_contra
    have h_mul_div' : q * (x + dx) = y * dx - r := by
      calc
        q * (x + dx) = (x + dx) * q := by rw [Nat.mul_comm]
        _ = ((x + dx) * q + r) - r := by rw [Nat.add_sub_cancel]
        _ = y * dx - r := by rw [hdiv_add_mod]
    calc
      (x + dx) * (y - swapOut ⟨x, y, hxApos, hxBpos⟩ dx) = (x + dx) * (y - q) := rfl
      _ = (x + dx) * y - (x + dx) * q := by rw [Nat.mul_sub_left_distrib]
      _ = (x + dx) * y - (q * (x + dx)) := by rw [Nat.mul_comm (x + dx) q]
      _ = (x + dx) * y - (y * dx - r) := by rw [h_mul_div']
      _ = (x * y + y * dx) - (y * dx - r) := by
        have h_mul_eq : (x + dx) * y = x * y + y * dx := by
          calc
            (x + dx) * y = x * y + dx * y := by rw [Nat.add_mul]
            _ = x * y + y * dx := by rw [Nat.mul_comm dx y]
        rw [h_mul_eq]
      _ = x * y + (y * dx - (y * dx - r)) := by
        rw [Nat.add_sub_assoc (Nat.sub_le (y * dx) r) (x * y)]
      _ = x * y + r := by
        rw [Nat.sub_sub_self (Nat.mod_le (y * dx) (x + dx))]
      _ ≥ x * y := Nat.le_add_right (x * y) r
      _ = k ⟨x, y, hxApos, hxBpos⟩ := rfl

/-- A swap route is a binary tree of pools.
    Leaf = terminal token, Node = sequential composition of two sub-routes. -/
inductive Route : Type where
  | leaf : Route
  | node : Route → Route → Route
  deriving DecidableEq, Repr

/-- Map a route to an EMLTree (the Tamari decomposition of the swap). -/
def routeToTree : Route → EMLTree
  | .leaf => .Leaf
  | .node l r => .Node (routeToTree l) (routeToTree r)

/-- The depth of a route as a path in the Tamari lattice. -/
def routeDepth : Route → Nat
  | .leaf => 0
  | .node l r => 1 + routeDepth l + routeDepth r

/-- A priced route: a route with its total cross-impact cost. -/
structure PricedRoute where
  route : Route
  totalCost : Nat

end AMM
