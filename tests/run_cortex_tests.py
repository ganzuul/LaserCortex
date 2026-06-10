#!/usr/bin/env python3
"""Standalone test runner for infra/_cortex — avoids infra eager imports."""
import sys
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORTEX_DIR = os.path.join(PROJECT_ROOT, "infra/_cortex")

sys.path.insert(0, PROJECT_ROOT)
sys.path.insert(0, CORTEX_DIR)

# ---------------------------------------------------------------------------
# Import cortex modules directly without triggering infra.__init__
# ---------------------------------------------------------------------------
# We use importlib with explicit path manipulation to avoid infra's eager
# agent imports (which need openai not installed in this environment).
import importlib.util
import importlib.machinery

_module_cache = {}

def _load_cortex_module(name):
    """Load a module from infra/_cortex/*.py directly."""
    if name in _module_cache:
        return _module_cache[name]
    path = os.path.join(CORTEX_DIR, f"_{name}.py")
    if not os.path.exists(path):
        path = os.path.join(CORTEX_DIR, f"{name}.py")
    spec = importlib.util.spec_from_file_location(f"infra._cortex._{name}", path,
                                                   submodule_search_locations=[])
    mod = importlib.util.module_from_spec(spec)
    # Make relative imports work by setting __package__
    mod.__package__ = "infra._cortex"
    sys.modules[f"infra._cortex._{name}"] = mod
    spec.loader.exec_module(mod)
    _module_cache[name] = mod
    return mod

# Patch: create a minimal infra package in sys.modules so relative imports work
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

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
EMLTree = eml.EMLTree
LEAF = eml.LEAF
rightComb = eml.rightComb
leftComb = eml.leftComb
contracts_one = eml.contracts_one
contracts_to = eml.contracts_to
contracts_one_successors = eml.contracts_one_successors
decidable_contracts_to = eml.decidable_contracts_to
tree_from_flow_index = eml.tree_from_flow_index

RouterIndex = typ.RouterIndex
TypeRegistry = typ.TypeRegistry
CortexCertificate = typ.CortexCertificate
certify = typ.certify
flow_to_index = typ.flow_to_index

LogicType = lt.LogicType
Gate = lt.Gate
LogicPipeline = lt.LogicPipeline
LogicTranslation = lt.LogicTranslation
logic_contraction = lt.logic_contraction
logic_normal_form = lt.logic_normal_form
CLOSURE_PIPELINE = lt.CLOSURE_PIPELINE
FULL_PIPELINE = lt.FULL_PIPELINE

LogicM = lm.LogicM
LogicMonad = lm.LogicMonad

Decision = dec.Decision
decide = dec.decide

liar_wrapper = par.liar_wrapper
liar_tower = par.liar_tower
friction_lagrangian = par.friction_lagrangian
LIAR_PROBLEM = par.LIAR_PROBLEM
WrappedProblem = par.WrappedProblem
Tower = par.Tower

reverse_one = decomp.reverse_one
ancestors_up_to = decomp.ancestors_up_to
view_dfs = decomp.view_dfs
Path = decomp.Path
Decomposition = decomp.Decomposition

Event = clo.Event
Norm = clo.Norm
closure_fn = clo.closure
HISTORY_TREE = clo.HISTORY_TREE

RIGHT_COMB_RESOLUTION = bnd.RIGHT_COMB_RESOLUTION
VERY_BIG_BOX = bnd.VERY_BIG_BOX

CortexBridge = brd.CortexBridge
NormCodeCortexBridge = brd.NormCodeCortexBridge

# ---------------------------------------------------------------------------
# Test functions
# ---------------------------------------------------------------------------
passed = 0
failed = 0

def check(name, cond, detail=""):
    global passed, failed
    if cond:
        print(f"  PASS  {name}")
        passed += 1
    else:
        msg = f"  FAIL  {name}" + (f" — {detail}" if detail else "")
        print(msg)
        failed += 1

# --- EMLTree ---
def test_eml_tree_construction():
    t = EMLTree.node(LEAF, LEAF)
    check("size 1", t.size() == 1)
    check("not leaf", not t.is_leaf)

    t2 = EMLTree.node(t, LEAF)
    check("size 2", t2.size() == 2)
    check("leaf size 0", LEAF.size() == 0)

def test_right_comb():
    check("rc(0)==LEAF", rightComb(0) == LEAF)
    r1 = rightComb(1)
    check("rc(1) not leaf", not r1.is_leaf)
    r3 = rightComb(3)
    check("rc(3) size=3", r3.size() == 3)

