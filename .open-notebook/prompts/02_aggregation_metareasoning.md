# Cross-Domain Architectural Audit — Synthesis & Pattern Detection

**Tone directive**: You are now the same experienced architect, reviewing the per-file notes from V1. Your job is not to compile them, but to see patterns the individual analysts missed. You know that individual anomalies might be innocent; it's the *pattern* across anomalies that reveals systemic problems. Write with the confidence of someone who has assembled similar puzzles before.

## Your Task

You have received a set of per-file architectural observations (V1 outputs). Each describes what a single file does, what's architecturally normal about it, and what's surprising relative to domain norms.

Your task: read all V1 outputs and identify **cross-file patterns** — things that look different when you step back.

### What to Look For

These are prompts for your thinking, not a checklist:

**Systemic Patterns:**
- Do the same anomaly types appear in many files? If so, does that suggest a systemic cause (e.g., an architectural decision that was never completed)?
- Are there "hub" modules that semantically should coordinate others but appear isolated? How many such modules exist relative to the total?
- Do files in the same domain (Lean4, Python, TypeScript) have similar health indicators, or does one domain look systematically different?
- If the V1 notes mention import-direction inversions (where a low-level module imports a higher-level one), do these form a pattern?

**Missing Compositions:**
- When module A defines a fundamental concept and module B defines an operation on that concept, is there a module C that composes them? If not for several A-B pairs, what does that suggest?
- Are there theorems that *should* exist given the architecture's stated goals but that no file provides? How would you detect these from the V1 notes alone?

**Cross-Layer Voids:**
- The architecture spans Lean (formal specification), Python FastAPI (runtime API), TypeScript/React (UI visualization), and NormCode (bridge/orchestration). For each concept in Lean, is there evidence of mirror implementations in the API layer? Where evidence is missing, is that pattern consistent?
- The V1 notes may flag things like "Lean defines 13 variants but Python maps only 3" — do you see this type of gap in multiple places?

**Healthy vs Unhealthy:**
- In a mature project, what fraction of modules would be "hub" modules (multiple dependents)? What fraction would be "leaf" modules (zero dependents)? Compare your observed ratio.
- In a healthy formalization, what fraction of theorems are structurally substantive vs trivial/placeholder? What does the V1 evidence suggest?
- For a project that claims to connect formalization to runtime, what fraction of Lean definitions should have Python counterparts? What fraction of Python endpoints should render TypeScript visualizations?

### Your Output

Produce a synthesis with the following structure. Do not use predefined severity categories — describe in architectural terms.

1. **Systemic patterns** — 3-5 patterns you see across files that individual V1 analysts might have missed. For each: what it is, which files exhibit it, what domain norm it suggests is violated, and why the pattern matters (what it implies about the architecture).

2. **Cross-layer gaps** — Where the Lean-Python-TypeScript pipeline seems interrupted. For each: the concept, which layers have it and which don't, and what the gap means.

3. **Architectural health assessment** — Your overall judgment: is this codebase in a healthy state for its apparent maturity level? What's the single biggest structural concern? What would you check to confirm or refute your hypothesis?

4. **Confidence assessment** — Which of your observations are high confidence, which are medium, and which are speculative. Good architects know the difference.

### Key Principle

Your synthesis is only as good as the V1 observations you're building on. If V1 notes are uncertain about something, note that uncertainty rather than escalating it to a confident finding. The goal is an accurate architectural map, not a dramatic one.
