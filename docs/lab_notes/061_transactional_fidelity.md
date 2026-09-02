# Lab Note 061 — Transactional Fidelity: Commits, Atoms, and the Dial

**Date**: 2026-09-02
**Follows**: 060 (the hole taxonomy; F3′ tiering), 058 (the fidelity dial and
the instrument criterion), 059 (naming discipline), 040 (a name collision we
are about to inherit)
**Trigger**: owner — *"Atomic in the sense of atomic transactions? Because
that is what we need for tunable fidelity between toy and research MHD"*;
then: write it, working toward **an API for our physics**.
**Status**: NOTE + **API v0.1** landed — `LaserCortex/PhysicsAPI.lean`
(root-imported; builds in 4.0 s; `commit_gap` needs `propext` alone)
**Protocol**: Timespace Decomposition v0.3 — (4,4) Signature Model

---

## 0. Thesis

The fidelity ladder between toy and research MHD is not a resolution slider.
It is a **commit policy**: a three-lever control surface on top of a model
in which smooth steps are abortable, reversible, and freely submissible,
while interface events are **atomic in the transactional sense** — because a
commit *is* multiplication by a non-unit, and its undo does not merely not
exist cheaply, it does not exist as a category
(`null_annihilated_by_conj`). The lattice makes the atomicity quantitative:
a smooth step's ledger charge has absolute value ≥ 1 (`commit_gap`), so an
invertible-only solver is never "almost reconnecting" — it is a full atom
away. That pair of theorems is what a tunable-fidelity API must expose, and
§4 exposes it.

## 1. The transaction dictionary

