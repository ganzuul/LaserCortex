"""
CortexSpec — typed inference specification from the Phase 5 registry.

Maps the JSON schema documented in:
  "Phase 5 Bootstrapping: Formalizing Typed Cortex Specifications
   from Natural-Language Seeds for the LaserCortex Registry"

Each CortexSpec defines what CAN be inferred: witness extraction,
mapping semantics, magnitude contract, and coupling signature.
NC targets these specs during inference rather than producing
trees ad hoc.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional
from datetime import datetime

from ._eml_tree import EMLTree
from ._types import TypeRegistry
from ._logic_types import LogicType


# ── Value objects ────────────────────────────────────────────────────


@dataclass(frozen=True)
class MagnitudeContract:
    """Evidentiary bounds for the witness-skeptic game.

    Mirror of the magnitude_contract object in a Phase 5 spec.
    """
    witness_mass_min: float = 0.0
    witness_mass_max: float = 1.0
    witness_mass_required: bool = True
    skeptic_mass_min: float = 0.0
    skeptic_mass_max: float = 1.0
    skeptic_mass_required: bool = True
    balance_threshold: float = 0.05

    def check_witness_mass(self, mass: float) -> bool:
        return self.witness_mass_min <= mass <= self.witness_mass_max

    def check_skeptic_mass(self, mass: float) -> bool:
        return self.skeptic_mass_min <= mass <= self.skeptic_mass_max

    def is_balanced(self, witness_mass: float, skeptic_mass: float) -> bool:
        return abs(witness_mass - skeptic_mass) < self.balance_threshold


@dataclass(frozen=True)
class SpecValidation:
    """Validation constraints for a spec's form payload."""
    uncertainty_required: bool = True
    uncertainty_min: float = 0.0
    uncertainty_max: float = 1.0
    witness_type: str = "integer"  # integer | number | string | boolean | object
    binary_outcome_type: str = "boolean"
    category_label_type: str = "string"


@dataclass(frozen=True)
class SpecExample:
    """A worked example from the seed corpus."""
    title: str
    source_text: str
    witness_extraction: str
    mapping_hint: str
    provenance_annotation: str = "seed example"


@dataclass(frozen=True)
class SpecProvenance:
    """Provenance chain from seed to spec."""
    prompt: str
    agent_version: str = "textcortex-researcher-v0.1.0"
    human_reviewed: bool = False
    reviewer_id: Optional[str] = None
    created_at: Optional[datetime] = None
    human_notes: str = ""

    @staticmethod
    def now(prompt: str, **kw: Any) -> SpecProvenance:
        return SpecProvenance(
            prompt=prompt,
            created_at=datetime.utcnow(),
            **kw,
        )


# ── Coupling signature → LogicType (from Phase 5 taxonomy) ───────────

COUPLING_TO_LOGIC: Dict[str, LogicType] = {
    "commutative": LogicType.CLASSICAL,
    "non-commutative": LogicType.TEMPORAL,
    "non-associative": LogicType.QUANTUM,
    "commutative-associative": LogicType.CLASSICAL,
}


# ── CortexSpec ────────────────────────────────────────────────────────

@dataclass(frozen=True)
class CortexSpec:
    """A typed inference specification — what CAN be inferred.

    Each spec defines the witness schema, mapping semantics,
    magnitude contract, and coupling signature. NC picks a spec
    from the registry and produces evidence matching it.
    """
    cortex_name: str
    form_type: str
    form_schema_version: str
    coupling_signature: str
    axes: List[str]
    tensor_shape: List[int]
    validation: SpecValidation
    default_payload: Dict[str, Any]
    magnitude_contract: MagnitudeContract
    examples: List[SpecExample]
    provenance: SpecProvenance

    def to_logic_type(self) -> LogicType:
        """Derive LC LogicType from coupling signature."""
        return COUPLING_TO_LOGIC.get(
            self.coupling_signature,
            LogicType.CLASSICAL,
        )

    def matches_coupling(self, sig: str) -> bool:
        return self.coupling_signature == sig

    def matches_form(self, form_type: str) -> bool:
        return self.form_type == form_type


