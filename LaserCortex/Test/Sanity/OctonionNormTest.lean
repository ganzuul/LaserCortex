import Mathlib
import LaserCortex.foundations.Algebra


-- Quick sanity check: is N(xy) = N(x)N(y) plausibly true?
-- Test on the famous e1 * e4 (associator-generating product)
example : (split_oct_mul e1_vec e4_vec).e5 = 1 := by
  simp [e1_vec, e4_vec, split_oct_mul]

example : (split_oct_mul e4_vec e1_vec).e5 = -1 := by
  simp [e4_vec, e1_vec, split_oct_mul]

example : octonion_norm e1_vec = 1 := by
  simp [e1_vec, octonion_norm]

example : octonion_norm e4_vec = -1 := by
  simp [e4_vec, octonion_norm]

example : octonion_norm (split_oct_mul e1_vec e4_vec) = -1 := by
  simp [e1_vec, e4_vec, split_oct_mul, octonion_norm]

-- Antipode pairing: (Sx · x).e0 = (x · Sx).e0 — both give the same (5,3) form
-- with positive sector {e0, e1, e2, e3, e4} and negative sector {e5, e6, e7}.
-- This differs from octonion_norm (4,4) and from x².e0 = antipode_pairing_self
-- (which has positive sector {e0, e4, e5, e6, e7}).
example {x : SplitOctonion} :
    (split_oct_mul (antipode x) x).e0
      = x.e0*x.e0 + x.e1*x.e1 + x.e2*x.e2 + x.e3*x.e3 + x.e4*x.e4
        - x.e5*x.e5 - x.e6*x.e6 - x.e7*x.e7 := by
  rcases x with ⟨a,b,c,d,e,f,g,h⟩
  dsimp [antipode, split_oct_mul]; ring

example {x : SplitOctonion} :
    (split_oct_mul x (antipode x)).e0
      = x.e0*x.e0 + x.e1*x.e1 + x.e2*x.e2 + x.e3*x.e3
        + x.e4*x.e4 - x.e5*x.e5 - x.e6*x.e6 - x.e7*x.e7 := by
  rcases x with ⟨a,b,c,d,e,f,g,h⟩
  dsimp [antipode, split_oct_mul]; ring
