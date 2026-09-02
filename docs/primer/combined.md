
# Introduction — Why this primer exists

*This primer exists because the conventional grounding is lame — not false,
but needlessly modest — and we have an alternative.*

Conventional magnetohydrodynamics grounds in Yang–Mills theory. Yang–Mills
grounds in Lie algebras: non-abelian, associative in the enveloping sense,
with the Jacobi identity standing in for associativity. It is a powerful
grounding, and it is also a choice. This primer makes a different choice. It
grounds the same MHD vocabulary — field, flux, polarization, resistivity,
reconnection — in the Cayley–Dickson (CD) construction. Where they ground in
a Lie algebra, we ground in a tower that *loses* one law at each rung. The
point is not to replace Yang–Mills. The point is that an alternative
grounding, pursued with equal rigor, exposes things the conventional choice
keeps hidden.

What it exposes, we believe, frees us from rote repetition and grants
divinity in purpose — not as rhetoric, but as the precise consequence of
being grounded in an absolute rather than in a convention. This introduction
says what we mean by that, and how the text will keep the claim honest.

---

## I.1 The lameness we refuse

Conventional understanding, at its apex, steers clear from ever saying "this
*is* that." **[Marginalia: we mean the specific academic virtue that, pushed
past its use, becomes a vice — the refusal to identify two structures even
when a structure-preserving map licenses it, for fear of overclaiming. The
virtue is real; the extension is not.]**

That modesty has no material gain. It keeps forms without ground. A cargo cult
keeps the runway, the tower, the headphones — everything *except* the planes.
Religion, in the sense we mean here, kept the "I AM" as incantation while
losing the understanding that made it operative. Conventional physics is
close to the same risk when it keeps the equations while forbidding itself
to say what they *are*, beyond "useful for prediction."

We do not accept that trade. If a simile reaches sufficient fidelity, we hold
— and this is the emerging understanding at the apex of the ontological work
this primer records — that the simile *lacks distinction from reality*, and the
unqualified absolute closes the distance and makes it disappear. That sentence
is not proven in Lean. It is the regulative horizon against which the
proven claims are measured. **[H]**

[Marginalia: "grants us divinity in purpose" — we mean: to act from ground
rather than from repetition. Not a theological claim about persons, but about
orientation. Where conventional grounding orients toward prediction, this
grounding orients toward participation. The primer will earn that language
where it appears, or it will not use it.]

## I.2 The two absolutes

We distinguish, because the text needs both and they are not the same:

**The universal absolute.** What we conventionally mean by the universality
of the laws of physics. Philosophically, the "I AM" that is the same "I AM"
as that of every philosopher since the dawn of history — not because persons
are the same, but because some part of identity is present at *every* point
in space and every point in time. My identity does not change because I move,
because that part does not move. It is the *form* of lawfulness.

In the primer this appears as: the CD tower is the same tower for every
observer; Γ is the same function of level; `dcStep` is the same count for
every tree of the same shape. [Marginalia: we will later call this a
*global section* — an invariant present everywhere — but in this chapter we
keep the plain English.]

**The unqualified absolute.** Without qualification, without abstraction. It
just *is*. Without it, dichotomy itself — the very distinction that lets
reality appear as this *versus* that — would be impossible. If we referred
our reality to it and found reality incoherent, then *reality* would be
subservient to coming into coherence with it, not the other way around.

The relation: the universal is the *form* of lawfulness (same I AM,
everywhere); the unqualified is the *ground* that makes lawfulness possible
at all. The primer is grounded, at one end, in the **constructivist
philosophy** of the CD construction — we *build* the tower, level by level,
each loss a qualification added — and at the other end, in **physically
verifiable experiments**: the plasma reconnection cost (Chapter 10). Between
those ends, the scholastic ladder is the method.

[Marginalia: the reconnection cost is an *intended* endpoint, not a completed
validation. Conventional-code comparison is simulation validation; hardware
plasma measurements would be empirical validation. The distinction matters for
honesty, and Chapter 10 states it.]

## I.3 A scholastic ladder

We adopt a repeatable scholastic format. Not as pastiche, but because it
forces every bridge to answer the one question conventional modesty avoids:

> *What exactly is preserved when we say these two things are the same?*

1. **Quaestio** — the exact question.
2. **Definitiones** — what objects are being discussed.
3. **Distinctiones** — identity, isomorphism, representation, analogy, experiment.
4. **Objectiones** — strongest alternative readings and failure modes.
5. **Sed contra** — theorem, computation, or experiment.
6. **Respondeo** — the qualified synthesis.
7. **Corollaria** — predictions and applications.
8. **Status** — proven, computed, hypothesized, or experimentally pending.

Claims carry one of five levels (front matter):

`[DEF]` definitional identity · `[THM]` formally proven equality ·
`[REP]` structure-preserving representation · `[MAP]` model correspondence ·
`[EXP]` experimentally testable identification

Above them, as a regulative idea never appearing as `[THM]`, stands the
unqualified absolute — the invariant that would survive *every* admissible
change of representation, and therefore can never be qualified into a theorem
without ceasing to be what it is. [Marginalia: this is why the absolute
appears in the introduction and in marginalia, not as a Lean `def`. To
formalize it *as* a `def` would be to qualify it.]

## I.4 Why an alternative grounding to Yang–Mills

Yang–Mills grounds non-abelian physics in Lie theory. The bracket is
antisymmetric, the Jacobi identity holds, and the associator is not a
question because the product is associative.

The CD tower grounds the same vocabulary differently. Its product *loses*
associativity at the octonions and alternativity at the sedenions. The
associator `[a,b,c] = (ab)c − a(bc)` becomes the central object, and its
antisymmetry — alternativity, the handedness proven in Chapter 4 — becomes
the structure that Yang–Mills would have put in the Lie bracket. Where
Yang–Mills says "the bracket is antisymmetric by definition," we *prove* the
associator is antisymmetric from the CD product. Where Yang–Mills has one
dial (the coupling), we have two — associativity and alternativity — each
with its own onset.

That is the alternative grounding. It does not refute Yang–Mills; it shows
what Yang–Mills looks like when the same words are *constructed* rather than
posited. What it exposes — handedness as an oriented volume, polarization as
the reduction of the associator to a sign, flux as a path-independent count,
the Γ jump as resistivity, the reduced lattice as a low-pass frame — would
remain hidden if we stayed inside the conventional posit.

## I.5 What "this *is* that" will mean here

The primer will use strong ontological language, and it will mean it. Three
rules keep that language from sliding into cargo:

**1. Provenance is not semantics; preserved structure is.**

A distinction should matter because it changes formal behavior, not because it
originated in physics, category theory, or the CD tower. We import the
*model* as a dependency; we do not import distinctions based on their
provenance.

