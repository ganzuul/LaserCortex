# Schutz audit — expository debt (pass 2026-08-28)

*Instrument: `scripts/schutz_audit.py` + `scripts/pacing_audit.py` (with table
exclusion). Heuristic, not verdict — every flagged line was re-read. The
question Schutz asks is: does every equation earn its prose, and is every term
used only after it has been named with a one-clause gloss?*

## What Schutz demands

1. **Every display equation earns its prose** — one sentence *before* saying
   why we need it, one *after* saying what it says.
2. **Strict dependency order** — no term used before it is named and glossed,
   or forward-pointed ("defined in Chapter X").
3. **No skipped derivation** — if `A = B` is claimed, the step from `A` to `B`
   is shown or cited.

The instrument checks (1) and (2) mechanically; (3) needs a reader.

## Summary of what the primer now gets right

- **First-use-without-gloss: 0 violations.** All 20 tracked terms first appear
  with a gloss or pointer. This was 6/20 before the pacing pass.
- **Pacing: worst w/s 41→28, Flesch spread 91→58** (prose only, tables
  excluded). The remaining spread is now mostly reference-dense ledger
  sections (`11.1`, `10.2`), legitimately high code density.

## Remaining debt, prioritized

### P1 — Equations introduced as bullet incantations (no before/after prose)

These bullet lines name the right Lean identifiers but the surrounding
paragraph does not say *why* the equation exists or *what* it says in
English. A Schutz reader sees a correct statement and has no way to
reproduce it.

| File:section | Line | Equation / name | Debt |
|---|---|---|---|
| `03_the_substrate.md:3.1` | bullet `SplitOctonion` / `split_oct_mul` | correct names, but the bullets state *what* (`SplitOctonion over ℤ`) without *why we need the substrate here* beyond the chapter title |
| `03_the_substrate.md:3.2` | `assocDefect`, `frictionDensity` | defined, but the step from "associator" to "defect functions" is asserted without the one-sentence bridge: the associator is a vector; the defect functions are its coarse scalar shadows |
| `04_handedness.md:4.2` | `[a,b,c] = (ab)c − a(bc)` | w/s 27.0, peak 9.6 — long definition sentence + display equation with no "to see why this is the right definition, consider…" |
| `06_flux.md:6.4` | `δ²=0`, pentagon `φ(b,c,d)·…` | w/s 23.3 — three heavy claims in one section, each needing its own earning sentence; currently the section bridges from a geodesic theorem to a cocycle claim without the one sentence that says "and here is what would have to be true for 'flux' to be literal" |
| `07_the_interface.md:7.2` | `dcStep (Node l r) = …` + `rightSpine (rightComb n) = n` | two theorems on consecutive bullets, no intervening English that says what the second adds to the first |
| `07_the_interface.md:7.4` | `looseCost_linear_in_trust` | stated, but the hypothesis "over ℚ" needs its own earned sentence (why ℚ, not ℕ — truncated division) before the theorem can be read |
| `08_resistivity.md:8.2` | `Γ functional` two-regime bullets | terminology "two-regime collapse" appears without the one-sentence gloss of what "regime" means here |
| `11_open_problems.md:11.1` | table preamble + two long [C] rows | w/s 18.0 — the preamble is a 43-word single sentence driving the peak; it should be two sentences with the "handedness is one-dimensional → flux conservation" implication unpacked |

**Schutz fix (template):** for each bullet equation, add *before*: one
sentence of motive ("We need a quantity that… therefore we define…"); and
*after*: one sentence of gloss ("This says, in English, that …").

### P2 — Dependency-order slips that remain readable but fragile

| File:section | Term | First use is glossed? | Fragility |
|---|---|---|---|
| `07_the_interface.md:7.1` | `leftWeight`, `rightWeight` (used in "wavelet" framing) | YES, but only in 07.3 — 07.1 invokes "leftWeight" in the lifting metaphor before its definition in 07.2 |
| `09_reduced_lattice.md:9.5` | limit shape / empirical measure | glossed as "the phase diagram of composable logics" but the *mechanism* (concentration, rescaling) is forward-pointed to Chapter 11 without the one-sentence sketch of "what would have to converge" |

**Fix:** add forward pointers in 07.1 ("`leftWeight` is defined in the next section; read it as the coarse measure until then") and a one-sentence sketch in 09.5.

### P3 — Terse conventional grounding that still leans on the reader

`02_conventional_grounding.md:2.4` remains w/s 25.1. It now *is* glossed, but
the rotational transform `ι = dθ/dζ` and the KAM sentence are doing a lot of
work in one breath. Schutz would ask for one worked example: a single field
line with rational vs irrational `ι` (5 vs 5 turns) as a miniature story.

### Not debt (intentionally dense — do not flatten)

| File:section | Why high density is correct |
|---|---|
| `10_stellarator_plan.md:10.2` | reference-dense by design (code catalogue). P2 notes the UNVERIFIED flag already satisfies Schutz — it tells the reader *not* to trust it yet. |
| `11_open_problems.md:11.1` | a table of [C] claims — its density *is* the content; flattening it would hide the structure. |
| `03_the_substrate.md:3.1` tower list | the `ℝ → ℂ → ℍ → 𝕆 → 𝕊` list is a definition; its density is the point. |

## Recommended next edits ( Schutz pass 2, in priority order )

1. **Add the earning sentence before every bare equation in P1.** Eight bullets,
   eight sentences — the cheapest pass with the highest leverage.
2. **Dependency pass:** every file scanned above for a term whose first
   gloss is in a *later* section of the *same* file already has a pointer;
   extend the same to cross-file pointers (e.g., `Γ` glossed in Chapter 3
   should be re-glossed on first reuse in Chapter 8 with a one-clause
   reminder).
3. **Running example:** introduce the five binary trees on four leaves in
   Chapter 1, carry them. This turns every later definition from abstract to
   checkable without adding abstract words.

## Instrument note

`scripts/schutz_audit.py` flags "no before-prose / no after-prose" with a
3-line / 5-line window — a *candidate* detector, not a verdict. `scripts/
pacing_audit.py` now excludes table rows (flagged `[tbl]`) and reports prose
stats only. Flesch is advisory: proper nouns ("quasi-isodynamicity",
"Cayley–Dickson") dominate syllable counts. The durable controls are:
first-use gloss = 0, prose w/s ≤ 28, peak ≤ 17 except intentional lists.
