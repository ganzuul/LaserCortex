import numpy as np, math
N, NK = 128, 64
TOT = N*N*NK
DX2 = (2*np.pi/N)**2; DXP2 = (2*np.pi/NK)**2
# 3D arrays (k,j,i)
IX = lambda i,j,k: (k*N+j)*N+i
def rollx(f, s): return np.roll(f, s, axis=2)
def rolly(f, s): return np.roll(f, s, axis=1)
def rollz(f, s): return np.roll(f, s, axis=0)
def dx(f): return (rollx(f,-1)-rollx(f,1))/(2*(2*np.pi/N))
def dy(f): return (rolly(f,-1)-rolly(f,1))/(2*(2*np.pi/N))
def dz(f): return (rollz(f,-1)-rollz(f,1))/(2*(2*np.pi/NK))
def lap(f): return (rollx(f,-1)+rollx(f,1)+rolly(f,-1)+rolly(f,1)+rollz(f,-1)+rollz(f,1)-6*f)/DX2
def br3(ax_,ay,az,bx,by,bz): return (ax_*by-ay*bx) + (ay*bz-az*by) + (az*bx-ax_*bz)
# init (same as the page: dipole + perturb + 3D-blurred noise; omega from phi0)
i_ = np.arange(N)[:,None,None]; j_ = np.arange(N)[None,:,None]; k_ = np.arange(NK)[None,None,:]
R = i_/N*2*np.pi-np.pi; Z = j_/N*2*np.pi-np.pi; PH = k_/NK*2*np.pi-np.pi
rho2 = R*R+Z*Z
psi = (1.0*(R*R)/(rho2+0.25)**1.5*np.exp(-rho2/(2*1.6**2)))*np.ones_like(PH)
psi += (0.35*np.exp(-rho2/(2*0.81))*np.sin(2*R))*np.ones_like(PH)
phi0 = 0.4*np.sin(R)*np.sin(Z)*np.ones_like(PH)
om = -lap(phi0)
rng = np.random.default_rng(7)
raw = rng.uniform(-1,1,(N,N,NK)); bl = np.zeros_like(raw)
for dk in (-1,0,1):
    for dy_ in (-1,0,1):
        for dx_ in (-1,0,1):
            bl += np.roll(np.roll(np.roll(raw, dx_, 0), dy_, 1), dk, 2)
bl /= 27
psi += 0.03*bl
phi = phi0.copy(); phi2 = phi0.copy()
drivef = (R*R)/(rho2+0.25)**1.5*np.exp(-rho2/5.12)*(1.0+0.3*np.sin(PH))
eta, nu, amp, T = 2e-3, 1e-3, 1.2, 1.0
def pois(omsrc, phi_src, phi_dst):
    for _ in range(40):
        taps = rollx(phi_src,-1)+rollx(phi_src,1)+rolly(phi_src,-1)+rolly(phi_src,1)+rollz(phi_src,-1)+rollz(phi_src,1)
        phi_dst = (taps + omsrc*DX2)/6.0
        phi_src, phi_dst = phi_dst, phi_src
    return phi_src
dt = 2e-3; t = 0.0
for step_ in range(60):
    j = -lap(psi)
    phi = pois(om, phi, phi2)
    pdx,pdy,pdz = dx(phi),dy(phi),dz(phi)
    sdx,sdy,sdz = dx(psi),dy(psi),dz(psi)
    wdx,wdy,wdz = dx(om),dy(om),dz(om)
    jdx,jdy,jdz = dx(j),dy(j),dz(j)
    bpp = br3(pdx,pdy,pdz, sdx,sdy,sdz)
    bpo = br3(pdx,pdy,pdz, wdx,wdy,wdz)
    bpj = br3(sdx,sdy,sdz, jdx,jdy,jdz)
    dpsi = -bpp + eta*lap(psi) + amp*math.sin(2*math.pi*t/T)*drivef
    dom  = -bpo + bpj + nu*lap(om)
    pm = psi + 0.5*dt*dpsi; omm = om + 0.5*dt*dom
    jm = -lap(pm)
    phim = pois(omm, phi, phi2)
    pdx,pdy,pdz = dx(phim),dy(phim),dz(phim)
    sdx,sdy,sdz = dx(pm),dy(pm),dz(pm)
    wdx,wdy,wdz = dx(omm),dy(omm),dz(omm)
    jdx,jdy,jdz = dx(jm),dy(jm),dz(jm)
    bpp = br3(pdx,pdy,pdz, sdx,sdy,sdz)
    bpo = br3(pdx,pdy,pdz, wdx,wdy,wdz)
    bpj = br3(sdx,sdy,sdz, jdx,jdy,jdz)
    dpsi = -bpp + eta*lap(pm) + amp*math.sin(2*math.pi*(t+0.5*dt)/T)*drivef
    dom  = -bpo + bpj + nu*lap(omm)
    psi = psi + dt*dpsi; om = om + dt*dom
    phi2 = phi
    phi = phim
    t += dt
    if step_ % 15 == 14:
        j = -lap(psi)
        em = 0.5*np.mean(dx(psi)**2+dy(psi)**2+dz(psi)**2)
        print(f"t={t:5.2f} max|j|={np.max(np.abs(j)):7.2f} Em={em:.4f}", flush=True)
        if not np.isfinite(psi).all():
            print("UNSTABLE", flush=True); break
print("DONE", flush=True)
