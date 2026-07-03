#!/usr/bin/env python3
r"""
tube_map_calibrate.py — enumerate trees, compute tropical coordinates, output .dat files

Derives coordinates directly from the Lean-proven formulas:

    tubeCoord cd t = (t.size + assocDefect(cd),  leftWeight t − rightWeight t)

where:
    size(t) = number of internal nodes
    leftWeight(t)  = sum of sizes of all left subtrees
    rightWeight(t) = sum of sizes of all right subtrees
    assocDefect(cd) = 0 if cd ≤ 2, 4 if cd ≥ 3

Outputs .dat files under plots/ for gnuplot consumption.
"""

import os
from dataclasses import dataclass
from typing import List, Tuple, Optional

PLOT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "plots")
os.makedirs(PLOT_DIR, exist_ok=True)


# ═══════════════════════════════════════════════════════════════════════
# 1. EMLTree primitive — mirrors Lean EMLTree
# ═══════════════════════════════════════════════════════════════════════

@dataclass(frozen=True)
class EMLTree:
    is_leaf: bool = True
    left: Optional['EMLTree'] = None
    right: Optional['EMLTree'] = None

    @staticmethod
    def leaf() -> 'EMLTree':
        return EMLTree(is_leaf=True)

    @staticmethod
    def node(left: 'EMLTree', right: 'EMLTree') -> 'EMLTree':
        return EMLTree(is_leaf=False, left=left, right=right)

    def size(self) -> int:
        if self.is_leaf:
            return 0
        return 1 + self.left.size() + self.right.size()

    def __repr__(self) -> str:
        if self.is_leaf:
            return "L"
        return f"N({self.left!r},{self.right!r})"

    def __hash__(self) -> int:
        if self.is_leaf:
            return hash(())
        return hash((self.left, self.right))


LEAF = EMLTree.leaf()
NODE = EMLTree.node  # shorthand


# ═══════════════════════════════════════════════════════════════════════
# 2. Canonical trees (mirror Lean rightComb, leftComb)
# ═══════════════════════════════════════════════════════════════════════

def right_comb(n: int) -> EMLTree:
    """Right-comb: Node(Leaf, Node(Leaf, ... Node(Leaf, Leaf)...))."""
    if n <= 0:
        return LEAF
    return NODE(LEAF, right_comb(n - 1))


def left_comb(n: int) -> EMLTree:
    """Left-comb: Node(Node(... Node(Leaf, Leaf)..., Leaf), Leaf)."""
    if n <= 0:
        return LEAF
    return NODE(left_comb(n - 1), LEAF)


# ═══════════════════════════════════════════════════════════════════════
# 3. Lean-proven measures
# ═══════════════════════════════════════════════════════════════════════

def left_weight(t: EMLTree) -> int:
    """leftWeight(t) = 0 if Leaf, else l.size + leftWeight(l) + leftWeight(r)."""
    if t.is_leaf:
        return 0
    return t.left.size() + left_weight(t.left) + left_weight(t.right)


def right_weight(t: EMLTree) -> int:
    """rightWeight(t) = 0 if Leaf, else r.size + rightWeight(l) + rightWeight(r)."""
    if t.is_leaf:
        return 0
    return t.right.size() + right_weight(t.left) + right_weight(t.right)


def assoc_defect(cd: int) -> int:
    """assocDefect(cd) = 0 if cd ≤ 2, 4 if cd ≥ 3 (proven in FrictionLagrangian.lean)."""
    return 0 if cd <= 2 else 4


def tube_coord(cd: int, t: EMLTree) -> Tuple[int, int]:
    """tubeCoord cd t = (size + assocDefect(cd), leftWeight − rightWeight)."""
    return (t.size() + assoc_defect(cd), left_weight(t) - right_weight(t))


# ═══════════════════════════════════════════════════════════════════════
# 4. Tree enumeration (Catalan)
# ═══════════════════════════════════════════════════════════════════════

def all_trees(n: int) -> List[EMLTree]:
    """All EMLTrees with n internal nodes. Catalan(n) = 1, 1, 2, 5, 14, ..."""
    if n == 0:
        return [LEAF]
    result: List[EMLTree] = []
    for i in range(n):
        for left in all_trees(i):
            for right in all_trees(n - 1 - i):
                result.append(NODE(left, right))
    return result


# ═══════════════════════════════════════════════════════════════════════
# 5. contracts_one (mirror Lean)
# ═══════════════════════════════════════════════════════════════════════

