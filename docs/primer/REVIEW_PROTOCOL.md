# Review protocol — multi-model adversarial adjudication

*Designed for many independent LLM passes ("many eyeballs") plus human
sampling. The product is not a single model's opinion — it is the
**disagreement map** between models, plus a ground-truthable answer key.*

## 1. Unit of review

**One claim row** of `CLAIMS.md`. Atomic, self-contained, and independently
adjudicable. A reviewer never edits prose; it issues a verdict on a row.
(~50 rows in the register.)

## 2. The rubric — six independent checks per row

| # | Check | Applies to |
|---|---|---|
| R1 | **Tag correct?** Does the evidence justify [P]/[V]/[H]/[C]/[std] — over- or under-claimed? | all |
| R2 | **Citation real?** For [P]: does the named Lean theorem exist, and say *this* claim? | [P] rows |
| R3 | **Level declared and right?** For reused conventional terms: literal / analogy / picture, per honesty-policy rule 3 | rows with a conventional term |
| R4 | **Decisive sentence?** For [H]/[C]: is there a one-sentence confirm/refute, and is it actually decisive? | [H], [C] rows |
| R5 | **Internal consistency?** Contradiction with any other row, duplicate facts, or chapter prose vs register drift? | all |
| R6 | **Prose overreach?** Does the chapter sentence claim more than the row's tag allows? | all |

## 3. Verdict vocabulary (exactly one per row)

- **ACCEPT** — row stands as written.
- **AMEND** — fix is local: change tag, add a missing sentence, or add the
  missing analogy-level word. Reviewer must *supply the corrected text*.
- **ESCALATE** — the defect is real but its fix changes another chapter; flag
  for authorship round.
- **VETO** — the claim as stated is false (e.g. a citation that does not say
  what is claimed). Must name a counterexample sentence.
- **UNDECIDABLE** — reviewer lacked the information; specify what was missing.

## 4. Answer keys (ground truth for calibration)

Some rows have objectively checkable answers; use them to score reviewers
before trusting their judgment rows.

**Key A — Lean existence (R2).** A reviewer that flags a cited theorem as
missing when it exists (or vice versa) has failed calibration:
```bash
cd /home/nos/labware/LaserCortex && for t in left_alternative right_alternative \
  associator_antisymm_left strut_weight_eq_four gamma_increment \
  gamma_only_jump_at_cd2_3 contracts_one_leftWeight_decreases dcStep_eq_geodesic \
  dcStep_is_maximal_potential weightedCost_edge_lipschitz looseCost_linear_in_trust \
  dcStep_node_compose rightSpine_rightComb boundary_retreat_linear_in_load \
  rescue_envelope_bounded_by_coupling weightedCost_assoc_regime weightedCost_nonassoc_regime \
  pentagon_defect_bound; do
  grep -rEq "^(theorem|def|lemma) $t\b" LaserCortex/ && echo "EXISTS $t" || echo "MISSING $t"; done
```

**Key B — census numbers (R1 on [V] rows).** These are correct as of
`scripts/presentation_data.py` / `scripts/metric_sweep.py`:
- transit collapse: 5→5, 14→9, 42→19, 132→29 (sizes 3–6)
- size-6 lightcone: cd0: 0/1/131 · cd1: 1/5/126 · cd2: 6/14/112 · cd≥3: **132/0/0**
  (spacelike/lightlike/timelike; γ = 0,1,2,19,20)
- Γ₀..Γ₇ = 0,1,2,19,20,21,22,23; total trees sizes ≤6 = 196

**Key C — seeded defects F-A…F-F** (bottom of `CLAIMS.md`). A reviewer must
catch at least the F-C and F-D classes (they are pure reading, no domain
knowledge required) to pass calibration. Missing all six while raising
non-defects = do-not-deploy.

## 5. Procedure (per model)

1. Input to model: `00_front.md` (honesty policy) + `CLAIMS.md` + the chapter
   file under review + this protocol. **No authorship context** — reviewers
   judge the text, not the story.
2. Model returns a verdict table: row id, verdict, one-sentence reason, and —
   for AMEND — replacement text.
3. Run the same on every model (DeepSeek, Qwen, …), then diff:
   - **unanimous ACCEPT** → freeze the row;
   - **split verdicts** → the harvest; put both rationales side-by-side and
     escalate to an authorship round (that is where revision happens);
   - **unanimous VETO on an [P] row** → a real bug in the primer *or* a real
     bug in the build — investigate before touching text;
   - **majority MISSES a seeded defect** → that model cannot be used for R3/R4
     checks; keep it for R2 (mechanical) only.

## 6. Why this task suits many models (and what it is *not* for)

- Adjudication is **decomposable** (~60 independent units) and **verdicts are
  short** — cheap to run many models redundantly.
- Different models have genuinely different failure profiles on R3 (level of
  analogy) and R4 (decisiveness of confirm/refute sentences); the
  disagreements there are exactly the corpus's weak spots made visible.
- It is *not* for generating prose — prose quality comes after, in the
  authorship rounds that consume the harvest.

## 7. Output artifacts expected from a review pass

- `REVIEW_<model>.md` — the verdict table.
- A merged `DISAGREEMENTS.md` (diff of models; the harvest).
- Updated `CLAIMS.md` with AMENDs applied and ESCALATEs converted into
  authorship todos (Chapter 11 ledger rows).
