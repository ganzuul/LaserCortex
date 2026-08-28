# Primer — concordance and status

*Working title: "The Cost of Re-association — a primer on Cayley–Dickson-grounded
magnetohydrodynamics." Internal canon; draft state.*

## File map

| File | Chapter | State |
|---|---|---|
| `00_front.md` | front matter (abstract, six anchors, honesty policy) | drafted |
| `00_introduction.md` | Introduction — why this primer exists | **drafted** |
| `01_the_problem.md` | 1. The problem, conventionally | scaffold |
| `02_conventional_grounding.md` | 2. Conventional MHD, compressed | scaffold |
| `03_the_substrate.md` | 3. The CD tower | scaffold |
| `04_handedness.md` | 4. Handedness (right-hand rule) | **drafted** (exemplar) |
| `05_polarization.md` | 5. Polarization | scaffold |
| `06_flux.md` | 6. Flux | scaffold |
| `07_the_interface.md` | 7. The cut / interface | scaffold |
| `08_resistivity.md` | 8. Resistivity | scaffold |
| `09_reduced_lattice.md` | 9. The reduced lattice | scaffold |
| `10_stellarator_plan.md` | 10. The stellarator comparison plan | scaffold |
| `11_open_problems.md` | 11. Open problems and the ledger | scaffold |
| `CLAIMS.md` | claims register — one adjudicable row per claim | **current** |
| `REVIEW_PROTOCOL.md` | multi-model adversarial adjudication rubric | **current** |
| `PACING_PROTOCOL.md` | reading-level / density-variance pass | **current** |
| — | instrument: `scripts/pacing_audit.py` | run from repo root |

"Drafted" = prose in place; "scaffold" = structure, tagged claims, and sources
in place, prose to be written.

## Source concordance (which repo material feeds which chapter)

| Source | Feeds chapters |
|---|---|
| `foundations/Algebra.lean` (associator, alternativity, strut_weight) | 3, 4, 5, 6, 11 |
| `foundations/Tamari.lean` (contracts_one, dcStep, leftWeight) | 6, 7, 9 |
| `TamariMetric.lean` (C2, C5) | 6, 9, 11 |
| `SubdivisionClosure.lean` (composition law, loose coupling, C3) | 6, 7, 8 |
| `Friction.lean`, `LogicalTemperature.lean` (Γ, critical point, Landauer) | 3, 8 |
| `OctilinearEmbedding.lean` (transit map, KKT multiplier) | 9 |
| `AMM.lean` (§9 market invariants) | 8 |
| notes 044–050 (temperature, phase diagram, loose coupling) | 3, 8 |
| notes 051–052 (metric, sweep, non-gradedness) | 6, 9 |
| notes 053–054 (interface flux, wavelet/MHD/anyon, anchors) | 4, 5, 6, 7, 8 |
| `scripts/metric_sweep.py`, `scripts/presentation_data.py`, `plots/` | 6, 9, 10 |
| conventional MHD / stellarator literature (restated, no external repo) | 1, 2, 10 |

## Conventions

- Neutral voice in the text; **[marginalia]** may use "we" (narrator notes,
  disclaimers, mid-writing discoveries).
- Tags: **[P]** proven in Lean, **[H]** hypothesis, **[C]** conjecture;
  conventional passages are untagged standard literature.
- No reference to external repositories; the primer is self-contained.
- Build (later): markdown + LaTeX math, pandoc → PDF. Not yet configured.
