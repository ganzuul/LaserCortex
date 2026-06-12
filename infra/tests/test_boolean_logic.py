"""
Boolean Logic Calibration Suite.

Tests that the cost landscape for Boolean logic behaves as expected:
- Flat: all trees of size n cost n (associativity, no bracket preference)
- Zero edge costs: all Tamari edges have zero crossImpact
- Absorption: cost decreases from expression to minimized form
- Coupling independence: coupling doesn't affect single-child compositions
- Cross-logic sanity: Boolean is flatter than any non-associative logic
"""
import sys
sys.path.insert(0, str(__import__('pathlib').Path(__file__).parent.parent.parent))

from infra._cortex._cost import phi, phi_coupled, NODE_PARAM
from infra._cortex._logic_types import LogicType
from infra._cortex._eml_tree import EMLTree
from infra._cortex._tamari_lattice import (
    all_trees, build_lattice, count_local_minima, coupling_decay,
)
from infra._cortex._eml_tree import rightComb, leftComb

Leaf = EMLTree.leaf()
BOOLEAN = LogicType.BOOLEAN
CLASSICAL = LogicType.CLASSICAL


def test_flat_landscape():
    """All trees of size n must have Φ = n under Boolean (rightDiv=0)."""
    for n in range(8):
        trees = all_trees(n)
        for t in trees:
            c = phi(BOOLEAN, t)
            assert c == n, (
                f"FAIL flat: {repr(t)} size={n} Φ={c} (expected {n})"
            )
    print(f"  PASS: all {sum(len(all_trees(n)) for n in range(8))} trees flat")


def test_flat_n4_all_bracketings():
    """All 14 bracketings of 4 elements cost 4."""
    n = 4
    trees = all_trees(n)
    assert len(trees) == 14, f"Expected 14 trees at n=4, got {len(trees)}"
    costs = [phi(BOOLEAN, t) for t in trees]
    assert all(c == 4 for c in costs), f"Non-flat costs: {costs}"
    print(f"  PASS: all 14 n=4 trees cost 4")


def test_flat_n5_all_bracketings():
    """All 42 bracketings of 5 elements cost 5."""
    n = 5
    trees = all_trees(n)
    assert len(trees) == 42, f"Expected 42 trees at n=5, got {len(trees)}"
    costs = [phi(BOOLEAN, t) for t in trees]
    assert all(c == 5 for c in costs), f"Non-flat costs: {set(costs)}"
    print(f"  PASS: all 42 n=5 trees cost 5")


def test_zero_edge_cross_impacts():
    """All Tamari edges have zero crossImpact under Boolean.

    CrossImpact = |Φ(src) - Φ(dst)|. If the landscape is flat,
    every edge has crossImpact = 0.
    """
    for n in range(2, 7):
        lattice = build_lattice(n)
        for e in lattice.edges:
            ci = e.cross_impacts.get('boolean', None)
            assert ci is not None, f"Missing boolean crossImpact on edge {e}"
            assert ci == 0, (
                f"n={n} edge ({e.source_id}→{e.target_id}) "
                f"crossImpact={ci} expected 0"
            )
    print(f"  PASS: all edges have zero crossImpact")


def test_all_trees_are_local_minima():
    """Every tree is a local minimum under Boolean (flat landscape)."""
    for n in range(2, 7):
        lattice = build_lattice(n)
        costs_boolean = {v.id: v.costs.get('boolean', 0) for v in lattice.vertices}
        minima = count_local_minima(costs_boolean, lattice.edges)
        total = len(lattice.vertices)
        assert minima == total, (
            f"n={n}: {minima}/{total} minima (expected all {total})"
        )
    print(f"  PASS: all trees are local minima (2≤n≤6)")


def test_absorption_gradient():
    """Absorption A∧(A∨B) = A: cost decreases across sizes.

    Tree for A∧(A∨B) = Node(Leaf, Node(Leaf, Leaf)) at n=2 costs 2.
    Tree for A = Leaf at n=0 costs 0.
    """
    abs_tree = EMLTree.node(Leaf, EMLTree.node(Leaf, Leaf))  # n=2
    min_tree = Leaf  # n=0
    c_abs = phi(BOOLEAN, abs_tree)
    c_min = phi(BOOLEAN, min_tree)
    assert c_abs == 2, f"A∧(A∨B) cost={c_abs} expected 2"
    assert c_min == 0, f"A cost={c_min} expected 0"
    assert c_abs > c_min, "No gradient: cost should decrease on minimization"
    print(f"  PASS: absorption gradient 2→0")


