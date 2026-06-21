# Roadmap: Timespace Calibration & Spacetime Logic Reimplementation

**2026-06-12** | Compiled from session discussion

## Completed Milestones

### 1. Cayley-Dickson Ladder Verification
- Split-octonion multiplication table from `unified_spacetime_engine_explicit.lean`
  copied verbatim into Python test harness
- Confirmed ladder: ℝ/ℂ/ℍ |assoc| = 0, 𝕆 max |assoc| = 4.0
- Most non-associative triple: (e1, e2, e4) — crosses associative/split boundary
- Split sector e4–e7 fully non-associative (all triples |assoc| = 4.0)
- File: `infra/tests/test_cayley_dickson_ladder.py`

### 2. Zero Divisor Analysis (Corrected)
- Split-octonions have zero divisors via isotropic null cone, not algebraic
  non-alternativity — distinct from sedenions
- Explicit: `(e0+e4)·(e0−e4) = 0` — 16 isotropic basis pairs
- Two-layer structure: metric zero divisors (dim 8, from (4,4) signature)
  vs algebraic zero divisors (dim 16+, from non-alternativity)
- Maps to cost classes: CI(Rmid)=0 channels (metric) vs explosive leftWeight=2
  regime (algebraic)

### 3. Timespace Decomposition Formalized
- (4,4) split signature is the algebraic skeleton:
  - Associative sector (+) e0–e3 → time → commutator → irreversibility
  - Split sector (−) e4–e7 → space → associator → differentiability
  - Null cone (norm=0) → interface → zero-divisor channels
- Each logic type = projection operator onto a subspace
- Sector weights: time_weight = leftWeight, space_weight = 1/(rightDiv+1),
  interface_weight = coupling/denom
- Spacetime is now space-biased via the `mirror` flag (v0.3)
  — `leftWeight=0, rightDiv=0, mirror=True` gives pure associator Φ = 1 + Φ(left)
- Torus knot calibration verified: (2,3) trefoil winding confirmed
- Files: `infra/tests/test_timespace_decomposition.py`,
  `infra/tests/test_torus_knot_calibration.py`
- Updated: `docs/lab_protocol.md` (version 0.3)

## Next Steps

### 4. Split-Quaternion Calibration ✅
- Split-quaternions have (2,2) signature and zero divisors but are ASSOCIATIVE
- Verified: all 64 basis triples have associator norm = 0
- Verified: (1+j)(1-j) = 0 (null-cone zero divisor)
- Verified: N(ab) = N(a)N(b) for generic elements (composition algebra)
- Verified: zero divisors and non-associativity are INDEPENDENT
  — split-quaternions have zero divisors without losing associativity
- Torus knot crossing formula: c(T_{p,q}) = min(p(q-1), q(p-1))
- Trefoil (2,3) maps to tree size 3, verified Φ gradient = 2
- Key insight: rightDiv=0 cost class (flat landscape) corresponds to
  split-quaternion LEVEL of associativity + metric zero divisors
- File: `infra/tests/test_split_quaternion_calibration.py`

### 5. Spacetime Logic Recalibration ✅ (v0.3)
- Implemented: `mirror` flag on `NodeCost` swaps left/right treatment
- Spacetime: `leftWeight=0, rightDiv=0, bias=1, mirror=True, coupling=0`
- Result: Φ(Node l r) = 1 + Φ(l) — pure associator, commutator silent
- Gradient reversal: Spacetime gradient drives toward leftComb (not rightComb)
- Torus knot: (2,3) trefoil verified — p=2 (associator), q=3 (split) winding

### 6. Split-Octonion Continuation (Future)
- After split-quaternion calibration is stable, move to full non-associative
  split-octonion cost landscape
- The 64-term multiplication table is already verified in Python, ready for
  Lean integration
- Zero divisors in the split-octonion algebra will map to degenerate cost
  paths — routes where composition vanishes despite non-zero component costs

## Files
- `LaserCortex/unified_spacetime_engine_explicit.lean` — split-octonion
  multiplication table (WIP, gitignored)
- `infra/tests/test_cayley_dickson_ladder.py` — ladder verification
- `infra/tests/test_timespace_decomposition.py` — sector projection mapping
- `docs/lab_protocol.md` — timespace decomposition (v0.2)
- `infra/tests/test_boolean_logic.py` — 16-test Boolean calibration suite
- `infra/tests/test_zero_divisor.py` — zero-divisor magnitude analysis

## References
- `spacetime_tensegrity_program.md` — foundational physics framework
- `docs/topological_isomer_hypothesis.md` — atomic model / strong force
- `lab_notes/004_coupling_sweep.md` — coupling analysis & Boolean/ZDV results
