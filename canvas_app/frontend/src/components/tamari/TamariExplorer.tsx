/**
 * TamariExplorer — Interactive 3D visualization of the Tamari lattice.
 *
 * Uses WebGPU compute shaders (TSL) for physics simulation:
 *   - Verlet integration kernel: vertex inertia and dynamics
 *   - Pentagonator constraint kernel: edge length constraints
 *
 * Falls back to WebGL if WebGPU is unavailable.
 *
 * Architecture (from Three-js_pentagonator-demo.md):
 *   Storage Buffers: positions, velocities, colors, edge topology
 *   Compute Kernels: Fn() + instanceIndex for parallel GPU execution
 *   Rendering: InstancedMesh + GPU readback for compute-driven updates
 */
import { useEffect, useRef, useState, useCallback } from 'react';
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { tamariApi, TamariLattice, TamariVertex, TamariPath, CostLandscape, CouplingDecayResult } from '../../services/tamariApi';
import { createBenchKernel } from '../../shaders/bench';
import { flattenAllTrees, computePhiCPU, getLogicParams, createPhiKernel } from '../../shaders/phi_cost';

// ── Color scheme ──────────────────────────────────────────────────────

const COLORS = {
  background: 0x0a0a1a,
  vertex_normal: 0x4488ff,
  vertex_rightcomb: 0x44ff88,
  vertex_leftcomb: 0xff4444,
  vertex_selected: 0xffaa00,
  vertex_path: 0xff44ff,
  edge_normal: 0x334466,
  edge_path: 0xff44ff,
  edge_antinertia: 0xff66aa,
};

const SCALE = 0.3;
const PARTICLE_COUNT = 100;

// ── 14 logic types (mirrors LogicTypes.lean) ──────────────────────────

const LOGIC_TYPES = [
  'classical', 'fuzzy', 'many_valued', 'paraconsistent',
  'temporal', 'deontic', 'epistemic', 'quantum',
  'intuitionistic', 'relevance', 'free', 'infinitary',
  'modal', 'spacetime',
];

const LOGIC_LABELS: Record<string, string> = {
  classical: 'Classical', fuzzy: 'Fuzzy', many_valued: 'Many-Valued',
  paraconsistent: 'Paraconsistent', temporal: 'Temporal', deontic: 'Deontic',
  epistemic: 'Epistemic', quantum: 'Quantum', intuitionistic: 'Intuitionistic',
  relevance: 'Relevance', free: 'Free', infinitary: 'Infinitary',
  modal: 'Modal', spacetime: 'Spacetime',
};

// ── Cost color mapping ────────────────────────────────────────────────

function costColor(cost: number, maxCost: number, isRC: boolean, isLC: boolean): number {
  if (isRC) return COLORS.vertex_rightcomb;
  if (isLC) return COLORS.vertex_leftcomb;
  if (maxCost === 0) return COLORS.vertex_normal;
  const t = Math.min(cost / maxCost, 1);
  // Blue (cold) → Yellow (hot) gradient
  const r = Math.round(0x44 + (0xff - 0x44) * t);
  const g = Math.round(0x88 * (1 - t * 0.7));
  const b = Math.round(0xff * (1 - t));
  return (r << 16) | (g << 8) | b;
}

// ── Helpers ───────────────────────────────────────────────────────────

function treeShortLabel(repr: string): string {
  return repr.replace(/Node/g, 'N').replace(/Leaf/g, 'L').replace(/\s/g, '');
}

function checkWebGPUSupport(): boolean {
  return !!(navigator as any).gpu;
}

// StorageInstancedBufferAttribute exists in three/webgpu at runtime but may
// not be in the type declarations. Create one safely.
function makeStorageAttribute(array: Float32Array, itemSize: number): any {
  const ctor = (THREE as any).StorageInstancedBufferAttribute;
  if (ctor) return new ctor(array, itemSize);
  const attr = new THREE.InstancedBufferAttribute(array, itemSize);
  (attr as any).isStorageInstancedBufferAttribute = true;
  return attr;
}

// ── Scene builder ─────────────────────────────────────────────────────

function buildLatticeMesh(
  lattice: TamariLattice,
  landscape: CostLandscape | null,
  logic: string,
  showCostFlag: boolean,
): { mesh: THREE.InstancedMesh; positions: Float32Array } {
  const sphereGeom = new THREE.SphereGeometry(0.15, 16, 16);
  const mesh = new THREE.InstancedMesh(
    sphereGeom, new THREE.MeshPhongMaterial(), lattice.vertices.length
  );
  const dummy = new THREE.Object3D();
  const color = new THREE.Color();
  const positions = new Float32Array(lattice.vertices.length * 3);

  let maxCost = 0;
  if (showCostFlag && landscape) {
    maxCost = Math.max(1, ...landscape.vertices.map(v => v.costs?.[logic] ?? 0));
  }

  lattice.vertices.forEach((v, i) => {
    const x = v.coord.x * SCALE, y = v.coord.y * SCALE;
    const cost = landscape?.vertices[i]?.costs?.[logic] ?? 0;
    const z = showCostFlag ? cost * SCALE : 0;
    positions[i * 3] = x; positions[i * 3 + 1] = y; positions[i * 3 + 2] = z;
    dummy.position.set(x, y, z);
    dummy.updateMatrix();
    mesh.setMatrixAt(i, dummy.matrix);
    if (showCostFlag && landscape) {
      color.setHex(costColor(cost, maxCost, v.is_right_comb, v.is_left_comb));
    } else {
      if (v.is_right_comb) color.setHex(COLORS.vertex_rightcomb);
      else if (v.is_left_comb) color.setHex(COLORS.vertex_leftcomb);
      else color.setHex(COLORS.vertex_normal);
    }
    mesh.setColorAt(i, color);
  });
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  mesh.userData = { positions, landscape };
  return { mesh, positions };
}

