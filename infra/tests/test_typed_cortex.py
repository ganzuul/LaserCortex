"""Phase 2 tests: typed inference guards fire on malformed payloads."""
import sys, types, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(ROOT))

fake_openai = types.ModuleType('openai')
class _FakeOpenAI:
    def __init__(self, *args, **kwargs): pass
fake_openai.OpenAI = _FakeOpenAI
sys.modules['openai'] = fake_openai

from infra._core._concept import Concept
from infra._core._reference import Reference
from infra._core._inference import Inference


def test_reject_missing_payload():
    bad = Concept('bad', type='{}', form_type='threshold_category', form_schema_version='0.1.0', coupling_signature='commutative')
    try:
        Inference('judgement', concept_to_infer=bad, function_concept=Concept('f', type='{}'))
        assert False, 'Expected ValueError'
    except ValueError as e:
        assert 'has typed form but no reference payload' in str(e)


def test_reject_uncertainty_present_false():
    c = Concept('x', type='{}', form_type='threshold_category', form_schema_version='0.1.0', coupling_signature='commutative')
    c.reference = Reference(['k'], [1], initial_value=0, form_payload={'uncertainty': {'present': False, 'score': 0.5}})
    try:
        Inference('judgement', concept_to_infer=c, function_concept=Concept('f', type='{}'))
        assert False, 'Expected ValueError'
    except ValueError:
        pass


def test_reject_uncertainty_score_bad():
    c = Concept('x', type='{}', form_type='threshold_category', form_schema_version='0.1.0', coupling_signature='commutative')
    c.reference = Reference(['k'], [1], initial_value=0, form_payload={'uncertainty': {'present': True, 'score': 1.2}})
    try:
        Inference('judgement', concept_to_infer=c, function_concept=Concept('f', type='{}'))
        assert False, 'Expected ValueError'
    except ValueError:
        pass


def test_reject_missing_witness():
    c = Concept('x', type='{}', form_type='threshold_category', form_schema_version='0.1.0', coupling_signature='commutative')
    c.reference = Reference(['k'], [1], initial_value=0, form_payload={
        'uncertainty': {'present': True, 'score': 0.0},
        'category_label': 'X',
        'binary_outcome': True,
    })
    try:
        Inference('judgement', concept_to_infer=c, function_concept=Concept('f', type='{}'))
        assert False, 'Expected ValueError'
    except ValueError:
        pass
