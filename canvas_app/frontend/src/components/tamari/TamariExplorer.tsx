import { useEffect, useRef, useState, useCallback } from 'react';
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { tamariApi, TamariLattice, TamariVertex, TamariPath, CostLandscape, CouplingDecayResult } from '../../services/tamariApi';
import { createBenchKernel } from '../../shaders/bench';
import { flattenAllTrees, computePhiCPU, getLogicParams, createPhiKernel } from '../../shaders/phi_cost';

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

const N_SURVEY_PARTICLES = 30;
const SURVEY_STEP_RATE = 3; // steps per frame per particle

function costColor(cost: number, maxCost: number, isRC: boolean, isLC: boolean): number {
  if (isRC) return COLORS.vertex_rightcomb;
  if (isLC) return COLORS.vertex_leftcomb;
  if (maxCost === 0) return COLORS.vertex_normal;
  const t = Math.min(cost / maxCost, 1);
  const r = Math.round(0x44 + (0xff - 0x44) * t);
  const g = Math.round(0x88 * (1 - t * 0.7));
  const b = Math.round(0xff * (1 - t));
  return (r << 16) | (g << 8) | b;
}

function treeShortLabel(repr: string): string {
  return repr.replace(/Node/g, 'N').replace(/Leaf/g, 'L').replace(/\s/g, '');
}

function makeStorageAttribute(array: Float32Array, itemSize: number): any {
  const ctor = (THREE as any).StorageInstancedBufferAttribute;
  if (ctor) return new ctor(array, itemSize);
  const attr = new THREE.InstancedBufferAttribute(array, itemSize);
  (attr as any).isStorageInstancedBufferAttribute = true;
  return attr;
}

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

interface SurveyParticle {
  vertexIdx: number;
  budget: number;
  stuck: boolean;
  hopCount: number;
}

type CalMode = 'off' | 'decay' | 'bench' | 'phi' | 'survey';

interface TamariExplorerProps {
  initialN?: number;
}

