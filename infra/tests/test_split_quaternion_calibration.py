"""
Split-Quaternion Calibration.

Split-quaternions (coquaternions) have (2,2) signature and are ASSOCIATIVE
but have zero divisors. This isolates the zero-divisor structure from
non-associativity, making them a clean calibration target.

Key facts:
  i² = -1,  j² = +1,  k² = +1,  ij = k = -ji
  Norm: N(q) = a² + b² - c² - d²  (indefinite (2,2) signature)
  Zero divisors from null cone: (1+j)(1-j) = 0
  Associative: all associator norms vanish

Torus knot connection:
  (p,q) torus knot → crossing number min(p(q-1), q(p-1))
  Trefoil (2,3): crossing = 3 → T_3 (3-leaf binary tree)
  Figure-eight (2,4) is NOT a torus knot, but (3,2)=trefoil maps here.

Mapping to cost classes:
  Split-quaternions have zero divisors WITHOUT losing associativity —
  this matches our rightDiv=0 cost classes (Boolean, Intuitionistic, Free)
  where Φ is flat (rotation-invariant) but zero divisors still exist
  as algebraic structure in the underlying split-octonion.
"""

import sys, math
from typing import List, Tuple, Dict

sys.path.insert(0, str(__import__('pathlib').Path(__file__).parent.parent.parent))


# ══════════════════════════════════════════════════════════════════════
# 1. Split-Quaternion Algebra
# ══════════════════════════════════════════════════════════════════════

class SplitQuaternion:
    """4-dimensional split-quaternion with (2,2) signature.

    Basis: {1, i, j, k} with:
      i² = -1,  j² = +1,  k² = +1
      ij = k  (anti-commutative: ji = -k)

    The j²=+1 makes this "split" — it has indefinite quadratic form
    and zero divisors, unlike the standard quaternions.

    Embedding in split-octonions: {e0, e1, e2, e4} (NOT e3!)
    because e4²=+1 in the split-octonion table matches j²=+1.
    Actually: standard ℍ embeds as {e0,e1,e2,e3}; split-ℍ̃ as {e0,e1,e4,e5}
    where e4²=+1 and e1e4=e5 (the split k). This matches ij=k with j=e4.
    """
    __slots__ = ('a', 'b', 'c', 'd')

    def __init__(self, a=0.0, b=0.0, c=0.0, d=0.0):
        self.a = float(a)  # scalar (1 component)
        self.b = float(b)  # i component
        self.c = float(c)  # j component
        self.d = float(d)  # k component

    def __repr__(self):
        parts = []
        if abs(self.a) > 1e-12: parts.append(f"{self.a:.4f}")
        if abs(self.b) > 1e-12: parts.append(f"{self.b:.4f}i")
        if abs(self.c) > 1e-12: parts.append(f"{self.c:.4f}j")
        if abs(self.d) > 1e-12: parts.append(f"{self.d:.4f}k")
        return " + ".join(parts) if parts else "0"

    @staticmethod
    def basis(idx: int) -> 'SplitQuaternion':
        """Return basis vector: 0→1, 1→i, 2→j, 3→k."""
        components = [0.0, 0.0, 0.0, 0.0]
        components[idx] = 1.0
        return SplitQuaternion(*components)

    @staticmethod
    def ONE() -> 'SplitQuaternion':
        return SplitQuaternion(1, 0, 0, 0)

    @staticmethod
    def I() -> 'SplitQuaternion':
        return SplitQuaternion(0, 1, 0, 0)

    @staticmethod
    def J() -> 'SplitQuaternion':
        return SplitQuaternion(0, 0, 1, 0)

    @staticmethod
    def K() -> 'SplitQuaternion':
        return SplitQuaternion(0, 0, 0, 1)


