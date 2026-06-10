#!/usr/bin/env python3
"""Tests for infra/_cortex — the Python mirror of LaserCortex types."""
import sys
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORTEX_DIR = os.path.join(PROJECT_ROOT, "infra/_cortex")
sys.path.insert(0, PROJECT_ROOT)
sys.path.insert(0, CORTEX_DIR)

import importlib.util

def _load_cortex_module(name):
    path = os.path.join(CORTEX_DIR, f"_{name}.py")
    spec = importlib.util.spec_from_file_location(f"infra._cortex._{name}", path,
                                                   submodule_search_locations=[])
    mod = importlib.util.module_from_spec(spec)
    mod.__package__ = "infra._cortex"
    sys.modules[f"infra._cortex._{name}"] = mod
    spec.loader.exec_module(mod)
    return mod

_infra_pkg = type(sys)("infra")
_infra_pkg.__path__ = [os.path.join(PROJECT_ROOT, "infra")]
_infra_pkg.__package__ = "infra"
sys.modules.setdefault("infra", _infra_pkg)
_infra_cortex_pkg = type(sys)("infra._cortex")
_infra_cortex_pkg.__path__ = [CORTEX_DIR]
_infra_cortex_pkg.__package__ = "infra._cortex"
sys.modules.setdefault("infra._cortex", _infra_cortex_pkg)

eml = _load_cortex_module("eml_tree")
typ = _load_cortex_module("types")
lt  = _load_cortex_module("logic_types")
lm  = _load_cortex_module("logic_monad")
dec = _load_cortex_module("decision")
par = _load_cortex_module("paradox")
decomp = _load_cortex_module("decomposition")
clo = _load_cortex_module("closure")
bnd = _load_cortex_module("boundlessness")
brd = _load_cortex_module("bridge")

EMLTree = eml.EMLTree
LEAF = eml.LEAF
rightComb = eml.rightComb
leftComb = eml.leftComb
contracts_one = eml.contracts_one
contracts_to = eml.contracts_to
contracts_one_successors = eml.contracts_one_successors
decidable_contracts_to = eml.decidable_contracts_to
RouterIndex = typ.RouterIndex
TypeRegistry = typ.TypeRegistry
CortexCertificate = typ.CortexCertificate
certify = typ.certify
flow_to_index = typ.flow_to_index
LogicType = lt.LogicType
Gate = lt.Gate
LogicPipeline = lt.LogicPipeline
CLOSURE_PIPELINE = lt.CLOSURE_PIPELINE
LogicM = lm.LogicM
Decision = dec.Decision
Decide = dec.decide
liar_wrapper = par.liar_wrapper
liar_tower = par.liar_tower
friction_lagrangian = par.friction_lagrangian
LIAR_PROBLEM = par.LIAR_PROBLEM
reverse_one = decomp.reverse_one
ancestors_up_to = decomp.ancestors_up_to
view_dfs = decomp.view_dfs
Decomposition = decomp.Decomposition
Chain = decomp.Chain
Event = clo.Event
Norm = clo.Norm
closure_fn = clo.closure
HISTORY_TREE = clo.HISTORY_TREE
RIGHT_COMB_RESOLUTION = bnd.RIGHT_COMB_RESOLUTION
VERY_BIG_BOX = bnd.VERY_BIG_BOX
NormCodeCortexBridge = brd.NormCodeCortexBridge


# ── EMLTree ──────────────────────────────────────────────────────────
def test_eml_tree_construction():
    t = EMLTree.node(LEAF, LEAF)
    assert t.size() == 1
    assert not t.is_leaf
    assert LEAF.is_leaf
    assert LEAF.size() == 0

def test_right_comb():
    assert rightComb(0) == LEAF
    assert not rightComb(1).is_leaf
    assert rightComb(3).size() == 3

def test_left_comb():
    assert leftComb(3).size() == 3

def test_contracts_one_rotate():
    a = EMLTree.node(LEAF, LEAF)
    b = LEAF
    c = LEAF
    s = EMLTree.node(EMLTree.node(a, b), c)
    t = EMLTree.node(a, EMLTree.node(b, c))
    assert contracts_one(s, t)

def test_contracts_to():
    l = leftComb(4)
    r = rightComb(l.size())
    assert contracts_to(l, r)
    assert decidable_contracts_to(l, r)

def test_contracts_one_successors():
    t = EMLTree.node(EMLTree.node(LEAF, LEAF), LEAF)
    succs = contracts_one_successors(t)
    assert len(succs) >= 1
    for s in succs:
        assert contracts_one(t, s)