# ── SpecRegistry ─────────────────────────────────────────────────────

@dataclass
class SpecRegistry:
    """Registry of CortexSpecs — the enumerated inference space.

    LC populates this. NC queries it to find valid inference targets.
    Mirror of the Phase 5 registry lifecycle (lookup_by_context, instantiate).
    """
    specs: Dict[str, CortexSpec] = field(default_factory=dict)

    def register(self, spec: CortexSpec) -> None:
        if spec.cortex_name in self.specs:
            raise ValueError(
                f"Spec '{spec.cortex_name}' already registered"
            )
        self.specs[spec.cortex_name] = spec

    def lookup(self, cortex_name: str) -> Optional[CortexSpec]:
        return self.specs.get(cortex_name)

    def lookup_by_coupling(self, sig: str) -> List[CortexSpec]:
        return [s for s in self.specs.values() if s.matches_coupling(sig)]

    def lookup_by_form(self, form_type: str) -> List[CortexSpec]:
        return [s for s in self.specs.values() if s.matches_form(form_type)]

    def lookup_by_context(self, context: str) -> List[CortexSpec]:
        """Match specs whose provenance prompt or example text overlaps context.
        Simple substring match; a real implementation would use embeddings.
        """
        ctx_lower = context.lower()
        results = []
        for s in self.specs.values():
            if ctx_lower in s.provenance.prompt.lower():
                results.append(s)
                continue
            for ex in s.examples:
                if ctx_lower in ex.source_text.lower():
                    results.append(s)
                    break
        return results


# ── The 10 seed specs (from the Phase 5 bootstrapping document) ──────

# Seed 1 — Sorites Heap
SORITES_SPEC = CortexSpec(
    cortex_name="sorites_threshold",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="commutative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="integer"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.5},
        "witness": None,
        "binary_outcome": None,
        "category_label": "heap",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Sorites (short)",
        source_text="If one grain is not a heap, adding one more grain cannot make it a heap. Starting from 1 grain, after adding grains we must decide at which point 'heap' becomes true.",
        witness_extraction="count grains as integer",
        mapping_hint="binary_outcome True if count >= threshold; threshold unspecified — to be determined by agent/human",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Sorites paradox — count_of_grains witness, parametric threshold, category label 'heap'",
        human_notes="Reviewer should verify threshold semantics and choose a domain-appropriate threshold or mark as parametric. Default uncertainty set to 0.5 reflecting threshold indeterminacy.",
    ),
)

# Seed 2 — Locked Room Footprint
LOCKED_ROOM_SPEC = CortexSpec(
    cortex_name="locked_room_footprint",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="commutative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="object"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.4},
        "witness": None,
        "binary_outcome": None,
        "category_label": "intruder_present",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Locked Room Footprint",
        source_text="A single set of muddy footprints leads from the window to the desk. There is only one set on the floor, but dust untouched elsewhere. Is there an intruder?",
        witness_extraction="Extract distinct_footprint_count as integer and footprint_pattern_coherence as enum ('matching','mismatched') from forensic scene description",
        mapping_hint="binary_outcome True if distinct_footprint_count >= 1 AND footprint_pattern_coherence == 'matching'; both conditions required",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Locked Room Footprint — compound witness with count and coherence enum, conjunction mapping",
        human_notes="Reviewer must verify compound witness schema: witness should contain distinct_footprint_count (integer >= 0) and footprint_pattern_coherence (string enum). Default uncertainty 0.4 reflects moderate confidence from single evidence type.",
    ),
)

# Seed 3 — Blue-Eyed Islanders
BLUE_EYED_SPEC = CortexSpec(
    cortex_name="blue_eyed_knowledge_threshold",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="non-commutative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="object"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.6},
        "witness": None,
        "binary_outcome": None,
        "category_label": "blue-eyed_known",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Blue-Eyed Islanders (short)",
        source_text="On an island where blue-eyed people don't know their own eye color, common knowledge announcements trigger a cascade of departures on day N.",
        witness_extraction="Extract public_common_knowledge_flag (boolean), number_blue (integer), and days_elapsed (integer) from narrative state",
        mapping_hint="binary_outcome True if number_blue >= 1 AND public_common_knowledge_flag == true AND days_elapsed >= number_blue; days_elapsed threshold is parametric — derived from number_blue",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Blue-Eyed Islanders — parametric temporal dependency, common knowledge flag, population count",
        human_notes="CRITICAL: Reviewer must verify parametric mapping semantics. days_elapsed >= number_blue encodes the induction depth. Coupling is non-commutative because temporal ordering of announcements affects state.",
    ),
)

