# The Cost of Re-association
## A Primer on Cayley–Dickson-Grounded Magnetohydrodynamics

*Working draft — internal canon. The main text is written in a neutral voice;
narrator commentary appears in **[bracketed marginalia]** and may use "we" — it
carries disclaimers, imperfect confidence, and mid-writing discoveries that
must stay close to the passage that provoked them. This is a sketch, and
sketches can be messy. Not for external citation in this state.*

---

## Abstract

Binary trees are the syntax of composition. Re-associating a product — changing
its bracketing — costs: a minimal, path-independent count of elementary flips,
weighted by a level-dependent constant Γ that jumps discontinuously at the
octonions. This primer develops the claim that this cost structure is a
magnetohydrodynamics in miniature. The associator is an *oriented* quantity —
its antisymmetry is the polarization of a re-association field, the flip count
is a conserved flux, and the Γ jump is a resistivity turning on. The
Cayley–Dickson tower — real, complex, quaternion, octonion, sedenion — becomes a
phase diagram of handedness: none, none, none, one (polarized), many
(depolarized).

Part I compresses the conventional grounding: ideal MHD, frozen-in flux, the
right-hand rule, and why stellarators are three-dimensional. Part II substitutes
our own grounding, chapter for chapter. Part III sketches the applications —
including a program to compare the resulting reduced model against conventional
stellarator equilibrium and optimization codes — and the open problems. Every
claim carries its proof status.

## The six anchors

| # | Anchor (conventional term) | Mnemonic | Reifies |
|---|---|---|---|
| A | **right-hand rule** | "which way does re-association turn?" | alternativity — the associator is an alternating 3-form |
| B | **polarization** | "is the turn one way, or all ways?" | associator antisymmetry — a sign, not a vector |
| C | **flux** | "how much turns, net?" | `dcStep` — the conserved, path-independent count |
| D | **the cut (interface)** | "what crosses the seam between parts?" | `rightSpine` — cross-boundary coupling |
| E | **resistivity** | "how much does a turn cost?" | Γ — the price of handedness (2 → 19 at CD 3) |
| F | **coarse / fine** | "what survives if I blur?" | the reduced lattice — slow vs. fast variables |

Read top-to-bottom: *re-association turns (A), the turn is one-way (B), the net
turn is a conserved count (C), the turn is carried across a seam (D), the turn
has a cost (E), and only the coarse part survives blurring (F).*

## How to read this primer

- **Claim tags.** Every substantive claim is tagged: **[P]** proven in Lean (no
  `sorry`, no axioms beyond classical choice), **[H]** hypothesis (working
  belief, not yet formalized), **[C]** conjecture (a precise statement we
  expect to hold or fail cleanly).
- **[Marginalia]** are narrator notes, written in the first draft as things were
  discovered. They are *not* claims; they are context.
- **Structure.** Part I (chapters 1–3) is the conventional grounding,
  compressed. Part II (chapters 4–9) is the CD-grounded theory, one chapter per
  anchor. Part III (chapters 10–11) is the stellarator comparison plan and the
  open-problems ledger. Appendices A–D hold the Lean index, the reification
  dictionary, the full honesty ledger, and the source concordance.

## Honesty policy

This text is written *before* peer review and is primarily for internal use: its
job is to keep the story straight when it is eventually presented and defended.
Consequently:

1. No claim about the theory may appear without a tag.
2. **[H]** and **[C]** claims must state, in one sentence, what would confirm or
   refute them.
3. Where a conventional term is reused ("flux", "resistivity", "polarization"),
   the chapter states the *level* of the analogy: literal structure, apt
   analogy, or motivating picture. The three levels are not interchangeable.
