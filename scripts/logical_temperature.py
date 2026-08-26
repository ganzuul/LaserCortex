#!/usr/bin/env python3
"""Logical Temperature — numerical mirror of LogicalTemperature.lean.

Computes the Boltzmann ensemble over CD steps {0..7} and the Landauer-
calibrated barrier-equivalent temperatures. Pure stdlib; no side effects.

Lean cross-refs:
  frictionDensity      -> LaserCortex/Friction.lean   (authoritative Γ)
  weight               -> LaserCortex/LogicalTemperature.lean (exp(-βΓ))
  barrierEquivalentTemperature -> Landauer calibration section

Usage:
    python3 scripts/logical_temperature.py
"""

from __future__ import annotations

import math
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_here, ".."))          # repo root (infra.*)
sys.path.insert(0, os.path.join(_here, "..", "infra"))  # _cortex.*
from _cortex._eml_tree import EMLTree  # noqa: E402

# ── Authoritative energy functional (mirror of Friction.lean) ────────────
# NOTE: this is the CD-step Γ, NOT the dimension_index proxy in
# infra/_cortex/_wfc.py::friction_density. See lab note 039 for the audit.

STRUT_WEIGHT = 4  # strut_weight_eq_four


def assoc_defect(k: int) -> int:
    return 0 if k <= 2 else STRUT_WEIGHT


def comm_defect(k: int) -> int:
    return k


def friction_density(k: int) -> int:
    """Γ_k = k + strut_weight · assocDefect(k)."""
    return comm_defect(k) + STRUT_WEIGHT * assoc_defect(k)


# ── Boltzmann ensemble ───────────────────────────────────────────────────

BETA = 1.0  # the implicit β = 1 of _wfc.py::_logic_weight

K_MAX = 7  # ensemble slice {0..K}


def weight(k: int, beta: float = BETA) -> float:
    return math.exp(-beta * friction_density(k))


def partition_function(k_max: int = K_MAX, beta: float = BETA) -> float:
    return sum(weight(k, beta) for k in range(k_max + 1))


# ── Landauer calibration ─────────────────────────────────────────────────

T_OP = 300.0        # K, room-temperature substrate
K_B_J_PER_K = 1.380649e-23  # J/K, SI exact
E_CHARGE = 1.602176634e-19  # C, SI exact
LN2 = math.log(2)


def landauer_energy_per_unit_j() -> float:
    """Joules per friction unit: k_B·T_op·ln 2."""
    return K_B_J_PER_K * T_OP * LN2


def barrier_temperature(k: int) -> float:
    """T_barrier(k) = Γ_k · T_op · ln 2  (Kelvin)."""
    return friction_density(k) * T_OP * LN2


REGIME = {
    0: "Classical (vacuum)",
    1: "Fuzzy",
    2: "Intuitionistic",
    3: "Quantum (critical)",
    4: "Paraconsistent",
    5: "beyond (sedenion)",
    6: "beyond",
    7: "beyond",
}

# ── Full logic temperature map ───────────────────────────────────────────
# Mirror of LogicName/logicCd in LogicalTemperature.lean §7, which mirrors
# infra/_cortex/_logic_types.py::LogicType.cd_step. All three agree.

LOGIC_CD = {
    "classical":      0,
    "boolean":        0,
    "fuzzy":          1,
    "many_valued":    1,
    "temporal":       1,
    "deontic":        1,
    "epistemic":      1,
    "intuitionistic": 2,
    "quantum":        3,
    "relevance":      3,
    "infinitary":     3,
    "modal":          3,
    "spacetime":      3,
    "paraconsistent": 4,
    "free":           4,
}


def logic_temperature(logic: str) -> float:
    """T = Γ_cd(logic) · T_op · ln 2."""
    return barrier_temperature(LOGIC_CD[logic])


def critical_point_census() -> list[tuple[int, int]]:
    """Increments ΔΓ(k) = Γ_{k+1} − Γ_k over the ladder.

    The Lean theorem `gamma_increment` proves every increment is 1 except
    the single jump of 17 at k = 2 (commutator +1, associator onset +16):
    CD 3 is the unique thermodynamic critical point of Γ.
    """
    return [(k, friction_density(k + 1) - friction_density(k))
            for k in range(K_MAX)]


