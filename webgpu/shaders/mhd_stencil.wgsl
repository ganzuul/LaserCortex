// mhd_stencil.wgsl — 2D Discrete MHD WebGPU Compute Kernels
// ==========================================================
// Implements the discrete calculus stencils certified in LaserCortex/Stencil.lean:
//
// 1. compute_b_field:   B = curl(ψ z_hat) = (dy(ψ), -dx(ψ))
// 2. compute_div_b:     div(B) = dx(B_x) + dy(B_y)
//                       [Provably 0 by Stencil.div_curl_eq_zero — F1]
// 3. compute_current:   J_z = dx(B_y) - dy(B_x)
//                       [= -laplacian₂ψ by Stencil.curl_curl_eq_neg_laplacian2]
// 4. advect_psi:        Conservative flux-form transport of ψ along a
//                       prescribed ψ-independent flow u₀ (vortex/shear)
//                       [Σψ conserved by Stencil.fluxDiv_sum_eq_zero; scheme
//                        details live in the flux pair and cannot break it]
//
// Why u₀ and not u = B: in 2D B·∇ψ ≡ 0 (B is tangent to ψ-contours), so
// advecting ψ by B is a degenerate no-op (∂ₜψ = 0) and the only "motion" is
// the scheme's residual discretization noise — grid-scale growth, diagonal
// banding, runaway |J_z|. A ψ-independent, divergence-free flow gives real
// frozen-in transport while the F1 + conservation certificates stand.

struct SimUniforms {
    dims: vec2<u32>,        // Grid resolution (Nx, Ny)
    dt: f32,                // Effective timestep (host clamps to CFL ≤ 1)
    dissipation: f32,       // Reserved (0). Ideal toy has no dissipation knob.
    flowType: u32,          // 0 = Taylor–Green vortex, 1 = uniform shear
    flowAmp: f32,           // Flow amplitude
    geomR0: f32,            // Domains: torus major radius R0 (poloidal mode)
    geomMinor: f32,         //         minor radius a (poloidal mode)
    geomBtor: f32,          //         toroidal field on axis B_φ(R0) (0 if Cartesian)
};

@group(0) @binding(0) var<uniform> uniforms: SimUniforms;
@group(0) @binding(1) var<storage, read> psi_in: array<f32>;
@group(0) @binding(2) var<storage, read_write> b_field: array<vec2<f32>>;
@group(0) @binding(3) var<storage, read_write> div_b_out: array<f32>;
@group(0) @binding(4) var<storage, read_write> current_out: array<f32>;
@group(0) @binding(5) var<storage, read_write> psi_out: array<f32>;
@group(0) @binding(6) var<storage, read_write> bphi_out: array<f32>;

// Poloidal-plane coordinates for the 2.5-D axisymmetric tokamak toy. Grid
// index k maps to c(k) = (k/N - 0.5)·2a, R = R0 + c(x), Z = c(y). R0 keeps
// R > 0. In Cartesian mode the geometry coords are unused (geomBtor = 0).
fn geom_R(px: f32) -> f32 {
    return uniforms.geomR0 + (px / f32(uniforms.dims.x) - 0.5)
        * 2.0 * uniforms.geomMinor;
}
fn geom_Z(py: f32) -> f32 {
    return (py / f32(uniforms.dims.y) - 0.5) * 2.0 * uniforms.geomMinor;
}

// Periodic boundary indexing mirroring ZMod Nx × ZMod Ny in Stencil.lean
fn get_flat_index(x: i32, y: i32) -> u32 {
    let nx = i32(uniforms.dims.x);
    let ny = i32(uniforms.dims.y);
    let px = (x % nx + nx) % nx;
    let py = (y % ny + ny) % ny;
    return u32(py) * uniforms.dims.x + u32(px);
}

// ----------------------------------------------------------------------------
// Kernel 1: B = curl(ψ)
// ----------------------------------------------------------------------------
@compute @workgroup_size(16, 16)
fn compute_b_field(@builtin(global_invocation_id) id: vec3<u32>) {
    if (id.x >= uniforms.dims.x || id.y >= uniforms.dims.y) {
        return;
    }

    let x = i32(id.x);
    let y = i32(id.y);

    // dx(f) = f(x+1, y) - f(x-1, y)
    let psi_xp1 = psi_in[get_flat_index(x + 1, y)];
    let psi_xm1 = psi_in[get_flat_index(x - 1, y)];
    let dx_psi = psi_xp1 - psi_xm1;

    // dy(f) = f(x, y+1) - f(x, y-1)
    let psi_yp1 = psi_in[get_flat_index(x, y + 1)];
    let psi_ym1 = psi_in[get_flat_index(x, y - 1)];
    let dy_psi = psi_yp1 - psi_ym1;

    // B_x = dy(ψ), B_y = -dx(ψ) (Unnormalized, exactly matching Stencil.lean)
    let idx = id.y * uniforms.dims.x + id.x;
    b_field[idx] = vec2<f32>(dy_psi, -dx_psi);
}

