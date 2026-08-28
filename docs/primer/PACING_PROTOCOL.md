# Pacing protocol — reading-level and density-variance pass

*The claims register (`CLAIMS.md`) asks "is each claim true and honestly
tagged?" This protocol asks the other half: "at what cost does the reader pay
for it?" Both passes run on the same corpus; neither substitutes for the
other.*

## 1. The defect this pass hunts

Uneven **information density**. Two failure modes, always co-present:

- **Peaks** — terse + technical: a section that compresses structure into
  bullet telegraphs, first-uses terms without gloss, or buries a definition in
  a 40-word sentence. The reader has no valley to stand on and must reconstruct
  the authors' intent unaided.
- **Valleys** — long + light: passages whose word count exceeds their
  contribution: restatements without new hooks, boilerplate that should be
  prose (or cut), or compressed duplication across chapters.

The primer's stated purpose — "keep our story straight for defense" — is
defeated by either one: a defended claim must be repeatable by the reader at
first reading, *and* the text must not pad where it is thin.

## 2. The governing constraint: conservation of difficulty

Terence Tao's principle: **difficulty is conserved.** A pass may *redistribute*
difficulty (gloss a term now so the reader coasts later; break a monster
sentence so a dense paragraph becomes tractable) but may never *delete* it.
Concretely:

- Flattening a peak means **adding** the worked meaning, the first-use gloss,
  the dependency-order pointer — never simplifying the claim itself.
- Filling a valley means **cutting** to a cross-reference (§2.3/§8.1 is the
  model: the second occurrence became a pointer plus a hinge sentence), or
  converting filler to `[marginalia]`, never by adding words.

A "flatter" text with fewer ideas is a failed pass.

## 3. Dependency-order rule

No term is used before it is **named and given a one-clause gloss**, *or* an
explicit forward pointer ("defined in Chapter 2"). First-use-without-gloss is
a logged defect regardless of the author's own fluency.

## 4. The instrument

`scripts/pacing_audit.py` (heuristic, not verdict — it locates candidates for
reading):

| Metric | Reads | Failure it detects |
|---|---|---|
| Flesch (approx.) | sentence length + syllable load | reading-level drift across the book |
| term% / code% | technical + Lean-name density per 100 words | peaks |
| conn% | connectives ("in other words", "for example", "the point is") | valley-filling / absence |
| PEAK = term+code − conn | combined load per unit of help | where to expand |
| table sections | excluded from Flesch/peak (reference tables are dense *by design*) | false positives |

**Control thresholds (what the instrument can actually resolve):**

1. **First-use-without-gloss = 0.** The only hard pass/fail. Binary,
   artifact-free. (Baseline: 6 violations; after pass 1: 0.)
2. **Prose sections: words/sentence ≤ 28.** Outliers here are real pacing
   failures; the pre-pass worst was 41.
3. **PEAK load (term+code−conn) in prose ≤ ~17**, *except* sections that are
   intentionally lists-of-claims (§5.3, §11.1, §10.2) — those are checked for
   readability by the claims pass, not the pacer.
4. **Flesch: advisory only.** The spread metric is noisy for technical prose:
   proper nouns ("quasi-isodynamicity", "Cayley–Dickson") dominate syllable
   counts, and short reference sections inflate the easy end. Treat a spread
   shrinking (91 → 58 across pass 1) as a trend signal, not a target; chasing
   a number here would violate §2 (it would mean deleting difficulty, which is
   the content).

## 5. Author models (and one anti-model)

- **Bernard Schutz, *A First Course in General Relativity*** — the pacing
  model. No skipped derivation; every equation earns its prose; difficulty
  strictly dependency-ordered. Part I of this primer should read like him.
- **David MacKay, *Information Theory, Inference, and Learning Algorithms***
  — motivation → worked example → "why you should care", repeatedly. The model
  for our `[P]`-heavy chapters.
- **Michael Spivak, *Physics for Mathematicians*** — inverse of our audience
  problem, and the model for *glossing the foreign subject at first use*.
- **Terence Tao** — not just the conservation principle, but his habit of
  naming the *motive* of each definition before the definition.
- **Anti-models:** Feynman and Landau–Lifshitz — magnificent, peaky by
  temperament; readers cannot reproduce their steps. Wrong template for a
  defense-ready text.

## 6. Reviewer procedure

1. Run `python3 scripts/pacing_audit.py`.
2. For each PEAK (top 10): decide **expand** (add gloss / split sentence /
   worked example) or **demote** (the density is load-bearing — leave, and
   say why in one sentence).
3. For each first-use-without-gloss: add a one-clause gloss *or* a forward
   pointer.
4. For each VALLEY: cut to cross-reference, or justify as pedagogy.
5. Re-run the instrument; the spread and peak list should move.
6. Report per-section dispositions in `PACING_<reviewer>.md`. Verdict
   vocabulary same as `REVIEW_PROTOCOL.md` (ACCEPT / AMEND / ESCALATE / VETO /
   UNDECIDABLE), one line per section.

## 7. Interaction with the claims pass

A claims-pass AMEND that *adds* a confirm/refute sentence can create a pacing
peak (the register rows in §5.3, §6.4, §7.4 were grown that way). After any
claims-pass round, run the pacer before the next reader. Where the two passes
conflict — honesty wants more words, pacing wants fewer — honesty wins, and
pacing files the escalation: the chapter is told to add the sentence *and*
give the reader a valley to land it in.