# ── Phase diagram composition (mirror of SubdivisionClosure §9) ──────────

def right_spine(t) -> int:
    """Depth of the rightmost leaf (coupling term of the composition law)."""
    if t.is_leaf:
        return 0
    return 1 + right_spine(t.right)


def _dcstep(t) -> int:
    """Structural mirror of Lean dcStep (rotations to right-comb)."""
    if t.is_leaf:
        return 0
    if t.left.is_leaf:
        return _dcstep(t.right)
    return 1 + _dcstep(EMLTree.node(t.left.left,
                                     EMLTree.node(t.left.right, t.right)))


def _all_trees(n):
    if n == 0:
        yield EMLTree.leaf()
        return
    for i in range(n):
        for l in _all_trees(i):
            for r in _all_trees(n - 1 - i):
                yield EMLTree.node(l, r)


def run_composition_law_check(max_size: int = 5) -> None:
    """Exhaustive verification of the composition law."""
    L = EMLTree.leaf()
    N = EMLTree.node
    passed = total = 0
    sup_bad = eq_bad = 0
    for nl in range(max_size):
        for l in _all_trees(nl):
            for nr in range(max_size - nl):
                for r in _all_trees(nr):
                    total += 1
                    d = _dcstep(N(l, r))
                    pred = _dcstep(l) + _dcstep(r) + right_spine(l)
                    if d == pred:
                        passed += 1
                    if d < _dcstep(l) + _dcstep(r):          # superadditivity
                        sup_bad += 1
                    if (d == _dcstep(l) + _dcstep(r)) != l.is_leaf:  # eq iff
                        eq_bad += 1
    print()
    print("═" * 78)
    print("PHASE DIAGRAM COMPOSITION LAW (SubdivisionClosure §9)")
    print("═" * 78)
    print(f"  dcStep(Node l r) = dcStep l + dcStep r + rightSpine l : "
          f"{passed}/{total} OK")
    print(f"  superadditivity violations: {sup_bad}   "
          f"equality-iff-left-Leaf violations: {eq_bad}")
    print("  ⇒ energy/temperature are superadditive under composition;")
    print("    coupling flows through the left subsystem's output chain.")


