-- EMLRegistry.lean - Minimal working version
-- Binding layer: neural router index <-> EML inductive tree type

namespace EMLRegistry

-- EMLTree: The core inductive type
inductive EMLTree : Type where
  | Leaf : EMLTree
  | Node : EMLTree → EMLTree → EMLTree
  deriving DecidableEq, Repr

-- Tree size (number of internal nodes)
def EMLTree.size : EMLTree → Nat
  | .Leaf       => 0
  | .Node l r   => 1 + l.size + r.size

-- Tamari contraction: one step (right rotation)
inductive contracts_one : EMLTree → EMLTree → Prop where
  | rotate : ∀ (a b c : EMLTree),
      contracts_one (.Node (.Node a b) c) (.Node a (.Node b c))
  | left   : ∀ (l l' r : EMLTree),
      contracts_one l l' → contracts_one (.Node l r) (.Node l' r)
  | right  : ∀ (l r r' : EMLTree),
      contracts_one r r' → contracts_one (.Node l r) (.Node l r')

-- Tamari contraction: reflexive-transitive closure
inductive contracts_to : EMLTree → EMLTree → Prop where
  | refl  : ∀ (t : EMLTree), contracts_to t t
  | step  : ∀ (s t u : EMLTree),
      contracts_one s t → contracts_to t u → contracts_to s u

-- Right-comb: the minimum element in Tamari order
def rightComb : Nat → EMLTree
  | 0     => .Leaf
  | n + 1 => .Node .Leaf (rightComb n)

-- Router index (bounded natural)
abbrev RouterIndex (n : Nat) := Fin n

-- Type registry
structure TypeRegistry (n : Nat) where
  toTree    : RouterIndex n → EMLTree
  injective : Function.Injective toTree

end EMLRegistry