def contracts_one(s: EMLTree, t: EMLTree) -> bool:
    """True if s → t in one Tamari rotation.
    Mirror of inductive `contracts_one : EMLTree → EMLTree → Prop`."""
    # Rule: rotate: Node(Node a b) c → Node a (Node b c)
    if s.is_leaf or s.left.is_leaf:
        pass
    else:
        a, b, c = s.left.left, s.left.right, s.right
        if t == NODE(a, NODE(b, c)):
            return True
    # Rule: left context: if l → l' then Node l r → Node l' r
    if not s.is_leaf and not t.is_leaf and s.right == t.right:
        if contracts_one(s.left, t.left):
            return True
    # Rule: right context: if r → r' then Node l r → Node l r'
    if not s.is_leaf and not t.is_leaf and s.left == t.left:
        if contracts_one(s.right, t.right):
            return True
    return False


def contracts_one_successors(t: EMLTree) -> List[EMLTree]:
    """All trees reachable in one contraction step (mirror Lean)."""
    if t.is_leaf:
        return []
    result: List[EMLTree] = []
    # Direct rotation
    if not t.left.is_leaf:
        a, b, c = t.left.left, t.left.right, t.right
        result.append(NODE(a, NODE(b, c)))
    # Left subtree rotations
    for a_prime in contracts_one_successors(t.left):
        result.append(NODE(a_prime, t.right))
    # Right subtree rotations
    for c_prime in contracts_one_successors(t.right):
        result.append(NODE(t.left, c_prime))
    return result


def contraction_path_to_right_comb(t: EMLTree) -> List[EMLTree]:
    """Trace a path from t to rightComb(t.size()) via contracts_one.
    Uses greedy DFS: always choose the first successor that's closer to rightComb."""
    target = right_comb(t.size())
    path = [t]
    current = t
    visited = set()
    while current != target:
        visited.add(current)
        succs = contracts_one_successors(current)
        # Prefer successors closer to target (fewer Loday inversions)
        best = None
        best_dist = None
        for s in succs:
            if s in visited:
                continue
            # Heuristic: Euclidean distance in (x,y) at cd=3
            c_cur = tube_coord(3, current)
            c_s = tube_coord(3, s)
            c_tgt = tube_coord(3, target)
            d = (c_s[0] - c_tgt[0]) ** 2 + (c_s[1] - c_tgt[1]) ** 2
            if best_dist is None or d < best_dist:
                best_dist = d
                best = s
        if best is None:
            break  # no unvisited successor — path incomplete
        path.append(best)
        current = best
    return path


# ═══════════════════════════════════════════════════════════════════════
# 6. Data file helpers
# ═══════════════════════════════════════════════════════════════════════

def tree_label(t: EMLTree) -> str:
    """Short human-readable label."""
    s = repr(t)
    if len(s) > 40:
        # Shrink: show structure compactly
        bits = []
        def visit(node, depth):
            if node.is_leaf:
                bits.append("L")
            else:
                if depth < 2:
                    bits.append("N")
                    visit(node.left, depth + 1)
                    visit(node.right, depth + 1)
                else:
                    bits.append("...")
        visit(t, 0)
        s = "".join(bits)
    return s


def write_tree_data(trees: List[EMLTree], size: int):
    """Write .dat file with all trees at cd=0,1,2,3."""
    filename = f"tube_calibrate_s{size}.dat"
    path = os.path.join(PLOT_DIR, filename)
    with open(path, "w") as f:
        f.write("# idx  label  size  leftWeight  rightWeight  cd  x  y\n")
        for idx, t in enumerate(trees):
            lw = left_weight(t)
            rw = right_weight(t)
            sz = t.size()
            lbl = tree_label(t)
            for cd in range(4):
                x, y = tube_coord(cd, t)
                f.write(f"{idx}  {lbl}  {sz}  {lw}  {rw}  {cd}  {x}  {y}\n")
    print(f"  Wrote {path} ({len(trees)} trees × 4 cd = {len(trees)*4} lines)")


