# Likely Objections & Rebuttals

*For Q&A. Rehearse the short (15-second) version of each; the long version is
for when they push.*

---

## Objection 1 — "What's actually new here?"

**The ask.** Tamari gradedness and the right comb are classical; the
associahedron is textbook. So is this just re-encoding known facts?

**Rebuttal (short).** "Three things I claim as new: the exact composition
identity with the coupling term, machine-checked; the Γ functional with its
single CD-3 jump; and the potentiality conjecture — cost equals geodesic
distance — with exhaustive evidence and a clear path to proof. The gradedness
itself I cite, not claim."

**Rebuttal (long).** If they still push: the *combination* — a cost function
that is simultaneously (a) a lattice rank, (b) additive-with-coupling under
composition, and (c) a geodesic distance — is not in the Tamari literature,
which treats the rank as combinatorial bookkeeping, not as a weight functional
with a phase transition. The Γ jump is what turns bookkeeping into structure.

**Never do.** Do not defend the temperature story as "the novelty." Concede it
immediately: it is a reading, not a result.

## Objection 2 — "Is the physics doing mathematical work, or just relabeling?"

**The ask.** Are "temperature," "grind," "heat" carrying any theorem, or are
they decorative?

**Rebuttal (short).** "Right now, relabeling — the physics motivates the
definitions but every theorem is pure combinatorics. The Landauer anchor is a
normalization, not a hypothesis. I say so on the slide."

**Rebuttal (long).** The one place physics *does* mathematical work: the
critical point is *discovered* by the thermodynamics (a natural energy scale
forces Γ to jump), not imposed. The Γ sequence isn't arbitrary — it's the
associator count at each Cayley–Dickson level. So the physics selects the
functional; the combinatorics proves its properties. That division of labor is
the honest claim.

## Objection 3 — "Why Lean / why machine-checking?"

**The ask.** Is this a gimmick? Are you using the checker to hide thin results?

**Rebuttal (short).** "Because the failure mode of this exact kind of identity
is an off-by-one in the recursion. Eight of the ~40 theorems in this line were
initially stated wrong by a term and caught by the checker. The checker is the
referee for the tedious cases, freeing the argument to be about why."

**Rebuttal (long).** The axiom audit is the reply to the sharper version of
this objection ("is it constructively empty?"). State: no `sorry`, axioms
limited to `propext`, `Classical.choice`, `Quot.sound`; everything else is
definitional.

## Objection 4 — "The C2 claim is only verified to size 6. Why should I
believe it?"

**The ask.** Finite check ≠ proof.

**Rebuttal.** That was the status at the time of the sweep — but it is now a
theorem. `dcStep_eq_geodesic` (Lean, no `sorry`, no axioms) proves that the
greedy flip count is the minimal number of rotations: each rotation drops
`dcStep` by at most 1 (`dcStep_contracts_one_le`), so any path to the right
comb needs at least `dcStep` steps, and the greedy recursion realizes exactly
that many. The finite check is now a *confirmation*, not the evidence. If
pressed, the whole argument reduces to the one bound — "each rotation drops
the rank by at most 1" — which is where the graded-lattice structure lives.

## Objection 5 — "Fifteen logics mapped to temperatures — this is numerology."

**The ask.** The map from `LogicName` to CD-level looks arbitrary.

**Rebuttal.** It is not asserted as mathematics. It is a *dictionary* from the
project's motivation, and the only entries doing work in the theorems are the
structural ones: modal → CD 3 (the critical point) and classical/boolean → CD 0
(absolute zero). The rest is indexing. Offer to restrict every theorem statement
to `cd : ℕ` with no logic names at all — they are eliminated from the formal
claims.

## Objection 6 — "Superadditivity of cost is just subadditivity of entropy
re-dressed."

**The ask.** Isn't this Landauer restated?

**Rebuttal.** Partially, and I'll say so. The composition law's coupling term
(`rightSpine l`) is the genuinely new ingredient — it says the interaction cost
depends on the *depth of the left operand's output chain*, not just the size of
the parts. Landauer gives you `W = kT ln 2` per erased bit; it does not give
you `+ rightSpine l`. That term is combinatorics, not thermodynamics.

## Objection 7 — "Where is this going? What would make it significant?"

**The ask.** So what?

**Rebuttal.** The concrete next theorem is C5 — minimality: any metric making
this cost 1-Lipschitz is dominated by d. That is a *universal property*, and
universal properties are the currency. Beyond it: the coupling term
`rightSpine` looks like a geometric invariant (right-spine depth = the left
system's "output length"), and if it survives to higher arities it becomes a
new invariant of operadic composition, not just binary trees.

## Objection 8 — "So what does this have to do with quantum computing, really?"

**The ask.** Prove the relevance; don't just assert it.

**Rebuttal (short).** "Two concrete hooks, both falsifiable. First, in
topological QC the fusion of non-abelian anyons is non-associative up to an
F-matrix, and the pentagon equation is exactly the associahedron — so my
rotation count `dcStep` is literally F-move depth, and my composition law is a
bound on it. Second, in circuit compilation the re-bracketing of a gate product
to match couplings is synthesis overhead, and `dcStep` is its combinatorial
lower bound. I prove the combinatorics; both hooks are stated as hypotheses
with a formalization path, not as results."

**Rebuttal (long).** Point to the honesty ledger (quantum_relevance.md §5).
The disciplined claim is: *the resource theory of non-associative composition
is a shared substrate* — the same graded lattice underlies anyon fusion,
compilation, and our cost. Whoever formalizes the correspondence gets a
machine-checked lower bound for free. That is a contribution even if the
physics is someone else's.

**Never do.** Do not say "we've solved fault-tolerant thresholds" or invoke
specific hardware (surface codes, Majorana qubits) as if the theorem depended
on them. It does not.

## Objection 9 — "You're overreaching — this is combinatorics wearing a physics costume."

**The ask.** Are you committing the sin you warned against (relabeling)?

**Rebuttal.** Yes if I *claim* the physics; no if I *offer* it. The paper
proves combinatorics and offers the quantum reading as a falsifiable mapping.
The test that separates costume from correspondence is: *does the mapping
predict something new, checkable, and non-tautological?* Here it does — the
composition law's coupling term `rightSpine l` is *not* forced by the physics
vocabulary; it is a specific combinatorial prediction (F-move depth grows by
the left output chain's length). If a fusion model refutes that term, the
correspondence is falsified. A costume cannot be falsified; a correspondence
can. I invite the falsification.

**Never do.** Do not retreat into "it's just an analogy" when challenged —
that collapses the contribution. Hold the line: *the combinatorics are proven,
the correspondence is specific enough to be wrong.*

