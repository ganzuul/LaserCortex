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
    EMLTree, LEAF, rightComb, balanced_tree, contracts_one, contracts_to,
    contracts_one_successors, decidable_contracts_to,
    tree_from_flow_index, tree_from_inference_entry,
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
from ._spec import CortexSpec, SpecRegistry, SEED_REGISTRY


class CortexBridgeError(Exception):
    """Base error for bridge operations."""


class _MinimalConcept:
    """Minimal Concept-like object for bridge operations.

    Used when a full Concept is not available (e.g., when lifting a
    reasoning trace that doesn't come from the NC orchestrator).
    """
    def __init__(self, name: str = "unknown", coupling_signature: Optional[str] = None,
                 form_type: Optional[str] = None, context: str = ""):
        self.name = name
        self.coupling_signature = coupling_signature
        self.form_type = form_type
        self.context = context


@dataclass
class LiftResult:
    """Result of lifting an NC inference to the LC layer."""
    router_index: RouterIndex
    eml_tree: EMLTree
    certificate: CortexCertificate
    logic_type: LogicType
    gate_results: Dict[str, bool]
    spec_name: Optional[str] = None  # statute citation
    zd_witness: Optional[ZDWitness] = None  # zero-divisor witness if detected
    structural_logic: Optional[LogicType] = None  # independently resolved LogicType
    structural_source: Optional[str] = None  # how structural LogicType was determined


@dataclass
class GroundResult:
    """Result of grounding an LC certificate back into NC."""
    certificate: CortexCertificate
    decompositions: List[Decomposition]
    decision: Decision


@dataclass
class ZDWitness:
    """Formal witness for a zero-divisor rejection.

    When incompatible LogicTypes are put in partial order (one in the
    associative regime CD ≤ 2, the other in the non-associative regime
    CD ≥ 3), the associator defect activates and the friction barrier
    (strut_weight² = 16) makes contraction impossible.

    The Lean theorem ``friction_barrier_across_cd23`` is the proof term:
    Γ_k₂ - Γ_k₁ ≥ strut_weight² when k₁ ≤ 2 and k₂ ≥ 3.
    """
    claimed_logic: LogicType
    structural_logic: LogicType
    claimed_cdstep: int
    structural_cdstep: int
    boundary: str = "CD_2_to_3"
    strut_weight_sq: int = 16
    friction_ratio: float = 9.5
    barrier_theorem: str = "FrictionLagrangian.friction_barrier_across_cd23"
    resolution_source: str = ""  # how the structural LogicType was determined

    def format_reason(self) -> str:
        return (
            f"Zero divisor at {self.boundary} boundary. "
            f"Claimed logic: {self.claimed_logic.display_name()} "
            f"(CD {self.claimed_cdstep}), but structural resolution gives "
            f"{self.structural_logic.display_name()} "
            f"(CD {self.structural_cdstep}). "
            f"Friction barrier strut_weight² = {self.strut_weight_sq} "
            f"(ratio {self.friction_ratio}). "
            f"Proof: {self.barrier_theorem}. "
            f"Source: {self.resolution_source}."
        )