def main() -> None:
    Z = partition_function()

    print("═" * 78)
    print("LOGICAL TEMPERATURE LADDER — CD steps 0..{}, β = {}".format(K_MAX, BETA))
    print("═" * 78)
    header = (
        f"{'cd':>3} {'regime':<20} {'Γ_k':>4} {'weight exp(-βΓ)':>16} "
        f"{'P(k)':>10} {'T_barrier (K)':>14}"
    )
    print(header)
    print("-" * 78)
    for k in range(K_MAX + 1):
        p = weight(k) / Z
        t = barrier_temperature(k)
        print(
            f"{k:>3} {REGIME[k]:<20} {friction_density(k):>4} "
            f"{weight(k):>16.6e} {p:>10.6f} {t:>14.2f}"
        )
    print("-" * 78)
    print(f"Partition function Z({K_MAX}) = {Z:.6f}")
    print()

    # ── Headline results ────────────────────────────────────────────────
    t_para = barrier_temperature(4)
    e_para_ev = friction_density(4) * landauer_energy_per_unit_j() / E_CHARGE

    print("HEADLINE (Landauer anchor, T_op = {} K):".format(int(T_OP)))
    print(
        "  T(paraconsistent) = Γ_4 · T_op · ln2 "
        f"= 20 × {int(T_OP)} × {LN2:.6f} ≈ {t_para:,.2f} K"
    )
    print(f"  E(paraconsistent barrier) ≈ {e_para_ev:.4f} eV")
    print(f"  Silicon bandgap anchor: 13,200 K ({e_para_ev / 1.14:.1%} of E_g = 1.14 eV)")
    print()
    print("CALIBRATION-FREE RATIOS (survive any anchor change):")
    g2 = friction_density(2)
    print(f"  Γ_4 / Γ_2 = {friction_density(4) / g2:g}   (phase-change ratio > 9)")
    print(f"  Γ_3 / Γ_2 = {friction_density(3) / g2:g}")
    print(f"  P(classical)/P(paraconsistent) at β=1: {weight(0) / weight(4):.3e}")
    print()
    print("LEAN CONSISTENCY CHECK:")
    print(f"  frictionDensity 4 == 20 : {friction_density(4) == 20}"
          "  (theorem paraconsistent_friction)")
    print(f"  frictionDensity 3 == 19 : {friction_density(3) == 19}"
          "  (Friction.lean frictionDensity_jump_at_cd3)")
    print(f"  frictionDensity 2 == 2  : {friction_density(2) == 2}"
          "  (theorem frictionDensity_at_cl11_boundary)")

    # Known divergence flag (lab note 045 §audit):
    # infra/_cortex/_wfc.py::friction_density uses dimension_index proxy.
    print()
    print("⚠ DIVERGENCE FLAG: _wfc.py's LogicType-level friction_density uses")
    print("  a dimension_index proxy (min(dim,7)+16), not this Γ. The CD-step")
    print("  Γ here is authoritative for all proven structure.")

    # ── Full logic temperature map (Lean §7) ────────────────────────────
    print()
    print("═" * 78)
    print("FULL LOGIC TEMPERATURE MAP — all 15 named logics, Landauer anchor")
    print("═" * 78)
    rows = sorted(LOGIC_CD.items(), key=lambda kv: (kv[1], kv[0]))
    print(f"{'logic':<16} {'cd':>3} {'Γ':>4} {'T_barrier (K)':>14}  sector")
    print("-" * 78)
    for name, k in rows:
        sector = "associative" if k <= 2 else ("split (critical)" if k == 3
                                               else "split (deep)")
        t = logic_temperature(name)
        print(f"{name:<16} {k:>3} {friction_density(k):>4} {t:>14,.2f}  {sector}")
    print("-" * 78)
    t_modal = logic_temperature("modal")
    print(f"  T(modal) = 19 · T_op · ln2 ≈ {t_modal:,.2f} K "
          "(theorem modal_barrier_temperature)")
    print(f"  Modal sits exactly AT the critical point CD 3 "
          "(modal_at_critical_point).")
    print(f"  Hottest named rung shared by paraconsistent + free "
          f"(logicTemp_le_paraconsistent).")

    # ── Critical-point census (Lean §8) ─────────────────────────────────
    print()
    print("CRITICAL-POINT CENSUS of Γ along the ladder:")
    census = critical_point_census()
    jumps = [(k, d) for k, d in census if d != 1]
    for k, d in census:
        flag = "  ← JUMP (associator onset)" if d != 1 else ""
        print(f"  ΔΓ({k}→{k+1}) = {d:>2}{flag}")
    assert len(jumps) == 1 and jumps[0] == (2, 17), "unique-jump invariant broke"
    print(f"  Unique jump: exactly one ({jumps[0]}); theorem gamma_increment.")
    print(f"  ⇒ CD 3 is the unique thermodynamic critical point; every other")
    print(f"    rung costs precisely one commutator unit T_op·ln2 ≈ "
          f"{T_OP * LN2:,.2f} K.")

    # ── Phase diagram composition law (SubdivisionClosure §9) ───────────
    run_composition_law_check()

    # ── Phase diagram of composable logics (AMM §8) ─────────────────────
    run_phase_diagram()

    # ── Loose coupling / institutional triad (AMM §9) ───────────────────
    run_loose_coupling_sweep()


def _right_comb(n: int):
    L = EMLTree.leaf()
    t = L
    for _ in range(n):
        t = EMLTree.node(L, t)
    return t


def _left_comb(n: int):
    L = EMLTree.leaf()
    t = L
    for _ in range(n):
        t = EMLTree.node(t, L)
    return t


def _market_type(cd: int, tree, reserve_b: int) -> str:
    """Mirror of AMM.decideMarketType: O=open, C=closed, P=paradox."""
    cost = _dcstep(tree) * friction_density(cd)
    if cost == 0:
        return "O"
    return "C" if cost < reserve_b else "P"