// ----------------------------------------------------------------------------
// Kernel 2: ∇·B (Divergence Verification Kernel)
// ----------------------------------------------------------------------------
@compute @workgroup_size(16, 16)
fn compute_div_b(@builtin(global_invocation_id) id: vec3<u32>) {
    if (id.x >= uniforms.dims.x || id.y >= uniforms.dims.y) {
        return;
    }

    let x = i32(id.x);
    let y = i32(id.y);

    // dx(B_x) = B_x(x+1, y) - B_x(x-1, y)
    let bx_xp1 = b_field[get_flat_index(x + 1, y)].x;
    let bx_xm1 = b_field[get_flat_index(x - 1, y)].x;
    let dx_bx = bx_xp1 - bx_xm1;

    // dy(B_y) = B_y(x, y+1) - B_y(x, y-1)
    let by_yp1 = b_field[get_flat_index(x, y + 1)].y;
    let by_ym1 = b_field[get_flat_index(x, y - 1)].y;
    let dy_by = by_yp1 - by_ym1;

    // div(B) = dx(B_x) + dy(B_y)
    let idx = id.y * uniforms.dims.x + id.x;
    div_b_out[idx] = dx_bx + dy_by;
}

// ----------------------------------------------------------------------------
// Kernel 3: Current Density J_z = (curl B)_z = -laplacian₂ψ
// ----------------------------------------------------------------------------
// Composes the two central differences: dx(By) with By = -dx(ψ) reaches taps
// at index distance 2, so J_z = -(dx∘dx + dy∘dy)ψ is minus the spacing-two
// five-point Laplacian — certified by Stencil.curl_curl_eq_neg_laplacian2.
// It is NOT the near-neighbour -∇²ψ: labels below say what the theorem says.
@compute @workgroup_size(16, 16)
fn compute_current(@builtin(global_invocation_id) id: vec3<u32>) {
    if (id.x >= uniforms.dims.x || id.y >= uniforms.dims.y) {
        return;
    }

    let x = i32(id.x);
    let y = i32(id.y);

    // dx(B_y) = B_y(x+1, y) - B_y(x-1, y)
    let by_xp1 = b_field[get_flat_index(x + 1, y)].y;
    let by_xm1 = b_field[get_flat_index(x - 1, y)].y;
    let dx_by = by_xp1 - by_xm1;

    // dy(B_x) = B_x(x, y+1) - B_x(x, y-1)
    let bx_yp1 = b_field[get_flat_index(x, y + 1)].x;
    let bx_ym1 = b_field[get_flat_index(x, y - 1)].x;
    let dy_bx = bx_yp1 - bx_ym1;

    // J_z = dx(B_y) - dy(B_x)
    let idx = id.y * uniforms.dims.x + id.x;
    current_out[idx] = dx_by - dy_bx;
}

// ----------------------------------------------------------------------------
// Kernel 5: Toroidal field B_φ = B₀·R₀/R  (2.5-D axisymmetric tokamak toy)
// ----------------------------------------------------------------------------
// Axisymmetry (∂_φ = 0) reduces a tokamak to the poloidal (R, Z) plane plus
// this toroidal scalar. B_φ is the classic vacuum 1/R toroidal field; the
// poloidal part comes from the stream function curl (certifiably div-free),
// so the physical cylindrical ∇·B = (1/R)·(reduced div) vanishes. geomBtor =
// 0 in Cartesian mode, so this layer is identically zero there. Mirrors
// reference_mhd.toroidal_field.
@compute @workgroup_size(16, 16)
fn compute_bphi(@builtin(global_invocation_id) id: vec3<u32>) {
    if (id.x >= uniforms.dims.x || id.y >= uniforms.dims.y) {
        return;
    }
    let x = f32(id.x);
    let idx = id.y * uniforms.dims.x + id.x;
    let R = geom_R(x);
    // R > 0 by construction (R0 keeps the axis off the seam).
    bphi_out[idx] = uniforms.geomBtor * uniforms.geomR0 / R;
}