class CortexBridge:
    """Core bridge: pure data transformations between NC and LC.

    This is the stateless translation layer. Stateful orchestration
    (which inference maps to which router index) is handled by
    NormCodeCortexBridge.

    GAP markers identify where the NC side is missing data that the
    LC side requires.
    """

    def resolve_spec(
        self,
        concept: Any,
        registry: SpecRegistry = SEED_REGISTRY,
    ) -> Optional[CortexSpec]:
        """Find a CortexSpec matching *concept* and pre-populate its
        typed-form fields.

        Intended to be called *before* ``Inference.__init__`` runs its
        ``validate_typed_form`` loop (the existing TVK).  After this call
        the concept carries the spec's form_type, coupling_signature,
        schema version, and a form_payload seeded from
        ``spec.default_payload`` so that the TVK can validate it.

        If no spec matches, the concept is left untouched and the caller
        should fall back to the existing heuristic path.
        """
        spec = registry.best_match(concept)
        if spec is not None:
            spec.pre_populate(concept)
        return spec

    def pre_populate_repo(
        self,
        concept_repo: Any,
        registry: SpecRegistry = SEED_REGISTRY,
    ) -> int:
        """Pre-populate all concepts in *concept_repo* from the spec registry.

        Iterates every concept in the repo, finds its best spec match, and
        calls ``pre_populate`` on each.  Returns the count of concepts that
        were matched.
        """
        count = 0
        for entry in concept_repo.get_all_concepts():
            if entry.concept is not None:
                spec = self.resolve_spec(entry.concept, registry)
                if spec is not None:
                    count += 1
        return count

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
        spec: Optional[CortexSpec] = None,
        eml_tree: Optional[EMLTree] = None,
        trace_data: Optional[Dict[str, str]] = None,
    ) -> LiftResult:
        """Convert an NC inference execution to LC types.

        Args:
            flow_index: NC flow index (e.g. '1.2.3')
            concept_name: The concept being inferred
            sequence_type: NC inference sequence type
            coupling_signature: Optional coupling signature from Concept
            concept: Optional Concept object (used for LogicType resolution)
            spec: Optional CortexSpec — the statute authorising this inference.
                  If provided, its ``coupling_signature`` and ``form_type``
                  take precedence over heuristics.
            eml_tree: Optional explicit EMLTree to use. When provided,
                  overrides the heuristic ``flow_index_to_tree`` mapping.
                  This is the formal path — use ``tree_from_inference_entry``
                  to build a tree from the actual dependency structure.
            trace_data: Optional dict with structural properties of the trace
                  (source_content, target_content, source_layer, target_layer).
                  When provided, the bridge independently resolves a structural
                  LogicType and checks for zero-divisor boundary crossing.
        """
        if eml_tree is not None:
            tree = eml_tree
        else:
            tree = self.flow_index_to_tree(flow_index)

        # Use spec's coupling signature if available and concept lacks one
        effective_coupling = coupling_signature
        if effective_coupling is None and spec is not None:
            effective_coupling = spec.coupling_signature

        # Determine claimed LogicType: prefer Concept.to_logic_type(),
        # fall back to spec, then coupling
        if concept is not None:
            claimed_logic = self.infer_logic_type(concept)
        else:
            claimed_logic = self._coupling_to_logic_type(effective_coupling)

        # ── Zero-divisor detection via dual LogicType resolution ──
        # When trace_data is provided, independently resolve a structural
        # LogicType from the module's structural properties (tags, layers,
        # spec matching). If claimed and structural LogicTypes straddle
        # the CD 2→3 boundary, the composition is algebraically impossible.
        zd_witness: Optional[ZDWitness] = None
        structural_logic: Optional[LogicType] = None
        structural_source: Optional[str] = None

        if trace_data is not None:
            structural_logic, structural_source = self.resolve_logic_type_from_structure(
                source_content=trace_data.get("source_content", ""),
                target_content=trace_data.get("target_content", ""),
                source_layer=trace_data.get("source_layer", ""),
                target_layer=trace_data.get("target_layer", ""),
                concept_name=concept_name,
            )
            zd_witness = self.detect_cd_boundary_crossing(
                claimed_logic, structural_logic
            )
            if zd_witness is not None:
                zd_witness.resolution_source = structural_source

        # Use structural LogicType if no ZD (it's more precise than claimed)
        logic_type = structural_logic if (structural_logic is not None and zd_witness is None) else claimed_logic

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
            spec_name=spec.cortex_name if spec is not None else None,
            zd_witness=zd_witness,
            structural_logic=structural_logic,
            structural_source=structural_source,
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

    # ── Structural LogicType resolution (evolves beyond string matching) ──

    # Module content tags → LogicType. These map structural properties
    # of a module (from its content description) to a LogicType, without
    # scanning the invariant text for keywords.
    #
    # The tags come from the trace's source_content / target_content
    # fields, which include hashtags like #paradox, #temporal, etc.
    TAG_TO_LOGIC: Dict[str, LogicType] = {
        "#paradox": LogicType.PARACONSISTENT,
        "#liar": LogicType.PARACONSISTENT,
        "#self-reference": LogicType.QUANTUM,
        "#non-associative": LogicType.QUANTUM,
        "#quantum": LogicType.QUANTUM,
        "#temporal": LogicType.TEMPORAL,
        "#fuzzy": LogicType.FUZZY,
        "#intuitionistic": LogicType.INTUITIONISTIC,
    }

    # Module layer → default LogicType. When no tags or spec match
    # provide a stronger signal, the layer gives a default.
    LAYER_TO_LOGIC: Dict[str, LogicType] = {
        "FORMALIZATION": LogicType.CLASSICAL,
        "API_GATEWAY": LogicType.CLASSICAL,
        "PRESENTATION": LogicType.CLASSICAL,
        "DOCUMENTATION": LogicType.CLASSICAL,
    }

    def resolve_logic_type_from_structure(
        self,
        source_content: str = "",
        target_content: str = "",
        source_layer: str = "",
        target_layer: str = "",
        concept_name: str = "",
    ) -> Tuple[LogicType, str]:
        """Resolve LogicType from a trace's structural properties.

        This is the evolution beyond string matching on invariant text.
        Instead of scanning the invariant for keywords, we resolve the
        LogicType from the module's structural signals:

        1. Content tags (e.g., #paradox → PARACONSISTENT, #quantum → QUANTUM)
        2. CortexSpec registry best_match on the concept name
        3. Layer defaults (FORMALIZATION/API_GATEWAY/PRESENTATION → CLASSICAL)

        Returns:
            Tuple of (LogicType, source_description) where source_description
            explains how the LogicType was determined.
        """
        combined_content = f"{source_content} {target_content}".lower()

        # 1. Tag-based resolution — scan content for #tags
        for tag, logic in self.TAG_TO_LOGIC.items():
            if tag in combined_content:
                return logic, f"tag:{tag}"

        # 2. Spec registry matching — try best_match on concept name
        if concept_name:
            minimal_concept = _MinimalConcept(name=concept_name)
            spec = SEED_REGISTRY.best_match(minimal_concept)
            if spec is not None:
                return spec.to_logic_type(), f"spec:{spec.cortex_name}"

        # 3. Layer-based default
        for layer in [source_layer, target_layer]:
            if layer in self.LAYER_TO_LOGIC:
                return self.LAYER_TO_LOGIC[layer], f"layer:{layer}"

        # 4. Ultimate fallback
        return LogicType.CLASSICAL, "fallback:default"

    def detect_cd_boundary_crossing(
        self,
        claimed_logic: LogicType,
        structural_logic: LogicType,
    ) -> Optional[ZDWitness]:
        """Detect whether two LogicTypes straddle the CD 2→3 boundary.

        This is the formal zero-divisor check. If the claimed LogicType
        (from the edge type's coupling signature) is in the associative
        regime (cdStep ≤ 2) but the structurally-resolved LogicType is
        in the non-associative regime (cdStep ≥ 3), or vice versa, the
        composition crosses the phase boundary where the associator
        defect activates.

        The friction barrier strut_weight² = 16 is the irreducible cost
        of this crossing — proven by friction_barrier_across_cd23 in Lean.
        """
        claimed_cd = claimed_logic.cd_step()
        structural_cd = structural_logic.cd_step()
        lo = min(claimed_cd, structural_cd)
        hi = max(claimed_cd, structural_cd)

        if lo <= 2 and hi >= 3:
            return ZDWitness(
                claimed_logic=claimed_logic,
                structural_logic=structural_logic,
                claimed_cdstep=claimed_cd,
                structural_cdstep=structural_cd,
            )
        return None

    def _coupling_to_tree(self, coupling_signature: str) -> EMLTree:
        """Build an EMLTree shape from a coupling signature.

        Each coupling signature encodes a structural constraint that
        maps to a normal-form tree shape:

        - ``commutative``          → balanced (leaf): order irrelevant
        - ``non-commutative``      → right-leaning: temporal order kept
        - ``non-associative``      → left-leaning: grouping matters
        - ``commutative-associative`` → leaf: no structural constraint
        """
        mapping = {
            "commutative": LEAF,
            "commutative-associative": LEAF,
            "non-commutative": EMLTree.node(LEAF, LEAF),
            "non-associative": EMLTree.node(EMLTree.node(LEAF, LEAF), LEAF),
        }
        return mapping.get(coupling_signature, LEAF)

    def instantiate_spec(
        self,
        spec: CortexSpec,
        witness_data: Dict[str, Any],
    ) -> Tuple[Concept, CortexCertificate]:
        """Issue a writ: instantiate a statute with concrete evidence.

        Takes an abstract ``CortexSpec`` and particular ``witness_data``,
        constructs a certified Concept under the statute's authority.

        The pipeline:
        1. Validate witness_data against spec.validation (type check)
        2. Create a Concept with the spec's form metadata
        3. Merge spec.default_payload + witness_data into form_payload
        4. Run validate_typed_form (reading clerk countersigns)
        5. Build EMLTree from coupling signature
        6. Certify the tree (apply the wax seal)
        7. Return (Concept, CortexCertificate)

        Raises ``TypeError`` if witness_data does not match the spec's
        expected witness type.
        """
        # Lazy imports to avoid circular dependency:
        # infra._core._concept imports LogicType from infra._cortex.
        from .._core._concept import Concept
        from .._core._reference import Reference
        from .._core._inference import validate_typed_form

        # 1. Validate witness type
        wt = spec.validation.witness_type
        if wt is not None and wt != "":
            _PYTYPE_TO_SPEC = {
                "int": "integer",
                "float": "float",
                "str": "string",
                "bool": "boolean",
                "list": "array",
                "dict": "object",
                "NoneType": "null",
            }
            actual_raw = type(witness_data.get("witness", None)).__name__
            actual = _PYTYPE_TO_SPEC.get(actual_raw, actual_raw)
            if actual != wt:
                raise TypeError(
                    f"Spec '{spec.cortex_name}' expects witness_type='{wt}', "
                    f"got '{actual}' (Python {actual_raw})"
                )

        # 2. Create concept under the statute
        concept = Concept(
            name=f"writ:{spec.cortex_name}",
            form_type=spec.form_type,
            coupling_signature=spec.coupling_signature,
            form_schema_version=spec.form_schema_version,
        )

        # 3. Populate form payload (spec defaults + witness data)
        payload = dict(spec.default_payload)
        payload.update(witness_data)
        concept.reference = Reference([], [], form_payload=payload)

        # 4. Reading clerk countersigns
        validate_typed_form(concept)

        # 5. Build tree from coupling signature
        tree = self._coupling_to_tree(spec.coupling_signature)

        # 6. Apply the wax seal
        cert = certify(tree)

        return concept, cert

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

    Hooks into the Orchestrator lifecycle:
    - ``on_inference_complete`` called after each successful inference
    - ``stamp_seal`` called at the end of ``run()`` / ``run_async()``
    """

    def __init__(self, registry_bound: int = 1024):
        self.core = CortexBridge()
        self.registry = TypeRegistry(bound=registry_bound)
        self._certificates: Dict[str, CortexCertificate] = {}
        self._lift_cache: Dict[str, LiftResult] = {}

    # ── Spec resolution (delegated to core) ────────────────────────

    def resolve_spec(
        self,
        concept: Any,
        registry: SpecRegistry = SEED_REGISTRY,
    ) -> Optional[CortexSpec]:
        """Find the governing statute for *concept* and pre-populate its
        typed-form fields.

        Delegates to ``CortexBridge.resolve_spec`` — the core stateless
        translation.  This wrapper exists so the stateful bridge presents
        the same interface to callers (Orchestrator, web UI, etc.).
        """
        return self.core.resolve_spec(concept, registry)

    def pre_populate_repo(
        self,
        concept_repo: Any,
        registry: SpecRegistry = SEED_REGISTRY,
    ) -> int:
        """Pre-populate every concept in *concept_repo* from the statute book.

        Returns the count of concepts that matched a statute.
        """
        return self.core.pre_populate_repo(concept_repo, registry)

    def instantiate_spec(
        self,
        spec: CortexSpec,
        witness_data: Dict[str, Any],
    ) -> Tuple[Concept, CortexCertificate]:
        """Issue a writ under a statute.

        Delegates to ``CortexBridge.instantiate_spec`` — the core
        stateless translation.  This wrapper exists so the stateful
        bridge presents the same interface to callers.
        """
        return self.core.instantiate_spec(spec, witness_data)

    # ── BlamePool / Event scaffold ─────────────────────────────────

    def blackboard_to_events(self, blackboard: Any) -> List[Event]:
        """Convert NC Blackboard inference history to LC Events.

        Every completed or failed inference becomes an Event with its
        cycle as the year, the flow_index and status as the description,
        and impact=1 for failures, impact=0 for successes.

        This is the **commutative base case**: no interest, no pooling
        threshold. Each debt is recorded independently.
        """
        events: List[Event] = []
        history = getattr(blackboard, 'history', {})
        if not history:
            return events
        for flow_index, item in history.items():
            status = getattr(item, 'status', None)
            cycle = getattr(item, 'cycle', 0)
            if status == 'failed':
                events.append(Event(
                    year=cycle,
                    description=f"inference {flow_index} failed",
                    impact=1,
                ))
            elif status == 'completed':
                events.append(Event(
                    year=cycle,
                    description=f"inference {flow_index} completed",
                    impact=0,
                ))
        return events

    def compute_blame(self, events: List[Event]) -> BlamePool:
        """Compute the BlamePool from a list of Events.

        Simple commutative sum: total_impact = Σ impact_i.
        No interest, no pooling threshold — the Calvinist base case.
        """
        total = sum(e.impact for e in events)
        return BlamePool(total_impact=total, event_count=len(events))

    def run_closure_on_blackboard(
        self,
        blackboard: Any,
    ) -> Tuple[List[Event], BlamePool]:
        """Run the institutional closure pipeline on NC Blackboard state.

        1. Convert blackboard history → Events
        2. Compute the BlamePool (simple sum)
        3. Return (events, pool)

        The full closure pipeline (temporal_normalize → fuzzy_grade →
        deontic_update) can run on these Events when wired.
        """
        events = self.blackboard_to_events(blackboard)
        pool = self.compute_blame(events)
        return events, pool

    # ── Orchestration hooks ────────────────────────────────────────

    def on_inference_complete(
        self,
        flow_index: str,
        concept: Any,
        sequence_type: str,
        run_id: str,
        value_concept_count: int = 0,
        has_function_concept: bool = False,
        supporting_count: int = 0,
        coupling_signature: Optional[str] = None,
    ) -> LiftResult:
        """Called when an NC inference completes.

        Resolves the applicable statute (CortexSpec) from the concept,
        then lifts the inference under that statute's authority.

        When ``value_concept_count``, ``has_function_concept``, and
        ``supporting_count`` are provided, the EMLTree is built from
        the actual dependency structure via ``tree_from_inference_entry``
        (the *formal mapping*). When omitted, falls back to the heuristic
        ``tree_from_flow_index`` (flow index depth only).

        GAP (previously): Must be called from Orchestrator. Now wired
        via ``Orchestrator.cortex_bridge`` in ``_process_inference_state``.
        """
        # Resolve the applicable statute before lifting
        spec = self.resolve_spec(concept)

        sig = coupling_signature
        if sig is None and hasattr(concept, 'coupling_signature'):
            sig = concept.coupling_signature

        # Build formal EMLTree when dependency structure is available,
        # falling back to heuristic depth-based tree otherwise.
        if value_concept_count > 0 or supporting_count > 0 or has_function_concept:
            tree = tree_from_inference_entry(
                value_concept_count=value_concept_count,
                has_function_concept=has_function_concept,
                supporting_count=supporting_count,
                coupling_signature=sig,
            )
        else:
            tree = None  # Fall back to flow_index heuristic

        result = self.core.lift_inference(
            flow_index=flow_index,
            concept_name=getattr(concept, 'name', 'unknown'),
            sequence_type=sequence_type,
            coupling_signature=sig,
            concept=concept,
            spec=spec,
            eml_tree=tree,
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

    def stamp_seal(self, run_id: str) -> Optional[CortexCertificate]:
        """Stamp the wax seal for a completed voyage (run).

        Collects every EMLTree lifted during the run, combines them
        into a composite tree, certifies it (source → rightComb normal
        form with full contraction path), and stores the certificate.

        The seal can be verified by anyone via ``cert.verify()`` without
        trusting the issuer.
        """
        trees = [
            v.eml_tree
            for k, v in self._lift_cache.items()
            if k.startswith(f"{run_id}:")
        ]
        if not trees:
            return None

        composite = LEAF
        for t in trees:
            composite = EMLTree.node(composite, t)

        cert = certify(composite)
        self._certificates[run_id] = cert
        return cert

    def stamp_checkpoint(self, run_id: str, cycle: int) -> Optional[CortexCertificate]:
        """Stamp a checkpoint seal — a log entry at an intermediate port.

        Collects all trees lifted under the original *run_id* (not a
        suffixed key) so the checkpoint seal is computed from the
        actual voyage cache, then stored under a composite key
        ``{run_id}:checkpoint:{cycle}`` for independent verification.
        """
        trees = [
            v.eml_tree
            for k, v in self._lift_cache.items()
            if k.startswith(f"{run_id}:")
        ]
        if not trees:
            return None

        composite = LEAF
        for t in trees:
            composite = EMLTree.node(composite, t)

        cert = certify(composite)
        self._certificates[f"{run_id}:checkpoint:{cycle}"] = cert
        return cert

    def get_certificate(self, run_id: str) -> Optional[CortexCertificate]:
        """Retrieve a stored certificate."""
        return self._certificates.get(run_id)

    def list_certificates(self) -> List[str]:
        """List all stored certificate keys."""
        return list(self._certificates.keys())

    # ── Checkpoint verification (Purser's Inspection) ──────────────

    def verify_checkpoint(
        self, run_id: str, cycle: int
    ) -> Tuple[bool, Optional[CortexCertificate]]:
        """Purser's inspection: verify a checkpoint seal.

        Returns ``(True, cert)`` if the seal exists and ``cert.verify()``
        passes.  Returns ``(False, None)`` if no seal was stamped for
        this checkpoint.
        """
        cert = self._certificates.get(f"{run_id}:checkpoint:{cycle}")
        if cert is None:
            return False, None
        return cert.verify(), cert

    def checkpoint_proof(
        self, run_id: str, cycle: int
    ) -> Optional[Dict[str, Any]]:
        """Package a checkpoint proof for smart contract verification.

        Returns a dict with the certificate metadata and verification
        status, or ``None`` if no checkpoint seal exists for this
        (run_id, cycle) pair.
        """
        ok, cert = self.verify_checkpoint(run_id, cycle)
        if not ok or cert is None:
            return None
        return {
            "run_id": run_id,
            "cycle": cycle,
            "source": repr(cert.source),
            "target": repr(cert.target),
            "path_len": len(cert.path),
            "verified": True,
        }

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