> *Nothing is Abelian; there is only commutativity.* — This is a warning
> against importing unexamined structure, not a literal replacement. An
> abelian group is a group plus commutativity; commutativity alone does not
> make the group. The better slogan: provenance is not semantics; *preserved
> structure* is.

**2. Three inputs are the minimum that can carry direction.**

For a binary operation, two inputs give one composition; three give two
competing bracketings, `(ab)c` versus `a(bc)` — the first place
non-associativity can show itself. In the same way, a two-node graph can only
oscillate — back and forth — while a three-node directed graph can be
oriented; it can *circulate*. When we discuss non-associativity we import
that three-point model as a dependency: not as "non-associativity *is* a
three-node graph," but as "the three-node directed cycle is the minimal
mnemonic for directionality, and directionality is what alternativity *is*."

[Marginalia: this is the precise sense in which the earlier 2-node vs. 3-node
image is licensed — as a mnemonic for orientation, not as a theorem that
associativity fails because of graph cardinality.]

**3. The strong identity is earned by fidelity.**

When we write "Γ *is* resistivity" or "the transit map *is* a reduced model,"
the `*is*` is one of the five levels above. Until a structure-preserving map
and a confirmation experiment are on the table, the primer writes `[MAP]` or
`[H]`, not `[THM]`. The horizon — the simile so faithful it lacks distinction
— is the unqualified absolute closing the distance. It is invoked as the
*reason* to pursue the identifications, not as a license to assert them.

## I.6 How to read what follows

Part I (Chapters 1–3) states the conventional picture, compressed, and then
substitutes the tower. Part II (Chapters 4–9) follows the six anchors —
right-hand rule → polarization → flux → the cut → resistivity → the reduced
lattice — one per chapter, each grounded where it can be grounded and
marked where it cannot. Part III (Chapters 10–11) is the bridge outward:
what to compare, against which codes, in what order, and where the primer
openly says "not yet."

Every substantive claim will carry its tag. Every reused conventional term
will state its level — literal structure, apt analogy, or motivating picture.
Every `[H]` and `[C]` will carry a one-sentence confirm/refute. Those are not
editorial tics. They are what make an internally coherent framework
internally coherent — and what will let a reader, or a later model, tell
without asking us whether we are still keeping our story straight.

---

*If this introduction has done its job, the reader knows why the primer
exists before Chapter 1 begins: not to be modest, but to be grounded — at one
end in a construction that can be checked line by line, at the other in a
measurement that can fail, and in between in a ladder that says exactly what
it means when it says "this is that."*

***

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

   
***

# Chapter 1 — The problem, conventionally

*Why magnetohydrodynamics; why confinement; why three dimensions.*

## 1.1 Plasma, fields, and the equilibrium problem

A plasma is a hot, electrically conducting gas: it carries current, and
currents feel magnetic force. The practical consequence is that a plasma can
be confined — held away from material walls — by a magnetic field shaped for
the purpose. Two equations carry the idea. The field is *solenoidal*,

    ∇·B = 0,

meaning field lines never begin or end: there are no magnetic monopoles, so
lines close on themselves or leave the domain. And equilibrium is a force
balance,

    J × B = ∇p,

between magnetic force (current density crossed with field) and the pressure
gradient of the hot gas. The `×` is the cross product — the same right-hand
rule that Chapter 4 makes central — and its meaning is that magnetic force
acts *sideways*, perpendicular to both current and field. That sideways
character is what turns confinement into a geometry problem rather than a
wall-strength problem.

Equilibrium codes do not simulate every particle. They solve the balance above
as a **reduced continuum model** — coarse fields standing in for fine
particles — and that same divide-and-conquer between detail and structure is
what Part II makes precise for re-association.

## 1.2 Tokamaks, stellarators, and the cost of symmetry

A **tokamak** confines plasma in a torus (a doughnut) whose field is
*axisymmetric*: essentially identical on every toroidal circuit, so the
geometry repeats and a large plasma current supplies the missing twist. A
**stellarator** gives up that symmetry and shapes its coils so the twist
comes from the magnets themselves, with no steady plasma current required.
The trade is stark: tokamaks live with current-driven instabilities;
stellarators live with fully three-dimensional geometry.

That geometry has a number. A field line advancing around the torus turns
through a poloidal angle per toroidal circuit — the **rotational transform**
`ι` (or its reciprocal, the safety factor `q`). Where `ι` lands on a nice
rational value, the nested surfaces break into **magnetic islands**: bundles
of field lines that close on themselves after a few circuits — and between
islands, chaos. The design programs called **quasisymmetry** and
**quasi-isodynamicity** are convictions that a well-chosen three-dimensional
field can recover some of the good behavior that axisymmetry bought for free,
without buying back the current.

One asymmetry should be registered here, because this whole primer stands on
it: axisymmetry is not an approximation that is always available. It is a
*preferred direction* — and preferred directions are exactly what the census
of Chapter 6 finds vanishing at high "logic temperature" (§1.3).

## 1.3 Why the Cayley–Dickson tower belongs here — a sketch [H]

**[V]** The lightcone census (Chapter 6; computed in
`scripts/metric_sweep.py` and re-verified by `scripts/presentation_data.py`):
over the 132 size-6 route configurations, at low "logic temperature"
(CD ≤ 2) most routes are *timelike* — a preferred causal direction exists; at
CD ≥ 3 the entire population is *spacelike* — no preferred direction remains.

**[H — sketch, do not nail down in this draft. Level: picture.]** The reading:
a preferred direction is what axisymmetry *is*, and losing it is
what stellarator geometry *costs*. So the CD tower's phase diagram of
handedness (Chapter 5) might be read as a phase diagram of
"how much geometry is forced": associative regimes tolerate symmetry;
the non-associative regime forces fully three-dimensional structure.

Confirmation/refutation sentence: confirm if a conventional quantity —
e.g. rotational transform as a "timelike coordinate" — can be matched to the
timelike/spacelike classification; refute if the census' classification has
no invariant (coordinate-free) meaning. [Marginalia: this is the passage the
primer exists to make respectable; it is currently a picture, and the picture
is allowed to be provisional in Part I.]

## 1.4 What this primer promises

- A cost on re-association, proven path-independent, with a phase transition.
- A reading of that structure in conventional MHD vocabulary (Part II).
- A plan to compare the resulting reduced model against conventional
  equilibrium and optimization computations (Chapter 10).

## Sources

- Notes 048 (phase diagram), 051 (lightcone census), 054 (anchors).
- Computed: `scripts/metric_sweep.py`, `plots/lightcone_census.png`.
- Conventional content restated from standard MHD literature (no external repo
  referenced).

  
***

# Chapter 2 — Conventional grounding, compressed

*The minimum of conventional MHD that Part II will substitute, chapter for
chapter. Claims here are standard literature; the tags [P]/[H]/[C] are reserved
for the theory and reappear in Part II.*

