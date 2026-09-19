# Lab Note 066 — The Missing Adjoint: the CD3 Distributor Obstruction, and Applications as a Source of LC Work

**Date**: 2026-09-18
**Trigger**: external application (ple-io). R3 — de Bruijn order reconstruction for the PLE-I/O
write channel — needs a *shuffle* that depends on how a fragment was built. `foundations/Chu.lean`
already documents that no linear map can do that shuffle, and that only the adjoint/sliding content
survives. The application asks LC for the CD ≥ 3 case; the case is open.
**Status**: NOTE + **§3 is a complete basis-restricted characterization [V]** (ported to Lean as
the immediate next unit) + **§4 re-scopes the open problem sharply** + **§5 states the standing
protocol change: applications assign LC work**
**Protocol**: Timespace Decomposition v0.3 — (4,4) Signature Model
**Marker key**: `[P]` proven in Lean · `[V]` verified computationally (golden vectors given) ·
`[H]` hypothesis · `[C]` conjectural / pending

---

## 0. Abstract

`foundations/Chu.lean` carries two monoidal structures on Chu spaces over `SplitQuat`:
`ChuTensor` (primal `X.a*Y.a`, dual `X.a'*Y.a'`) and `ChuSeq` (primal `X.a*Y.a`, dual
`Y.a'*X.a'`). They agree on primals and differ only on duals, so the duoidal distributor
that would interchange them must shuffle a **factorization-dependent** middle pair. The
file's own header records the consequence — *"no linear map on a non-commutative algebra
can perform factorization-dependent shuffles"* — and retains only the adjoint content, the
sliding law `β(u*v, w) = β(v, S(u)*w)` (`splitQuatPairingAux_mul_slide` [P]), with
`cd2_distributor` supplied for **CD ≤ 2 only** via the antipode (`foundations/Chu.lean:490` [P]).

This note does three things. **(1)** It isolates what actually breaks at CD 3: not the
pairing, not nondegeneracy, not even the antipode — all present for `SplitOctonion` — but
**antipode contravariance**, which is *false* at CD 3 and is already proven false
(`antipode_mul_false` [P], `foundations/Algebra.lean:720`). **(2)** It **settles the
basis-restricted question completely [V]**: the antipode sliding law fails on exactly **18
of 512** basis triples, the failures are exactly the three Fano lines `{e1,e4,e5}`,
`{e2,e4,e6}`, `{e3,e4,e7}`, and — the surprising part — the sliding defect is **disjoint**
from the associator: sliding holds on *every* triple where the associator is nonzero, and
fails only where the associator vanishes. **(3)** It re-scopes the open problem from "find a
CD3 distributor" to the sharper "find a *signed/braided* adjoint, since the antipode cannot
be one" — which is the question a real application needs answered.

The result is that a missing algorithm can now be specified precisely enough to be *worked
on*, and that the search for it is a competency worth developing (§5).

---

## 1. Why CD ≤ 2 works, and what exactly fails at CD 3

The CD ≤ 2 proof of the distributor has a short dependency chain:

```text
splitQuatPairingAux_mul_slide  [P, foundations/Chu.lean:380]
   β(u*v, w) = β(v, S(u)*w)                    -- the sliding law
   proved by: split_quat_mul_assoc  +  `ring`
cd2_distributor                [P, foundations/Chu.lean:490]
   fwd_primal := fwd_dual := antipode_sq_lm
   pair_preserved: β(S(x), y) = β(x, S(y))     -- S self-adjoint  [P, :109]
```

`split_quat_mul_assoc` is *associativity*. That is the whole story of CD ≤ 2: the
sliding law is an associativity rewrite, and self-adjointness of the antipode makes it a
valid adjoint pair.

At CD 3, every ingredient except one is already in the corpus:

