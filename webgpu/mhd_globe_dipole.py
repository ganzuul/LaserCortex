# mhd_globe_dipole.py — 3-D volumetric plasma globe from driven dipole MHD.
#
# The field is genuinely 3-D and axisymmetric: a magnetized-sphere dipole
# (field lines arc pole-to-pole around the central globe, exactly a plasma
# globe's streamers) evolved by 2-D in the meridional plane (the "2.5-D"
# reduced-MHD reduction: the solver is 2-D, the field is 3-D). The globe is
# AC-driven (like a real plasma globe's oscillating electrode): a periodic
# poloidal flow forcing, with genuine current-sheet response and cyclic
# stretching of the field lines.
#
# Rendered: black background, dark globe sphere carrying the |j| (current
# density) heat map, and gold *discharge* field lines (bright core + soft
# halo). `--still` renders one PNG frame for self-inspection; otherwise a
# rotating MP4.

import sys

import numpy as np

MPL = __import__("matplotlib")
MPL.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.colors import Normalize  # noqa: E402

from reduced_mhd import ReducedMHD  # noqa: E402


class DrivenMHD(ReducedMHD):
    """Reduced MHD + an AC poloidal drive (the plasma globe's electrode)."""

    def __init__(self, *a, drive_amp=1.2, drive_T=1.0, **k):
        super().__init__(*a, **k)
        self.drive_amp = drive_amp
        self.drive_T = drive_T
        x = np.linspace(0, 2 * np.pi, self.N, endpoint=False)
        self.X, self.Y = np.meshgrid(x, x, indexing="ij")
        self.phi_d = np.sin(self.X - np.pi) * np.sin(self.Y - np.pi)

    def rhs(self, psi, om, t=0.0):
        dpsi, dom = super().rhs(psi, om)
        om_d = self.drive_amp * np.sin(2 * np.pi * t / self.drive_T) * (
            -self._lap(self.phi_d)
        )
        return dpsi, dom + om_d


RG = 0.45  # globe core radius (the magnetized sphere)
NROT = 6


def sphere_tex(f, N):
    """Globe sphere mesh + |f| sampled at the surface (axisymmetric map)."""
    u = np.linspace(0, 2 * np.pi, 48)
    v = np.linspace(0, np.pi, 26)
    gx = RG * np.outer(np.cos(u), np.sin(v))
    gy = RG * np.outer(np.sin(u), np.sin(v))
    gz = RG * np.outer(np.ones_like(u), np.cos(v))
    rr = np.sqrt(gx * gx + gy * gy)
    zz = gz
    ix = np.mod(np.floor((rr + np.pi) / (2 * np.pi) * N).astype(int), N)
    iy = np.mod(np.floor((zz + np.pi) / (2 * np.pi) * N).astype(int), N)
    return (gx, gy, gz), f[iy, ix]


def draw_globe(ax, fig, m, psi_f, jmax_scale):
    """Black background, |j| heat-map globe, glowing gold field lines."""
    ax.clear()
    ax.set_axis_off()
    fig.patch.set_facecolor("black")
    ax.set_facecolor("black")
    j = -m._lap(psi_f)
    jmax = np.percentile(np.abs(j), 99.0) * jmax_scale  # contrasty, not one-hot
    (gx, gy, gz), tex = sphere_tex(np.abs(j), m.N)
    face = plt.get_cmap("magma")(Normalize(0, jmax)(tex))
    face[..., 3] = 1.0
    ax.plot_surface(gx, gy, gz, facecolors=face, shade=False, rstride=1,
                    cstride=1, antialiased=False, linewidth=0)
    # magnetic field lines = ψ contours, rotated around the axis; discharge
    # glow in three passes — wide soft halo, mid halo, bright core.
    # Levels exclude near-zero so the ψ≈0 contour (which is literally the
    # symmetry axis) is not drawn as a dead-straight vertical line.
    vmax = float(np.max(np.abs(psi_f)))
    levels = [v for v in np.linspace(-0.9 * vmax, 0.9 * vmax, 16)
              if abs(v) > 0.08 * vmax]
    # compute contour segments on a throwaway 2-D figure so nothing is drawn
    # into the 3-D axes (ax.contour on a 3-D axes can render its own layer).
    fig_tmp, ax_tmp = plt.subplots()
    cs = ax_tmp.contour(np.arange(m.N), np.arange(m.N), psi_f, levels=levels,
                        colors="none")
    plt.close(fig_tmp)
    for segs in cs.allsegs:
        for seg in segs:
            rr = seg[:, 0] / m.N * 2 * np.pi - np.pi
            zz = seg[:, 1] / m.N * 2 * np.pi - np.pi
            # NaN-break near-axis: the dipole "teardrops" converge at their
            # poles; stopping them short of the axis avoids a bright vertical
            # pile-up and reads as open, pole-to-pole field lines.
            keep = np.abs(rr) > 0.30
            rr = np.where(keep, rr, np.nan)
            zz = np.where(keep, zz, np.nan)
            if np.sum(keep) < 2:
                continue
            for k in range(NROT):
                ph = k * 2 * np.pi / NROT
                px = rr * np.cos(ph)
                py = rr * np.sin(ph)
                ax.plot(px, py, zz, color=(1.0, 0.62, 0.30, 0.05), lw=11.0)
                ax.plot(px, py, zz, color=(1.0, 0.72, 0.38, 0.14), lw=4.5)
                ax.plot(px, py, zz, color=(1.0, 0.95, 0.82, 0.55), lw=1.8)
                ax.plot(px, py, zz, color=(1.0, 0.97, 0.88), lw=0.9, alpha=0.95)
    ax.set_box_aspect((1, 1, 1))
    ax.set_xlim(-1.6, 1.6)
    ax.set_ylim(-1.6, 1.6)
    ax.set_zlim(-1.6, 1.6)