# Seed 4 — Tallness Threshold
TALLNESS_SPEC = CortexSpec(
    cortex_name="tallness_threshold",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="commutative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="integer"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.45},
        "witness": None,
        "binary_outcome": None,
        "category_label": "tall",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Tallness Threshold",
        source_text="When is a person 'tall'? Height is continuous; categorize 'tall' with a threshold on centimeters.",
        witness_extraction="Extract height_cm as integer from physical description or measurement record",
        mapping_hint="binary_outcome True if height_cm >= threshold_cm; threshold_cm is parametric — domain-specific convention required",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Tallness Threshold — height_cm witness, parametric threshold, category 'tall'",
        human_notes="Reviewer should verify threshold_cm is domain-calibrated (e.g., 180 cm for adult males in many populations, or demographic-appropriate values).",
    ),
)

# Seed 5 — Poisoned Cup
POISONED_CUP_SPEC = CortexSpec(
    cortex_name="poisoned_cup_causal",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="commutative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="object"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.6},
        "witness": None,
        "binary_outcome": None,
        "category_label": "poisoning_likely",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Poisoned Cup",
        source_text="Two cups; the inspector tastes both and only the suspect's cup leads to symptoms five minutes later. Are we confident the suspect poisoned the victim?",
        witness_extraction="Extract symptom_onset_latency_seconds as number and compound_presence_flag as boolean from toxicological report and timeline",
        mapping_hint="binary_outcome True if symptom_onset_latency_seconds <= some_short_window_seconds AND compound_presence_flag == True; short_window_seconds is parametric — toxicological domain threshold",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Poisoned Cup — causal witness with latency and compound flag, temporal threshold parametric",
        human_notes="Reviewer must verify short_window_seconds against toxicological reference data (e.g., 300 seconds for rapid-acting agents, longer for slower toxins).",
    ),
)

# Seed 6 — Heap Fuzzy
HEAP_FUZZY_SPEC = CortexSpec(
    cortex_name="heap_fuzzy_membership",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="commutative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="integer"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.7},
        "witness": None,
        "binary_outcome": None,
        "category_label": "heap_membership",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Heap-Fuzzy",
        source_text="Gradually shifting counts where 'heap' is a fuzzy predicate; we want graded membership rather than a strict threshold.",
        witness_extraction="count_of_grains as integer",
        mapping_hint="binary_outcome replaced by graded membership in default_payload; for threshold_category form, binary_outcome True if count >= threshold but threshold should be soft or multi-valued. Recommend fuzzy wrapper or form_type upgrade.",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Heap-Fuzzy — fuzzy predicate, graded membership requested, agent emits threshold_category with elevated uncertainty",
        human_notes="This seed requests graded membership but form_type remains threshold_category per instruction. Reviewer MUST evaluate whether to: (a) wrap binary_outcome with a fuzzy membership function, (b) upgrade form_type to 'fuzzy_category', or (c) maintain strict threshold with high uncertainty.",
    ),
)

# Seed 7 — Conflicting Alibis
CONFLICTING_ALIBIS_SPEC = CortexSpec(
    cortex_name="conflicting_alibis",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="commutative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="object"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.5},
        "witness": None,
        "binary_outcome": None,
        "category_label": "alibi_valid",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Conflicting Alibis",
        source_text="Multiple witnesses give conflicting alibis; one is corroborated by CCTV but the time stamps are ambiguous.",
        witness_extraction="Extract corroboration_score as float in [0,1] from witness statement cross-referencing, and cctv_match_flag as boolean from video evidence review",
        mapping_hint="binary_outcome True if corroboration_score >= 0.8 OR cctv_match_flag == True; disjunctive evidence rule",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Conflicting Alibis — skeptic mass case with corroboration score and CCTV flag, disjunctive mapping",
        human_notes="Reviewer should verify disjunctive threshold: is 0.8 corroboration appropriate? Should cctv_match_flag require timestamp reconciliation? This seed directly exercises skeptic_mass dynamics.",
    ),
)

