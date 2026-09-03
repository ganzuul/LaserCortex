# reduced_mhd.py — 2-D incompressible (resistive) reduced MHD, spectral.
# Physics "core" of the plasma globe: the glowing filaments are meant to BE a
# real MHD field, so the wiggle the eye reads must be genuine current-sheet
# formation, magnetic-island growth and reconnection — not a canned sine.
#
#   ∂t ψ + [φ, ψ] = η ∇²ψ            (flux / induction; η -> reconnection)
#   ∂t ω + [φ, ω] = [ψ, j] + ν ∇²ω   (vorticity; Lorentz forcing [ψ,j])
#   j = -∇²ψ,  ω = -∇²φ,  B = ∇×(ψ ẑ),  u = ∇×(φ ẑ)
#
# [a,b] = ∂x a ∂y b - ∂y a ∂x b. Solve the inverse Laplacian (φ from ω) in
# Fourier space; spectral derivatives. Orszag–Tang-style initialization.
# This is the exploratory physics / mirror core (AGENTS.md: exploratory scripts
# may be written first; the stencils it uses are Stencil.lean-certified, and
# conservation statements are Lean targets).

import numpy as np

MPL = __import__("matplotlib")
MPL.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402


class ReducedMHD:
    def __init__(self, N=128, eta=4e-3, nu=2e-3, B0=1.0, v0=1.0):
        self.N = N
        self.eta = eta
        self.nu = nu
        self.B0 = B0
        self.v0 = v0
        self.kx = np.fft.fftfreq(N) * N  # domain is [0, 2π): angular wavenumber
        self.ky = np.fft.fftfreq(N) * N   # (fundamental mode -> k = 1)
        self.k2 = self.kx[:, None] ** 2 + self.ky[None, :] ** 2
        self.k2[0, 0] = 1.0  # avoid divide-by-zero in the Poisson solve

    def _lap(self, f):
        return np.real(np.fft.ifft2(-self.k2 * np.fft.fft2(f)))

    def _grad(self, f):
        fh = np.fft.fft2(f)
        dx = np.real(np.fft.ifft2(1j * self.kx[:, None] * fh))
        dy = np.real(np.fft.ifft2(1j * self.ky[None, :] * fh))
        return dx, dy

    def _poisson(self, f):
        # solve lap(g) = f (the mean-free inverse Laplacian).
        fh = np.fft.fft2(f)
        fh[0, 0] = 0.0
        return np.real(np.fft.ifft2(-fh / self.k2))

    def _bracket(self, a, b):
        ax, ay = self._grad(a)
        bx, by = self._grad(b)
        return ax * by - ay * bx

    def rhs(self, psi, om):
        phi = self._poisson(-om)
        j = -self._lap(psi)
        dpsi = -self._bracket(phi, psi) + self.eta * self._lap(psi)
        dom = -self._bracket(phi, om) + self._bracket(psi, j) + self.nu * self._lap(om)
        return dpsi, dom

    def energies(self, psi, om):
        phi = self._poisson(-om)
        bx, by = self._grad(psi)
        ux, uy = self._grad(phi)
        em = 0.5 * np.sum(bx * bx + by * by) / self.N ** 2
        ek = 0.5 * np.sum(ux * ux + uy * uy) / self.N ** 2
        jmax = float(np.max(np.abs(-self._lap(psi))))
        return em, ek, jmax

    def initials(self):
        x = np.linspace(0, 2 * np.pi, self.N, endpoint=False)
        X, Y = np.meshgrid(x, x, indexing="ij")
        psi = self.B0 * (np.cos(Y) + 0.5 * np.cos(2 * X))
        phi = self.v0 * (np.cos(X) + np.cos(Y))
        om = -self._lap(phi)
        return psi, om


