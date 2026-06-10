"""
Decision composition — Python mirror of DecisionComposition.lean.

Mirrors:
  structure Gate where ...
  structure Decision (gates : List Gate) where
    datum : EMLTree
    proof : ∀ (g : Gate), g ∈ gates → g.check datum
  def LogicPipeline.run : (p : LogicPipeline) (tree : EMLTree) → Decision
  def decide : LogicM Event → Decision
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional

from ._eml_tree import EMLTree
from ._logic_types import LogicType, Gate, LogicPipeline, CLOSURE_PIPELINE


@dataclass(frozen=True)
class Decision:
    """A datum with a proof that it passes a list of gates.
    Mirror of: structure Decision (gates : List Gate) where
      datum : EMLTree
      proof : ∀ (g : Gate), g ∈ gates → g.check datum

    In Python, 'proof' is a Dict[gate_name, bool] tracking which gates passed.
    """
    datum: EMLTree
    gates: List[Gate] = field(default_factory=list)
    proofs: Dict[str, bool] = field(default_factory=dict)

    def all_passed(self) -> bool:
        """Check if all gates pass."""
        return all(self.proofs.get(g.name, False) for g in self.gates)

    def compose(self, gate: Gate) -> 'Decision':
        """Augment a decision with an additional gate.
        Mirror of: Decision.compose
        """
        h = gate.check(self.datum)
        new_gates = [gate] + list(self.gates)
        new_proofs = dict(self.proofs)
        new_proofs[gate.name] = h
        return Decision(datum=self.datum, gates=new_gates, proofs=new_proofs)

    def compose_of(self, lt: LogicType) -> 'Decision':
        """Augment with the gate of a logic type.
        Mirror of: Decision.composeOf
        """
        return self.compose(Gate.of_logic_type(lt))

    @staticmethod
    def empty(tree: EMLTree) -> 'Decision':
        """Empty decision (no gates).
        Mirror of: Decision.empty
        """
        return Decision(datum=tree)

    @staticmethod
    def singleton(tree: EMLTree, gate: Gate, passes: bool) -> 'Decision':
        """Decision with a single gate.
        Mirror of: Decision.singleton
        """
        return Decision(
            datum=tree,
            gates=[gate],
            proofs={gate.name: passes},
        )

    @staticmethod
    def singleton_of(tree: EMLTree, lt: LogicType) -> 'Decision':
        """Decision with the gate of a logic type.
        Mirror of: Decision.singletonOf
        """
        g = Gate.of_logic_type(lt)
        return Decision.singleton(tree, g, g.check(tree))


def decide(tree: EMLTree) -> Decision:
    """Run the full institutional closure pipeline.
    Mirror of: DecisionComposition.decide (events : LogicM Event) → Decision
    """
    return CLOSURE_PIPELINE.run(tree)
