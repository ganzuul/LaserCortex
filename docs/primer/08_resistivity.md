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

## 8.5 What would make the analogy literal (updated)

- The pentagon cocycle identity (Chapter 6) is **[P] on the basis**
  (`pentagon_cocycle_basis`), and the discrete `∇·B = 0` statement is
  independently **[P]** (§6.5). What remains **[H]** is the identification:
  that flux conservation *is* δ²=0 and the Γ jump is that class becoming
  nontrivial — the reading, now that both of its halves are separately
  proven, is the last mile.
- [H] The missing alternator strut (Chapter 5): the *second* dial, at CD 4.

## 8.6 The quantum and the dial

§8.2 showed the cost *turns on* at CD 3. Two further facts — one theorem,
one design — make it a resistivity in something close to the practical
sense: the cost comes in **atoms**, and the atoms can be **dialed**.

- **Strut quantization [P].** Run the associator over the entire eight-point
  basis lattice — all 8³ = 512 ordered triples — and the magnitude histogram
  has exactly two bars: `0 ↦ 344`, `4 ↦ 168` (`strut_quantized_on_basis`).
  Nothing in between; and every nonzero associator is ±2 times a *single*
  imaginary axis, never lightlike (`assocBasis_nonzero_null_free` — in the
  (4,4) signature a nonzero vector can still have vanishing norm, which
  would make "magnitude" a lie; here it never happens). In English:
  **resistivity has an atom.** The strut 4 is the quantum in which
  re-association cost is paid, and the 168 full-strength events are the 28
  non-associative imaginary triples in six orderings each — the Fano-plane
  count of Chapter 4, now with a census.
- **The dial is the fibre [H].** An atom does not forbid fractions: the
  chirplet operator `rightSpine · c` is a *family* in the parameter `c`,
  interpolating between the wavelet step (`c = 0`, coarse channel only) and
  the full-chirplet step (`c = 4`, interface bookkeeping paid in full
  struts). The fractions `c ∈ {1,2,3}` are not associator magnitudes — the
  previous bullet refutes that reading on the lattice — they are *choices
  of how much of the priced channel to pay for*. Confirm: observables
  (compression, reconnection cost in the reduced model, Chapter 10) vary
  monotonically with `c`; refute: `c = 1, 2, 3` runs are indistinguishable
  from `c = 0` or `c = 4` in every observable — the strut is quantized in
  behavior as well as on the basis, and the dial collapses to a switch.
- **What the dial is for: an error budget.** §6.5 certified the closure
  half of a numerical step (`∇·B = 0` by stream function) as *provably
  free*; the dial has nothing to tune there. The multiplicative half —
  advection, the Lorentz coupling, the only channels through which the
  associativity defect can enter — is where `c` acts: an effective slip
  η_eff = (c/4) · strut-unit, tunable *and dimensional*, because the atom
  gives the dial its units. The relation is photoelectric: continuous
  intensities, quantized action. In English, the discipline this section
  buys: **a toy is one fibre; an instrument is the family plus the proofs
  that bind its fibres.** At each setting of `c`, what was skipped has a
  name (the unpaid detail), the name has a unit (the strut), and the unit
  has a theorem (§8.6 bullet 1) and an exact-discount certificate (§8.4, the
  same mold in which loose coupling is certified in the cost calculus).

*Level: "resistivity" here inherits §8.3's **[H]**; quantization is **[P]**;
the fibre-dial is **[H]** pending Chapter 10's behavioral test.*

## Sources

- `Friction.lean`, `LogicalTemperature.lean`, `SubdivisionClosure.lean` (§10),
  `AMM.lean` (§9), `Stencil.lean` (the free half of the error budget),
  `HyperbolicChirplet.lean` (the chirplet family `rightSpine · c`).
- Notes 045–050, 053 (§7), 054 (anchor E), 056–058 (Rees fibres, quantization,
  the fidelity dial).