function buildEdgeLines(
  lattice: TamariLattice,
  positions: Float32Array,
  landscape: CostLandscape | null,
  logic: string,
  showAntiInertiaFlag: boolean,
): THREE.LineSegments {
  const edgePositions: number[] = [];
  const edgeColors: number[] = [];

  let maxCross = 0;
  if (showAntiInertiaFlag && landscape) {
    const crosses = lattice.edges
      .map(e => Math.abs(
        (landscape.vertices[e.source]?.costs?.[logic] ?? 0) -
        (landscape.vertices[e.target]?.costs?.[logic] ?? 0)
      ));
    maxCross = Math.max(1, ...crosses);
  }

  lattice.edges.forEach(e => {
    const i = e.source * 3, j = e.target * 3;
    edgePositions.push(
      positions[i], positions[i + 1], positions[i + 2],
      positions[j], positions[j + 1], positions[j + 2],
    );
    if (showAntiInertiaFlag && landscape) {
      const ci = Math.abs(
        (landscape.vertices[e.source]?.costs?.[logic] ?? 0) -
        (landscape.vertices[e.target]?.costs?.[logic] ?? 0)
      );
      const t = Math.min(ci / maxCross, 1);
      // Anti-inertia: blue → magenta based on cross-impact
      const r = Math.round(0x33 + (0xff - 0x33) * t);
      const g = Math.round(0x44 * (1 - t * 0.6));
      const b = Math.round(0x66 + (0xaa - 0x66) * t);
      edgeColors.push(r / 255, g / 255, b / 255, r / 255, g / 255, b / 255);
    } else {
      edgeColors.push(0.2, 0.27, 0.4, 0.2, 0.27, 0.4);
    }
  });

  const edgeGeom = new THREE.BufferGeometry();
  edgeGeom.setAttribute('position', new THREE.Float32BufferAttribute(edgePositions, 3));
  edgeGeom.setAttribute('color', new THREE.Float32BufferAttribute(edgeColors, 3));
  const edgeMat = new THREE.LineBasicMaterial({
    vertexColors: true,
    transparent: true,
    opacity: 0.6,
  });
  return new THREE.LineSegments(edgeGeom, edgeMat);
}

function addSceneLights(scene: THREE.Scene): void {
  scene.add(new THREE.AmbientLight(0x404040, 2));
  const pl = new THREE.PointLight(0xffffff, 1, 100);
  pl.position.set(10, 10, 10);
  scene.add(pl);
  const grid = new THREE.GridHelper(20, 20, 0x112233, 0x112233);
  grid.position.y = -5;
  scene.add(grid);
}

// ── Main component ────────────────────────────────────────────────────

interface TamariExplorerProps {
  initialN?: number;
}

type RendererStatus = 'init' | 'ready';