| database notion | model carrier | status |
| --- | --- | --- |
| local work (readable/writable, undoable) | a **smooth step**: `isSmooth x := ledger x ≠ 0`; rollback = `x̄ / ledger x` (`undo_smooth`) | [P] |
| commit | a **commit**: `isCommit x := x ≠ 0 ∧ ledger x = 0` — exactly a zero divisor (`isCommit_iff_isZeroDivisor` [P] = the cone theorem restated) | [P] |
| atomicity (ACID's A) | `commit_indivisible`: a commit never factors into two smooth steps | [P] |
| the log | `ledger = octonion_norm`, a monoid homomorphism into `(ℤ, ·)` (`ledger_mul`) — event-content is recorded once, composed multiplicatively, never re-derived | [P] |
| isolation / serializability | re-bracketing (schedule reordering) of skeleton evaluations changes results by a path-independent sign, and that sign is the product of local cocycles | [P], skeleton domain (`rebracket_agrees`, `edge_sign_is_cocycle`, `face_closes`) |
| consistency | the closure certificate: fields enter only through the stream function; `divFree` holds by theorem, not measurement | [P] (F1) |
| compensated skip (not ACID; saga-pattern) | the `looseCost` mould: exact discount, linear in trust — proven **for tree costs** | [P-tree] / [H-MHD wiring] |
| durability | persistence of the certificate across sessions — the ledger + gnuplot/plots convention and Graphiti rows are the current mechanism, informal | [H] |

Where ACID says *all-or-nothing*, we have the stronger algebraic fact: the
"nothing" branch does not exist for a commit — its adjugate annihilates, so
a rolled-back reconnection is not the pre-state, it is a *different theory's
answer*. That is the content of the atomicity, and it is [P].

## 2. What is new as theorems (this note's unit)

All in `PhysicsAPI`, thin over the F3′ section of `foundations/Algebra.lean`:

- `commit_gap` — `isSmooth x → 1 ≤ (ledger x).natAbs`. **The gap is an
  integrality phenomenon**: over `ℝ` the null cone is approachable
  (`Q = 1/n` family), so the theorem's force is exactly its lattice
  hypothesis. Design consequence (§4 rule 2).
- `isCommit_iff_isZeroDivisor` — the transactional vocabulary bolts onto the
  geometry: commits = zero divisors = null cone = horizon. One predicate,
  three theorems deep.
- `commit_invariant` — smooth factors neither create nor destroy commit
  content: the horizon is invariant under change of invertible frame.
- `undo_smooth` (the adjugate identity, exported) — and its negative twin,
  `null_annihilated_by_conj`: on a commit the *undo operation changes into
  the annihilator*. Abort is not expensive; it is not defined.
- `amplitude_free` + `strut` standing together: **amplitude is free, defect
  is quantized** is now a two-name API fact, the resolution of 057's
  {0,4} against any demand for fractional struts.

## 3. The three levers, and what the toy cannot fake

The dial `c ∈ {0,…,strut}` (056's Rees fibre) is one knob on a control
surface with three distinct axes — conflating them is the failure mode this
section exists to prevent:

1. **Amplitude paid** — continuous axis, free per `amplitude_free`: how much
   of the priced channel's bookkeeping the solver executes.
2. **Events committed** — discrete axis, forced: whether the trajectory's
   ledger charge passes through 0 is a property of the *steps taken*, not a
   setting. `FidelitySettings` has no `nCommits` field, and that absence is
   the theorem (`commit_indivisible`, `commit_gap`).
3. **Bookkeeping recorded** — the λ-axis: pay for part of an event's cost
   and *log the discount exactly* (the `looseCost` mould; the MHD wiring is
   F3's open obligation). A skipped payment with no log is a lie; with the
   exact-discount certificate it is a *saga*.

The consequence for the ladder, stated as the toy's contract: a solver that
stays smooth across a region where the physics commits is **not a
low-resolution version of research MHD; by `commit_indivisible` it is a
different theory** — its error at that location is not small-but-known, it
is categorical, and no refinement of its timesteps closes it (gap ≥ 1 atom).
The instrument's job at each tier is then: commit where committed physics
lives, and certify the ledger where it does not.

**Sweet–Parker echo [H]** (register it, test it in Ch 10): the resistive
fact that reconnection persists at finite rate as η → 0 (the singular ideal
limit; Sweet–Parker, Priest–Forbes [std]) is the continuum reflection of
transactional atomicity — the PDE's version of "no refinement of smooth
steps reaches a commit." *Confirm*: in the reduced model (Ch 10),
invertible-only toys fail to converge to the committed reference at
interface events as step size → 0, while the amplitude dial converges
smoothly off-interface. *Refute*: convergence of the smooth sector to
committed behaviour at any interface — then the analogy is decorative and
this paragraph gets deleted.

## 4. The API, v0.1

`PhysicsAPI` (namespaces within): sectors **Ledger / Fields / Bookkeeping /
Settings**. Table: endpoint → the promise it makes to a caller.

| endpoint | promise | backer |
| --- | --- | --- |
| `ledger`, `ledger_mul` | event-content of a trajectory is one integer, composed multiplicatively; never re-derived from state | [P] |
| `isCommit`, `isSmooth`, `isCommit_iff_isZeroDivisor` | the transactional partition of steps = the cone partition; horizon is frame-invariant (`commit_invariant`) | [P] |
| `commit_indivisible`, `commit_gap` | commits are atomic and gapped: a smooth scheme cannot fake or approach one | [P] |
| `undo_smooth` (+ `null_annihilated_by_conj`) | abort exists for smooth steps, is undefined for commits | [P] |
| `amplitude_free`, `strut` | amplitude axis has representatives everywhere; defect unit = strut (spectrum `{0, strut}`) | [P] |
| `makeField`, `divFree` | the **only** way to get a B; closure certified by theorem (certified number, not measured one) | [P] |
| `rebracket_agrees`, `edge_sign_is_cocycle`, `face_closes` | evaluation-schedule reordering is a path-independent sign, computed locally, flat on faces | [P], skeleton |
| `FidelitySettings` | the levers, named | fields [P-usable]; constraints live in docstrings as F3 obligations |

**Design rules baked in** (each is a choice with a reason):

1. **Nothing [H] gets a name.** Ranges, monotonicity, and the MHD-λ wiring
   are docstring obligations; an obligation graduates to a theorem (and a
   name) only with a proof — this is the honesty policy turned into an API
   deprecation discipline.
2. **Continuous fields, integer books.** The gap (§2) only exists for the
   lattice; so solver state (`ψ`, B) may be float, but the *defect ledger*
   is integer-valued (charges, strut multiples) and the *sign channel* is
   ℤ/2 — exactly the channels F2 proves you may re-bracket without loss.
   Discreteness where it buys the gap; continuity where it buys accuracy.
3. **Constructor = certificate.** `makeField` is the only B-entry point;
   hand-built flux components are outside the API, and that is the whole
   toy-vs-instrument line expressed in one signature.
4. **The log is a homomorphism.** Commit accounting composes by
   multiplication of charges; nothing in a solver needs to *count* events to
   verify the books — a trajectory's total charge is the product of its
   steps' charges (the ledger).
5. **Python mirrors names, not proofs.** When F3 closes the obligations,
   the lift/ground discipline (normcode) mirrors this surface; the mirror
   re-exports `PhysicsAPI` names 1:1 and never invents its own. The API
   exists *before* the mirror — that is Lean-first applied to interfaces.

## 5. What v0.1 does NOT promise (the open seams)

- **Unit classification over the lattice**: which smooth steps have a
  *lattice* inverse (candidates: `ledger x = ±1`; the "±1 iff unit"
  direction needs one more `⟨⟩`-level lemma). Until then `undo_smooth`
  promises rational rollback only. An afternoon's work; not claimed.
- **Event count**: `ledger` records total charge, not a count of atomic
  commits; a factorization theory of null steps is not developed
  (null×null is null, so counting is hopeless without more structure —
  honest note, not [H]).
- **The solver-domain transfer**: everything in §1–§3 is a theorem about
  the *model's algebra*; "therefore MHD solvers must commit" is the §3
  hypothesis with its confirm/refute attached, and F3 + Ch 10 are where it
  either graduates or dies.
- **No `chirpRate`**: the stub is unchanged — its replacement is F3 and it
  will *enter* the API, not the other way around.

## 6. F3 graduation checklist (the API's to-do list, verbatim from docstrings)

1. `0 ≤ amplitude ≤ strut` — make it a structure field invariant or delete
   the ambition;
2. monotonicity of `chirpletDetail_c`-analogue committed cost in `c`;
3. exact-discount identity at `{0, strut}`; λ↔MHD-event wiring, proved in
   the `looseCost` mould;
4. `chirpRate` real definition (057 §3.2, 058 F3);
5. unit classification (lattice inverses ⟺ charge ±1) — upgrades
   `undo_smooth`.

Each item, when proved, gets its theorem name in `PhysicsAPI` and its
docstring obligation retired. The API is how F3's done-ness is *visible*.

## 7. Naming hygiene (059 discipline, extended)

**"Atomic" now has three senses in this repo**: (a) 040's *atomic shell*
(atom-spectrum model, `fundamental_atomic_transition`), (b) monoid-theoretic
*irreducible* (F3′/`commit_indivisible`), (c) ACID *transactional*. Bare
"atomic" is banned. Vocabulary from this note: **commit** (a zero-charge
nonzero step — API sense), **interface atom** (sense (b) in prose),
**atomic shell** (040, unchanged). Also: "log" now means the ledger
homomorphism, not git; in ambiguous prose write "ledger."

## 8. Status of claims

| item | tag |
| --- | --- |
| §1 dictionary rows marked [P] | stand on `PhysicsAPI`/`Algebra`/`Coherence`/`Stencil` [P] backers |
| §3 lever taxonomy | **stipulative** (organizing; no new content) |
| toy-is-a-different-theory | [P] as algebra (`commit_indivisible` + `commit_gap`); as a statement *about solvers* [H] via §3 transfer |
| Sweet–Parker echo | **[H]** with confirm/refute attached |
| §4 rules 1–5 | stipulative, each traceable to a [P] or an explicit gap |
| §5 seams | open, listed |
| §6 checklist | = F3, open |

---

## References

- `LaserCortex/PhysicsAPI.lean` — v0.1 (this unit); `LaserCortex/foundations/Algebra.lean`
  — §"F3′" + cone section; `LaserCortex/Coherence.lean` — F2; `LaserCortex/Stencil.lean` — F1
- Notes 056 (Rees fibres), 057 (quantization), 058 (dial + instrument
  criterion; §6 changelog), 059 (disambiguation discipline), 060 (hole
  taxonomy), 040 (the atomic-shell name we are protecting)
- [std] ACID transactions (Gray, 1981); saga pattern (García-Molina &
  Salem, 1987); Sweet–Parker reconnection; Priest & Forbes, *Magnetohydrodynamics*
  — for the §3 echo's physics side
- `docs/ZD_CONVEX_OPTIMIZATION.md` — the monopole/change-of-sheet origin of
  the commit metaphor inside this project