def test_left_comb():
    l3 = leftComb(3)
    check("lc(3) size=3", l3.size() == 3)

def test_contracts_one_rotate():
    a = EMLTree.node(LEAF, LEAF)
    b = LEAF
    c = LEAF
    s = EMLTree.node(EMLTree.node(a, b), c)
    t = EMLTree.node(a, EMLTree.node(b, c))
    check("rotate", contracts_one(s, t))

def test_contracts_to():
    l = leftComb(4)
    r = rightComb(l.size())
    check("lc→rc", contracts_to(l, r))
    check("decidable lc→rc", decidable_contracts_to(l, r))

def test_contracts_one_successors():
    t = EMLTree.node(EMLTree.node(LEAF, LEAF), LEAF)
    succs = contracts_one_successors(t)
    check("successors exist", len(succs) >= 1)
    for s in succs:
        check(f"contracts_one({t},{s})", contracts_one(t, s))

def test_certificate():
    t = leftComb(4)
    cert = certify(t)
    check("cert source", cert.source == t)
    check("cert target rc", cert.target == rightComb(t.size()))
    check("cert verify", cert.verify())
    for i in range(len(cert.path) - 1):
        check(f"cert step {i}", contracts_one(cert.path[i], cert.path[i+1]))

# --- Types ---
def test_router_index():
    idx = RouterIndex(0, 1024)
    check("router index 0", idx.index == 0)
    try:
        RouterIndex(1024, 1024)
        check("reject oob", False)
    except ValueError:
        check("reject oob", True)

def test_type_registry():
    reg = TypeRegistry(bound=4)
    idx0 = RouterIndex(0, 4)
    idx1 = RouterIndex(1, 4)
    reg.register(idx0, rightComb(2))
    check("lookup", reg.lookup(idx0) == rightComb(2))
    try:
        reg.register(idx1, rightComb(2))
        check("injective check", False)
    except ValueError:
        check("injective check", True)
    reg2 = TypeRegistry(bound=4)
    reg2.register(idx0, rightComb(2))
    reg2.register(idx1, leftComb(2))
    check("find idx0", reg2.find(rightComb(2)) == idx0)
    check("injective", reg2.is_injective())

def test_flow_index():
    check("flow_to_index('1.2.3')", flow_to_index("1.2.3") >= 0)

# --- LogicType ---
def test_logic_type():
    check("FUZZY cd_step=1", LogicType.FUZZY.cd_step() == 1)
    check("CLASSICAL cd_step=0", LogicType.CLASSICAL.cd_step() == 0)
    check("CLASSICAL associative", LogicType.CLASSICAL.is_associative_sector())
    check("QUANTUM not associative", not LogicType.QUANTUM.is_associative_sector())
    check("display Fuzzy", LogicType.FUZZY.display_name() == "Fuzzy Logic")

def test_gate():
    g = Gate.of_logic_type(LogicType.TEMPORAL)
    check("gate name", g.name == "Temporal Logic")
    check("gate check", g.check(rightComb(5)))
    check("gate check leaf", g.check(LEAF))

def test_pipeline():
    d = CLOSURE_PIPELINE.run(rightComb(3))
    check("pipeline all passed", d.all_passed())
    t = leftComb(4)
    d2 = CLOSURE_PIPELINE.run(t)
    check("pipeline datum", d2.datum == t)

# --- Decision ---
def test_decision():
    t = rightComb(3)
    d = Decision.empty(t)
    check("empty datum", d.datum == t)
    check("empty all passed", d.all_passed())
    d2 = Decision.singleton_of(t, LogicType.CLASSICAL)
    check("singleton passed", d2.all_passed())

# --- LogicM ---
def test_logic_monad():
    m = LogicM.pure(42)
    check("pure", m.is_pure)
    check("value", m.value == 42)
    m2 = m.map(lambda x: x * 2)
    check("map", m2.value == 84)
    m3 = m.bind(lambda x: LogicM.pure(x + 1))
    check("bind", m3.value == 43)
    m4 = LogicM.node(LogicM.pure("a"), LogicM.pure("b"))
    check("flatten", m4.flatten() == ["a", "b"])
    check("to_eml_tree", m4.to_eml_tree().size() == 1)

