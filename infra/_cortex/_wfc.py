#!/usr/bin/env python3
"""
Wave Function Collapse for LogicType resolution — the constraint
propagation layer that derives suitableLogics rather than asserting it.

Inspired by mxgmn/WaveFunctionCollapse (the Model.cs simple tiled model).
Adapted for LaserCortex:

  - The "grid" is a dependency graph of modules, not a 2D pixel grid.
  - The "tiles" are the 14 LogicTypes.
  - The "adjacency rules" are CD boundary compatibility: two LogicTypes
    can coexist in an edge iff they don't straddle the CD 2→3 boundary
    (the zero-divisor condition from the Friction Lagrangian).
  - The "weights" are inverse friction density: lower cost = higher
    weight = more likely to be selected during observation.
  - Entropy is Shannon entropy of the candidate set weighted by
    friction density.
  - A contradiction (empty candidate set) is a zero divisor: the
    module cannot be consistently typed.

The Barber Paradox is the first formalization that REQUIRES WFC: the
self-application constraint shaves(b,b) ↔ ¬shaves(b,b) eliminates
CLASSICAL from the Barber node by propagation. What remains in the
superposition is exactly the suitable logics — derived, not asserted.
"""

from __future__ import annotations
import math
import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple

from infra._cortex._logic_types import LogicType


# ── Friction density (mirror of FrictionLagrangian.lean) ───────────────

STRUT_WEIGHT = 4  # verified by SplitOctonionCost.strut_weight_eq_four
STRUT_WEIGHT_SQ = STRUT_WEIGHT * STRUT_WEIGHT  # 16 — the irreducible barrier


def _logic_taxi_distance(lt: LogicType) -> int:
    """Commutator cost for a LogicType within its sector.

    Each logic maps to a position in the split octonion algebra.
    The associative sector (e₀-e₃) contains stable logics; the
    non-associative sector (e₄-e₇) contains the split-sector logics.
    Within each sector, the commutator cost distinguishes further:
    more non-commutative logics pay a higher commutator cost.

    The linear cdStep was scaffolding that only mapped 5 logics.
    Here we use dimension_index as a uniform commutator proxy,
    modulated by sector membership.

    The named logics are semantic features — labels for specific
    algebraic configurations in the split octonion. The underlying
    algebra is what's real; the labels are interpretations.
    """
    dim = lt.dimension_index()
    if lt.is_associative_sector():
        # Associative sector (e₀-e₃): low commutator cost, no barrier
        # Map dimension_index (1-15) to a small commutator cost
        return min(dim, 3)
    else:
        # Non-associative sector (e₄-e₇): the split sector
        # Commutator varies within this sector too
        return min(dim, 7)


def friction_density(lt: LogicType) -> float:
    """Total algebraic cost of a LogicType from the split octonion.

    Γ(lt) = commDefect(lt) + AssocSector(lt) * strut_weight²

    where AssocSector is 0 in the associative sector, 1 in the split
    sector. The barrier (strut_weight² = 16) applies to ALL logics
    in the non-associative sector, not just the 5 that the linear
    cdStep scaffolding mapped.

    This replaces the linear cdStep (which only covered 5 logics and
    defaulted the rest to 0 — masking their non-associative structure).
    """
    comm = _logic_taxi_distance(lt)
    if lt.is_associative_sector():
        return float(comm)
    else:
        return float(comm + STRUT_WEIGHT_SQ)


def _logic_weight(lt: LogicType) -> float:
    """Weight for a LogicType in the observation step.

    Lower friction density = higher weight = more likely to be selected.
    We use exp(-Γ) so that ACCESSIBLE associative logics (Γ≤3) dominate
    while non-associative-sector logics (Γ≥16) are vanishingly unlikely
    unless propagation has eliminated all associative options.
    """
    gamma = friction_density(lt)
    return math.exp(-gamma)


# ── Compatibility rules ───────────────────────────────────────────────

def can_coexist(lt1: LogicType, lt2: LogicType) -> bool:
    """Can two LogicTypes coexist on adjacent nodes (an edge)?

    They can coexist iff they DON'T straddle the associative /
    non-associative sector boundary. Crossing that boundary triggers
    the zero-divisor condition: the friction barrier strut_weight² = 16
    makes the composition algebraically impossible.

    The sector boundary is determined by ``is_associative_sector()``,
    which partitions logics into the associative sector (Cl(1,1) ≅ ℍ̃,
    associativity holds) and the non-associative sector (split octonions
    𝕆ˢ, associativity fails). This is the same boundary that the
    Friction Lagrangian's ``assocDefect`` activates at.
    """
    return lt1.is_associative_sector() == lt2.is_associative_sector()


