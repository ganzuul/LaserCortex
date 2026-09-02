# Lab Note 062 — The Foundations Migration Audit: Deprecation, Bit-Rot, and a Green CI

**Date**: 2026-09-02
**Trigger**: owner — *"I am not sure which of the .lean files are deprecated. We
moved to grounding in foundations/ but everything didn't get moved over. The
duplicated theorem we just encountered is an example of that."*
**Status**: NOTE + **repairs landed** (this unit turns `lake build` green for the
first time since `c71d6d6`, 2026-07-20) + **owner-decisions list** (§5)
**Protocol**: Timespace Decomposition v0.3 — (4,4) Signature Model

---

## 0. Abstract

The move to `foundations/` grounding (~July 20, commit `c71d6d6` "CALPHAD-LC
bridge + archive cleanup … dead code removal") was a content migration
performed **without a graph migration**: the migrated definitions were
replicated into `foundations/Algebra.lean` / `foundations/Tamari.lean` /
`foundations/Chu.lean`, but the source files stayed in place, the root
import list kept accreting, and `Main.lean` (the `lean_exe` target) was
deleted while `lakefile.toml` kept pointing `defaultTargets` at it. Result:
CI red for six weeks; two half-migrated files poisoning the closure; four
modules rotting silently in orphan state; two stale dependency artifacts
describing a tree that no longer exists. The `octonion_norm_mul` duplicate
(060 §7) was the symptom that forced this audit; the full sweep found ~30
cross-file duplicate names and a family of distinct failure mechanisms,
each now named (§4).

## 1. Module census (37 `.lean` files, `lake build` default target = lib root)

**CI-BUILT, green (22 modules)** — the default build now covers:
`foundations/{Algebra,Tamari,Chu}`, `Coherence`, `Stencil`, `PhysicsAPI`,
`SubdivisionClosure`, `Generation`, `Generation` deps, `Basic`, `AMM`,
`Hopf`, `ParadoxAxioms`, `LogicalTemperature`, `FreeEnergy`, `Friction`,
`TamariMetric`, `ThermodynamicBridge` (carries 1 `sorry`, warning),
`TemporalParadox`, **`CayleyDickson`** (fixed this unit — §3.2),
**`HyperbolicChirplet`** (F3 home — newly wired in: it must not orphan
while F3 is worked on), **`Test/Sanity/OctonionNormTest`** (newly wired —
the repo's only Lean test now actually runs in CI), and the root module.

**ARCHIVED this unit** (`git mv` → `_archive/`):
- `SplitQuaternionClifford.lean` — fully superseded: every declaration
  (`SplitQuat`, `split_quat_*`, `antipode_sq*`, `Cl11/Q11/Q22`, `ε0/ε1`,
  `embed`, `norm_mul`, …) exists in `foundations/Algebra`'s SplitQuat /
  CD sections; the file was also broken by a stray mid-file `import`
  (060 §7.2's own failure mode, ironically) introduced when someone
  appended a Clifford-algebra *note* (markdown `## Tags` and all) below
  the code. `open SplitQuaternionClifford` in consumers removed.
- `experiments/LabelPropagationOscillation.lean` — imports
  `LaserCortex.Problem`, a module deleted in `c71d6d6`. Experiment from
  July 7; archived with its broken import intact (git history is the
  recovery path).

**REPAIRED this unit (3)**:
- `CayleyDickson.lean` (green): (i) a parse-breaking **stray docstring**
  (a `cdMul` explanation copy-pasted above `gamma`, orphaned before
  another docstring — the signature of an aborted edit); (ii)
  `add_eq_sca`/`mul_eq_scm` **declared after their use** — Lean needs
  declaration before use, and the "helper lemmas" block sat below
  `emb_add`/`emb_mul`; moved above with a comment. No statements changed.
- `Test/Sanity/OctonionNormTest.lean`: dead `open LaserCortex` (namespace
  never existed post-flattening). Removed; wired into root imports.
- `Entanglement.lean` partial (see §5 — not repaired to green).

**BIT-ROTTED ORPHANS (owner decisions, §5)**:
- `Entanglement.lean` — see §5.1.
- `BornTest.lean` — one rewrite failure at :76 (`antipode` semantics
  drift; file last touched June 28, pre-dating the antipode/pairing
  section rewrite in Algebra). Ties to the `born_test_calibration_ladder_
  plan` Phase B (which *planned* this rewrite). §5.2.
- `OctilinearEmbedding.lean` — unsolved goals at :77 (`covectorProjection
  / SplitQuat.grade`). **The most urgent** by exposure: primer Ch 9
  (`09_reduced_lattice.md`) and the ledger cite `transitCoord` theorems
  as **[P]** — a claim not verifiable while the file does not build.
  §5.3.
- `GraphitiEmbedding.lean` — fails only via `OctilinearEmbedding` (and
  its own imports are healthy); revives with §5.3's fix.
- `AtomicShell/CoherenceMetric/ImpedanceMetric/CycleDynamics/
  ThermalResidue/EmissiveAbsorptive` — one cluster, **all compile green**
  today but nothing imports the cluster (root never did). §5.4.
- `Composition`, `Boundlessness`, `KernelChoice`, `TropicalTypeAlgebra` —
  compile green, imported by nothing (except `Boundlessness` ← archived
  experiment only). §5.4.

## 2. Duplicate-declaration map (the "didn't all move over" evidence)

30 duplicate *simple* names across files. The load-bearing groups:
- **SQC ↔ Algebra** (16): the split-quaternion family — fully migrated;
  SQC archived. (`octonion_norm_mul`'s near-twins `norm_mul`,
  `splitQuat_norm_mul` all live in Algebra now — and note the incident
  that started this: *within* Algebra, a fresh copy of
  `octonion_norm_mul` had been added at line ~301 while the original
  stood at ~1414, until the compiler's duplicate-declaration error
  caught it: the grep that missed it had been truncated by `| head`.
  060 §7.1's rule, upgraded: **grep the full output before declaring**.)
- **CD ↔ Algebra** (4: `SplitComplex`, `ext_components`, norm/pythagorean
  family): CD's SECTION 1–2 duplicate Algebra's namespace-SplitComplex +
  Quaternionℤ content; CD's SECTION 3 (`gamma`, `cdConj`, `cdMul`,
  **`toSO`**) does **not** exist in Algebra — the carrier morphism of
  note 007. CD is now fixed and CI-wired, but the honest end-state is
  one home for each: §5.5.
- **SubdivisionClosure ↔ Tamari** (1: `rightComb_size`) — check which
  is canonical when next touched; harmless duplicate, not an error.
- **Coherence ↔ CycleDynamics** (`split_neg_neg`) — namespaced, benign.

## 3. What was fixed mechanically

1. **`lakefile.toml`**: `defaultTargets = ["LaserCortex"]` (was
   `["lasercortex"]` — the exe whose `Main.lean` `c71d6d6` deleted);
   the dead `[[lean_exe]]` block removed (history holds `Main.lean`
   under `git show c71d6d6^:Main.lean` if the bridge ever needs it
   again — no `lake exe` call exists anywhere in `infra/`, `scripts/`
   today).
2. **`CayleyDickson.lean`**: stray docstring deleted; helper-lemma pair
   moved above first use.
3. **`Entanglement.lean`**: dropped dead `import`s of SQC + CD and dead
   `open Hopf` (the namespace is `SplitOctonionAntipode`), removed the
   `open` lines; rewired to resolve `SplitComplex` to `_root_`
   (Algebra's, post-migration) — the docstrings' `SplitComplex.emb`
   mentions are prose-only. Its annihilation theorems: `simp` could no
   longer reduce `(-x).eᵢ` through the `Neg` instance chain → replaced
   with `native_decide` on closed literals (no statement change; 8
   theorems). *What remains broken is §5.1; the module is out of the
   default build until repaired.*
4. **`BornTest.lean`**: import re-pointed SQC → `foundations.Algebra`
   (still one proof gap, §5.2 — not wired in).
5. **Root imports** re-truthed: `+CayleyDickson, +HyperbolicChirplet,
   +Test/Sanity`; `−Entanglement` (temporarily; §5.1). `lake build`:
   **8558 jobs, all green.**

## 4. The failure mechanisms, named (so they stop recurring)

- **Content-migration-without-graph-migration**: the root cause
  above all. Moving theorems into `foundations/` is only half a move;
  the import edges and the old file are the other half, and they are
  what rot.
- **Downstream masking**: lake skips targets whose imports failed, so
  `Entanglement`'s and `BornTest`'s own bit-rot sat *invisible* behind
  the SQC/CD breakage. Fixing the blockers is a **diagnostic**, not
  only a repair.
- **Orphan = rot**: a module nothing imports is not built, its proofs
  are not checked against the migrated foundations, and drift
  accumulates silently (six weeks for Entanglement, longer for the
  `simp`/instance reductions — 060 §7.2's transparency trap struck
  again). CI coverage is the cure: everything alive lives in the root
  list.
- **Declaration order** (CD), **aborted-edit debris** (CD's stray
  docstring, SQC's mid-file markdown+imports), **namespace renames
  consumers didn't follow** (`open Hopf`), **truncated search**
  (`octonion_norm_mul`).
- **Stale meta-artifacts**: `DEPENDENCY_GRAPH.json` nodes list ≥12
  modules that no longer exist (`Candidates`, `Cost`,
  `DecisionComposition`, `Decomposition`, `EMLRegistry(+_test)`,
  `FrictionLagrangian`, `InstitutionalClosure`, `LiarParadox`,
  `LodayCoords`, `LogicMonad`, `Problem`, …); `connectivity_voids.md`
  points into deleted files too. Both describe the pre-July-20 tree.

## 5. Owner decisions (numbered for the ledger)

1. **`Entanglement.lean`** (§5.1 in-file): ~8 residual proof gaps
   (lines ~165–280) where `rw`/`omega` goals drifted — pairing
   semantics (`antipodePairing`/`counit` in Algebra have been rewritten
   since; `isAnnihilationElement` + the "annihilation subspace" theory
   needs a re-derivation pass, not a patch). **Decision: repair (one
   focused session against the current Algebra) or archive (its claims
   are re-expressible in `Chu`/`Hopf` terms?).** Until then it is out
   of the default build (root import commented-out note in
   `LaserCortex.lean` — actually removed; restore the line when green).
2. **`BornTest.lean`**: rewrite gap at :76; the
   `born_test_calibration_ladder_plan` Phase B already anticipates a
   rewrite. **Decision: fold into that plan rather than repair in place.**
3. **`OctilinearEmbedding.lean`** (:77 `covectorProjection_antipode`):
   the file Ch 9 cites as [P]. **This is the most urgent repair** —
   either fix the proof or downgrade Ch 9's rows to [V] until it is
   fixed. Flagged to the primer's honesty discipline either way.
4. **The healthy-orphan cluster** (AtomicShell → ImpedanceMetric →
   CycleDynamics/ThermalResidue/EmissiveAbsorptive; Composition,
   Boundlessness, KernelChoice, TropicalTypeAlgebra): all compile;
   **decision: wire what's still referenced by notes/primer into the
   root imports** (cheap insurance), and let the rest go to `_archive/`
   on a later sweep with the same `git mv` discipline used here.
5. **Finish the CD→Algebra move**: promote SECTION 3
   (`cdConj`/`cdMul`/`toSO` + `toSO_add`, the note-007 carrier) into
   `foundations/Algebra`, then archive `CayleyDickson.lean` and drop
   its root import. One migration, done once.
6. **Regenerate or delete `DEPENDENCY_GRAPH.json`** and annotate
   `connectivity_voids.md` as historical. (A regenerated graph should
   also flag *orphan status* as a first-class node attribute — that is
   the audit's lesson in data form.)

## 6. Hygiene rules adopted (060 §7 extended)

1. **Declare-once discipline**: before adding a lemma, grep the
   **un-truncated** output for the name (`lake env lean -e` /
   `grep -rn 'theorem <name>'` full view); prefer extending the
   `foundations/` home over re-declaring anywhere else.
2. **Migration = file + graph**: when content moves to
   `foundations/`, in the same commit: delete or archive the source,
   fix every `import`/`open`, and re-run `lake build`.
3. **Alive ⇒ in root imports**: no active module lives orphaned.
   Orphans get archived (git holds them) or get wired in.
4. **`lake build` is the CI contract**: `defaultTargets` points at
   the library; no dangling exe blocks; a red badge is a *graph* bug,
   fix the graph before blaming the target.
5. **Stale [P] is worse than missing [P]**: when a file cited as [P]
   stops building (or was never built), the claim's tag must move
   (owner call §5.3).

## 7. Status of claims in this note

All §1–§3 entries are empirical (build outputs this session, quoted
line numbers, `git show`-recoverable files); §5 items are
recommendations pending owner decision; §6 are stipulations. `lake
build` green = 8558 jobs (verified 2026-09-02, this unit).

---

## References

- `c71d6d6` (the half-migration), `bff16a0`, `e212301` (batch that
  orphaned Entanglement behind broken deps), 060 §7 (the predecessor
  hygiene notes), 059 (disambiguation method applied here to files)
- `_archive/SplitQuaternionClifford.lean`,
  `_archive/LabelPropagationOscillation.lean` (this unit's `git mv`s)
- Notes 006/007 (`toSO` carrier: §5.5), primer Ch 9 (`transitCoord`:
  §5.3), `docs/born_test_calibration_ladder_plan.md` (§5.2)
