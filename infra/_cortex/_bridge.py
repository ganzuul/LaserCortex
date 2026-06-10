"""
NormCode ↔ LaserCortex Bridge.

This module connects NC's orchestration runtime to the LC formal layer.
It defines the bidirectional interface:

  NC → LC (Lift)  : serialize NC inferences, plans, traces → LC types
  LC → NC (Ground): pull normal forms, contraction paths, certificates → NC

GAPS are documented inline with `GAP:` markers — places where NC doesn't
yet produce the data LC needs. These are the gaps this staging phase
is designed to surface.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from ._eml_tree import (
    EMLTree, LEAF, rightComb, contracts_one, contracts_to,
    contracts_one_successors, decidable_contracts_to,
    tree_from_flow_index,
)
from ._types import (
    RouterIndex, RouterIndexError, TypeRegistry,
    CortexCertificate, certify,
    flow_to_index,
)
from ._logic_types import (
    LogicType, Gate, LogicPipeline,
    logic_contraction, logic_normal_form,
    CLOSURE_PIPELINE, FULL_PIPELINE,
)
from ._logic_monad import LogicM, LogicMonad
from ._decision import Decision, decide
from ._paradox import (
    ProblemClass, Problem, WrappedProblem, Tower,
    LIAR_PROBLEM, liar_wrapper,
)
from ._decomposition import (
    Path, Decomposition, Chain,
    reverse_one, ancestors_up_to, view_dfs,
)
from ._closure import (
    Event, Norm, BlamePool,
    closure as run_closure,
    HISTORY_TREE,
)


class CortexBridgeError(Exception):
    """Base error for bridge operations."""


@dataclass
class LiftResult:
    """Result of lifting an NC inference to the LC layer."""
    router_index: RouterIndex
    eml_tree: EMLTree
    certificate: CortexCertificate
    logic_type: LogicType
    gate_results: Dict[str, bool]


@dataclass
class GroundResult:
    """Result of grounding an LC certificate back into NC."""
    certificate: CortexCertificate
    decompositions: List[Decomposition]
    decision: Decision


class CortexBridge:
    """Core bridge: pure data transformations between NC and LC.

    This is the stateless translation layer. Stateful orchestration
    (which inference maps to which router index) is handled by
    NormCodeCortexBridge.

    GAP markers identify where the NC side is missing data that the
    LC side requires.
    """

    # ── NC → LC (Lift) ─────────────────────────────────────────────

    def flow_index_to_tree(self, flow_index: str) -> EMLTree:
        """Convert an NC flow index like '1.2.3' to an EMLTree.

        GAP: This is a heuristic. NC's flow index hierarchy doesn't
        yet have a formal mapping to EMLTree shapes. The correct
        mapping depends on the inference's dependency structure,
        not just its position in the flow index space.
        """
        parts = [int(p) for p in flow_index.split(".")]
        return tree_from_flow_index(parts)

    def lift_inference(
        self,
        flow_index: str,
        concept_name: str,
        sequence_type: str,
        coupling_signature: Optional[str] = None,
        concept: Any = None,
    ) -> LiftResult:
        """Convert an NC inference execution to LC types.

        Args:
            flow_index: NC flow index (e.g. '1.2.3')
            concept_name: The concept being inferred
            sequence_type: NC inference sequence type
            coupling_signature: Optional coupling signature from Concept
            concept: Optional Concept object (used for LogicType resolution)
        """
        tree = self.flow_index_to_tree(flow_index)

        # Determine LogicType: prefer Concept.to_logic_type(), fall back to coupling
        if concept is not None:
            logic_type = self.infer_logic_type(concept)
        else:
            logic_type = self._coupling_to_logic_type(coupling_signature)

        # Generate router index
        flat_idx = flow_to_index(flow_index)
        bound = max(flat_idx + 1, 1024)
        try:
            router_idx = RouterIndex(flat_idx, bound)
        except RouterIndexError:
            # GAP: Need dynamic bound management from NC
            router_idx = RouterIndex(flat_idx % 1024, 1024)

        # Generate certificate
        cert = certify(tree)

        # Run logic pipeline gates
        gate_results: Dict[str, bool] = {}
        for gate in CLOSURE_PIPELINE.gates():
            gate_results[gate.name] = gate.check(tree)

        return LiftResult(
            router_index=router_idx,
            eml_tree=tree,
            certificate=cert,
            logic_type=logic_type,
            gate_results=gate_results,
        )

    def _coupling_to_logic_type(self, sig: Optional[str]) -> LogicType:
        """Map NC coupling signature to LC LogicType.

        GAP: This is a placeholder mapping. The actual connection
        between NC's COUPLING_SIGNATURES and LC's LogicTypes is
        not yet formalized.
        """
        mapping = {
            "commutative": LogicType.CLASSICAL,
            "non-commutative": LogicType.TEMPORAL,
            "non-associative": LogicType.QUANTUM,
            "commutative-associative": LogicType.CLASSICAL,
        }
        if sig:
            return mapping.get(sig, LogicType.CLASSICAL)
        return LogicType.CLASSICAL

    def infer_logic_type(self, concept: Any) -> LogicType:
        """Determine which LogicType applies.

        Uses Concept.to_logic_type() if available, then
        falls back to coupling-signature heuristic.
        """
        if hasattr(concept, 'to_logic_type'):
            return concept.to_logic_type()
        form_type = getattr(concept, 'form_type', None)
        coupling = getattr(concept, 'coupling_signature', None)
        return self._coupling_to_logic_type(coupling)

    def lift_plan_to_logic_m(self, flow_indices: List[str]) -> LogicM[str]:
        """Convert a list of flow indices to a LogicM tree.

        GAP: NC's plan graph (Waitlist) has a dependency structure
        that should map to LogicM node structure. Currently we just
        build a right-nested tree from the flow index list. A proper
        mapping would use the actual dependency DAG.
        """
        if not flow_indices:
            return LogicM.pure("empty_plan")
        if len(flow_indices) == 1:
            return LogicM.pure(flow_indices[0])
        # Build a right-nested tree
        current = LogicM.pure(flow_indices[-1])
        for idx in reversed(flow_indices[:-1]):
            current = LogicM.node(LogicM.pure(idx), current)
        return current

    def detect_paradox(
        self,
        tree: EMLTree,
        logic_type: LogicType,
        failure_context: Optional[str] = None,
    ) -> Optional[WrappedProblem]:
        """Check if a tree represents a paradox.

        GAP: NC doesn't yet classify inference failures as paradoxes.
        This is a placeholder that only checks the Liar pattern.
        """
        nf = logic_normal_form(logic_type, tree.size())
        if not decidable_contracts_to(tree, nf):
            return liar_wrapper(logic_type)
        return None

    # ── LC → NC (Ground) ───────────────────────────────────────────

    def ground_certificate(self, cert: CortexCertificate) -> GroundResult:
        """Convert an LC certificate into NC-usable data.

        GAP: NC doesn't yet consume certificates. The certificate
        should be stored as part of the run metadata and accessible
        via the checkpoint system.
        """
        # Generate decompositions (ancestor trees)
        decomps: List[Decomposition] = []
        for ancestor in ancestors_up_to(cert.target, depth=3):
            if decidable_contracts_to(ancestor, cert.target):
                decomps.append(Decomposition(source=ancestor, target=cert.target))

        # Run the decision pipeline
        decision = decide(cert.source)

        return GroundResult(
            certificate=cert,
            decompositions=decomps,
            decision=decision,
        )

    def decompose_decision(
        self,
        tree: EMLTree,
        depth: int = 5,
        max_results: int = 10,
    ) -> List[Decomposition]:
        """Generate counterfactual ancestors for a decision tree.

        GAP: NC doesn't yet consume decompositions. These should
        be displayed in the UI as alternative reasoning paths.
        """
        result: List[Decomposition] = []
        for ancestor in ancestors_up_to(tree, depth):
            if len(result) >= max_results:
                break
            if decidable_contracts_to(ancestor, tree):
                result.append(Decomposition(source=ancestor, target=tree))
        return result


class NormCodeCortexBridge:
    """Stateful bridge connecting a running NC Orchestrator to LC.

    Manages:
    - TypeRegistry (binding flow indices → EMLTrees)
    - Certificate store (run_id → CortexCertificate)
    - LogicPipeline results per inference

    GAP: This class assumes NC will provide hooks at the right points
    in the orchestration lifecycle. Those hooks don't exist yet.
    """

    def __init__(self, registry_bound: int = 1024):
        self.core = CortexBridge()
        self.registry = TypeRegistry(bound=registry_bound)
        self._certificates: Dict[str, CortexCertificate] = {}
        self._lift_cache: Dict[str, LiftResult] = {}

    # ── Orchestration hooks (GAP: not yet wired into NC) ───────────

    def on_inference_complete(
        self,
        flow_index: str,
        concept: Any,
        sequence_type: str,
        run_id: str,
    ) -> LiftResult:
        """Called when an NC inference completes.

        GAP: Must be called from infra/_core/_inference.py execute()
        or infra/_orchest/_orchestrator.py _process_inference_state().
        These calls don't exist yet.
        """
        sig = None
        if hasattr(concept, 'coupling_signature'):
            sig = concept.coupling_signature

        result = self.core.lift_inference(
            flow_index=flow_index,
            concept_name=getattr(concept, 'name', 'unknown'),
            sequence_type=sequence_type,
            coupling_signature=sig,
            concept=concept,
        )

        # Register in TypeRegistry
        try:
            self.registry.register(result.router_index, result.eml_tree)
        except ValueError:
            pass  # Tree already registered

        # Cache the result
        key = f"{run_id}:{flow_index}"
        self._lift_cache[key] = result

        return result

    def on_plan_complete(self, run_id: str) -> Optional[CortexCertificate]:
        """Called when an NC plan execution completes.

        GAP: Must be called from Orchestrator after all cycles complete.
        The certificate should incorporate ALL inference trees from the run.
        """
        # Collect all trees lifted during this run
        trees = [
            v.eml_tree
            for k, v in self._lift_cache.items()
            if k.startswith(f"{run_id}:")
        ]
        if not trees:
            return None

        # Build a composite tree
        composite = LEAF
        for t in trees:
            composite = EMLTree.node(composite, t)

        cert = certify(composite)
        self._certificates[run_id] = cert
        return cert

    def on_checkpoint(self, run_id: str, cycle: int) -> Optional[CortexCertificate]:
        """Called at checkpoint time.

        GAP: Must be called from Orchestrator._run_cycle() or via
        CheckpointManager. The certificate at checkpoint serves as
        a verifiable snapshot of partial progress.
        """
        return self.on_plan_complete(f"{run_id}:checkpoint:{cycle}")

    def get_certificate(self, run_id: str) -> Optional[CortexCertificate]:
        """Retrieve a stored certificate."""
        return self._certificates.get(run_id)

    def get_registry_state(self) -> List[Tuple[RouterIndex, EMLTree]]:
        """Get all TypeRegistry bindings."""
        return self.registry.all_bindings()

    # ── Paradox detection ─────────────────────────────────────────

    def classify_failure(
        self,
        flow_index: str,
        error: Exception,
        run_id: str,
    ) -> Optional[WrappedProblem]:
        """Classify an NC inference failure as a paradox.

        GAP: Called when an inference fails. NC doesn't currently
        route failures through paradox classification.
        """
        lift = self._lift_cache.get(f"{run_id}:{flow_index}")
        if lift is None:
            return None
        return self.core.detect_paradox(
            tree=lift.eml_tree,
            logic_type=lift.logic_type,
            failure_context=str(error),
        )

    # ── Decomposition (counterfactuals) ──────────────────────────

    def decompose_decision(
        self,
        flow_index: str,
        run_id: str,
        depth: int = 5,
    ) -> List[Decomposition]:
        """Get counterfactual ancestors for a lifted inference."""
        lift = self._lift_cache.get(f"{run_id}:{flow_index}")
        if lift is None:
            return []
        return self.core.decompose_decision(lift.eml_tree, depth)

    # ── Institutional closure ────────────────────────────────────

    def run_closure_pipeline(
        self,
        flow_indices: List[str],
        events: Optional[List[Event]] = None,
    ) -> LogicM[Norm]:
        """Run institutional closure on a set of NC flow indices.

        GAP: NC doesn't have an Event model that maps to LC's Event
        structure. The closure pipeline needs NC to provide structured
        event data (timestamps, impact scores, etc.)
        """
        if events is None:
            events = self._flow_indices_to_events(flow_indices)
        tree = self.core.lift_plan_to_logic_m(flow_indices)
        # Would convert events to LogicM[Event] and run closure
        return LogicM.pure(Norm(rule="closure_complete", threshold=0))

    def _flow_indices_to_events(self, flow_indices: List[str]) -> List[Event]:
        """GAP: No event source from NC yet.
        Currently returns placeholder events.
        """
        return [
            Event(year=i, description=idx, impact=1)
            for i, idx in enumerate(flow_indices)
        ]
