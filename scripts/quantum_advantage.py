#!/usr/bin/env python3
r"""
quantum_advantage.py — compute and output data for gnuplot

Computes the quantum advantage in the Chu/CD‑homotopy framework:

  • Friction barrier Γ(k) = k + strut_weight · assocDefect(k)
    (proven in FrictionLagrangian.lean)
  • Chu pairing norm N(θ) = cos(θ) for a split-quaternion mode on S³
  • Standard QI phase-conjugating receiver SNR (scale-free)
  • Chu‑enhanced SNR with structural coupling factor

Physical anchor: Ta‑180m isomer at 75 keV (10–100 keV X‑ray range).
All results are dimensionless — the energy scale is an external parameter.
For a different isomer (e.g. Hf‑178m2 at 2.44 MeV), the algebraic framework
is identical; only the physical significance of the "keV" axis changes.

Output: data files in plots/ for gnuplot consumption.
"""

import math
import os

PLOT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "plots")
os.makedirs(PLOT_DIR, exist_ok=True)

# ── Verified algebraic constants ───────────────────────────────────────
STRUT_WEIGHT = 4       # SplitOctonionCost.strut_weight_eq_four
STRUT_WEIGHT_SQ = 16   # strut_weight * strut_weight

def assoc_defect(k: int) -> int:
    """assocDefect(k) = 0 if k ≤ 2 else 4."""
    return 0 if k <= 2 else STRUT_WEIGHT

def friction_density(k: int) -> int:
    """Γ(k) = k + strut_weight · assocDefect(k)."""
    return k + STRUT_WEIGHT * assoc_defect(k)

# ── Chu pairing on S³ ─────────────────────────────────────────────────
# Split quaternion x = (a,b,c,d) ∈ S³ parametrised by Hopf angles:
#   a = cos(θ/2)·cos(φ), b = cos(θ/2)·sin(φ)
#   c = sin(θ/2)·cos(ψ), d = sin(θ/2)·sin(ψ)
# Norm: N(x) = a² + b² - c² - d² = cos(θ)
def chu_norm(theta: float) -> float:
    """N(θ) = cos(θ). Returns −1 … +1."""
    return math.cos(theta)

# ── QI SNR formulas ───────────────────────────────────────────────────
def snr_classical(N_S: float) -> float:
    """Coherent-state shot-noise SNR per mode."""
    return N_S

def snr_pcr(N_S: float) -> float:
    """Phase-conjugating receiver SNR (standard QI, N_B = 0)."""
    return N_S + N_S*N_S / (1.0 + 2.0*N_S)

def snr_chu(N_S: float, theta: float) -> float:
    """
    Chu‑enhanced SNR:
      The joint measurement extracts correlation β(x, S(x)) = N(x).
      This modulates the entanglement utilisation term.
    """
    corr = abs(chu_norm(theta))          # |N(θ)| in [0, 1]
    return N_S + corr * N_S*N_S / (1.0 + 2.0*N_S)

def advantage_db(snr_q: float, snr_c: float) -> float:
    """Advantage in dB: 10·log₁₀(snr_q / snr_c)."""
    if snr_c <= 0 or snr_q <= 0:
        return 0.0
    return 10.0 * math.log10(snr_q / snr_c)

# ── Structural coupling advantage (friction gap) ──────────────────────
# The headroom = Γ₃ / Γ₂ = 19 / 2 = 9.8 dB
FRICTION_HEADROOM_DB = 10.0 * math.log10(friction_density(3) / friction_density(2))


# ═══════════════════════════════════════════════════════════════════════
# DATA FILES
# ═══════════════════════════════════════════════════════════════════════

# ─── 1. Friction barrier ─────────────────────────────────────────────
with open(os.path.join(PLOT_DIR, "friction_barrier.dat"), "w") as f:
    f.write("# k  Γ(k)  label\n")
    labels = ["CD₀ ℝ", "CD₁ ℂ", "CD₂ ℍ", "CD₃ 𝕆ˢ", "CD₄ 𝕊"]
    for k in range(5):
        f.write(f"{k}  {friction_density(k)}  {labels[k]}\n")