def test_idempotence_gradient():
    """Idempotence a∧a = a: Node(Leaf,Leaf) costs 1, Leaf costs 0."""
    c_idem = phi(BOOLEAN, EMLTree.node(Leaf, Leaf))
    c_leaf = phi(BOOLEAN, Leaf)
    assert c_idem == 1, f"a∧a cost={c_idem} expected 1"
    assert c_leaf == 0, f"a cost={c_leaf} expected 0"
    assert c_idem > c_leaf
    print(f"  PASS: idempotence gradient 1→0")


def test_left_right_branching_equal():
    """(a∧b)∧c = a∧(b∧c): left and right bracketings cost the same."""
    left_branch = EMLTree.node(EMLTree.node(Leaf, Leaf), Leaf)
    right_branch = EMLTree.node(Leaf, EMLTree.node(Leaf, Leaf))
    c_left = phi(BOOLEAN, left_branch)
    c_right = phi(BOOLEAN, right_branch)
    assert c_left == c_right, (
        f"Associativity fail: left={c_left} right={c_right}"
    )
    print(f"  PASS: left/right branching both cost {c_left}")


def test_all_n4_bracketings_equal():
    """All 5 bracketings of 4 elements cost the same.

    Representing the 5 binary trees with 4 leaves:
    ((ab)c)d, (a(bc))d, (ab)(cd), a((bc)d), a(b(cd))
    """
    n = 3  # 3 internal nodes = 4 leaves
    trees = all_trees(n)
    costs = [phi(BOOLEAN, t) for t in trees]
    assert len(set(costs)) == 1, f"Not all equal: {costs}"
    print(f"  PASS: all {len(trees)} n=3 trees cost {costs[0]}")


def test_rightComb_leftComb_equal():
    """rightComb and leftComb have the same cost under Boolean."""
    for n in range(1, 7):
        rc = rightComb(n)
        lc = leftComb(n)
        c_rc = phi(BOOLEAN, rc)
        c_lc = phi(BOOLEAN, lc)
        assert c_rc == c_lc == n, (
            f"n={n}: rightComb={c_rc} leftComb={c_lc} expected {n}"
        )
    print(f"  PASS: rightComb==leftComb for n=1..6")


def test_boolean_flatter_than_classical():
    """Boolean has zero cost variance; Classical has non-zero."""
    for n in range(3, 7):
        lattice = build_lattice(n)
        bool_costs = [v.costs.get('boolean', 0) for v in lattice.vertices]
        class_costs = [v.costs.get('classical', 0) for v in lattice.vertices]
        bool_var = max(bool_costs) - min(bool_costs)
        class_var = max(class_costs) - min(class_costs)
        assert bool_var == 0, f"n={n}: Boolean variance={bool_var} (expected 0)"
        assert class_var > 0, f"n={n}: Classical variance={class_var} (expected >0)"
    print(f"  PASS: Boolean flat; Classical has structure")


def test_coupling_doesnt_affect_unbalanced():
    """
    Coupling term coupling*L*R/denom is zero when either child is a leaf.
    So leftComb and rightComb are unaffected by coupling.
    """
    for n in range(1, 7):
        rc = rightComb(n)
        lc = leftComb(n)
        for k in [0, 1, 10, 50, 100]:
            c_rc = phi_coupled(BOOLEAN, rc, coupling=k, denom=10)
            c_lc = phi_coupled(BOOLEAN, lc, coupling=k, denom=10)
            assert c_rc == n, f"n={n} k={k}: rightComb cost={c_rc} expected {n}"
            assert c_lc == n, f"n={n} k={k}: leftComb cost={c_lc} expected {n}"
    print(f"  PASS: coupling doesn't affect left/right comb")


def test_coupling_affects_balanced():
    """
    Coupling term IS non-zero for balanced trees (both children have structure).
    For Boolean with coupling>0, a balanced tree costs > n.
    """
    balanced = EMLTree.node(
        EMLTree.node(Leaf, Leaf),   # cost 1
        EMLTree.node(Leaf, Leaf),   # cost 1
    )  # size 3
    c0 = phi_coupled(BOOLEAN, balanced, coupling=0, denom=10)
    c10 = phi_coupled(BOOLEAN, balanced, coupling=10, denom=10)
    assert c0 == 3, f"Boolean balanced with c=0: {c0} expected 3"
    # With coupling=10: cost = 1 + 1 + 1 + 10*1*1/10 = 4
    assert c10 == 4, f"Boolean balanced with c=10: {c10} expected 4"
    print(f"  PASS: coupling penalizes balanced trees (3→4)")