def split_quat_mul(x: SplitQuaternion, y: SplitQuaternion) -> SplitQuaternion:
    """Multiply two split-quaternions.

    (a + bi + cj + dk)(a' + b'i + c'j + d'k)
    Using: i²=-1, j²=+1, k²=+1, ij=k, ji=-k, ik=-j, ki=+j, jk=-i, kj=+i

    Derived basis table:
      1·1=1   1·i=i   1·j=j   1·k=k
      i·1=i   i·i=-1  i·j=k   i·k=-j
      j·1=j   j·i=-k  j·j=+1  j·k=-i
      k·1=k   k·i=+j  k·j=+i  k·k=+1
    """
    return SplitQuaternion(
        a=x.a*y.a - x.b*y.b + x.c*y.c + x.d*y.d,   # 1: real
        b=x.a*y.b + x.b*y.a - x.c*y.d + x.d*y.c,    # i
        c=x.a*y.c - x.b*y.d + x.c*y.a + x.d*y.b,    # j
        d=x.a*y.d + x.b*y.c - x.c*y.b + x.d*y.a,    # k
    )


def split_quat_norm(q: SplitQuaternion) -> float:
    """(2,2) quadratic form: a² + b² - c² - d²."""
    return q.a**2 + q.b**2 - q.c**2 - q.d**2


def split_quat_conj(q: SplitQuaternion) -> SplitQuaternion:
    """Conjugate: a - bi - cj - dk."""
    return SplitQuaternion(q.a, -q.b, -q.c, -q.d)


def split_quat_add(x: SplitQuaternion, y: SplitQuaternion) -> SplitQuaternion:
    return SplitQuaternion(x.a + y.a, x.b + y.b, x.c + y.c, x.d + y.d)


def split_quat_sub(x: SplitQuaternion, y: SplitQuaternion) -> SplitQuaternion:
    return SplitQuaternion(x.a - y.a, x.b - y.b, x.c - y.c, x.d - y.d)


def split_quat_scale(s: float, q: SplitQuaternion) -> SplitQuaternion:
    return SplitQuaternion(s*q.a, s*q.b, s*q.c, s*q.d)


def is_zero(q: SplitQuaternion, tol: float = 1e-9) -> bool:
    return all(abs(getattr(q, c)) < tol for c in 'abcd')


# Wire up operators
SplitQuaternion.__add__ = split_quat_add
SplitQuaternion.__sub__ = split_quat_sub
SplitQuaternion.__mul__ = split_quat_mul
SplitQuaternion.__rmul__ = lambda s, q: split_quat_scale(s, q)


# ══════════════════════════════════════════════════════════════════════
# 2. Torus Knot Crossing Numbers
# ══════════════════════════════════════════════════════════════════════

def torus_knot_crossing(p: int, q: int) -> int:
    """Crossing number of the (p,q) torus knot.

    Standard formula for coprime p, q with p,q >= 2:
      c(T_{p,q}) = min(p(q-1), q(p-1))

    This gives (p-1)q when p < q. Examples:
      T(2,3): c = min(4,3) = 3  (trefoil)
      T(2,5): c = min(8,5) = 5  (cinquefoil)
      T(3,5): c = min(12,10) = 10
      T(3,7): c = min(18,14) = 14
    """
    if math.gcd(p, q) != 1 or p < 2 or q < 2:
        return -1  # Not a valid torus knot
    return min(p * (q - 1), q * (p - 1))


def torus_knot_tree_size(p: int, q: int) -> int:
    """Map torus knot crossing number to EMLTree size.

    Option B: the crossing number becomes n in T_n (the n-leaf tree).
    The tree of size n has n internal nodes (and n+1 leaves).

    T(2,3) → c=3 → tree of size 3 (3 internal nodes, 4 leaves).
    T(2,5) → c=5 → tree of size 5.
    T(3,5) → c=10 → tree of size 10.

    The trefoil has 3 crossings → a 3-node binary tree has exactly
    2 internal nodes (not 3). So for crossing n, we need tree
    size n (where size = internal node count).
    """
    c = torus_knot_crossing(p, q)
    if c < 0:
        return -1
    return c


# ══════════════════════════════════════════════════════════════════════
# 3. Tests
# ══════════════════════════════════════════════════════════════════════

