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
- **The scalar part is proven to vanish; the reduction to a single
  direction is not** [P]/[C]. In ℝ³, an alternating trilinear form is a
  scalar (the determinant) — the sign. In higher dimension, alternating
  forms need not be 1-dimensional. The first step has landed: the
  associator's e₀ component vanishes identically **[P]**
  (`associator_e0_vanishes`) — the flux has dropped its scalar part and
  lives in the seven imaginary directions. On the basis lattice the picture
  sharpens: every nonzero basis associator is ±2 times a *single* imaginary
  axis, and its magnitude is quantized (§8.6) **[P]** — but the landing axis
  varies from triple to triple, so "one signed direction for all physics"
  remains **[C]**. What the formalization did instead: `signCocycle`
  deliberately quotients the axis away, and *that* coarsened sign passes
  the pentagon coherence check on the basis **[P]** (`pentagon_cocycle_basis`,
  Chapter 6 §6.4). Confirm/refute for the remaining step: Chapter 11.
- **"Right-handed" versus "left-handed" is a convention** [marginalia: the
  split-octonion product is fixed; there is no choice of orientation to make.
  The handedness is absolute here, not a convention. Whether a "left-handed"
  mirror exists as a distinct algebra — the compact octonions? — is a question
  for the CD homotopy of Chapter 3.]

So Chapter 4's honest claim is: **the associator is antisymmetric [P]; the
antisymmetry is the handedness [reification]; the handedness is signed and
quantized in magnitude on the lattice [P]; its reduction to a single signed
direction is [C]**.

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
