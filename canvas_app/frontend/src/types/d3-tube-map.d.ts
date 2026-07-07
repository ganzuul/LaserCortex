// Type declarations for d3-tube-map
// See https://github.com/johnwalley/d3-tube-map

declare module 'd3-tube-map' {
  import * as d3 from 'd3';

  interface TubeMapMargin {
    top: number;
    right: number;
    bottom: number;
    left: number;
  }

  interface TubeMapLine {
    name: string;
    color: string;
    shiftCoords: [number, number];
    nodes: Array<{
      coords: [number, number];
      name?: string;
      labelPos?: string;
    }>;
  }

  interface TubeMapRiverSegment {
    source: string;
    source_coords: [number, number];
    target: string;
    target_coords: [number, number];
    color: string;
    label: string;
  }

  interface TubeMapData {
    stations: Record<string, { label: string }>;
    lines: TubeMapLine[];
    rivers?: TubeMapRiverSegment[];
  }

  interface TubeMapGenerator {
    (selection: d3.Selection<any, any, any, any>): void;
    width(w: number): this;
    width(): number;
    height(h: number): this;
    height(): number;
    margin(m: TubeMapMargin): this;
    margin(): TubeMapMargin;
  }

  export function tubeMap(): TubeMapGenerator;
}