def _build_compatibility_table() -> Dict[LogicType, Set[LogicType]]:
    """Build the full compatibility table."""
    all_logics = list(LogicType)
    table: Dict[LogicType, Set[LogicType]] = {}
    for lt1 in all_logics:
        table[lt1] = {lt2 for lt2 in all_logics if can_coexist(lt1, lt2)}
    return table


_COMPATIBILITY = _build_compatibility_table()


# ── SuperpositionNode ─────────────────────────────────────────────────

@dataclass
class SuperpositionNode:
    """A node in the WFC wave — a module whose LogicType is undetermined.

    Initially in superposition over all LogicTypes. As constraints
    propagate, candidates are eliminated. When only one remains,
    the node has "collapsed" to a definite LogicType. When zero
    remain, the node is in a contradiction state (zero divisor).

    Attributes:
        name: Module name (for identification).
        candidates: Set of remaining LogicType candidates.
        collapsed: The collapsed LogicType, or None if uncollapsed.
        contradicted: True if candidates is empty (zero divisor).
    """
    name: str
    candidates: Set[LogicType] = field(default_factory=lambda: set(LogicType))
    collapsed: Optional[LogicType] = None

    @property
    def contradicted(self) -> bool:
        return len(self.candidates) == 0 and self.collapsed is None

    @property
    def is_collapsed(self) -> bool:
        return self.collapsed is not None

    @property
    def entropy(self) -> float:
        """Shannon entropy of the candidate distribution.

        Lower entropy = more constrained = collapse this node next.
        """
        if self.is_collapsed or self.contradicted:
            return float("inf")  # don't select collapsed/contradicted nodes
        weights = [_logic_weight(lt) for lt in self.candidates]
        total = sum(weights)
        if total <= 0:
            return 0.0
        h = 0.0
        for w in weights:
            p = w / total
            if p > 0:
                h -= p * math.log(p)
        return h

    def ban(self, logic: LogicType) -> bool:
        """Remove a candidate. Returns True if this caused a collapse
        or contradiction (i.e., propagation needed)."""
        self.candidates.discard(logic)
        if len(self.candidates) == 1:
            self.collapsed = next(iter(self.candidates))
            return True
        if len(self.candidates) == 0:
            self.collapsed = None  # clear stale collapse
            return True  # contradiction
        return False

    def force_collapse(self, logic: LogicType) -> None:
        """Force-collapse to a specific logic (constraint initialization)."""
        self.candidates = {logic}
        self.collapsed = logic

    def eliminate(self, logic: LogicType) -> bool:
        """Alias for ban."""
        return self.ban(logic)


# ── WFCPropagator ─────────────────────────────────────────────────────

@dataclass
class WFCEdge:
    """An edge in the dependency graph."""
    source: str  # node name
    target: str  # node name
    direction: str = "default"  # unused for now, but kept for future directed constraints


@dataclass
class WFCResult:
    """Result of running WFC over a dependency graph."""
    nodes: Dict[str, SuperpositionNode]
    edges: List[WFCEdge]
    collapsed: bool
    contradictions: List[str]  # node names that hit zero divisor
    propagation_steps: int
    eliminated_by_propagation: Dict[str, List[str]]  # node → [eliminated logics]


