# Lab Note 063 — The WebGPU MHD Plasma Globe Goes 3-D, and the WGSL `vec3<u32>` Uniform Trap

**Date**: 2026-09-03
**Follows**: 057 (strut quantization: span of the associator is {0,4} — the "half-strut" question has no basis answer), 056 (Rees strut weight = 4), 060 (anatomy of a hole)
**Status**: NOTE — the 3-D A-form solver is **live** (field evolves on the GPU; `dPsiInit` 0 → 1.4e-2); the RenderPass-Debugging sub-strand produced one hard-won **\[P\]** diagnosis (the `vec3<u32>` uniform-layout trap) and two prior silent-failure fixes; the *reconnection-defect test* that would actually engage the (4,4) / `strut = 4` model is still **[H]**, now that the field is rich enough for it.
**Protocol**: Timespace Decomposition v0.3 — (4,4) Signature Model

---

## 0. Abstract

In `webgpu/` the reduced-MHD "plasma globe" (real-space stencil, ψ-form) moved from a 2-D meridional toy to a genuine **3-D azimuthal solver** — `ψ(r, z, φ)` on 64×64×32, `J = 40` Jacobi sweeps, exactly **8 storage buffers** (the per-stage limit, so it runs on any device). The bulk of the session was not the physics but a **class of WGSL silent failures**: the renderer produces a *correct-looking* frame while the field never changes, because — three separate times — the GPU was being told to do nothing while every CPU-side instrument (meters, heartbeats, uniform readback) read sane values. The capstone is the **`vec3<u32>` uniform-layout trap**: this implementation carries the member *after* a `vec3<u32>` at +12 (packed alignment), not +16, so the shader read `dt` from the buffer's padding zeros — every RK2 update multiplied by 0, freezing each of the 131,072 cells. Lean-first groundwork (`Stencil3.F1-3D` div-curl certificate, `Cost3D` step-count contract) held throughout.

## 1. What was built (Lean-first)

| Artifact | Content | Tag |
| --- | --- | --- |
| `LaserCortex/Stencil3.lean` | **F1-3D**: `div (curl A) = 0` on `ZMod Nx × ZMod Ny × ZMod Nz`, any `AddCommGroup` — the 3-D A-form `B = ∇×A` is div-free by telescoping, no cleaning | **[P]** |
| `LaserCortex/Cost3D.lean` | `cellOps J = 2·(13+20+13J)`, `stepOps N M K J = N·M·K·cellOps J`; theorems: positivity, **exact 8× all-axis doubling** (`stepOps_double_all`), **exact linear-in-K** (the reduced-lattice lever: halving φ-planes halves cost, exact — `stepOps_linear_in_K`), monotonicity | **[P]** |
| `Cost3D #eval` | 64×64×32, J=40 → **144,965,632** ops/step (11.8× the 2-D page); K=16/8 → exact halves | **[P]** |

The build matches the contract: 8 storage buffers, 8×8×4 workgroups (256 ≤ 256 limit), `J=40`, `dt=2e-3`, φ-modulated AC flux drive (`1+0.3 sin φ`), 3×3×3-blurred noise seed, trilinear (φ-wrapped) render sampling, twisted meridian cross-sections. The `mirror_3d.py` stencil replica shows **bounded, drive-oscillating** dynamics (`max|j|` 13–17, `E_mag` 0.030–0.045 over `t=0.8`, no blow-up).

## 2. The silent-failure class (the real content)

The recurring failure mode: **a correct-looking frame whose data never changes.** Three diagnoses in order.

**(a) March bounds — interior never sampled.** The glow pass marched `t ∈ (camera, dome-entry)` and stopped *before entering* the glass: the whole interior was simply never visited. Fixed by computing both sphere hits (entry and exit) and marching across the interior. This was the "dome blots out the glow" symptom; the mirror (`mirror_fs.py`, an exact fragment-shader replica) showed `accStream = 0` and reproduced it.

**(b) Workgroup coverage — half the domain.** `dispatchWorkgroups(N/8, N/8, NK/8)` dispatched `(8,8,4)` workgroups; with 8×8×4 threads that covers only `(64,64,16)` — **φ-planes 16–31 never computed**: their current was never written (zero ⇒ "only half the globe has glow") and their field never advanced. Fixed to `(8,8,8)` workgroups (`NK/4`).

