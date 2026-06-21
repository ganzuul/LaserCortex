"""
NodeCost + Φ — Python mirror of Cost.lean.

Extended with depth-2 semantics:
  maxSem (Intuitionistic): Φ = tree height (proof depth)
  satCap (Fuzzy): Φ bounded above by saturation cap

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
    mirror: bool = False
    maxSem: bool = False
    satCap: int = 0

    def apply(self, a: int, b: int) -> int:
        # Depth-2 max-semantics: proof depth (Intuitionistic)
        if self.maxSem:
            uncapped = max(a, b) + self.bias
        elif self.mirror:
            uncapped = self.bias + (a // max(1, self.rightDiv + 1)) + self.leftWeight * b
            uncapped += (self.coupling * a * b) // max(1, self.denom)
        else:
            uncapped = self.bias + self.leftWeight * a + (b // max(1, self.rightDiv + 1))
            uncapped += (self.coupling * a * b) // max(1, self.denom)
        # Depth-2 saturation cap (Fuzzy)
        if self.satCap > 0:
            return min(self.satCap, uncapped)
        return uncapped


NODE_PARAM: Dict[LogicType, NodeCost] = {
    LogicType.CLASSICAL:      NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.FUZZY:          NodeCost(leftWeight=1, rightDiv=2, bias=1, satCap=5),
    LogicType.MANY_VALUED:    NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.PARACONSISTENT: NodeCost(leftWeight=2, rightDiv=1, bias=1, coupling=1, denom=8),
    LogicType.TEMPORAL:       NodeCost(leftWeight=2, rightDiv=1, bias=1, coupling=1, denom=8),
    LogicType.DEONTIC:        NodeCost(leftWeight=1, rightDiv=2, bias=1),
    LogicType.EPISTEMIC:      NodeCost(leftWeight=1, rightDiv=2, bias=1),
    LogicType.QUANTUM:        NodeCost(leftWeight=1, rightDiv=1, bias=1, coupling=1, denom=10),
    LogicType.INTUITIONISTIC: NodeCost(leftWeight=1, rightDiv=0, bias=1, maxSem=True),
    LogicType.RELEVANCE:      NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.FREE:           NodeCost(leftWeight=1, rightDiv=0, bias=1),
    LogicType.INFINITARY:     NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.MODAL:          NodeCost(leftWeight=1, rightDiv=1, bias=1),
    LogicType.SPACETIME:      NodeCost(leftWeight=0, rightDiv=0, bias=1, mirror=True),
    LogicType.BOOLEAN:        NodeCost(leftWeight=1, rightDiv=0, bias=1),
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