def test_coupling_decay_doesnt_crash():
    """coupling_decay for Boolean returns sensible results (no collapse).

    At coupling=0: all 14 trees are minima, costs are flat (all 4).
    At coupling>0: balanced trees get penalized, minima count drops,
    max_cost rises. This is the same coupling behavior seen in all logics.
    """
    result = coupling_decay(n=4, logic="boolean", couplings=[0, 1, 5, 10])
    assert result["logic_type"] == "boolean"
    assert len(result["sweep"]) == 4
    assert result["sweep"][0]["num_local_minima"] == 14  # c=0: all minima
    assert result["sweep"][0]["min_cost"] == 4
    assert result["sweep"][0]["max_cost"] == 4
    # As coupling increases, minima drop and max may rise
    assert result["sweep"][-1]["num_local_minima"] <= result["sweep"][0]["num_local_minima"]
    print(f"  PASS: coupling_decay for Boolean (c=0: all minima → c=10: {result['sweep'][-1]['num_local_minima']} minima)")


def test_Φ_theorem_holds():
    """
    The Lean theorem Φ_eq_size_classical states: for rightDiv=0,
    Φ t = t.size. This must hold for Boolean.
    """
    for n in range(0, 7):
        trees = all_trees(n)
        for t in trees:
            assert phi(BOOLEAN, t) == t.size(), (
                f"Φ theorem violation: {repr(t)} Φ={phi(BOOLEAN, t)} size={t.size()}"
            )
    print(f"  PASS: Φ t = t.size for Boolean (matches Lean theorem)")


def test_contracts_one_preserves_cost():
    """If s contracts_one t, then Φ(s) = Φ(t) under Boolean.

    This is the Lean theorem Φ_contracts_one_eq_classical.
    """
    for n in range(2, 6):
        lattice = build_lattice(n)
        for e in lattice.edges:
            src = lattice.vertices[e.source_id]
            dst = lattice.vertices[e.target_id]
            cs = phi(BOOLEAN, src.tree)
            ct = phi(BOOLEAN, dst.tree)
            assert cs == ct, (
                f"n={n}: edge {e.source_id}→{e.target_id} "
                f"Φ(src)={cs} Φ(dst)={ct}"
            )
    print(f"  PASS: contracts_one preserves Boolean cost")


# ── Run all ──────────────────────────────────────────────────────────

def main():
    tests = [
        ("Flat landscape (n=0..7)", test_flat_landscape),
        ("n=4 all 14 bracketings flat", test_flat_n4_all_bracketings),
        ("n=5 all 42 bracketings flat", test_flat_n5_all_bracketings),
        ("Zero edge crossImpacts", test_zero_edge_cross_impacts),
        ("All trees are local minima", test_all_trees_are_local_minima),
        ("Absorption gradient", test_absorption_gradient),
        ("Idempotence gradient", test_idempotence_gradient),
        ("Left/right branching equal", test_left_right_branching_equal),
        ("All n=3 bracketings equal", test_all_n4_bracketings_equal),
        ("rightComb == leftComb", test_rightComb_leftComb_equal),
        ("Boolean flatter than Classical", test_boolean_flatter_than_classical),
        ("Coupling doesn't affect unbalanced", test_coupling_doesnt_affect_unbalanced),
        ("Coupling affects balanced trees", test_coupling_affects_balanced),
        ("coupling_decay doesn't crash", test_coupling_decay_doesnt_crash),
        ("Φ theorem (Φ t = t.size)", test_Φ_theorem_holds),
        ("contracts_one preserves cost", test_contracts_one_preserves_cost),
    ]

    n_pass = 0
    n_fail = 0
    for name, fn in tests:
        try:
            fn()
            n_pass += 1
        except Exception as e:
            print(f"  FAIL: {name}: {e}")
            n_fail += 1

    print(f"\n{'='*50}")
    print(f"Boolean Logic Calibration: {n_pass}/{len(tests)} passed")
    if n_fail:
        print(f"FAILURES: {n_fail}")
        return 1
    print(f"ALL PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
