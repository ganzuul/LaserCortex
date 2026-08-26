# Presentation Pack — index

Material for presenting the LaserCortex cost-of-re-association results, from
formal handout to Q&A prep, with the quantum-computing pivot.

## Read order

1. **`theorem_statement_sheet.md`** — the pure-math handout. Every named Lean
   theorem + statement, grouped by theme. Hand this out at any talk.
2. **`quantum_relevance.md`** — *the pivot document*. Why quantum computing
   makes the work relevant: the anyon/F-move correspondence, the octonion
   boundary, compilation overhead. Includes the honesty ledger (proven vs.
   correspondence vs. speculative).
3. **`colloquium_abstract.md`** — 3-paragraph abstract + four audience-tuning
   variants (math / physics / CS-PL / quantum).
4. **`seminar_talk_outline.md`** — 30-min math-faculty talk, 12 slides, with
   the "new vs. known" honesty slide and the quantum-motivation slide.
5. **`preprint_skeleton.md`** — arXiv-style section map, novelty ledger, ranked
   venues, and the quantum-applications section.
6. **`objections_rebuttals.md`** — 9 anticipated questions, short + long
   answers, and "never do" warnings.

## Figures

| Figure | File | Script | Shows |
|---|---|---|---|
| The Γ jump | `../plots/friction_barrier.png` | `../../scripts/friction_barrier.gnuplot` | Γ_k for k=0..7 with the associator-onset jump (2→19) and the 4159 K barrier |
| Lightcone inversion | `../plots/lightcone_census.png` | `../../scripts/lightcone_census.gnuplot` | all 196 size-6 routes flip timelike→spacelike at CD 3 |

Regenerate with:
```
python3 scripts/presentation_data.py      # rewrites plots/*.dat from source
gnuplot scripts/friction_barrier.gnuplot
gnuplot scripts/lightcone_census.gnuplot
```

## The one-sentence through-line

> Composition in non-associative algebra carries an exact, computable cost —
> a distance from closure — with a sharp phase transition at the split
> octonions; quantum computing (anyon fusion, octonionic gate algebras,
> compilation) is where that cost is physically paid.
