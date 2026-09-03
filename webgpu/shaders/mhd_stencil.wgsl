// mhd_stencil.wgsl — 2D Discrete MHD WebGPU Compute Kernels
// ==========================================================
// Implements the discrete calculus stencils certified in LaserCortex/Stencil.lean:
//
// 1. compute_b_field:   B = curl(ψ z_hat) = (dy(ψ), -dx(ψ))
// 2. compute_div_b:     div(B) = dx(B_x) + dy(B_y)
//                       [Provably 0 by Stencil.div_curl_eq_zero — F1]
// 3. compute_current:   J_z = dx(B_y) - dy(B_x)
//                       [= -laplacian₂ψ by Stencil.curl_curl_eq_neg_laplacian2]
// 4. advect_psi:        Conservative flux-form transport of ψ along u = B
//                       [Σψ conserved by Stencil.fluxDiv_sum_eq_zero; scheme
//                        details live in the flux pair and cannot break it]

struct SimUniforms {
    dims: vec2<u32>,        // Grid resolution (Nx, Ny)
    dt: f32,                // Simulation timestep (CFL: dt · max|u| ≤ 1)
    dissipation: f32,       // Reserved; ideal toy ships zero. The flux-form
};                          // scheme has no dissipation knob (see advect_psi).

@group(0) @binding(0) var<uniform> uniforms: SimUniforms;
@group(0) @binding(1) var<storage, read> psi_in: array<f32>;
@group(0) @binding(2) var<storage, read_write> b_field: array<vec2<f32>>;
@group(0) @binding(3) var<storage, read_write> div_b_out: array<f32>;
@group(0) @binding(4) var<storage, read_write> current_out: array<f32>;
@group(0) @binding(5) var<storage, read_write> psi_out: array<f32>;

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
// Kernel 4: Conservative flux-form advection of ψ along u = B (toy transport)
// ----------------------------------------------------------------------------
// Donor-cell (upwind) flux form over the periodic grid. Each cell changes by
// net edge inflow only, so total flux Σψ is conserved to rounding of the
// individual ops for ANY flux pair — mirror of Stencil.fluxDiv_sum_eq_zero.
// There is no dissipation term: any L2 decay the scheme shows is its own
// (visible, metered) truncation error, never a hidden knob. Stable under the
// CFL bound dt · max|u| ≤ 1.
//
//   ψ' = ψ + Fx(x-1,y) - Fx(x,y) + Fy(x,y-1) - Fy(x,y)
//   Fx(i,j) = dt·(max(vx,0)·ψ(i,j) + min(vx,0)·ψ(i+1,j))   vx = B_x at (i,j)
//   Fy(i,j) = dt·(max(vy,0)·ψ(i,j) + min(vy,0)·ψ(i,j+1))   vy = B_y at (i,j)
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

    // Cell-centred velocity u = B at this cell and at the upwind neighbours
    // (left neighbour for the x-edge, bottom neighbour for the y-edge).
    let v_c = b_field[idx];
    let vx_xm1 = b_field[get_flat_index(x - 1, y)].x;
    let vy_ym1 = b_field[get_flat_index(x, y - 1)].y;

    // Edge fluxes. fx_in crosses the left edge (i-1 -> i), fx_out the right
    // edge (i -> i+1); fy_in crosses the bottom edge (j-1 -> j), fy_out the
    // top edge (j -> j+1). Donor is the upwind cell in each case.
    let fx_in  = dt * (max(vx_xm1, 0.0) * psi_xm1 + min(vx_xm1, 0.0) * psi_c);
    let fx_out = dt * (max(v_c.x, 0.0) * psi_c + min(v_c.x, 0.0) * psi_xp1);
    let fy_in  = dt * (max(vy_ym1, 0.0) * psi_ym1 + min(vy_ym1, 0.0) * psi_c);
    let fy_out = dt * (max(v_c.y, 0.0) * psi_c + min(v_c.y, 0.0) * psi_yp1);

    psi_out[idx] = psi_c + (fx_in - fx_out) + (fy_in - fy_out);
}