export function TamariExplorer({ initialN = 3 }: TamariExplorerProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const rendererRef = useRef<any>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const controlsRef = useRef<OrbitControls | null>(null);
  const animFrameRef = useRef<number>(0);
  const [rendererStatus, setRendererStatus] = useState<RendererStatus>('init');

  // GPU compute refs
  const [webgpuAvailable, setWebgpuAvailable] = useState(false);
  const computeReadyRef = useRef(false);
  const storagePosRef = useRef<any>(null);
  const computeVerletRef = useRef<any>(null);
  const computeConstraintRef = useRef<any>(null);
  const staticPositionsRef = useRef<Float32Array | null>(null);
  const instancedMeshRef = useRef<THREE.InstancedMesh | null>(null);
  const edgeLinesRef = useRef<THREE.LineSegments | null>(null);

  // Calibration
  const calCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const calAnimRef = useRef<number>(0);

  // Contraction animation
  const contractionLambdaRef = useRef(1.0);

  const [n, setN] = useState(initialN);
  const [lattice, setLattice] = useState<TamariLattice | null>(null);
  const [costLandscape, setCostLandscape] = useState<CostLandscape | null>(null);
  const [selectedLogic, setSelectedLogic] = useState('classical');
  const [selectedVertex, setSelectedVertex] = useState<TamariVertex | null>(null);
  const [contractionPath, setContractionPath] = useState<TamariPath | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [animatePath, setAnimatePath] = useState(false);
  const [animProgress, setAnimProgress] = useState(0);
  const [showCost, setShowCost] = useState(true);
  const [showAntiInertia, setShowAntiInertia] = useState(true);
  const [calMode, setCalMode] = useState<'off' | 'decay' | 'bench' | 'phi'>('off');
  const [calResult, setCalResult] = useState<string | null>(null);
  const [calError, setCalError] = useState<string | null>(null);

  // ── Fetch lattice data ──────────────────────────────────────────────

  const fetchLattice = useCallback(async (size: number) => {
    setLoading(true);
    setError(null);
    try {
      const [data, landscape] = await Promise.all([
        tamariApi.getLattice(size),
        tamariApi.getCostLandscape(size),
      ]);
      setLattice(data);
      setCostLandscape(landscape);
      setSelectedVertex(null);
      setContractionPath(null);
      setAnimProgress(0);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to fetch lattice');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchLattice(n); }, [n, fetchLattice]);

  // ── Initialize renderer (WebGPU async or WebGL sync) ────────────────

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    let disposed = false;
    let cleanupFns: (() => void)[] = [];

    const hasWebGPU = checkWebGPUSupport();
    setWebgpuAvailable(hasWebGPU);

    async function initWebGPU() {
      const { WebGPURenderer } = await import('three/webgpu');
      if (disposed || !containerRef.current) return;
      const ctr = containerRef.current!;

      const renderer = new WebGPURenderer({ antialias: true });
      renderer.setPixelRatio(window.devicePixelRatio);
      renderer.setSize(ctr.clientWidth, ctr.clientHeight);
      ctr.appendChild(renderer.domElement);
      await renderer.init();

      if (disposed) { renderer.dispose(); return; }

      rendererRef.current = renderer;

      const scene = new THREE.Scene();
      scene.background = new THREE.Color(COLORS.background);
      sceneRef.current = scene;
      addSceneLights(scene);

      const camera = new THREE.PerspectiveCamera(60, ctr.clientWidth / ctr.clientHeight, 0.1, 1000);
      camera.position.set(0, 0, 15);
      cameraRef.current = camera;

      const controls = new OrbitControls(camera, renderer.domElement);
      controls.enableDamping = true;
      controls.dampingFactor = 0.05;
      controlsRef.current = controls;

      const onResize = () => {
        if (!containerRef.current) return;
        camera.aspect = containerRef.current.clientWidth / containerRef.current.clientHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(containerRef.current.clientWidth, containerRef.current.clientHeight);
      };
      window.addEventListener('resize', onResize);
      cleanupFns.push(() => window.removeEventListener('resize', onResize));

      setRendererStatus('ready');
    }

    if (hasWebGPU) {
      initWebGPU();
    } else {
      const renderer = new THREE.WebGLRenderer({ antialias: true });
      renderer.setPixelRatio(window.devicePixelRatio);
      renderer.setSize(container.clientWidth, container.clientHeight);
      container.appendChild(renderer.domElement);
      rendererRef.current = renderer;

      const scene = new THREE.Scene();
      scene.background = new THREE.Color(COLORS.background);
      sceneRef.current = scene;
      addSceneLights(scene);

      const camera = new THREE.PerspectiveCamera(60, container.clientWidth / container.clientHeight, 0.1, 1000);
      camera.position.set(0, 0, 15);
      cameraRef.current = camera;

      const controls = new OrbitControls(camera, renderer.domElement);
      controls.enableDamping = true;
      controls.dampingFactor = 0.05;
      controlsRef.current = controls;

      const onResize = () => {
        if (!containerRef.current) return;
        camera.aspect = containerRef.current.clientWidth / containerRef.current.clientHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(containerRef.current.clientWidth, containerRef.current.clientHeight);
      };
      window.addEventListener('resize', onResize);
      cleanupFns.push(() => window.removeEventListener('resize', onResize));

      setRendererStatus('ready');
    }

    return () => {
      disposed = true;
      cleanupFns.forEach(fn => fn());
      cancelAnimationFrame(animFrameRef.current);
      controlsRef.current?.dispose();
      if (rendererRef.current) {
        rendererRef.current.dispose();
        const canv = rendererRef.current.domElement;
        if (canv.parentNode === container) container.removeChild(canv);
        rendererRef.current = null;
      }
    };
  }, []);

  // ── Animation loop (starts when renderer is ready) ─────────────────

  useEffect(() => {
    if (rendererStatus !== 'ready') return;

    const animate = () => {
      animFrameRef.current = requestAnimationFrame(animate);
      controlsRef.current?.update();

      const renderer = rendererRef.current as any;
      const scene = sceneRef.current;
      const camera = cameraRef.current;

      // Dispatch compute shaders if ready
      if (computeReadyRef.current && renderer?.compute) {
        if (computeVerletRef.current) renderer.compute(computeVerletRef.current);
        if (computeConstraintRef.current) renderer.compute(computeConstraintRef.current);

        // Read back compute buffer → update InstancedMesh positions
        const buf = storagePosRef.current;
        const mesh = instancedMeshRef.current;
        if (mesh && renderer.readBuffer && buf) {
          const byteLen = buf.array.byteLength;
          const gpuBuf = (buf as any).__storageBuffer || buf;
          renderer.readBuffer(gpuBuf, 0, byteLen).then((readData: ArrayBuffer) => {
            const floats = new Float32Array(readData);
            const dummy = new THREE.Object3D();
            const cnt = Math.min(mesh.count, floats.length / 3);
            for (let i = 0; i < cnt; i++) {
              const ix = i * 3;
              dummy.position.set(floats[ix], floats[ix + 1], floats[ix + 2]);
              dummy.updateMatrix();
              mesh.setMatrixAt(i, dummy.matrix);
            }
            mesh.instanceMatrix.needsUpdate = true;
          }).catch(() => { /* readBuffer not supported on this device */ });
        }
      }

      if (scene && camera && renderer) {
        renderer.render(scene, camera);
      }
    };

    animate();
  }, [rendererStatus]);

  // ── Build scene from lattice data ───────────────────────────────────

  useEffect(() => {
    if (rendererStatus !== 'ready' || !lattice) return;
    const scene = sceneRef.current;
    if (!scene) return;

    // Clear previous objects
    if (instancedMeshRef.current) { scene.remove(instancedMeshRef.current); instancedMeshRef.current = null; }
    if (edgeLinesRef.current) { scene.remove(edgeLinesRef.current); edgeLinesRef.current = null; }

    const { mesh, positions } = buildLatticeMesh(lattice, costLandscape, selectedLogic, showCost);
    staticPositionsRef.current = positions;
    scene.add(mesh);
    instancedMeshRef.current = mesh;

    const lines = buildEdgeLines(lattice, positions, costLandscape, selectedLogic, showAntiInertia);
    scene.add(lines);
    edgeLinesRef.current = lines;

    // Initialize compute shaders with this lattice data
    if (webgpuAvailable) {
      initCompute(lattice).catch(() => {});
    }
  }, [lattice, costLandscape, selectedLogic, showCost, showAntiInertia, rendererStatus, webgpuAvailable]);

  // ── Initialize WebGPU compute shaders ───────────────────────────────

  async function initCompute(lattice: TamariLattice) {
    const count = lattice.vertices.length;
    if (count < 1 || count > PARTICLE_COUNT) return;

    let TSL: Record<string, any>;
    try { TSL = await import('three/tsl'); } catch { return; }
    const { Fn, uniform, instanceIndex, If, storage } = TSL;

    // Populate positions from lattice data
    const posArr = new Float32Array(count * 3);
    lattice.vertices.forEach((v, i) => {
      posArr[i * 3] = v.coord.x * SCALE;
      posArr[i * 3 + 1] = v.coord.y * SCALE;
      posArr[i * 3 + 2] = v.coord.z * SCALE;
    });
    const storagePos = makeStorageAttribute(posArr, 3);
    storagePosRef.current = storagePos;

    // Velocities initialized to zero
    const velArr = new Float32Array(count * 3);
    const storageVel = makeStorageAttribute(velArr, 3);

    // Target positions (defaults = current positions, updated on path selection)
    const targetArr = new Float32Array(count * 3);
    targetArr.set(posArr);
    const storageTarget = makeStorageAttribute(targetArr, 3);

    // Create TSL storage nodes — one per buffer, created once
    const posNode = storage(storagePos, 'vec3', count);
    const velNode = storage(storageVel, 'vec3', count);
    const targetNode = storage(storageTarget, 'vec3', count);

    // Uniforms
    const gravity = uniform(-0.001);
    const friction = uniform(0.98);
    const lambda = uniform(1.0);
    const springStrength = uniform(0.05);

    // Verlet integration compute kernel
    const computeVerlet = Fn(() => {
      const pos = posNode.element(instanceIndex);
      const vel = velNode.element(instanceIndex);

      vel.y = vel.y.add(gravity);
      vel.x = vel.x.mul(friction);
      vel.y = vel.y.mul(friction);
      vel.z = vel.z.mul(friction);

      pos.x = pos.x.add(vel.x);
      pos.y = pos.y.add(vel.y);
      pos.z = pos.z.add(vel.z);

      If(pos.y.lessThan(-5), () => {
        pos.y = -5;
        vel.y = vel.y.negate().mul(0.5);
      });
    })().compute(count);
    computeVerletRef.current = computeVerlet;

    // Pentagonator constraint compute kernel
    const computeConstraint = Fn(() => {
      const pos = posNode.element(instanceIndex);
      const target = targetNode.element(instanceIndex);

      const dx = target.x.sub(pos.x);
      const dy = target.y.sub(pos.y);
      const dz = target.z.sub(pos.z);

      const strength = springStrength.mul(lambda);

      pos.x = pos.x.add(dx.mul(strength));
      pos.y = pos.y.add(dy.mul(strength));
      pos.z = pos.z.add(dz.mul(strength));
    })().compute(count);

    computeConstraintRef.current = computeConstraint;
    computeReadyRef.current = true;
  }

  // ── Highlight contraction path ──────────────────────────────────────

  useEffect(() => {
    const mesh = instancedMeshRef.current;
    if (!lattice || !contractionPath || !mesh) return;

    const pathSet = new Set(contractionPath.vertices);
    const color = new THREE.Color();
    lattice.vertices.forEach((v, i) => {
      if (pathSet.has(i)) color.setHex(COLORS.vertex_path);
      else if (v.is_right_comb) color.setHex(COLORS.vertex_rightcomb);
      else if (v.is_left_comb) color.setHex(COLORS.vertex_leftcomb);
      else color.setHex(COLORS.vertex_normal);
      mesh.setColorAt(i, color);
    });
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  }, [contractionPath, lattice]);

  // ── Click handler ───────────────────────────────────────────────────

  const handleVertexClick = useCallback(async (vertex: TamariVertex) => {
    setSelectedVertex(vertex);
    setAnimatePath(false);
    setAnimProgress(0);
    contractionLambdaRef.current = 1.0;
    try {
      const path = await tamariApi.findPathToEquilibrium(vertex.bits);
      setContractionPath(path);
    } catch { setContractionPath(null); }
  }, []);

  useEffect(() => {
    const renderer = rendererRef.current;
    const mesh = instancedMeshRef.current;
    if (!renderer || !lattice || !mesh) return;

    const raycaster = new THREE.Raycaster();
    const mouse = new THREE.Vector2();
    const onClick = (event: MouseEvent) => {
      const rect = renderer.domElement.getBoundingClientRect();
      mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(mouse, cameraRef.current!);
      const intersects = raycaster.intersectObject(mesh);
      if (intersects.length > 0) {
        const idx = intersects[0].instanceId;
        if (idx !== undefined) handleVertexClick(lattice.vertices[idx]);
      }
    };
    renderer.domElement.addEventListener('click', onClick);
    return () => renderer.domElement.removeEventListener('click', onClick);
  }, [lattice, handleVertexClick]);

  // ── Path animation ─────────────────────────────────────────────────

  useEffect(() => {
    if (!animatePath || !contractionPath) return;
    contractionLambdaRef.current = 1.0;
    const totalSteps = contractionPath.vertices.length - 1;
    let step = 0;
    const interval = setInterval(() => {
      step++;
      setAnimProgress(step / totalSteps);
      if (step >= totalSteps) { clearInterval(interval); setAnimatePath(false); }
    }, 500);
    return () => clearInterval(interval);
  }, [animatePath, contractionPath]);

  // ── Decay chart (coupling sweep) ──────────────────────────────────

  const [decayResult, setDecayResult] = useState<CouplingDecayResult | null>(null);

  // Fetch decay data when calMode changes to 'decay' or logic/n changes
  useEffect(() => {
    if (calMode !== 'decay') { setDecayResult(null); return; }
    tamariApi.getCouplingDecay(n, selectedLogic, '0,1,2,5,10,20,50')
      .then(setDecayResult)
      .catch(() => setDecayResult(null));
  }, [calMode, n, selectedLogic]);

  const drawDecayChart = useCallback(() => {
    const canvas = calCanvasRef.current;
    if (!canvas || !decayResult) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    canvas.width = canvas.clientWidth * window.devicePixelRatio;
    canvas.height = canvas.clientHeight * window.devicePixelRatio;
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;

    ctx.clearRect(0, 0, w, h);
    const pad = { top: 32, right: 16, bottom: 28, left: 44 };
    const plotW = w - pad.left - pad.right;
    const plotH = h - pad.top - pad.bottom;

    const sweep = decayResult.sweep;
    const maxMin = Math.max(...sweep.map(s => s.num_local_minima), 1);
    const maxDefect = Math.max(...sweep.map(s => s.pentagon_defect), 1);

    // Grid
    ctx.strokeStyle = 'rgba(100,130,180,0.12)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      const y = pad.top + (plotH / 4) * i;
      ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(w - pad.right, y); ctx.stroke();
    }

    // Axes
    ctx.strokeStyle = 'rgba(150,180,220,0.4)';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(pad.left, pad.top); ctx.lineTo(pad.left, pad.top + plotH); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(pad.left, pad.top + plotH); ctx.lineTo(w - pad.right, pad.top + plotH); ctx.stroke();

    // Y-axis labels (left = num local minima, right = pentagon defect)
    ctx.fillStyle = 'rgba(200,220,255,0.5)';
    ctx.font = '9px monospace';
    ctx.textAlign = 'right';
    for (let i = 0; i <= 4; i++) {
      const y = pad.top + (plotH / 4) * i;
      ctx.fillText(String(Math.round(maxMin * (1 - i / 4))), pad.left - 4, y + 3);
    }

    // X labels (coupling values)
    ctx.textAlign = 'center';
    sweep.forEach((s, i) => {
      const x = pad.left + (plotW / (sweep.length - 1 || 1)) * i;
      ctx.fillText(String(s.coupling), x, pad.top + plotH + 14);
    });

    // Curves: local minima (solid), pentagon defect (dashed)
    const lineX = (i: number) => pad.left + (plotW / (sweep.length - 1 || 1)) * i;

    // Local minima curve
    ctx.strokeStyle = '#44ff88';
    ctx.lineWidth = 2;
    ctx.setLineDash([]);
    ctx.beginPath();
    sweep.forEach((s, i) => {
      const y = pad.top + plotH - (s.num_local_minima / maxMin) * plotH;
      i === 0 ? ctx.moveTo(lineX(i), y) : ctx.lineTo(lineX(i), y);
    });
    ctx.stroke();
    sweep.forEach((s, i) => {
      const y = pad.top + plotH - (s.num_local_minima / maxMin) * plotH;
      ctx.fillStyle = '#44ff88';
      ctx.beginPath(); ctx.arc(lineX(i), y, 3, 0, Math.PI * 2); ctx.fill();
    });

    // Pentagon defect curve
    ctx.strokeStyle = '#ff6644';
    ctx.lineWidth = 1.5;
    ctx.setLineDash([4, 3]);
    ctx.beginPath();
    sweep.forEach((s, i) => {
      const y = pad.top + plotH - (s.pentagon_defect / maxDefect) * plotH;
      i === 0 ? ctx.moveTo(lineX(i), y) : ctx.lineTo(lineX(i), y);
    });
    ctx.stroke();
    ctx.setLineDash([]);

    // Labels
    ctx.fillStyle = '#44ff88';
    ctx.font = '9px monospace';
    ctx.textAlign = 'left';
    ctx.fillText('local minima', pad.left + 4, pad.top + 12);
    ctx.fillStyle = '#ff6644';
    ctx.fillText('pentagon defect', pad.left + 4, pad.top + 24);

    // Title
    ctx.fillStyle = 'rgba(200,220,255,0.4)';
    ctx.font = '9px monospace';
    ctx.textAlign = 'left';
    ctx.fillText(`Decay: ${decayResult.logic_type} (coupling → collapse)`, pad.left, pad.top - 6);
  }, [decayResult]);

  useEffect(() => {
    if (calMode !== 'decay' || !decayResult) return;
    drawDecayChart();
  }, [calMode, decayResult, drawDecayChart]);

  useEffect(() => {
    if (calMode !== 'decay') { cancelAnimationFrame(calAnimRef.current); return; }
    let running = true;
    const loop = () => {
      if (!running) return;
      drawDecayChart();
      calAnimRef.current = requestAnimationFrame(loop);
    };
    loop();
    return () => { running = false; cancelAnimationFrame(calAnimRef.current); };
  }, [calMode, drawDecayChart]);

  // ── Bench calibration ─────────────────────────────────────────────

  useEffect(() => {
    if (calMode !== 'bench' || !webgpuAvailable) return;
    let cancelled = false;

    (async () => {
      setCalResult(null);
      setCalError(null);
      let TSL: any;
      try { TSL = await import('three/tsl'); } catch { setCalError('Failed to import three/tsl'); return; }
      if (cancelled) return;

      const count = 16;
      const arr = new Float32Array(count);
      const attr = makeStorageAttribute(arr, 1);
      if (!(attr as any).isStorageInstancedBufferAttribute) {
        setCalError('StorageInstancedBufferAttribute not available (WebGPU required)');
        return;
      }

      const { kernel, verify } = createBenchKernel(TSL, attr, count);
      const renderer = rendererRef.current as any;
      if (!renderer?.compute) { setCalError('Renderer does not support compute'); return; }

      try {
        renderer.compute(kernel);
        const readData = await renderer.readBuffer(attr, 0, arr.byteLength);
        if (cancelled) return;
        const floats = new Float32Array(readData);
        const ok = verify(floats);
        const details = Array.from({ length: Math.min(8, count) }, (_, i) =>
          `[${i}] = ${floats[i]} (expected ${i * 2})`
        ).join(', ');
        setCalResult(ok
          ? `PASS: bench kernel verified (${details})`
          : `FAIL: bench mismatch (${details})`
        );
      } catch (e) {
        if (!cancelled) setCalError(`Bench error: ${e}`);
      }
    })();

    return () => { cancelled = true; };
  }, [calMode, webgpuAvailable]);

  // ── Phi calibration ───────────────────────────────────────────────

  useEffect(() => {
    if (calMode !== 'phi' || !webgpuAvailable || !lattice || !costLandscape) return;
    let cancelled = false;

    (async () => {
      setCalResult(null);
      setCalError(null);
      let TSL: any;
      try { TSL = await import('three/tsl'); } catch { setCalError('Failed to import three/tsl'); return; }
      if (cancelled) return;

      const V = lattice.vertex_count;
      const internalN = n;
      const bitStrings = lattice.vertices.map(v => v.bits);

      // Flatten all trees
      const treeData = flattenAllTrees(bitStrings, internalN);
      const treeAttr = makeStorageAttribute(
        new Float32Array(treeData), 1,
      );
      if (!(treeAttr as any).isStorageInstancedBufferAttribute) {
        setCalError('StorageInstancedBufferAttribute not available (WebGPU required)');
        return;
      }

      // Temp costs buffer (one extra element per tree for sentinel = 0)
      const costArr = new Float32Array(V * (internalN + 1));
      const costAttr = makeStorageAttribute(costArr, 1);

      // Output buffer
      const outArr = new Float32Array(V);
      const outAttr = makeStorageAttribute(outArr, 1);

      const params = getLogicParams(selectedLogic);
      const { kernel } = createPhiKernel(
        TSL, treeAttr, costAttr, outAttr, V, internalN, params,
      );

      const renderer = rendererRef.current as any;
      if (!renderer?.compute) { setCalError('Renderer does not support compute'); return; }

      try {
        renderer.compute(kernel);
        const readData = await renderer.readBuffer(outAttr, 0, outArr.byteLength);
        if (cancelled) return;
        const gpuCosts = new Float32Array(readData);

        // CPU reference
        const apiCosts = costLandscape.vertices.map(v => v.costs?.[selectedLogic] ?? 0);
        const cpuCosts = bitStrings.map(bits => computePhiCPU(bits, params));

        // Compare
        let maxGpuError = 0;
        let totalGpuError = 0;
        let maxCpuError = 0;
        let totalCpuError = 0;
        const errors: number[] = [];

        for (let i = 0; i < V; i++) {
          const gpuErr = Math.abs(gpuCosts[i] - apiCosts[i]);
          const cpuErr = Math.abs(cpuCosts[i] - apiCosts[i]);
          maxGpuError = Math.max(maxGpuError, gpuErr);
          totalGpuError += gpuErr;
          maxCpuError = Math.max(maxCpuError, cpuErr);
          totalCpuError += cpuErr;
          errors.push(gpuErr);
        }

        const gpuOk = maxGpuError === 0;
        const cpuOk = maxCpuError === 0;
        const summary = [
          `Trees: ${V}, n=${internalN}, logic: ${selectedLogic}`,
          `GPU vs API: ${gpuOk ? 'PASS' : 'FAIL'} (max err=${maxGpuError}, avg err=${(totalGpuError / V).toFixed(4)})`,
          `CPU vs API: ${cpuOk ? 'PASS' : 'FAIL'} (max err=${maxCpuError}, avg err=${(totalCpuError / V).toFixed(4)})`,
          `Params: bias=${params.bias} w=${params.leftWeight} rd=${params.rightDiv} c=${params.coupling} d=${params.denom}`,
          `GPU costs: ${gpuCosts.slice(0, 5).join(', ')}${V > 5 ? '...' : ''}`,
          `API costs: ${apiCosts.slice(0, 5).join(', ')}${V > 5 ? '...' : ''}`,
        ];
        setCalResult(summary.join('\n'));
      } catch (e) {
        if (!cancelled) setCalError(`Phi error: ${e}`);
      }
    })();

    return () => { cancelled = true; };
  }, [calMode, webgpuAvailable, lattice, costLandscape, n, selectedLogic]);

  // ── Render ─────────────────────────────────────────────────────────

  return (
    <div className="flex h-full w-full">
      {/* 3D Canvas */}
      <div className="flex-1 relative">
        <div ref={containerRef} className="absolute inset-0" />
        {/* Calibration chart overlay */}
        {calMode === 'decay' && (
          <canvas ref={calCanvasRef}
            className="absolute bottom-4 right-4 w-80 h-52 rounded-lg pointer-events-none"
            style={{ background: 'rgba(10,10,30,0.88)', border: '1px solid rgba(100,130,180,0.3)' }}
          />
        )}
        {/* Bench / Phi calibration result */}
        {(calMode === 'bench' || calMode === 'phi') && (
          <div className="absolute bottom-4 right-4 w-96 max-h-64 rounded-lg overflow-auto p-3 font-mono text-xs"
            style={{ background: 'rgba(10,10,30,0.92)', border: '1px solid rgba(100,130,180,0.3)' }}
          >
            {calError && <div className="text-red-400 whitespace-pre-wrap">{calError}</div>}
            {calResult && <div className="text-green-400 whitespace-pre-wrap">{calResult}</div>}
            {!calError && !calResult && <div className="text-slate-400">Running calibration...</div>}
          </div>
        )}
        {/* Controls overlay */}
        <div className="absolute top-4 left-4 bg-slate-900/80 backdrop-blur rounded-lg p-3 text-white text-sm space-y-2 max-w-xs">
          <div className="flex items-center gap-2">
            <label className="text-slate-300">Size n:</label>
            <select value={n} onChange={e => setN(Number(e.target.value))}
              className="bg-slate-700 text-white rounded px-2 py-1 text-sm">
              {[0, 1, 2, 3, 4, 5].map(v => (
                <option key={v} value={v}>T{v} ({[1, 1, 2, 5, 14, 42][v]} trees)</option>
              ))}
            </select>
          </div>
          {/* Logic type selector */}
          <div className="flex items-center gap-2">
            <label className="text-slate-300 text-xs">Logic:</label>
            <select value={selectedLogic} onChange={e => setSelectedLogic(e.target.value)}
              className="bg-slate-700 text-white rounded px-2 py-1 text-xs max-w-[140px]">
              {LOGIC_TYPES.map(lt => (
                <option key={lt} value={lt}>{LOGIC_LABELS[lt] || lt}</option>
              ))}
            </select>
          </div>
          {/* Toggles */}
          <div className="flex items-center gap-3 text-xs">
            <label className="flex items-center gap-1 cursor-pointer">
              <input type="checkbox" checked={showCost} onChange={e => setShowCost(e.target.checked)}
                className="accent-blue-500" />
              Φ cost field
            </label>
            <label className="flex items-center gap-1 cursor-pointer">
              <input type="checkbox" checked={showAntiInertia} onChange={e => setShowAntiInertia(e.target.checked)}
                className="accent-pink-500" />
              Anti-inertia
            </label>
          </div>
          {/* Calibration mode */}
          <div className="flex items-center gap-2 text-xs">
            <label className="text-slate-300">Cal:</label>
            <select value={calMode} onChange={e => setCalMode(e.target.value as any)}
              className="bg-slate-700 text-white rounded px-1 py-0.5 text-xs">
              <option value="off">Off</option>
              <option value="decay">Decay</option>
              <option value="bench">Bench (GPU)</option>
              <option value="phi">Phi (GPU)</option>
            </select>
          </div>
          {loading && <div className="text-yellow-400">Loading...</div>}
          {error && <div className="text-red-400">{error}</div>}
          <div className="flex items-center gap-2 text-xs">
            <span className={`w-2 h-2 rounded-full ${webgpuAvailable ? 'bg-green-500' : 'bg-yellow-500'}`} />
            <span className="text-slate-400">{webgpuAvailable ? 'WebGPU (compute shaders)' : 'WebGL (fallback)'}</span>
          </div>
          {lattice && <div className="text-slate-400 text-xs">{lattice.vertex_count} vertices, {lattice.edge_count} edges</div>}
        </div>
        {/* Legend */}
        <div className="absolute bottom-4 left-4 bg-slate-900/80 backdrop-blur rounded-lg p-3 text-white text-xs space-y-1">
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#4488ff' }} /><span>Regular tree</span></div>
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#44ff88' }} /><span>rightComb (equilibrium)</span></div>
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#ff4444' }} /><span>leftComb (maximum)</span></div>
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: showCost ? '#ffaa00' : '#4488ff' }} /><span>Cost height → yellow</span></div>
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#ff44ff' }} /><span>Contraction path</span></div>
          {showAntiInertia && <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#ff66aa' }} /><span>Anti-inertia (Φ gradient)</span></div>}
        </div>
      </div>

      {/* Side panel */}
      <div className="w-80 bg-slate-900 text-white overflow-y-auto border-l border-slate-700">
        <div className="p-4">
          <h2 className="text-lg font-semibold mb-4">Tamari Lattice T{n}</h2>

          {selectedVertex && (
            <div className="mb-4 p-3 bg-slate-800 rounded-lg">
              <h3 className="text-sm font-medium text-slate-300 mb-2">Selected Tree</h3>
              <div className="text-xs space-y-1 font-mono">
                <div className="text-blue-300">{selectedVertex.repr}</div>
                <div className="text-slate-400">bits: {selectedVertex.bits}</div>
                <div className="text-slate-400">
                  coord: ({selectedVertex.coord.x}, {selectedVertex.coord.y}, {selectedVertex.coord.z})
                </div>
                {costLandscape && (
                  <div className="text-yellow-400">
                    Φ({LOGIC_LABELS[selectedLogic] || selectedLogic}) = {costLandscape.vertices[selectedVertex.id]?.costs?.[selectedLogic] ?? '?'}
                  </div>
                )}
                {selectedVertex.is_right_comb && <div className="text-green-400">rightComb — equilibrium attractor</div>}
                {selectedVertex.is_left_comb && <div className="text-red-400">leftComb — maximum element</div>}
              </div>
            </div>
          )}

          {contractionPath && (
            <div className="mb-4 p-3 bg-slate-800 rounded-lg">
              <h3 className="text-sm font-medium text-slate-300 mb-2">Contraction Path to Equilibrium</h3>
              <div className="text-xs space-y-1">
                <div className="text-slate-400">Length: {contractionPath.length} step{contractionPath.length !== 1 ? 's' : ''}</div>
                <button onClick={() => { setAnimatePath(true); setAnimProgress(0); contractionLambdaRef.current = 1.0; }}
                  className="mt-2 px-3 py-1 bg-purple-600 hover:bg-purple-500 rounded text-xs">
                  Animate NA→NC Transition
                </button>
                {animProgress > 0 && (
                  <div className="mt-2">
                    <div className="w-full bg-slate-700 rounded-full h-2">
                      <div className="bg-purple-500 h-2 rounded-full transition-all duration-300" style={{ width: `${animProgress * 100}%` }} />
                    </div>
                    <div className="text-slate-400 mt-1">λ = {(1 - animProgress).toFixed(2)} (non-assoc → NC)</div>
                  </div>
                )}
                <div className="mt-2 text-slate-400">
                  Path: {contractionPath.vertices.map((vi, i) => (
                    <span key={i}>{i > 0 && ' → '}<span className="text-purple-300">{treeShortLabel(lattice?.vertices[vi]?.repr || '')}</span></span>
                  ))}
                </div>
              </div>
            </div>
          )}

          <div>
            <h3 className="text-sm font-medium text-slate-300 mb-2">All Trees ({lattice?.vertex_count || 0})</h3>
            <div className="space-y-1">
              {lattice?.vertices.map(v => (
                <button key={v.id} onClick={() => handleVertexClick(v)}
                  className={`w-full text-left px-2 py-1 rounded text-xs font-mono transition-colors ${
                    selectedVertex?.id === v.id ? 'bg-purple-600/30 text-purple-300' : 'hover:bg-slate-800 text-slate-400'
                  }`}>
                  <span className={v.is_right_comb ? 'text-green-400' : v.is_left_comb ? 'text-red-400' : ''}>
                    {treeShortLabel(v.repr)}
                  </span>
                  <span className="text-slate-600 ml-2">({v.coord.x},{v.coord.y})</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