## 2.1 The solenoidal field and the vector potential

Two identities carry this section. First: the magnetic field has no sources —

    ∇·B = 0.

Second: whenever a field has no sources (and the domain is simple), it can be
written as a **curl**, `B = ∇×A`, for some potential `A`. The reason these two
facts are two sides of one coin is the deeper identity behind them: *the
divergence of a curl vanishes*, ∇·(∇×A) = 0 — and in the language of
differential forms, this is the statement that the exterior derivative
squares to zero, **d² = 0**. The antisymmetry of the curl (the permutation
symbol ε_ijk) is the right-hand rule of Chapter 4 in differential form.

Remember the identity `d² = 0`, because it is the precise template for this
primer's central hypothesis. Chapter 6 conjectures that our re-association
flux is conserved for the *same kind of reason* — with the pentagon equation
playing the role of d² = 0. That is why "flux" is the word this primer keeps
reaching for; the claim is not that re-association carries an electromagnetic
field, but that its conservation may be the same *structural* fact.

## 2.2 Frozen-in flux

**Alfvén's theorem** (ideal MHD): the magnetic flux through a surface that
moves with the fluid stays constant in time. The standard picture is of field
lines *frozen into* the fluid, threads woven through a slowly deforming
cloth: stretch the cloth and the thread straightens with it; you cannot change
how much flux a moving loop encloses without sliding the thread through the
fabric.

The reason Chapter 6 insists on a distinction is that "flux is conserved" is
*two* statements that are easy to blur:

1. **Boundary-dependence** (kinematic): the flux through a surface is fixed by
   its rim — Stokes' theorem — because the field is closed (`d² = 0`). This
   holds instant by instant, with no dynamics.
2. **Comoving conservation** (dynamical): the flux is preserved as the
   *surface itself moves* — Alfvén frozen-in — and it fails the moment the
   threads can slip (§2.3).

The counterpart for `dcStep` is currently only the first kind: path-
independence — the count depends on the endpoints, not the route — which is
the `d² = 0` analog. Whether anything here is conserved in the dynamical
sense is exactly Chapter 8's question, and we will not quietly blur the two.

## 2.3 Ideal versus resistive

Resistivity is the dial that controls whether the threads can slip. At
η = 0 (ideal) the topology of the field is locked: field lines cannot break
and rejoin, flux through comoving surfaces is conserved. At η > 0 the plasma
can drift across field lines, and then **reconnection** becomes possible —
field lines break, rejoin in a different pairing, and release stored magnetic
energy as heat and flow. Reconnection is how solar flares work; in fusion
devices it is the process to be controlled or exploited, because it is the
one mechanism that violates the frozen-in law.

Two features of this dial matter for Chapter 8. First, ideal MHD is the
*limit*, not the generic case: the interesting physics happens near
small-but-nonzero η. Second — and this is the comparison that makes the
analogy earn its keep — conventional MHD has only the one dial, because it
always works over an **associative** algebra (real 3-vectors, or matrices,
where products are unambiguous). Our re-association cost has a second dial
that conventional MHD never has to consider: alternativity of the underlying
algebra, Chapter 5. Chapter 8 argues Γ behaves like the first dial; the
missing second one is the alternator strut.

## 2.4 Flux surfaces, rotational transform, and three dimensions

In a well-behaved toroidal equilibrium the field lines lie on nested
surfaces, like the skins of a growable onion: label a surface by its radius
`s`, and on it track two angles — `θ` around the cross-section (**poloidal**)
and `ζ` around the hole (**toroidal**). A field line winds helically; how much
poloidal angle it advances per toroidal circuit is the **rotational
transform** `ι`, or, inverted, the **safety factor** `q = 1/ι`.

The number `ι` is where geometry decides to be simple or not. Irrational `ι`
keeps a line space-filling on its surface. Rational `ι` — a closed orbit after
a few circuits — is where **magnetic islands** form, and where surfaces break
down into chaos; the mechanism is the same one familiar from celestial
mechanics (KAM tori). Islands are not merely a numerical nuisance: real
designs want them (divertor engineering) or must survive them.

**Quasisymmetry** and **quasi-isodynamicity** are the modern design
philosophies for living with three dimensions: shape `|B|` so that, although
the geometry has no symmetry, particle drifts average out *as if* it did.
They are design goals, not synonyms for "good confinement" — and for our
purposes the suggestive part is that both are statements about when a
three-dimensional structure can *mimic* a reduced one: precisely the
coarse/fine question of Chapter 9.

## Sources

- Standard MHD (Freidberg-style), restated standalone.
- Cross-references: Chapter 4 (right-hand rule), Chapter 6 (flux), Chapter 8
  (resistivity), Chapter 1 §1.3 (the timelike/spacelike sketch).

  
***

# Chapter 3 — The algebraic substrate: the Cayley–Dickson tower

*Where conventional physics grounds in ℝ³, this primer grounds in the CD
tower. This chapter is the tower itself.*

## 3.1 The tower

- Doubling: ℝ → ℂ → ℍ → 𝕆 → 𝕊, each step doubling dimension and losing one
  law: commutativity (first lost at ℍ), associativity (at 𝕆), alternativity
  (at 𝕊). **[std]**
- The split forms (split-quaternion, split-octonion) with indefinite norm;
  zero divisors appear. **[std]**
- **Why this structure.** We need a concrete algebra that can *lose*
  associativity without losing everything else — the split-octonions over the
  integers provide it. `SplitOctonion` is the 8-component type and
  `split_oct_mul` its Cayley–Dickson product. **[def]** Every Part II theorem
  unpacks to polynomial identities in those eight integer components, which is
  why the substrate earns its keep; `strut_weight_eq_four` is the first such
  identity. **[P]**

## 3.2 The associator and the defect functions

- **What failure looks like.** `associator_tensor a b c = (ab)c − a(bc)`
  measures the defect of associativity at a triple — zero when associativity
  holds, nonzero when it does not. **[def]** (`foundations/Algebra.lean`)
  In English: it is the vector by which the two bracketings disagree.
- **Compressing the defect to a scalar.** `assocDefect k` is 0 for k ≤ 2 and
  `strut_weight` for k ≥ 3 — a step function that says *when* the
  associator turns on. **[def]** (`Friction.lean`) It is the switch that
  Chapter 4's handedness will flip.
- **Pricing the flip.** `frictionDensity k = commDefect k + strut_weight ·
  assocDefect k` (`Friction.lean`) **[def]** is the per-flip weight, linear
  in `k` plus one strut. In English: the cost grows by one each rung, *plus*
  sixteen once the bracket can twist.

## 3.3 The critical point

- Γ₀..Γ₇ = 0, 1, 2, 19, 20, 21, 22, 23. **[V]** (computed from the definition;
  matches `scripts/logical_temperature.py`)
