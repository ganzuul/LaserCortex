import React, { useEffect, useRef } from 'react';
import * as d3 from 'd3';
import dagreD3 from 'dagre-d3';

interface TamariLatticeProps {
  data: {
    nodes: Array<{ id: string; label: string; rank: number }>;
    edges: Array<{ from: string; to: string }>;
  };
  width?: number;
  height?: number;
}

export const TamariLattice: React.FC<TamariLatticeProps> = ({
  data,
  width = 800,
  height = 600,
}) => {
  const svgRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (!svgRef.current || !data) return;

    // Clear previous render
    d3.select(svgRef.current).selectAll('*').remove();

    // Create a new directed graph
    const g = new dagreD3.graphlib.Graph()
      .setGraph({
        rankdir: 'BT', // Bottom to top (min at bottom, max at top)
        nodesep: 50,   // Horizontal separation between nodes
        edgesep: 20,   // Separation between edges
        ranksep: 80,   // Vertical separation between ranks
        marginx: 20,
        marginy: 20,
      })
      .setDefaultEdgeLabel(() => ({}));

    // Add nodes
    data.nodes.forEach((node) => {
      g.setNode(node.id, {
        label: node.label,
        labelStyle: 'font-family: monospace; font-size: 11px;',
        style: 'fill: #f0f0f0; stroke: #333; stroke-width: 1.5px;',
        rx: 4,
        ry: 4,
        padding: 8,
      });
    });

    // Add edges
    data.edges.forEach((edge) => {
      g.setEdge(edge.from, edge.to, {
        style: 'stroke: #666; stroke-width: 1.5px; fill: none;',
        arrowheadStyle: 'fill: #666; stroke: #666;',
        curve: d3.curveBasis,
      });
    });

    // Create the renderer
    const render = new dagreD3.render();

    // Set up an SVG group so that we can translate the entire graph
    const svg = d3.select(svgRef.current);
    const inner = svg.append('g');

    // Run the renderer
    render(inner as any, g as any);

    // Center the graph
    const graphObj = g.graph() as any;
    const graphWidth = graphObj.width || 0;
    const graphHeight = graphObj.height || 0;
    
    // Calculate scale to fit the graph
    const scaleX = width / (graphWidth + 40);
    const scaleY = height / (graphHeight + 40);
    const scale = Math.min(scaleX, scaleY, 1); // Don't scale up, only down
    
    const xOffset = (width - graphWidth * scale) / 2;
    const yOffset = (height - graphHeight * scale) / 2;

    inner.attr(
      'transform',
      `translate(${xOffset}, ${yOffset}) scale(${scale})`
    );

    // Set SVG dimensions
    svg.attr('width', width).attr('height', height);

    // Add zoom behavior
    const zoom = d3.zoom<SVGSVGElement, unknown>()
      .scaleExtent([0.3, 3])
      .on('zoom', (event) => {
        inner.attr('transform', event.transform);
      });

    svg.call(zoom);

    // Add node click handler for highlighting
    inner.selectAll('g.node').on('click', function () {
      const nodeId = d3.select(this).attr('id');
      
      // Reset all nodes
      inner.selectAll('g.node rect').style('fill', '#f0f0f0').style('stroke', '#333');
      inner.selectAll('g.edgePath path').style('stroke', '#666').style('stroke-width', '1.5px');
      
      // Highlight selected node
      d3.select(this).select('rect').style('fill', '#ffd700').style('stroke', '#ff8c00');
      
      // Highlight connected edges
      g.nodeEdges(nodeId)?.forEach((edge) => {
        inner
          .select(`#edge-${edge.v}-${edge.w}`)
          .select('path')
          .style('stroke', '#ff8c00')
          .style('stroke-width', '3px');
      });
    });

  }, [data, width, height]);

  return (
    <svg
      ref={svgRef}
      style={{
        border: '1px solid #ccc',
        borderRadius: '4px',
        background: '#fafafa',
      }}
    />
  );
};
