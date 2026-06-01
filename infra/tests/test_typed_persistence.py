"""Phase 3 typed-cortex persistence TDD tests."""
import sys
import types
import tempfile
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

fake_openai = types.ModuleType("openai")
class _FakeOpenAI:
    def __init__(self, *args, **kwargs):
        pass

fake_openai.OpenAI = _FakeOpenAI
sys.modules.setdefault("openai", fake_openai)

from infra._core._concept import Concept
from infra._core._reference import Reference
from infra._orchest._db import OrchestratorDB
from infra._orchest._checkpoint import CheckpointManager


class FakeBlackboard:
    def __init__(self):
        self.concept_statuses = {}
        self.item_results = {}
        self.item_execution_counts = {}
        self.item_completion_details = {}
        self.completed_concept_timestamps = {}
        self.concept_to_flow_index = {}
        self.item_statuses = {}

    def to_dict(self):
        return {}

    def get_concept_status(self, name):
        return self.concept_statuses.get(name, "empty")

    def set_concept_status(self, name, status):
        self.concept_statuses[name] = status


class FakeTracker:
    def __init__(self):
        self.cycle_count = 0

    def to_dict(self):
        return {}

    def load_from_dict(self, _):
        pass


class FakeConceptRepo:
    def __init__(self, entries):
        self._entries = list(entries)

    def get_all_concepts(self):
        return self._entries

    def get_concept(self, name):
        for entry in self._entries:
            if getattr(entry, "concept_name", None) == name:
                return entry
        return None

    def add_reference(self, **kwargs):
        pass


class FakeConceptEntry:
    def __init__(self, name, concept):
        self.concept_name = name
        self.is_ground_concept = False
        self.is_final_concept = False
        self.concept = concept
        self.reference_data = None
        self.reference_axis_names = None

    def get_signature(self):
        return ""


class FakeOrchestrator:
    def __init__(self, concept_repo):
        self.concept_repo = concept_repo
        self.blackboard = FakeBlackboard()
        self.tracker = FakeTracker()
        self.workspace = {}


def _make_concept(name):
    concept = Concept(
        name,
        type="{}",
        form_type="threshold_category",
        form_schema_version="0.1.0",
        coupling_signature="commutative",
    )
    concept.reference = Reference(
        ["k"],
        [1],
        initial_value=None,
        form_payload={
            "uncertainty": {"present": True, "score": 0.3},
            "witness": "crossed",
            "binary_outcome": True,
            "category_label": "detected",
            "path_valid": True,
            "category_valid": True,
        },
    )
    return concept


def test_typed_cortex_is_survives_checkpoint():
    concept = _make_concept("decision")
    entry = FakeConceptEntry("decision", concept)
    orchestrator = FakeOrchestrator(FakeConceptRepo([entry]))

    with tempfile.TemporaryDirectory() as tmp:
        db = OrchestratorDB(str(pathlib.Path(tmp) / "memory.db"), run_id="phase3")
        manager = CheckpointManager(db)
        manager.save_state(1, orchestrator, inference_count=0)
        state = manager.load_latest_checkpoint("phase3")

    assert state is not None
    saved = state["completed_concepts"]["decision"]
    assert "typed_cortex" in saved
    assert saved["typed_cortex"]["form_type"] == "threshold_category"
    payload = saved["typed_cortex"]["form_payload"]
    assert payload["path_valid"] is True
    assert payload["category_valid"] is True
    assert payload["uncertainty"]["score"] == 0.3
    assert payload["binary_outcome"] is True


def test_path_valid_is_immutable():
    concept = _make_concept("validator")
    concept.reference.form_payload["path_valid"] = True
    entry = FakeConceptEntry("validator", concept)
    orchestrator = FakeOrchestrator(FakeConceptRepo([entry]))

    with tempfile.TemporaryDirectory() as tmp:
        db = OrchestratorDB(str(pathlib.Path(tmp) / "memory.db"), run_id="phase3path")
        manager = CheckpointManager(db)
        manager.save_state(1, orchestrator, inference_count=0)
        reloaded = manager.load_latest_checkpoint("phase3path")

    assert reloaded is not None
    saved = reloaded["completed_concepts"]["validator"]
    assert saved["typed_cortex"]["form_payload"]["path_valid"] is True


def test_category_valid_can_flip():
    concept = _make_concept("mutable")
    concept.reference.form_payload["path_valid"] = True
    concept.reference.form_payload["category_valid"] = False
    concept.reference.form_payload["category_label"] = "later"
    entry = FakeConceptEntry("mutable", concept)
    orchestrator = FakeOrchestrator(FakeConceptRepo([entry]))

    with tempfile.TemporaryDirectory() as tmp:
        db = OrchestratorDB(str(pathlib.Path(tmp) / "memory.db"), run_id="phase3cat")
        manager = CheckpointManager(db)
        manager.save_state(1, orchestrator, inference_count=0)
        reloaded = manager.load_latest_checkpoint("phase3cat")

    assert reloaded is not None
    saved = reloaded["completed_concepts"]["mutable"]
    payload = saved["typed_cortex"]["form_payload"]
    assert payload["path_valid"] is True
    assert payload["category_valid"] is False
    assert payload["category_label"] == "later"


def _run(fn):
    try:
        fn()
        return True, ''
    except Exception as e:
        return False, f'{type(e).__name__}: {e}'


if __name__ == '__main__':
    results = []
    for fn in (
        test_typed_cortex_is_survives_checkpoint,
        test_path_valid_is_immutable,
        test_category_valid_can_flip,
    ):
        ok, detail = _run(fn)
        results.append((fn.__name__, ok, detail))

    for name, ok, detail in results:
        tag = 'PASS' if ok else 'FAIL'
        print(f'[{name}] {tag} {detail}'.rstrip())

    raise SystemExit(0 if all(ok for _, ok, _ in results) else 1)