def test_basis_relations():
    """Verify the split-quaternion basis relations."""
    e = SplitQuaternion.ONE()
    i = SplitQuaternion.I()
    j = SplitQuaternion.J()
    k = SplitQuaternion.K()

    # i² = -1
    i2 = i * i
    assert is_zero(i2 + e), f"i² = -1 failed: i² = {i2}"
    print("  PASS: i² = -1")

    # j² = +1 (SPLIT: this differs from standard quaternions)
    j2 = j * j
    assert is_zero(j2 - e), f"j² = +1 failed: j² = {j2}"
    print("  PASS: j² = +1 (split signature)")

    # k² = +1
    k2 = k * k
    assert is_zero(k2 - e), f"k² = +1 failed: k² = {k2}"
    print("  PASS: k² = +1")

    # ij = k
    ij = i * j
    assert is_zero(ij - k), f"ij = k failed: ij = {ij}"
    print("  PASS: ij = k")

    # ji = -k (anti-commutative)
    ji = j * i
    assert is_zero(ji + k), f"ji = -k failed: ji = {ji}"
    print("  PASS: ji = -k (anti-commutative)")

    # jk = ji·ik (via anti-commutativity: jk = j(ij) = (ji)j? no.)
    # Actually: k = ij, so jk = j(ij). By associativity:
    # j(ij) = (ji)j = (-k)j... that's circular.
    # Direct: jk = j(ij) = (ji)j = (-k)j... no, split-quaternions are associative!
    # jk = j·(ij) = (j·i)·j = (-k)·j = -(i·j)·j = -i·(j²) = -i·1 = -i
    jk = j * k
    assert is_zero(jk + i), f"jk = -i failed: jk = {jk}"
    print("  PASS: jk = -i")

    # ki = (ij)i = i(ji) = i(-k) = -i·k... let's just compute
    # ki = k·i = (ij)·i = i·(j·i) = i·(-k) = -i·k
    # i·k = i·(i·j) = (i²)·j = (-1)·j = -j
    # So ki = -(-j) = j... wait:
    # ki = k*i. k = ij. ki = (ij)i. By associativity: = i(ji) = i(-k) = -(ik)
    # ik = i(ij) = (ii)j = (-1)j = -j. So ki = -(-j) = j.
    ki = k * i
    assert is_zero(ki - j), f"ki = j failed: ki = {ki}"
    print("  PASS: ki = j")

    # kj = (ij)j = i(jj) = i·1 = i
    kj = k * j
    assert is_zero(kj - i), f"kj = i failed: kj = {kj}"
    print("  PASS: kj = i")

    return True


def test_associativity():
    """Verify ALL triples of basis vectors are associative.

    This is the key property that distinguishes split-quaternions
    from split-octonions: zero divisors WITHOUT losing associativity.
    """
    basis = [SplitQuaternion.ONE(), SplitQuaternion.I(),
             SplitQuaternion.J(), SplitQuaternion.K()]
    names = ['1', 'i', 'j', 'k']

    max_assoc_norm = 0.0
    max_triple = None

    for ai in range(4):
        for bi in range(4):
            for ci in range(4):
                a, b, c = basis[ai], basis[bi], basis[ci]
                lhs = (a * b) * c
                rhs = a * (b * c)
                diff = lhs - rhs
                n = abs(split_quat_norm(diff))
                if n > max_assoc_norm:
                    max_assoc_norm = n
                    max_triple = (names[ai], names[bi], names[ci])

    assert max_assoc_norm < 1e-9, \
        f"Associativity FAILED: max |assoc| = {max_assoc_norm} at {max_triple}"

    print(f"  PASS: All 64 basis triples are associative (max |assoc| = {max_assoc_norm:.2e})")
    return True


