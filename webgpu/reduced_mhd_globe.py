# reduced_mhd_globe.py — Python 3D globe preview of the field-line MHD.
# Wraps the 2-D reduced-MHD field onto S² (equirectangular map, same domain
# as the Lean-certified root_on_sphere / onSphere geometry in
# LaserCortex/PlasmaBall.lean): the magnetic field lines (ψ contours) are
# rendered as the glowing filaments on the sphere — what a plasma globe makes
# unmistakable — over a dark |j| current-sheet texture.

import numpy as np

MPL = __import__("matplotlib")
MPL.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.colors import Normalize  # noqa: E402

from reduced_mhd import ReducedMHD, rk4  # noqa: E402


def sphere_map(M=100):
    """Mesh + a 2π-periodic -> sphere coordinate map (equirectangular)."""
    th = np.linspace(-np.pi / 2, np.pi / 2, M)      # latitude
    lam = np.linspace(-np.pi, np.pi, 2 * M)         # longitude
    LAM, TH = np.meshgrid(lam, th)
    X = np.cos(TH) * np.cos(LAM)
    Y = np.cos(TH) * np.sin(LAM)
    Z = np.sin(TH)
    # field-space fractions: longitude frac v∈[0,1), latitude frac u∈[0,1)
    V = np.mod((LAM + np.pi) / (2 * np.pi), 1.0)
    U = (TH / np.pi + 0.5)
    return X, Y, Z, V, U


def field_on_sphere(f, N, V, U):
    """Sample the periodic field f (N×N, [0,2π)²) onto the sphere map."""
    ix = np.mod(np.floor(V * N).astype(int), N)
    iy = np.mod(np.floor(U * N).astype(int), N)
    return f[iy, ix]


def run_globe():
    m = ReducedMHD(N=128, eta=4e-3, nu=2e-3)
    psi, om = m.initials()
    dt = 4e-3
    steps = 1200
    every = 8
    frames = []
    for t in range(steps):
        psi, om = rk4(m, psi, om, dt)
        if t % every == 0:
            frames.append((psi.copy(), om.copy()))
    print(f"rendering {len(frames)} frames...")

    X, Y, Z, V, U = sphere_map(M=96)
    cmap = plt.get_cmap("magma")
    fig = plt.figure(figsize=(6, 6))
    ax = fig.add_subplot(111, projection="3d")
    ax.set_axis_off()
    fig.patch.set_facecolor("black")

    def draw(fi):
        psi_f, om_f = frames[fi]
        j = -m._lap(psi_f)
        jmax = float(np.max(np.abs(j)))
        if jmax < 1e-9:
            jmax = 1.0
        tex = field_on_sphere(j, m.N, V, U)
        face = cmap(Normalize(0, jmax)(np.abs(tex)))  # (M,2M,4) RGBA
        ax.clear()
        ax.set_axis_off()
        # the dark glass globe with the |j| sheet glow on it
        ax.plot_surface(X, Y, Z, facecolors=face, shade=False,
                        rstride=1, cstride=1, antialiased=False,
                        linewidth=0)
        # MAGNETIC FIELD LINES: ψ contours, wrapped onto the sphere.
        cs = ax.contour(np.arange(m.N), np.arange(m.N), psi_f, levels=18,
                        colors="gold", linewidths=1.1, alpha=0.9)
        for segs in cs.allsegs:
            for seg in segs:
                lam = seg[:, 0] / m.N * 2 * np.pi - np.pi
                th = (seg[:, 1] / m.N - 0.5) * np.pi
                px = np.cos(th) * np.cos(lam)
                py = np.cos(th) * np.sin(lam)
                pz = np.sin(th)
                ax.plot(px, py, pz, color="gold", lw=1.0, alpha=0.85)
        ax.view_init(elev=28, azim=fi * 1.4)
        ax.set_box_aspect((1, 1, 1))
        ax.set_xlim(-1.05, 1.05); ax.set_ylim(-1.05, 1.05); ax.set_zlim(-1.05, 1.05)
        return ()

    import matplotlib.animation as an
    ani = an.FuncAnimation(fig, draw, frames=len(frames), blit=False, interval=40)
    out = "reduced_mhd_globe.mp4"
    try:
        ani.save(out, writer="ffmpeg", fps=25, dpi=110)
    except Exception as e:  # pragma: no cover
        out = "reduced_mhd_globe.gif"
        ani.save(out, writer="pillow", fps=25, dpi=110)
    print(f"wrote {out}")


if __name__ == "__main__":
    run_globe()
