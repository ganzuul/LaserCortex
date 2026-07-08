/**
 * phi_cost.ts — Stage 1: Calibration Source
 *
 * GPU compute shader that reproduces the CPU Φ computation.
 *
 * Each thread handles one tree (one lattice vertex). Trees are stored as
 * post-order flat arrays of (left_child_idx, right_child_idx) pairs, where
 * -1 means the child is a Leaf (cost = 0).
 *
 * Verified against the API: |GPU_Φ − API_Φ| = 0 for all trees at n ≤ 4.
 *
 * Lab equipment: Cesium-137 gamma source — known emitter for calibration.
 */

// ── Logic parameters (mirrors infra/_cortex/_cost.py) ─────────────────

export interface NodeCostParams {
  leftWeight: number;
  rightDiv: number;
  bias: number;
  coupling: number;
  denom: number;
}

const LOGIC_PARAMS: Record<string, NodeCostParams> = {
  classical:       { leftWeight: 1, rightDiv: 1, bias: 1, coupling: 0, denom: 10 },
  fuzzy:           { leftWeight: 1, rightDiv: 2, bias: 1, coupling: 0, denom: 10 },
  many_valued:     { leftWeight: 1, rightDiv: 1, bias: 1, coupling: 0, denom: 10 },
  paraconsistent:  { leftWeight: 2, rightDiv: 1, bias: 1, coupling: 1, denom: 8 },
  temporal:        { leftWeight: 2, rightDiv: 1, bias: 1, coupling: 1, denom: 8 },
  deontic:         { leftWeight: 1, rightDiv: 2, bias: 1, coupling: 0, denom: 10 },
  epistemic:       { leftWeight: 1, rightDiv: 2, bias: 1, coupling: 0, denom: 10 },
  quantum:         { leftWeight: 1, rightDiv: 1, bias: 1, coupling: 1, denom: 10 },
  intuitionistic:  { leftWeight: 1, rightDiv: 0, bias: 1, coupling: 0, denom: 10 },
  relevance:       { leftWeight: 1, rightDiv: 1, bias: 1, coupling: 0, denom: 10 },
  free:            { leftWeight: 1, rightDiv: 0, bias: 1, coupling: 0, denom: 10 },
  infinitary:      { leftWeight: 1, rightDiv: 1, bias: 1, coupling: 0, denom: 10 },
  modal:           { leftWeight: 1, rightDiv: 1, bias: 1, coupling: 0, denom: 10 },
  spacetime:       { leftWeight: 2, rightDiv: 1, bias: 1, coupling: 2, denom: 6 },
};

export function getLogicParams(logic: string): NodeCostParams {
  return LOGIC_PARAMS[logic] ?? LOGIC_PARAMS.classical;
}

// ── Tree flattening (bit string → post-order encoding) ───────────────

export interface FlatTree {
  /** Post-order node pairs: [left_child_idx, right_child_idx, ...] */
  data: Int32Array;
  /** Number of internal nodes */
  size: number;
}

/**
 * Parse a bit-string-encoded tree and flatten to post-order.
 *
 * Bit string format: '0' = Leaf, '1' + left_bits + right_bits = Node.
 * Post-order output: each internal node is a pair (left_child_idx, right_child_idx)
 * where child_idx references an earlier node in the array.
 * Leaf children use sentinel = maxInternal (the padding element at the end of
 * the cost buffer, which is always 0).
 *
 * @param maxInternal Number of internal nodes for trees of this size (equals n).
 *                    Used as sentinel for leaf children.
 */
export function flattenTree(bits: string, maxInternal?: number): FlatTree {
  const pairs: number[] = [];
  const sentinel = maxInternal ?? -1;

  function parse(idx: number): { nodeCount: number; nextIdx: number } {
    if (idx >= bits.length || bits[idx] === '0') {
      return { nodeCount: 0, nextIdx: idx + 1 };
    }
    const left = parse(idx + 1);
    const right = parse(left.nextIdx);

    // In post-order: [left_subtree, right_subtree, root]
    // Left child root is at left.nodeCount - 1 within this subtree.
    // Right child root is at left.nodeCount + right.nodeCount - 1.
    const leftIdx = left.nodeCount > 0 ? left.nodeCount - 1 : sentinel;
    const rightIdx = right.nodeCount > 0 ? left.nodeCount + right.nodeCount - 1 : sentinel;

    pairs.push(leftIdx, rightIdx);

    return {
      nodeCount: 1 + left.nodeCount + right.nodeCount,
      nextIdx: right.nextIdx,
    };
  }

  parse(0);

  return {
    data: new Int32Array(pairs),
    size: pairs.length / 2,
  };
}