def run():
    m = DrivenMHD(N=128, eta=2e-3, nu=1e-3, drive_amp=1.2, drive_T=1.0)
    R = m.X - np.pi
    Z = m.Y - np.pi
    rho2 = R * R + Z * Z
    a = 0.5
    sig = 1.6
    psi = 1.0 * (R * R) / (rho2 + a * a) ** 1.5 * np.exp(-rho2 / (2 * sig * sig))
    psi += 0.2 * np.exp(-rho2 / (2 * 0.9 ** 2)) * np.sin(2.0 * m.X)
    om = -m._lap(0.4 * np.sin(R) * np.sin(Z))

    dt = 2e-3
    steps = 1500
    every = 10
    frames = []
    for t in range(steps):
        tt = t * dt
        k1p, k1o = m.rhs(psi, om, tt)
        k2p, k2o = m.rhs(psi + 0.5 * dt * k1p, om + 0.5 * dt * k1o, tt + 0.5 * dt)
        k3p, k3o = m.rhs(psi + 0.5 * dt * k2p, om + 0.5 * dt * k2o, tt + 0.5 * dt)
        k4p, k4o = m.rhs(psi + dt * k3p, om + dt * k3o, tt + dt)
        psi = psi + dt / 6 * (k1p + 2 * k2p + 2 * k3p + k4p)
        om = om + dt / 6 * (k1o + 2 * k2o + 2 * k3o + k4o)
        if t % every == 0:
            frames.append((psi.copy(), om.copy()))
            em, _, jmax = m.energies(psi, om)
        if t % 250 == 0:
            print(f"t={tt:5.2f}  Em={em:.4f}  max|j|={jmax:.3f}")
    print(f"frames: {len(frames)}")

    fig = plt.figure(figsize=(6, 6))
    ax = fig.add_subplot(111, projection="3d")

    if "--still" in sys.argv:
        # self-inspection frame (the loop that lets me see it myself)
        fi = 75
        psi_f, _ = frames[fi]
        draw_globe(ax, fig, m, psi_f, 0.5)
        ax.view_init(elev=24, azim=75 * 1.6)
        plt.savefig("mhd_globe_still.png", dpi=150, facecolor="black")
        print("wrote mhd_globe_still.png")
        return

    def draw(fi):
        psi_f, _ = frames[fi]
        draw_globe(ax, fig, m, psi_f, 0.5)
        ax.view_init(elev=24, azim=fi * 1.6)
        return ()

    import matplotlib.animation as an
    ani = an.FuncAnimation(fig, draw, frames=len(frames), blit=False, interval=40)
    out = "mhd_globe_dipole.mp4"
    try:
        ani.save(out, writer="ffmpeg", fps=30, dpi=110)
    except Exception as e:  # pragma: no cover
        out = "mhd_globe_dipole.gif"
        ani.save(out, writer="pillow", fps=30, dpi=110)
    print(f"wrote {out}")


if __name__ == "__main__":
    run()
