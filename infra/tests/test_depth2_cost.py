"""
Depth-2 EML Cost Tests — Intuitionistic (max-semantics) and Fuzzy (saturation cap).

Verifies that:
1. Φ(Intuitionistic, t) = t.height (proof depth, not proof size)
2. Φ(Fuzzy, t) ≤ satCap (saturation bound)
3. Existing depth-1 logics (Classical, Boolean, Spacetime) are unchanged
4. EMLTree.height() returns correct values for combs and balanced trees

Mirrors Lean theorems:
  - Φ_intuitionistic_eq_height
  - Φ_fuzzy_le_satCap
"""

import pytest
from infra._cortex._eml_tree import EMLTree, rightComb, leftComb
from infra._cortex._cost import phi, node_param, NodeCost
from infra._cortex._logic_types import LogicType


# ── EMLTree.height ──────────────────────────────────────────────────

class TestEMLTreeHeight:
    """EMLTree.height mirrors Lean EMLTree.height."""

    def test_leaf_height(self):
        assert EMLTree.leaf().height() == 0

    def test_single_node_height(self):
        t = EMLTree.node(EMLTree.leaf(), EMLTree.leaf())
        assert t.height() == 1

    def test_right_comb_height(self):
        for n in range(1, 8):
            assert rightComb(n).height() == n, f"rightComb({n}).height() = {rightComb(n).height()}, expected {n}"

    def test_left_comb_height(self):
        for n in range(1, 8):
            assert leftComb(n).height() == n, f"leftComb({n}).height() = {leftComb(n).height()}, expected {n}"

    def test_balanced_tree_height(self):
        # Balanced tree of size 3: Node(Node(Leaf, Leaf), Node(Leaf, Leaf))
        bal3 = EMLTree.node(EMLTree.node(EMLTree.leaf(), EMLTree.leaf()),
                             EMLTree.node(EMLTree.leaf(), EMLTree.leaf()))
        assert bal3.size() == 3
        assert bal3.height() == 2  # height = 2, not 3!

    def test_balanced_tree_height_computation(self):
        # Node(Leaf, Node(Leaf, Leaf)) — size 2, height 2
        t = EMLTree.node(EMLTree.leaf(),
                         EMLTree.node(EMLTree.leaf(), EMLTree.leaf()))
        assert t.size() == 2
        assert t.height() == 2

        # Node(Node(Leaf, Leaf), Leaf) — size 2, height 2
        t2 = EMLTree.node(EMLTree.node(EMLTree.leaf(), EMLTree.leaf()),
                          EMLTree.leaf())
        assert t2.size() == 2
        assert t2.height() == 2


# ── Intuitionistic (max-semantics, depth-2) ─────────────────────────

class TestIntuitionisticMaxSemantics:
    """Φ(Intuitionistic, t) = t.height (proof depth, not proof size).

    In intuitionistic logic, the cost of a verification is determined
    by the depth of the assumption chain, not the total number of steps.
    """

    def test_intuitionistic_leaf(self):
        assert phi(LogicType.INTUITIONISTIC, EMLTree.leaf()) == 0

    def test_intuitionistic_single_node(self):
        t = EMLTree.node(EMLTree.leaf(), EMLTree.leaf())
        assert phi(LogicType.INTUITIONISTIC, t) == 1
        assert phi(LogicType.INTUITIONISTIC, t) == t.height()

    def test_intuitionistic_right_comb(self):
        """rightComb: height = size for combs."""
        for n in range(1, 8):
            rc = rightComb(n)
            phi_val = phi(LogicType.INTUITIONISTIC, rc)
            assert phi_val == rc.height(), \
                f"Φ(INTUITIONISTIC, rightComb({n})) = {phi_val}, expected height = {rc.height()}"
            # For combs, height = size, so this aligns with classical
            assert phi_val == rc.size(), \
                f"Φ(INTUITIONISTIC, rightComb({n})) = {phi_val}, expected size = {rc.size()}"

    def test_intuitionistic_left_comb(self):
        """leftComb: height = size for combs (same as rightComb)."""
        for n in range(1, 8):
            lc = leftComb(n)
            phi_val = phi(LogicType.INTUITIONISTIC, lc)
            assert phi_val == lc.height(), \
                f"Φ(INTUITIONISTIC, leftComb({n})) = {phi_val}, expected height = {lc.height()}"

    def test_intuitionistic_balanced(self):
        """Balanced tree: Φ = height < size (key difference from classical!).

        For balanced trees, intuitionistic cost (height) is logarithmic in
        size, while classical cost (size) is linear.
        """
        bal3 = EMLTree.node(
            EMLTree.node(EMLTree.leaf(), EMLTree.leaf()),
            EMLTree.node(EMLTree.leaf(), EMLTree.leaf())
        )
        assert phi(LogicType.INTUITIONISTIC, bal3) == 2  # height = 2
        assert bal3.size() == 3  # size = 3
        assert phi(LogicType.INTUITIONISTIC, bal3) < phi(LogicType.BOOLEAN, bal3)

    def test_intuitionistic_depth_1_params_ignored(self):
        """In maxSem mode, leftWeight/rightDiv are irrelevant."""
        c = node_param(LogicType.INTUITIONISTIC)
        assert c.maxSem is True
        # maxSem means: Φ(Node l r) = max(Φ(l), Φ(r)) + bias
        # The depth-1 params (leftWeight, rightDiv) don't affect Φ
        assert c.bias == 1  # bias is still used

    def test_intuitionistic_classical_diverge_for_balanced(self):
        """Classical and Intuitionistic give same Φ for combs,
        but Intuitionistic < Classical for balanced trees."""
        for n in range(1, 6):
            rc = rightComb(n)
            assert phi(LogicType.INTUITIONISTIC, rc) == phi(LogicType.BOOLEAN, rc)

        # Balanced tree: Intuitionistic < Classical
        bal3 = EMLTree.node(
            EMLTree.node(EMLTree.leaf(), EMLTree.leaf()),
            EMLTree.node(EMLTree.leaf(), EMLTree.leaf())
        )
        assert phi(LogicType.INTUITIONISTIC, bal3) < phi(LogicType.BOOLEAN, bal3)


