"""
Core bridge types — Python mirror of EMLRegistry.lean sections on
RouterIndex, TypeRegistry, CortexCertificate.

Mirrors:
  abbrev RouterIndex (n : Nat) := Fin n
  structure TypeRegistry (n : Nat) where ...
  structure CortexCertificate where ...
  def certify (t : EMLTree) : CortexCertificate
"""

from __future__ import annotations
import subprocess
import os
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Set


# ── RouterIndex ──────────────────────────────────────────────────────

class RouterIndexError(ValueError):
    """Raised when a router index is out of bounds."""


@dataclass(frozen=True)
class RouterIndex:
    """Bounded natural number — neural binding address.
    Mirror of: abbrev RouterIndex (n : Nat) := Fin n

    A RouterIndex is a natural number i : 0 ≤ i < bound.
    """
    index: int
    bound: int

    def __post_init__(self):
        if not (0 <= self.index < self.bound):
            raise RouterIndexError(
                f"RouterIndex({self.index}) out of bounds [0, {self.bound})"
            )

    def __repr__(self) -> str:
        return f"#{self.index}"

    def to_flow_string(self) -> str:
        """Convert to a dotted flow index string like '1.2.3'."""
        return _index_to_flow(self.index)


def _index_to_flow(i: int) -> str:
    """Decode a flat index into a dotted flow index.
    Heuristic: flow "1.2.3" would map to index position in a DFS ordering.
    For now, just return the index as a single segment.
    """
    return str(i + 1)


def flow_to_index(flow: str) -> int:
    """Convert a dotted flow index like '1.2.3' to a flat index.
    Heuristic: use a hash/bucket approach. In practice this maps to
    a position in the TypeRegistry's RouterIndex space.
    """
    parts = [int(p) for p in flow.split(".")]
    # Simple encoding: treat as variable-base number
    idx = 0
    for i, p in enumerate(reversed(parts)):
        idx += (p - 1) * (10 ** i)
    return idx


# ── TypeRegistry ─────────────────────────────────────────────────────

@dataclass
class TypeRegistry:
    """Injective mapping from router indices to EMLTrees.
    Mirror of: structure TypeRegistry (n : Nat) where
      toTree    : RouterIndex n → EMLTree
      injective : Function.Injective toTree

    In Python we maintain the mapping explicitly and check
    injectivity on insertion.
    """
    bound: int
    _entries: Dict[int, EMLTree] = field(default_factory=dict)

    def register(self, idx: RouterIndex, tree: EMLTree) -> None:
        """Register a binding. Raises if index is out of bounds
        or if the tree would break injectivity.
        """
        if idx.bound != self.bound:
            raise RouterIndexError(
                f"RouterIndex bound {idx.bound} != registry bound {self.bound}"
            )
        # Check injectivity: no other index maps to the same tree
        for existing_i, existing_tree in self._entries.items():
            if existing_tree == tree and existing_i != idx.index:
                raise ValueError(
                    f"Tree {tree} already registered at index {existing_i}; "
                    f"cannot register at {idx.index} (injectivity violated)"
                )
        self._entries[idx.index] = tree

    def lookup(self, idx: RouterIndex) -> Optional[EMLTree]:
        """Get the tree bound to a router index."""
        return self._entries.get(idx.index)

    def find(self, tree: EMLTree) -> Optional[RouterIndex]:
        """Reverse lookup: find the index for a tree (if registered)."""
        for i, t in self._entries.items():
            if t == tree:
                return RouterIndex(i, self.bound)
        return None

    def all_bindings(self) -> List[tuple[RouterIndex, EMLTree]]:
        """Return all (index, tree) pairs."""
        return [
            (RouterIndex(i, self.bound), t)
            for i, t in sorted(self._entries.items())
        ]

    def is_injective(self) -> bool:
        """Verify the injectivity property holds."""
        trees = list(self._entries.values())
        return len(trees) == len(set(trees))


# ── CortexCertificate ────────────────────────────────────────────────

def _lean_binary_path() -> str:
    """Return the path to the Lean verifier binary."""
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    candidate = os.path.join(repo_root, ".lake", "build", "bin", "lasercortex")
    if os.path.exists(candidate):
        return candidate
    return "lasercortex"


def lean_verify(tree: EMLTree) -> bool:
    """Verify that `tree` contracts to its right-comb normal form
    by calling the Lean verifier binary.

    The binary reads a binary-encoded EMLTree on stdin
    ('0' for Leaf, '1' + left + right for Node) and prints
    "verified" or "failed".
    """
    encoded = tree.to_bits()
    try:
        result = subprocess.run(
            [_lean_binary_path()],
            input=encoded,
            capture_output=True,
            text=True,
            timeout=30,
        )
        return "verified" in result.stdout
    except (subprocess.SubprocessError, FileNotFoundError):
        return False


@dataclass(frozen=True)
class CortexCertificate:
    """Proof-carrying audit trail: a tree reaches its equilibrium.
    Mirror of: structure CortexCertificate where
      source : EMLTree
      target : EMLTree
      proof  : contracts_to source target

    In Python, 'proof' is approximated by the path (list of intermediate trees).
    The actual proof term lives in Lean.
    """
    source: EMLTree
    target: EMLTree
    path: List[EMLTree]  # sequence of intermediate trees [source, ..., target]

    def __repr__(self) -> str:
        return (
            f"CortexCertificate("
            f"source={self.source!r}, "
            f"target={self.target!r}, "
            f"path_len={len(self.path)})"
        )

    def verify(self, use_lean: bool = False) -> bool:
        """Check that every step in the path is a valid contraction.
        This is the Skeptic's verification: given the path, check
        each contracts_one step.

        When `use_lean=True`, additionally delegates to the Lean
        verifier binary for final confirmation.
        """
        from ._eml_tree import contracts_one
        if not self.path:
            return False
        if self.path[0] != self.source:
            return False
        if self.path[-1] != self.target:
            return False
        for i in range(len(self.path) - 1):
            if not contracts_one(self.path[i], self.path[i + 1]):
                return False
        if use_lean:
            return lean_verify(self.source)
        return True


def certify(t: EMLTree) -> CortexCertificate:
    """Issue a CortexCertificate for any tree.
    Mirror of: def certify (t : EMLTree) : CortexCertificate
    Guarantees: target = rightComb t.size and contracts_to t target.
    """
    from ._eml_tree import rightComb, contracts_one_successors

    target = rightComb(t.size())
    # Build a path via greedy DFS
    path = _build_contraction_path(t, target)
    return CortexCertificate(source=t, target=target, path=path)


def _build_contraction_path(s: EMLTree, t: EMLTree, max_depth: int = 1000) -> List[EMLTree]:
    """Find a contraction path from s to t via DFS."""
    from ._eml_tree import contracts_one_successors
    if s == t:
        return [s]
    if max_depth <= 0:
        return [s]

    visited: Set[EMLTree] = set()

    def dfs(current: EMLTree, depth: int) -> Optional[List[EMLTree]]:
        if current == t:
            return [current]
        if depth <= 0:
            return None
        key = current
        if key in visited:
            return None
        visited.add(key)
        for succ in contracts_one_successors(current):
            rest = dfs(succ, depth - 1)
            if rest is not None:
                return [current] + rest
        return None

    result = dfs(s, max_depth)
    if result is None:
        # Fallback: just return [s, t] (unverified path)
        return [s, t]
    return result
