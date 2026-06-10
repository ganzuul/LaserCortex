"""
Cortex Bridge — Python mirror of LaserCortex (Lean 4) types.

This package provides a pure-Python representation of the LaserCortex
formal logic framework, enabling NormCode to produce LC-compatible data
structures (EMLTrees, certificates, logic pipelines, paradox wrappers)
and prepare them for verification by the Lean runtime.

Package structure mirrors the Lean source files:

  _eml_tree.py       ← EMLRegistry.lean     (EMLTree, contracts_to, rightComb)
  _types.py           ← EMLRegistry.lean     (RouterIndex, TypeRegistry, CortexCertificate)
  _logic_types.py     ← LogicTypes.lean      (LogicType, Gate, LogicPipeline)
                       + DecisionComposition.lean
  _logic_monad.py     ← LogicMonad.lean      (LogicM, LogicMonad)
  _decision.py        ← DecisionComposition.lean (Decision, decide)
  _paradox.py         ← LiarParadox.lean     (Problem, WrappedProblem, Tower)
  _decomposition.py   ← Decomposition.lean   (Path, reverse_one, ancestorsUpTo)
  _closure.py         ← InstitutionalClosure.lean (Event, Norm, closure pipeline)
  _boundlessness.py   ← Boundlessness.lean   (IdempotentResolution, VeryBigBox)
  _bridge.py          ← NormCodeCortexBridge (wires everything, identifies gaps)
"""

from ._eml_tree import (
    EMLTree,
    LEAF,
    rightComb,
    leftComb,
    contracts_one,
    contracts_to,
    contracts_one_successors,
    decidable_contracts_to,
    tree_from_flow_index,
)
from ._types import (
    RouterIndex,
    RouterIndexError,
    TypeRegistry,
    CortexCertificate,
    certify,
    flow_to_index,
    _index_to_flow,
)
from ._logic_types import (
    LogicType,
    Gate,
    LogicPipeline,
    LogicTranslation,
    logic_contraction,
    logic_normal_form,
    logic_contracts_to_normal_form,
    CLOSURE_PIPELINE,
    FULL_PIPELINE,
    run_closure_pipeline,
)
from ._logic_monad import (
    LogicM,
    LogicMonad,
)
from ._decision import (
    Decision,
    decide,
)
from ._paradox import (
    ProblemClass,
    Problem,
    WrappedProblem,
    Tower,
    LIAR_PROBLEM,
    liar_wrapper,
    liar_tower,
    friction_lagrangian,
)
from ._decomposition import (
    Path,
    Decomposition,
    Chain,
    reverse_one,
    reverse_one_sound,
    ancestors_up_to,
    view_dfs,
)
from ._closure import (
    Event,
    Norm,
    BlamePool,
    temporal_normalize,
    fuzzy_grade,
    deontic_update,
    self_recognize,
    closure,
    closure_is_fixed_point,
    normalization_idempotent,
    HISTORY_TREE,
)
from ._boundlessness import (
    IdempotentResolution,
    VeryBigBox,
    RIGHT_COMB_RESOLUTION,
    VERY_BIG_BOX,
)
from ._bridge import (
    CortexBridge,
    NormCodeCortexBridge,
    CortexBridgeError,
    LiftResult,
    GroundResult,
)
from ._spec import (
    CortexSpec,
    SpecRegistry,
    MagnitudeContract,
    SpecValidation,
    SpecExample,
    SpecProvenance,
    SEED_REGISTRY,
    SORITES_SPEC,
    LOCKED_ROOM_SPEC,
    BLUE_EYED_SPEC,
    TALLNESS_SPEC,
    POISONED_CUP_SPEC,
    HEAP_FUZZY_SPEC,
    CONFLICTING_ALIBIS_SPEC,
    BARBER_SPEC,
    MONTY_HALL_SPEC,
    CONFESSIONAL_SPEC,
)
from ._qc_adapter import (
    QCSignalAdapter,
    SignalConfig,
    SignalEvent,
    BacktestResult,
)

__all__ = [
    # Core tree types
    "EMLTree",
    "LEAF",
    "rightComb",
    "leftComb",
    "contracts_one",
    "contracts_to",
    "contracts_one_successors",
    "decidable_contracts_to",
    "tree_from_flow_index",

    # Registry / binding
    "RouterIndex",
    "RouterIndexError",
    "TypeRegistry",
    "CortexCertificate",
    "certify",
    "flow_to_index",

    # Logic types
    "LogicType",
    "Gate",
    "LogicPipeline",
    "LogicTranslation",
    "logic_contraction",
    "logic_normal_form",
    "logic_contracts_to_normal_form",
    "CLOSURE_PIPELINE",
    "FULL_PIPELINE",
    "run_closure_pipeline",

    # Monad
    "LogicM",
    "LogicMonad",

    # Decision
    "Decision",
    "decide",

    # Paradox
    "ProblemClass",
    "Problem",
    "WrappedProblem",
    "Tower",
    "LIAR_PROBLEM",
    "liar_wrapper",
    "liar_tower",
    "friction_lagrangian",

    # Decomposition
    "Path",
    "Decomposition",
    "Chain",
    "reverse_one",
    "reverse_one_sound",
    "ancestors_up_to",
    "view_dfs",

    # Closure
    "Event",
    "Norm",
    "BlamePool",
    "temporal_normalize",
    "fuzzy_grade",
    "deontic_update",
    "self_recognize",
    "closure",
    "closure_is_fixed_point",
    "normalization_idempotent",
    "HISTORY_TREE",

    # Boundlessness
    "IdempotentResolution",
    "VeryBigBox",
    "RIGHT_COMB_RESOLUTION",
    "VERY_BIG_BOX",

    # Bridge
    "CortexBridge",
    "NormCodeCortexBridge",
    "CortexBridgeError",
    "LiftResult",
    "GroundResult",

    # Specs
    "CortexSpec",
    "SpecRegistry",
    "MagnitudeContract",
    "SpecValidation",
    "SpecExample",
    "SpecProvenance",
    "SEED_REGISTRY",
    "SORITES_SPEC",
    "LOCKED_ROOM_SPEC",
    "BLUE_EYED_SPEC",
    "TALLNESS_SPEC",
    "POISONED_CUP_SPEC",
    "HEAP_FUZZY_SPEC",
    "CONFLICTING_ALIBIS_SPEC",
    "BARBER_SPEC",
    "MONTY_HALL_SPEC",
    "CONFESSIONAL_SPEC",
]