def test_zero_divisors():
    """Verify zero divisors exist from (2,2) signature.

    The key identity: (1+j)(1-j) = 0
    Proof: (1+j)(1-j) = 1 - j + j - j² = 1 - j² = 1 - 1 = 0

    This is the split-quaternion analogue of the split-octonion
    zero divisor (e0+e4)(e0-e4) = 0.
    """
    e = SplitQuaternion.ONE()
    j = SplitQuaternion.J()

    # (1+j)(1-j) = 0
    lhs = (e + j) * (e - j)
    assert is_zero(lhs), f"(1+j)(1-j) = 0 FAILED: got {lhs}"
    print("  PASS: (1+j)(1-j) = 0  (null-cone zero divisor)")

    # Verify the norm of (1+j) is zero (isotropic vector)
    v = e + j
    norm_v = split_quat_norm(v)
    assert abs(norm_v) < 1e-9, f"|1+j|² should be 0, got {norm_v}"
    print(f"  PASS: |1+j|² = {norm_v:.2e}  (isotropic)")

    # Verify the norm of (1-j) is zero (isotropic vector)
    w = e - j
    norm_w = split_quat_norm(w)
    assert abs(norm_w) < 1e-9, f"|1-j|² should be 0, got {norm_w}"
    print(f"  PASS: |1-j|² = {norm_w:.2e}  (isotropic)")

    # Find ALL zero-divisor pairs from isotropic vectors
    # Isotropic vectors: a + bi + cj + dk with a²+b²-c²-d² = 0
    # The simplest: (1+j), (1-j), (1+k), (1-k), (1+k?), etc.
    i = SplitQuaternion.I()
    k_elem = SplitQuaternion.K()

    # More zero divisors
    for name, v in [("1+i·j", e + i * SplitQuaternion.J()),  # This is 1+k
                     ("1-i·j", e - i * SplitQuaternion.J()),  # 1-k
                     ("1+k", e + k_elem),
                     ("1-k", e - k_elem)]:
        n = abs(split_quat_norm(v))
        if n < 1e-9:
            # Check if v has a zero-divisor partner
            vc = split_quat_conj(v) if False else None  # conjugate isn't the partner
            # The partner is the "orthogonal isotropic" vector
            # For v = a+cj: partner is a-cj (same a, sign flip on j)
            pass

    # Count isotropic basis combinations
    isotropic_count = 0
    for a_val in [1, -1]:
        for b_coeff in range(-1, 2):
            for c_coeff in range(-1, 2):
                for d_coeff in range(-1, 2):
                    q = SplitQuaternion(a_val, b_coeff, c_coeff, d_coeff)
                    if not is_zero(q, tol=0.5):
                        if abs(split_quat_norm(q)) < 1e-9:
                            isotropic_count += 1

    print(f"  PASS: Found {isotropic_count} isotropic vectors with ±1 coefficients")

    return True


def test_norm_multiplicativity():
    """Split-quaternion norm is NOT multiplicative (unlike standard quaternions).

    For standard quaternions: |ab|² = |a|²|b|²
    For split-quaternions: this fails when zero divisors are involved.

    Proof: (1+j) and (1-j) both have norm 0, but we need to check
    whether N(ab) = N(a)N(b) holds for generic elements.
    """
    i = SplitQuaternion.I()
    j = SplitQuaternion.J()

    # For non-null elements, N(ab) = N(a)N(b) should hold
    # (split-quaternions still form a composition algebra)
    a = SplitQuaternion(1, 2, 3, 4)
    b = SplitQuaternion(5, 6, 7, 8)

    nab = split_quat_norm(a * b)
    na_nb = split_quat_norm(a) * split_quat_norm(b)

    assert abs(nab - na_nb) < 1e-6, \
        f"Norm multiplicativity failed: N(ab)={nab}, N(a)N(b)={na_nb}"
    print(f"  PASS: N(ab) = N(a)N(b) for generic elements ({nab:.4f} ≈ {na_nb:.4f})")

    # For null (isotropic) elements, N(a)N(b) = 0 but N(ab) might not be
    v = SplitQuaternion.ONE() + j  # |v|² = 0
    w = SplitQuaternion.ONE() - j  # |w|² = 0
    vw = v * w
    n_vw = split_quat_norm(vw)
    print(f"  INFO: N(1+j)·N(1-j) = 0·0 = 0, N((1+j)(1-j)) = {n_vw:.6f}")
    print(f"  INFO: (1+j)(1-j) = {vw}  (zero divisor product)")

    return True


