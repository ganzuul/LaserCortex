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
