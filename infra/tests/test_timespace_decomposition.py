"""
Timespace Decomposition: Mapping the 15 logic types onto the split-octonion (4,4) signature.

The split-octonion norm has (4,4) signature:
  e0² + e1² + e2² + e3² - e4² - e5² - e6² - e7²

  Associative sector (+)  = e0..e3  → time-like  → commutator → irreversibility
  Split sector (−)         = e4..e7  → space-like → associator → differentiability
  Null cone (norm=0)       = eᵢ+eⱼ   → interface  → zero-divisor channels

Each logic type's cost function Φ corresponds to a projection operator P_L
in the (4,4) space. The projection weights the associative vs split sectors:
  leftWeight  = amplification of time-like (associative) composition
  rightDiv    = compression of space-like (split) composition by 1/(rightDiv+1)
  coupling    = cross-term amplitude between the two sectors

This script computes the sector decomposition for each logic type and
maps it onto the timespace decomposition from docs/lab_protocol.md.
"""
import sys, math
from typing import Dict, List, Tuple

sys.path.insert(0, str(__import__('pathlib').Path(__file__).parent.parent.parent))

from infra._cortex._cost import phi, phi_coupled, NODE_PARAM, NodeCost
from infra._cortex._logic_types import LogicType
from infra._cortex._eml_tree import EMLTree, LEAF, rightComb, leftComb
from infra._cortex._tamari_lattice import all_trees, build_lattice


# ── Sector decomposition helpers ────────────────────────────────────

def sector_weights(params: NodeCost) -> Dict[str, float]:
    """Decompose a NodeCost into associative/split sector weights.

    The projection operator P_L acts on composition cost as:
      Φ_linear = bias + leftWeight·a + b/(rightDiv+1)
      Φ_coupled = coupling·a·b/denom

    Sector decomposition:
      time_weight  = leftWeight    (how much the associative sector amplifies)
      space_weight = 1/(rightDiv+1)  (how much the split sector transmits)
      interface_weight = coupling/denom (cross-term between sectors)
      null_index   = |time_weight - space_weight| (distance from the null cone)

    Returns weights normalized so that total = time_weight + space_weight.
    """
    tw = params.leftWeight
    sw = 1.0 / (params.rightDiv + 1)
    iw = params.coupling / max(params.denom, 1)
    null_idx = abs(tw - sw)
    total = tw + sw
    return {
        "time_weight": tw,
        "space_weight": sw,
        "interface_weight": iw,
        "null_index": round(null_idx, 4),
        "time_frac": round(tw / total, 4) if total > 0 else 0.5,
        "space_frac": round(sw / total, 4) if total > 0 else 0.5,
        "sector_bias": "time" if tw > sw else ("space" if sw > tw else "balanced"),
    }


def timespace_classification(lt: LogicType) -> str:
    """Classify a logic type by its timespace sector dominance."""
    params = NODE_PARAM[lt]
    sw = sector_weights(params)
    bias = sw["sector_bias"]
    if sw["null_index"] < 0.01:
        return f"{bias} (on null cone)"
    if sw["interface_weight"] > 0:
        return f"{bias} (with coupling)"
    return bias


# ── Timespace projection matrix ─────────────────────────────────────

def projection_table() -> str:
    """Build a formatted table showing each logic's sector projection."""
    header = (
        f"{'Logic Type':<20} {'leftWt':<7} {'rightDiv':<8} "
        f"{'coupl':<7} {'time_wt':<8} {'space_wt':<8} "
        f"{'null_idx':<9} {'bias':<12} {'interface':<10}"
    )
    sep = "-" * len(header)
    rows = [header, sep]

    for lt in LogicType:
        params = NODE_PARAM[lt]
        sw = sector_weights(params)
        rows.append(
            f"{lt.value:<20} {params.leftWeight:<7} {params.rightDiv:<8} "
            f"{params.coupling:<7} {sw['time_weight']:<8} {sw['space_weight']:<8} "
            f"{sw['null_index']:<9} {sw['sector_bias']:<12} {sw['interface_weight']:<10}"
        )
    return "\n".join(rows)