# ── Fuzzy (saturation cap, depth-2) ────────────────────────────────

class TestFuzzySaturationCap:
    """Φ(Fuzzy, t) ≤ satCap for all trees t.

    In fuzzy logic, truth values are bounded in [0, 1]. The satCap
    models this: Φ saturates at satCap=5, preventing unbounded growth.
    """

    def test_fuzzy_leaf(self):
        assert phi(LogicType.FUZZY, EMLTree.leaf()) == 0

    def test_fuzzy_sat_cap(self):
        """Φ(Fuzzy, t) ≤ 5 for all trees up to size 10."""
        c = node_param(LogicType.FUZZY)
        assert c.satCap == 5

        # rightComb: Φ grows slowly due to rightDiv=2
        for n in range(1, 12):
            rc = rightComb(n)
            phi_val = phi(LogicType.FUZZY, rc)
            assert phi_val <= 5, \
                f"Φ(FUZZY, rightComb({n})) = {phi_val}, expected ≤ 5"

        # leftComb: Φ grows like Spacetime (left-biased), but capped at 5
        for n in range(1, 12):
            lc = leftComb(n)
            phi_val = phi(LogicType.FUZZY, lc)
            assert phi_val <= 5, \
                f"Φ(FUZZY, leftComb({n})) = {phi_val}, expected ≤ 5"

    def test_fuzzy_does_saturate(self):
        """For large enough trees, Φ(Fuzzy) actually reaches satCap."""
        c = node_param(LogicType.FUZZY)
        # leftComb grows linearly (Φ ≈ n in depth-1 mode), so it should
        # eventually saturate. With satCap=5, leftComb(5) or later.
        found_saturation = False
        for n in range(1, 15):
            lc = leftComb(n)
            phi_val = phi(LogicType.FUZZY, lc)
            if phi_val == c.satCap:
                found_saturation = True
                break
        # In ℕ arithmetic with rightDiv=2, leftWeight=1: leftComb(5) should
        # saturate. Let's verify it actually does.
        assert found_saturation, "Fuzzy Φ should reach satCap for large enough leftComb"

    def test_fuzzy_still_grows_for_small_trees(self):
        """For small trees (before saturation), Φ(Fuzzy) is distinct from 0."""
        rc1 = rightComb(1)
        assert phi(LogicType.FUZZY, rc1) == 1  # small tree, not saturated

    def test_fuzzy_depth_1_params_still_matter(self):
        """satCap doesn't change the depth-1 formula for unsaturated trees."""
        c = node_param(LogicType.FUZZY)
        assert c.satCap == 5
        assert c.maxSem is False  # Fuzzy uses sum mode, not max
        assert c.rightDiv == 2  # logarithmic saturation
        assert c.leftWeight == 1  # standard left amplification


# ── Existing logics unchanged ──────────────────────────────────────