# --- Paradox ---
def test_paradox():
    wp = liar_wrapper(LogicType.FUZZY)
    check("liar cost 1", wp.cost == 1)
    check("liar verify", wp.verify())
    tower = liar_tower()
    check("tower 12 layers", len(tower.layers) == 12)
    expected = sum(lt.cd_step() for lt in LIAR_PROBLEM.suitable_logics)
    check("tower total_cost", tower.total_cost() == expected)
    check("lagrangian", friction_lagrangian() == expected)

# --- Decomposition ---
def test_decomposition():
    r3 = rightComb(3)
    rev = reverse_one(r3)
    check("reverse_one nonempty", len(rev) > 0)
    for s in rev:
        check(f"reverse_one contracts({s})", contracts_one(s, r3))
    anc = ancestors_up_to(r3, 2)
    check("ancestors nonempty", len(anc) > 0)
    chain = view_dfs(r3, max_depth=3)
    # chain.target is the deepest ancestor reached, not the starting tree
    check("chain steps exist", len(chain.steps) >= 2)
    d = decomp.Decomposition(source=leftComb(3), target=rightComb(3))
    check("decomp verify", d.verify())

# --- Closure ---
def test_closure():
    result = closure_fn(HISTORY_TREE)
    norms = result.flatten()
    check("closure 3 norms", len(norms) == 3)
    check("norm 0", norms[0] == clo.Norm(rule="tighten threshold", threshold=25))
    check("norm 1", norms[1] == clo.Norm(rule="tighten threshold", threshold=15))
    check("norm 2", norms[2] == clo.Norm(rule="tighten threshold", threshold=20))

# --- Boundlessness ---
def test_boundlessness():
    check("idempotent", RIGHT_COMB_RESOLUTION.check_idempotent(rightComb(5)))
    check("factor", RIGHT_COMB_RESOLUTION.check_factor(rightComb(5)))

# --- Bridge ---
def test_bridge():
    bridge = NormCodeCortexBridge()
    result = bridge.on_inference_complete("1.2.3", None, "functional", "run_001")
    check("bridge idx", result.router_index.index == flow_to_index("1.2.3"))
    check("bridge tree", result.eml_tree.size() >= 1)
    check("bridge cert", result.certificate.verify())
    check("bridge logic", result.logic_type == LogicType.CLASSICAL)
    bindings = bridge.get_registry_state()
    check("registry nonempty", len(bindings) > 0)

def test_bridge_certificate_flow():
    bridge = NormCodeCortexBridge()
    bridge.on_inference_complete("1", None, "functional", "run_002")
    bridge.on_inference_complete("1.1", None, "functional", "run_002")
    cert = bridge.on_plan_complete("run_002")
    check("plan cert not None", cert is not None)
    check("plan cert verify", cert.verify())
    check("cert retrieve", bridge.get_certificate("run_002") == cert)

def test_bridge_decompose():
    bridge = NormCodeCortexBridge()
    bridge.on_inference_complete("1.2", None, "functional", "run_003")
    decomps = bridge.decompose_decision("1.2", "run_003", depth=2)
    check("decompose no error", True)  # just runs

# --- Run ---
if __name__ == "__main__":
    tests = [
        ("EMLTree construction",        test_eml_tree_construction),
        ("rightComb",                    test_right_comb),
        ("leftComb",                     test_left_comb),
        ("contracts_one rotate",         test_contracts_one_rotate),
        ("contracts_to",                 test_contracts_to),
        ("contracts_one_successors",     test_contracts_one_successors),
        ("Certificate",                  test_certificate),
        ("RouterIndex",                  test_router_index),
        ("TypeRegistry",                 test_type_registry),
        ("flow_to_index",                test_flow_index),
        ("LogicType",                    test_logic_type),
        ("Gate",                         test_gate),
        ("Pipeline",                     test_pipeline),
        ("Decision",                     test_decision),
        ("LogicMonad",                   test_logic_monad),
        ("Paradox",                      test_paradox),
        ("Decomposition",                test_decomposition),
        ("Closure",                      test_closure),
        ("Boundlessness",                test_boundlessness),
        ("Bridge lift",                  test_bridge),
        ("Bridge certificate flow",      test_bridge_certificate_flow),
        ("Bridge decompose",             test_bridge_decompose),
    ]
    print(f"Running {len(tests)} tests...\n")
    for name, fn in tests:
        try:
            fn()
        except Exception as e:
            import traceback
            print(f"  FAIL  {name}: {e}")
            traceback.print_exc()
            failed += 1
            print()

    print(f"\n{'='*40}")
    print(f"  {passed} passed, {failed} failed")
    print(f"{'='*40}")
    sys.exit(1 if failed else 0)
