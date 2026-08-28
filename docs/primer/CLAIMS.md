# Claims register — adversarial review substrate

*One row per substantive claim. Reviewers (human or LLM) adjudicate each row
independently; disagreements are the product. Machine-readable table: keep it
parseable when editing. Tags: [P] proven in Lean · [V] computed/verified ·
[H] hypothesis · [C] conjecture · [std] standard literature (no tag needed in
Part I, used in Part III for external-code claims).*

## How to read a row

- **Claim** — one sentence, no hedging. The hedge belongs in the chapter prose.
- **Basis** — for [P]: the Lean theorem name (grep-able). For [V]: the script
  and figure. For [H]/[C]: the confirmation/refutation sentence *or* "ABSENT".
- **Level** — for rows reusing a conventional term: literal / analogy / picture,
  per front-matter honesty-policy rule 3. "ABSENT" is a logged defect.
- **Verdict** — reviewer fills: ACCEPT · AMEND(tag/prose) · ESCALATE · VETO ·
  UNDECIDABLE.

## Register

### Chapter 1 — The problem

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 1.3.1 | 1.3 | The size-6 census shows CD≤2 mostly timelike, CD≥3 entirely spacelike | [V] | `metric_sweep.py`, `lightcone_census.png` | n/a | |
| 1.3.2 | 1.3 | A preferred direction is what axisymmetry *is*; the CD tower's phase diagram predicts when geometry is forced | [H] | present (1.3 §) | picture | |

### Chapter 2 — Conventional grounding

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 2.2.1 | 2.2 | Flux is conserved (frozen-in) in ideal MHD because ∇·B=0 and B is closed | [std] | — | source level | |
| 2.3.1 | 2.3 | Resistivity allows reconnection; flux dissipates | [std] | — | source level | |

### Chapter 3 — The substrate

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 3.1.1 | 3.1 | CD tower loses commutativity at ℍ, associativity at 𝕆, alternativity at 𝕊 | [std] | classical | — | |
| 3.2.1 | 3.2 | `frictionDensity k = commDefect k + strut_weight · assocDefect k` | [P-def] | `Friction.lean` def | — | |
| 3.3.1 | 3.3 | Γ₀..Γ₇ = 0,1,2,19,20,21,22,23; unique jump 2→19 | [P] | `gamma_increment`, `gamma_only_jump_at_cd2_3` | — | |
| 3.3.2 | 3.3 | CD 4 = sedenions = alternativity fails | [std/H] | classical for sedenions; *in our formalization: not yet proven to fail* | literal? | |
| 3.3.3 | 3.3 | Landauer unit ≈ 207.9 K; paraconsistency barrier 4159 K | [P-def] | `LogicalTemperature.lean` | analogy | |
| 3.4.1 | 3.4 | Antipode = grade involution / "time-reversal" on odd sector | [P-def] | `foundations/Algebra.lean` | analogy | |

### Chapter 4 — Handedness (exemplar)

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 4.3.1 | 4.3 | `(xx)y = x(xy)` for split-octonions | [P] | `left_alternative` | n/a | |
| 4.3.2 | 4.3 | `(xy)y = x(yy)` | [P] | `right_alternative` | n/a | |
| 4.3.3 | 4.3 | `[a,b,c] = −[b,a,c]` | [P] | `associator_antisymm_left` | n/a | |
| 4.3.4 | 4.3 | `strut_weight = \|[e₁,e₂,e₄]\| = 4` | [P] | `strut_weight_eq_four` | n/a | |
| 4.4.1 | 4.4 | The associator reduces to a sign (1-dim range) — the "handedness is one-dimensional" | [C] | **ABSENT confirm/refute sentence** (only described) | picture→analogy (declared: "not yet proven") | |
| 4.4.2 | 4.4 | The determinant is the unique (up to scale) alternating trilinear form on ℝ³ | [std] | classical linear algebra | literal | |
| 4.5.1 | 4.5 | The associator is the CD analog of the G₂ 3-form / oriented volume | [H] | present (4.5) | analogy | |
| 4.5.2 | 4.5 | The "handedness turns on" reading = resistivity | [H] | **ABSENT** | picture | |

### Chapter 5 — Polarization

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 5.2.1 | 5.2 | Alternativity = polarization of the re-association field | [H] | depends on 4.4.1 [C] | **ABSENT** | |
| 5.3.1 | 5.3 | CD 3→4 = depolarization (sign → vector) | [H] | **ABSENT** | **ABSENT** | |
| 5.4.1 | 5.4 | Γ has no alternator strut; if alternativity is physical, Γ is missing a second strut | [H] | present (5.4) | analogy | |

### Chapter 6 — Flux

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 6.2.1 | 6.2 | `dcStep` = minimal rotation count (geodesic) | [P] | `TamariMetric.dcStep_eq_geodesic` | n/a | |
| 6.2.2 | 6.2 | dcStep is path-independent | [P] | `dcStep_le_path_to_rightComb`, `contracts_to_steps_of_dcStep` | n/a | |
| 6.3.1 | 6.3 | 196 trees (sizes ≤6); size-6 census = 132 routes | [V] | `metric_sweep.py` | n/a | |
| 6.4.1 | 6.4 | The pentagon coherence is what makes flux path-independent | [H] | **ABSENT** | analogy (8.5 says "would be literal once 6.4.2 proven") | |
| 6.4.2 | 6.4 | The pentagon cocycle identity holds for the sign cocycle | [C] | **ABSENT** (future work) | literal-if-proven | |
| 6.4.3 | 6.4 | Associator e₀ component vanishes (imaginary-part property) | [C] | **ABSENT** | literal-if-proven | |
| 6.5.1 | 6.1/6.2 | `dcStep` is the conserved flux (frozen-in analog) | [H] | by-level-declared? no | analogy | |