# Seed 8 — Barber Paradox
BARBER_SPEC = CortexSpec(
    cortex_name="barber_self_reference",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="non-associative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="string"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.9},
        "witness": None,
        "binary_outcome": None,
        "category_label": "self_shave_paradox",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Barber Paradox (classification)",
        source_text="In a town, the barber shaves all who do not shave themselves. Is the barber a self-shaver?",
        witness_extraction="not_directly_numeric; narrative description of shaving relation must be parsed for logical structure",
        mapping_hint="binary_outcome is paradoxical — no consistent assignment exists under classical logic. Agent recommends 'narrative_justification' form_type instead of threshold_category for self-referential cases.",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Barber Paradox — self-referential classification, no numeric witness",
        human_notes="AGENT RECOMMENDATION: This seed warrants form_type 'narrative_justification' rather than 'threshold_category'. Self-reference prevents consistent binary assignment. Default uncertainty 0.9 is MAXIMUM — no computable witness exists. DO NOT register autonomously.",
    ),
)

# Seed 9 — Monty Hall
MONTY_HALL_SPEC = CortexSpec(
    cortex_name="monty_hall_decision",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="commutative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="object"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.3},
        "witness": None,
        "binary_outcome": None,
        "category_label": "switch_is_better",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Monty Hall Decision",
        source_text="You pick one of three doors; host reveals a goat; should you switch? Evaluate whether switching increases win probability above 0.5.",
        witness_extraction="Extract prior_prob_win as float (1/3 for standard 3-door) and host_knowledge_flag as boolean from game setup description",
        mapping_hint="binary_outcome True for 'switch' if posterior_win_switch >= 0.5. Posterior computed as: if host_knowledge_flag==true then posterior_win_switch = 2/3 (standard), else 1/2 (random reveal).",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Monty Hall — probability witness, Bayesian computation, host knowledge flag",
        human_notes="Reviewer should verify computation hint accuracy. For standard 3-door Monty Hall with knowledgeable host, posterior_win_switch = 2/3. If host reveals randomly, posterior = 1/2.",
    ),
)

# Seed 10 — Confessional Consistency
CONFESSIONAL_SPEC = CortexSpec(
    cortex_name="confessional_consistency",
    form_type="threshold_category",
    form_schema_version="0.1.0",
    coupling_signature="commutative",
    axes=["f"],
    tensor_shape=[1],
    validation=SpecValidation(witness_type="object"),
    default_payload={
        "uncertainty": {"present": True, "score": 0.55},
        "witness": None,
        "binary_outcome": None,
        "category_label": "confession_truthful",
    },
    magnitude_contract=MagnitudeContract(),
    examples=[SpecExample(
        title="Confessional Consistency",
        source_text="A suspect's confession contains time/place details that match independent records; however portions seem rehearsed. Are they truthful?",
        witness_extraction="Extract matched_detail_count as integer by cross-referencing confession details against independent records, and rehearsed_phrases_flag as boolean from linguistic pattern analysis",
        mapping_hint="binary_outcome True if matched_detail_count >= threshold AND rehearsed_phrases_flag == False; threshold is parametric — determined by case granularity",
    )],
    provenance=SpecProvenance(
        prompt="Seed: Confessional Consistency — detail count witness, rehearsed flag, conjunction with parametric threshold",
        human_notes="Reviewer should verify threshold for matched_detail_count. How many independent verifications are sufficient? Typical forensic standards suggest 3-5 specific uncorroborated details indicate insider knowledge.",
    ),
)


# ── Default registry with all 10 seed specs ─────────────────────────

SEED_REGISTRY = SpecRegistry()
for _spec in [
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
]:
    SEED_REGISTRY.register(_spec)
