"""
Paradox taxonomy — Python mirror of LiarParadox.lean.

Mirrors:
  inductive ProblemClass where
    | selfReference | vagueness | inconsistentDef | ...
  structure Problem where ...
  structure WrappedProblem (p : Problem) (lt : LogicType) where ...
  structure Tower (p : Problem) where ...
  def frictionLagrangian : Nat
  def liarCost (lt : LogicType) : Nat
"""

from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Callable, Dict, List, Optional

from ._eml_tree import EMLTree, rightComb, contracts_to, leftComb, LEAF
from ._logic_types import LogicType, logic_contraction, logic_normal_form


class ProblemClass(Enum):
    """A class of paradoxes sharing a common structural pattern.
    Mirror of: inductive ProblemClass
    """
    SELF_REFERENCE = "self_reference"
    VAGUENESS = "vagueness"
    INCONSISTENT_DEF = "inconsistent_def"
    TEMPORAL_DECISION = "temporal_decision"
    DEONTIC = "deontic"
    EPISTEMIC = "epistemic"
    QUANTUM_SUPERPOSITION = "quantum_superposition"
    CONSTRUCTIVE = "constructive"
    RELEVANCE = "relevance"
    EMPTY_REFERENCE = "empty_reference"
    INFINITY = "infinity"
    MODALITY = "modality"
    META_PARADOX = "meta_paradox"

    def display_name(self) -> str:
        names = {
            ProblemClass.SELF_REFERENCE: "Self-Reference",
            ProblemClass.VAGUENESS: "Vagueness",
            ProblemClass.INCONSISTENT_DEF: "Inconsistent Definition",
            ProblemClass.TEMPORAL_DECISION: "Temporal Decision",
            ProblemClass.DEONTIC: "Deontic Conflict",
            ProblemClass.EPISTEMIC: "Epistemic Gap",
            ProblemClass.QUANTUM_SUPERPOSITION: "Quantum Superposition",
            ProblemClass.CONSTRUCTIVE: "Constructive",
            ProblemClass.RELEVANCE: "Relevance",
            ProblemClass.EMPTY_REFERENCE: "Empty Reference",
            ProblemClass.INFINITY: "Infinity",
            ProblemClass.MODALITY: "Modality",
            ProblemClass.META_PARADOX: "Meta-Paradox",
        }
        return names[self]


@dataclass(frozen=True)
class Problem:
    """A logical puzzle encoded as a family of trees.
    Mirror of: structure Problem where
      cls            : ProblemClass
      name           : String
      suitableLogics : List LogicType
      tree           : LogicType → EMLTree
      normalForm     : LogicType → EMLTree
    """
    cls: ProblemClass
    name: str
    suitable_logics: List[LogicType]
    _tree_fn: Callable[[LogicType], EMLTree]
    _nf_fn: Callable[[LogicType], EMLTree]

    def tree(self, lt: LogicType) -> EMLTree:
        return self._tree_fn(lt)

    def normal_form(self, lt: LogicType) -> EMLTree:
        return self._nf_fn(lt)


@dataclass(frozen=True)
class WrappedProblem:
    """A problem paired with a logic type (the WfCA collapse).
    Mirror of: structure WrappedProblem (p : Problem) (lt : LogicType)
    """
    problem: Problem
    logic: LogicType
    tree: EMLTree
    target: EMLTree
    cost: int  # pentagonator distance / cdStep

    def verify(self) -> bool:
        """Check that the tree contracts to target under this logic."""
        return logic_contraction(self.logic, self.tree, self.target)


@dataclass(frozen=True)
class Tower:
    """A sequence of logic-wrapped problems, each collapsing the output
    of the previous.
    Mirror of: structure Tower (p : Problem) where
      layers : List (Σ lt, WrappedProblem p lt)
    """
    problem: Problem
    layers: List[WrappedProblem]

    def total_cost(self) -> int:
        """Sum of costs across all layers.
        Mirror of: frictionLagrangian
        """
        return sum(wp.cost for wp in self.layers)


# ── Canonical paradoxes ──────────────────────────────────────────────

def _symmetric_tree() -> EMLTree:
    """Node(Node Leaf Leaf)(Node Leaf Leaf). Size 3."""
    return EMLTree.node(EMLTree.node(LEAF, LEAF), EMLTree.node(LEAF, LEAF))


def _left_comb2() -> EMLTree:
    """Node(Node Leaf Leaf) Leaf. Size 2."""
    return EMLTree.node(EMLTree.node(LEAF, LEAF), LEAF)


LIAR_PROBLEM = Problem(
    cls=ProblemClass.SELF_REFERENCE,
    name="Liar",
    suitable_logics=[
        LogicType.MANY_VALUED,
        LogicType.PARACONSISTENT,
        LogicType.INTUITIONISTIC,
        LogicType.FUZZY,
        LogicType.TEMPORAL,
        LogicType.EPISTEMIC,
        LogicType.QUANTUM,
        LogicType.RELEVANCE,
        LogicType.FREE,
        LogicType.INFINITARY,
        LogicType.MODAL,
        LogicType.CLASSICAL,
    ],
    _tree_fn=lambda lt: _left_comb2() if lt == LogicType.MANY_VALUED else _symmetric_tree(),
    _nf_fn=lambda lt: rightComb(2) if lt == LogicType.MANY_VALUED else rightComb(3),
)


def liar_wrapper(lt: LogicType) -> WrappedProblem:
    """Wrap the Liar for a specific logic type. Cost = cdStep(lt).
    Mirror of: liarWrapper
    """
    return WrappedProblem(
        problem=LIAR_PROBLEM,
        logic=lt,
        tree=LIAR_PROBLEM.tree(lt),
        target=LIAR_PROBLEM.normal_form(lt),
        cost=lt.cd_step(),
    )


def liar_tower() -> Tower:
    """Full Liar tower: one layer per suitable logic.
    Mirror of: liarTower
    """
    return Tower(
        problem=LIAR_PROBLEM,
        layers=[liar_wrapper(lt) for lt in LIAR_PROBLEM.suitable_logics],
    )


def friction_lagrangian() -> int:
    """Total cost across the full Liar tower.
    Mirror of: frictionLagrangian
    """
    return liar_tower().total_cost()
