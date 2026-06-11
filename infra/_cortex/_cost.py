"""
NodeCost + Φ — Python mirror of Cost.lean.

Mirrors:
  structure NodeCost
  def nodeParam : LogicType → NodeCost
  def Φ : LogicType → EMLTree → ℕ
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Dict

from ._eml_tree import EMLTree
from ._logic_types import LogicType


@dataclass(frozen=True)
class NodeCost:
    leftWeight: int
    rightDiv: int
    bias: int

    def apply(self, a: int, b: int) -> int:
        return self.bias + self.leftWeight * a + (b // max(1, self.rightDiv + 1))


NODE_PARAM: Dict[LogicType, NodeCost] = {
    LogicType.CLASSICAL:      NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.FUZZY:          NodeCost(leftWeight=1, rightDiv=2, bias=1),
    LogicType.MANY_VALUED:    NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.PARACONSISTENT: NodeCost(leftWeight=2, rightDiv=1, bias=1),
    LogicType.TEMPORAL:       NodeCost(leftWeight=2, rightDiv=1, bias=1),
    LogicType.DEONTIC:        NodeCost(leftWeight=1, rightDiv=2, bias=1),
    LogicType.EPISTEMIC:      NodeCost(leftWeight=1, rightDiv=2, bias=1),
    LogicType.QUANTUM:        NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.INTUITIONISTIC: NodeCost(leftWeight=1, rightDiv=0, bias=1),
    LogicType.RELEVANCE:      NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.FREE:           NodeCost(leftWeight=1, rightDiv=0, bias=1),
    LogicType.INFINITARY:     NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.MODAL:          NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.SPACETIME:      NodeCost(leftWeight=2, rightDiv=1, bias=1),
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


def phi_right_comb(lt: LogicType, n: int) -> int:
    from ._eml_tree import rightComb
    return phi(lt, rightComb(n))