def run_phase_diagram(reserve_b: int = 10) -> None:
    """The computable phase diagram of composable logics.

    Rows: the 15 named logics (their CD step sets friction density).
    Columns: routes — closed markets (right combs), tense markets
    (left combs), and grafts of two closed markets.
    Phases: O = openMarket (vacuum), C = closedMarket (liquid),
    P = paradoxMarket (superheated). Mirror of AMM.logicMarketType.
    """
    L = EMLTree.leaf()
    N = EMLTree.node
    routes = {
        "leaf":            L,
        "rc1":             _right_comb(1),
        "rc4":             _right_comb(4),
        "lc3":             _left_comb(3),
        "rc2+rc2":         N(_right_comb(2), _right_comb(2)),
        "rc3+rc3":         N(_right_comb(3), _right_comb(3)),
        "lc2*lc2*rc1":     N(_left_comb(2), N(_left_comb(2), L)),
    }
    print()
    print("═" * 78)
    print(f"PHASE DIAGRAM OF COMPOSABLE LOGICS "
          f"(AMM §8, reserveB = {reserve_b})")
    print("═" * 78)
    print(f"{'logic':<16} {'cd':>3} {'γ':>3} " +
          " ".join(f"{name:>10}" for name in routes))
    print("-" * 78)
    rows = sorted(LOGIC_CD.items(), key=lambda kv: kv[1])
    for name, k in rows:
        g = friction_density(k)
        cells = " ".join(
            f"{_market_type(k, tree, reserve_b):>10}" for tree in routes.values())
        print(f"{name:<16} {k:>3} {g:>3} {cells}")
    print("-" * 78)
    print("  O = openMarket (vacuum, T=0)   C = closedMarket (liquid)")
    print("  P = paradoxMarket (superheated)")
    print("  Theorems behind it: classical_logic_market_always_open,")
    print("  composing_closed_markets_costs, paradox_dominance,")
    print("  crossImpactTree_eq_rightSpine_mul.")

    # Cross-impact closed-form spot check
    ok = all(
        _dcstep(N(l, r)) * friction_density(3)
          - (_dcstep(l) + _dcstep(r)) * friction_density(3)
        == right_spine(l) * friction_density(3)
        for l in _all_trees(3) for r in _all_trees(3))
    print(f"  cross-impact = rightSpine(l)·γ at cd=3: "
          f"{'OK' if ok else 'FAILED'}")


def _loose_cost(cd: int, num: int, den: int, l, r) -> int:
    """Mirror of SubdivisionClosure.looseCost (λ = num/den trust discount)."""
    g = friction_density(cd)
    return (_dcstep(l) + _dcstep(r)) * g + num * right_spine(l) * g // den


def _loose_market_type(cd: int, num: int, den: int, l, r,
                       reserve_b: int) -> str:
    """Mirror of AMM.looseMarketType."""
    cost = _loose_cost(cd, num, den, l, r)
    if cost == 0:
        return "O"
    return "C" if cost < reserve_b else "P"


# The institutional triad: temporal accumulation (P2), fuzzy grading (P1),
# deontic threshold revision (P6). All three host-logics sit at CD 1 —
# same heat (~208 K), different Hopf direction (AMM.institutional_triad_friction).
TRIAD = ("temporal", "fuzzy", "deontic")