| ingredient | CD 2 | CD 3 (`SplitOctonion`) | where |
|---|---|---|---|
| bilinear pairing | ✅ `splitQuatPairing` | ✅ `octonionPairing` | `foundations/Chu.lean:84`, `:148` [P] |
| pairing nondegenerate | ✅ `:113` | ✅ `:179` | [P] |
| antipode self-adjoint | ✅ `:109` | ✅ `octonionPairing_antipode_symm` | `foundations/Chu.lean:175` [P] |
| antipode involutive | ✅ | ✅ `antipode_involutive` | `foundations/Algebra.lean:714` [P] |
| **antipode contravariant** | ✅ | ❌ **`antipode_mul_false`** | `foundations/Algebra.lean:720` [P] |
| sliding law | ✅ | ❌ **open (this note)** | — |

**So the obstruction is already localized and already proven.** The missing piece is not
"the CD 3 distributor" as a vague goal: it is *one* failed property, named and machine-checked.
That is a materially better starting position than the open-problem line in `Chu.lean` suggests,
and it is why this is workable rather than speculative.

Note also that `Chu.lean`'s `Distributor` structure deliberately omits its normalization fields,
with the reason stated (`:451-470`): the shuffle depends on the factorization of the input, not
just its product. This note does **not** attempt to re-add them — that is the documented dead end.
It instead asks the well-posed question: *does the antipode's adjoint content survive at CD 3?*

---

## 2. What an application needs (and why it is the same question)

The ple-io write channel stores order-free keys (a bag) and needs to recover order. Its seam law
(`ConditionalMemory/SpectrumOrder.lean:105`, ple-io) says the *entire* order content of a concatenation is one
boundary edge — exactly the kind of "one extra term in an append law" that the sliding law
exhibits. Reconstruction then requires moving a fragment's contribution across the key/pairing
bilinear form, i.e. an **adjoint for the shift operator**. ple-io cannot use the shuffle route
(same factorization-dependence obstruction), so it needs precisely the object LC is missing.

That is the coupling: **a real application is blocked on an open LC question, and the question
has a precise shape.** The application does not merely consume LC results — it *assigns* the
next one (§5).

---

## 3. The basis-restricted answer, complete [V]

Ported `split_oct_mul` (`foundations/Algebra.lean:79`) and `antipode` (`:697`) to Python and
enumerated all 512 basis triples. The port was validated against Lean's own witness for
`antipode_mul_false`: `antipode(e1*e4) = (0,0,0,0,0,-1,0,0)` and `antipode(e4)*antipode(e1) =
(0,0,0,0,0,1,0,0)` — reproduced exactly, so the arithmetic is Lean's arithmetic.

### 3.1 The sliding law fails at CD 3, on 18 of 512 triples

| test | result |
|---|---|
| associative part only (`e0..e3`), 64 triples | **0** counterexamples |
| all 8 basis vectors, 512 triples | **18** counterexamples |
| defect values attained | `{−2, +2}` only |
| of the 18, triples with `w = +u*v` / `w = −u*v` | **9 / 9** |

Minimal witness: `β(e1*e4, e5) = −1` but `β(e4, S(e1)*e5) = +1`. So the sliding law is not
merely unproved at CD 3 — it is **false**, and falsified on a basis triple.

The last row is load-bearing and was checked separately: **every one of the 18 failures is a
triple where a product is actually formed** (`w = ±u·v`). The failure is therefore not an
artifact of testing on basis elements rather than on products — the law fails exactly at the
places the distributor needs it. (This was the sharpest open question in the first draft of
this note; it is now resolved in favour of the failure being real.)

### 3.2 The failures are exactly three Fano lines

Every failing triple has support set one of

```text
{e1, e4, e5}    {e2, e4, e6}    {e3, e4, e7}
```

Each is a line of the octonion multiplication table, each is an *ordered* triple of a
quaternionic subalgebra, and each crosses the (4,4) sector boundary — the associative sector
`{e1,e2,e3}` and the split sector `{e4,e5,e6,e7}` meet at exactly one split axis per line
(`e4` throughout). The 18 failures are the 6 orderings of each of the 3 lines. Defect sign:
`−2` when the split element is the middle factor, `+2` when it leads.

This is a satisfying answer because it is the **least** one: the failure is not generic
non-associativity, it is three named lines, and they are the lines where the two sectors touch.

### 3.3 The distributor defect is DISJOINT from the associator

The surprising finding, and the one that re-scopes the problem:

