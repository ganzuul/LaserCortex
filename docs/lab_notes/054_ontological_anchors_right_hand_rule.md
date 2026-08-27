# Lab Note 054 — Ontological Anchors: the right-hand rule and polarization

**Date**: 2026-08-26
**Follows**: 053 (interface flux / wavelet / MHD), the alternativity proofs in `foundations/Algebra.lean`
**Status**: ANCHORING — a reification of the rarified machinery into a small set of conventional, mnemonic concepts.

## 0. The problem this note solves

The project has accumulated precision but lost grip: *alternativity, associator,
dcStep, rightSpine, Γ strut, flux, coarse-graining, slow variables* — each
exact, each hard to hold alongside the others. The fix is **ontological
anchoring**: hang every rarified concept off a handful of concrete, familiar,
mnemonic ideas, so that a general intelligence can hold the whole thing in one
hand.

The central anchor is one you already know from physics:

> **The right-hand rule.**

## 1. The right-hand rule — and what it actually is here

The right-hand rule is a mnemonic for **orientation**. Its algebraic heart is
the cross product `a × b = −(b × a)`: the *antisymmetry* is the handedness. The
determinant `det(a,b,c)` is the unique (up to scale) *alternating* trilinear
form in three dimensions — an ordered triple has a sign, and that sign is its
orientation.

We just proved (this session, `foundations/Algebra.lean`) that the associator

    [a,b,c] = (ab)c − a(bc)

is **alternating**: `[a,b,c] = −[b,a,c]`. That is *precisely* the determinant /
right-hand-rule structure, generalized to the split-octonion space. In plain
English:

> **Re-association has a handedness.** The associator is an *oriented volume* —
> it assigns a sign to every ordered triple of factors, exactly as the
> right-hand rule assigns an orientation to every ordered pair.

This is not a metaphor layered on top of the algebra; the antisymmetry *is* the
handedness, and we have the theorem.

## 2. The anchor chain

Five anchors. Each is a conventional term, a mnemonic, and a reification of one
(or more) rarified concepts. This is the whole map.

| # | Anchor (conventional) | Mnemonic | Reifies (rarified) |
|---|---|---|---|
| A | **right-hand rule** | "which way does re-association turn?" | *alternativity* — the associator is an alternating 3-form |
| B | **polarization** | "is the turn one way, or all ways?" | *associator antisymmetry* — a sign (±1), not a vector |
| C | **flux** | "how much turns, net?" | *dcStep* — the conserved, path-independent count |
| D | **the cut (interface)** | "what crosses the seam between parts?" | *rightSpine* — cross-boundary coupling |
| E | **resistivity** | "how much does a turn cost?" | *Γ strut* — the price of handedness (2 → 19 at CD 3) |
| F | **coarse / fine** | "what survives if I blur?" | *reduced lattice / transit map* — slow vs. fast variables |

Read top-to-bottom, the six anchors tell one story: *re-association turns
(A), the turn is one-way (B), the net turn is a conserved count (C), the turn
is carried across a seam (D), the turn has a cost (E), and only the coarse part
of the turn survives blurring (F).*

## 3. Polarization — the term that does the most work

"Polarization" (of light, of a field) means the oscillation is restricted to a
single direction — linearly polarized light oscillates in one plane, unpolarized
light in all. The same word, applied literally here:

- **Alternative (CD ≤ 3):** the associator is *polarized* — antisymmetry
  collapses it from an 8-component vector to a single signed (axial) direction,
  a ±1. Reconnection is a clean binary flip.
- **Non-alternative (CD ≥ 4, sedenions):** the associator *depolarizes* — it
  regains full vector degrees of freedom. Reconnection is multi-directional.

So alternativity is not a technical clause in an algebra definition; it is
**the polarization of the re-association field.** And the two transitions are
distinct and nameable:

- CD 2 → 3: **the handedness turns on** (associator 0 → nonzero; the Γ jump).
- CD 3 → 4: **the polarization breaks** (associator sign → vector).

The first is "resistivity turning on"; the second is "depolarization." The
current Γ functional models the first (a strut of 16) but not yet the second —
which is exactly the falsifiable gap this anchoring makes visible.

## 4. The reification dictionary

Rarified → conventional, for when you need to translate:

| Rarified | Conventional (mnemonic) |
|---|---|
| associator `[a,b,c]` | the "turn" — the oriented re-association |
| alternativity | the handedness (right-hand rule) |
| associator antisymmetry | polarization (axial, signed) |
| `dcStep` | the net flux (conserved, path-independent) |
| `rightSpine` | the interface flux across a cut |
| `strut_weight = 4 = \|[e₁,e₂,e₄]\|` | the fixed magnitude of the handedness |
| Γ (friction density) | resistivity (cost per turn) |
| composition law `dcStep = dcStep l + dcStep r + rightSpine l` | coarse + detail (wavelet / lifting) |
| transit map (many-to-one) | the low-pass frame (slow variables) |
| CD tower | the phase diagram of handedness |
| critical point CD 3 | the handedness turns on |
| CD 4 (sedenions) | the polarization breaks |

## 5. The phase diagram of handedness

The whole Cayley–Dickson tower, in three lines of mnemonic:

| CD | Algebra | Handedness |
|---|---|---|
| 0–2 | ℝ, ℂ, ℍ | **none** (associative — nothing to orient) |
| 3 | 𝕆 (octonions) | **one, polarized** (alternating associator, a sign) |
| ≥ 4 | 𝕊, … (sedenions) | **many, unpolarized** (associator becomes a vector) |

This is the "simple ontological anchor" the rarified story reduces to: *first
there is no handedness, then there is one handedness, then the handedness
shatters into many.*

## 6. Honesty ledger

Grounded (proven, no `sorry`/axioms):
- `left_alternative`, `right_alternative` — the split-octonions are alternative.
- `associator_antisymm_left` — the associator is alternating (the right-hand rule).
- `dcStep_eq_geodesic` — flux is path-independent (conserved).
- `dcStep_node_compose` — coarse + detail, with `rightSpine` the interface.
- `strut_weight_eq_four` — the handedness has fixed magnitude 4.

Belief (working hypothesis, not yet proven):
- "flux conservation = δ²=0" (the pentagon as a cocycle identity).
- "Γ = resistivity", "CD 4 = depolarization", and the missing alternator strut.
- the wavelet and MHD readings as *literal* structures (vs. apt analogies).

## 7. Why this matters for manageability

With the six anchors, every new theorem can be filed under one of A–F, and every
new result phrased as an answer to one of six questions: *which way? one way?
how much net? across what seam? at what cost? what survives blurring?* That is
the "simple ontological anchoring" the rarified material needed — the
right-hand rule is the handle by which alternativity, polarization, flux, and
the reduced lattice can all be picked up at once.
