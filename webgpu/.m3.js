
const N = 64;           // radial (r) and axial (z) resolution
const NK = 32;          // azimuthal (phi) planes  -- Cost3D contract: 64x64x32, J=40
const TOT = N * N * NK;
const DX = (2 * Math.PI) / N;
const DX2 = DX * DX;
const DXP = (2 * Math.PI) / NK;
const canvas = document.getElementById("view");

function fatal(msg) {
  console.error("[LaserCortex] " + msg);
  const s = document.getElementById("gpuStatus");
  if (s) { s.style.display = "block"; s.textContent = msg; }
  try {
    const c = canvas.getContext("2d");
    if (c) {
      c.fillStyle = "#111827"; c.fillRect(0, 0, canvas.width, canvas.height);
      c.fillStyle = "#eab308"; c.font = "bold 13px monospace";
      c.fillText("WEBGPU UNAVAILABLE", 18, canvas.height / 2);
    }
  } catch (e) {}
}
function browserHint() {
  if (/Firefox\//.test(navigator.userAgent))
    return "Firefox: WebGPU on by default since v141 (needs Vulkan; check about:support).";
  return "Chromium: check chrome://gpu and flags --use-gl=angle --use-angle=vulkan --ignore-gpu-blocklist, optionally --enable-unsafe-webgpu.";
}

const WGSL = `
struct CUniforms {
    dims    : vec3<u32>,
    dt      : f32,
    time    : f32,
    driveAmp: f32,
    driveT  : f32,
    which   : u32,
    njac    : u32,
    phiSrc  : u32,
}
struct RUniforms {
    eye      : vec4<f32>,
    fwd      : vec4<f32>,
    right    : vec4<f32>,
    up       : vec4<f32>,
    tanHalf  : f32,
    aspect   : f32,
    rG       : f32,
    jmax     : f32,
    levelMin : f32,
    levelInv : f32,
    which    : f32,
    wR0      : f32,
    wZ0      : f32,
    wSigma   : f32,
    exposure : f32,
    gamma    : f32,
    glowLift : f32,
    rDome    : f32,
    axisMode : f32,
    mirror   : f32,
}

@group(0) @binding(0)  var<uniform> cu : CUniforms;
@group(0) @binding(1)  var<uniform> ru : RUniforms;
@group(0) @binding(2)  var<storage, read_write> psi_a  : array<f32>;
@group(0) @binding(3)  var<storage, read_write> psi_b  : array<f32>;
@group(0) @binding(4)  var<storage, read_write> om_a   : array<f32>;
@group(0) @binding(5)  var<storage, read_write> om_b   : array<f32>;
@group(0) @binding(6)  var<storage, read_write> phi_a  : array<f32>;
@group(0) @binding(7)  var<storage, read_write> phi_b  : array<f32>;
@group(0) @binding(8)  var<storage, read_write> jbuf   : array<f32>;
@group(0) @binding(9)  var<storage, read_write> drivef : array<f32>;

const PI   : f32 = 3.141592653589793;
const NXF  : f32 = 64.0;
const NYF  : f32 = 64.0;
const NZF  : f32 = 32.0;
const DEL   : f32 = 0.09817477042468103;    // 2*pi/64
const DEL2  : f32 = 0.009638285185425472;
const DELP  : f32 = 0.19634954084936207;     // 2*pi/32
const DELP2 : f32 = 0.038553140741701886;

fn ix(i : u32, j : u32, k : u32) -> u32 { return (k * cu.dims.y + j) * cu.dims.x + i; }

// ---- 3-D stencil helpers (storage arrays cannot be function parameters, so
//      these read the module-scope buffers via scalar selects; sel: 0 = _a,
//      1 = _b; phi is selected by cu.phiSrc) ----
fn dxPsi(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.x; let xm = (i + n - 1u) % n; let xp = (i + 1u) % n;
    let a = select(psi_b[ix(xm,j,k)], psi_a[ix(xm,j,k)], sel == 0u);
    let b = select(psi_b[ix(xp,j,k)], psi_a[ix(xp,j,k)], sel == 0u);
    return (b - a) / (2.0 * DEL);
}
fn dyPsi(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.y; let ym = (j + n - 1u) % n; let yp = (j + 1u) % n;
    let a = select(psi_b[ix(i,ym,k)], psi_a[ix(i,ym,k)], sel == 0u);
    let b = select(psi_b[ix(i,yp,k)], psi_a[ix(i,yp,k)], sel == 0u);
    return (b - a) / (2.0 * DEL);
}
fn dzPsi(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.z; let km = (k + n - 1u) % n; let kp = (k + 1u) % n;
    let a = select(psi_b[ix(i,j,km)], psi_a[ix(i,j,km)], sel == 0u);
    let b = select(psi_b[ix(i,j,kp)], psi_a[ix(i,j,kp)], sel == 0u);
    return (b - a) / (2.0 * DELP);
}
fn dxOm(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.x; let xm = (i + n - 1u) % n; let xp = (i + 1u) % n;
    let a = select(om_b[ix(xm,j,k)], om_a[ix(xm,j,k)], sel == 0u);
    let b = select(om_b[ix(xp,j,k)], om_a[ix(xp,j,k)], sel == 0u);
    return (b - a) / (2.0 * DEL);
}
fn dyOm(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.y; let ym = (j + n - 1u) % n; let yp = (j + 1u) % n;
    let a = select(om_b[ix(i,ym,k)], om_a[ix(i,ym,k)], sel == 0u);
    let b = select(om_b[ix(i,yp,k)], om_a[ix(i,yp,k)], sel == 0u);
    return (b - a) / (2.0 * DEL);
}
fn dzOm(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.z; let km = (k + n - 1u) % n; let kp = (k + 1u) % n;
    let a = select(om_b[ix(i,j,km)], om_a[ix(i,j,km)], sel == 0u);
    let b = select(om_b[ix(i,j,kp)], om_a[ix(i,j,kp)], sel == 0u);
    return (b - a) / (2.0 * DELP);
}
fn dxPh(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.x; let xm = (i + n - 1u) % n; let xp = (i + 1u) % n;
    let a = select(phi_b[ix(xm,j,k)], phi_a[ix(xm,j,k)], sel == 0u);
    let b = select(phi_b[ix(xp,j,k)], phi_a[ix(xp,j,k)], sel == 0u);
    return (b - a) / (2.0 * DEL);
}
fn dyPh(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.y; let ym = (j + n - 1u) % n; let yp = (j + 1u) % n;
    let a = select(phi_b[ix(i,ym,k)], phi_a[ix(i,ym,k)], sel == 0u);
    let b = select(phi_b[ix(i,yp,k)], phi_a[ix(i,yp,k)], sel == 0u);
    return (b - a) / (2.0 * DEL);
}
fn dzPh(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.z; let km = (k + n - 1u) % n; let kp = (k + 1u) % n;
    let a = select(phi_b[ix(i,j,km)], phi_a[ix(i,j,km)], sel == 0u);
    let b = select(phi_b[ix(i,j,kp)], phi_a[ix(i,j,kp)], sel == 0u);
    return (b - a) / (2.0 * DELP);
}
fn dxJ(i : u32, j : u32, k : u32) -> f32 {
    let n = cu.dims.x; let xm = (i + n - 1u) % n; let xp = (i + 1u) % n;
    return (jbuf[ix(xp,j,k)] - jbuf[ix(xm,j,k)]) / (2.0 * DEL);
}
fn dyJ(i : u32, j : u32, k : u32) -> f32 {
    let n = cu.dims.y; let ym = (j + n - 1u) % n; let yp = (j + 1u) % n;
    return (jbuf[ix(i,yp,k)] - jbuf[ix(i,ym,k)]) / (2.0 * DEL);
}
fn dzJ(i : u32, j : u32, k : u32) -> f32 {
    let n = cu.dims.z; let km = (k + n - 1u) % n; let kp = (k + 1u) % n;
    return (jbuf[ix(i,j,kp)] - jbuf[ix(i,j,km)]) / (2.0 * DELP);
}
fn lap3Psi(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.x; let m = cu.dims.y; let q = cu.dims.z;
    let xm = (i + n - 1u) % n; let xp = (i + 1u) % n;
    let ym = (j + m - 1u) % m; let yp = (j + 1u) % m;
    let km = (k + q - 1u) % q; let kp = (k + 1u) % q;
    let s = select(psi_b[ix(xp,j,k)], psi_a[ix(xp,j,k)], sel == 0u)
          + select(psi_b[ix(xm,j,k)], psi_a[ix(xm,j,k)], sel == 0u)
          + select(psi_b[ix(i,yp,k)], psi_a[ix(i,yp,k)], sel == 0u)
          + select(psi_b[ix(i,ym,k)], psi_a[ix(i,ym,k)], sel == 0u)
          + select(psi_b[ix(i,j,kp)], psi_a[ix(i,j,kp)], sel == 0u)
          + select(psi_b[ix(i,j,km)], psi_a[ix(i,j,km)], sel == 0u)
          - 6.0 * select(psi_b[ix(i,j,k)], psi_a[ix(i,j,k)], sel == 0u);
    return s / DEL2;
}
fn lap3Om(i : u32, j : u32, k : u32, sel : u32) -> f32 {
    let n = cu.dims.x; let m = cu.dims.y; let q = cu.dims.z;
    let xm = (i + n - 1u) % n; let xp = (i + 1u) % n;
    let ym = (j + m - 1u) % m; let yp = (j + 1u) % m;
    let km = (k + q - 1u) % q; let kp = (k + 1u) % q;
    let s = select(om_b[ix(xp,j,k)], om_a[ix(xp,j,k)], sel == 0u)
          + select(om_b[ix(xm,j,k)], om_a[ix(xm,j,k)], sel == 0u)
          + select(om_b[ix(i,yp,k)], om_a[ix(i,yp,k)], sel == 0u)
          + select(om_b[ix(i,ym,k)], om_a[ix(i,ym,k)], sel == 0u)
          + select(om_b[ix(i,j,kp)], om_a[ix(i,j,kp)], sel == 0u)
          + select(om_b[ix(i,j,km)], om_a[ix(i,j,km)], sel == 0u)
          - 6.0 * select(om_b[ix(i,j,k)], om_a[ix(i,j,k)], sel == 0u);
    return s / DEL2;
}
fn br3(ax : f32, ay : f32, az : f32, bx : f32, by : f32, bz : f32) -> f32 {
    return (ax * by - ay * bx) + (ay * bz - az * by) + (az * bx - ax * bz);
}

@compute @workgroup_size(8,8,8)
fn init_drive(@builtin(global_invocation_id) id : vec3<u32>) {
    if (id.x >= cu.dims.x || id.y >= cu.dims.y || id.z >= cu.dims.z) { return; }
    let i = id.x; let j = id.y; let k = id.z;
    let r = 2.0 * PI * (f32(i)) / NXF - PI;
    let zz = 2.0 * PI * (f32(j)) / NYF - PI;
    let ph = 2.0 * PI * (f32(k)) / NZF - PI;
    let rho2 = r * r + zz * zz;
    // AC flux drive: electrode dipole shape, mildly phi-modulated so the
    // azimuthal structure is forced, not pure axisymmetry
    drivef[ix(i,j,k)] = (r * r) / pow(rho2 + 0.25, 1.5) * exp(-rho2 / 5.12)
        * (1.0 + 0.3 * sin(ph));
}

@compute @workgroup_size(8,8,8)
fn lapj(@builtin(global_invocation_id) id : vec3<u32>) {
    if (id.x >= cu.dims.x || id.y >= cu.dims.y || id.z >= cu.dims.z) { return; }
    jbuf[ix(id.x,id.y,id.z)] = -lap3Psi(id.x, id.y, id.z, cu.which);
}

@compute @workgroup_size(8,8,8)
fn poisson_a2b(@builtin(global_invocation_id) id : vec3<u32>) {
    if (id.x >= cu.dims.x || id.y >= cu.dims.y || id.z >= cu.dims.z) { return; }
    let i = id.x; let j = id.y; let k = id.z;
    let n = cu.dims.x; let m = cu.dims.y; let q = cu.dims.z;
    let omv = select(om_b[ix(i,j,k)], om_a[ix(i,j,k)], cu.which == 0u);
    let taps = phi_a[ix((i+1u)%n,j,k)] + phi_a[ix((i+n-1u)%n,j,k)]
             + phi_a[ix(i,(j+1u)%m,k)] + phi_a[ix(i,(j+m-1u)%m,k)]
             + phi_a[ix(i,j,(k+1u)%q)] + phi_a[ix(i,j,(k+q-1u)%q)];
    phi_b[ix(i,j,k)] = (taps + omv * DEL2) / 6.0;
}
@compute @workgroup_size(8,8,8)
fn poisson_b2a(@builtin(global_invocation_id) id : vec3<u32>) {
    if (id.x >= cu.dims.x || id.y >= cu.dims.y || id.z >= cu.dims.z) { return; }
    let i = id.x; let j = id.y; let k = id.z;
    let n = cu.dims.x; let m = cu.dims.y; let q = cu.dims.z;
    let omv = select(om_b[ix(i,j,k)], om_a[ix(i,j,k)], cu.which == 0u);
    let taps = phi_b[ix((i+1u)%n,j,k)] + phi_b[ix((i+n-1u)%n,j,k)]
             + phi_b[ix(i,(j+1u)%m,k)] + phi_b[ix(i,(j+m-1u)%m,k)]
             + phi_b[ix(i,j,(k+1u)%q)] + phi_b[ix(i,j,(k+q-1u)%q)];
    phi_a[ix(i,j,k)] = (taps + omv * DEL2) / 6.0;
}

@compute @workgroup_size(8,8,8)
fn mid_rhs(@builtin(global_invocation_id) id : vec3<u32>) {
    if (id.x >= cu.dims.x || id.y >= cu.dims.y || id.z >= cu.dims.z) { return; }
    let i = id.x; let j = id.y; let k = id.z;
    let ps = cu.phiSrc;
    let pdx = dxPh(i,j,k,ps); let pdy = dyPh(i,j,k,ps); let pdz = dzPh(i,j,k,ps);
    let sdx = dxPsi(i,j,k,0u); let sdy = dyPsi(i,j,k,0u); let sdz = dzPsi(i,j,k,0u);
    let wdx = dxOm(i,j,k,0u); let wdy = dyOm(i,j,k,0u); let wdz = dzOm(i,j,k,0u);
    let jdx = dxJ(i,j,k); let jdy = dyJ(i,j,k); let jdz = dzJ(i,j,k);
    let bpp = br3(pdx,pdy,pdz, sdx,sdy,sdz);
    let bpo = br3(pdx,pdy,pdz, wdx,wdy,wdz);
    let bpj = br3(sdx,sdy,sdz, jdx,jdy,jdz);
    let dpsi = -bpp + 0.002 * lap3Psi(i,j,k,0u)
        + cu.driveAmp * sin(2.0 * PI * cu.time / cu.driveT) * drivef[ix(i,j,k)];
    let dom  = -bpo + bpj + 0.001 * lap3Om(i,j,k,0u);
    psi_b[ix(i,j,k)] = psi_a[ix(i,j,k)] + 0.5 * cu.dt * dpsi;
    om_b[ix(i,j,k)]  = om_a[ix(i,j,k)]  + 0.5 * cu.dt * dom;
}

@compute @workgroup_size(8,8,8)
fn adv_rhs(@builtin(global_invocation_id) id : vec3<u32>) {
    if (id.x >= cu.dims.x || id.y >= cu.dims.y || id.z >= cu.dims.z) { return; }
    let i = id.x; let j = id.y; let k = id.z;
    let ps = cu.phiSrc;
    let pdx = dxPh(i,j,k,ps); let pdy = dyPh(i,j,k,ps); let pdz = dzPh(i,j,k,ps);
    let sdx = dxPsi(i,j,k,1u); let sdy = dyPsi(i,j,k,1u); let sdz = dzPsi(i,j,k,1u);
    let wdx = dxOm(i,j,k,1u); let wdy = dyOm(i,j,k,1u); let wdz = dzOm(i,j,k,1u);
    let jdx = dxJ(i,j,k); let jdy = dyJ(i,j,k); let jdz = dzJ(i,j,k);
    let bpp = br3(pdx,pdy,pdz, sdx,sdy,sdz);
    let bpo = br3(pdx,pdy,pdz, wdx,wdy,wdz);
    let bpj = br3(sdx,sdy,sdz, jdx,jdy,jdz);
    let dpsi = -bpp + 0.002 * lap3Psi(i,j,k,1u)
        + cu.driveAmp * sin(2.0 * PI * cu.time / cu.driveT) * drivef[ix(i,j,k)];
    let dom  = -bpo + bpj + 0.001 * lap3Om(i,j,k,1u);
    psi_a[ix(i,j,k)] = psi_a[ix(i,j,k)] + cu.dt * dpsi;
    om_a[ix(i,j,k)]  = om_a[ix(i,j,k)]  + cu.dt * dom;
}

// ------------------------------------------------------------------ //
// render: ray-marched axisymmetric globe                                //
// ------------------------------------------------------------------ //
// axis convention is user-selectable (X/Y/Z for the polar axis) + mirror,
// so the scene orientation is a control, not a guess.
fn rrOf(p : vec3<f32>) -> f32 {
    if (ru.axisMode < 0.5) { return sqrt(p.y * p.y + p.z * p.z); }
    if (ru.axisMode < 1.5) { return sqrt(p.x * p.x + p.z * p.z); }
    return sqrt(p.x * p.x + p.y * p.y);
}
fn axOf(p : vec3<f32>) -> f32 {
    var a = 0.0;
    if (ru.axisMode < 0.5) { a = p.x; }
    else if (ru.axisMode < 1.5) { a = p.y; }
    else { a = p.z; }
    if (ru.mirror > 0.5) { a = -a; }
    return a;
}
fn winEnv(r : f32, z : f32) -> f32 {
    let dr = r - ru.wR0; let dz = z - ru.wZ0;
    let d2 = dr * dr + dz * dz;
    return exp(-d2 / (2.0 * ru.wSigma * ru.wSigma));
}
// azimuth of the world point about the selected axis (transverse pair of
// the same convention as rrOf/axOf, so r and phi are consistent)
fn phiOf(p : vec3<f32>) -> f32 {
    if (ru.axisMode < 0.5) { return atan2(p.z, p.y); }
    if (ru.axisMode < 1.5) { return atan2(p.z, p.x); }
    return atan2(p.y, p.x);
}
// trilinear sampling of psi on the 64x64x32 grid: (r,z) clamped to the
// meridional window, phi period-wrapped. Buffer layout (k*64+j)*64+i (3D).
fn psiAt3(r : f32, z : f32, ph : f32) -> f32 {
    let useA = ru.which < 0.5;
    let fx = clamp((r + PI) / (2.0 * PI), 0.0, 1.0) * 63.0;
    let fy = clamp((z + PI) / (2.0 * PI), 0.0, 1.0) * 63.0;
    let fp = (ph + PI) / (2.0 * PI) * 32.0;
    let x0 = u32(floor(fx)); let y0 = u32(floor(fy)); let p0 = u32(floor(fp)) % 32u;
    let x1 = min(x0 + 1u, 63u); let y1 = min(y0 + 1u, 63u); let p1 = (p0 + 1u) % 32u;
    let tx = fx - f32(x0); let ty = fy - f32(y0); let tp = fp - floor(fp);
    let v00 = select(psi_b[(p0 * 64u + y0) * 64u + x0], psi_a[(p0 * 64u + y0) * 64u + x0], useA);
    let v01 = select(psi_b[(p1 * 64u + y0) * 64u + x0], psi_a[(p1 * 64u + y0) * 64u + x0], useA);
    let v10 = select(psi_b[(p0 * 64u + y1) * 64u + x0], psi_a[(p0 * 64u + y1) * 64u + x0], useA);
    let v11 = select(psi_b[(p1 * 64u + y1) * 64u + x0], psi_a[(p1 * 64u + y1) * 64u + x0], useA);
    let v20 = select(psi_b[(p0 * 64u + y0) * 64u + x1], psi_a[(p0 * 64u + y0) * 64u + x1], useA);
    let v21 = select(psi_b[(p1 * 64u + y0) * 64u + x1], psi_a[(p1 * 64u + y0) * 64u + x1], useA);
    let v30 = select(psi_b[(p0 * 64u + y1) * 64u + x1], psi_a[(p0 * 64u + y1) * 64u + x1], useA);
    let v31 = select(psi_b[(p1 * 64u + y1) * 64u + x1], psi_a[(p1 * 64u + y1) * 64u + x1], useA);
    let b0 = mix(v00, v10, ty); let b1 = mix(v01, v11, ty);
    let b2 = mix(v20, v30, ty); let b3 = mix(v21, v31, ty);
    let c0 = mix(b0, b2, tx); let c1 = mix(b1, b3, tx);
    return mix(c0, c1, tp);
}
// trilinear |j| with the same layout (phi wrapped)
fn jAt3(r : f32, z : f32, ph : f32) -> f32 {
    let fx = clamp((r + PI) / (2.0 * PI), 0.0, 1.0) * 63.0;
    let fy = clamp((z + PI) / (2.0 * PI), 0.0, 1.0) * 63.0;
    let fp = (ph + PI) / (2.0 * PI) * 32.0;
    let x0 = u32(floor(fx)); let y0 = u32(floor(fy)); let p0 = u32(floor(fp)) % 32u;
    let x1 = min(x0 + 1u, 63u); let y1 = min(y0 + 1u, 63u); let p1 = (p0 + 1u) % 32u;
    let tx = fx - f32(x0); let ty = fy - f32(y0); let tp = fp - floor(fp);
    let v00 = jbuf[(p0 * 64u + y0) * 64u + x0]; let v01 = jbuf[(p1 * 64u + y0) * 64u + x0];
    let v10 = jbuf[(p0 * 64u + y1) * 64u + x0]; let v11 = jbuf[(p1 * 64u + y1) * 64u + x0];
    let v20 = jbuf[(p0 * 64u + y0) * 64u + x1]; let v21 = jbuf[(p1 * 64u + y0) * 64u + x1];
    let v30 = jbuf[(p0 * 64u + y1) * 64u + x1]; let v31 = jbuf[(p1 * 64u + y1) * 64u + x1];
    let b0 = mix(v00, v10, ty); let b1 = mix(v01, v11, ty);
    let b2 = mix(v20, v30, ty); let b3 = mix(v21, v31, ty);
    let c0 = mix(b0, b2, tx); let c1 = mix(b1, b3, tx);
    return abs(mix(c0, c1, tp));
}
fn heatColor(t : f32) -> vec3<f32> {
    let c = clamp(t, 0.0, 1.0);
    if (c < 0.55) {
        let k = c / 0.55;
        return mix(vec3<f32>(0.12, 0.06, 0.28), vec3<f32>(0.62, 0.10, 0.55), k);
    }
    let k = (c - 0.55) / 0.45;
    return mix(vec3<f32>(0.62, 0.10, 0.55), vec3<f32>(1.0, 0.78, 0.25), k);
}

struct VSOut {
    @builtin(position) pos : vec4<f32>,
    @location(0) uv : vec2<f32>,
}
@vertex
fn vs(@builtin(vertex_index) vi : u32) -> VSOut {
    var p = array<vec2<f32>,3>(vec2<f32>(-1.0,-1.0), vec2<f32>(3.0,-1.0), vec2<f32>(-1.0,3.0));
    return VSOut(vec4<f32>(p[vi], 0.0, 1.0), p[vi]);
}

@fragment
fn fs(in : VSOut) -> @location(0) vec4<f32> {
    let ndc = in.uv;
    let rd = normalize(ru.fwd.xyz + ru.right.xyz * ndc.x * ru.tanHalf * ru.aspect
                       + ru.up.xyz * ndc.y * ru.tanHalf);
    let ro = ru.eye.xyz;
    // sphere intersections: electrode core (rG) and glass dome (rDome)
    let b = dot(ro, rd);
    let c = dot(ro, ro) - ru.rG * ru.rG;
    let disc = b * b - c;
    var tG = -1.0;
    if (disc > 0.0) {
        let sq = sqrt(disc);
        let t0 = -b - sq; let t1 = -b + sq;
        if (t0 > 0.0) { tG = t0; } else if (t1 > 0.0) { tG = t1; }
    }
    let cD = dot(ro, ro) - ru.rDome * ru.rDome;
    let discD = b * b - cD;
    var tDome = -1.0;      // entry hit (the visible glass surface)
    var tDome1 = -1.0;     // exit hit (bounds the interior march)
    if (discD > 0.0) {
        let sq = sqrt(discD);
        let t0 = -b - sq; let t1 = -b + sq;
        if (t0 > 0.0) { tDome = t0; } else if (t1 > 0.0) { tDome = t1; }
        if (t1 > 0.0) { tDome1 = t1; }
    }
    var accStream = vec3<f32>(0.0);
    var accLine = 0.0;
    let steps = 96;
    let tmax = length(ru.eye.xyz) + 2.6;
    var marchEnd = tmax;
    if (tDome1 > 0.0) { marchEnd = min(marchEnd, tDome1 - 0.012); }
    else { marchEnd = 0.0; }   // ray misses the glass ball: nothing inside
    for (var s = 0; s < steps; s = s + 1) {
        let t = (f32(s) + 0.5) / f32(steps) * tmax;
        if (t > marchEnd) { break; }
        if (tG > 0.0 && t > tG - 0.015) { break; }
        let p = ro + rd * t;
        // axis convention: the polar axis lies along +X (horizontal);
        // r = distance from it. Matches the interp panel labels r0/z0.
        let rr = rrOf(p);
        let ax = axOf(p);
        let rho2 = rr * rr + ax * ax;
        // no break here: samples outside the ball are zeroed by the boundary
        // win fade; the march is bounded by marchEnd (dome exit) anyway.
        // boundary-only fade: full glow inside, soft rolloff at the glass
        let win = clamp((ru.rDome * ru.rDome - rho2) / (ru.rDome * 0.3), 0.0, 1.0);
        let psiv = psiAt3(rr, ax, phiOf(p));
        let jv = jAt3(rr, ax, phiOf(p));
        let u = (psiv - ru.levelMin) * ru.levelInv;
        let jn = clamp(jv / max(ru.jmax, 1e-9), 0.0, 20.0);
        let jt = jn / (jn + 1.0);
        accStream += heatColor(jt * 1.15) * jt * jt * jt * win * (1.0 - t / tmax * 0.30) * 0.04;
    }
    // PASS 2: width-less AA field lines on 4 meridian planes, clipped at dome
    var u4 = array<f32, 4>(0.0, 0.0, 0.0, 0.0);
    var ok4 = array<bool, 4>(false, false, false, false);
    for (var k = 0u; k < 4u; k = k + 1u) {
        let phi = f32(k) * PI / 4.0;
        let nx = -sin(phi);
        let ny = cos(phi);
        let denom = nx * rd.x + ny * rd.y;
        var ti = 0.0;
        var ok = abs(denom) >= 1e-6;
        if (ok) {
            ti = -(nx * ro.x + ny * ro.y) / denom;
            if (ti <= 0.02 || ti > tmax) { ok = false; }
            if (tG > 0.0 && ti > tG - 0.008) { ok = false; }
        }
        let q = ro + rd * ti;
        let rr = rrOf(q);
        let ax = axOf(q);
        let rho = sqrt(rr * rr + ax * ax);
        if (rho > ru.rDome) { ok = false; }
        u4[k] = (psiAt3(rr, ax, f32(k) * PI / 4.0) - ru.levelMin) * ru.levelInv;
        ok4[k] = ok;
    }
    for (var k = 0u; k < 4u; k = k + 1u) {
        let u = u4[k];
        let dU = max(abs(dpdx(u)), abs(dpdy(u))) + 1e-5;
        let du = abs(fract(u + 0.5) - 0.5);
        let distPx = du / dU;
        let line = 1.0 - smoothstep(0.45, 1.4, distPx);
        if (ok4[k]) { accLine = max(accLine, line); }
    }
    // reference display chain: log-ish gather -> EV exposure -> ACES filmic
    // (Narkowicz 2015, the standard WebGPU tonemap) -> display gamma 2.2
    let streamer = 1.0 - exp(-accStream * exp2(ru.exposure));
    var composite = streamer + vec3<f32>(1.0, 0.80, 0.15) * accLine * 1.2;
    if (tG > 0.0) {
        let ph = ro + rd * tG;
        let nrm = normalize(ph);
        let rr = rrOf(ph);
        let jv = jAt3(rr, axOf(ph), phiOf(ph));
        let jn = clamp(jv / max(ru.jmax, 1e-9), 0.0, 1.0);
        let body = heatColor(jn * 1.15);
        let rim = 0.30 * pow(1.0 - abs(dot(nrm, -rd)), 3.0);
        let hb = 1.0 - exp(-(body * 1.2 + vec3<f32>(0.30, 0.40, 0.70) * rim));
        composite = composite * 0.1 + hb * 0.9;
    }
    // glass dome: the simulation boundary, explicitly visible — a real ball
    // toy's shell; scatters a little of the interior light
    if (tDome > 0.0) {
        // glass dome: pure ADDITIVE shell (never darkens the scene) — a faint
        // haze from all angles + fresnel rim; scatters a hint of the interior
        let pd = ro + rd * tDome;
        let nd = normalize(pd);
        let rim = pow(1.0 - abs(dot(nd, -rd)), 3.0) * 0.11;
        composite = composite
            + vec3<f32>(0.42, 0.58, 0.92) * rim
            + vec3<f32>(0.16, 0.22, 0.34) * 0.01;
    }
    // ACES filmic tone map + display gamma 2.2 (reference implementation)
    let cAces = vec3<f32>(
        clamp((composite.x * (2.51 * composite.x + 0.03)) /
              (composite.x * (2.43 * composite.x + 0.59) + 0.14), 0.0, 1.0),
        clamp((composite.y * (2.51 * composite.y + 0.03)) /
              (composite.y * (2.43 * composite.y + 0.59) + 0.14), 0.0, 1.0),
        clamp((composite.z * (2.51 * composite.z + 0.03)) /
              (composite.z * (2.43 * composite.z + 0.59) + 0.14), 0.0, 1.0));
    let out = vec3<f32>(pow(cAces.x, 1.0 / 2.2), pow(cAces.y, 1.0 / 2.2), pow(cAces.z, 1.0 / 2.2));
    let bg = vec3<f32>(0.012, 0.016, 0.028);
    return vec4<f32>(bg + out * 0.95, 1.0);
}
`;

// ------------------------------------------------------------------ //
// JS orchestration                                                     //
// ------------------------------------------------------------------ //
let device, ctx, cModule, rPipeline, layout, pipelineLayout;
let cBufs = {}, rbBufs = {}, computePipes = {};
let cuBuf, ruBuf, cBindGroup;
const BUILD = "2025-09-03d";   // visible build tag: hard-refresh must show this in the badge
let simTime = 0, running = true, driveAmp = 1.2, driveT = 0.5, stepsPerFrame = 4;
let winR0 = 0.0, winZ0 = 0.0, winSigma = 3.0;
let kLevels = 6, exposure = 0.0, rDome = 1.9, noiseAmp = 0.03;
let axisIdx = 1, mirror = false;
let yaw = 0.8, pitch = 0.35, dist = 3.2, autoRotate = false;   // turntable OFF by default
let last = performance.now();
let phiSol = "a";
let levelMin = 0, levelInv = 30, jExp = 16.0;
let announced = false;

function initField(psi, om) {
  for (let k = 0; k < NK; k++) {
    for (let j = 0; j < N; j++) {
      const Z = (j / N) * 2 * Math.PI - Math.PI;
      for (let i = 0; i < N; i++) {
        const R = (i / N) * 2 * Math.PI - Math.PI;
        const rho2 = R * R + Z * Z, a = 0.5, sig = 1.6;
        let v = (R * R) / Math.pow(rho2 + a * a, 1.5) * Math.exp(-rho2 / (2 * sig * sig));
        v += 0.35 * Math.exp(-rho2 / (2 * 0.81)) * Math.sin(2 * R);
        psi[(k * N + j) * N + i] = v;
        om[(k * N + j) * N + i] = 0;
      }
    }
  }
  // meridional initial flow (same in every phi plane), then blurred 3D noise
  const phi0 = (i, j) => {
    const R = (i / N) * 2 * Math.PI - Math.PI;
    const Z = (j / N) * 2 * Math.PI - Math.PI;
    return 0.4 * Math.sin(R) * Math.sin(Z);
  };
  for (let j = 0; j < N; j++)
    for (let i = 0; i < N; i++) {
      const ip = (i + 1) % N, im = (i + N - 1) % N;
      const jp = (j + 1) % N, jm = (j + N - 1) % N;
      const lap = (phi0(ip, j) + phi0(im, j) + phi0(i, jp) + phi0(i, jm) - 4 * phi0(i, j)) / DX2;
      for (let k = 0; k < NK; k++) om[(k * N + j) * N + i] = -lap;
    }
  // seed noise: low-frequency (3x3x3 box-blurred), so it perturbs the 3D
  // structure without polluting the current with grid-scale spikes
  if (noiseAmp > 0) {
    const raw = new Float32Array(TOT);
    for (let i = 0; i < TOT; i++) raw[i] = Math.random() * 2 - 1;
    const bl = new Float32Array(TOT);
    for (let k = 0; k < NK; k++)
      for (let j = 0; j < N; j++)
        for (let i = 0; i < N; i++) {
          let s2 = 0;
          for (let dk = -1; dk <= 1; dk++)
            for (let dy = -1; dy <= 1; dy++)
              for (let dx = -1; dx <= 1; dx++) {
                const x = (i + dx + N) % N, y = (j + dy + N) % N, z = (k + dk + NK) % NK;
                s2 += raw[(z * N + y) * N + x];
              }
          bl[(k * N + j) * N + i] = s2 / 27;
        }
    for (let i = 0; i < TOT; i++) psi[i] += noiseAmp * bl[i];
  }
  return phi0;
}

async function init() {
  if (!navigator.gpu) { fatal("navigator.gpu missing — " + browserHint()); return; }
  const adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
  if (!adapter) { fatal("requestAdapter() returned null. " + browserHint()); return; }
  device = await adapter.requestDevice();
  device.lost.then((info) => fatal("GPU device lost: " + info.reason));

  const fmt = navigator.gpu.getPreferredCanvasFormat();

  cModule = device.createShaderModule({ code: WGSL });
  const info = await cModule.getCompilationInfo();
  const errs = info.messages.filter((m) => m.type === "error");
  if (errs.length) { fatal("WGSL compile failed: " + errs.map((m) => m.message).join("; ")); return; }

  ctx = canvas.getContext("webgpu");
  ctx.configure({ device, format: fmt });

  const V = GPUShaderStage;
  layout = device.createBindGroupLayout({
    entries: [
      { binding: 0, visibility: V.COMPUTE, buffer: { type: "uniform", minBindingSize: 48 } },
      { binding: 1, visibility: V.FRAGMENT, buffer: { type: "uniform", minBindingSize: 128 } },
      { binding: 2, visibility: V.COMPUTE | V.FRAGMENT, buffer: { type: "storage", minBindingSize: 4 } },
      { binding: 3, visibility: V.COMPUTE | V.FRAGMENT, buffer: { type: "storage", minBindingSize: 4 } },
      { binding: 4, visibility: V.COMPUTE, buffer: { type: "storage", minBindingSize: 4 } },
      { binding: 5, visibility: V.COMPUTE, buffer: { type: "storage", minBindingSize: 4 } },
      { binding: 6, visibility: V.COMPUTE, buffer: { type: "storage", minBindingSize: 4 } },
      { binding: 7, visibility: V.COMPUTE, buffer: { type: "storage", minBindingSize: 4 } },
      { binding: 8, visibility: V.COMPUTE | V.FRAGMENT, buffer: { type: "storage", minBindingSize: 4 } },
      { binding: 9, visibility: V.COMPUTE, buffer: { type: "storage", minBindingSize: 4 } },
    ],
  });
  pipelineLayout = device.createPipelineLayout({ bindGroupLayouts: [layout] });

  const mk = (ep) => device.createComputePipeline({
    layout: pipelineLayout,
    compute: { module: cModule, entryPoint: ep },
  });
  for (const ep of ["init_drive", "lapj", "poisson_a2b", "poisson_b2a", "mid_rhs", "adv_rhs"])
    computePipes[ep] = mk(ep);

  rPipeline = device.createRenderPipeline({
    layout: pipelineLayout,
    vertex: { module: cModule, entryPoint: "vs" },
    fragment: { module: cModule, entryPoint: "fs", targets: [{ format: fmt }] },
    primitive: { topology: "triangle-list" },
  });

  const sz = TOT * 4;
  const mkS = (extra) => device.createBuffer({ size: sz, usage: GPUBufferUsage.STORAGE | extra });
  cBufs = {
    psi_a: mkS(GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST),
    psi_b: mkS(GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST),
    om_a: mkS(GPUBufferUsage.COPY_DST), om_b: mkS(GPUBufferUsage.COPY_DST),
    phi_a: mkS(GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST),
    phi_b: mkS(GPUBufferUsage.COPY_DST),
    jbuf: mkS(GPUBufferUsage.COPY_SRC),
    drivef: mkS(0),
  };
  cuBuf = device.createBuffer({ size: 48, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
  ruBuf = device.createBuffer({ size: 128, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });

  const seq = [cBufs.psi_a, cBufs.psi_b, cBufs.om_a, cBufs.om_b, cBufs.phi_a, cBufs.phi_b,
               cBufs.jbuf, cBufs.drivef];
  cBindGroup = device.createBindGroup({
    layout,
    entries: [
      { binding: 0, resource: { buffer: cuBuf } },
      { binding: 1, resource: { buffer: ruBuf } },
      ...seq.map((b, k) => ({ binding: k + 2, resource: { buffer: b } })),
    ],
  });
  rbBufs = {
    j: device.createBuffer({ size: sz, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST }),
    p: device.createBuffer({ size: sz, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST }),
    ph: device.createBuffer({ size: sz, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST }),
  };

  const psi = new Float32Array(TOT), om = new Float32Array(TOT);
  const phi0f = initField(psi, om);
  const phi0 = new Float32Array(TOT);
  for (let j = 0; j < N; j++)
    for (let i = 0; i < N; i++) phi0[i * N + j] = phi0f(i, j);
  device.queue.writeBuffer(cBufs.psi_a, 0, psi);
  device.queue.writeBuffer(cBufs.psi_b, 0, psi);
  device.queue.writeBuffer(cBufs.om_a, 0, om);
  device.queue.writeBuffer(cBufs.om_b, 0, om);
  device.queue.writeBuffer(cBufs.phi_a, 0, phi0);
  device.queue.writeBuffer(cBufs.phi_b, 0, phi0);
  phiSol = "a";
  dispatch1("init_drive");
  requestAnimationFrame(loop);
}

function dispatch1(ep) {
  const enc = device.createCommandEncoder();
  const pass = enc.beginComputePass();
  pass.setPipeline(computePipes[ep]);
  pass.setBindGroup(0, cBindGroup);
  pass.dispatchWorkgroups(N / 8, N / 8, NK / 8);
  pass.end();
  device.queue.submit([enc.finish()]);
}

function writeCu(which, t, phiSrc) {
  // CUniforms: dims vec3<u32> (0-11, pad to 16), dt/t/driveAmp/driveT (16-31),
  // which/njac/phiSrc as u32 (32-43); total 48
  const d = new ArrayBuffer(48);
  const u = new Uint32Array(d), f = new Float32Array(d);
  u[0] = N; u[1] = N; u[2] = NK;
  f[4] = 2e-3; f[5] = t; f[6] = driveAmp; f[7] = driveT;
  u[8] = which; u[9] = 40; u[10] = (phiSrc === "a") ? 0 : 1;
  device.queue.writeBuffer(cuBuf, 0, d);
}

function poissonSolve(omWhich, t) {
  writeCu(omWhich, t, phiSol);
  for (let k = 0; k < 60; k++) {
    dispatch1(phiSol === "a" ? "poisson_a2b" : "poisson_b2a");
    phiSol = phiSol === "a" ? "b" : "a";
  }
}

function step() {
  // stage 1: k1 at (ψ_a, ω_a) computed inline by mid_rhs
  writeCu(0, simTime, phiSol);
  dispatch1("lapj");            // jbuf = j(ψ_a)
  poissonSolve(0, simTime);     // φ(ω_a); phiSol updated
  writeCu(0, simTime, phiSol);  // phiSrc = φ solution buffer
  dispatch1("mid_rhs");         // ψ_b, ω_b = midpoint
  // stage 2: k2 at midpoint computed inline by adv_rhs
  writeCu(1, simTime + 1e-3, phiSol);
  dispatch1("lapj");            // jbuf = j(ψ_b)
  poissonSolve(1, simTime + 1e-3);
  writeCu(1, simTime + 1e-3, phiSol);
  dispatch1("adv_rhs");         // ψ_a, ω_a += dt·k2
  simTime += 2e-3;
}

function updateCamera() {
  const target = [0, 0, 0];
  const cp = Math.cos(pitch), sp = Math.sin(pitch);
  const sy = Math.sin(yaw), cy = Math.cos(yaw);
  const eye = [dist * cp * sy, dist * sp, dist * cp * cy];
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
  const norm = (a) => { const l = Math.hypot(a[0],a[1],a[2])||1; return [a[0]/l,a[1]/l,a[2]/l]; };
  const fwd = norm(sub(target, eye));
  const right = norm(cross(fwd, [0,1,0]));
  const up = cross(right, fwd);
  return { eye, fwd, right, up };
}

async function meters() {
  const enc = device.createCommandEncoder();
  enc.copyBufferToBuffer(cBufs.jbuf, 0, rbBufs.j, 0, TOT * 4);
  enc.copyBufferToBuffer(cBufs.psi_a, 0, rbBufs.p, 0, TOT * 4);
  const phiBuf = phiSol === "a" ? cBufs.phi_a : cBufs.phi_b;
  enc.copyBufferToBuffer(phiBuf, 0, rbBufs.ph, 0, TOT * 4);
  device.queue.submit([enc.finish()]);
  await Promise.all([rbBufs.j.mapAsync(GPUMapMode.READ), rbBufs.p.mapAsync(GPUMapMode.READ),
                     rbBufs.ph.mapAsync(GPUMapMode.READ)]);
  const j = new Float32Array(rbBufs.j.getMappedRange().slice(0));
  const p = new Float32Array(rbBufs.p.getMappedRange().slice(0));
  const ph = new Float32Array(rbBufs.ph.getMappedRange().slice(0));
  rbBufs.j.unmap(); rbBufs.p.unmap(); rbBufs.ph.unmap();
  let maxJ = 0, em = 0, ek = 0, pMin = Infinity, pMax = -Infinity;
  const absJ = new Float32Array(TOT);
  for (let i = 0; i < TOT; i++) {
    const a = Math.abs(j[i]); if (a > maxJ) maxJ = a;
    absJ[i] = a;
    if (p[i] < pMin) pMin = p[i];
    if (p[i] > pMax) pMax = p[i];
  }
  for (let k = 0; k < NK; k++)
    for (let j2 = 0; j2 < N; j2++)
      for (let i = 0; i < N; i++) {
        const ip = (i+1)%N, im = (i+N-1)%N, jp = (j2+1)%N, jm = (j2+N-1)%N;
        const kp = (k+1)%NK, km = (k+NK-1)%NK;
        const bx = (p[(k*N+j2)*N+ip]-p[(k*N+j2)*N+im])/(2*DX);
        const by = (p[(k*N+jp)*N+i]-p[(k*N+jm)*N+i])/(2*DX);
        const bz = (p[(kp*N+j2)*N+i]-p[(km*N+j2)*N+i])/(2*DXP);
        const ux = (ph[(k*N+j2)*N+ip]-ph[(k*N+j2)*N+im])/(2*DX);
        const uy = (ph[(k*N+jp)*N+i]-ph[(k*N+jm)*N+i])/(2*DX);
        const uz = (ph[(kp*N+j2)*N+i]-ph[(km*N+j2)*N+i])/(2*DXP);
        em += 0.5*(bx*bx+by*by+bz*bz)/TOT;
        ek += 0.5*(ux*ux+uy*uy+uz*uz)/TOT;
      }
  levelMin = pMin; levelInv = kLevels / Math.max(pMax - pMin, 1e-6);
  // instrument: where is the current peak (r,z)? plus flux range (X-point stats)
  let pi = 0, pj = 0;
  for (let i = 0; i < TOT; i++) if (Math.abs(j[i]) > Math.abs(j[pi])) pi = i;
  const pjz = Math.floor(pi / N), pix = pi % N;
  const jr = (pix / N) * 2 * Math.PI - Math.PI;
  const jz = (pjz / N) * 2 * Math.PI - Math.PI;
  document.getElementById("mTime").innerText = simTime.toFixed(3);
  document.getElementById("mJ").innerText = maxJ.toExponential(2);
  document.getElementById("mDiag").innerText =
    "j-peak (r,z): (" + jr.toFixed(2) + ", " + jz.toFixed(2) + ")  \u03a6=" + (pMax - pMin).toFixed(3);
  document.getElementById("mEm").innerText = em.toFixed(4);
  document.getElementById("mEk").innerText = ek.toFixed(4);
  meters.absJ = absJ;
  return maxJ;
}

async function loop(now) {
  const dtMs = Math.min(0.05, (now - last) / 1000);
  last = now;
  if (autoRotate) yaw += dtMs * 0.25;
  let maxJ = 0;
  try {
    if (running) for (let s = 0; s < stepsPerFrame; s++) step();
    writeCu(0, simTime, phiSol);
    dispatch1("lapj");
    maxJ = await meters();
    // eye-like exposure: EMA of the 95th-percentile |j| (robust scale;
    // the peak is often an occluded single cell, not what the eye sees)
    const jj = Array.from(meters.absJ || [], Math.abs).sort((a, b) => a - b);
    const j95 = jj.length ? jj[Math.floor(jj.length * 0.95)] : maxJ;
    jExp = jExp * 0.93 + j95 * 0.07;
    if (!announced) {
      announced = true;
      console.log("[LaserCortex] RUNNING t=" + simTime.toFixed(3)
        + " maxJ=" + maxJ.toExponential(2)
        + " render{exposure=" + exposure + " jExp=" + jExp.toFixed(2)
        + " wSigma=" + winSigma + " rDome=" + rDome + "}");
    }
  } catch (e) { fatal("step failed: " + e); return; }

  const cam = updateCamera();
  const ru = new ArrayBuffer(128);
  const f = new Float32Array(ru);
  f[0]=cam.eye[0]; f[1]=cam.eye[1]; f[2]=cam.eye[2]; f[3]=1;
  f[4]=cam.fwd[0]; f[5]=cam.fwd[1]; f[6]=cam.fwd[2]; f[7]=1;
  f[8]=cam.right[0]; f[9]=cam.right[1]; f[10]=cam.right[2]; f[11]=1;
  f[12]=cam.up[0]; f[13]=cam.up[1]; f[14]=cam.up[2]; f[15]=1;
  f[16]=Math.tan(0.45); f[17]=canvas.width/canvas.height;
  f[18]=0.30; f[19]=jExp;
  f[20]=levelMin; f[21]=levelInv; f[22]=0;
  f[23]=winR0; f[24]=winZ0; f[25]=winSigma;
  f[26]=exposure; f[27]=2.2; f[28]=0; f[29]=rDome; f[30]=axisIdx; f[31]=mirror?1:0;
  device.queue.writeBuffer(ruBuf, 0, ru);

  const enc = device.createCommandEncoder();
  const pass = enc.beginRenderPass({
    colorAttachments: [{ view: ctx.getCurrentTexture().createView(),
      clearValue: { r: 0.012, g: 0.016, b: 0.028, a: 1 }, loadOp: "clear", storeOp: "store" }],
  });
  pass.setPipeline(rPipeline);
  pass.setBindGroup(0, cBindGroup);
  pass.draw(3);
  pass.end();
  device.queue.submit([enc.finish()]);
  requestAnimationFrame(loop);
}

let dragging = false, px = 0, py = 0;
canvas.addEventListener("pointerdown", (e) => { dragging = true; px=e.clientX; py=e.clientY; canvas.setPointerCapture(e.pointerId); });
canvas.addEventListener("pointermove", (e) => { if(!dragging) return; yaw += (e.clientX-px)*0.008; pitch = Math.max(-1.4, Math.min(1.4, pitch + (e.clientY-py)*0.008)); px=e.clientX; py=e.clientY; });
canvas.addEventListener("pointerup", () => { dragging = false; });
canvas.addEventListener("pointercancel", () => { dragging = false; });
canvas.addEventListener("wheel", (e) => { e.preventDefault(); dist = Math.max(2.0, Math.min(6.5, dist + e.deltaY*0.002)); }, { passive: false });
document.getElementById("playBtn").onclick = (e) => { running = !running; e.target.innerText = running ? "Pause" : "Resume"; };
document.getElementById("stepBtn").onclick = () => { step(); };
document.getElementById("resetBtn").onclick = () => {
  const psi = new Float32Array(TOT), om = new Float32Array(TOT);
  const phi0f = initField(psi, om);
  const phi0 = new Float32Array(TOT);
  for (let j = 0; j < N; j++)
    for (let i = 0; i < N; i++) phi0[i * N + j] = phi0f(i, j);
  device.queue.writeBuffer(cBufs.psi_a, 0, psi);
  device.queue.writeBuffer(cBufs.psi_b, 0, psi);
  device.queue.writeBuffer(cBufs.om_a, 0, om);
  device.queue.writeBuffer(cBufs.om_b, 0, om);
  device.queue.writeBuffer(cBufs.phi_a, 0, phi0);
  device.queue.writeBuffer(cBufs.phi_b, 0, phi0);
  phiSol = "a"; simTime = 0;
};
document.getElementById("speedSel").onchange = (e) => { stepsPerFrame = parseInt(e.target.value, 10); };
document.getElementById("driveSlider").oninput = (e) => { driveAmp = parseFloat(e.target.value); };
document.getElementById("driveTsel").onchange = (e) => { driveT = parseFloat(e.target.value); };
document.getElementById("wr0S").oninput = (e) => { winR0 = parseFloat(e.target.value); };
document.getElementById("wz0S").oninput = (e) => { winZ0 = parseFloat(e.target.value); };
document.getElementById("wsigmaS").oninput = (e) => { winSigma = parseFloat(e.target.value); };
document.getElementById("levelsS").oninput = (e) => { kLevels = parseInt(e.target.value, 10); };
document.getElementById("domeS").oninput = (e) => { rDome = parseFloat(e.target.value); };
document.getElementById("noiseS").oninput = (e) => { noiseAmp = parseFloat(e.target.value); };
document.getElementById("spinCb").onchange = (e) => { autoRotate = e.target.checked; };
document.getElementById("expS").oninput = (e) => { exposure = parseFloat(e.target.value); };
document.getElementById("axisSel").onchange = (e) => { axisIdx = parseInt(e.target.value, 10); };
document.getElementById("mirrorCb").onchange = (e) => { mirror = e.target.checked; };

init().catch((e) => fatal("init failed: " + e));
