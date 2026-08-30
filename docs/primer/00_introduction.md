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

## I.7 Coda — Seashell vs. coil: what "curled up" should mean

A reader unfamiliar with the subject will have heard one picture: the extra
dimensions of string theory are "curled up" so small they cannot be seen,
like a tiny seashell. A seashell is a good image for *smallness*, but not for
what the mathematics actually hides. What it hides is not smallness but
**handedness**.

A seashell curl, as usually pictured, is a flat spiral. It has a radius, but
no orientation in the sense we need: you can curl it either way and still have
a small circle. A *coil* — a helix, a spring, a flux tube — is different. A
coil has a *pitch* and a *hand*: right-handed or left-handed, and the two are
not the same. You need three points to tell which hand a coil is — two points
can only oscillate back and forth; three can circulate. That is why
non-associativity needs three inputs to show itself, and why three is the
minimum that can carry direction.

That is exactly what alternativity gives us, and why Chapter 4 proves it
rather than posits it. The associator `[a,b,c] = (ab)c − a(bc)` is, on the
split-octonions, *alternating* — swapping any two arguments flips its sign:

    [a,b,c] = −[b,a,c].

In plain English: re-association has a handedness, like a cross product.
In the primer's anchors: **alternativity is the polarization of the
re-association field** — the associator collapses from a vector with many
directions to a single signed axis. A polarized coil has one way to turn; an
unpolarized one has all ways. That is the content of "the associator reduces
to a sign" (Chapter 4, pending the imaginary-part property), and its fixed
magnitude is `strut_weight = 4`.

So when a conventional account says "the extra dimensions are curled up," a
sophisticated reader should translate: *curled how?* The answer this primer
offers is not "into a tiny seashell" but **"into a coil whose handedness is
the associator."** Downprojecting a higher dimension does not make it
disappear into smallness; it makes it appear downstairs as a *coil* — a
handed flux tube whose pitch is the cost Γ and whose polarization is whether
the associator is a sign (one handedness, octonions) or a vector (many,
sedenions).

This is why the plasma toy of Chapter 10 is a calibration, not a variant of
the transit map, and why it is three-dimensional. The toy does not add new
dynamics to ideal MHD; it shows that ideal-MHD-like dynamics — `∇·B = 0` as
`d² = 0`, flux as a path-independent count, frozen-in as path-independence —
already *is* what the CD-grounded associator does, once its handedness is
taken seriously. And it is why the stellarator sketch of Chapter 1 is not an
analogy *to* MHD but the same coil, seen from the other side: a preferred
direction is what axisymmetry *is*, and losing it is what makes geometry fully
three-dimensional — a coil with no axis to lean on.

[Marginalia: this coda is not a claim that string theory *is wrong* to
compactify. It is a claim about what "compactify" should be taken to mean
here: not "make small" but "make axial." Smallness is a radius; handedness
is an orientation. The primer keeps both, but only the second survives the
downprojection as structure.]

---

*If this introduction has done its job, the reader knows why the primer
exists before Chapter 1 begins: not to be modest, but to be grounded — at one
end in a construction that can be checked line by line, at the other in a
measurement that can fail, and in between in a ladder that says exactly what
it means when it says "this is that."*