| implication | status |
|---|---|
| `assoc(u,v,w) ≠ 0` ⟹ sliding **holds** | **true** |
| sliding **fails** ⟹ `assoc(u,v,w) = 0` | **true** |
| triples with `assoc = 0`: 344/512, of which sliding fails: 18 | — |
| triples with `assoc ≠ 0`: 168/512, of which sliding fails: **0** | — |

So the two defects **partition** the triple space: the sliding law fails *only where
multiplication already associates*, and never fails where the associator is non-zero. The
distributor obstruction at CD 3 is **not an associativity defect**. It is orthogonal to the
one LC's whole cost landscape is built on (`assocDefect`, `frictionDensity`,
`strut_weight` — `Friction.lean:30, :43`).

This matters twice over. It says the `Distributor` obstruction will **not** be found by
following the associator — a natural and, as it turns out, wrong first move. And it means the
distributor defect is a *second, independent* invariant of the CD tower, which is a structural
claim about LC's algebra that this note did not set out to make and which should be checked
at CD 4 before being believed in general.

### 3.4 Candidate relations tested and rejected

Recorded so they are not retried. All of the following **fail** on the basis triples:

```text
defect = 0  ⟺  assoc = 0                  fails   (they are disjoint, §3.3)
defect = β(assoc, w)                       fails
defect = β(u, assoc)                       fails
2·defect = β(assoc, w)                     fails
defect = −β(assoc, w)                      fails
|defect| constant whenever assoc ≠ 0       vacuous (assoc ≠ 0 ⟹ defect = 0)
```

---

## 4. What the open problem now is

Before: *"find the CD ≥ 3 analogue of `cd2_distributor`."*
After, and sharply:

> **Find a `Distributor` at CD 3 whose adjoint is not the antipode.**
> The antipode's adjoint content is exhausted at the three Fano lines of §3.2, and the
> obstruction is disjoint from associativity (§3.3), so the replacement must be a
> **signed/braided** map — the CD 3 analogue of the sign twist that appears in
> `signCocycle` (`foundations/Algebra.lean:247`) and `basisWord_eq_or_neg`
> (`Coherence.lean:300`) — not a further associativity rewrite.

Two consequences, both usable:

1. **The failure is finite and certified.** §3.1 is a complete answer on the basis, with
   golden vectors. A formalization is a `decide`/`native_decide` enumeration in the style of
   `headMods_pairwise_coprime` (`ConditionalMemory/GramDictionary.lean:277`), not a research project. **That is
   the immediate next unit** (§6).
2. **A negative result is now a publishable outcome.** If no `Distributor` exists at CD 3, the
   deliverable is a named absence theorem — following LC's own convention
   (`antipode_mul_false`, `draft_no_period5`, `free_not_quantized`,
   `real_projection_blind_to_supercompleteness`) — and it settles the route for the
   application, which needs to know whether to use the adjoint route or Eulerian-path theory.
   Either answer unblocks work.

---

## 5. Protocol change: applications assign LC work

This note is itself the evidence for a standing change, and it should be recorded as one.

**The change.** An external application (here ple-io) that needs a theorem LC does not have
**files it as LC work**, rather than weakening its own claim or inventing a workaround. The
application becomes a *source of research assignments*, not only a consumer of results. The
grounds are in this note's own history: B3 was a one-line open-problem remark in `Chu.lean`
until an application gave it a purpose, at which point it became a specified, bounded,
falsifiable task — and the specification immediately produced §3.

**What makes an assignment admissible.** A specific missing theorem (or its absence), a stated
purpose, and a named consumer. Not a topic. If the item turns out false, the deliverable is a
named absence theorem plus a reference-corpus entry — *a better outcome than the theorem would
have been, because it settles the route.*

**Where this is recorded.** In the application's own reference corpus: ple-io's
`docs/LC-MINING-ROADMAP.md` §9 is the live backlog (B1–B4), and `docs/LC-GLOSSARY.md` is the
terminology mapping. LC-side, this note is the first entry in the class. If the pattern
recurs, a `docs/lab_notes/`-adjacent assignments register is the natural home; this note
should not be duplicated into one.