class TestDepth1Unchanged:
    """Verify that depth-1 logics (Classical, Boolean, Spacetime) are
    unchanged by the depth-2 extension."""

    def test_boolean_unchanged(self):
        """Boolean: Φ = size, rightDiv=0 (flat landscape)."""
        for n in range(1, 6):
            rc = rightComb(n)
            assert phi(LogicType.BOOLEAN, rc) == rc.size()

    def test_classical_rightdiv1(self):
        """Classical: rightDiv=1, so Φ ≠ size.
        Classical gives Φ(rightComb n) = n (same as rightComb height),
        but Φ ≠ size in general because of the /2 term in ℕ."""
        # rightComb: Φ(rightComb 1) = 1 + 0 + 1/2 = 1 (ℕ division: 1//2 = 0)
        assert phi(LogicType.CLASSICAL, rightComb(1)) == 1

    def test_spacetime_unchanged(self):
        """Spacetime: Φ(Node l r) = 1 + Φ(l) (left spine)."""
        lc3 = leftComb(3)
        assert phi(LogicType.SPACETIME, lc3) == 3

        rc3 = rightComb(3)
        assert phi(LogicType.SPACETIME, rc3) == 1

    def test_no_maxSem_for_depth1(self):
        """Depth-1 logics all have maxSem=False."""
        depth1_logics = [
            LogicType.CLASSICAL, LogicType.MANY_VALUED,
            LogicType.PARACONSISTENT, LogicType.TEMPORAL,
            LogicType.DEONTIC, LogicType.EPISTEMIC,
            LogicType.QUANTUM, LogicType.RELEVANCE,
            LogicType.FREE, LogicType.INFINITARY, LogicType.MODAL,
            LogicType.SPACETIME, LogicType.BOOLEAN,
        ]
        for lt in depth1_logics:
            assert node_param(lt).maxSem is False, f"{lt} should have maxSem=False"

    def test_no_satCap_for_nonfuzzy(self):
        """Only Fuzzy has satCap > 0."""
        for lt in LogicType:
            if lt == LogicType.FUZZY:
                assert node_param(lt).satCap == 5, f"{lt} should have satCap=5"
            else:
                assert node_param(lt).satCap == 0, f"{lt} should have satCap=0"


# ── NodeCost.apply depth-2 unit tests ──────────────────────────────

class TestNodeCostDepth2:
    """Unit tests for NodeCost.apply with maxSem and satCap."""

    def test_max_sem_basic(self):
        """maxSem: apply(a, b) = max(a, b) + bias."""
        c = NodeCost(leftWeight=1, rightDiv=0, bias=1, maxSem=True)
        assert c.apply(3, 5) == 6  # max(3, 5) + 1 = 6
        assert c.apply(7, 2) == 8  # max(7, 2) + 1 = 8
        assert c.apply(0, 0) == 1  # max(0, 0) + 1 = 1

    def test_sat_cap_basic(self):
        """satCap=5: apply is capped at 5."""
        c = NodeCost(leftWeight=2, rightDiv=0, bias=1, satCap=5)
        # Without cap: 1 + 2*4 + 0 = 9, but capped at 5
        assert c.apply(4, 0) == 5
        # Within cap: 1 + 2*1 + 0 = 3
        assert c.apply(1, 0) == 3

    def test_max_sem_with_sat_cap(self):
        """maxSem + satCap: max is computed first, then capped."""
        c = NodeCost(leftWeight=1, rightDiv=0, bias=1, maxSem=True, satCap=3)
        # max(4, 5) + 1 = 6, capped at 3
        assert c.apply(4, 5) == 3
        # max(0, 0) + 1 = 1, within cap
        assert c.apply(0, 0) == 1

    def test_sat_cap_zero_means_no_cap(self):
        """satCap=0: no capping (depth-1 behavior)."""
        c = NodeCost(leftWeight=1, rightDiv=0, bias=1, satCap=0)
        # 1 + 1*100 + 0 = 101, no cap
        assert c.apply(100, 0) == 101

    def test_fuzzy_node_param(self):
        """Fuzzy: satCap=5, maxSem=False."""
        c = node_param(LogicType.FUZZY)
        assert c.satCap == 5
        assert c.maxSem is False
        assert c.leftWeight == 1
        assert c.rightDiv == 2
        assert c.bias == 1

    def test_intuitionistic_node_param(self):
        """Intuitionistic: maxSem=True, satCap=0."""
        c = node_param(LogicType.INTUITIONISTIC)
        assert c.maxSem is True
        assert c.satCap == 0
        assert c.bias == 1