import numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
# ---------- solver state: t=0 field (same as page init) ----------
N=128; DXN=2*np.pi/N
x=np.linspace(0,2*np.pi,N,endpoint=False); X,Y=np.meshgrid(x,x,indexing="ij")
R=X-np.pi; Z=Y-np.pi; rho2=R*R+Z*Z
psi=1.0*(R*R)/(rho2+0.25)**1.5*np.exp(-rho2/(2*1.6**2))
psi+=0.35*np.exp(-rho2/(2*0.81))*np.sin(2.0*R)
def L5(f): return (np.roll(f,-1,0)+np.roll(f,1,0)+np.roll(f,-1,1)+np.roll(f,1,1)-4*f)/(DXN*DXN)
j=-L5(psi)
pmin,pmax=psi.min(),psi.max(); levelMin=pmin; levelInv=6/(pmax-pmin)
# ---------- camera (matches updateCamera; axisIdx=1 => axial = world Y) ----------
yaw, pitch, dist = 0.8, 0.35, 3.2
cp,sp,sy,cy = np.cos(pitch),np.sin(pitch),np.sin(yaw),np.cos(yaw)
eye=np.array([dist*cp*sy, dist*sp, dist*cp*cy],dtype=float)
fwd=-eye/np.linalg.norm(eye)
right=np.cross(fwd,[0,1,0]); right/=np.linalg.norm(right)
up=np.cross(right,fwd)
M=560
u,v = np.meshgrid(np.linspace(-1,1,M),np.linspace(-1,1,M),indexing="ij")
tan=0.45; aspect=1.0
rd = fwd[None,None,:] + right[None,None,:]*(u[...,None]*tan*aspect) + up[None,None,:]*(v[...,None]*tan)
rd/=np.linalg.norm(rd,axis=-1,keepdims=True)
ro=eye
SZ=(M,M,3)
def sphere(rad):
    b=np.sum(ro*rd,axis=-1); c=np.sum(ro*ro)-rad*rad
    disc=b*b-c
    tG=np.full(SZ[:2],-1.0)
    sq=np.sqrt(np.maximum(disc,0))
    t0=-b-sq; t1=-b+sq
    tG=np.where((disc>0)&(t0>0),t0,np.where((disc>0)&(t1>0),t1,-1.0))
    return tG
def sphere2(rad):
    b=np.sum(ro*rd,axis=-1); c=np.sum(ro*ro)-rad*rad
    disc=b*b-c; sq=np.sqrt(np.maximum(disc,0))
    t0=-b-sq; t1=-b+sq
    en=np.where((disc>0)&(t0>0),t0,np.where((disc>0)&(t1>0),t1,-1.0))
    ex=np.where((disc>0)&(t1>0),t1,-1.0)
    return en,ex
tG=sphere(0.30); tDome,tDome1=sphere2(1.9)
tmax=np.linalg.norm(ro)+2.6
marchEnd=np.where(tDome1>0,np.minimum(tmax,tDome1-0.012),0.0)
def bil(f, rr, ax):
    fx=np.clip((rr+np.pi)/(2*np.pi),0,1)*(N-1)
    fy=np.clip((ax+np.pi)/(2*np.pi),0,1)*(N-1)
    x0=np.floor(fx).astype(int); y0=np.floor(fy).astype(int)
    x1=np.minimum(x0+1,N-1); y1=np.minimum(y0+1,N-1)
    tx=fx-x0; ty=fy-y0
    q=f.copy()
    a0=q[x0,y0]; a1=q[x1,y0]; a2=q[x0,y1]; a3=q[x1,y1]
    return (a0*(1-tx)+a1*tx)*(1-ty)+(a2*(1-tx)+a3*tx)*ty
def heatColor(t):
    t=np.clip(t,0,1)
    c0=np.array([0.12,0.06,0.28]); c1=np.array([0.62,0.10,0.55]); c2=np.array([1.0,0.78,0.25])
    lo=t<0.55
    c1l=c0+(c1-c0)*(t/0.55)[...,None]
    c2l=c1+(c2-c1)*((t-0.55)/0.45)[...,None]
    c=np.where(lo[...,None],c1l,c2l)
    return c