### Chapter 7 — The cut

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 7.2.1 | 7.2 | `dcStep (Node l r) = dcStep l + dcStep r + rightSpine l` | [P] | `dcStep_node_compose` | n/a | |
| 7.2.2 | 7.2 | `rightSpine l` counts cross-boundary flips (worked example) | [P/V] | example + `rightSpine_rightComb` | literal | |
| 7.3.1 | 7.3 | `rightSpine` = the invariant meaning = minimal cross-boundary flux | [H] | **ABSENT** | analogy | |
| 7.3.2 | 7.3 | The composition law is a lifting scheme (coarse+detail, wavelet) | [H] | **ABSENT** | **ABSENT** (7.1 asserts "the same algebraic shape") | |
| 7.4.1 | 7.4 | λ-discount rescales only the interface, exactly linear over ℚ | [P] | `looseCost_linear_in_trust`, def `looseCost` | n/a | |
| 7.4.2 | 7.4 | The λ-discount = rate-distortion (cost of discarding detail) | [H] | **ABSENT** | analogy | |

### Chapter 8 — Resistivity

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 8.2.1 | 8.2 | Γ = per-flip weight; two-regime collapse | [P] | `weightedCost_assoc_regime`, `weightedCost_nonassoc_regime` | n/a | |
| 8.2.2 | 8.2 | Edge-Lipschitz: cost changes ≤ Γ per flip | [P] | `weightedCost_edge_lipschitz` | n/a | |
| 8.3.1 | 8.3 | Γ = resistivity (ideal CD≤2, resistive CD≥3) | [H] | **ABSENT** | analogy → literal-if-6.4.2 | |
| 8.4.1 | 8.4 | Loose coupling is exactly linear in load (Hooke), over ℚ | [P] | `boundary_retreat_linear_in_load` | analogy | |
| 8.4.2 | 8.4 | The rescue envelope is bounded by the coupling | [P] | `rescue_envelope_bounded_by_coupling` | n/a | |

### Chapter 9 — Reduced lattice

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 9.2.1 | 9.2 | Transit map collapses trees→coords: 5→5, 14→9, 42→19, 132→29 | [V] | `presentation_data.py` / hand-recomputable | n/a | |
| 9.2.2 | 9.2 | Micro-states exponential (Catalan), macro-states polynomial → reduced model | [H/V] | counting; **ABSENT** growth-rate precision | analogy | |
| 9.3.1 | 9.3 | `leftWeight` strict descent along every cover | [P] | `contracts_one_leftWeight_decreases` | n/a | |
| 9.3.2 | 9.3 | dcStep is *not* strict descent (left-context rotations) | [P/V] | `TamariMetric` §4 note; census | n/a | |
| 9.4.1 | 9.4 | T₃ = N₅ — the Tamari lattice is not graded; dcStep≠rank | [P/V] | `dcStep(leftComb)=2` vs height 3, computed | n/a | |
| 9.4.2 | 9.4 | `dcStep` is the maximal Bellman-consistent potential (C5) | [P] | `dcStep_is_maximal_potential` | n/a | |
| 9.5.1 | 9.5 | Rescaled transit-coordinate measure converges to a limit shape | [C] | **ABSENT** | literal-if-proven | |

### Chapter 10 — Stellarator plan

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 10.1.1 | 10.1 | Timelike/spacelike ↔ axisymmetric/non-axisymmetric | [H] | present (1.3/10.1) | picture | |
| 10.2.1 | 10.2 | VMEC/DESC/SIMSOPT/SPEC characterizations | [std] | **no source cited** | n/a | |
| 10.4.x | 10.4 | Comparison quantities 1–5, in order | [H] | each has confirm/refute? **partly** | picture | |

### Chapter 11 — Ledger

| ID | § | Claim | Tag | Basis | Level | Verdict |
|---|---|---|---|---|---|---|
| 11.2.x | 11.2 | The closed ledger rows = the [P] cites above (consistency check) | [P] | must match ch 4,6,7,8,9 rows exactly | n/a | |

## Self-caught defects (seeded for reviewer calibration)

These were found by the drafting model's own mechanical audit (2026-08-28). A
reviewer that catches them independently is calibrated; one that catches none
while flagging non-defects is a warning sign.

- **F-A (untagged verified data)**: quantitative claims in 1.3, 6.3, 9.2 rest
  on verified computations but were not tagged [V]; register adds the [V] class.
- **F-B (duplicate untagged facts)**: ch 3 restates ch 8's tagged facts
  (Γ jump, regimes) without tags.
- **F-C (analogy-level gaps)**: policy rule 3 violated in ch 5
  (polarization), 6 (flux), 7 (lifting scheme), 8 (resistivity). Only ch 4
  declares levels. Rows above carry Level=**ABSENT** at the exact sites.
- **F-D (missing confirm/refute sentences)**: policy rule 2 violated on
  4.4.1, 4.5.2, 5.3.1, 6.4.1, 6.4.2, 6.4.3, 7.3.1, 7.3.2, 7.4.2, 8.3.1, 9.2.2,
  9.5.1.
- **F-E (external facts uncited)**: 10.2 code characterizations lack sources.
- **F-F (level mislabel risk)**: 3.3.2 and 6.1/6.2/6.5 blur "proven for
  octonions (alternative)" against "claimed for sedenions (not yet in
  formalization)". Reviewer must decide whether these are one claim or two.