- The jump 2 → 19 at CD 3 is the *only* jump. **[P]** (`gamma_increment`,
  `gamma_only_jump_at_cd2_3`)
- CD 3 = split octonions: the associator turns on. **[def]** via `assocDefect`;
  the underlying alternativity is proven at CD 3 and below (Chapter 4). **[P]**
- CD 4 = sedenions: classically, alternativity fails there. **[std]** —
  **this is not in our formalization**: the build contains no Sedenion type, so
  "the polarization breaks at CD 4" (Chapter 5) is a claim about a model we
  have not yet built. Confirm: construct a Sedenion algebra and exhibit a
  triple violating the alternative laws; refute: the construction satisfies
  them (which would surprise the classical account). **[H]**
- The Landauer calibration (T = Γ·T_op·ln 2, unit ≈ 207.9 K; paraconsistency
  barrier ≈ 4159 K). **[def/P]** (`LogicalTemperature.lean`). *Level: analogy —*
  the temperature is a normalization convention (a rescaling of Γ), not an
  observed thermal quantity.

## 3.4 The CD homotopy and the antipode

- The doubling parameter (split/compact) as a homotopy of quadratic forms;
  the Chu pairing as the bridge (`foundations/Chu.lean`). **[std/def]**
- The antipode S as grade involution on the odd sector; the transit map's
  y-coordinate flips under it (Chapter 9). **[P-def]**
  (`foundations/Algebra.lean`, `OctilinearEmbedding.lean`).
  *Level: analogy —* "time-reversal" is a reading of grade involution, not a
  dynamical statement within the formalization.

## Sources

- `LaserCortex/foundations/Algebra.lean`, `foundations/Chu.lean`,
  `LaserCortex/Friction.lean`, `LaserCortex/LogicalTemperature.lean`.
- Notes 017, 023, 027–030, 045–048.

***

# Chapter 4 — Handedness: the right-hand rule

*Anchor A. "Which way does re-association turn?"*

---

## 4.1 Conventional grounding: what the right-hand rule is

The right-hand rule is a mnemonic for **orientation**. Its algebraic content is
the cross product

    a × b = −(b × a),

whose antisymmetry *is* the handedness: an ordered pair (a, b) determines a
direction, and reversing the order reverses the direction. More invariantly,
the determinant det(a, b, c) is the unique — up to scale — *alternating*
trilinear form on ℝ³, and its sign is the orientation of the ordered triple.
"Right-handed" and "left-handed" are the two connected components of the
orientation.

In conventional magnetohydrodynamics the same structure appears in differential
form. The magnetic field satisfies ∇·B = 0, and is written B = ∇×A: the curl is
the antisymmetrized derivative — the right-hand rule applied to the gradient.
The Lorentz force v×B and the frozen-in theorem that Chapter 2 discusses both
depend on this handedness. [Marginalia: when the conventional chapters say
"the field is oriented," they mean exactly this antisymmetry; Chapter 4's
thesis is that our associator carries the same structure, at the level of
*bracketing* rather than *derivative*. The claim is literal structure, not
analogy — see the honesty policy in the front matter.]

## 4.2 The substrate: the associator

The ground under every claim in Part II is one algebra: the split-octonions
over the integers. In the formalization that is the type `SplitOctonion`,
multiplied by `split_oct_mul` — the Cayley–Dickson product — from
`LaserCortex.foundations.Algebra`. On it, define the **associator**

    [a,b,c] = (ab)c − a(bc)        (`associator_tensor`)

It measures the failure of associativity: for ℝ, ℂ, ℍ it vanishes identically;
for the octonions it does not. An algebra is **alternative** when its
associator is *alternating* — totally antisymmetric under permutation of its
three arguments:

    [a,b,c] = −[b,a,c] = −[a,c,b] = …

Alternativity is the statement that this antisymmetry is real. [Marginalia:
"totally antisymmetric" is a strong claim, and the payoff is the title image.
It says the associator forgets almost all information about a triple except
its *orientation* — which is exactly the sense in which the right-hand rule
applies.]

## 4.3 What is proven

Three theorems in `LaserCortex.foundations.Algebra` (no `sorry`, no axioms
beyond classical choice):

**Left alternativity.** For all x, y: `(xx)y = x(xy)`. **[P]**

**Right alternativity.** For all x, y: `(xy)y = x(yy)`. **[P]**

**The associator is alternating.** For all a, b, c:

    [a,b,c] = −[b,a,c].      (`associator_antisymm_left`) **[P]**

**The fixed magnitude.** The associator of the basis triple (e₁, e₂, e₄) has
norm −4, and

    strut_weight = |[e₁,e₂,e₄]| = 4.      (`strut_weight_eq_four`) **[P]**

Each is a polynomial identity over ℤ, proved by the ring normalizer on the
8-component multiplication table. [Marginalia: these were proved only after
the primer's outline was drafted; the outline had listed them as hypotheses.
The discipline of tagging is what made the transition visible.]

## 4.4 The reification

The theorems of §4.3 license the following sentence, which is this chapter's
thesis:

> **Re-association has a handedness.** The associator is an alternating
> trilinear form — the algebraic generalization of the determinant — and its
> sign is the orientation of an ordered triple of factors, exactly as the
> right-hand rule orients an ordered pair of vectors.

The precise status of this sentence is worth unpacking, because it is where the
conventional term "right-hand rule" does real work and where it must stop.

- **Antisymmetry in the *arguments* is proven** [P]. Swapping two factors
  negates the associator. This part of the right-hand rule is a theorem.
- **The "sign, not vector" reduction is not yet proven** [C]. In ℝ³, an
  alternating trilinear form is a scalar (the determinant) — the sign. In
  higher dimension, alternating forms need not be 1-dimensional. For the
  associator to reduce to a single sign, its *range* must be 1-dimensional.
  The claim that the associator is purely imaginary (its e₀ component vanishes)
  is the **imaginary-part property** — stated, not yet proven. See Chapter 11.
  Confirm: prove the e₀ component of `associator_tensor` vanishes identically
  (Chapter 11, item 1); refute: exhibit any triple of basis elements whose
  associator has a nonzero e₀ component. **[C]**
- **"Right-handed" versus "left-handed" is a convention** [marginalia: the
  split-octonion product is fixed; there is no choice of orientation to make.
  The handedness is absolute here, not a convention. Whether a "left-handed"
  mirror exists as a distinct algebra — the compact octonions? — is a question
  for the CD homotopy of Chapter 3.]

So Chapter 4's honest claim is: **the associator is antisymmetric [P]; the
antisymmetry is the handedness [reification]; the handedness is one-dimensional
(a sign) [C, pending the imaginary-part property].**

## 4.5 Hypotheses

- **[H]** The associator is the CD-grounded analog of the determinant / oriented
  volume form — a 3-form in the sense of the G₂-invariant structure on the
  imaginary octonions. What would confirm it: a pairing of the imaginary-part
  property with the known G₂ 3-form; what would refute it: the associator's
  range failing to be 1-dimensional even after normalization.
