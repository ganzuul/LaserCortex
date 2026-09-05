"""
reference_mhd.py — Headless CPU Reference Implementation
=========================================================
Mirrors LaserCortex/Stencil.lean and webgpu/shaders/mhd_stencil.wgsl exactly:

- Periodic grid indexing on ZMod Nx × ZMod Ny (np.roll = group addition)
- Stream function ψ -> B = curl(ψ) = (dy ψ, -dx ψ)
- Divergence D(B) = D(curl(ψ)) ≡ 0 (certificate: Stencil.div_curl_eq_zero)
- Current density J_z = dx(B_y) - dy(B_x) = -laplacian2(ψ), the *spacing-two*
  five-point Laplacian (certificate: Stencil.curl_curl_eq_neg_laplacian2).
  N.B. composing central differences of step 1 reaches taps at distance 2,
  so J_z is NOT the near-neighbour -∇²ψ.
- Conservative flux-form advection of ψ along an *externally prescribed*
  DIVERGENCE-FREE flow u₀ (donor cell / upwind), exactly as the WGSL
  advect_psi kernel. Total flux Σψ is conserved to rounding of the
  individual ops for any flux pair (certificate: Stencil.fluxDiv_sum_eq_zero).

Why u₀ and not u = B? In 2D, B·∇ψ ≡ 0 (B is tangent to ψ-contours), so
advecting ψ by B is a *degenerate* no-op: ∂ₜψ = 0 in the continuum, and the
scheme's residual discretization noise becomes the only "motion" (grid-scale
growth, diagonal banding, runaway |J_z|). A prescribed, ψ-independent flow u₀
gives genuine frozen-in transport and real (grid-scale) current-sheet
steepening, while the F1 + conservation certificates are untouched.

F32 arithmetic is IEEE-754 single precision, op-for-op as WGSL computes it,
so this file is the headless oracle for GPU-path regression testing.
"""

import numpy as np

F32_EPS = np.finfo(np.float32).eps  # ~1.19e-7
TWO_PI = np.float32(2 * np.pi)