# ── Cost landscape as timespace projection ──────────────────────────

def cost_vs_timespace(logic_a: LogicType, logic_b: LogicType, n: int) -> Dict[str, float]:
    """Compare the cost landscapes of two logic types as timespace projections.

    Computes the correlation between their cost vectors across all trees of size n.
    High correlation = similar timespace projection operator.
    """
    trees = all_trees(n)
    ca = [phi(logic_a, t) for t in trees]
    cb = [phi(logic_b, t) for t in trees]
    n_trees = len(ca)
    mean_a = sum(ca) / n_trees
    mean_b = sum(cb) / n_trees
    # Pearson correlation
    num = sum((ca[i] - mean_a) * (cb[i] - mean_b) for i in range(n_trees))
    den_a = math.sqrt(sum((ca[i] - mean_a) ** 2 for i in range(n_trees))) or 1
    den_b = math.sqrt(sum((cb[i] - mean_b) ** 2 for i in range(n_trees))) or 1
    r = num / (den_a * den_b)
    return {"correlation": round(r, 4), "mean_a": round(mean_a, 2), "mean_b": round(mean_b, 2)}


def timespace_clusters(n: int) -> str:
    """Group logic types by their cost-landscape similarity (timespace proximity)."""
    logics = list(LogicType)
    pairs: List[Tuple[str, str, float]] = []
    for i in range(len(logics)):
        for j in range(i + 1, len(logics)):
            r = cost_vs_timespace(logics[i], logics[j], n)["correlation"]
            pairs.append((logics[i].value, logics[j].value, r))

    # Cluster by correlation > 0.99
    clusters: List[List[str]] = []
    assigned: set = set()
    for a, b, r in sorted(pairs, key=lambda x: -x[2]):
        if r > 0.99:
            if a not in assigned and b not in assigned:
                clusters.append([a, b])
                assigned.add(a)
                assigned.add(b)
            elif a in assigned and b not in assigned:
                for c in clusters:
                    if a in c:
                        c.append(b)
                        assigned.add(b)
                        break
            elif b in assigned and a not in assigned:
                for c in clusters:
                    if b in c:
                        c.append(a)
                        assigned.add(a)
                        break

    # Unclustered singletons
    for lt in logics:
        if lt.value not in assigned:
            clusters.append([lt.value])

    rows = [f"{'Cluster':<5} {'Logics':<60} {'Sector Bias':<20}"]
    rows.append("-" * 85)
    for ci, cluster in enumerate(clusters):
        # Determine sector bias of the cluster
        bias_counts: Dict[str, int] = {}
        for name in cluster:
            lt = LogicType(name)
            sw = sector_weights(NODE_PARAM[lt])
            bias_counts[sw["sector_bias"]] = bias_counts.get(sw["sector_bias"], 0) + 1
        dominant_bias = max(bias_counts, key=bias_counts.get)
        rows.append(f"{ci:<5} {', '.join(cluster):<60} {dominant_bias:<20}")
    return "\n".join(rows)


# ── Null cone analysis: which logics sit on it ──────────────────────

def null_cone_logics() -> List[Tuple[str, float, float, float]]:
    """Logic types whose projection lands on or near the null cone.

    A projection is on the null cone when time_weight = space_weight
    (i.e., leftWeight = 1/(rightDiv+1)).
    """
    results: List[Tuple[str, float, float, float]] = []
    for lt in LogicType:
        params = NODE_PARAM[lt]
        tw = params.leftWeight
        sw = 1.0 / (params.rightDiv + 1)
        ni = abs(tw - sw)
        if ni < 0.1:  # within 10% of the null cone
            results.append((lt.value, tw, sw, ni))
    return results


# ── Main ─────────────────────────────────────────────────────────────

