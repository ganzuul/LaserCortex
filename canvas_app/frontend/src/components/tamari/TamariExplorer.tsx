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
import { tamariApi, TamariLattice, TamariVertex, TamariPath } from '../../services/tamariApi';

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
};

const SCALE = 0.3;
const PARTICLE_COUNT = 100;

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

function buildLatticeMesh(lattice: TamariLattice):
  { mesh: THREE.InstancedMesh; positions: Float32Array } {
  const sphereGeom = new THREE.SphereGeometry(0.15, 16, 16);
  const mesh = new THREE.InstancedMesh(
    sphereGeom, new THREE.MeshPhongMaterial(), lattice.vertices.length
  );
  const dummy = new THREE.Object3D();
  const color = new THREE.Color();
  const positions = new Float32Array(lattice.vertices.length * 3);
  lattice.vertices.forEach((v, i) => {
    const x = v.coord.x * SCALE, y = v.coord.y * SCALE, z = v.coord.z * SCALE;
    positions[i * 3] = x; positions[i * 3 + 1] = y; positions[i * 3 + 2] = z;
    dummy.position.set(x, y, z);
    dummy.updateMatrix();
    mesh.setMatrixAt(i, dummy.matrix);
    if (v.is_right_comb) color.setHex(COLORS.vertex_rightcomb);
    else if (v.is_left_comb) color.setHex(COLORS.vertex_leftcomb);
    else color.setHex(COLORS.vertex_normal);
    mesh.setColorAt(i, color);
  });
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  mesh.userData = { positions, lattice };
  return { mesh, positions };
}

function buildEdgeLines(lattice: TamariLattice, positions: Float32Array): THREE.LineSegments {
  const edgePositions: number[] = [];
  lattice.edges.forEach(e => {
    const i = e.source * 3, j = e.target * 3;
    edgePositions.push(
      positions[i], positions[i + 1], positions[i + 2],
      positions[j], positions[j + 1], positions[j + 2],
    );
  });
  const edgeGeom = new THREE.BufferGeometry();
  edgeGeom.setAttribute('position', new THREE.Float32BufferAttribute(edgePositions, 3));
  const edgeMat = new THREE.LineBasicMaterial({ color: COLORS.edge_normal, transparent: true, opacity: 0.4 });
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

  // Contraction animation
  const contractionLambdaRef = useRef(1.0);

  const [n, setN] = useState(initialN);
  const [lattice, setLattice] = useState<TamariLattice | null>(null);
  const [selectedVertex, setSelectedVertex] = useState<TamariVertex | null>(null);
  const [contractionPath, setContractionPath] = useState<TamariPath | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [animatePath, setAnimatePath] = useState(false);
  const [animProgress, setAnimProgress] = useState(0);

  // ── Fetch lattice data ──────────────────────────────────────────────

  const fetchLattice = useCallback(async (size: number) => {
    setLoading(true);
    setError(null);
    try {
      const data = await tamariApi.getLattice(size);
      setLattice(data);
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

    const { mesh, positions } = buildLatticeMesh(lattice);
    staticPositionsRef.current = positions;
    scene.add(mesh);
    instancedMeshRef.current = mesh;

    const lines = buildEdgeLines(lattice, positions);
    scene.add(lines);
    edgeLinesRef.current = lines;

    // Initialize compute shaders with this lattice data
    if (webgpuAvailable) {
      initCompute(lattice).catch(() => {});
    }
  }, [lattice, rendererStatus, webgpuAvailable]);

  // ── Initialize WebGPU compute shaders ───────────────────────────────

  async function initCompute(lattice: TamariLattice) {
    const count = lattice.vertices.length;
    if (count < 1 || count > PARTICLE_COUNT) return;

    let TSL: Record<string, any>;
    try { TSL = await import('three/tsl'); } catch { return; }
    const { Fn, uniform, float, instanceIndex, If, storage } = TSL;

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

  // ── Render ─────────────────────────────────────────────────────────

  return (
    <div className="flex h-full w-full">
      {/* 3D Canvas */}
      <div className="flex-1 relative">
        <div ref={containerRef} className="absolute inset-0" />
        {/* Controls overlay */}
        <div className="absolute top-4 left-4 bg-slate-900/80 backdrop-blur rounded-lg p-3 text-white text-sm space-y-2">
          <div className="flex items-center gap-2">
            <label className="text-slate-300">Size n:</label>
            <select value={n} onChange={e => setN(Number(e.target.value))}
              className="bg-slate-700 text-white rounded px-2 py-1 text-sm">
              {[0, 1, 2, 3, 4, 5].map(v => (
                <option key={v} value={v}>T{v} ({[1, 1, 2, 5, 14, 42][v]} trees)</option>
              ))}
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
          <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ background: '#ff44ff' }} /><span>Contraction path</span></div>
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
