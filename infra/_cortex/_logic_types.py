"""
Pluralistic logic type system — Python mirror of LogicTypes.lean
and DecisionComposition.lean (Gate / LogicPipeline).

Mirrors:
  inductive LogicType where
    | Fuzzy | ManyValued | Paraconsistent | Temporal | Deontic
    | Epistemic | Quantum | Intuitionistic | Relevance | Free
    | Infinitary | Modal | Classical

  def LogicContraction : LogicType → EMLTree → EMLTree → Prop
  def LogicNormalForm  : LogicType → Nat → EMLTree
  structure Gate where ...
  structure LogicPipeline where ...
"""

from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Callable, Dict, List, Optional, Set, Tuple

from ._eml_tree import EMLTree, rightComb, contracts_to


# ── LogicType (13-valued enum) ───────────────────────────────────────

class LogicType(Enum):
    """The 14 logic types forming the pluralistic logic framework.
    Mirror of LogicTypes.lean: inductive LogicType.
    """
    FUZZY = "fuzzy"
    MANY_VALUED = "many_valued"
    PARACONSISTENT = "paraconsistent"
    TEMPORAL = "temporal"
    DEONTIC = "deontic"
    EPISTEMIC = "epistemic"
    QUANTUM = "quantum"
    INTUITIONISTIC = "intuitionistic"
    RELEVANCE = "relevance"
    FREE = "free"
    INFINITARY = "infinitary"
    MODAL = "modal"
    SPACETIME = "spacetime"
    CLASSICAL = "classical"

    def display_name(self) -> str:
        """Mirror of LogicType.name."""
        names = {
            LogicType.FUZZY: "Fuzzy Logic",
            LogicType.MANY_VALUED: "Many-Valued Logic",
            LogicType.PARACONSISTENT: "Paraconsistent Logic",
            LogicType.TEMPORAL: "Temporal Logic",
            LogicType.DEONTIC: "Deontic Logic",
            LogicType.EPISTEMIC: "Epistemic Logic",
            LogicType.QUANTUM: "Quantum Logic",
            LogicType.INTUITIONISTIC: "Intuitionistic Logic",
            LogicType.RELEVANCE: "Relevance Logic",
            LogicType.FREE: "Free Logic",
            LogicType.INFINITARY: "Infinitary Logic",
            LogicType.MODAL: "Modal Logic",
            LogicType.CLASSICAL: "Classical Logic",
            LogicType.SPACETIME: "Spacetime Logic",
        }
        return names[self]

    def dimension_index(self) -> int:
        """Mirror of LogicType.dimensionIndex."""
        indices = {
            LogicType.FUZZY: 1,
            LogicType.MANY_VALUED: 2,
            LogicType.PARACONSISTENT: 3,
            LogicType.TEMPORAL: 4,
            LogicType.DEONTIC: 5,
            LogicType.EPISTEMIC: 6,
            LogicType.QUANTUM: 7,
            LogicType.INTUITIONISTIC: 8,
            LogicType.RELEVANCE: 9,
            LogicType.FREE: 10,
            LogicType.INFINITARY: 11,
            LogicType.MODAL: 12,
            LogicType.CLASSICAL: 13,
            LogicType.SPACETIME: 14,
        }
        return indices[self]

    def cd_step(self) -> int:
        """Cayley-Dickson step index. Mirror of LogicType.cdStep.
        Only Classical, Fuzzy, Intuitionistic, Quantum, Paraconsistent
        have non-zero CD steps.
        """
        steps = {
            LogicType.CLASSICAL: 0,
            LogicType.FUZZY: 1,
            LogicType.INTUITIONISTIC: 2,
            LogicType.QUANTUM: 3,
            LogicType.PARACONSISTENT: 4,
        }
        return steps.get(self, 0)

    def is_associative_sector(self) -> bool:
        """Mirror of LogicType.isAssociativeSector.
        Split-octonion (4,4) signature division.
        """
        return self in {
            LogicType.CLASSICAL,
            LogicType.FUZZY,
            LogicType.MANY_VALUED,
            LogicType.TEMPORAL,
            LogicType.DEONTIC,
            LogicType.EPISTEMIC,
            LogicType.SPACETIME,
        }