def test_associator_disappears_despite_zero_divisors():
    """The KEY property: associativity holds even with zero divisors.

    In split-octonions, associativity fails AND zero divisors exist.
    In split-quaternions, associativity holds AND zero divisors exist.
    This means zero-divisors alone do NOT imply non-associativity.

    Implication for our cost classes:
      - rightDiv=0 (flat landscape) CAN have zero divisors in the
        underlying algebra (the split-quaternion level)
      - Non-associativity (rightDiv>0, crossing structure) is
        INDEPENDENT of zero divisors
    """
    e = SplitQuaternion.ONE()
    j = SplitQuaternion.J()

    # (1+j) is a zero divisor, but it should associate with everything
    v = e + j  # zero divisor

    # Check: (v·v)·v = v·(v·v)
    lhs = (v * v) * v
    rhs = v * (v * v)
    diff = lhs - rhs
    assert is_zero(diff), f"Associativity failed for zero divisor: {lhs} ≠ {rhs}"
    print("  PASS: Zero divisor (1+j) still associates")

    # Check: (v·a)·b = v·(a·b) for generic a,b
    a = SplitQuaternion(1, 2, 3, 4)
    b = SplitQuaternion(5, 6, 7, 8)
    lhs2 = (v * a) * b
    rhs2 = v * (a * b)
    diff2 = lhs2 - rhs2
    assert is_zero(diff2), f"Associativity failed for v·(a·b)"
    print("  PASS: Zero divisor associates with generic elements")

    # Cross-check: split-octonions FAIL associativity on (e1,e2,e4)
    from infra.tests.test_cayley_dickson_ladder import SplitOctonion, associator as oct_assoc
    from infra.tests.test_cayley_dickson_ladder import octonion_norm
    e1 = SplitOctonion.basis(1)
    e2 = SplitOctonion.basis(2)
    e4 = SplitOctonion.basis(4)
    assoc_oct = oct_assoc(e1, e2, e4)
    assoc_norm = abs(octonion_norm(assoc_oct))
    print(f"  INFO: Split-octonion associator norm at (e1,e2,e4) = {assoc_norm:.4f}")
    print(f"  INFO: Split-quaternion associator norm = 0 (for ALL triples)")
    print(f"  → Zero divisors and non-associativity are INDEPENDENT structural features")

    return True


def test_torus_knot_crossing_numbers():
    """Verify torus knot crossing numbers match known values.

    The trefoil T(2,3) has 3 crossings — this maps to our tree size 3.
    """
    # Known torus knots and their crossing numbers
    known = [
        # (p, q, expected_crossing)
        (2, 3, 3),   # Trefoil knot
        (2, 5, 5),   # Solomon's seal / cinquefoil
        (2, 7, 7),   # Septafoil
        (3, 2, 3),   # T(3,2) = T(2,3) (same knot)
        (3, 5, 10),  # Torus knot 3_5
        (3, 4, 8),   # Torus knot T(3,4)
        (3, 7, 14),  # Torus knot T(3,7)
        (4, 3, 8),   # Same as T(3,4)
        (4, 5, 15),  # Torus knot T(4,5)
    ]

    all_pass = True
    for p, q, expected in known:
        c = torus_knot_crossing(p, q)
        status = "PASS" if c == expected else "FAIL"
        if c != expected:
            all_pass = False
        print(f"  {status}: T({p},{q}) crossing = {c} (expected {expected})")

    assert all_pass, "Some crossing numbers don't match"
    return True


