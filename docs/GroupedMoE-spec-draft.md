# GroupedMoE.lean — draft theorem statements (pre-formalization)

For the grouped-GEMM MoE baseline (`pleio` runtime: torch._grouped_mm over
cumulative segment offsets; reference: the Python-loop expert sum).

## 1. Segmentation-order lemma (certification target)

    grouped_output x jmax weights order = loop_output x jmax weights index_order

The per-token expert sum is INDEPENDENT of how tokens were bucketed/sorted before the
grouped matmul, provided the scatter-back respects the sort permutation. Proof sketch:
both sides compute ∑ over the token's selected experts of w_e · FFN_e(x) — equality by
Finset.sum commutativity over the selection set, with the sort permutation absorbed by
`List.Perm` on the segment structure. This is the licence a grouped kernel needs to be
legal at all (analogue: `lse_shift`'s any-base identity).

## 2. Accumulation error, hypotheses-forward (cf. gap_drift_retention's pattern)

Per-operation rounding is a HYPOTHESIS (Mathlib's Data.FP has no IEEE-754 proof theory;
Float is opaque). Statement:

    | fl_grouped - exact | ≤ (k - 1) * eps * max_e |w_e| * |FFN_e(x)| + (scatter term)

where fl_grouped is the float-computed grouped accumulation and eps is the per-op
relative rounding bound. Runtime hedge: differential test vs an fp64 reference in CI,
tolerance derived from THIS theorem rather than an eyeballed atol.

## 3. Router-gradient precondition

The composite output's dependence on the router weights must factor through the
selection mask AND the routing weights multiplicatively — selecting by topk indices
alone starves the router of gradient (a real bug caught by pleio's dry run, documented
in pleio/model.py dense_experts). Statement: for the reference and the grouped path
alike, ∂out/∂w_router = 0 iff the mask·weight product is not differentiated. This turns
a documented bug-class into a CI-checkable invariant.

## Deliberately NOT claimed

* Coherence of top-k selection — the corpus PROVES it non-associative
  (topk_selection_not_associative). The target is correspondence, not coherence.
* The kernel implementation (race-free scatter, warp behavior) — out of Lean's reach;
  covered by differential testing, not proof. Disclosed per the ple-io parity register
  (status: uncertified until 1-2 land, then certified-with-hypothesis for 2).