def test_certificate():
    t = leftComb(4)
    cert = certify(t)
    assert cert.source == t
    assert cert.target == rightComb(t.size())
    assert cert.verify()
    for i in range(len(cert.path) - 1):
        assert contracts_one(cert.path[i], cert.path[i + 1])

# ── Types ────────────────────────────────────────────────────────────
def test_router_index():
    idx = RouterIndex(0, 1024)
    assert idx.index == 0
    try:
        RouterIndex(1024, 1024)
        assert False
    except ValueError:
        pass

def test_type_registry():
    reg = TypeRegistry(bound=4)
    idx0 = RouterIndex(0, 4)
    idx1 = RouterIndex(1, 4)
    reg.register(idx0, rightComb(2))
    assert reg.lookup(idx0) == rightComb(2)
    try:
        reg.register(idx1, rightComb(2))
        assert False
    except ValueError:
        pass
    reg2 = TypeRegistry(bound=4)
    reg2.register(idx0, rightComb(2))
    reg2.register(idx1, leftComb(2))
    assert reg2.find(rightComb(2)) == idx0
    assert reg2.is_injective()

def test_flow_index():
    assert flow_to_index("1.2.3") >= 0

# ── LogicType ────────────────────────────────────────────────────────
def test_logic_type():
    assert LogicType.FUZZY.cd_step() == 1
    assert LogicType.CLASSICAL.cd_step() == 0
    assert LogicType.CLASSICAL.is_associative_sector()
    assert not LogicType.QUANTUM.is_associative_sector()

def test_gate():
    g = Gate.of_logic_type(LogicType.TEMPORAL)
    assert g.name == "Temporal Logic"
    assert g.check(rightComb(5))

def test_pipeline():
    d = CLOSURE_PIPELINE.run(rightComb(3))
    assert d.all_passed()

# ── Decision ─────────────────────────────────────────────────────────
def test_decision():
    t = rightComb(3)
    d = Decision.empty(t)
    assert d.datum == t
    assert d.all_passed()
    d2 = Decision.singleton_of(t, LogicType.CLASSICAL)
    assert d2.all_passed()

# ── LogicM ───────────────────────────────────────────────────────────
def test_logic_monad():
    m = LogicM.pure(42)
    assert m.is_pure
    assert m.value == 42
    m2 = m.map(lambda x: x * 2)
    assert m2.value == 84
    m3 = m.bind(lambda x: LogicM.pure(x + 1))
    assert m3.value == 43
    m4 = LogicM.node(LogicM.pure("a"), LogicM.pure("b"))
    assert m4.flatten() == ["a", "b"]

# ── Paradox ──────────────────────────────────────────────────────────
def test_paradox():
    wp = liar_wrapper(LogicType.FUZZY)
    assert wp.cost == 1
    assert wp.verify()
    tower = liar_tower()
    expected = sum(lt.cd_step() for lt in LIAR_PROBLEM.suitable_logics)
    assert tower.total_cost() == expected
    assert friction_lagrangian() == expected

# ── Decomposition ────────────────────────────────────────────────────
def test_decomposition():
    r3 = rightComb(3)
    rev = reverse_one(r3)
    assert len(rev) > 0
    for s in rev:
        assert contracts_one(s, r3)
    anc = ancestors_up_to(r3, 2)
    assert len(anc) > 0
    d = Decomposition(source=leftComb(3), target=r3)
    assert d.verify()

# ── Closure ──────────────────────────────────────────────────────────
def test_closure():
    result = closure_fn(HISTORY_TREE)
    norms = result.flatten()
    assert len(norms) == 3
    assert norms[0] == Norm(rule="tighten threshold", threshold=25)
    assert norms[1] == Norm(rule="tighten threshold", threshold=15)
    assert norms[2] == Norm(rule="tighten threshold", threshold=20)

# ── Boundlessness ────────────────────────────────────────────────────
def test_boundlessness():
    assert RIGHT_COMB_RESOLUTION.check_idempotent(rightComb(5))
    assert RIGHT_COMB_RESOLUTION.check_factor(rightComb(5))

# ── Bridge ───────────────────────────────────────────────────────────
def test_bridge_lift():
    bridge = NormCodeCortexBridge()
    result = bridge.on_inference_complete("1.2.3", None, "functional", "run_001")
    assert result.router_index.index == flow_to_index("1.2.3")
    assert result.eml_tree.size() >= 1
    assert result.certificate.verify()

def test_bridge_certificate_flow():
    bridge = NormCodeCortexBridge()
    bridge.on_inference_complete("1", None, "functional", "run_002")
    bridge.on_inference_complete("1.1", None, "functional", "run_002")
    cert = bridge.on_plan_complete("run_002")
    assert cert is not None
    assert cert.verify()
    assert bridge.get_certificate("run_002") == cert
