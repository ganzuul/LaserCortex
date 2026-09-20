# The store format, formally — draft theorem statements (pre-formalization)

The 196B store's FORMAT layer is provable in Lean (no new certificate content; same
PentagonatorExpert style) — three theorems. Draft,yki:, with what's provable vs measurable:

## 1. e8m0 decode is deterministic + monotone (provable)

The scale byte IS a biased-127 exponent with no sign/mantissa/NaN for legal bytes
(engram_row_spectrum.py:69's decoder convention — the corpus's own, so this is a
FORMAT fact not an interpretation guess):

    e8m0_decode b = (2:ℝ)^(↑b:ℝ)          -- byte → 2^(b-127) via rpow (h exp, rpow_natCast)
    theorem e8m0_decode_monotone : monotone in b

## 2. e4m3 payload magnitudes are bounded (provable)

    |e4m3_decode v| ≤ 448             -- the format's own ±448 max
    e4m3 relative error ≤ 2^-4        -- 3 stored mantissa bits + implicit bit

## 3. Row_dequant_bound (the runtime-consumable claim)

    |dequant(r, b_re, blk)| ≤ 448 * 2^(byte(r,blk) - 126)
    row norm ≤ 16 * 448 * max-block-scale(r)

Consequence for the shipped outliers (row norms to 1e41, the row-spectrum artifact):
they are PROVABLY finite; their magnitude is tied to their own scale bytes — which
licenses the runtime's outlier-quarantine hypothesis: the certified LSE combine
requires a bounded input, and a capped scale byte IS its certificate. The certified
dispatch's tile tests then see bounded inputs under the theorem's hypothesis.

## Deliberately NOT claimed (content is not format)

* Nothing about which SEMANTIC value a row carries. The address is a prime-modulus
  hash fold; row→content is `gramVal_addr_inj`'s business.
* Nothing about the trained meaning of a row. The row->meaning relation is MODELLED
  (the student trunk's training), not algebra — it stays in the ple-io parity
  register as UNCERTIFIED until the trunk is trained against the real store.

## Implementer's honesty note this session

An attempt to formalize this in SAME session ran into Mathlib API roulette at
Real.rpow monotonicity (six candidate lemma-name paths, none cleanly 'rpow' with a
Nat-cast exponent) — the DRAFT is kept out of the corpus until the named lemmas can
be verified server-side rather than patched piecemeal: better to ship the STATEMENT
(with hypotheses and honest non-claims) than a proof that strains assumptions.