accStream=np.zeros(SZ); A=np.zeros(SZ[:2])
print("DEBUG tG:", float(tG.max()), float(tG[tG>0].mean()) if (tG>0).any() else 0.0, "hits:", int((tG>0).sum()))
print("DEBUG tDome:", float(tDome.max()), "hits:", int((tDome>0).sum()), "marchEnd.max:", float(marchEnd.max()))
jmax=float(np.percentile(np.abs(j),95))
wSigma=3.0; rDome=1.9; exposure=0.0; lift=0.03
steps=96
for s in range(steps):
    t=(s+0.5)/steps*tmax
    active=(t<=marchEnd)&np.isfinite(marchEnd)
    active &= ~((tG>0)&(t>tG-0.015))
    p=ro[None,None,:]+rd*t
    # axisIdx=1: rr=sqrt(x^2+z^2), ax=y
    rr=np.sqrt(p[...,0]**2+p[...,2]**2); ax=p[...,1]
    rho2=rr*rr+ax*ax
    # outside samples are zeroed by the boundary win fade
    if not active.any(): break
    win=np.clip((rDome*rDome-rho2)/(rDome*0.3),0,1)
    winEnv=np.exp(-((rr-0.0)**2+(ax-0.0)**2)/(2*wSigma*wSigma))
    psiv=bil(psi,rr,ax); jv=np.abs(bil(j,rr,ax))
    jn=np.clip(jv/np.maximum(jmax,1e-9),0,20); jt=jn/(jn+1.0)
    if s in (0, 20, 40, 60, 80, 95):
        print(f"step {s}: active={int(active.sum())} jt.max={float(jt.max()):.3f} "
              f"win.max={float(win.max()):.2f} winEnv.max={float(winEnv.max()):.2f} "
              f"jv.max={float(jv.max()):.3f} jmax={jmax:.3f} t={t:.2f} marchEnd.max={float(marchEnd.max()):.2f}")
    g=heatColor(jt*1.15)*(jt**3)[...,None]*win[...,None]*winEnv[...,None]
    a=g*(1.0-t/tmax*0.30)*0.04
    accStream+=np.where(active[...,None],a,0.0)
streamer=1.0-np.exp(-accStream*np.exp2(exposure))
lifted=streamer+lift*(1.0-streamer)*0.6
comp=lifted.copy()
# globe hit
hit=tG>0
if hit.any():
    ph=ro[None,None,:]+rd*tG[...,None]
    nr=np.sqrt(ph[...,0]**2+ph[...,2]**2); nax=ph[...,1]
    jv=np.abs(bil(j,nr,nax)); jn=np.clip(jv/np.maximum(jmax,1e-9),0,1.0)
    body=heatColor(jn*1.15)
    nd=ph/np.linalg.norm(ph,axis=-1,keepdims=True)
    rim=0.30*np.maximum(1.0-np.abs(np.sum(nd*(-rd),axis=-1)),0)**3
    hb=1.0-np.exp(-(body*1.2+np.array([0.30,0.40,0.70])*rim[...,None]))
    comp=np.where(hit[...,None],comp*0.1+hb*0.9,comp)
# dome additive
hitD=tDome>0
if hitD.any():
    pd=ro[None,None,:]+rd*tDome[...,None]
    nd=pd/np.linalg.norm(pd,axis=-1,keepdims=True)
    rimD=0.11*np.maximum(1.0-np.abs(np.sum(nd*(-rd),axis=-1)),0)**3
    glass=np.array([0.42,0.58,0.92])*rimD[...,None]+np.array([0.16,0.22,0.34])*0.01
    comp=comp+np.where(hitD[...,None],glass,0.0)
# ACES + gamma 2.2 + bg
def aces(x): return np.clip(x*(2.51*x+0.03)/(x*(2.43*x+0.59)+0.14),0,1)
comp=aces(comp)**(1/2.2)
bg=np.array([0.012,0.016,0.028])
out=bg+comp*0.95
img=np.clip(out,0,1)
plt.imsave("fs_mirrorB.png", np.flipud(img), vmin=0, vmax=1)
import matplotlib.pyplot as _p
_p.figure(figsize=(5,5))
_p.imshow(np.flipud(np.clip(accStream,0,1)), cmap="magma")
_p.axis("off"); _p.savefig("acc_dbg.png", dpi=90, facecolor="black")
print("accStream: nonzero px =", int((accStream>0.1).sum()), "of", int(accStream.shape[0]*accStream.shape[1]),
      "| max =", float(accStream.max()))
print("rendered; mean bright:", float(img.mean()), "max:", float(img.max()))