// ----------------------------------------------------------------------------
// Kernel 4: Conservative flux-form advection of ψ along a prescribed flow u₀
// ----------------------------------------------------------------------------
// Donor-cell (upwind) flux form over the periodic grid. Each cell changes by
// net edge inflow only, so total flux Σψ is conserved to rounding of the
// individual ops for ANY flux pair — mirror of Stencil.fluxDiv_sum_eq_zero.
// There is no dissipation term: any L2 decay the scheme shows is its own
// (visible, metered) truncation error, never a hidden knob. Stable under the
// CFL bound dt · max|u₀| ≤ 1.
//
//   ψ' = ψ + Fx(x-1,y) - Fx(x,y) + Fy(x,y-1) - Fy(x,y)
//   Fx(i,j) = dt·(max(u0x,0)·ψ(i,j) + min(u0x,0)·ψ(i+1,j))   u0x = u₀ at (i,j)
//   Fy(i,j) = dt·(max(u0y,0)·ψ(i,j) + min(u0y,0)·ψ(i,j+1))   u0y = u₀ at (i,j)

const TWO_PI: f32 = 6.28318530718;

// Prescribed, ψ-independent, divergence-free flow u₀ (mirror of
// reference_mhd.flow_velocity). Coord uses the same physical map as initGrid:
// p = (k/N)·2π, k = cell index.
fn flow_vel(px: f32, py: f32) -> vec2<f32> {
    let cp = px / f32(uniforms.dims.x) * TWO_PI;
    let sp = py / f32(uniforms.dims.y) * TWO_PI;
    let amp = uniforms.flowAmp;
    if (uniforms.flowType == 1u) {
        // shear: φ₀ = -amp·cos(y)  ->  u₀ = (amp·sin y, 0)
        return vec2<f32>(amp * sin(sp), 0.0);
    }
    if (uniforms.flowType == 2u) {
        // rigid poloidal rotation about the magnetic axis (R0, 0):
        // u₀ = amp·(-Z, R - R0). Divergence-free and separatrix-free, so it
        // swirls flux surfaces cleanly with no grid-aligned `#`.
        let R = geom_R(px);
        let Z = geom_Z(py);
        return vec2<f32>(-amp * Z, amp * (R - uniforms.geomR0));
    }
    // vortex: φ₀ = amp·cos(x)·cos(y) -> u₀ = amp·(cosx·siny, -sinx·cosy)
    return vec2<f32>(amp * cos(cp) * sin(sp), -amp * sin(cp) * cos(sp));
}

@compute @workgroup_size(16, 16)
fn advect_psi(@builtin(global_invocation_id) id: vec3<u32>) {
    if (id.x >= uniforms.dims.x || id.y >= uniforms.dims.y) {
        return;
    }

    let x = i32(id.x);
    let y = i32(id.y);
    let idx = id.y * uniforms.dims.x + id.x;
    let dt = uniforms.dt;

    // Own and neighbouring ψ values (periodic wrapping mirrors ZMod).
    let psi_c = psi_in[idx];
    let psi_xm1 = psi_in[get_flat_index(x - 1, y)];
    let psi_xp1 = psi_in[get_flat_index(x + 1, y)];
    let psi_ym1 = psi_in[get_flat_index(x, y - 1)];
    let psi_yp1 = psi_in[get_flat_index(x, y + 1)];

    // Prescribed flow at this cell and the upwind neighbours. Unlike u = B,
    // u₀·∇ψ ≠ 0, so this is genuinely non-degenerate transport.
    let u_c = flow_vel(f32(x), f32(y));
    let u_xm1 = flow_vel(f32(x - 1), f32(y));
    let u_ym1 = flow_vel(f32(x), f32(y - 1));

    // Edge fluxes. fx_in crosses the left edge (i-1 -> i), fx_out the right
    // edge (i -> i+1); fy_in crosses the bottom edge (j-1 -> j), fy_out the
    // top edge (j -> j+1). Donor is the upwind cell in each case.
    let fx_in  = dt * (max(u_xm1.x, 0.0) * psi_xm1 + min(u_xm1.x, 0.0) * psi_c);
    let fx_out = dt * (max(u_c.x, 0.0) * psi_c + min(u_c.x, 0.0) * psi_xp1);
    let fy_in  = dt * (max(u_ym1.y, 0.0) * psi_ym1 + min(u_ym1.y, 0.0) * psi_c);
    let fy_out = dt * (max(u_c.y, 0.0) * psi_c + min(u_c.y, 0.0) * psi_yp1);

    psi_out[idx] = psi_c + (fx_in - fx_out) + (fy_in - fy_out);
}
