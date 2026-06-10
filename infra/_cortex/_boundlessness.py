"""
Boundlessness — Python mirror of Boundlessness.lean.

Mirrors:
  structure IdempotentResolution (α : Type) where
    step  : α → α
    idemp : step ∘ step = step
    limit : α → α
    factor : limit = step ∘ limit
  structure VeryBigBox where
    liar / sorites / grandfather / russells : IdempotentResolution EMLTree
  def rightCombResolution : IdempotentResolution EMLTree
  def rightComb_meta_idemp : rightComb ∘ rightComb = rightComb
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Callable, Generic, TypeVar

from ._eml_tree import EMLTree, rightComb

A = TypeVar('A')


@dataclass(frozen=True)
class IdempotentResolution(Generic[A]):
    """A regularization step that is idempotent with a limit point.
    Mirror of: structure IdempotentResolution (α : Type) where
      step   : α → α
      idemp  : step ∘ step = step
      limit  : α → α
      factor : limit = step ∘ limit

    In Python, idempotence is a runtime-checkable property rather than
    a proof term.
    """
    step: Callable[[A], A]
    limit: Callable[[A], A]

    def check_idempotent(self, value: A) -> bool:
        """Check step(step(value)) == step(value)."""
        return self.step(self.step(value)) == self.step(value)

    def check_factor(self, value: A) -> bool:
        """Check limit(value) == step(limit(value))."""
        return self.limit(value) == self.step(self.limit(value))


# ── Right-comb resolution ─────────────────────────────────────────────

def _step(t: EMLTree) -> EMLTree:
    """Contract any tree to its right-comb normal form."""
    return rightComb(t.size())


def _limit(t: EMLTree) -> EMLTree:
    """Same as step for right-comb resolution."""
    return rightComb(t.size())


RIGHT_COMB_RESOLUTION = IdempotentResolution[EMLTree](
    step=_step,
    limit=_limit,
)


# ── Very Big Box ──────────────────────────────────────────────────────

@dataclass(frozen=True)
class VeryBigBox:
    """Packages the four populated problem classes into a single product.
    Mirror of: structure VeryBigBox where
      liar        : IdempotentResolution EMLTree
      sorites     : IdempotentResolution EMLTree
      grandfather : IdempotentResolution EMLTree
      russells    : IdempotentResolution EMLTree
    """
    liar: IdempotentResolution[EMLTree]
    sorites: IdempotentResolution[EMLTree]
    grandfather: IdempotentResolution[EMLTree]
    russells: IdempotentResolution[EMLTree]


VERY_BIG_BOX = VeryBigBox(
    liar=RIGHT_COMB_RESOLUTION,
    sorites=RIGHT_COMB_RESOLUTION,
    grandfather=RIGHT_COMB_RESOLUTION,
    russells=RIGHT_COMB_RESOLUTION,
)
