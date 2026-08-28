# Chapter 8 — Resistivity

*Anchor E. "How much does a turn cost?"*

## 8.1 Conventional grounding: ideal versus resistive (draft)

- Ideal MHD: flux frozen in, no reconnection, no dissipation.
- Resistive MHD: reconnection allowed; flux dissipates into heat.
- The resistivity η is a *dial*, and the ideal limit is η = 0.

## 8.2 The Γ functional

- `frictionDensity k` — the per-flip weight on the CD tower;
   Γ₀..Γ₇ = 0, 1, 2, 19, 20, 21, 22, 23. **[V]**
- The single jump 2 → 19 at CD 3 **[P]** (`gamma_increment`,
  `gamma_only_jump_at_cd2_3`); the two-regime collapse **[P]**
  (`weightedCost_assoc_regime`, `weightedCost_nonassoc_regime`).
- `weightedCost cd t = dcStep t · frictionDensity cd` **[def]**
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
