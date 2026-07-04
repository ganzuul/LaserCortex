import React, { useEffect, useRef } from 'react';
import * as d3 from 'd3';

interface OctolinearNode {
  id: string;
  label: string;
  x: number;
  y: number;
  size: number;
  lw: number;
  rw: number;
}

interface OctolinearEdge {
  from: string;
  to: string;
  angle: '90' | '45';
}

interface OctolinearLatticeProps {
  data: {
    nodes: OctolinearNode[];
    edges: OctolinearEdge[];
    cd: number;
    stats: any;
  };
  width?: number;
  height?: number;
}

export const OctolinearLattice: React.FC<OctolinearLatticeProps> = ({
  data,
  width = 1000,
  height = 700,
}) => {
  const svgRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (!svgRef.current || !data) return;

    // Clear previous render
    d3.select(svgRef.current).selectAll('*').remove();

    const svg = d3.select(svgRef.current);
    const margin = { top: 40, right: 40, bottom: 40, left: 40 };
    const innerWidth = width - margin.left - margin.right;
    const innerHeight = height - margin.top - margin.bottom;

    // Compute scales
    const xExtent = d3.extent(data.nodes, d => d.x) as [number, number];
    const yExtent = d3.extent(data.nodes, d => d.y) as [number, number];

    // Add padding
    const xPadding = (xExtent[1] - xExtent[0]) * 0.1 || 1;
    const yPadding = (yExtent[1] - yExtent[0]) * 0.1 || 1;

    const xScale = d3.scaleLinear()
      .domain([xExtent[0] - xPadding, xExtent[1] + xPadding])
      .range([0, innerWidth]);

    const yScale = d3.scaleLinear()
      .domain([yExtent[0] - yPadding, yExtent[1] + yPadding])
      .range([innerHeight, 0]); // Flip y-axis

    // Create main group
    const g = svg.append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`);

    // Draw grid lines
    const xTicks = d3.range(Math.floor(xExtent[0]), Math.ceil(xExtent[1]) + 1);
    const yTicks = d3.range(Math.floor(yExtent[0]), Math.ceil(yExtent[1]) + 1);

    g.append('g')
      .attr('class', 'grid-x')
      .selectAll('line')
      .data(xTicks)
      .enter()
      .append('line')
      .attr('x1', d => xScale(d))
      .attr('x2', d => xScale(d))
      .attr('y1', 0)
      .attr('y2', innerHeight)
      .attr('stroke', '#e0e0e0')
      .attr('stroke-width', 1);

    g.append('g')
      .attr('class', 'grid-y')
      .selectAll('line')
      .data(yTicks)
      .enter()
      .append('line')
      .attr('x1', 0)
      .attr('x2', innerWidth)
      .attr('y1', d => yScale(d))
      .attr('y2', d => yScale(d))
      .attr('stroke', '#e0e0e0')
      .attr('stroke-width', 1);

    // Draw edges
    const nodeMap = new Map(data.nodes.map(n => [n.id, n]));

    g.append('g')
      .attr('class', 'edges')
      .selectAll('line')
      .data(data.edges)
      .enter()
      .append('line')
      .attr('x1', d => xScale(nodeMap.get(d.from)!.x))
      .attr('y1', d => yScale(nodeMap.get(d.from)!.y))
      .attr('x2', d => xScale(nodeMap.get(d.to)!.x))
      .attr('y2', d => yScale(nodeMap.get(d.to)!.y))
      .attr('stroke', d => d.angle === '90' ? '#666' : '#c62828')
      .attr('stroke-width', d => d.angle === '90' ? 1.5 : 2)
      .attr('stroke-dasharray', d => d.angle === '45' ? '5,5' : null)
      .attr('marker-end', 'url(#arrowhead)');

    // Draw arrowhead marker
    svg.append('defs')
      .append('marker')
      .attr('id', 'arrowhead')
      .attr('viewBox', '0 -5 10 10')
      .attr('refX', 8)
      .attr('refY', 0)
      .attr('markerWidth', 6)
      .attr('markerHeight', 6)
      .attr('orient', 'auto')
      .append('path')
      .attr('d', 'M0,-5L10,0L0,5')
      .attr('fill', '#666');

    // Draw nodes
    const nodeGroups = g.append('g')
      .attr('class', 'nodes')
      .selectAll('g')
      .data(data.nodes)
      .enter()
      .append('g')
      .attr('transform', d => `translate(${xScale(d.x)},${yScale(d.y)})`);

    nodeGroups.append('circle')
      .attr('r', 6)
      .attr('fill', d => {
        // Color by size
        const colors = ['#4caf50', '#2196f3', '#ff9800', '#f44336'];
        return colors[(d.size - 1) % colors.length];
      })
      .attr('stroke', '#333')
      .attr('stroke-width', 1.5);

    nodeGroups.append('text')
      .attr('x', 10)
      .attr('y', 4)
      .text(d => d.label)
      .attr('font-family', 'monospace')
      .attr('font-size', '10px')
      .attr('fill', '#333');

    // Add axes
    const xAxis = d3.axisBottom(xScale).ticks(xTicks.length);
    const yAxis = d3.axisLeft(yScale).ticks(yTicks.length);

    g.append('g')
      .attr('transform', `translate(0,${innerHeight})`)
      .call(xAxis);

    g.append('g')
      .call(yAxis);

    // Add axis labels
    g.append('text')
      .attr('x', innerWidth / 2)
      .attr('y', innerHeight + 35)
      .attr('text-anchor', 'middle')
      .attr('font-size', '12px')
      .text('x = size + assocDefect(cd)');

    g.append('text')
      .attr('transform', 'rotate(-90)')
      .attr('x', -innerHeight / 2)
      .attr('y', -30)
      .attr('text-anchor', 'middle')
      .attr('font-size', '12px')
      .text('y = leftWeight - rightWeight');

    // Add title
    svg.append('text')
      .attr('x', width / 2)
      .attr('y', 20)
      .attr('text-anchor', 'middle')
      .attr('font-size', '16px')
      .attr('font-weight', 'bold')
      .text(`Octolinear Tamari Lattice (CD=${data.cd})`);

    // Add legend
    const legend = svg.append('g')
      .attr('transform', `translate(${width - 150}, 50)`);

    legend.append('text')
      .attr('font-size', '12px')
      .attr('font-weight', 'bold')
      .text('Edge angles:');

    legend.append('line')
      .attr('x1', 0).attr('y1', 20)
      .attr('x2', 30).attr('y2', 20)
      .attr('stroke', '#666')
      .attr('stroke-width', 1.5);

    legend.append('text')
      .attr('x', 35).attr('y', 24)
      .attr('font-size', '11px')
      .text('90° (axis-aligned)');

    legend.append('line')
      .attr('x1', 0).attr('y1', 40)
      .attr('x2', 30).attr('y2', 40)
      .attr('stroke', '#c62828')
      .attr('stroke-width', 2)
      .attr('stroke-dasharray', '5,5');

    legend.append('text')
      .attr('x', 35).attr('y', 44)
      .attr('font-size', '11px')
      .text('45° (diagonal)');

  }, [data, width, height]);

  return (
    <svg
      ref={svgRef}
      width={width}
      height={height}
      style={{
        border: '1px solid #ccc',
        borderRadius: '4px',
        background: '#fafafa',
      }}
    />
  );
};