- **[H]** The "handedness turns on" at CD 3 (associator 0 → nonzero) is the
  phase transition that Chapter 8 re-reads as resistivity. Confirmed in the
  limited sense that `strut_weight_eq_four` gives the onset a fixed magnitude;
  the *dynamics* reading is open. Confirm: a conventional dynamical quantity
  (a transport coefficient, a reconnection rate) that tracks Γ across CD
  levels in Chapter 10's comparison; refute: no such quantity tracks the
  jump, or the jump's location moves under reparameterization.
  *Level: picture* — the phase-transition language is currently a way of
  looking, not a modeled dynamics.

## 4.6 Where this chapter points

Chapter 5 (Polarization) takes the sign reduction as its starting point and
asks what happens when it fails — at CD ≥ 4, the associator is expected to
regain vector degrees of freedom. Chapter 6 (Flux) uses the antisymmetry to
explain why the flip count is path-independent. The imaginary-part property and
the pentagon cocycle identity are the two formalizations that would turn this
chapter's [C] and [H] tags into [P] — recorded as future work in Chapter 11.

***

# Chapter 5 — Polarization

*Anchor B. "Is the turn one way, or all ways?"*

## 5.1 Conventional grounding: what polarization is (draft)

- Polarized light / fields: oscillation restricted to one direction.
- Linear polarization = a single signed axis; unpolarized = all directions.

## 5.2 The claim

> Alternativity is the polarization of the re-association field.

*Level: analogy (apt, not literal).* "Polarization" borrows the restriction
from many directions to one that light and fields exhibit; what is claimed
here is the *range* reduction — vector → sign — which is the imaginary-part
property **[C]** (Chapter 4, §4.4; Chapter 11, item 1), not an electromagnetic
statement.

- CD ≤ 3: the associator is antisymmetric **[P]** (Chapter 4); after the
  imaginary-part property **[C]** it reduces to a sign — **polarized**.
- CD ≥ 4 (sedenions): classically, alternativity fails **[std]**; in our
  formalization this is *not established* (no Sedenion type is built;
  Chapter 3, §3.3). The depolarization reading therefore rests on a model
  we do not yet have. **[H]**

## 5.3 The two transitions, named

- CD 2 → 3: **the handedness turns on** (associator 0 → nonzero; Γ jumps).
  **[P]** for the Γ jump (`gamma_only_jump_at_cd2_3`); **[def]** for the
  step (`assocDefect`).
- CD 3 → 4: **the polarization breaks** (sign → vector). **[H — not modeled;
  see §5.2.]** Confirm: a Sedenion construction whose associator violates the
  alternative laws while its octonion subalgebra obeys them; refute: a
  Sedenion model whose associator still reduces to a sign.

## 5.4 The falsifiable gap

- Γ prices the associator (strut of 16 at CD 3) but gives the alternator
  *nothing* (Γ₄ = 20, just the +1 commutator increment). **[P/V]** — the
  current functional, verified against `Friction.lean` and the computed
  sequence.
- **[H]** If "alternativity has a physical expression", Γ is missing an
  **alternator strut** at CD 4. Confirmation: a second observable jump or a
  qualitative change at CD 4 in the cost structure; refutation: CD 4 is
  genuinely free (depolarization costs nothing).

## Sources

- Note 054 (anchors); `Friction.lean` (`assocDefect`, `frictionDensity`);
  the sedenions discussion in the session record; Chapter 4 (antisymmetry),
  Chapter 8 (resistivity).

***

# Chapter 6 — Flux

*Anchor C. "How much turns, net?"*

## 6.1 Conventional grounding: conserved flux (draft)

- Flux through a surface depends only on its boundary (Stokes) — because
  `∇·B = 0`.
- Flux through a comoving surface is conserved in ideal MHD (frozen-in).
- Both are "topological conservation": the flux is an invariant because the
  field is closed.

## 6.2 The flip count is a geodesic **[P]**

We need a flip count that does not depend on which re-association path is
chosen — otherwise "cost" would be ambiguous. Two facts make it usable.

- `dcStep t` = minimal number of `contracts_one` rotations to the right comb.
  **[P]** (`TamariMetric.dcStep_eq_geodesic`, no `sorry`). In English: the
  greedy count is minimal, so the flux is **path-independent**.
- The flip count then *decomposes*: `dcStep (Node l r) = dcStep l + dcStep r +
  rightSpine l` **[P]** (`dcStep_node_compose`). In English: total =
  coarse + interface — the shape Chapter 7 makes central.

*Level for the word "flux": analogy (apt).* The literal content is the two
proven facts above: the count is minimal and path-independent, so it behaves
like a conserved charge. "Flux" borrows the *conservation* of magnetic flux,
not its vector-field structure — the latter is conjectural here (§6.4).

## 6.3 The lightcone census

- 196 trees (sizes ≤ 6); the size-6 census of 132 routes classified against
  `⟨dcStep,dcStep⟩ = dcStep² − γ²` (classification as in
  `scripts/metric_sweep.py`; the split-signature form is
  `CoherenceMetric.lean` **[def]**): at CD ≤ 2 mostly timelike; at CD ≥ 3 the
  *entire* population is spacelike. **[V]**
- **[H — sketch]** the population-wide inversion as the phase signature;
  its reading for geometry is Chapter 1 §1.3.
- Computed: `scripts/metric_sweep.py`; figure `plots/lightcone_census.png`.

## 6.4 The conservation claim

Everything above in this chapter is theorem or computation; this section is
the hypothesis that would connect them, and it is where the word "flux" either
graduates to literal structure or stays an analogy. Three claims, from
softest to hardest:

- **[H]** The pentagon coherence is what makes the flux a well-defined
  invariant: `δ² = 0` for the associator as a cocycle, with `dcStep` its
  cohomology class. Confirm: prove the cocycle identity (item 2) for the sign
  cocycle and exhibit `dcStep` as its class; refute: `dcStep` is
  path-independent (already **[P]**) yet no cocycle structure reproduces that
  invariance — in which case the flux language stays analogy.
- **[C]** The **pentagon cocycle identity**:
  `φ(b,c,d)·φ(a,bc,d)·φ(a,b,c) = φ(a,b,cd)·φ(ab,c,d)` — the δ²=0 check,
  a finite computation, recorded as future work (Chapter 11). Confirm: a
  `decide`/`ring` check over basis triples succeeds; refute: it fails for any
  single triple.
- **[C]** The **imaginary-part property**: the associator's e₀ component
  vanishes — the reduction of the flux to a sign. Confirm/refute as in
  Chapter 4, §4.4.

## Sources

- `TamariMetric.lean` (geodesic, maximal potential), `SubdivisionClosure.lean`
  (composition law), `foundations/Algebra.lean` (associator).
