"""
Logic monad — Python mirror of LogicMonad.lean.

Mirrors:
  inductive LogicM (α : Type) where
    | pure : α → LogicM α
    | node : LogicM α → LogicM α → LogicM α
  structure LogicMonad (lt : LogicType) (α : Type) where
    tree : LogicM α
  def toEMLTree : LogicM α → EMLTree
  def bind / map (Monad / Functor instances)
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Callable, Generic, List, TypeVar

from ._eml_tree import EMLTree, LEAF
from ._logic_types import LogicType

A = TypeVar('A')
B = TypeVar('B')


@dataclass(frozen=True)
class LogicM(Generic[A]):
    """Free monad over binary trees.
    Mirror of: inductive LogicM (α : Type) where
      | pure : α → LogicM α
      | node : LogicM α → LogicM α → LogicM α

    This is the universal self-reference structure: bind performs
    substitution at every leaf.
    """
    is_pure: bool = True
    value: A = None  # type: ignore
    left: 'LogicM[A]' = None  # type: ignore
    right: 'LogicM[A]' = None  # type: ignore

    @staticmethod
    def pure(val: A) -> 'LogicM[A]':
        return LogicM(is_pure=True, value=val)

    @staticmethod
    def node(left: 'LogicM[A]', right: 'LogicM[A]') -> 'LogicM[A]':
        return LogicM(is_pure=False, left=left, right=right)

    def bind(self, f: Callable[[A], 'LogicM[B]']) -> 'LogicM[B]':
        """Monadic bind: substitute every leaf with f(value).
        Mirror of: LogicM.bind
        """
        if self.is_pure:
            return f(self.value)
        return LogicM.node(
            self.left.bind(f),
            self.right.bind(f),
        )

    def map(self, f: Callable[[A], B]) -> 'LogicM[B]':
        """Functor map.
        Mirror of: LogicM.map
        """
        if self.is_pure:
            return LogicM.pure(f(self.value))
        return LogicM.node(
            self.left.map(f),
            self.right.map(f),
        )

    def to_eml_tree(self) -> EMLTree:
        """Forget the leaf values: map every leaf to Leaf.
        Mirror of: LogicM.toEMLTree
        """
        if self.is_pure:
            return LEAF
        return EMLTree.node(
            self.left.to_eml_tree(),
            self.right.to_eml_tree(),
        )

    def size(self) -> int:
        """Number of internal nodes.
        Mirror of: LogicM.size
        """
        return self.to_eml_tree().size()

    def flatten(self) -> List[A]:
        """Collect all leaf values in left-to-right order."""
        if self.is_pure:
            return [self.value]
        return self.left.flatten() + self.right.flatten()

    def __repr__(self) -> str:
        if self.is_pure:
            return f"pure({self.value!r})"
        return f"node({self.left!r}, {self.right!r})"


@dataclass(frozen=True)
class LogicMonad(Generic[A]):
    """A logic-specific monad: a LogicM tree paired with a logic type.
    Mirror of: structure LogicMonad (lt : LogicType) (α : Type)
      tree : LogicM α
    """
    logic: LogicType
    tree: LogicM[A]

    def to_tree(self) -> LogicM[A]:
        """Forget the logic-specific structure.
        Mirror of: LogicMonad.toTree
        """
        return self.tree

    def seq(self, f: Callable[[A], 'LogicMonad[B]']) -> 'LogicMonad[B]':
        """Sequence and normalize under the logic.
        Mirror of: LogicMonad.seq
        """
        combined = self.tree.bind(lambda x: f(x).tree)
        return LogicMonad(logic=self.logic, tree=combined)

    @staticmethod
    def pure(lt: LogicType, val: A) -> 'LogicMonad[A]':
        """Embed a value as a pure logic-specific monad.
        Mirror of: LogicMonad.pure
        """
        return LogicMonad(logic=lt, tree=LogicM.pure(val))
