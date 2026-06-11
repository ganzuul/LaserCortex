/**
 * Tamari Lattice API client.
 *
 * Endpoints:
 *   GET /api/tamari/lattice/{n}          — lattice graph (vertices + edges)
 *   GET /api/tamari/tree/{bits}          — single tree layout
 *   POST /api/tamari/path                — shortest contraction path
 *   GET /api/tamari/path-to-rightcomb/{bits} — path to equilibrium
 *   GET /api/tamari/cost-lattice/{n}/{logic} — lattice with Φ costs
 *   GET /api/tamari/cost-landscape/{n}   — full cost matrix for all logics
 */

const API_BASE = '/api/tamari';

export interface Point3D {
  x: number;
  y: number;
  z: number;
}

export interface TamariVertex {
  id: number;
  bits: string;
  repr: string;
  coord: Point3D;
  is_left_comb: boolean;
  is_right_comb: boolean;
  size: number;
  costs?: Record<string, number>;
}

export interface TamariEdge {
  source: number;
  target: number;
  cross_impacts?: Record<string, number>;
}

export interface TamariLattice {
  n: number;
  vertex_count: number;
  edge_count: number;
  vertices: TamariVertex[];
  edges: TamariEdge[];
}

export interface CostLattice {
  n: number;
  vertex_count: number;
  edge_count: number;
  logic_type: string;
  vertices: TamariVertex[];
  edges: TamariEdge[];
}

export interface CostLandscape {
  n: number;
  logic_types: string[];
  vertices: TamariVertex[];
}

export interface TamariPath {
  source: number;
  target: number;
  vertices: number[];
  length: number;
}

async function fetchJson<T>(url: string, options?: RequestInit): Promise<T> {
  const res = await fetch(url, options);
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(err.detail || `HTTP ${res.status}`);
  }
  return res.json();
}

export const tamariApi = {
  getLattice: (n: number): Promise<TamariLattice> =>
    fetchJson(`${API_BASE}/lattice/${n}`),

  getTreeLayout: (bits: string): Promise<any> =>
    fetchJson(`${API_BASE}/tree/${encodeURIComponent(bits)}`),

  findPath: (sourceBits: string, targetBits: string): Promise<TamariPath> =>
    fetchJson(`${API_BASE}/path`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ source_bits: sourceBits, target_bits: targetBits }),
    }),

  findPathToEquilibrium: (bits: string): Promise<TamariPath> =>
    fetchJson(`${API_BASE}/path-to-rightcomb/${encodeURIComponent(bits)}`),

  getCostLattice: (n: number, logic: string): Promise<CostLattice> =>
    fetchJson(`${API_BASE}/cost-lattice/${n}/${logic}`),

  getCostLandscape: (n: number): Promise<CostLandscape> =>
    fetchJson(`${API_BASE}/cost-landscape/${n}`),
};

// Type re-exports for backward compatibility
export type { TamariLattice as TamariLatticeType, TamariPath as TamariPathType };