export function TamariExplorer({ initialN = 3 }: TamariExplorerProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const rendererRef = useRef<any>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const controlsRef = useRef<OrbitControls | null>(null);
  const animFrameRef = useRef<number>(0);
  const [rendererStatus, setRendererStatus] = useState<'init' | 'ready'>('init');

  const [webgpuAvailable, setWebgpuAvailable] = useState(false);
  const staticPositionsRef = useRef<Float32Array | null>(null);
  const instancedMeshRef = useRef<THREE.InstancedMesh | null>(null);
  const edgeLinesRef = useRef<THREE.LineSegments | null>(null);

  const calCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const calAnimRef = useRef<number>(0);

  // Path animation refs
  const pathLerpRef = useRef(0);
  const pathAnimRunningRef = useRef(false);
  const pathStepRef = useRef(0);
  const latticeRef = useRef<TamariLattice | null>(null);
  const pathRef = useRef<TamariPath | null>(null);

  // Survey refs (avoid stale closures in rAF)
  const surveyParticlesRef = useRef<SurveyParticle[]>([]);
  const surveyBudgetRef = useRef(50);
  const surveyAdjListRef = useRef<number[][]>([]);
  const surveyEdgeCostRef = useRef<Float32Array | null>(null);
  const surveyStuckCountRef = useRef(0);
  const surveyKnotVerticesRef = useRef<Set<number>>(new Set());
  const surveyParticleMeshesRef = useRef<THREE.InstancedMesh | null>(null);
  const surveyKnotMeshesRef = useRef<THREE.InstancedMesh | null>(null);

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
  const [antiInertiaBudget, setAntiInertiaBudget] = useState(50);
  const [calMode, setCalMode] = useState<CalMode>('off');
  const [calResult, setCalResult] = useState<string | null>(null);
  const [calError, setCalError] = useState<string | null>(null);

  // Survey live stats (updated periodically from refs)
  const [surveyStats, setSurveyStats] = useState({ free: 0, stuck: 0, knots: 0, totalHops: 0 });
  const [surveySweepActive, setSurveySweepActive] = useState(false);
  const surveySweepIdxRef = useRef(0);

  // Lean verification
  const [leanResult, setLeanResult] = useState<{ passed: boolean; summary: string; target_count: number } | null>(null);
  const [leanVerifying, setLeanVerifying] = useState(false);

  // Find interesting
  const [interestingVertices, setInterestingVertices] = useState<any[] | null>(null);
  const [interestingLoading, setInterestingLoading] = useState(false);

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

  useEffect(() => { latticeRef.current = lattice; }, [lattice]);
  useEffect(() => { pathRef.current = contractionPath; }, [contractionPath]);

  // ── Initialize renderer ─────────────────────────────────────────────

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    let disposed = false;
    let cleanupFns: (() => void)[] = [];

    async function waitForDimensions(ctr: HTMLDivElement, timeout = 3000): Promise<void> {
      if (ctr.clientWidth > 0 && ctr.clientHeight > 0) return;
      return new Promise<void>(resolve => {
        const start = Date.now();
        const obs = new ResizeObserver(() => {
          if (ctr.clientWidth > 0 && ctr.clientHeight > 0 || Date.now() - start > timeout) {
            obs.disconnect();
            resolve();
          }
        });
        obs.observe(ctr);
      });
    }

    function initWebGL(ctr: HTMLDivElement) {
      const w = ctr.clientWidth || window.innerWidth;
      const h = ctr.clientHeight || window.innerHeight;
      const renderer = new THREE.WebGLRenderer({ antialias: true });
      renderer.setPixelRatio(window.devicePixelRatio);
      renderer.setSize(w, h);
      ctr.appendChild(renderer.domElement);
      rendererRef.current = renderer;

      const scene = new THREE.Scene();
      scene.background = new THREE.Color(COLORS.background);
      sceneRef.current = scene;
      addSceneLights(scene);

      const aspect = ctr.clientWidth / Math.max(ctr.clientHeight, 1);
      const camera = new THREE.PerspectiveCamera(60, aspect, 0.1, 1000);
      camera.position.set(0, 0, 15);
      cameraRef.current = camera;

      const controls = new OrbitControls(camera, renderer.domElement);
      controls.enableDamping = true;
      controls.dampingFactor = 0.05;
      controlsRef.current = controls;

      const onResize = () => {
        if (!containerRef.current) return;
        const w = containerRef.current.clientWidth;
        const h = Math.max(containerRef.current.clientHeight, 1);
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
        renderer.setSize(w, h);
      };
      window.addEventListener('resize', onResize);
      cleanupFns.push(() => window.removeEventListener('resize', onResize));

      setRendererStatus('ready');
    }

    async function initWebGPU(ctr: HTMLDivElement) {
      const { WebGPURenderer } = await import('three/webgpu');
      if (disposed || !containerRef.current) return;
      await waitForDimensions(ctr);

      const w = ctr.clientWidth || window.innerWidth;
      const h = Math.max(ctr.clientHeight, 1) || window.innerHeight;
      const renderer = new WebGPURenderer({ antialias: true, powerPreference: 'high-performance' });
      renderer.setPixelRatio(window.devicePixelRatio);
      renderer.setSize(w, h);
      ctr.appendChild(renderer.domElement);
      await renderer.init();

      if (disposed) { renderer.dispose(); return; }

      rendererRef.current = renderer;

      const scene = new THREE.Scene();
      scene.background = new THREE.Color(COLORS.background);
      sceneRef.current = scene;
      addSceneLights(scene);

      const aspect = ctr.clientWidth / Math.max(ctr.clientHeight, 1);
      const camera = new THREE.PerspectiveCamera(60, aspect, 0.1, 1000);
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

      setWebgpuAvailable(true);
      setRendererStatus('ready');
    }

    const hasWebGPU = !!(navigator as any).gpu;
    if (hasWebGPU) {
      initWebGPU(container).catch(() => {
        setWebgpuAvailable(false);
        if (disposed) return;
        initWebGL(container);
      });
    } else {
      setWebgpuAvailable(false);
      initWebGL(container);
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

  // ── Survey init (build adjacency + edge costs) ─────────────────────

  useEffect(() => {
    if (calMode !== 'survey' || !lattice || !costLandscape) return;
    const nVerts = lattice.vertices.length;
    const adj: number[][] = Array.from({ length: nVerts }, () => []);
    const edgeCost = new Float32Array(nVerts * nVerts).fill(-1);

    lattice.edges.forEach(e => {
      adj[e.source].push(e.target);
      adj[e.target].push(e.source);
      const ci = Math.abs(
        (costLandscape.vertices[e.source]?.costs?.[selectedLogic] ?? 0) -
        (costLandscape.vertices[e.target]?.costs?.[selectedLogic] ?? 0)
      );
      edgeCost[e.source * nVerts + e.target] = ci;
      edgeCost[e.target * nVerts + e.source] = ci;
    });

    surveyAdjListRef.current = adj;
    surveyEdgeCostRef.current = edgeCost;
  }, [calMode, lattice, costLandscape, selectedLogic]);

  // ── Survey particle initialization ─────────────────────────────────

  useEffect(() => {
    if (calMode !== 'survey' || !lattice) return;

    surveyParticlesRef.current = Array.from({ length: N_SURVEY_PARTICLES }, () => ({
      vertexIdx: Math.floor(Math.random() * lattice.vertices.length),
      budget: antiInertiaBudget,
      stuck: false,
      hopCount: 0,
    }));
    surveyStuckCountRef.current = 0;
    surveyKnotVerticesRef.current = new Set();
  }, [calMode, lattice, antiInertiaBudget]);

  // Keep budget ref in sync (for rAF)
  useEffect(() => { surveyBudgetRef.current = antiInertiaBudget; }, [antiInertiaBudget]);

  // ── Survey sweep (auto-cycle logics) ──────────────────────────────

  useEffect(() => {
    if (calMode !== 'survey' || !surveySweepActive) return;
    const interval = setInterval(() => {
      const next = (surveySweepIdxRef.current + 1) % LOGIC_TYPES.length;
      surveySweepIdxRef.current = next;
      setSelectedLogic(LOGIC_TYPES[next]);
    }, 5000);
    return () => clearInterval(interval);
  }, [calMode, surveySweepActive]);

  // ── Build/teardown survey particle meshes ──────────────────────────

  useEffect(() => {
    if (calMode !== 'survey') {
      if (surveyParticleMeshesRef.current && sceneRef.current) {
        sceneRef.current.remove(surveyParticleMeshesRef.current);
        surveyParticleMeshesRef.current.geometry.dispose();
        (surveyParticleMeshesRef.current.material as THREE.Material).dispose();
        surveyParticleMeshesRef.current = null;
      }
      if (surveyKnotMeshesRef.current && sceneRef.current) {
        sceneRef.current.remove(surveyKnotMeshesRef.current);
        surveyKnotMeshesRef.current.geometry.dispose();
        (surveyKnotMeshesRef.current.material as THREE.Material).dispose();
        surveyKnotMeshesRef.current = null;
      }
      return;
    }
    if (!sceneRef.current) return;

    // Particle mesh (small glowing spheres)
    const partGeom = new THREE.SphereGeometry(0.08, 8, 8);
    const partMat = new THREE.MeshBasicMaterial({ color: 0x88ff88 });
    const partMesh = new THREE.InstancedMesh(partGeom, partMat, N_SURVEY_PARTICLES);
    sceneRef.current.add(partMesh);
    surveyParticleMeshesRef.current = partMesh;

    // Knot mesh (larger pulsing spheres, up to Verts)
    const knotGeom = new THREE.SphereGeometry(0.12, 8, 8);
    const knotMat = new THREE.MeshBasicMaterial({ color: 0xff4488 });
    const knotMesh = new THREE.InstancedMesh(knotGeom, knotMat, 0);
    sceneRef.current.add(knotMesh);
    surveyKnotMeshesRef.current = knotMesh;

    return () => {
      if (surveyParticleMeshesRef.current && sceneRef.current) {
        sceneRef.current.remove(surveyParticleMeshesRef.current);
        surveyParticleMeshesRef.current.geometry.dispose();
        (surveyParticleMeshesRef.current.material as THREE.Material).dispose();
        surveyParticleMeshesRef.current = null;
      }
      if (surveyKnotMeshesRef.current && sceneRef.current) {
        sceneRef.current.remove(surveyKnotMeshesRef.current);
        surveyKnotMeshesRef.current.geometry.dispose();
        (surveyKnotMeshesRef.current.material as THREE.Material).dispose();
        surveyKnotMeshesRef.current = null;
      }
    };
  }, [calMode]);

  // ── Animation loop ─────────────────────────────────────────────────

  useEffect(() => {
    if (rendererStatus !== 'ready') return;

    const animate = () => {
      animFrameRef.current = requestAnimationFrame(animate);
      controlsRef.current?.update();

      const renderer = rendererRef.current as any;
      const scene = sceneRef.current;
      const camera = cameraRef.current;

      // CPU path animation
      const mesh = instancedMeshRef.current;
      const staticPos = staticPositionsRef.current;
      const path = pathRef.current;
      const lats = latticeRef.current;
      if (pathAnimRunningRef.current && mesh && staticPos && path && lats) {
        const totalSteps = path.vertices.length - 1;
        const step = pathStepRef.current;
        if (step < totalSteps) {
          const fromIdx = path.vertices[step];
          const toIdx = path.vertices[step + 1];

          const fx = staticPos[fromIdx * 3];
          const fy = staticPos[fromIdx * 3 + 1];
          const fz = staticPos[fromIdx * 3 + 2];
          const tx = staticPos[toIdx * 3];
          const ty = staticPos[toIdx * 3 + 1];
          const tz = staticPos[toIdx * 3 + 2];

          pathLerpRef.current = Math.min(pathLerpRef.current + 0.025, 1.0);
          const t = pathLerpRef.current;
          const s = t * t * (3 - 2 * t);

          const dummy = new THREE.Object3D();
          const ax = fx + (tx - fx) * s;
          const ay = fy + (ty - fy) * s;
          const az = fz + (tz - fz) * s;
          dummy.position.set(ax, ay, az);
          dummy.updateMatrix();
          mesh.setMatrixAt(fromIdx, dummy.matrix);
          mesh.instanceMatrix.needsUpdate = true;

          if (t >= 1.0) {
            dummy.position.set(tx, ty, tz);
            dummy.updateMatrix();
            mesh.setMatrixAt(fromIdx, dummy.matrix);
            mesh.instanceMatrix.needsUpdate = true;

            if (step >= totalSteps - 1) {
              pathAnimRunningRef.current = false;
              setAnimatePath(false);
              const dummy2 = new THREE.Object3D();
              const cnt = Math.min(mesh.count, staticPos.length / 3);
              for (let i = 0; i < cnt; i++) {
                dummy2.position.set(staticPos[i * 3], staticPos[i * 3 + 1], staticPos[i * 3 + 2]);
                dummy2.updateMatrix();
                mesh.setMatrixAt(i, dummy2.matrix);
              }
              mesh.instanceMatrix.needsUpdate = true;
              setAnimProgress(1);
            } else {
              pathStepRef.current = step + 1;
              pathLerpRef.current = 0;
              setAnimProgress((step + 1) / totalSteps);
            }
          }
        }
      }

      // ── Survey simulation ────────────────────────────────────────────
      if (calMode === 'survey') {
        const adj = surveyAdjListRef.current;
        const edgeCost = surveyEdgeCostRef.current;
        const particles = surveyParticlesRef.current;
        const nVerts = adj.length;
        const pos = staticPositionsRef.current;
        const partMesh = surveyParticleMeshesRef.current;

        if (adj.length > 0 && pos && particles.length > 0) {
          let totalStuck = 0;
          let totalHops = 0;
          const knotVerts = surveyKnotVerticesRef.current;

          for (let p = 0; p < particles.length; p++) {
            const pt = particles[p];
            totalHops += pt.hopCount;

            if (pt.stuck) { totalStuck++; continue; }

            // Step SURVEY_STEP_RATE times per frame
            for (let step = 0; step < SURVEY_STEP_RATE; step++) {
              const neighbors = adj[pt.vertexIdx];
              if (!neighbors || neighbors.length === 0) break;

              // Pick random neighbor
              const nIdx = neighbors[Math.floor(Math.random() * neighbors.length)];
              const cost = edgeCost ? edgeCost[pt.vertexIdx * nVerts + nIdx] : 0;

              if (cost <= pt.budget) {
                pt.vertexIdx = nIdx;
                pt.budget -= cost;
                pt.hopCount++;
              } else {
                // Particle is stuck — record knot
                pt.stuck = true;
                totalStuck++;
                knotVerts.add(pt.vertexIdx);
                break;
              }
            }
          }

          surveyStuckCountRef.current = totalStuck;
          surveyKnotVerticesRef.current = knotVerts;

          // Update particle mesh
          if (partMesh) {
            const dummy = new THREE.Object3D();
            for (let p = 0; p < particles.length; p++) {
              const vi = particles[p].vertexIdx;
              const px = pos[vi * 3];
              const py = pos[vi * 3 + 1];
              const pz = pos[vi * 3 + 2];
              dummy.position.set(px, py + 0.1, pz);
              dummy.scale.setScalar(particles[p].stuck ? 0.5 : 1);
              dummy.updateMatrix();
              partMesh.setMatrixAt(p, dummy.matrix);
            }
            partMesh.instanceMatrix.needsUpdate = true;
            partMesh.count = particles.length;
          }

          // Update knot mesh
          const knotMesh = surveyKnotMeshesRef.current;
          if (knotMesh) {
            const knotArr = Array.from(knotVerts);
            if (knotArr.length !== knotMesh.count) {
              // Recreate geometry with correct count
              const newGeom = new THREE.SphereGeometry(0.12, 8, 8);
              const newKnot = new THREE.InstancedMesh(newGeom, knotMesh.material, knotArr.length);
              if (sceneRef.current) {
                sceneRef.current.remove(knotMesh);
                sceneRef.current.add(newKnot);
              }
              surveyKnotMeshesRef.current = newKnot;
            }
            const kMesh = surveyKnotMeshesRef.current;
            if (kMesh) {
              const kDummy = new THREE.Object3D();
              knotArr.forEach((vi, i) => {
                const kx = pos[vi * 3];
                const ky = pos[vi * 3 + 1];
                const kz = pos[vi * 3 + 2];
                kDummy.position.set(kx, ky, kz);
                kDummy.scale.setScalar(1 + 0.2 * Math.sin(Date.now() * 0.003 + i));
                kDummy.updateMatrix();
                kMesh.setMatrixAt(i, kDummy.matrix);
              });
              kMesh.instanceMatrix.needsUpdate = true;
            }
          }

          // Push stats to state periodically (every ~60 frames via hopCount-based throttle)
          setSurveyStats({
            free: particles.length - totalStuck,
            stuck: totalStuck,
            knots: knotVerts.size,
            totalHops,
          });
        }
      }

      if (scene && camera && renderer) {
        renderer.render(scene, camera);
      }
    };

    animate();
  }, [rendererStatus, calMode]);

  // ── Build scene from lattice data ───────────────────────────────────

  useEffect(() => {
    if (rendererStatus !== 'ready' || !lattice) return;
    const scene = sceneRef.current;
    if (!scene) return;

    if (instancedMeshRef.current) { scene.remove(instancedMeshRef.current); instancedMeshRef.current = null; }
    if (edgeLinesRef.current) { scene.remove(edgeLinesRef.current); edgeLinesRef.current = null; }

    const { mesh, positions } = buildLatticeMesh(lattice, costLandscape, selectedLogic, showCost);
    staticPositionsRef.current = positions;
    scene.add(mesh);
    instancedMeshRef.current = mesh;

    const lines = buildEdgeLines(lattice, positions, costLandscape, selectedLogic, showAntiInertia);
    scene.add(lines);
    edgeLinesRef.current = lines;

    pathStepRef.current = 0;
    pathLerpRef.current = 0;
    pathAnimRunningRef.current = false;
  }, [lattice, costLandscape, selectedLogic, showCost, showAntiInertia, rendererStatus]);

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

  // ── Lean verify handler ───────────────────────────────────────────

  const handleLeanVerify = useCallback(async () => {
    setLeanVerifying(true);
    setLeanResult(null);
    try {
      const result = await tamariApi.verifyLean();
      setLeanResult(result);
    } catch {
      setLeanResult({ passed: false, summary: 'FAIL: network error', target_count: 0 });
    } finally {
      setLeanVerifying(false);
    }
  }, []);

  const handleVertexClick = useCallback(async (vertex: TamariVertex) => {
    setSelectedVertex(vertex);
    pathAnimRunningRef.current = false;
    setAnimatePath(false);
    setAnimProgress(0);
    const mesh = instancedMeshRef.current;
    const pos = staticPositionsRef.current;
    if (mesh && pos) {
      const dummy = new THREE.Object3D();
      const cnt = Math.min(mesh.count, pos.length / 3);
      for (let i = 0; i < cnt; i++) {
        dummy.position.set(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]);
        dummy.updateMatrix();
        mesh.setMatrixAt(i, dummy.matrix);
      }
      mesh.instanceMatrix.needsUpdate = true;
    }
    try {
      const path = await tamariApi.findPathToEquilibrium(vertex.bits);
      setContractionPath(path);
    } catch { setContractionPath(null); }
  }, []);

  // Find interesting meta-stable configurations via Lean-verified backend
  const handleFindInteresting = useCallback(async () => {
    if (!lattice) return;
    setInterestingLoading(true);
    setInterestingVertices(null);
    try {
      const result = await tamariApi.findInteresting(n, selectedLogic, 5);
      setInterestingVertices(result.vertices);
      if (result.vertices.length > 0) {
        const v = lattice.vertices[result.vertices[0].id];
        if (v) handleVertexClick(v);
      }
    } catch { /* ignore */ }
    setInterestingLoading(false);
  }, [n, selectedLogic, lattice]);

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

  useEffect(() => {
    if (!animatePath || !contractionPath) return;
    pathStepRef.current = 0;
    pathLerpRef.current = 0;
    pathAnimRunningRef.current = true;
    const mesh = instancedMeshRef.current;
    const pos = staticPositionsRef.current;
    if (mesh && pos) {
      const dummy = new THREE.Object3D();
      const cnt = Math.min(mesh.count, pos.length / 3);
      for (let i = 0; i < cnt; i++) {
        dummy.position.set(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]);
        dummy.updateMatrix();
        mesh.setMatrixAt(i, dummy.matrix);
      }
      mesh.instanceMatrix.needsUpdate = true;
    }
    setAnimProgress(0);
  }, [animatePath, contractionPath]);

  // ── Decay chart ───────────────────────────────────────────────────

  const [decayResult, setDecayResult] = useState<CouplingDecayResult | null>(null);

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

    ctx.strokeStyle = 'rgba(100,130,180,0.12)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      const y = pad.top + (plotH / 4) * i;
      ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(w - pad.right, y); ctx.stroke();
    }

    ctx.strokeStyle = 'rgba(150,180,220,0.4)';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(pad.left, pad.top); ctx.lineTo(pad.left, pad.top + plotH); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(pad.left, pad.top + plotH); ctx.lineTo(w - pad.right, pad.top + plotH); ctx.stroke();

    ctx.fillStyle = 'rgba(200,220,255,0.5)';
    ctx.font = '9px monospace';
    ctx.textAlign = 'right';
    for (let i = 0; i <= 4; i++) {
      const y = pad.top + (plotH / 4) * i;
      ctx.fillText(String(Math.round(maxMin * (1 - i / 4))), pad.left - 4, y + 3);
    }

    ctx.textAlign = 'center';
    sweep.forEach((s, i) => {
      const x = pad.left + (plotW / (sweep.length - 1 || 1)) * i;
      ctx.fillText(String(s.coupling), x, pad.top + plotH + 14);
    });

    const lineX = (i: number) => pad.left + (plotW / (sweep.length - 1 || 1)) * i;

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

    ctx.fillStyle = '#44ff88';
    ctx.font = '9px monospace';
    ctx.textAlign = 'left';
    ctx.fillText('local minima', pad.left + 4, pad.top + 12);
    ctx.fillStyle = '#ff6644';
    ctx.fillText('pentagon defect', pad.left + 4, pad.top + 24);

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
      const canvas = calCanvasRef.current;
      const ctx = canvas?.getContext('2d');
      if (!ctx) { calAnimRef.current = requestAnimationFrame(loop); return; }
      drawDecayChart();
      calAnimRef.current = requestAnimationFrame(loop);
    };
    loop();
    return () => { running = false; cancelAnimationFrame(calAnimRef.current); };
  }, [calMode, drawDecayChart]);

  // ── Bench calibration ─────────────────────────────────────────────

  useEffect(() => {
    if (calMode !== 'bench') return;
    let cancelled = false;

    (async () => {
      setCalResult(null);
      setCalError(null);

      if (!webgpuAvailable) {
        setCalError('WebGPU not available — bench requires GPU compute');
        return;
      }

      let TSL: any;
      try { TSL = await import('three/tsl'); } catch { setCalError('Failed to import three/tsl'); return; }
      if (cancelled) return;

      const count = 16;
      const arr = new Float32Array(count);
      const attr = makeStorageAttribute(arr, 1);
      if (!(attr as any).isStorageInstancedBufferAttribute) {
        setCalError('StorageInstancedBufferAttribute not available');
        return;
      }

      const { kernel, verify } = createBenchKernel(TSL, attr, count);
      const renderer = rendererRef.current as any;
      if (!renderer?.compute) { setCalError('Renderer does not support compute'); return; }

      try {
        renderer.compute(kernel);
        const readData = await renderer.backend.getArrayBufferAsync(attr, null, 0, arr.byteLength);
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

  // ── Phi calibration (GPU or CPU fallback) ─────────────────────────

  useEffect(() => {
    if (calMode !== 'phi' || !lattice || !costLandscape) return;
    let cancelled = false;

    (async () => {
      setCalResult(null);
      setCalError(null);

      const V = lattice.vertex_count;
      const internalN = n;
      const bitStrings = lattice.vertices.map(v => v.bits);
      const params = getLogicParams(selectedLogic);

      if (webgpuAvailable) {
        // GPU path
        let TSL: any;
        try { TSL = await import('three/tsl'); } catch { setCalError('Failed to import three/tsl'); return; }
        if (cancelled) return;

        const treeData = flattenAllTrees(bitStrings, internalN);
        const treeAttr = makeStorageAttribute(new Float32Array(treeData), 1);
        if (!(treeAttr as any).isStorageInstancedBufferAttribute) {
          setCalError('StorageInstancedBufferAttribute not available');
          return;
        }
        const costArr = new Float32Array(V * (internalN + 1));
        const costAttr = makeStorageAttribute(costArr, 1);
        const outArr = new Float32Array(V);
        const outAttr = makeStorageAttribute(outArr, 1);

        // Try GPU compute, fall back to CPU on any error
        let gpuCosts: Float32Array | null = null;
        try {
          const { kernel } = createPhiKernel(TSL, treeAttr, costAttr, outAttr, V, internalN, params);
          const renderer = rendererRef.current as any;
          if (renderer?.compute) {
            renderer.compute(kernel);
            const readData = await renderer.backend.getArrayBufferAsync(outAttr, null, 0, outArr.byteLength);
            if (!cancelled) gpuCosts = new Float32Array(readData);
          }
        } catch (e) {
          if (!cancelled) console.warn('Phi GPU path failed, falling back to CPU:', e);
        }
        if (cancelled) return;

        // CPU reference always computed
        const apiCosts = costLandscape.vertices.map(v => v.costs?.[selectedLogic] ?? 0);
        const cpuCosts = bitStrings.map(bits => computePhiCPU(bits, params));

        let maxCpuError = 0, totalCpuError = 0;
        for (let i = 0; i < V; i++) {
          const err = Math.abs(cpuCosts[i] - apiCosts[i]);
          maxCpuError = Math.max(maxCpuError, err);
          totalCpuError += err;
        }
        const cpuOk = maxCpuError === 0;

        const lines: string[] = [
          `Trees: ${V}, n=${internalN}, logic: ${selectedLogic}`,
        ];

        if (gpuCosts) {
          let maxGpuError = 0, totalGpuError = 0;
          for (let i = 0; i < V; i++) {
            const err = Math.abs(gpuCosts[i] - apiCosts[i]);
            maxGpuError = Math.max(maxGpuError, err);
            totalGpuError += err;
          }
          const gpuOk = maxGpuError === 0;
          lines.push(`GPU vs API: ${gpuOk ? 'PASS' : 'FAIL'} (max err=${maxGpuError}, avg err=${(totalGpuError / V).toFixed(4)})`);
          lines.push(`GPU costs: ${gpuCosts.slice(0, 5).join(', ')}${V > 5 ? '...' : ''}`);
        }
        lines.push(`CPU vs API: ${cpuOk ? 'PASS' : 'FAIL'} (max err=${maxCpuError}, avg err=${(totalCpuError / V).toFixed(4)})`);
        lines.push(`Params: bias=${params.bias} w=${params.leftWeight} rd=${params.rightDiv} c=${params.coupling} d=${params.denom}`);
        lines.push(`CPU costs: ${cpuCosts.slice(0, 5).join(', ')}${V > 5 ? '...' : ''}`);
        lines.push(`API costs: ${apiCosts.slice(0, 5).join(', ')}${V > 5 ? '...' : ''}`);
        if (!gpuCosts) lines.push(`(GPU path failed — CPU result shown)`);
        setCalResult(lines.join('\n'));
      }
    })();

    return () => { cancelled = true; };
  }, [calMode, webgpuAvailable, lattice, costLandscape, n, selectedLogic]);

  // ── Render ─────────────────────────────────────────────────────────

  return (
    <div className="flex h-full w-full">
      <div className="flex-1 relative">
        <div ref={containerRef} className="absolute inset-0" />

        {/* Decay chart overlay */}
        {calMode === 'decay' && (
          <canvas ref={calCanvasRef}
            className="absolute bottom-4 right-4 w-80 h-52 rounded-lg pointer-events-none"
            style={{ background: 'rgba(10,10,30,0.88)', border: '1px solid rgba(100,130,180,0.3)' }}
          />
        )}

        {/* Bench/Phi calibration result */}
        {(calMode === 'bench' || calMode === 'phi') && (
          <div className="absolute bottom-4 right-4 w-96 max-h-64 rounded-lg overflow-auto p-3 font-mono text-xs"
            style={{ background: 'rgba(10,10,30,0.92)', border: '1px solid rgba(100,130,180,0.3)' }}
          >
            {calError && <div className="text-red-400 whitespace-pre-wrap">{calError}</div>}
            {calResult && <div className="text-green-400 whitespace-pre-wrap">{calResult}</div>}
            {!calError && !calResult && <div className="text-slate-400">Running calibration...</div>}
          </div>
        )}

        {/* Survey stats overlay */}
        {calMode === 'survey' && (
          <div className="absolute bottom-4 right-4 w-64 rounded-lg p-3 font-mono text-xs"
            style={{ background: 'rgba(10,10,30,0.92)', border: '1px solid rgba(100,130,180,0.3)' }}
          >
            <div className="text-green-400 mb-1">Streaming Survey — {selectedLogic}</div>
            <div className="text-slate-300">
              wander: <span className="text-green-300">{surveyStats.free}</span>{' '}
              stuck: <span className="text-yellow-300">{surveyStats.stuck}</span>{' '}
              knots: <span className="text-pink-400">{surveyStats.knots}</span>
            </div>
            <div className="text-slate-400">hops: {surveyStats.totalHops}</div>
            <div className="text-slate-400 mt-1">
              budget: {antiInertiaBudget} | {N_SURVEY_PARTICLES} particles
            </div>
            <div className="mt-1 flex gap-2">
              <button onClick={() => setSurveySweepActive(v => !v)}
                className={`px-2 py-0.5 rounded text-xs ${surveySweepActive ? 'bg-green-700 text-green-200' : 'bg-slate-700 text-slate-300'}`}>
                {surveySweepActive ? 'Sweeping...' : 'Sweep all logics'}
              </button>
            </div>
          </div>
        )}

        {/* Controls overlay */}
        <div className="absolute top-4 left-4 bg-slate-900/80 backdrop-blur rounded-lg p-3 text-white text-sm space-y-2 max-w-xs">
          <div className="flex items-center gap-2">
            <label className="text-slate-300">Size n:</label>
            <select value={n} onChange={e => setN(Number(e.target.value))}
              className="bg-slate-700 text-white rounded px-2 py-1 text-sm">
              {[0, 1, 2, 3, 4, 5, 6, 7].map(v => (
                <option key={v} value={v}>T{v} ({[1, 1, 2, 5, 14, 42, 132, 429][v]} trees)</option>
              ))}
            </select>
          </div>

          <div className="flex items-center gap-2">
            <label className="text-slate-300 text-xs">Logic:</label>
            <select value={selectedLogic} onChange={e => setSelectedLogic(e.target.value)}
              className="bg-slate-700 text-white rounded px-2 py-1 text-xs max-w-[140px]">
              {LOGIC_TYPES.map(lt => (
                <option key={lt} value={lt}>{LOGIC_LABELS[lt] || lt}</option>
              ))}
            </select>
          </div>

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

          {/* Anti-inertia budget slider */}
          <div className="flex items-center gap-2 text-xs">
            <label className="text-slate-300 whitespace-nowrap">Budget:</label>
            <input type="range" min={0} max={200} value={antiInertiaBudget}
              onChange={e => setAntiInertiaBudget(Number(e.target.value))}
              className="flex-1 accent-pink-500" />
            <span className="text-slate-300 w-8 text-right">{antiInertiaBudget}</span>
          </div>

          {/* Calibration mode */}
          <div className="flex items-center gap-2 text-xs">
            <label className="text-slate-300">Cal:</label>
            <select value={calMode} onChange={e => setCalMode(e.target.value as CalMode)}
              className="bg-slate-700 text-white rounded px-1 py-0.5 text-xs">
              <option value="off">Off</option>
              <option value="decay">Decay</option>
              <option value="bench">Bench (GPU)</option>
              <option value="phi">Phi (GPU)</option>
              <option value="survey">Survey</option>
            </select>
          </div>

          {loading && <div className="text-yellow-400">Loading...</div>}
          {error && <div className="text-red-400">{error}</div>}
          <div className="flex items-center gap-2 text-xs">
            <span className={`w-2 h-2 rounded-full ${webgpuAvailable ? 'bg-green-500' : 'bg-yellow-500'}`} />
            <span className="text-slate-400">{webgpuAvailable ? 'WebGPU (compute shaders)' : 'WebGL (fallback)'}</span>
          </div>
          {lattice && <div className="text-slate-400 text-xs">{lattice.vertex_count} vertices, {lattice.edge_count} edges</div>}

          {/* Lean certificate */}
          <div className="text-xs">
            <button onClick={handleLeanVerify} disabled={leanVerifying}
              className="px-2 py-1 rounded text-xs bg-slate-700 hover:bg-slate-600 disabled:opacity-50">
              {leanVerifying ? 'Verifying...' : 'Verify Lean'}
            </button>
            {leanResult && (
              <div className={`mt-1 ${leanResult.passed ? 'text-green-400' : 'text-red-400'}`}>
                {leanResult.summary}
                {leanResult.passed && (
                  <span className="ml-1 text-green-500">✓ ({leanResult.target_count} targets)</span>
                )}
              </div>
            )}
          </div>
        </div>

        <div className="absolute bottom-4 left-4 bg-slate-900/80 backdrop-blur rounded-lg p-3 text-white text-xs space-y-1">
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#4488ff' }} /><span>Regular tree</span></div>
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#44ff88' }} /><span>rightComb (equilibrium)</span></div>
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#ff4444' }} /><span>leftComb (maximum)</span></div>
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: showCost ? '#ffaa00' : '#4488ff' }} /><span>Cost height → yellow</span></div>
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#ff44ff' }} /><span>Contraction path</span></div>
          {showAntiInertia && <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#ff66aa' }} /><span>Anti-inertia (Φ gradient)</span></div>}
          {calMode === 'survey' && (
            <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#88ff88' }} /><span>Particle</span>
              <span className="w-3 h-3 rounded-full ml-2" style={{ background: '#ff4488' }} /><span>Knot</span></div>
          )}
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
                <button onClick={() => { setAnimatePath(true); setAnimProgress(0); }}
                  className="mt-2 px-3 py-1 bg-purple-600 hover:bg-purple-500 rounded text-xs">
                  Animate NA→NC Transition
                </button>
                {animProgress > 0 && (
                  <div className="mt-2">
                    <div className="w-full bg-slate-700 rounded-full h-2">
                      <div className="bg-purple-500 h-2 rounded-full transition-all duration-300" style={{ width: `${animProgress * 100}%` }} />
                    </div>
                    <div className="text-slate-400 mt-1">step {pathStepRef.current} / {contractionPath.vertices.length - 1}</div>
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

          {calMode === 'survey' && (
            <div className="mb-4 p-3 bg-slate-800 rounded-lg">
              <h3 className="text-sm font-medium text-slate-300 mb-2">Streaming Survey</h3>
              <div className="text-xs space-y-1">
                <div className="text-slate-400">
                  Particles wander the lattice, consuming anti-inertia budget (Φ gradient) to traverse edges.
                  When budget runs out, they get <span className="text-pink-400">stuck</span> — forming
                  a <span className="text-pink-400">knot</span> in spacetime.
                </div>
                <div className="mt-2 space-y-1">
                  <div className="flex justify-between text-slate-400">
                    <span>Wandering (budget left)</span>
                    <span className="text-green-300">{surveyStats.free}</span>
                  </div>
                  <div className="flex justify-between text-slate-400">
                    <span>Stuck (budget exhausted)</span>
                    <span className="text-yellow-300">{surveyStats.stuck}</span>
                  </div>
                  <div className="flex justify-between text-slate-400">
                    <span>Knot vertices (stuck sites)</span>
                    <span className="text-pink-400">{surveyStats.knots}</span>
                  </div>
                  <div className="flex justify-between text-slate-400">
                    <span>Total hops</span>
                    <span>{surveyStats.totalHops}</span>
                  </div>
                  <div className="flex justify-between text-slate-400">
                    <span>Budget per particle</span>
                    <span>{antiInertiaBudget}</span>
                  </div>
                  <div className="flex justify-between text-slate-400">
                    <span>Particle count</span>
                    <span>{N_SURVEY_PARTICLES}</span>
                  </div>
                </div>
                <div className="mt-2 text-slate-500 italic">
                  Knots are self-sustaining configurations — the energetic atom of spacetime tensegrity.
                </div>
              </div>
            </div>
          )}

          {/* Find interesting (Lean-guided) */}
          <div className="mb-4 p-3 bg-slate-800 rounded-lg">
            <h3 className="text-sm font-medium text-slate-300 mb-2">Lean-Guided Discovery</h3>
            <div className="text-xs space-y-1">
              <button onClick={handleFindInteresting} disabled={interestingLoading || !lattice}
                className="px-3 py-1 bg-indigo-700 hover:bg-indigo-600 rounded text-xs disabled:opacity-50">
                {interestingLoading ? 'Searching...' : 'Find Interesting Trees'}
              </button>
              {interestingVertices && interestingVertices.length > 0 && (
                <div className="mt-2 space-y-1">
                  <div className="text-slate-400">Top meta-stable candidates:</div>
                  {interestingVertices.map((v: any) => (
                    <button key={v.id} onClick={() => {
                      const tv = lattice?.vertices[v.id];
                      if (tv) handleVertexClick(tv);
                    }}
                      className={`w-full text-left px-2 py-0.5 rounded text-xs font-mono block ${
                        selectedVertex?.id === v.id ? 'bg-indigo-600/30 text-indigo-300' : 'hover:bg-slate-700 text-slate-300'
                      }`}>
                      {treeShortLabel(v.repr)} <span className="text-slate-500">Φ={v.cost} var={v.cost_variance}</span>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>

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