**Why this is a competency to develop, not a chore.** §3 was produced by an application
question in a single sitting, and it produced a result (defect ⊥ associator) that LC's own
research programme had no reason to look for. External applications arrive with questions
that are *already reduced* by having a use — they cannot afford vagueness — and their
constraints (finiteness, portability, a concrete artifact) prune the search space before the
work starts. The competency is therefore: **treat an application's blocked dependency as a
scoping service for LC's open problems.** B3 is the poster child: an open problem that was
unactionable as a remark and became a bounded enumeration the moment it had a consumer.

---

## 6. Next units

1. **Formalize §3 as a Lean unit** — `SpectrumOrder`-style module or a `Chu.lean` §7:
   `antipode_slide_fails_at_cd3` (witness triple `(e1,e4,e5)`, matching
   `antipode_mul_false`'s proof style) and the enumeration `slide_defect_fano_lines`
   (`native_decide` over 512 triples). Then the disjointness pair:
   `assoc_ne_zero_implies_slide_holds` and `slide_fails_implies_assoc_eq_zero`.
   All `[V] → [P]`. **Effort: one session.**
2. **Check §3.3 at CD 4** (sedenions) before the disjointness is believed in general. If it
   holds, the distributor defect is a genuine second invariant of the tower — worth its own
   note. If it fails, §3.3 is a CD-3 coincidence and must be labelled one. **Effort: one
   sitting, same Python harness.**
3. **Search the signed/braided adjoint** per §4 — the actual missing algorithm. `signCocycle`
   and `basisWord_eq_or_neg` are the existing sign machinery to start from.
4. **Discharge the application's B1/B2** (ple-io's `LC-MINING-ROADMAP.md` §9.1): the `↔`
   direction of `excess_eq_zero_iff_rightComb`, and `observational_selects_minimal`. Both are
   unfinished in `FreeEnergy.lean` and both are small.

---

## 7. Falsifiers

- ~~If the sliding law turns out to hold for all *products* even though it fails on the basis,
  §3.1's failure is not load-bearing.~~ **RESOLVED (§3.1):** all 18 failures satisfy `w = ±u·v`,
  so the law fails precisely where products are formed. The failure is load-bearing.
- If §3.3's disjointness fails at CD 4, the "second invariant" reading is wrong (next unit
  decides this).
- If a `Distributor` exists at CD 3 with a *non*-signed adjoint, §4's re-scoping is wrong and
  the original problem statement was adequate.

---

## References

- `LaserCortex/ConditionalMemory/SpectrumOrder.lean` — the application side: seam law,
  decoy theorem, `edgeBag_does_not_determine_order` (the same "lossy projection" shape as
  `real_projection_blind_to_supercompleteness`)
- `LaserCortex/foundations/Chu.lean` — `ChuTensor` `:342`, `ChuSeq` `:347`,
  `splitQuatPairingAux_mul_slide` `:380`, `Chu_distributor` `:393`,
  `Distributor` `:471`, `cd2_distributor` `:490` (the CD ≤ 2 result and the documented gap)
- `LaserCortex/foundations/Algebra.lean` — `split_oct_mul` `:79`, `associator_tensor` `:177`,
  `signCocycle` `:247`, `antipode` `:697`, `antipode_involutive` `:714`,
  **`antipode_mul_false` `:720`** (the proven obstruction)
- `LaserCortex/Friction.lean` — `assocDefect` `:30`, `commDefect` `:35`,
  `frictionDensity` `:43` (the invariant §3.3 shows the distributor defect is *not*)
- `LaserCortex/Coherence.lean` — `pentagonLoop` `:144`, `basisWord_eq_or_neg` `:300` (sign
  machinery for §4)
- `LaserCortex/docs/lab_notes/060_anatomy_of_a_hole.md` (absence as a result),
  `062_foundations_migration_audit.md` (audit method and note hygiene)
- ple-io: `docs/LC-MINING-ROADMAP.md` (mining operators; §9.1 the B1–B4 backlog),
  `docs/LC-GLOSSARY.md` (terminology mapping and falsified mappings)
- 039/041/042/043 (the (4,4) sector structure §3.2's boundary crossing sits in)
