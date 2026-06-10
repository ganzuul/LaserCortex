/**
 * Cortex Bridge API client — the Reading Room.
 */
import type { SpecSummary, SpecDetail, CertificateInfo, BridgeState, InstantiateRequest, InstantiateResponse } from '../types/cortex';

const API_BASE = '/api/cortex';

async function fetchJson<T>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  });
  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: response.statusText }));
    throw new Error(error.detail || `Request failed: ${response.status}`);
  }
  return response.json();
}

export const cortexApi = {
  /** List all seed CortexSpecs. */
  listSpecs: (): Promise<SpecSummary[]> =>
    fetchJson(`${API_BASE}/specs`),

  /** Get full detail for a single spec. */
  getSpec: (name: string): Promise<SpecDetail> =>
    fetchJson(`${API_BASE}/specs/${encodeURIComponent(name)}`),

  /** List stored certificate keys. */
  listCertificates: (): Promise<string[]> =>
    fetchJson(`${API_BASE}/certificates`),

  /** Get certificate detail by key. */
  getCertificate: (key: string): Promise<CertificateInfo> =>
    fetchJson(`${API_BASE}/certificates/${encodeURIComponent(key)}`),

  /** Instantiate a spec (issue a writ). */
  instantiate: (req: InstantiateRequest): Promise<InstantiateResponse> =>
    fetchJson(`${API_BASE}/instantiate`, {
      method: 'POST',
      body: JSON.stringify(req),
    }),

  /** Snapshot of the bridge state. */
  getBridgeState: (): Promise<BridgeState> =>
    fetchJson(`${API_BASE}/bridge/state`),
};