def run_loose_coupling_sweep(reserve_b: int = 10) -> None:
    """Loose-coupling phase sweep over the institutional triad.

    Strict grafting pays the full coupling tax rightSpine(l)·γ; loosening
    discounts it by λ = num/den ≤ 1 and the paradox boundary retreats into
    a risk-taking window. Verified empirically:
      1. RESCUE WITHOUT DAMNATION (AMM.loose_never_damns): loose paradox
         ⇒ strict paradox, for every pair, every λ.
      2. RISK ENVELOPE (AMM.rescue_envelope_bounded_by_coupling):
         strict − loose ≤ rightSpine(l)·γ, with equality at λ = 1.
      3. TRIAD FRICTION: all three logics share γ(cd=1).
    """
    den_max = 4
    triad_cd = {name: LOGIC_CD[name] for name in TRIAD}
    gammas = {friction_density(k) for k in triad_cd.values()}

    print()
    print("═" * 78)
    print(f"LOOSE-COUPLING PHASE SWEEP — INSTITUTIONAL TRIAD "
          f"(AMM §9, reserveB = {reserve_b})")
    print("═" * 78)
    print(f"  triad friction densities: "
          f"{ {n: friction_density(k) for n, k in triad_cd.items()} }"
          f"  (shared heat: one value ⇒ institutional_triad_friction OK)"
          if len(gammas) == 1 else "  TRIAD FRICTION MISMATCH!")

    # Grafts of two closed markets in the triad's own algebra (cd = 1).
    # NOTE dcStep(rightComb n) = 0: a closed market's whole friction sits
    # in its output chain, so strict graft cost = rightSpine(l)·γ and the
    # boundary is crossed by LONG chains — exactly the institutional case
    # (temporal accumulation = long blame chains).
    rc_a, rc_b = _right_comb(12), _right_comb(4)
    grafts = {
        "temporal⊗fuzzy":   EMLTree.node(rc_a, rc_b),
        "fuzzy⊗deontic":    EMLTree.node(rc_b, rc_a),
        "deontic⊗temporal": EMLTree.node(rc_a, rc_a),
    }
    cd = LOGIC_CD["temporal"]  # shared by the whole triad

    print()
    print(f"  {'λ':>5} | " +
          " ".join(f"{name:>18}" for name in grafts))
    print("  " + "-" * 66)
    for num in range(den_max + 1):
        lam = num / den_max
        cells = [
            _loose_market_type(cd, num, den_max, t.left, t.right, reserve_b)
            for t in grafts.values()]
        print(f"  {lam:>5.2f} | " +
              " ".join(f"{c:>18}" for c in cells))
    print("  " + "-" * 66)
    print("  (λ=1 reproduces the strict phase; λ<1 opens the risk window)")

    # Exhaustive safety check across ALL small-tree pairs and λ-grid:
    # loose paradox ⇒ strict paradox (rescue without damnation), and the
    # risk envelope strict − loose ≤ rightSpine(l)·γ holds exactly.
    damn_violations = envelope_violations = rescued = 0
    pairs = [(l, r) for l in _all_trees(4) for r in _all_trees(4)]
    # plus long-chain combs, where the boundary is actually crossed:
    pairs += [(_right_comb(a), _right_comb(b))
              for a in range(0, 16) for b in range(4)]
    for num in range(den_max + 1):
        for l, r in pairs:
            s_cost = (_dcstep(l) + _dcstep(r)) * friction_density(cd) \
                + right_spine(l) * friction_density(cd)
            lo_cost = _loose_cost(cd, num, den_max, l, r)
            if _market_type(cd, EMLTree.node(l, r), reserve_b) == "P" \
                    and lo_cost < reserve_b and lo_cost > 0:
                rescued += 1
            if lo_cost >= reserve_b and lo_cost > 0 \
                    and s_cost < reserve_b:
                damn_violations += 1
            if s_cost - lo_cost > right_spine(l) * friction_density(cd):
                envelope_violations += 1
    total = len(pairs) * (den_max + 1)
    print(f"  exhaustive over {len(pairs)} pairs × λ∈{{0,…,1}} ({total} states):")
    print(f"    rescues (P→C/O under loosening):        {rescued}")
    print(f"    damnation violations (must be 0):       {damn_violations}")
    print(f"    risk-envelope violations (must be 0):   {envelope_violations}")
    verdict = "OK" if damn_violations == 0 and envelope_violations == 0 \
        else "FAILED"
    print(f"    ⇒ rescue-without-damnation: {verdict}")
    print("  Theorems behind it: AMM.loose_never_damns,")
    print("  AMM.rescue_envelope_bounded_by_coupling,")
    print("  AMM.institutional_triad_friction,")

    # Hooke-law spot check (boundary_retreat_linear_in_load): in the
    # quantized elastic regime (den | num·S) the retreat is EXACTLY
    # (1 − λ)·S; outside it, truncated division deviates by less than one
    # cost unit.
    hooke_ok = True
    for l, r in pairs:
        S = right_spine(l) * friction_density(cd)
        if S == 0:
            continue
        for num in range(den_max + 1):
            strict = (_dcstep(l) + _dcstep(r)) * friction_density(cd) + S
            loose = _loose_cost(cd, num, den_max, l, r)
            retreat = strict - loose
            expected = (1 - num / den_max) * S
            if (num * S) % den_max == 0:
                hooke_ok &= retreat == expected
            else:
                hooke_ok &= abs(retreat - expected) < 1.0
    print(f"    Hooke linearity retreat = (1−λ)·S: "
          f"{'OK' if hooke_ok else 'FAILED'}")


if __name__ == "__main__":
    main()