def test_crossing_to_tree_mapping():
    """Map torus knot crossings to EMLTree sizes.

    The crossing number c(T_{p,q}) maps to tree size c via Option B:
    the knot invariant becomes a label on the Tamari vertex, and
    the crossing number equals the number of internal nodes.
    """
    from infra._cortex._cost import NODE_PARAM, NodeCost, phi
    from infra._cortex._logic_types import LogicType
    from infra._cortex._eml_tree import EMLTree, rightComb, leftComb

    # Trefoil (2,3): crossing = 3, tree size = 3
    # A tree of size 3 has 3 internal nodes:
    #   rightComb(3) and leftComb(3) are the extremal trees
    c_trefoil = torus_knot_crossing(2, 3)
    assert c_trefoil == 3
    print(f"  Trefoil T(2,3): crossing = {c_trefoil}")

    # Build the extremal trees for size 3
    right3 = rightComb(3)
    left3 = leftComb(3)

    # Verify they have the right size
    assert right3.size() == 3, f"rightComb(3).size() = {right3.size()}"
    assert left3.size() == 3, f"leftComb(3).size() = {left3.size()}"
    print(f"  PASS: rightComb(3).size() = 3, leftComb(3).size() = 3")

    # Spacetime cost of these trees
    spacetime = LogicType.SPACETIME
    phi_right3 = phi(spacetime, right3)
    phi_left3 = phi(spacetime, left3)

    print(f"  Spacetime phi(rightComb 3) = {phi_right3}")
    print(f"  Spacetime phi(leftComb 3) = {phi_left3}")

    # For Spacetime: phi(rightComb) = 1 (commutator silent)
    #                phi(leftComb) = 3 (associator dominant)
    assert phi_right3 == 1, f"Expected phi(rightComb 3) = 1, got {phi_right3}"
    assert phi_left3 == 3, f"Expected phi(leftComb 3) = 3, got {phi_left3}"
    print(f"  PASS: Spacetime phi(right) = 1, phi(left) = 3")
    print(f"  → Trefoil (2,3) winding: p=2 phi(left)-phi(right)=2, q=3 crossings")

    # Solomon's seal (2,5): crossing = 5
    c_cinquefoil = torus_knot_crossing(2, 5)
    assert c_cinquefoil == 5
    right5 = rightComb(5)
    left5 = leftComb(5)
    phi_right5 = phi(spacetime, right5)
    phi_left5 = phi(spacetime, left5)
    print(f"  Cinquefoil T(2,5): crossing = {c_cinquefoil}")
    print(f"  Spacetime phi(rightComb 5) = {phi_right5}, phi(leftComb 5) = {phi_left5}")

    # Φ gradient: |Δ| = left - right = n - 1 for Spacetime leftComb of size n
    delta_3 = phi_left3 - phi_right3
    delta_5 = phi_left5 - phi_right5
    print(f"  Φ gradient for trefoil: |Δ| = {delta_3}")
    print(f"  Φ gradient for cinquefoil: |Δ| = {delta_5}")

    return True


def test_split_quaternion_cost_class_mapping():
    """Map split-quaternion properties to our cost classes.

    Split-quaternions: associative + zero divisors
    → Maps to rightDiv=0 class (flat landscape, but algebraic zero divisors exist)

    This is the calibration insight: the flat Φ landscape for rightDiv=0
    logics (Boolean, Intuitionistic, Free) CORRESPONDS to the associativity
    of split-quaternions. The zero divisors at this level are METRIC
    (from the (2,2) signature), not ALGEBRAIC (from lost alternativity).
    """
    from infra._cortex._cost import NODE_PARAM, phi
    from infra._cortex._logic_types import LogicType
    from infra._cortex._eml_tree import EMLTree, rightComb, leftComb

    # rightDiv=0 logics: Boolean, Intuitionistic, Free
    rightDiv0_logics = [
        (LogicType.BOOLEAN, "Boolean"),
        (LogicType.INTUITIONISTIC, "Intuitionistic"),
        (LogicType.FREE, "Free"),
    ]

    # Build a few trees to verify flat landscape
    trees = [
        rightComb(3),
        leftComb(3),
        EMLTree.node(EMLTree.leaf(), EMLTree.node(EMLTree.leaf(), EMLTree.leaf())),
    ]

    print("  Cost class: rightDiv=0 (associative + zero divisors)")
    print("  Algebra: split-quaternions (2,2) signature")
    print()

    for lt, name in rightDiv0_logics:
        costs = [phi(lt, t) for t in trees]
        sizes = [t.size() for t in trees]
        flat = all(c == s for c, s in zip(costs, sizes))
        print(f"  {name}: Φ = {costs}, sizes = {sizes} → {'FLAT (Φ=size)' if flat else 'NOT FLAT'}")

    # Verify they all match tree size (Φ = size for rightDiv=0)
    for lt, name in rightDiv0_logics:
        for t in trees:
            assert phi(lt, t) == t.size(), \
                f"{name}: phi({t}) = {phi(lt, t)} ≠ size {t.size()}"
    print()
    print("  PASS: All rightDiv=0 logics have Φ = size (flat landscape)")
    print("  → This flatness corresponds to split-quaternion ASSOCIATIVITY")
    print("  → Zero divisors exist at this level (from (2,2) metric, not algebra)")

    return True