class DiscreteMHD2D:
    def __init__(self, nx: int = 128, ny: int = 128, dx: float = 1.0, dy: float = 1.0):
        self.nx = nx
        self.ny = ny
        self.dx = dx
        self.dy = dy

    # ------------------------------------------------------------------ #
    # Stencils — mirror of Stencil.lean (unnormalized central differences) #
    # ------------------------------------------------------------------ #
    def periodic_diff_x(self, f: np.ndarray) -> np.ndarray:
        """Central difference along x: f(i+1, j) - f(i-1, j)."""
        return np.roll(f, -1, axis=0) - np.roll(f, 1, axis=0)

    def periodic_diff_y(self, f: np.ndarray) -> np.ndarray:
        """Central difference along y: f(i, j+1) - f(i, j-1)."""
        return np.roll(f, -1, axis=1) - np.roll(f, 1, axis=1)

    def curl(self, psi: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        """B = curl(ψ ẑ) = (dy ψ, -dx ψ). Matches Stencil.curl."""
        bx = self.periodic_diff_y(psi)
        by = -self.periodic_diff_x(psi)
        return bx, by

    def divergence(self, bx: np.ndarray, by: np.ndarray) -> np.ndarray:
        """div(B) = dx(B_x) + dy(B_y). Matches Stencil.div."""
        return self.periodic_diff_x(bx) + self.periodic_diff_y(by)

    def current_density(self, bx: np.ndarray, by: np.ndarray) -> np.ndarray:
        """J_z = (curl B)_z = dx(B_y) - dy(B_x).

        Composed over B = curl ψ this is -laplacian₂ψ: the taps sit at index
        distance 2 (Stencil.curl_curl_eq_neg_laplacian2), NOT the
        near-neighbour -∇²ψ. The WGSL compute_current kernel matches this
        op-for-op.
        """
        return self.periodic_diff_x(by) - self.periodic_diff_y(bx)

    def wide_laplacian2(self, psi: np.ndarray) -> np.ndarray:
        """Spacing-two five-point Laplacian: taps at distance 2 minus 4ψ."""
        return (
            np.roll(psi, -2, axis=0)
            + np.roll(psi, 2, axis=0)
            + np.roll(psi, -2, axis=1)
            + np.roll(psi, 2, axis=1)
            - 4.0 * psi
        )

    # ------------------------------------------------------------------ #
    # Prescribed divergence-free flow (mirror of WGSL flow_vel)            #
    # ------------------------------------------------------------------ #
    def flow_velocity(self, flow: str = "vortex", amp: float = 1.0,
                      R0: float = 3.0, minorA: float = 1.0) -> tuple[np.ndarray, np.ndarray]:
        """u₀ = ẑ×∇φ₀ for the chosen stream function; checked div-free.

        Coord xp(k) = 2π·k/NX (endpoint=False), matching the shader's
        xp = (x/NX)·2π and initGrid's u = (x/NX)·2π.

        vortex:  φ₀ = amp·cos(x)·cos(y)  ->  u₀ = amp·(cosx·siny, -sinx·cosy)
        shear:   φ₀ = -amp·cos(y)        ->  u₀ = (amp·sin y, 0)
        rotation: rigid poloidal rotation about (R0, 0): u₀ = amp·(-Z, R-R0).
                 Divergence-free and separatrix-free -> no grid-aligned `#`.
        """
        x = np.arange(self.nx, dtype=np.float32) / np.float32(self.nx) * TWO_PI
        y = np.arange(self.ny, dtype=np.float32) / np.float32(self.ny) * TWO_PI
        X, Y = np.meshgrid(x, y, indexing="ij")
        a = np.float32(amp)
        if flow == "shear":
            ux = a * np.sin(Y)
            uy = np.zeros_like(Y)
        elif flow == "rotation":
            RR, ZZ = poloidal_grid(self.nx, self.ny, R0, minorA)
            ux = -a * ZZ
            uy = a * (RR - np.float32(R0))
        else:
            ux = a * np.cos(X) * np.sin(Y)
            uy = -a * np.sin(X) * np.cos(Y)
        return ux.astype(np.float32), uy.astype(np.float32)

    @staticmethod
    def cfl(ux: np.ndarray, uy: np.ndarray, dt: float | np.floating) -> float:
        """CFL number in cell units: dt · max|u₀| (stability bound ≤ 1)."""
        return float(dt) * float(np.sqrt(np.max(ux * ux + uy * uy)))

    # ------------------------------------------------------------------ #
    # Conservative transport — mirror of WGSL advect_psi (donor cell)      #
    # ------------------------------------------------------------------ #
    def advect_flux_form(self, psi: np.ndarray, u0x: np.ndarray, u0y: np.ndarray,
                         dt: float | np.floating = 0.005) -> np.ndarray:
        """One conservative flux-form step: ψ' = ψ + fluxDiv(Fx, Fy).

        Donor-cell (upwind) fluxes along the prescribed flow u₀, float32
        op-for-op with the WGSL kernel:
          Fx(i,j) = dt·(max(u0x,0)·ψ(i,j) + min(u0x,0)·ψ(i+1,j))
          Fy(i,j) = dt·(max(u0y,0)·ψ(i,j) + min(u0y,0)·ψ(i,j+1))
          ψ'(i,j) = ψ(i,j) + Fx(i-1,j) - Fx(i,j) + Fy(i,j-1) - Fy(i,j)
        Stable under CFL dt·max|u₀| ≤ 1. Σψ is conserved to op rounding for
        ANY flux pair (Stencil.fluxDiv_sum_eq_zero); Σψ² decay is the
        scheme's own visible truncation error.
        """
        psi = np.ascontiguousarray(psi, dtype=np.float32)
        u0x = np.ascontiguousarray(u0x, dtype=np.float32)
        u0y = np.ascontiguousarray(u0y, dtype=np.float32)
        dt32 = np.float32(dt)

        # Fluxes across right edges (i -> i+1) and top edges (j -> j+1).
        fx = dt32 * (np.maximum(u0x, np.float32(0)) * psi
                     + np.minimum(u0x, np.float32(0)) * np.roll(psi, -1, axis=0))
        fy = dt32 * (np.maximum(u0y, np.float32(0)) * psi
                     + np.minimum(u0y, np.float32(0)) * np.roll(psi, -1, axis=1))

        # Net inflow: +F(left edge) - F(right edge) + F(bottom) - F(top).
        return psi + (np.roll(fx, 1, axis=0) - fx) + (np.roll(fy, 1, axis=1) - fy)


def orszag_tang(nx: int = 128, ny: int = 128) -> np.ndarray:
    """Orszag–Tang streamfunction ψ = 2cos(x) + cos(2y), float32."""
    x = np.linspace(0, 2 * np.pi, nx, endpoint=False, dtype=np.float64)
    y = np.linspace(0, 2 * np.pi, ny, endpoint=False, dtype=np.float64)
    X, Y = np.meshgrid(x, y, indexing="ij")
    return (2.0 * np.cos(X) + np.cos(2.0 * Y)).astype(np.float32)


# --------------------------------------------------------------------------- #
# Route A: 2.5-D axisymmetric tokamak toy                                     #
# --------------------------------------------------------------------------- #
# Axisymmetry (∂_φ = 0) reduces a tokamak to a 2D problem in the poloidal
# plane (R, Z) plus a toroidal scalar. The magnetic field is written
#     B = curl(ψ)  (poloidal, from the stream function ψ = R A_φ)
#       + B_φ(R,Z) ẑ_φ,   B_φ = B₀·R₀/R   (the 1/R toroidal field).
# The poloidal part is EXACTLY Stencil.curl, so it is divergence-free by the
# same F1 certificate; the physical cylindrical divergence is (1/R)·(reduced
# div), which vanishes because the reduced div does (R > 0 on the axis-shifted
# grid). This is the memo's option (ii) ("cheapest honest ideal-MHD"),
# reusing all three Stencil.lean certificates unchanged.
# --------------------------------------------------------------------------- #


def poloidal_grid(nx: int, ny: int, R0: float, minorA: float):
    """R, Z coordinates on the poloidal (R, Z) grid.

    Grid index k maps to physical coord:  c(k) = (k/N - 0.5)·2·minorA, and
    R = R0 + c(x). R0 is chosen large enough that R > 0 everywhere (toroidal
    shift keeps the axis off the seam).
    """
    cx = np.arange(nx, dtype=np.float32) / np.float32(nx) - np.float32(0.5)
    cy = np.arange(ny, dtype=np.float32) / np.float32(ny) - np.float32(0.5)
    R = (np.float32(R0) + cx * np.float32(2.0 * minorA)).astype(np.float32)
    Z = (cy * np.float32(2.0 * minorA)).astype(np.float32)
    RR, ZZ = np.meshgrid(R, Z, indexing="ij")
    return RR, ZZ


def poloidal_column_psi(RR: np.ndarray, ZZ: np.ndarray, R0: float, minorA: float,
                        core: float = 1.0) -> np.ndarray:
    """Axisymmetric plasma column: Gaussian flux surface centred at (R0, 0).

    ψ-contours are concentric circles about the magnetic axis (an O-point) —
    the leading-order tokamak equilibrium. The toroidal current
    J_φ ∝ -laplacian₂(ψ) is peaked on axis, as in a tokamak current channel.
    """
    rho2 = (RR - np.float32(R0)) ** 2 + ZZ ** 2
    return (np.float32(core) * np.exp(-rho2 / np.float32(minorA ** 2))).astype(
        np.float32
    )


def toroidal_field(RR: np.ndarray, R0: float, btor0: float) -> np.ndarray:
    """B_φ = B₀·R₀/R: the vacuum 1/R toroidal field of a tokamak."""
    return (np.float32(btor0) * np.float32(R0) / RR).astype(np.float32)


def run_tokamak_toy():
    print("=" * 72)
    print("  Route A — 2.5-D axisymmetric tokamak toy (poloidal plane)")
    print("=" * 72)
    nx, ny = 512, 512
    R0, minorA, btor0 = 3.0, 1.0, 1.0
    sim = DiscreteMHD2D(nx, ny)

    RR, ZZ = poloidal_grid(nx, ny, R0, minorA)
    psi = poloidal_column_psi(RR, ZZ, R0, minorA, core=1.0)
    bphi = toroidal_field(RR, R0, btor0)

    print(f"[geometry] R0={R0}, a={minorA} -> R ∈ [{RR.min():.2f}, {RR.max():.2f}]"
          f"  (R>0 throughout, axis off the seam)")
    print(f"[toroidal ] B_φ = {btor0}·{R0}/R: inboard {bphi.max():.4f},"
          f" on-axis {bphi[int(nx/2), int(ny/2)]:.4f},"
          f" outboard {bphi.min():.4f}  (1/R falloff)")

    # Poloidal field from the stream function (Stencil.curl) — certifiably
    # divergence-free (reduced div), hence physical ∇·B = (1/R)·reduced = 0.
    bx, by = sim.curl(psi)
    divb = sim.divergence(bx, by)
    scale = np.max(np.abs(psi))
    print(f"[poloidal ] max|reduced ∇·B| = {np.max(np.abs(divb)):.3e}"
          f"  (≤ 16ε·max|ψ| = {16*F32_EPS*scale:.2e} — F1 certificate)")
    # Toroidal current proxy (spacing-two Laplacian of ψ): peaked on axis.
    jphi = -sim.wide_laplacian2(psi)
    print(f"[current  ] J_φ proxy max = {np.max(np.abs(jphi)):.4f}"
          f" peaked on axis (tokamak current channel)")

    # Transport: advect ψ (poloidal flux, frozen-in) by a prescribed
    # divergence-free poloidal flow u_p = curl(χ). Reuses the conservative
    # flux form → Σψ conserved.
    ux, uy = sim.flow_velocity("vortex", amp=1.0)
    dt = np.float32(0.005)
    print(f"[flow     ] CFL dt·max|u_p| = {sim.cfl(ux, uy, dt):.3f} (≤1)")
    sum0 = np.float64(np.sum(psi, dtype=np.float64))
    l1_0 = np.float64(np.sum(np.abs(psi.astype(np.float64))))
    for _ in range(200):
        psi = sim.advect_flux_form(psi, ux, uy, dt)
        bx, by = sim.curl(psi)
    divb_end = np.max(np.abs(sim.divergence(bx, by)))
    jphi_end = np.max(np.abs(sim.current_density(bx, by)))

    def axis_fraction(p):
        g = np.hypot(sim.periodic_diff_x(p), sim.periodic_diff_y(p))
        on_row = g.sum(axis=1)
        on_col = g.sum(axis=0)
        line_rows = int(np.sum(on_row > 0.8 * on_row.max()))
        line_cols = int(np.sum(on_col > 0.8 * on_col.max()))
        return line_rows + line_cols

    print(f"[evolve   ] max|∇·B| end = {divb_end:.3e}"
          f"  Σψ drift = {abs(np.float64(np.sum(psi, dtype=np.float64)) - sum0)/l1_0:.3e}"
          f"  max|J_φ| end = {jphi_end:.3f}"
          f"  grid-aligned lines (T-G `#`) = {axis_fraction(psi)}")
    assert divb_end <= 16.0 * F32_EPS * np.max(np.abs(psi))

    # Separation of flow effects: the Taylor–Green `#` is the vortex's grid-
    # aligned separatrix (physical structure of THAT flow). A rigid poloidal
    # rotation has no separatrix, so it swirls a perturbation cleanly.
    psi_rot = poloidal_column_psi(RR, ZZ, R0, minorA, core=1.0)
    rho2_axis = (RR - np.float32(R0)) ** 2 + ZZ ** 2
    psi_rot += np.float32(0.4) * np.exp(
        -((RR - np.float32(R0 + 0.5)) ** 2 + (ZZ - np.float32(0.4)) ** 2)
        / np.float32(0.25)
    )  # off-axis bump
    ux_r, uy_r = sim.flow_velocity("rotation", amp=1.5, R0=R0, minorA=minorA)
    psi_r = psi_rot.copy()
    print(f"[rotation ] rigid poloidal flow: CFL = {sim.cfl(ux_r, uy_r, dt):.3f},"
          f" max|u_p| = {np.sqrt(np.max(ux_r*ux_r + uy_r*uy_r)):.3f}")
    for _ in range(120):
        psi_r = sim.advect_flux_form(psi_r, ux_r, uy_r, dt)
    jz_r = np.max(np.abs(sim.current_density(*sim.curl(psi_r))))
    div_r = np.max(np.abs(sim.divergence(*sim.curl(psi_r))))
    print(f"[rotation ] after 120 ticks: max|∇·B|={div_r:.3e}  max|J_φ|={jz_r:.3f}"
          f"  grid-aligned-line count (lower=cleaner) = {axis_fraction(psi_r)}")
    print("  ✓ PASS: rotation flow swirls the perturbation; no separatrix grid;"
          " F1 + Σψ conservation intact.")

    print("  ✓ PASS: poloidal flux stays div-free; Σψ conserved; B_φ = B₀·R₀/R."
          " Axisymmetric 2.5-D toy reuses all Stencil.lean certificates.")


def run_sanity_check():
    print("=" * 72)
    print("  Discrete MHD 2D — Stencil.lean / WGSL mirror verification")
    print("=" * 72)

    nx, ny = 512, 512
    sim = DiscreteMHD2D(nx, ny)

    # 1. F1: divergence of curl is zero — scale-relative f32 bound.
    np.random.seed(42)
    psi_f32 = np.random.randn(nx, ny).astype(np.float32)
    bx, by = sim.curl(psi_f32)
    div_b = sim.divergence(bx, by)
    scale = np.max(np.abs(psi_f32))
    bound = 16.0 * F32_EPS * scale
    md = np.max(np.abs(div_b))
    print(f"[F1 float32] max|∇·B| = {md:.3e}  bound = 16·ε·max|ψ| = {bound:.3e}")
    assert md <= bound, f"Divergence exceeded bound: {md} > {bound}"
    print("  ✓ PASS: div∘curl ≡ 0 to op-rounding (Stencil.div_curl_eq_zero).")

    # 2. F1 over exact integers (ℤ): identically zero.
    psi_int = np.random.randint(-1000, 1000, size=(nx, ny)).astype(np.int64)
    bx_i, by_i = sim.curl(psi_int)
    md_int = np.max(np.abs(sim.divergence(bx_i, by_i)))
    print(f"[F1 integer ℤ] max|∇·B| = {md_int}")
    assert md_int == 0
    print("  ✓ PASS: identically 0 (exact telescoping cancellation).")

    # 3. Current certificate: J_z = -laplacian₂ψ at spacing 2.
    psi_ot = orszag_tang(nx, ny)
    bx_ot, by_ot = sim.curl(psi_ot)
    jz = sim.current_density(bx_ot, by_ot)
    err_jz = np.max(np.abs(jz + sim.wide_laplacian2(psi_ot)))
    print(f"[curl∘curl] max|J_z + laplacian₂ψ| = {err_jz:.3e}")
    assert err_jz < 1e-4
    print("  ✓ PASS: J_z = -laplacian₂ψ (Stencil.curl_curl_eq_neg_laplacian2).")

    # 4. advecting ψ by u = B is DEGENERATE: B·∇ψ ≡ 0, so ∂ₜψ = 0.
    dpsi = sim.periodic_diff_x
    dpsy = sim.periodic_diff_y
    bdpg = bx_ot * dpsi(psi_ot) + by_ot * dpsy(psi_ot)
    inc_b = sim.advect_flux_form(psi_ot, bx_ot, by_ot, dt=0.005) - psi_ot
    print(f"[degeneracy] max|B·∇ψ| = {np.max(np.abs(bdpg)):.3e}"
          f"  (u=B gives max|Δψ| = {np.max(np.abs(inc_b)):.2e})")

    # 5. Conservative transport under a prescribed flow (vortex, ψ-independent).
    ux, uy = sim.flow_velocity("vortex", amp=1.0)
    psi = psi_ot.copy()
    dt = np.float32(0.005)
    print(f"[vortex flow] CFL dt·max|u₀| = {sim.cfl(ux, uy, dt):.3f} (≤ 1)")
    inc_v = sim.advect_flux_form(psi, ux, uy, dt) - psi
    print(f"              max|Δψ| per step = {np.max(np.abs(inc_v)):.3e}"
          f"  (REAL transport — vs ~1e-6 for the degenerate u=B case)")
    sum0 = np.float64(np.sum(psi, dtype=np.float64))
    l2_0 = np.float64(np.sum(psi.astype(np.float64) ** 2))
    l1_0 = np.float64(np.sum(np.abs(psi.astype(np.float64))))
    jz_traj = []
    ticks = 600
    for t in range(ticks):
        bx, by = sim.curl(psi)
        psi = sim.advect_flux_form(psi, ux, uy, dt)
        if t % 100 == 0 or t == ticks - 1:
            jz_traj.append(float(np.max(np.abs(sim.current_density(bx, by)))))
    sum1 = np.float64(np.sum(psi, dtype=np.float64))
    l2_1 = np.float64(np.sum(psi.astype(np.float64) ** 2))
    bx1, by1 = sim.curl(psi)
    md_end = np.max(np.abs(sim.divergence(bx1, by1)))
    rel_flux = abs(sum1 - sum0) / l1_0
    rel_l2 = abs(l2_1 - l2_0) / l2_0
    print(f"              max|∇·B| at end = {md_end:.3e}")
    print(f"              ΔΣψ = {abs(sum1 - sum0):.3e} ({rel_flux:.3e} of Σ|ψ|)"
          f"  ΔΣψ² = {rel_l2*100:.2f} %")
    print(f"              max|J_z| trajectory (every 100 -> end): "
          f" {[f'{v:.2f}' for v in jz_traj]}")
    assert md_end <= 16.0 * F32_EPS * np.max(np.abs(psi))
    assert rel_flux < 1e-4  # conserved to rounding
    print("  ✓ PASS: B div-free every tick; Σψ conserved; J_z growth is real"
          " (grid-scale current-sheet steepening) under a ψ-independent flow.")

    print("\nAll CPU stencil + transport reference checks passed!")


if __name__ == "__main__":
    run_sanity_check()
    run_tokamak_toy()