class WFCPropagator:
    """Wave Function Collapse constraint propagator.

    Implements the observation-propagation cycle from mxgmn/WFC:
      1. Initialize all nodes in full superposition (all LogicTypes)
      2. Apply any initial constraints (forced collapses, custom elimination rules)
      3. Propagate constraints to neighbors via compatibility rules
      4. Find the node with minimal entropy
      5. Collapse it (observe) — pick a LogicType by weight
      6. Propagate the new information
      7. Repeat until all nodes are collapsed or a contradiction is found

    The dependency graph is NOT a 2D grid — it's an arbitrary graph
    where edges represent module dependencies. Each edge constrains
    the two endpoint LogicTypes to be compatible (can_coexist).

    The compatibility rule is: two LogicTypes can coexist on an edge
    iff they don't straddle the CD 2→3 boundary. This is the zero-
    divisor condition from the Friction Lagrangian.
    """

    def __init__(
        self,
        node_names: List[str],
        edges: List[WFCEdge],
        seed: int = 42,
    ):
        self.nodes: Dict[str, SuperpositionNode] = {
            name: SuperpositionNode(name=name) for name in node_names
        }
        self.edges = edges
        self.adjacency: Dict[str, Set[str]] = {name: set() for name in node_names}
        for edge in edges:
            self.adjacency[edge.source].add(edge.target)
            self.adjacency[edge.target].add(edge.source)
        self.rng = random.Random(seed)

        # Propagation stack: (node_name, eliminated_logic)
        # When a node loses a candidate, we need to check all neighbors.
        self._stack: List[Tuple[str, LogicType]] = []
        self._propagation_steps = 0
        self._eliminated: Dict[str, List[str]] = {}

    def add_constraint(
        self,
        node_name: str,
        eliminate: Optional[List[LogicType]] = None,
        force: Optional[LogicType] = None,
    ) -> None:
        """Add an initial constraint to a node.

        Either eliminate specific LogicTypes from the node's
        superposition, or force-collapse it to a specific logic.
        """
        node = self.nodes[node_name]
        if force is not None:
            # Force collapse: ban everything except `force`
            for lt in list(node.candidates):
                if lt != force:
                    self._ban(node_name, lt)
        elif eliminate is not None:
            for lt in eliminate:
                self._ban(node_name, lt)

    def _ban(self, node_name: str, logic: LogicType) -> None:
        """Ban a logic from a node and push to propagation stack."""
        node = self.nodes[node_name]
        changed = node.ban(logic)
        self._stack.append((node_name, logic))
        self._eliminated.setdefault(node_name, []).append(logic.display_name())
        if changed:
            self._propagate_from(node_name)

    def _propagate_from(self, source_name: str) -> None:
        """Propagate constraints from a source node to its neighbors."""
        while self._stack:
            node_name, eliminated = self._stack.pop(0)
            self._propagation_steps += 1
            source = self.nodes[node_name]

            for neighbor_name in self.adjacency.get(node_name, []):
                neighbor = self.nodes[neighbor_name]
                if neighbor.is_collapsed or neighbor.contradicted:
                    continue

                # If the eliminated logic was the only compatible one
                # for some candidate in the neighbor, ban that candidate.
                # This is the AC-3-like arc consistency check.
                to_ban: List[LogicType] = []
                for candidate in list(neighbor.candidates):
                    # Check if `candidate` can coexist with ANY remaining
                    # candidate in the source node. If the source has
                    # collapsed, check against the collapsed value.
                    if source.is_collapsed and source.collapsed is not None:
                        if not can_coexist(candidate, source.collapsed):
                            to_ban.append(candidate)
                    else:
                        # Source is still in superposition — candidate is
                        # viable iff it's compatible with at least one
                        # remaining source candidate.
                        viable = any(
                            can_coexist(candidate, src_cand)
                            for src_cand in source.candidates
                        )
                        if not viable:
                            to_ban.append(candidate)

                for lt in to_ban:
                    self._ban(neighbor_name, lt)

    def _find_min_entropy_node(self) -> Optional[str]:
        """Find the uncollapsed node with minimal entropy."""
        min_entropy = float("inf")
        result = None
        for name, node in self.nodes.items():
            if node.is_collapsed or node.contradicted:
                continue
            h = node.entropy
            # Add small random noise to break ties (like mxgmn/WFC)
            noise = 1e-6 * self.rng.random()
            if h + noise < min_entropy:
                min_entropy = h + noise
                result = name
        return result

    def _observe(self, node_name: str) -> None:
        """Collapse a node by selecting a LogicType by weight."""
        node = self.nodes[node_name]
        candidates = list(node.candidates)
        weights = [_logic_weight(lt) for lt in candidates]
        total = sum(weights)
        if total <= 0:
            return
        # Weighted random selection
        r = self.rng.random() * total
        cumulative = 0.0
        chosen = candidates[0]
        for lt, w in zip(candidates, weights):
            cumulative += w
            if r <= cumulative:
                chosen = lt
                break
        # Ban everything except the chosen one
        for lt in candidates:
            if lt != chosen:
                self._ban(node_name, lt)

    def run(self, max_steps: int = 1000) -> WFCResult:
        """Run the full WFC observation-propagation cycle.

        Returns a WFCResult with collapsed nodes, contradictions, and
        propagation statistics.
        """
        # Initial propagation from any constraints added before run()
        if self._stack:
            first_source = self._stack[0][0]
            self._propagate_from(first_source)

        steps = 0
        while steps < max_steps:
            node_name = self._find_min_entropy_node()
            if node_name is None:
                # All nodes collapsed or contradicted
                break
            self._observe(node_name)
            steps += 1

        contradictions = [
            name for name, node in self.nodes.items()
            if node.contradicted
        ]
        collapsed = len(contradictions) == 0

        return WFCResult(
            nodes=self.nodes,
            edges=self.edges,
            collapsed=collapsed,
            contradictions=contradictions,
            propagation_steps=self._propagation_steps,
            eliminated_by_propagation=dict(self._eliminated),
        )


