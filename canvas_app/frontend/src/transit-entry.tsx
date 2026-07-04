/**
 * Standalone entry point for the CD Tower Transit Map.
 * Mounted at /transit.html — opens in a separate window.
 *
 * Renders a three-line transit map of the Tamari lattice
 * showing CD tower islands at different Cayley-Dickson levels:
 *   SplitComplex (Red, cd=0)
 *   SplitQuat    (Blue, cd=1)
 *   SplitOctonion (Green, cd=3)
 */
import React, { useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom/client';
import * as d3 from 'd3';
import { tubeMap } from 'd3-tube-map';

// ═══════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════

interface StationData {
  label: string;
  size: number;
  y: number;
}

interface TransitNode {
  coords: [number, number];
  name?: string;
  labelPos?: string;
}

interface TransitLine {
  name: string;
  color: string;
  shiftCoords: [number, number];
  nodes: TransitNode[];
}

interface TransitData {
  stations: Record<string, StationData>;
  lines: TransitLine[];
}

// ═══════════════════════════════════════════════════════════════════════
// Legend component
// ═══════════════════════════════════════════════════════════════════════

const CD_LINES = [
  { color: '#e6194b', label: 'SplitComplex  (cd=0)' },
  { color: '#3b75af', label: 'SplitQuat     (cd=1)' },
  { color: '#44aa44', label: 'SplitOctonion (cd=3)' },
];

const Legend: React.FC = () => (
  <div style={{
    position: 'absolute',
    top: 16,
    left: 16,
    background: 'rgba(26, 26, 46, 0.85)',
    border: '1px solid rgba(255,255,255,0.15)',
    borderRadius: 8,
    padding: '12px 18px',
    color: '#ccc',
    fontFamily: 'monospace',
    fontSize: 13,
    zIndex: 10,
  }}>
    <div style={{ marginBottom: 8, fontWeight: 'bold', color: '#eee', fontSize: 14 }}>
      CD Tower Islands
    </div>
    {CD_LINES.map((l, i) => (
      <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
        <div style={{
          width: 24,
          height: 3,
          background: l.color,
          borderRadius: 2,
        }} />
        <span>{l.label}</span>
      </div>
    ))}
    <div style={{
      marginTop: 10,
      paddingTop: 8,
      borderTop: '1px solid rgba(255,255,255,0.1)',
      fontSize: 11,
      color: '#888',
    }}>
      Station labels: EMLTree repr
      <br />
      Interchange = same tree at multiple CD levels
    </div>
  </div>
);

// ═══════════════════════════════════════════════════════════════════════
// Main Transit Map component
// ═══════════════════════════════════════════════════════════════════════

const TransitMap: React.FC = () => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [data, setData] = useState<TransitData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [dimensions, setDimensions] = useState({ width: 1200, height: 700 });

  // Fetch data
  useEffect(() => {
    fetch('/transit_map.json')
      .then(res => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((json: TransitData) => {
        setData(json);
        // Auto-size: lines × 200 height, stations × 40 width
        const nStations = json.lines[0]?.nodes.length ?? 22;
        const w = Math.max(1200, nStations * 45 + 200);
        const h = Math.max(500, 200);
        setDimensions({ width: w, height: h });
      })
      .catch(err => setError(err.message));
  }, []);

  // Render d3-tube-map
  useEffect(() => {
    if (!data || !containerRef.current) return;

    const container = d3.select(containerRef.current);

    // Clear previous render
    container.selectAll('svg').remove();

    const { width, height } = dimensions;

    const margin = {
      top: 40,
      right: width / 5,
      bottom: 40,
      left: width / 8,
    };

    const map = tubeMap()
      .width(width)
      .height(height)
      .margin(margin);

    container.datum(data).call(map);

    // After the map is rendered, add connectome edge annotations
    // We'll do this in a future iteration

  }, [data, dimensions]);

  if (error) {
    return (
      <div style={{ color: '#ff6b6b', padding: 40, fontFamily: 'monospace' }}>
        Error loading transit map: {error}
        <br />
        Make sure <code>transit_map.json</code> is in the <code>public/</code> directory.
      </div>
    );
  }

  return (
    <div style={{
      width: '100vw',
      height: '100vh',
      background: '#1a1a2e',
      position: 'relative',
      overflow: 'auto',
    }}>
      <Legend />
      <div
        ref={containerRef}
        style={{
          width: dimensions.width,
          height: dimensions.height,
          margin: '0 auto',
        }}
      />
      {!data && (
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          color: '#888',
          fontFamily: 'monospace',
        }}>
          Loading transit map data...
        </div>
      )}
    </div>
  );
};

// ═══════════════════════════════════════════════════════════════════════
// Mount
// ═══════════════════════════════════════════════════════════════════════

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <TransitMap />
  </React.StrictMode>,
);