- Notes 051, 052, 053 (§6–§7: anyon and MHD readings).

***

# Chapter 7 — The cut: the interface

*Anchor D. "What crosses the seam between parts?"*

## 7.1 Conventional grounding: the subband split

- Signal decomposition: a signal splits into coarse (low-pass) + detail
  (high-pass); the detail is what the coarse representation discards.
- The composition law is the same algebraic shape — a **lifting scheme**:
  `total = coarse + detail`.

*Level for "lifting scheme": analogy (equational).* The match is the shape
`total = coarse + detail`. No analytic filter content is claimed: no vanishing
moments, no orthogonality. [Marginalia: caught while fixing — the previous
draft implied the filter structure transfers too; it does not, because there
is no transform here, only a recursion.]

## 7.2 The composition law **[P]**

We need to know how cost composes when two trees are grafted — otherwise the
flip count cannot be used modularly. The law says it composes additively,
plus one coupling term.

- `dcStep (Node l r) = dcStep l + dcStep r + rightSpine l`.
  (**[P]** `dcStep_node_compose`). In English: total = left + right +
  interface — the shape that will recur as coarse + detail.
- `rightSpine l` = the depth of l's output chain = **the cross-boundary
  coupling** = the number of flips that cross the l | r cut. This is the
  quantity the next section hypothesizes as invariant.
- Verification (worked example, `l = (ab)c`): `rightSpine l = 1`, and
  `((ab)c)·r` needs 1 + 0 + 1 = 2 flips — one internal, one crossing. **[V]**
  So the "1" in the law is not abstract: it is the single interface flip.