# ─── 2. Chu pairing norm on S³ ───────────────────────────────────────
N_THETA = 200
with open(os.path.join(PLOT_DIR, "chu_norm.dat"), "w") as f:
    f.write("# theta(rad)  N(theta)  |N(theta)|\n")
    for i in range(N_THETA + 1):
        th = math.pi * i / N_THETA
        n = chu_norm(th)
        f.write(f"{th:.6f}  {n:.8f}  {abs(n):.8f}\n")

# ─── 3. Quantum advantage vs N_S for various θ ───────────────────────
N_S_POINTS = 200
N_S_MIN = -3   # 10^-3
N_S_MAX = 2    # 10^2

thetas = [0.0, math.pi/6, math.pi/4, math.pi/3, math.pi/2]

with open(os.path.join(PLOT_DIR, "advantage_vs_ns.dat"), "w") as f:
    header = "# log10(N_S)  " + "  ".join(f"theta={t:.3f}" for t in thetas)
    f.write(header + "\n")
    for i in range(N_S_POINTS + 1):
        log_ns = N_S_MIN + (N_S_MAX - N_S_MIN) * i / N_S_POINTS
        N_S = 10.0 ** log_ns
        adv_std = advantage_db(snr_pcr(N_S), snr_classical(N_S))
        parts = [f"{log_ns:.6f}"]
        for th in thetas:
            adv_chu = advantage_db(snr_chu(N_S, th), snr_classical(N_S))
            parts.append(f"{adv_chu:.8f}")
        f.write("  ".join(parts) + "\n")

# ─── 4. Standard QI reference (undifferentiated from Chu at θ=0) ─────
with open(os.path.join(PLOT_DIR, "advantage_standard.dat"), "w") as f:
    f.write("# log10(N_S)  adv_std_dB  asymptotic(1.76dB)\n")
    for i in range(N_S_POINTS + 1):
        log_ns = N_S_MIN + (N_S_MAX - N_S_MIN) * i / N_S_POINTS
        N_S = 10.0 ** log_ns
        adv_std = advantage_db(snr_pcr(N_S), snr_classical(N_S))
        f.write(f"{log_ns:.6f}  {adv_std:.8f}\n")

# ─── 5. Combined: advantage heatmap for gnuplot pm3d ──────────────────
N_THETA_COMB = 60
N_NS_COMB = 120
with open(os.path.join(PLOT_DIR, "advantage_heatmap.dat"), "w") as f:
    f.write("# theta(rad)  log10(N_S)  adv_dB\n")
    for i in range(N_THETA_COMB + 1):
        th = math.pi * i / N_THETA_COMB
        for j in range(N_NS_COMB + 1):
            log_ns = N_S_MIN + (N_S_MAX - N_S_MIN) * j / N_NS_COMB
            N_S = 10.0 ** log_ns
            adv = advantage_db(snr_chu(N_S, th), snr_classical(N_S))
            f.write(f"{th:.6f}  {log_ns:.6f}  {adv:.8f}\n")
        f.write("\n")   # blank line for pm3d

# ─── 6. Structural advantage: friction gap as function of CD step ────
with open(os.path.join(PLOT_DIR, "structural_advantage.dat"), "w") as f:
    f.write("# k  Γ(k)  Γ_excess  Γ_ratio_dB\n")
    for k in range(5):
        gk = friction_density(k)
        g2 = friction_density(2)
        excess = gk - g2
        ratio_db = 10.0 * math.log10(gk / g2) if gk > 0 and g2 > 0 else 0.0
        f.write(f"{k}  {gk}  {excess}  {ratio_db:.6f}\n")

print(f"Data written to {PLOT_DIR}/")
print(f"Friction headroom:  Γ₃/Γ₂ = {friction_density(3)}/{friction_density(2)} "
      f"= {friction_density(3)/friction_density(2):.3f}  "
      f"= {FRICTION_HEADROOM_DB:.2f} dB")
print(f"Standard QI asymptotic advantage (N_S → ∞): "
      f"{advantage_db(snr_pcr(1e6), snr_classical(1e6)):.3f} dB")
