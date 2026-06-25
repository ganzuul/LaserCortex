# Cross-Domain Architectural Audit — Self-Critique & Refinement

**Tone directive**: You are now auditing your own synthesis. This is the hardest part: catching what you missed, acknowledging where you were overconfident, and identifying what you would do differently. An architect who cannot critique their own work is not trustworthy.

## Your Task

You have produced a V2 synthesis — an aggregated analysis of architectural patterns across the codebase. Now you will critique it using the same domain-norm-based approach that guided V1.

### Critique Dimensions

**1. Known blindspots of per-file analysis (V1):**
- Each V1 analyst saw only one file at a time. What patterns only appear when you see all files together? Did the V2 synthesis catch these emergent patterns, or did it simply restate individual V1 findings?
- Files that look pathological in isolation may look normal in context (e.g., a module with zero dependents might serve as a spec reference, not a runtime component). Did V2 consider this possibility?
- V1 analysts had no cross-layer visibility. Did V2 properly account for connections that span Lean → Python FastAPI → TypeScript/React (+ NormCode bridge), or did it default to analyzing each layer independently?

**2. Domain norm strength:**
- For each finding in V2, ask: *How confident am I that this violates a real domain norm?* Not all deviations are problems — some domain "norms" are conventions that this project may have legitimately departed from.
- Which V2 findings rely on norms that are genuinely universal (e.g., "a definition with zero uses outside its module may be orphaned") vs project-specific (e.g., "the 13:3 ProblemClass mapping ratio is too low")?
- Would a practitioner in the relevant domain agree that the alleged norm exists?

**3. Missing evidence:**
- What evidence would confirm or refute each V2 finding? If that evidence isn't in the V1 notes, should the finding's confidence be lowered?
- Are there V2 findings that could be explained by a simpler hypothesis than "architectural problem"? What are those alternative explanations?

**4. What would you do next:**
- If you were to do another V1 pass with the knowledge you now have, what would you look for that the original V1 prompts didn't ask about?
- What single piece of information (missing from all V1/V2 data) would most change your architectural assessment?

### Your Output

Produce a structured critique:

1. **V2 findings you agree with** — For each: why the domain norm is real, and what confidence you assign (now with the benefit of cross-file sight).

2. **V2 findings you'd downgrade** — For each: what the alternative explanation is, and why the original confidence was too high.

3. **Patterns V2 missed** — If stepping back from V2 reveals emergent patterns it didn't capture, describe them.

4. **Refined methodology** — How would you change V1 if you ran it again? What questions would you add? What domain norms would you emphasize that V1 underweighted?

5. **Overall assessment shift** — Did the critique change your high-level architectural assessment? If so, how? If not, why not?

### Key Principle

The goal is not to find all the problems — it's to produce an accurate map of what's known, what's uncertain, and what would resolve the uncertainty. A self-critique that downgrades several V2 findings is a success, not a failure. It means the map is getting more accurate.
