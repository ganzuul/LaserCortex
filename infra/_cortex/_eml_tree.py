"""
EMLTree — Python mirror of LaserCortex/EMLRegistry.lean

Mirrors:
  inductive EMLTree : Type where
    | Leaf : EMLTree
    | Node : EMLTree → EMLTree → EMLTree

  inductive contracts_one : EMLTree → EMLTree → Prop
  inductive contracts_to  : EMLTree → EMLTree → Prop
  def rightComb / leftComb
  def contracts_one_successors
  partial def decidable_contracts_to
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import List, Optional, Tuple


@dataclass(frozen=True)
class EMLTree:
    """Binary tree — the core inductive type of the Tamari lattice.
    Leaf = empty configuration. Node = non-associative composition.
    """
    is_leaf: bool = True
    left: Optional['EMLTree'] = None
    right: Optional['EMLTree'] = None

    @staticmethod
    def leaf() -> 'EMLTree':
        return EMLTree(is_leaf=True)

    @staticmethod
    def node(left: 'EMLTree', right: 'EMLTree') -> 'EMLTree':
        return EMLTree(is_leaf=False, left=left, right=right)

    def size(self) -> int:
        """Number of internal nodes. Mirrors EMLTree.size."""
        if self.is_leaf:
            return 0
        return 1 + self.left.size() + self.right.size()

    def __repr__(self) -> str:
        if self.is_leaf:
            return "Leaf"
        return f"Node({self.left!r}, {self.right!r})"

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, EMLTree):
            return NotImplemented
        if self.is_leaf and other.is_leaf:
            return True
        if not self.is_leaf and not other.is_leaf:
            return self.left == other.left and self.right == other.right
        return False

    def __hash__(self) -> int:
        if self.is_leaf:
            return hash(())
        return hash((self.left, self.right))

    def to_bits(self) -> str:
        """Binary preorder encoding for the Lean verifier.
        '0' → Leaf, '1' + left + right → Node.
        """
        if self.is_leaf:
            return "0"
        return "1" + self.left.to_bits() + self.right.to_bits()


# ── Canonical trees ──────────────────────────────────────────────────

LEAF: EMLTree = EMLTree.leaf()


def rightComb(n: int) -> EMLTree:
    """Right-comb normal form: minimum element in Tamari order.
    Mirror of EMLRegistry.rightComb.
    """
    if n <= 0:
        return LEAF
    return EMLTree.node(LEAF, rightComb(n - 1))


def leftComb(n: int) -> EMLTree:
    """Left-comb: sequential composition, maximum element in Tamari order.
    Mirror of EMLRegistry.leftComb.
    """
    if n <= 0:
        return LEAF
    return EMLTree.node(leftComb(n - 1), LEAF)


# ── Single-step Tamari contraction ───────────────────────────────────

def contracts_one(s: EMLTree, t: EMLTree) -> bool:
    """Check if s → t in one Tamari rotation.
    Mirror of inductive contracts_one : EMLTree → EMLTree → Prop.
    Three rules: rotate, left context, right context.
    """
    return _contracts_one_inner(s, t)


def _contracts_one_inner(s: EMLTree, t: EMLTree) -> bool:
    """Direct check without context rules — used by successors generator."""
    # Rule: rotate: Node(Node a b) c → Node a (Node b c)
    if not s.is_leaf and not s.left.is_leaf:
        a, b, c = s.left.left, s.left.right, s.right
        expected = EMLTree.node(a, EMLTree.node(b, c))
        if t == expected:
            return True

    # Rule: left context: if l → l' then Node l r → Node l' r
    if not s.is_leaf and not t.is_leaf and s.right == t.right:
        if contracts_one(s.left, t.left):
            return True

    # Rule: right context: if r → r' then Node l r → Node l r'
    if not s.is_leaf and not t.is_leaf and s.left == t.left:
        if contracts_one(s.right, t.right):
            return True

    return False


def contracts_to(s: EMLTree, t: EMLTree, max_depth: int = 1000) -> bool:
    """Reflexive-transitive closure of contracts_one.
    Mirror of inductive contracts_to : EMLTree → EMLTree → Prop.
    Uses bounded DFS since the space is finite for a given size.
    """
    if s.size() != t.size():
        return False
    return _contracts_to_dfs(s, t, set(), max_depth)


def _contracts_to_dfs(
    current: EMLTree, target: EMLTree,
    visited: set[EMLTree], depth: int
) -> bool:
    if current == target:
        return True
    if depth <= 0:
        return False
    key = current
    if key in visited:
        return False
    visited.add(key)
    for succ in contracts_one_successors(current):
        if _contracts_to_dfs(succ, target, visited, depth - 1):
            return True
    return False


# ── Successor enumeration ────────────────────────────────────────────

def contracts_one_successors(t: EMLTree) -> List[EMLTree]:
    """All trees reachable in one contraction step.
    Mirror of contracts_one_successors from EMLRegistry.lean.
    """
    if t.is_leaf:
        return []

    # Direct rotation at this node: Node(Node a b) c → Node a (Node b c)
    result: List[EMLTree] = []

    if not t.left.is_leaf:
        a, b, c = t.left.left, t.left.right, t.right
        result.append(EMLTree.node(a, EMLTree.node(b, c)))

    # Possible rotations in left subtree
    for a_prime in contracts_one_successors(t.left):
        result.append(EMLTree.node(a_prime, t.right))

    # Possible rotations in right subtree
    for c_prime in contracts_one_successors(t.right):
        result.append(EMLTree.node(t.left, c_prime))

    return result


def decidable_contracts_to(s: EMLTree, t: EMLTree) -> bool:
    """Decidable version of contracts_to via bounded search.
    Mirror of partial def decidable_contracts_to.
    """
    return contracts_to(s, t)


# ── Helpers for tree construction from flow indices ──────────────────

def tree_from_flow_index(parts: List[int]) -> EMLTree:
    """Build an EMLTree from a flow index like [1, 2, 3].
    Each segment becomes a right-nested node: Node(Leaf, Node(Leaf, Node(Leaf, Leaf)))
    """
    if not parts:
        return LEAF
    if len(parts) == 1:
        return EMLTree.node(LEAF, LEAF)
    current = LEAF
    for _ in parts:
        current = EMLTree.node(current, LEAF)
    return current
