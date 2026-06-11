"""
AMM routing — Python mirror of AMM.lean.

Mirrors:
  inductive Route
  def routeToTree
  def compose
  def crossImpact : LogicType → Route → Route → ℕ
  def associatorCost : LogicType → Route → Route → Route → ℕ
  def absDiff
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import List

from ._eml_tree import EMLTree
from ._cost import phi
from ._logic_types import LogicType


@dataclass(frozen=True)
class Route:
    is_leaf: bool = True
    left: Route | None = None
    right: Route | None = None

    @staticmethod
    def leaf() -> Route:
        return Route(is_leaf=True)

    @staticmethod
    def node(left: Route, right: Route) -> Route:
        return Route(is_leaf=False, left=left, right=right)

    def __repr__(self) -> str:
        if self.is_leaf:
            return "Leaf"
        return f"Node({self.left!r}, {self.right!r})"


def route_to_tree(r: Route) -> EMLTree:
    if r.is_leaf:
        return EMLTree.leaf()
    return EMLTree.node(route_to_tree(r.left), route_to_tree(r.right))


def compose(r1: Route, r2: Route) -> Route:
    return Route.node(r1, r2)


def abs_diff(a: int, b: int) -> int:
    return (a - b) + (b - a)


def cross_impact(lt: LogicType, r1: Route, r2: Route) -> int:
    phi_compose = phi(lt, route_to_tree(compose(r1, r2)))
    phi_sum = phi(lt, route_to_tree(r1)) + phi(lt, route_to_tree(r2))
    if phi_compose < phi_sum:
        return 0
    return phi_compose - phi_sum


def associator_cost(lt: LogicType, r1: Route, r2: Route, r3: Route) -> int:
    a = phi(lt, route_to_tree(compose(compose(r1, r2), r3)))
    b = phi(lt, route_to_tree(compose(r1, compose(r2, r3))))
    return abs_diff(a, b)


def route_depth(r: Route) -> int:
    if r.is_leaf:
        return 0
    return 1 + route_depth(r.left) + route_depth(r.right)


def all_routes(n: int) -> List[Route]:
    """Generate all routes with n internal nodes (Catalan(n) of them)."""
    if n == 0:
        return [Route.leaf()]
    result: List[Route] = []
    for i in range(n):
        for left in all_routes(i):
            for right in all_routes(n - 1 - i):
                result.append(Route.node(left, right))
    return result