def rk4(model, psi, om, dt):
    k1p, k1o = model.rhs(psi, om)
    k2p, k2o = model.rhs(psi + 0.5 * dt * k1p, om + 0.5 * dt * k1o)
    k3p, k3o = model.rhs(psi + 0.5 * dt * k2p, om + 0.5 * dt * k2o)
    k4p, k4o = model.rhs(psi + dt * k3p, om + dt * k3o)
    psi = psi + dt / 6.0 * (k1p + 2 * k2p + 2 * k3p + k4p)
    om = om + dt / 6.0 * (k1o + 2 * k2o + 2 * k3o + k4o)
    return psi, om


def run():
    m = ReducedMHD(N=128, eta=4e-3, nu=2e-3)
    psi, om = m.initials()
    dt = 4e-3
    steps = 1200
    every = 4
    em0, ek0, _ = m.energies(psi, om)
    print(f"init  Em={em0:.4f}  Ek={ek0:.4f}  (E_total={em0+ek0:.4f})")
    # diagnostics + collect current sheet peak over time
    jmax_t = []
    frames = []
    em_t = []
    for t in range(steps):
        psi, om = rk4(m, psi, om, dt)
        if t % 40 == 0:
            em, ek, jmax = m.energies(psi, om)
            em_t.append((t, em, ek, em + ek))
            print(f"t={t:4d}  Em={em:.4f}  Ek={ek:.4f}  Emax={jmax:.3f}")
        if t % every == 0:
            jmax_t.append(float(np.max(np.abs(-m._lap(psi)))))
            frames.append((psi, om))
    em, ek, jmax = m.energies(psi, om)
    print(f"final Em={em:.4f}  Ek={ek:.4f}  E={em+ek:.4f}  max|j|={jmax:.3f}")

    # MHD signature: current-sheet steepening (max|j| growth) then reconnection
    # (Em drops, Ek rises then decays) — print the shape.
    print("\ncurrent-sheet max|j| trajectory (every 4 steps, sampled):")
    print("  ", " ".join(f"{v:.1f}" for v in jmax_t[::10]))

    # A short MP4 so you can watch the MHD. The field lines (ψ = const
    # contours, i.e. flux surfaces) are the primary, unmistakable feature —
    # a plasma globe's glowing filaments ARE field lines. The fluid
    # streamlines (φ = const) are shown faintly so field vs. flow is clear.
    x = np.linspace(0, 2 * np.pi, m.N, endpoint=False)
    X, Y = np.meshgrid(x, x, indexing="ij")
    fig, ax = plt.subplots(figsize=(6, 6))
    jmax = jmax_t[-1] if jmax_t else 1
    def draw(frame):
        psi_f, om_f = frames[frame]
        j = -m._lap(psi_f)
        phi = m._poisson(-om_f)
        ax.clear()
        ax.set_facecolor("black")
        # faint glow of the current density (current sheets) underneath
        ax.pcolormesh(X, Y, np.abs(j), cmap="magma", vmin=0, vmax=jmax,
                      shading="gouraud", alpha=0.35)
        # MAGNETIC FIELD LINES: flux surfaces ψ = const (bright gold).
        ax.contour(X, Y, psi_f, levels=26, colors="gold", linewidths=1.2)
        # fluid streamlines φ = const (dim blue), to distinguish flow from field.
        ax.contour(X, Y, phi, levels=9, colors="deepskyblue",
                   linewidths=0.5, alpha=0.35, linestyles="dashed")
        ax.set_title(f"reduced MHD — gold: magnetic field lines (ψ), "
                     f"dashed blue: flow streamlines (φ)  (t≈{frame*every*dt:.2f})")
        ax.set_xticks([]); ax.set_yticks([]); ax.set_aspect("equal")
        return ()
    import matplotlib.animation as an
    ani = an.FuncAnimation(fig, draw, frames=len(frames), blit=False)
    out = "webgpu/reduced_mhd.mp4"
    try:
        ani.save(out, writer="ffmpeg", fps=25, dpi=110)
    except Exception as e:  # fallback to pillow if ffmpeg writer unavailable
        out = "webgpu/reduced_mhd.gif"
        ani.save(out, writer="pillow", fps=25, dpi=110)
    print(f"\nwrote {out}")


if __name__ == "__main__":
    run()
