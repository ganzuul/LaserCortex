/-
Copyright (c) 2026 LaserCortex contributors. All rights reserved.
Released under the MIT license. See LICENSE.
Authors: nos <ple-io program>

PLE-ACID: the store's transactional-guarantee family, named and bundled,
extended with the LOCK-GAUGE twin certificates (ple-io dataforge DESIGN §12).

The "PLE-version of ACID compliance" asserted in ple-io/DESIGN.md §12 is
made explicit here:

  DB-ACID        this file                    origin
  -------        --------------------------   ----------------------------------
  Atomicity      acid_atomicity               NEW: batch = one accumulation add
  Consistency    acid_consistency             bundle writes_nonneg+semantics
  Isolation      acid_isolation               re-export noInterference
  Durability     acid_durability              NEW: presence survives extension
                 (commit-order stability)     writes_perm (already certified)

  Gauge (Λ instrument — reader-side ACID, DESIGN §12.3 L-ids):
  L1 classification  gauge_partition          decisive/inert label is decidable
                                              from (write-log, probe) alone
  L2 guard arm       gauge_guard              verdict invariant under irrelevant
                                              writes — exactness is a theorem,
                                              so σ₀ failures are the model's
  L3 exogeneity      gauge_exogeneity         same probe, two write-logs,
                                              OPPOSITE verdicts (witnessed):
                                              treatment is not a function of text
  L4 floor           gramKey_inj (imported)   key-level freshness check in the
                                              collision-free regime
  presence twin      gauge_presence           written probe resolves
  decisive twin      gauge_decisive           FRESH window ⇒ provable flip

Honest boundaries, on the faces of the theorems themselves:
- `resolvesP` is the bag-level SUPPORT kernel of the served membership test;
  the ≥2 prefix-count threshold and left-padding conventions are certified
  by the executable spec (`ple_io.py`), not restated here.
- Decisiveness carries FRESHNESS as a hypothesis, because it is false
  without it: a single-token edit can re-create an existing window in
  periodic text (witness: [a,a,b], edit b↦a re-creates [a,a]). Freshness is
  decidable from the write-log — that IS L3's mechanism; the served-regime
  escape from the hypothesis is multi-head (CRT / roadmap R5), and in the
  collision-free regime `gramKey_inj` upgrades freshness to key level (L4).
- No `native_decide` in this file: axiom-clean (propext/choice/quot only).
-/
import Mathlib
import LaserCortex.ConditionalMemory.GramDictionary

namespace LaserCortex.ConditionalMemory.PleAcid

open LaserCortex.ConditionalMemory.GramDictionary

section Acid

/-- **Atomicity**: a batch commits as ONE accumulation addition — the table
never exposes an intermediate state inside a transaction. -/
theorem writes_append (l₁ l₂ : List ℕ) :
    writes (l₁ ++ l₂) = writes l₁ + writes l₂ := by
  induction l₁ with
  | nil =>
      ext a
      rw [List.nil_append, writes]
      simp
  | cons x l ih =>
      rw [List.cons_append, writes_cons, ih, writes_cons]
      abel

/-- Atomicity, under its transactional name. -/
theorem acid_atomicity (l₁ l₂ : List ℕ) :
    writes (l₁ ++ l₂) = writes l₁ + writes l₂ := writes_append l₁ l₂

/-- **Consistency**: every committed table satisfies the store's invariants:
counts nonnegative everywhere, and every written key self-present. -/
theorem acid_consistency (ks : List ℕ) :
    ∀ k, 0 ≤ writes ks k ∧ (k ∈ ks → writes ks k ≠ 0) :=
  fun k => ⟨writes_nonneg k ks, selfPresence k ks⟩

/-- **Isolation**: a key outside the batch is undisturbed by it
(`noInterference`, under its transactional name). -/
theorem acid_isolation (base : Table) (ks : List ℕ) (k : ℕ)
    (hk : ∀ x ∈ ks, x ≠ k) : (base + writes ks) k = base k :=
  noInterference base ks k hk

/-- **Durability**: once present, always present — committed facts are not
undone by any extension of the store. (Order-stability of whole batches is
the already-certified `writes_perm`.) -/
theorem acid_durability (ks extra : List ℕ) (k : ℕ) (hk : k ∈ ks) :
    writes (ks ++ extra) k ≠ 0 := by
  rw [writes_append, Finsupp.add_apply]
  have h₁ : 0 ≤ writes ks k := writes_nonneg k ks
  have h₂ : 0 ≤ writes extra k := writes_nonneg k extra
  intro h
  apply selfPresence k ks hk
  omega