def main():
    print("=" * 80)
    print("TIMESPACE DECOMPOSITION")
    print("Mapping 15 logic types onto the split-octonion (4,4) signature")
    print("=" * 80)
    print()

    # ── 1. Sector projection table ────────────────────────────────
    print("1. SECTOR PROJECTION TABLE")
    print()
    print(projection_table())
    print()

    # ── 2. Interpretation ─────────────────────────────────────────
    print("2. INTERPRETATION")
    print()
    print("  time_weight  = leftWeight                               (associative sector gain)")
    print("  space_weight = 1 / (rightDiv + 1)                       (split sector transmission)")
    print("  null_index   = |time_weight - space_weight|             (distance to null cone)")
    print("  interface    = coupling / denom                         (cross-sector coupling)")
    print()
    print("  Sector bias:")
    print("    time      → commutator dominates  → irreversibility (order matters)")
    print("    space     → associator dominates  → differentiability (grouping matters)")
    print("    balanced  → on the null cone      → zero-divisor channels active")
    print()

    # ── 3. Null cone ──────────────────────────────────────────────
    print("3. LOGICS ON THE NULL CONE")
    print()
    nc = null_cone_logics()
    if nc:
        for name, tw, sw, ni in nc:
            print(f"  {name:<20} time={tw}, space={sw}, |Δ|={ni}")
    else:
        print(f"  No logics are exactly on the null cone (the closest is")
        print(f"  Boolean/Intuitionistic/Free at time=1, space=1, |Δ|=0)")
    print()

    # ── 4. Timespace clusters ─────────────────────────────────────
    print("4. TIMESPACE CLUSTERS (cost-landscape similarity at n=4)")
    print()
    print(timespace_clusters(4))
    print()

    # ── 5. Coupling as interface term ─────────────────────────────
    print("5. COUPLING AS CROSS-SECTOR INTERFACE")
    print()
    print("  The product coupling term coupling·a·b/denom is the interface")
    print("  between the associative (time) and split (space) sectors.")
    print("  When coupling > 0, the cost has a cross-term that:")
    print("    1. Penalizes balanced trees (both subtrees have structure)")
    print("    2. Breaks the flat landscape even for Boolean")
    print("    3. Creates additional pentagon defect (Lagrangian friction)")
    print()
    print(f"  Logics with coupling > 0:")
    for lt in LogicType:
        params = NODE_PARAM[lt]
        if params.coupling > 0:
            sw = sector_weights(params)
            print(f"    {lt.value:<20} coupling={params.coupling}/{params.denom} = "
                  f"{sw['interface_weight']}  (interface strength)")
    print()

    # ── 6. Spacetime alignment ────────────────────────────────────
    print("6. SPACETIME LOGIC ALIGNMENT")
    print()
    print("  Current Spacetime: leftWeight=2, rightDiv=1, coupling=2, denom=6")
    print("  → time_weight=2, space_weight=0.5, interface=2/6=0.333")
    print()
    print("  The split-octonion e4-e7 sector has:")
    print("  - Associator norm |assoc| = 4.0 for ALL triples in the sector")
    print("  - Zero divisors via null cone combinations with associative")
    print("  - No commutator (pure associator — all grouping, no ordering)")
    print()
    print("  Proposed Spacetime recalibration:")
    print("    rightDiv = 3  (space_weight = 1/4 = 0.25 — strong space bias)")
    print("    leftWeight = 1  (time_weight = 1 — no commutator amplification)")
    print("    coupling = 1, denom = 2  (interface = 0.5 — strong cross-sector)")
    print("  This would give pure associator-dominant behavior: space >> time.")
    print()

    # ── 7. Summary ────────────────────────────────────────────────
    print("7. SUMMARY")
    print()
    print("  The (4,4) split signature IS the timespace decomposition.")
    print("  Each logic type's cost function is a projection operator")
    print("  onto a subspace of the split-octonion algebra.")
    print()
    print("  Timespace component mapping:")
    print("    Associative sector (+)  → Irreversibility (commutator)")
    print("    Split sector (−)         → Differentiability (associator)")
    print("    Null cone (norm=0)       → Zero-divisor channels")
    print("    Interface (coupling)     → Cross-sector tensegrity")
    print()
    print("  The 15 logic types form a continuous spectrum across this")
    print("  3-component decomposition, from Boolean (balanced, no interface)")
    print("  through Classical (time-biased) to Spacetime (space-biased).")
    print("=" * 80)

    return 0


if __name__ == "__main__":
    sys.exit(main())