# ── Self-application constraint (Barber Paradox) ──────────────────────

def apply_self_reference_constraint(
    propagator: WFCPropagator,
    node_name: str,
) -> None:
    """Apply the self-application constraint to a node.

    For the Barber: shaves(b,b) ↔ ¬shaves(b,b). This is a contradiction
    under any associative logic — meaning CLASSICAL, FUZZY, and
    INTUITIONISTIC (all of which preserve a form of consistency)
    must be eliminated. What remains is the non-associative regime
    (QUANTUM, PARACONSISTENT) — the logics that can tolerate
    contradictions.

    In WFC terms: this is the initial constraint that starts propagation.
    The Barber node starts in superposition over all LogicTypes. The
    self-application constraint eliminates CLASSICAL — and since the
    Barber is the most constrained node (its invariant is self-
    contradictory), it has the lowest entropy and collapses first.

    Importantly, the elimination is not by fiat. CLASSICAL is eliminated
    because it cannot admit a contradiction (it has explosion: from
    ⊥ derive anything). The same applies to FUZZY, INTUITIONISTIC,
    TEMPORAL, DEONTIC, EPISTEMIC, and BOOLEAN — they are all in the
    associative sector (cdStep ≤ 2). What survives is the non-
    associative sector: QUANTUM (cdStep 3) and PARACONSISTENT (cdStep 4).
    """
    # Eliminate all associative-sector logics from the self-referential node.
    # These are the logics where the law of non-contradiction or explosion
    # holds — meaning shaves(b,b) ↔ ¬shaves(b,b) immediately trivializes.
    associative_logics = [
        lt for lt in LogicType
        if lt.is_associative_sector()
    ]
    propagator.add_constraint(node_name, eliminate=associative_logics)


def create_barber_wfc(
    barber_node: str = "barber",
    classical_neighbors: Optional[List[str]] = None,
    seed: int = 42,
) -> WFCPropagator:
    """Create a WFC propagator for the Barber Paradox.

    The Barber node starts in superposition. The self-application
    constraint eliminates the associative sector. Neighbors (if any)
    start as CLASSICAL (the default for ordinary modules). Propagation
    then checks: can CLASSICAL neighbors coexist with a non-associative
    Barber? No — the CD 2→3 boundary prevents it. The neighbors either
    collapse to a non-associative logic too, or they contradict.

    Args:
        barber_node: Name of the Barber node.
        classical_neighbors: Names of neighbor nodes that start as
            CLASSICAL (ordinary modules). If None, a single neighbor
            is created to show the propagation effect.
        seed: Random seed for reproducibility.
    """
    if classical_neighbors is None:
        classical_neighbors = ["town"]

    all_nodes = [barber_node] + classical_neighbors
    edges = [
        WFCEdge(source=barber_node, target=neighbor)
        for neighbor in classical_neighbors
    ]

    propagator = WFCPropagator(all_nodes, edges, seed=seed)

    # Apply self-reference constraint to the Barber node
    apply_self_reference_constraint(propagator, barber_node)

    # Force neighbors to start as CLASSICAL (they're ordinary modules)
    for neighbor in classical_neighbors:
        propagator.add_constraint(node_name=neighbor, force=LogicType.CLASSICAL)

    return propagator


# ── Convenience: run Barber WFC and report ─────────────────────────────

def run_barber_wfc(seed: int = 42) -> WFCResult:
    """Run WFC on the Barber Paradox and return the result.

    Expected behavior:
      - Barber node: associative logics eliminated by self-reference
        constraint → collapses to QUANTUM or PARACONSISTENT
      - Town node: starts CLASSICAL → incompatible with Barber (CD 2→3
        boundary) → must either change or contradict
      - If town is flexible: collapses to a non-associative logic
      - If town is fixed CLASSICAL: contradiction (zero divisor)
    """
    propagator = create_barber_wfc(seed=seed)
    return propagator.run()