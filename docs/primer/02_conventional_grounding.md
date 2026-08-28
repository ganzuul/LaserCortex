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