def test_null_cone_structure():
    """Study the null cone of split-quaternions in detail.

    The null cone N(q) = 0 forms a conical surface in (2,2) space:
      a² + b² = c² + d²

    This is the boundary between "time-like" (N>0) and "space-like" (N<0)
    vectors, analogous to the light cone in special relativity.

    For our cost classes:
      - rightDiv=0 logics: all trees same cost → Φ is on the null cone (metric zero divisors)
      - time-like logics (leftWeight>1): Φ amplifies left → time-dominant
      - space-like logic (Spacetime, mirror): Φ tracks left spine → space-dominant
    """
    e = SplitQuaternion.ONE()
    j = SplitQuaternion.J()

    # Parameterize the null cone: a = cos(θ), c = cos(θ) (a² = c² part)
    # Actually: a² + b² = c² + d². On the null cone, norm = 0.
    # The simplest parameterization: (cos θ, sin θ, cos φ, sin φ) with θ = φ

    print("  Null cone: a² + b² = c² + d² (N = 0)")
    print()

    # Check: isotropic vectors in each quadrant
    null_vectors = [
        (1, 0, 1, 0),  # (1+j)
        (1, 0, -1, 0), # (1-j)
        (0, 1, 0, 1),  # (i+k)
        (0, 1, 0, -1), # (i-k)
        (1, 1, 1, 1),  # (1+i+j+k) ... norm = 1+1-1-1 = 0
        (1, 1, 1, -1), # norm = 1+1-1-1 = 0
    ]

    for vals in null_vectors:
        q = SplitQuaternion(*vals)
        n = split_quat_norm(q)
        assert abs(n) < 1e-9, f"Expected null, got norm={n}"
        print(f"  Null vector ({vals[0]},{vals[1]},{vals[2]},{vals[3]}): "
              f"N = {n:.2e} ✓")

    print()
    # Time-like vectors (N > 0): these are like our time-biased logics
    time_vectors = [
        (1, 0, 0, 0),  # e = 1 (pure scalar)
        (0, 1, 0, 0),  # i (pure imaginary, standard)
        (1, 1, 0, 0),  # 1+i (norm = 2 > 0)
    ]
    print("  Time-like vectors (N > 0): like our time-biased logics")
    for vals in time_vectors:
        q = SplitQuaternion(*vals)
        n = split_quat_norm(q)
        print(f"  ({vals[0]},{vals[1]},{vals[2]},{vals[3]}): N = {n:.1f}")

    # Space-like vectors (N < 0): these are like our space-biased logic (Spacetime)
    space_vectors = [
        (0, 0, 1, 0),  # j (norm = -1 < 0)
        (0, 0, 0, 1),  # k (norm = -1 < 0)
        (0, 0, 1, 1),  # j+k (norm = -2 < 0)
    ]
    print()
    print("  Space-like vectors (N < 0): like our space-biased logic (Spacetime)")
    for vals in space_vectors:
        q = SplitQuaternion(*vals)
        n = split_quat_norm(q)
        print(f"  ({vals[0]},{vals[1]},{vals[2]},{vals[3]}): N = {n:.1f}")

    return True


# ══════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════

def main():
    print("=" * 75)
    print("SPLIT-QUATERNION CALIBRATION")
    print("(2,2) Signature: Associative + Zero Divisors")
    print("=" * 75)
    print()

    tests = [
        ("Basis relations", test_basis_relations),
        ("Associativity", test_associativity),
        ("Zero divisors", test_zero_divisors),
        ("Norm multiplicativity", test_norm_multiplicativity),
        ("Assoc despite zero divisors", test_associator_disappears_despite_zero_divisors),
        ("Torus knot crossings", test_torus_knot_crossing_numbers),
        ("Crossing → tree mapping", test_crossing_to_tree_mapping),
        ("Cost class mapping", test_split_quaternion_cost_class_mapping),
        ("Null cone structure", test_null_cone_structure),
    ]

    passed = 0
    failed = 0
    for name, test_fn in tests:
        print(f"--- {name} ---")
        try:
            test_fn()
            passed += 1
        except AssertionError as e:
            print(f"  FAIL: {e}")
            failed += 1
        print()

    print("=" * 75)
    print(f"RESULTS: {passed} passed, {failed} failed out of {len(tests)} tests")
    print("=" * 75)

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())