**(c) `vec3<u32>` uniform layout — the capstone [P].** With (a) and (b) fixed, the field *still* froze though `maxJ` stayed sane. Micro-probes established: a brand-new kernel (`zz_test`) writing a constant did write; the physical `mid_rhs` did not. Byte-level probes then pinned the cause — the shader read `cu.dt` from **offset 12** (the struct padding, `0`) and `cu.which` from **offset 28** (the bits of `driveT = 0.5f32 = 1,056,964,608`, giving the observed `1.06e+12` probe). So this implementation lays out the member after `vec3<u32>` at +12 (alignment 4), **not** +16. Every RK2 advance computed `ψ += 0.5·0·dpsi` — the field was mathematically frozen while `lapj`, the Poisson solve, the meters, the heartbeats, **and the CPU-side uniform readback** all read correct values. Fix: `dims` as three scalar `u32`s (`nx, ny, nz`), `writeCu` remapped. Post-fix: `dPsiInit = 1.41e-2` (field genuinely evolves).

## 3. The instruments that cracked it

These are worth keeping; they convert "looks fine" into a verdict.

| Instrument | What it proves |
| --- | --- |
| CPU checksum round-trip (offscreen texture → readback → checksum, before/after N steps) | whether two frames are actually *different* — it was right (`pre == post`); the user's question "is this checking that frames differ?" was the correct diagnosis point |
| `dPsiInit` self-test (`max|ψ − ψ_init|` in every heartbeat) | whether the GPU ever writes to the field at all |
| Constant-write kernel probe (`zz_test`) | whether dispatch+write+readback work (isolates a "real" kernel) |
| Uniform readback (with `COPY_SRC`) + field-layout probe | whether the shader sees the bytes you wrote — the `vec3` trap lived here |

WGSL gotchas catalogued along the way (each cost a compile/harness cycle): no `? :` (use `select`), `_` is not an identifier, runtime-sized arrays can't be function parameters, storage-buffer-per-stage limit is 8, fragment `read_write` storage is legal, `pow`/`array` restrictions, and uniform `vec3` member alignment is implementation-defined.

## 4. Connection to the (4,4) model — honest

The globe is the **physical staging ground** for the question note 057 couldn't answer inside the basis: whether a *defect* in a real discrete field can realize the `strut = 4` quantum (or intermediate values). The `B = ∇×A` field rendered here is div-free **by the F1-3D certificate** (the A-form family), and the flux-`ψ` level surfaces are the algebraic surfaces the defect ledger would price. Nothing about the MHD evolution has been (or is) constrained by the (4,4) model yet — that link is the intended **[H]** test, and the field is now rich enough (3-D, azimuthal filaments, reconnection-capable) to make a counter meaningful. Do **not** read any triumph here as evidence for the algebra; the solver is conventional resistive MHD, LC-flavored only in form.

## 5. Reproduction

`file://webgpu/mhd_globe_webgpu_3D.html` (build tag `3d-2025-09-05h`; the 2.5-D reference stays at `mhd_globe_webgpu.html`). Headless SwiftShader: `RUNNING t=0.048 … dPsiInit=1.41e-2` (the `device destroyed` ~1 s after load is headless-only, not seen on real GPUs). Lean: `lake build LaserCortex.Stencil3 LaserCortex.Cost3D` — both green, axiom footprint `propext`, `Quot.sound` (plus per-theorem `native_decide` where used). Mirrors: `mirror_3d.py` (solver), `mirror_fs.py` (fragment), both reproducing the diagnostics.

## 6. Next (open)

1. **[H] Reconnection/defect counter** on the 3-D field: count X-point/separatrix crossings and island births in `ψ`, and ask whether the topology-change events land on `strut = 4` (or don't). Falsifiable either way — that's the point.
2. **[P->measure] Performance vs contract**: measure real step time against `Cost3D.stepOps 64 64 32 40`; `K=16` is the theorem-exact half-step if headroom is wanted.
3. Art (lower priority): sharpen the discharge into genuine filament legs (`jt³` emission + exposure dials).

---

## References

* `LaserCortex/Stencil3.lean` — F1-3D div-curl certificate
* `LaserCortex/Cost3D.lean` — the step-cost contract and `#eval` figures
* `webgpu/mhd_globe_webgpu_3D.html`, `webgpu/mhd_globe_webgpu.html` — the solver and reference
* `webgpu/mirror_3d.py`, `webgpu/mirror_fs.py` — stencil and fragment-shader replicas
* `docs/lab_notes/056_rees_strut_weight.md`, `057_strut_quantization.md` — `strut = 4` and the unresolved half-strut
* `docs/lab_protocol.md` v0.3 — Timespace Decomposition, (4,4) Signature Model
