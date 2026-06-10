"""
Decomposition — Python mirror of Decomposition.lean.

Mirrors:
  inductive Path : EMLTree → EMLTree → Type
  def reverse_one : EMLTree → List EMLTree
  structure Decomposition (target : EMLTree) where
    source : EMLTree
    proof  : contracts_to source target
  inductive Chain : EMLTree → Type
  partial def ancestorsUpTo (t : EMLTree) (n : Nat) → List EMLTree
  partial def viewDFS (t : EMLTree) → Chain t
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Optional, Set

from ._eml_tree import (
    EMLTree, LEAF,
    contracts_one, contracts_to,
    contracts_one_successors, decidable_contracts_to,
)


# ── Path: a sequence of contraction steps ────────────────────────────

@dataclass(frozen=True)
class Path:
    """A witness path through the Tamari lattice.
    Mirror of: inductive Path : EMLTree → EMLTree → Type
    """
    source: EMLTree
    target: EMLTree
    steps: List[EMLTree] = field(default_factory=list)

    @staticmethod
    def nil(t: EMLTree) -> 'Path':
        """Empty path (reflexivity)."""
        return Path(source=t, target=t)

    @staticmethod
    def cons(step_src: EMLTree, step_tgt: EMLTree, rest: 'Path') -> 'Path':
        """Prepend a contraction step."""
        return Path(
            source=step_src,
            target=rest.target,
            steps=[step_src, step_tgt] + rest.steps[1:],
        )

    def length(self) -> int:
        """Number of contraction steps."""
        return max(0, len(self.steps) - 1)

    def append(self, other: 'Path') -> 'Path':
        """Concatenate two paths (self.source → other.target).
        Mirror of: Path.append
        """
        if not self.steps:
            return other
        if not other.steps:
            return self
        # Ensure continuity
        if self.steps[-1] != other.steps[0]:
            raise ValueError(
                f"Cannot append: self ends at {self.steps[-1]}, "
                f"other starts at {other.steps[0]}"
            )
        return Path(
            source=self.source,
            target=other.target,
            steps=self.steps + other.steps[1:],
        )

    def to_contracts_to(self) -> bool:
        """Check that every step is a valid contraction.
        Mirror of: Path.to_contracts_to
        """
        if not self.steps:
            return self.source == self.target
        if self.steps[0] != self.source:
            return False
        if self.steps[-1] != self.target:
            return False
        for i in range(len(self.steps) - 1):
            if not contracts_one(self.steps[i], self.steps[i + 1]):
                return False
        return True


# ── reverse_one: immediate predecessors ──────────────────────────────

def reverse_one(t: EMLTree) -> List[EMLTree]:
    """All trees that contract to t in one step.
    Mirror of: def reverse_one : EMLTree → List EMLTree

    Soundness: each s in result satisfies contracts_one s t.
    Completeness: every s with contracts_one s t is in result.
    """
    if t.is_leaf:
        return []

    l, r = t.left, t.right

    # Case: Node l (Node r1 r2) — can rotate backward
    if not r.is_leaf:
        r1, r2 = r.left, r.right
        result: List[EMLTree] = []
        # Direct rotation: (Node (Node l r1) r2) → Node l (Node r1 r2)
        result.append(EMLTree.node(EMLTree.node(l, r1), r2))
        # Rotations in left subtree
        for l_prime in reverse_one(l):
            result.append(EMLTree.node(l_prime, EMLTree.node(r1, r2)))
        # Rotations in right subtree (the Node r1 r2)
        for r_prime in reverse_one(r):
            result.append(EMLTree.node(l, r_prime))
        return result

    # Case: Node l Leaf — only context rules apply
    result = []
    for l_prime in reverse_one(l):
        result.append(EMLTree.node(l_prime, r))
    for r_prime in reverse_one(r):
        result.append(EMLTree.node(l, r_prime))
    return result


def reverse_one_sound(t: EMLTree, s: EMLTree) -> bool:
    """Soundness check: if s in reverse_one(t), then contracts_one s t.
    Mirror of: reverse_one_sound
    """
    return s in reverse_one(t) and contracts_one(s, t)


def reverse_one_complete(s: EMLTree, t: EMLTree) -> bool:
    """Completeness check: if contracts_one s t, then s in reverse_one(t).
    Mirror of: reverse_one_complete
    """
    if not contracts_one(s, t):
        return True  # vacuous
    return s in reverse_one(t)


# ── Decomposition ────────────────────────────────────────────────────

@dataclass(frozen=True)
class Decomposition:
    """An outcome together with a prior configuration that produces it.
    Mirror of: structure Decomposition (target : EMLTree) where
      source : EMLTree
      proof  : contracts_to source target
    """
    source: EMLTree
    target: EMLTree

    def verify(self) -> bool:
        """Check that source contracts to target."""
        return decidable_contracts_to(self.source, self.target)


# ── Chain: a finite ancestor chain ──────────────────────────────────

@dataclass(frozen=True)
class Chain:
    """A finite chain of contraction steps from an ancestor to a target.
    Mirror of: inductive Chain : EMLTree → Type
    """
    target: EMLTree
    steps: List[EMLTree] = field(default_factory=list)

    @staticmethod
    def tip(t: EMLTree) -> 'Chain':
        """Empty chain at the target (no reconstructed past)."""
        return Chain(target=t)

    @staticmethod
    def link(step_src: EMLTree, step_tgt: EMLTree, rest: 'Chain') -> 'Chain':
        """Prepend a contraction step."""
        return Chain(
            target=rest.target,
            steps=[step_src, step_tgt] + rest.steps[1:],
        )


# ── ancestorsUpTo: hypercomputer enumeration ────────────────────────

def ancestors_up_to(t: EMLTree, n: int) -> List[EMLTree]:
    """Enumerate all ancestors up to depth n via DFS.
    Mirror of: partial def ancestorsUpTo (t : EMLTree) (n : Nat) → List EMLTree

    This is the hypercomputer in function form: the infinite tree of all
    possible pasts is present as the limit as n → ∞.
    """
    if n <= 0:
        return []
    cur = reverse_one(t)
    result = list(cur)
    for s in cur:
        result.extend(ancestors_up_to(s, n - 1))
    return result


# ── viewDFS: a single committed lineage ─────────────────────────────

def view_dfs(t: EMLTree, max_depth: int = 100) -> Chain:
    """Extract a single lineage by always following the first predecessor.
    Mirror of: partial def viewDFS (t : EMLTree) → Chain t
    """
    preds = reverse_one(t)
    if not preds or max_depth <= 0:
        return Chain.tip(t)
    first = preds[0]
    rest = view_dfs(first, max_depth - 1)
    return Chain.link(first, t, rest)
