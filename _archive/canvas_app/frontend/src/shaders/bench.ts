/**
 * bench.ts — Stage 0: Lab Bench
 *
 * Minimal WebGPU compute shader that verifies the pipeline is operational.
 * Each thread writes `index * 2.0` to an output buffer.
 *
 * Lab equipment: Bench power supply + multimeter + oscilloscope.
 * Verification: readback[0] === 0.0, readback[1] === 2.0, readback[2] === 4.0
 */

export function createBenchKernel(
  tsl: any,
  outputBuffer: any,
  count: number,
) {
  const { Fn, instanceIndex, storage, float } = tsl;
  const buf = storage(outputBuffer, 'float', count);
  const computeFn = Fn(() => {
    const idx = instanceIndex;
    buf.element(idx).assign(float(idx).mul(2.0));
  });
  return {
    kernel: computeFn().compute(count),
    outputBuffer,
    verify(readback: Float32Array): boolean {
      for (let i = 0; i < Math.min(count, readback.length); i++) {
        if (Math.abs(readback[i] - i * 2.0) > 0.001) return false;
      }
      return true;
    },
  };
}