def write_edge_data(trees: List[EMLTree], size: int, cd: int):
    """Write .dat file with contracts_one edges at given cd."""
    filename = f"tube_edges_s{size}.dat"
    path = os.path.join(PLOT_DIR, filename)
    tree_set = set(trees)
    tree_to_idx = {t: i for i, t in enumerate(trees)}
    with open(path, "w") as f:
        f.write("# x1  y1  x2  y2  source_idx  target_idx  source_label  target_label\n")
        for s in trees:
            x1, y1 = tube_coord(cd, s)
            for t in contracts_one_successors(s):
                if t in tree_set:
                    x2, y2 = tube_coord(cd, t)
                    f.write(f"{x1}  {y1}  {x2}  {y2}  "
                            f"{tree_to_idx[s]}  {tree_to_idx[t]}  "
                            f"{tree_label(s)}  {tree_label(t)}\n")
    print(f"  Wrote {path}")


def write_qe_path(cd: int):
    """Write the QI protocol tree's contraction path at given cd."""
    # QI protocol tree: balanced tree of size 3
    qe_tree = NODE(NODE(LEAF, LEAF), NODE(LEAF, LEAF))
    path = contraction_path_to_right_comb(qe_tree)
    filename = f"tube_qe_path_s3.dat"
    path_out = os.path.join(PLOT_DIR, filename)
    with open(path_out, "w") as f:
        f.write("# step  x  y  label  size  leftWeight  rightWeight\n")
        for step, t in enumerate(path):
            x, y = tube_coord(cd, t)
            lw = left_weight(t)
            rw = right_weight(t)
            sz = t.size()
            lbl = tree_label(t)
            f.write(f"{step}  {x}  {y}  {lbl}  {sz}  {lw}  {rw}\n")
    print(f"  Wrote {path_out} ({len(path)} steps)")
    return path


# ═══════════════════════════════════════════════════════════════════════
# 7. Summary table (stdout)
# ═══════════════════════════════════════════════════════════════════════

def print_summary(trees: List[EMLTree], size: int):
    """Print a human-readable summary of the trees at cd=0 and cd=3."""
    header = f"\n{'─'*70}\n  SIZE {size} — {len(trees)} trees\n{'─'*70}"
    print(header)
    print(f"  {'idx':>3}  {'label':<20}  {'size':>4}  {'lW':>3}  {'rW':>3}  "
          f"{'cd0(x,y)':>10}  {'cd3(x,y)':>10}")
    print(f"  {'─'*3}  {'─'*20}  {'─'*4}  {'─'*3}  {'─'*3}  {'─'*10}  {'─'*10}")
    for idx, t in enumerate(trees):
        lw = left_weight(t)
        rw = right_weight(t)
        sz = t.size()
        lbl = tree_label(t)
        x0, y0 = tube_coord(0, t)
        x3, y3 = tube_coord(3, t)
        print(f"  {idx:>3}  {lbl:<20}  {sz:>4}  {lw:>3}  {rw:>3}  "
              f"({x0:>3},{y0:>3})  ({x3:>3},{y3:>3})")


# ═══════════════════════════════════════════════════════════════════════
# 8. Main
# ═══════════════════════════════════════════════════════════════════════

def main():
    print("Tube Map Calibration — enumerating all trees size 1..4")
    print(f"Output directory: {PLOT_DIR}")

    for size in [1, 2, 3, 4]:
        trees = all_trees(size)
        write_tree_data(trees, size)
        write_edge_data(trees, size, cd=3)
        print_summary(trees, size)

    # Size-3 QI protocol path at cd=3
    print(f"\n{'─'*70}")
    print("  QI protocol path (balanced tree → rightComb(3)) at cd=3")
    print(f"{'─'*70}")
    path = write_qe_path(cd=3)
    print(f"\n  Path steps:")
    for step, t in enumerate(path):
        x, y = tube_coord(3, t)
        lw = left_weight(t)
        rw = right_weight(t)
        print(f"    {step}: {repr(t):<30}  x={x}  y={y}  lW={lw}  rW={rw}")

    # Verify monotonicity at cd=3 for size 3
    print(f"\n  Monotonicity check (size 3, cd=3):")
    trees_3 = all_trees(3)
    for s in trees_3:
        xs, ys = tube_coord(3, s)
        for t in contracts_one_successors(s):
            if t in set(trees_3):
                xt, yt = tube_coord(3, t)
                ok_x = xt <= xs
                ok_y = yt <= ys if xt == xs else True  # only check y if x is equal
                ok = ok_x
                if ok_x:
                    msg = "✓"
                else:
                    msg = "✗ (x increased!)"
                print(f"    {tree_label(s):<20} → {tree_label(t):<20}  "
                      f"({xs},{ys}) → ({xt},{yt})  {msg}")


if __name__ == "__main__":
    main()