# ── LogicContraction ─────────────────────────────────────────────────

def logic_contraction(lt: LogicType, s: EMLTree, t: EMLTree) -> bool:
    """Contraction relation for a specific logic type.
    Mirror of: def LogicContraction : LogicType → EMLTree → EMLTree → Prop

    Currently all logics use Tamari contraction (contracts_to).
    Future: logic-specific contraction relations.
    """
    return contracts_to(s, t)


def logic_normal_form(lt: LogicType, n: int) -> EMLTree:
    """Normal form for a logic type.
    Mirror of: def LogicNormalForm : LogicType → Nat → EMLTree

    All logics currently use rightComb as normal form.
    """
    return rightComb(n)


def logic_contracts_to_normal_form(lt: LogicType, t: EMLTree) -> bool:
    """Check if a tree contracts to its normal form under a logic.
    Mirror of: theorem logic_contracts_to_normal_form
    """
    nf = logic_normal_form(lt, t.size())
    return logic_contraction(lt, t, nf)


# ── LogicTranslation ─────────────────────────────────────────────────

@dataclass
class LogicTranslation:
    """Formal translation between two logic types.
    Mirror of: structure LogicTranslation (lt1 lt2 : LogicType) ...
    """
    source_logic: LogicType
    target_logic: LogicType
    forward: Callable[[EMLTree], EMLTree]
    backward: Callable[[EMLTree], EMLTree]

    def check_soundness(self, tree: EMLTree) -> bool:
        """Forward translation preserves structure."""
        return logic_contraction(
            self.source_logic, tree, self.forward(tree)
        )

    def check_completeness(self, tree: EMLTree) -> bool:
        """Backward translation preserves structure."""
        return logic_contraction(
            self.target_logic, self.backward(tree), tree
        )


# ── Gate & LogicPipeline (from DecisionComposition.lean) ─────────────

@dataclass(frozen=True)
class Gate:
    """A binary decision function indexed by logic modality.
    Mirror of: structure Gate where
      name     : String
      modality : LogicType
      check    : EMLTree → Prop
    """
    name: str
    modality: LogicType

    def check(self, tree: EMLTree) -> bool:
        """Check that tree contracts to normal form under this logic.
        Mirror of: Gate.check = λ tree => LogicContraction lt tree (LogicNormalForm lt tree.size)
        """
        return logic_contracts_to_normal_form(self.modality, tree)

    @staticmethod
    def of_logic_type(lt: LogicType) -> 'Gate':
        """Construct the Gate for a logic type.
        Mirror of: Gate.ofLogicType
        """
        return Gate(name=lt.display_name(), modality=lt)


@dataclass(frozen=True)
class LogicPipeline:
    """A pipeline over a list of logic types.
    Mirror of: structure LogicPipeline where
      logics : List LogicType
      name   : String
    """
    logics: List[LogicType]
    name: str

    def gates(self) -> List[Gate]:
        """Derive the gates for this pipeline.
        Mirror of: LogicPipeline.gates
        """
        return [Gate.of_logic_type(lt) for lt in self.logics]

    def run(self, tree: EMLTree) -> 'Decision':
        """Run all gates on a tree, producing a Decision.
        Mirror of: LogicPipeline.run
        """
        from ._decision import Decision
        gates_seq = self.gates()
        proofs = {}
        for g in gates_seq:
            proofs[g.name] = g.check(tree)
        return Decision(datum=tree, gates=gates_seq, proofs=proofs)


# ── Predefined pipelines ─────────────────────────────────────────────

CLOSURE_PIPELINE = LogicPipeline(
    logics=[LogicType.TEMPORAL, LogicType.FUZZY, LogicType.DEONTIC],
    name="institutional_closure",
)

FULL_PIPELINE = LogicPipeline(
    logics=[
        LogicType.TEMPORAL,
        LogicType.FUZZY,
        LogicType.DEONTIC,
        LogicType.EPISTEMIC,
        LogicType.CLASSICAL,
    ],
    name="full_governance",
)


def run_closure_pipeline(tree: EMLTree) -> 'Decision':
    """Run the institutional closure pipeline.
    Mirror of: DecisionComposition.decide
    """
    return CLOSURE_PIPELINE.run(tree)