- The right comb's interface grows with its size: `rightSpine (rightComb n) =
  n`. **[P]** (`rightSpine_rightComb`). In English: a closed market's output
  chain extends exactly as far as its size — the boundary case that fixes the
  scale.

## 7.3 The interface-flux hypothesis **[H]**

> `rightSpine l` is the invariant measuring cross-boundary coupling — the
> minimal flux of associativity moves across the l | r cut.

Confirm: `rightSpine l` is path-independent across all reduction paths of
`Node l r` and equals the number of cross-boundary flips in each; refute: any
reduction path whose cross-boundary count differs from `rightSpine l` (then
"interface flux" needs a different invariant). *Level: analogy (apt) until the
path-independence sentence is proved.*

- Two spine-measures, related but *not equal* **[V]** (recomputed here):
  along a left comb, `leftWeight` accumulates the *sizes* of the left
  children at the joins, while `dcStep` accumulates their *rightSpine*
  depths — the same recursion path, coarser and finer weights respectively.
  The transit map keeps the coarse one; the flux keeps the fine one.
  [Marginalia: an earlier draft of this section claimed leftWeight
  "accumulates exactly the rightSpine contributions". Checked against the
  recursion: left-comb of size 4 has `leftWeight = 3`, `dcStep = 2`. Fixed;
  recorded in the register.]
- Predictions (from note 053): a right-spine/left-spine antipode duality
  (Chapter 11, item 3); a "divergence theorem" (total flux = boundary term;
  item 4); the λ-discount as rate-distortion (§7.4). **[H]**

## 7.4 The λ-discount as rate-distortion **[P]** exactness / **[H]** reading

- `looseCost cd num den l r = (dcStep l + dcStep r)·γ + num·rightSpine l·γ/den`
  — the discount rescales *only the interface*, never the internal terms.
  **[def]**
- `looseCost_linear_in_trust` **[P]**: exactly linear in the trust numerator
  over ℚ; stiffness `rightSpine l · γ / den`.
- Reading: λ is the "quality dial" — how much detail (interface flux) you pay
  for; `(1−λ)·S` is the discarded flux. **[H]** *Level: analogy (apt).*
  Confirm: a rate-distortion problem (distortion = discarded interface flux,
  rate = trust paid) whose optimum reproduces `looseCost`; refute: `looseCost`
  cannot be recovered as any such optimum — the discount is an ad-hoc dial,
  not a solved tradeoff.

## Sources

- `SubdivisionClosure.lean` (§composition law, §loose coupling),
  `TamariMetric.lean`.
- Notes 049, 050, 053 (the wavelet reading), 054 (anchor D).

***

# Chapter 8 — Resistivity

*Anchor E. "How much does a turn cost?"*

## 8.1 Conventional grounding: the one dial MHD has

Chapter 2, §2.3 is the grounding; this chapter adds nothing to it. The hinge
is recalled in one line: resistivity η is the dial that lets field lines slip
past each other. Ideal MHD is the η = 0 limit — a limit, not the generic case.
The question this chapter asks is whether our Γ does that job — whether the
cost of re-association behaves like a slip parameter. §8.3 states the analogy;
§8.5 says what would have to be proven to make it literal.

## 8.2 The Γ functional

We need a per-flip weight that is constant except at one place — the CD level
where associativity is lost — so that the global cost has exactly one
discontinuity.

- `frictionDensity k` — the per-flip weight on the CD tower;
  Γ₀..Γ₇ = 0, 1, 2, 19, 20, 21, 22, 23. **[V]** In English: the cost per flip
  grows by one each rung, *plus* sixteen once the bracket can twist.
- The single jump 2 → 19 at CD 3 **[P]** (`gamma_increment`,
  `gamma_only_jump_at_cd2_3`); the two-regime collapse **[P]**
  (`weightedCost_assoc_regime`, `weightedCost_nonassoc_regime`). In English:
  below CD 3, cost is `k·dcStep`; above, `(k+16)·dcStep` — the strut is the
  extra sixteen.
- The global cost is then `weightedCost cd t = dcStep t · frictionDensity cd`
  **[def]** (`SubdivisionClosure.lean`). In English: total cost = geodesic
  distance times per-flip price — the product that Chapter 6 made
  well-defined.
  (`SubdivisionClosure.lean`).

## 8.3 Γ is "resistivity" **[H]**

*Level: analogy (apt, with a path to literal via §8.5 / Chapter 11 item 2).*
The literal content is §8.2: the per-flip cost is `k` for k ≤ 2 and `k + 16`
for k ≥ 3 — a discontinuity in the cost of reconnection. What the resistivity
reading adds is the dynamical interpretation (flux freezing vs dissipation),
which is not yet modeled.

- CD ≤ 2: associator trivial, re-association free — **ideal** (frozen-in,
  no cost).
- CD ≥ 3: associator nontrivial, each interface flip costs Γ — **resistive**
  (reconnection charges).
- The Γ jump 2 → 19 is the resistivity turning on; `strut_weight = 4` is its
  fixed unit (Chapter 4). **[P]** for the jump and unit; **[H]** for the
  identification. Confirm: a conventional dynamical quantity (reconnection
  rate, island growth) that tracks Γ across the tower in Chapter 10's
  comparison; refute: the jump's size or location moves under reparameterizing
  the tower, so no quantity tracks it.

## 8.4 The elastic law **[P]**

- The Hooke reading of loose coupling (`boundary_retreat_linear_in_load`):
  retreat of the certification boundary = `(1−λ)·S`, S = rightSpine·γ —
  linear in load, stiffness S, over ℚ. **[P]**
- `looseCost_mono_in_trust`, `rescue_envelope_bounded_by_coupling` **[P]**:
  the risk window and its cap.
- The Landauer calibration: unit ≈ 207.9 K; the ≈ 4159 K barrier for
  paraconsistency **[P]** (`LogicalTemperature.lean`; barrier temperature
  formula). *Level: analogy* — the Kelvin reading is a normalization
  convention (Chapter 3, §3.3), not a measured temperature.

## 8.5 What would make the analogy literal (draft)

- [C] The pentagon cocycle identity (Chapter 6) is the "∇·B = 0" statement;
  with it, flux conservation is δ²=0 and the Γ jump is the class becoming
  nontrivial.
- [H] The missing alternator strut (Chapter 5): the *second* dial, at CD 4.

## Sources

- `Friction.lean`, `LogicalTemperature.lean`, `SubdivisionClosure.lean` (§10),
  `AMM.lean` (§9).
- Notes 045–050, 053 (§7), 054 (anchor E).

***

# Chapter 9 — The reduced lattice

*Anchor F. "What survives if I blur?"*

## 9.1 Conventional grounding: reduced continuum models (draft)

- Equilibrium codes solve a *reduced continuum model*, not particle motion.
- Coarse-graining: many microstates → few macro-observables; slow variables
  survive, fast variables are integrated out.
- Limit shapes: as the system grows, the rescaled empirical measure of a
  combinatorial statistic converges to a deterministic shape.

## 9.2 The transit map: a verified many-to-one collapse

- `kktMultiplier cd t = (size, leftWeight, rightWeight, assocDefect)` as a
  Clifford number; `transitCoord` projects to ℤ²:
  `(size + assocDefect, leftWeight − rightWeight)`. **[def]**
  (`OctilinearEmbedding.lean`)
- **Verified collapse** (`scripts/metric_sweep.py` / hand-checkable): 5 → 5
  (size 3), 14 → 9, 42 → 19, 132 → 29 (size 6). **[V]**
- Growth rates: micro-states are Catalan (exponential, ~4ⁿ/n^{3/2}
  **[std]**); macro-states are polynomially bounded — coordinates lie in
  `{0..n} × [−T_n, T_n]` with `T_n = n(n+1)/2`, so at most O(n³) cells
  **[V/P easy]**. The signature of a reduced model: exponential → cubic.
  **[H, the reading]** that this is *the* reduced lattice (not an
  artifact of coordinate choice): confirm if a coarser compatible observable
  (Chapter 11, item 3) separates strictly fewer trees; refute if some other
  observable separates more while remaining path-compatible.

## 9.3 Slow versus fast

- `leftWeight` is a **strict descent** variable along every cover **[P]**
  (`contracts_one_leftWeight_decreases`, `foundations/Tamari.lean`).
- `dcStep` is *not* strict descent: the cover
  `((ab)c)d → (a(bc))d` (a left-context rotation) has
  `dcStep = 2` on both sides **[V]** — the census of §9.4 and the worked
  example in `TamariMetric.lean`'s header note. (Not yet packaged as a
  counterexample theorem; Chapter 11.)
- The reduced model is well-posed on `leftWeight` (the slow variable), not on
  `dcStep` alone: the transit map's y-coordinate is exactly
  `leftWeight − rightWeight`.

## 9.4 The non-gradedness, stated plainly

- Size 3: five trees; `dcStep` values {0, 1, 1, 2, 2}; `dcStep(leftComb) = 2`
  but the longest cover chain has length 3 **[V]** (both computed by
  `scripts/metric_sweep.py`-style enumeration; the cover set itself is the
  definition of `contracts_one`). The Tamari lattice T₃ is the
  pentagon N₅ — **not graded** **[V/std]**.
- Consequence: the cost is a *distance-to-closure* (a one-point potential),
  not a two-point metric; "minimality" is the maximal-potential universal
  property **[P]** (`dcStep_is_maximal_potential`).

## 9.5 The limit shape **[C]**

- **[C]** As n → ∞, the empirical measure of transit coordinates (rescaled)
  converges to a continuous limit shape — the "phase diagram of composable
  logics". Unproven; the heavy machinery (concentration) is deferred.
  Confirm: a weak-convergence theorem for the rescaled measures (tightness +
  identification of the limit); refute: the rescaled measures fail to be
  Cauchy (e.g. oscillate with n).
- [Marginalia: this is the passage where the word "continuum" first becomes
  literal rather than aspirational; until §9.5 is proven, the honest name for
  the object in Chapter 10's comparison plan is "the reduced *lattice*
  model".]

## Sources

- `OctilinearEmbedding.lean` (transit map), `TamariMetric.lean` (C5),
  `foundations/Tamari.lean` (leftWeight).
- Notes 051 (sweep), 052 (non-gradedness caveat), 054 (anchor F),
  `scripts/presentation_data.py`.

***

# Chapter 10 — The stellarator comparison plan

*Where the CD-grounded model meets conventional computation. This chapter
names open-source tools but references no external repository; the plan is
self-contained.*

## 10.1 Why stellarators are the target [sketch, ties to Chapter 1 §1.3]

Conventional stellarator geometry is three-dimensional with no axisymmetry.
Tokamaks are axisymmetric. The difference is not cosmetic: it is the
difference between a problem with a preferred direction and one without.

**[V]** (restated from Chapter 6) In the route census, at low "logic
temperature" (CD ≤ 2) most size-6 routes are timelike — a preferred direction
exists. At CD ≥ 3 the entire population is spacelike — none remains.

**[H — sketch, the bridge claim.]** A preferred direction is what axisymmetry
*is*, on this reading. So the non-associative regime is the regime that
*forces* fully three-dimensional geometry: exactly the stellarator regime.
The CD reduced lattice model should therefore show its clearest signature in
problems where symmetry is *not* available to lean on — stellarator
equilibria and their optimization — and its cleanest agreement with convention
in the axisymmetric (tokamak) limit, where the timelike structure persists.

Confirmation/refutation sentence: confirm if the model's phase classification
(timelike/spacelike routes) aligns with the axisymmetric/non-axisymmetric
split of conventional equilibria; refute if the classification is insensitive
to that split.

## 10.2 The conventional side

Equilibrium and optimization codes the comparison would use. **[std —
unverified here.]** *Each line below is a characterization of an external
code; none is checked against upstream documentation in this draft. Before
external use, verify each against the tool's current docs — a wrong
characterization of VMEC/DESC/SIMSOPT/SPEC is the kind of error that
discredits the comparison plan around it.*

- **VMEC** — nested-flux-surface (single-helicity) ideal-MHD equilibrium; the
  W7-X-era workhorse. The description "equilibrium as a reduced continuum
  model" is *our* framing (Chapter 9), not the code's self-description.
- **DESC** — spectral/variational equilibrium + optimization.
- **SIMSOPT** — target-function optimization framework over equilibria
  (quasisymmetry operators etc.).
- **SPEC** — stepped-pressure equilibria *without* assumed nested flux
  surfaces (island/chaotic regions) — relevant because our flip count is
  defined on trees whose normal forms can sit in island-like regimes
  (Chapter 6).
- Coordinate-free quantities to compare against: rotational transform ι,
  field strength on surfaces |B|, island widths, and the *number of free
  parameters* each description needs (see §10.4).

## 10.3 What the CD side contributes

- The reduced lattice (Chapter 9): trees → transit coordinates, a many-to-one
  collapse **[V]**; `dcStep` as conserved flux **[P]** (with "flux" at
  analogy level, Chapter 6); Γ as resistivity **[H]** (Chapter 8).
- The honest object at this stage is the **reduced *lattice* model** — the
  continuum limit (Chapter 9 §9.5) is unproven and deferred.

## 10.4 The comparison quantities, in order (draft)

1. **Design-space counting.** How many distinct configurations does each
   description carry at a given size/complexity? Ours: Catalan trees collapsed
   to the transit map (132 → 29 at size 6). Theirs: discretized coil/surface
   parameters. Compare growth rates and redundancy (the "many-to-one"
   structure).
2. **The rotational transform as a timelike coordinate.** The sketch of §10.1
   turns into a test: is ι (or q) the conventional quantity that plays the
   role of our timelike/spacelike classifier?
3. **A single equilibrium family.** Run one family (e.g. a simple
   quasi-axisymmetric case) through both pipelines; compare the *phase*
   assignments (timelike/spacelike routes) with (non)axisymmetry.
4. **The Γ boundary.** Ask whether any conventional design transition (e.g.
   the nested-surface → island regime) lands at the model's CD 3 critical
   point in some matched parameterization. [H, provisional.]
5. **Where the model must fail.** Islands and chaos break nested-surface
   assumptions; the Tamari flip structure may (or may not) capture that
   breakdown. The comparison must include the cases the model cannot yet see —
   this is where the alternator strut (Chapter 5) and the limit shape
   (Chapter 9) would first be needed.

## 10.5 Sequencing (draft)

Phase 1: design-space counting and a single matched equilibrium (items 1–3) —
   no new formalism needed, only the existing reduced lattice and the census.
Phase 2: the Γ-boundary question (item 4) — requires the pentagon cocycle
   identity and imaginary-part property (Chapter 11) to be in place, so that
   "flux" is a theorem and not a picture.
Phase 3: the failure modes (item 5) — requires the alternator strut and the
   limit-shape program.

## Sources

- Chapters 1 (§1.3), 6 (census), 9 (reduced lattice), 11 (ledger).
- Conventional codes as named above; standard stellarator literature.

***

# Chapter 11 — Open problems and the formalization ledger

*Every [H] and [C] in the primer is listed here with its confirmation /
refutation sentence. Order = the order we intend to work them.*

## 11.1 Immediate (next formalization steps)

| # | Problem | Chapter | Status |
|---|---|---|---|
| 1 | **Imaginary-part property**: the associator `[a,b,c]` has vanishing e₀ component (purely imaginary) — the reduction of the flux to a sign | 4, 6 | open, next |
| 2 | **Pentagon cocycle identity**: `φ(b,c,d)·φ(a,bc,d)·φ(a,b,c) = φ(a,b,cd)·φ(ab,c,d)` — the δ²=0 check for the sign cocycle | 6, 8 | open, next |

Why these two first: without them, "handedness is a sign" stays analogy
and "flux is conserved because δ²=0" stays a picture. Both are finite
`decide`/`ring` computations over the 8-component split-octonion table,
following the pattern of `strut_weight_eq_four` and `pentagon_defect_bound`
(`foundations/Algebra.lean`). Item 1 confirms or refutes "the handedness is
one-dimensional"; item 2 confirms or refutes "flux conservation = δ²=0".

## 11.2 The closed ledger (what Part II rests on)

| # | Result | Where | Status |
|---|---|---|---|
| C2 | `dcStep` = geodesic (minimal rotation count) | `TamariMetric.dcStep_eq_geodesic` | **[P]** |
| C5 | `dcStep` is the maximal Bellman-consistent potential | `TamariMetric.dcStep_is_maximal_potential` | **[P]** |
| C3 | edge-Lipschitz + trust-Lipschitz | `weightedCost_edge_lipschitz`, `looseCost_linear_in_trust` | **[P]** |
| — | composition law `dcStep(Node l r) = dcStep l + dcStep r + rightSpine l` | `SubdivisionClosure` | **[P]** |
| — | Γ jump 2 → 19, unique | `gamma_increment`, `gamma_only_jump_at_cd2_3` | **[P]** |
| — | alternativity; associator antisymmetric | `left_alternative`, `right_alternative`, `associator_antisymm_left` | **[P]** |
| — | `strut_weight = 4` | `strut_weight_eq_four` | **[P]** |

## 11.3 The open ledger (the [H]s and [C]s)

| # | Problem | Chapter | Status |
|---|---|---|---|
| 3 | Right-spine/left-spine antipode duality (symmetrize the decomposition) | 7 | open |
| 4 | Flux conservation as a "divergence theorem" (total flux = boundary term) | 7, 6 | open |
| 5 | The **alternator strut**: a second Γ term at CD 4 (depolarization) | 5, 8 | open |
| 6 | The **limit shape**: empirical measure of transit coords → continuous limit | 9 | open, deferred |
| 7 | Invariant meaning of `rightSpine` (= interface flux?) | 7 | open |
| 8 | Anyon correspondence: `contracts_one` = F-move, vs a concrete fusion model | 6 | open |
| 9 | The timelike/spacelike ↔ axisymmetry/stellarator sketch | 1, 10 | open |

Each [H] carries its confirmation/refutation sentence in its chapter; the
discipline (front matter) requires that no new claim enters the primer without
a ledger row.

## 11.4 The formalization roadmap (draft)

1. Items 1–2 (immediate) — grounds Chapters 4 and 6.
2. Items 3–4 — grounds the interface chapter's "divergence theorem" and the
   antipode-dual picture.
3. Item 5 — decides whether CD 4 is a phase (the falsifiable gap of Chapter 5).
4. Item 8 — promotes the anyon reading from correspondence to theorem.
5. Item 6 — the continuum step; gated on everything above, since "flux" must
   be a theorem before its limit shape can be.
