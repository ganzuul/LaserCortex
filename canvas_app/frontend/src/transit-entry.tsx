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

interface TransitRiverSegment {
  source: string;
  source_coords: [number, number];
  target: string;
  target_coords: [number, number];
  color: string;
  label: string;
}

interface TransitData {
  stations: Record<string, StationData>;
  lines: TransitLine[];
  rivers?: TransitRiverSegment[];
}

// ═══════════════════════════════════════════════════════════════════════
// Legend component
// ═══════════════════════════════════════════════════════════════════════

const CD_LINES = [
  { color: '#e6194b', label: 'SplitComplex  (cd=0)' },
  { color: '#3b75af', label: 'SplitQuat     (cd=1)' },
  { color: '#44aa44', label: 'SplitOctonion (cd=3)' },
];

const RIVER_LINES = [
  { color: '#ffa500', label: 'cd≤1 45° edges (leaf expansion)', dash: '3,2' },
  { color: '#ff69b4', label: 'cd=3 45° edges (leaf expansion)', dash: '3,2' },
  { color: '#88ccff', label: 'cd0→1 CD projection (same tree)', dash: '4,4' },
  { color: '#cc88ff', label: 'cd1→3 CD projection (same tree)', dash: '4,4' },
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
    {RIVER_LINES.map((l, i) => (
      <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
        <div style={{
          width: 24,
          height: 0,
          borderTop: `2.5px dashed ${l.color}`,
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
      Arcs = true 45° edges: leaf expansion at odd depth
      <br />
      (|Δx| = |Δy| = 1 in tubeCoord space). Within same CD.
      <br />
      Vertical dashes = CD projection (same tree, next CD).
      <br />
      Interchange = same tree at multiple CD levels.
      <br />
      Total: {RIVER_LINES.length} edge families
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

    // ── River overlay: two edge types ──
    //
    // (A) True 45° tropical edges (leaf expansion at balanced odd-depth).
    //     Within a single CD level (same y_base). Rendered as shallow arcs
    //     above/below the transit line to avoid visual overlap.
    //
    // (B) Cross-CD projection edges (same tree, different CD level).
    //     Vertical in this coordinate system. Rendered as dashed lines.
    //
    // d3-tube-map's built-in river only supports octolinear paths
    // (N/NE/E/SE/S/SW/W/NW), so we render rivers as a separate SVG overlay.
    if (data.rivers && data.rivers.length > 0) {
      const svg = container.select<SVGSVGElement>('svg');
      const gMap = svg.select<SVGGElement>(':first-child');

      // Replicate d3-tube-map's scale computation from data bounds
      const allX = data.lines.flatMap(l => l.nodes.map(n => n.coords[0]));
      const allY = data.lines.flatMap(l => l.nodes.map(n => n.coords[1]));
      const minX = Math.min(...allX) - 1;
      const maxX = Math.max(...allX) + 1;
      const minY = Math.min(...allY) - 1;
      const maxY = Math.max(...allY) + 1;

      const desiredAspectRatio = (maxX - minX) / (maxY - minY);
      const actualAspectRatio =
        (width - margin.left - margin.right) /
        (height - margin.top - margin.bottom);
      const ratioRatio = actualAspectRatio / desiredAspectRatio;

      let maxXRange: number, maxYRange: number;
      if (desiredAspectRatio > actualAspectRatio) {
        maxXRange = width - margin.left - margin.right;
        maxYRange = (height - margin.top - margin.bottom) * ratioRatio;
      } else {
        maxXRange = (width - margin.left - margin.right) / ratioRatio;
        maxYRange = height - margin.top - margin.bottom;
      }

      const xScale = d3.scaleLinear()
        .domain([minX, maxX])
        .range([margin.left, margin.left + maxXRange]);
      const yScale = d3.scaleLinear()
        .domain([minY, maxY])
        .range([margin.top + maxYRange, margin.top]);

      // Insert rivers group at start of gMap so it renders behind lines
      const riversGroup = gMap.insert('g', ':first-child')
        .attr('class', 'rivers');

      data.rivers.forEach(r => {
        const [sx, sy] = r.source_coords;
        const [tx, ty] = r.target_coords;
        const px1 = xScale(sx);
        const py1 = yScale(sy);
        const px2 = xScale(tx);
        const py2 = yScale(ty);

        if (sy === ty) {
          // (A) True 45° edge: within same CD level.
          // Render as a shallow quadratic Bezier arc above/below the line.
          const midX = (px1 + px2) / 2;
          const span = Math.abs(px2 - px1);
          // Arc height proportional to span, max 8px
          const arcH = Math.min(span * 0.04, 8);
          // Alternate above/below based on label NE/SE
          const arcDir = r.label.includes('NE') ? -1 : 1;
          const midY = (py1 + py2) / 2 + arcDir * arcH;
          riversGroup.append('path')
            .attr('d', `M${px1},${py1} Q${midX},${midY} ${px2},${py2}`)
            .attr('stroke', r.color)
            .attr('stroke-width', 1.8)
            .attr('stroke-opacity', 0.6)
            .attr('fill', 'none');
        } else {
          // (B) Cross-CD projection edge: vertical between CD levels.
          riversGroup.append('line')
            .attr('x1', px1)
            .attr('y1', py1)
            .attr('x2', px2)
            .attr('y2', py2)
            .attr('stroke', r.color)
            .attr('stroke-width', 1.5)
            .attr('stroke-opacity', 0.35)
            .attr('stroke-dasharray', '4,4')
            .attr('fill', 'none');
        }
      });
    }

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
