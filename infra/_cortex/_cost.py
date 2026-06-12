"""
NodeCost + Φ — Python mirror of Cost.lean.

Extended with product coupling term for tensegrity:
  apply(a,b) = bias + leftWeight*a + b/(rightDiv+1) + coupling*a*b/denom

Mirrors (extended):
  structure NodeCost
  def nodeParam : LogicType → NodeCost
  def Φ : LogicType → EMLTree → ℕ
  def Φ_coupled : LogicType → Nat → EMLTree → ℕ   (coupling parameter)
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Dict, List

from ._eml_tree import EMLTree
from ._logic_types import LogicType


@dataclass(frozen=True)
class NodeCost:
    leftWeight: int
    rightDiv: int
    bias: int
    coupling: int = 0
    denom: int = 10

    def apply(self, a: int, b: int) -> int:
        linear = self.bias + self.leftWeight * a + (b // max(1, self.rightDiv + 1))
        product = (self.coupling * a * b) // max(1, self.denom)
        return linear + product


NODE_PARAM: Dict[LogicType, NodeCost] = {
    LogicType.CLASSICAL:      NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.FUZZY:          NodeCost(leftWeight=1, rightDiv=2, bias=1),
    LogicType.MANY_VALUED:    NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.PARACONSISTENT: NodeCost(leftWeight=2, rightDiv=1, bias=1, coupling=1, denom=8),
    LogicType.TEMPORAL:       NodeCost(leftWeight=2, rightDiv=1, bias=1, coupling=1, denom=8),
    LogicType.DEONTIC:        NodeCost(leftWeight=1, rightDiv=2, bias=1),
    LogicType.EPISTEMIC:      NodeCost(leftWeight=1, rightDiv=2, bias=1),
    LogicType.QUANTUM:        NodeCost(leftWeight=1, rightDiv=1, bias=1, coupling=1, denom=10),
    LogicType.INTUITIONISTIC: NodeCost(leftWeight=1, rightDiv=0, bias=1),
    LogicType.RELEVANCE:      NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.FREE:           NodeCost(leftWeight=1, rightDiv=0, bias=1),
    LogicType.INFINITARY:     NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.MODAL:          NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.SPACETIME:      NodeCost(leftWeight=2, rightDiv=1, bias=1, coupling=2, denom=6),
}


def node_param(lt: LogicType) -> NodeCost:
    return NODE_PARAM[lt]


def phi(lt: LogicType, t: EMLTree) -> int:
    c = node_param(lt)
    def _inner(tree: EMLTree) -> int:
        if tree.is_leaf:
            return 0
        return c.apply(_inner(tree.left), _inner(tree.right))
    return _inner(t)


def phi_coupled(lt: LogicType, t: EMLTree, coupling: int, denom: int = 10) -> int:
    """Φ with an explicit coupling override for sweep analysis."""
    base = node_param(lt)
    c = NodeCost(
        leftWeight=base.leftWeight,
        rightDiv=base.rightDiv,
        bias=base.bias,
        coupling=coupling,
        denom=denom,
    )
    def _inner(tree: EMLTree) -> int:
        if tree.is_leaf:
            return 0
        return c.apply(_inner(tree.left), _inner(tree.right))
    return _inner(t)


def phi_right_comb(lt: LogicType, n: int) -> int:
    from ._eml_tree import rightComb
    return phi(lt, rightComb(n))