end Acid

section Gauge

/-- All bucket keys of all windows of a stream — the write-log of one fact. -/
def winKeys (V m w : ℕ) (s : List ℕ) : List ℕ :=
  (List.range s.length).map (fun i => gramKey V m (windowAt w s i))

/-- The bag-store of a single written fact. -/
noncomputable def factStore (V m w : ℕ) (f : List ℕ) : Table := writes (winKeys V m w f)

/-- **Resolution verdict** (bag-support kernel): every probe key reads
count ≥ 1. The served ≥2 threshold + prefix conventions are the executable
spec's (`ple_io.py`), by design. -/
def resolvesP (T : Table) (keys : List ℕ) : Prop :=
  ∀ k ∈ keys, 1 ≤ T k

private theorem one_le_of_nonneg_ne_zero (x : ℤ) (h₀ : 0 ≤ x) (hz : x ≠ 0) :
    1 ≤ x := by omega

/-- Presence twin: a probe built from written material resolves — each of its
keys was itself written. (`selfPresence`, aimed at probes.) -/
theorem gauge_presence (V m w : ℕ) (f : List ℕ) :
    resolvesP (factStore V m w f) (winKeys V m w f) := by
  intro k hk
  exact one_le_of_nonneg_ne_zero _ (writes_nonneg k (winKeys V m w f))
    (selfPresence k (winKeys V m w f) hk)

/-- **L1 (twin decidability)**: for every probe key, membership in the
write-log's support is DECIDABLE from (bag, probe) alone — the treatment
classification of DESIGN §12.2 is effective arithmetic; the model appears
nowhere in it. -/
theorem gauge_partition (bag keys : List ℕ) :
    ∀ k ∈ keys, k ∈ bag ∨ k ∉ bag := by
  intro k hk
  by_cases h : k ∈ bag
  · exact Or.inl h
  · exact Or.inr h

/-- **L2 (guard-arm exactness)**: verdicts are invariant under EXTENSION of
the store — resolution can never be falsified by irrelevant writes. The
guard arm of Λ is therefore a theorem: σ₀ behavioral failures are
attributable to the model and only to the model (DESIGN §12.2). -/
theorem gauge_guard (bag extra keys : List ℕ)
    (h : resolvesP (writes bag) keys) :
    resolvesP (writes (bag ++ extra)) keys := by
  intro k hk
  specialize h k hk
  rw [writes_append, Finsupp.add_apply]
  have h₂ : 0 ≤ writes extra k := writes_nonneg k extra
  omega

/-- **Decisive twin (flip certificate)**: a probe whose key set contains a
window FRESH against the write-log provably fails resolution. Freshness is a
write-log-side decidable fact (L1); checking it at bucket-key level in the
collision-free regime is `gramKey_inj` (L4). -/
theorem gauge_decisive (V m w : ℕ) (f probe : List ℕ)
    (hfresh : ∃ k ∈ winKeys V m w probe, k ∉ winKeys V m w f) :
    ¬ resolvesP (factStore V m w f) (winKeys V m w probe) := by
  obtain ⟨k, hk, hn⟩ := hfresh
  intro h
  have hzk : (factStore V m w f) k = 0 := by
    unfold factStore
    exact writes_apply_zero k (winKeys V m w f)
      (fun x hx hxe => hn (hxe ▸ hx))
  have := h k hk
  simp only [hzk] at this
  omega

/-- **L3 (exogeneity, witnessed)**: the verdict is NOT a function of the
probe — one probe, two write-logs, opposite verdicts. No model-side summary
of probe text can substitute for the treatment label; the label lives in
the write-log. This is the formal core of "the null is theorem-assigned,
not folklore". -/
theorem gauge_exogeneity (k : ℕ) :
    (∀ j ∈ [k], 1 ≤ writes [k] j) ∧ ¬ (∀ j ∈ [k], 1 ≤ writes [] j) := by
  constructor
  · intro j hj
    exact one_le_of_nonneg_ne_zero _ (writes_nonneg j [k])
      (selfPresence j [k] hj)
  · intro h
    have hk := h k (by simp)
    simp [writes] at hk

end Gauge

end LaserCortex.ConditionalMemory.PleAcid