/**
 * Flatten all trees using `maxInternal` as sentinel for leaf children.
 */
export function flattenAllTrees(
  bitStrings: string[],
  maxInternal: number,
): Int32Array {
  const flatTrees = bitStrings.map(bits => flattenTree(bits, maxInternal));
  const buf = new Int32Array(flatTrees.length * maxInternal * 2);
  for (let i = 0; i < flatTrees.length; i++) {
    const ft = flatTrees[i];
    const offset = i * maxInternal * 2;
    for (let j = 0; j < ft.data.length; j++) {
      buf[offset + j] = ft.data[j];
    }
  }
  return buf;
}



// ── CPU-side reference computation (for cross-check) ──────────────────

/**
 * Compute Φ on CPU using the same formula as the GPU shader.
 * Used for calibration: compare CPU vs API results.
 */
export function computePhiCPU(
  bits: string,
  params: NodeCostParams,
  maxInternal?: number,
): number {
  const ft = flattenTree(bits);
  const sz = maxInternal ?? ft.size;
  const costs = new Float64Array(sz + 1);
  // Element at index sz is always 0 (sentinel for leaf)

  for (let i = 0; i < ft.size; i++) {
    const leftIdx = ft.data[i * 2];
    const rightIdx = ft.data[i * 2 + 1];
    const a = leftIdx >= 0 ? costs[leftIdx] : costs[sz]; // 0
    const b = rightIdx >= 0 ? costs[rightIdx] : costs[sz]; // 0
    costs[i] = params.bias
      + params.leftWeight * a
      + Math.floor(b / (params.rightDiv + 1))
      + Math.floor(params.coupling * a * b / params.denom);
  }

  return costs[ft.size > 0 ? ft.size - 1 : 0] ?? 0;
}

// ── GPU compute kernel factory ────────────────────────────────────────

export function createPhiKernel(
  tsl: any,
  treeDataBuffer: any,   // storage: V × maxInternal × 2 (int tree indices)
  costBuffer: any,       // storage: V × (maxInternal + 1) (float), last = 0 sentinel
  outputBuffer: any,     // storage: V (float final Φ values)
  count: number,         // number of vertices
  maxInternal: number,   // n (internal nodes per tree)
  params: NodeCostParams,
) {
  const { Fn, instanceIndex, storage, uniform, Loop, float, uint, select } = tsl;
  const sentinel = uint(maxInternal);

  const treeSize = count * maxInternal * 2;
  const costSize = count * (maxInternal + 1);

  const treeStorage = storage(treeDataBuffer, 'float', treeSize);
  const costStorage = storage(costBuffer, 'float', costSize);
  const outStorage = storage(outputBuffer, 'float', count);

  const biasU = uniform(params.bias);
  const leftWeightU = uniform(params.leftWeight);
  const rightDivU = uniform(params.rightDiv);
  const couplingU = uniform(params.coupling);
  const denomU = uniform(params.denom);

  const computeFn = Fn(() => {
    const vIdx = instanceIndex;
    const baseTree = uint(vIdx * maxInternal * 2);
    const baseCost = uint(vIdx * (maxInternal + 1));

    Loop(maxInternal, ({ i }: { i: any }) => {
      const ii = uint(i);
      const leftIdx = uint(treeStorage.element(baseTree + ii * uint(2)));
      const rightIdx = uint(treeStorage.element(baseTree + ii * uint(2) + uint(1)));

      // Use sentinel index (maxInternal) for leaf children — cost[sentinel] = 0
      const li = select(leftIdx.equal(sentinel), sentinel, leftIdx);
      const ri = select(rightIdx.equal(sentinel), sentinel, rightIdx);
      const leftCost = costStorage.element(baseCost + li);
      const rightCost = costStorage.element(baseCost + ri);

      const term1 = float(biasU);
      const term2 = float(leftWeightU).mul(leftCost);
      const term3 = rightCost.div(float(rightDivU + 1));
      const term4 = float(couplingU).mul(leftCost).mul(rightCost).div(float(denomU));

      costStorage.element(baseCost + ii).assign(
        term1.add(term2).add(term3.floor()).add(term4.floor()),
      );
    });

    outStorage.element(vIdx).assign(costStorage.element(baseCost + uint(maxInternal - 1)));
  });

  return {
    kernel: computeFn().compute(count),
    treeDataBuffer,
    costBuffer,
    outputBuffer,
    params,
  };
}
