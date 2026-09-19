import LaserCortex.ConditionalMemory.GramDictionary

/-!
# AddressingContract — the contract at the store/consumer interface

Roadmap §12 identified the gap: LaserCortex *names* the joint-key CRT hypothesis
(`GramDictionary.headMods_pairwise_coprime`) and **nothing consumes it**, so the one question that decides
whether a fresh trunk can use the as-shipped 196B store — *does the addressing resolve distinct n-grams to
distinct rows?* — had no theorem behind it.

This module supplies it **as a contract at the interface**, not as a fact about one implementation. The
distinction matters and was a correction from the user: the theorem quantifies over an abstract window map
`κ`, so it commits neither to LaserCortex's positional `gramVal` nor to V4.1's XOR fold. A specific store
discharges the two hypotheses; the *composition with the heads* is proved once, here.

## The contract

A consumer of the addressing API may rely on three things:

* **`jointAddr_inj`** — distinct windows get distinct address vectors, **provided** the window map is
  injective-and-bounded and the per-head moduli are pairwise coprime with `V^w ≤ ∏ mᵢ`. This is the tight
  condition: the product of the moduli, not a loose counting bound. The ~38 orders of magnitude of slack in
  V4.1's 8 heads is then *accounted for* by the hypothesis rather than assumed — which is the point, since
  that slack is what the coprime construction buys.
* **`mapAddr` / `mapAddr_window`** — an address is a function of its **window alone**. Nothing else is in
  scope, so *no trunk can change it*: this is the index half of the index/gate split, made a statement about
  a signature rather than a hope.
* **`mapAddr_causal`** — positions after `i` cannot affect the address at `i`, which is what makes prefetch
  and single-token edit accounting meaningful.

## What is NOT here, stated so it is not assumed

The contract's hypotheses must be **discharged for the served window map**. LaserCortex's `gramVal`
discharges them (`GramDictionary.gramVal_inj`, `gramVal_lt_pow`) — see `gramVal_addr_inj`. **V4.1's XOR fold
does not yet**: it is not a positional map, and `xorFold_inj`/`xorFold_bound` are owed. Until they exist,
`jointAddr_inj` says *what would be true* of V4.1's addressing, not *that* it is true.
-/

namespace LaserCortex.ConditionalMemory.AddressingContract

open LaserCortex.ConditionalMemory.GramDictionary

variable {V w : ℕ}

/-- **The multi-head addressing contract, tight in the product of the moduli.**

If a window map `κ` is injective on windows of length `≤ w` over the alphabet `< V`, and its values stay
below `V ^ w`, then reducing it modulo **pairwise-coprime** head moduli is injective as soon as the moduli's
**product** covers the window space. The CRT does the work: agreement modulo each head forces agreement
modulo the product, and the product then exceeds the value, so the value itself is determined.

This is `GramDictionary.gramKey_inj` with the single modulus replaced by the product of the heads — i.e. it
is the theorem that TURNS the corpus's named CRT hypothesis into a result. -/
theorem jointAddr_inj (κ : List ℕ → ℕ) (ms : List ℕ)
    (hinj : ∀ l₁ l₂ : List ℕ, l₁.length = l₂.length → (∀ x ∈ l₁ ++ l₂, x < V) →
      l₁.length ≤ w → l₂.length ≤ w → κ l₁ = κ l₂ → l₁ = l₂)
    (hbound : ∀ l : List ℕ, (∀ x ∈ l, x < V) → l.length ≤ w → κ l < V ^ w)
    (hcop : ms.Pairwise Nat.Coprime) (hprod : V ^ w ≤ ms.prod)
    (l₁ l₂ : List ℕ) (hlen : l₁.length = l₂.length)
    (hd : ∀ x ∈ l₁ ++ l₂, x < V) (hw₁ : l₁.length ≤ w) (hw₂ : l₂.length ≤ w)
    (hk : ∀ m ∈ ms, κ l₁ % m = κ l₂ % m) : l₁ = l₂ := by
  -- agreement at every head is agreement modulo the product (this is the CRT, and it is where
  -- pairwise coprimality is USED rather than merely assumed)
  -- `Nat.modEq_list_prod_iff` indexes the heads positionally (`l.get i`), not by membership, so the
  -- membership hypothesis is converted rather than restated.
  have hmod : Nat.ModEq ms.prod (κ l₁) (κ l₂) :=
    (Nat.modEq_list_prod_iff hcop).mpr (fun i => hk (ms.get i) (List.get_mem ms i))
  -- and the product dominates the window space, so neither value wraps
  have hd₁ : ∀ x ∈ l₁, x < V := fun x hx => hd x (List.mem_append_left l₂ hx)
  have hd₂ : ∀ x ∈ l₂, x < V := fun x hx => hd x (List.mem_append_right l₁ hx)
  have b₁ : κ l₁ < ms.prod :=
    (hbound l₁ hd₁ hw₁).trans_le hprod
  have b₂ : κ l₂ < ms.prod :=
    (hbound l₂ hd₂ hw₂).trans_le hprod
  rw [Nat.ModEq, Nat.mod_eq_of_lt b₁, Nat.mod_eq_of_lt b₂] at hmod
  exact hinj l₁ l₂ hlen hd hw₁ hw₂ hmod

-- ---------------------------------------------------------------------------
-- The positional instance: LaserCortex's own key map discharges the hypotheses
-- ---------------------------------------------------------------------------

/-- LaserCortex's `gramVal` satisfies the contract's injectivity hypothesis. -/
theorem gramVal_inj' (hV : 0 < V) : ∀ l₁ l₂ : List ℕ, l₁.length = l₂.length →
    (∀ x ∈ l₁ ++ l₂, x < V) → l₁.length ≤ w → l₂.length ≤ w →
    gramVal V l₁ = gramVal V l₂ → l₁ = l₂ :=
  fun l₁ l₂ hlen hd _ _ heq => gramVal_inj V hV l₁ l₂ hlen hd heq

/-- LaserCortex's `gramVal` satisfies the contract's bound hypothesis. -/
theorem gramVal_bound (hV : 0 < V) : ∀ l : List ℕ, (∀ x ∈ l, x < V) → l.length ≤ w →
    gramVal V l < V ^ w :=
  fun l hd hl => (gramVal_lt_pow V hV l hd).trans_le (Nat.pow_le_pow_right hV hl)

/-- **The contract discharged for the positional key map** — so the CRT step is instantiated, not merely
available, for the corpus's own addressing. -/
theorem gramVal_addr_inj (hV : 0 < V) (ms : List ℕ) (hcop : ms.Pairwise Nat.Coprime)
    (hprod : V ^ w ≤ ms.prod) (l₁ l₂ : List ℕ) (hlen : l₁.length = l₂.length)
    (hd : ∀ x ∈ l₁ ++ l₂, x < V) (hw₁ : l₁.length ≤ w) (hw₂ : l₂.length ≤ w)
    (hk : ∀ m ∈ ms, gramVal V l₁ % m = gramVal V l₂ % m) : l₁ = l₂ :=
  jointAddr_inj (gramVal V) ms (gramVal_inj' hV) (gramVal_bound hV) hcop hprod
    l₁ l₂ hlen hd hw₁ hw₂ hk

-- ---------------------------------------------------------------------------
-- The API surface: per-position addresses, and what a consumer may rely on
-- ---------------------------------------------------------------------------

/-- **The addressing API.** One bucket index per head for the window ending at `i`. This is the whole of
what a consumer sees; note that it is a function of `(V, ms, w, l, i)` and of **nothing else** — there is no
hidden-state argument, which is the index half of the index/gate split expressed as a signature. -/
def mapAddr (V : ℕ) (ms : List ℕ) (w : ℕ) (l : List ℕ) (i : ℕ) : List ℕ :=
  ms.map (fun m => gramKey V m (windowAt w l i))

/-- **Contract: an address depends on its window alone.** Two sequences that present the same window at the
same index get the same address vector. There is no other input, so no consumer — and in particular no
trunk's hidden state — can influence it. -/
theorem mapAddr_window {l l' : List ℕ} {i : ℕ} (h : windowAt w l i = windowAt w l' i) :
    mapAddr V ms w l i = mapAddr V ms w l' i := by
  simp only [mapAddr, h]

/-- **Contract: locality.** The window at `i` is a function of `l.take (i+1)`, so a sequence that agrees with
`l` up to and including index `i` yields the same address there. Edits later in the stream cannot move an
earlier position's address — the causality that makes prefetch well-defined and lets `≈144` keys be the
whole cost of a one-token edit. -/
theorem mapAddr_causal {l l' : List ℕ} {i : ℕ} (h : l.take (i + 1) = l'.take (i + 1)) :
    mapAddr V ms w l i = mapAddr V ms w l' i := by
  refine mapAddr_window (V := V) (ms := ms) ?_
  simp only [windowAt, h]

-- ---------------------------------------------------------------------------
-- Instantiation on the SHIPPED store's parameters
-- ---------------------------------------------------------------------------

/-! ### V4.1's actual moduli

These are the served constants, not LaserCortex's illustrative `headMods` (which are 16 moduli near
`2.0e7` and match neither pinned reference — see roadmap §12). Layer 1's 8 head moduli per order, drawn by
`EngramLayout.from_args` / `find_next_prime` from `engram_vocab_size - 1 = 15,999,999`.

The alphabet is the **compressed** vocab: `build_compressed_token_map` maps the raw 129,280 onto
`0 .. 99,091`, and the hash consumes compressed ids. Using the raw vocab here would be the wrong referent
*and* would flatter the condition by a factor of `(129280/99092)^4 ≈ 2.9`. -/

/-- The compressed alphabet the hash actually sees. -/
def v41Alphabet : ℕ := 99092

/-- Layer 1, order 2, heads 0-7. -/
def v41ModsOrder2 : List ℕ :=
  [16000057, 16000079, 16000081, 16000097, 16000121, 16000129, 16000133, 16000183]
/-- Layer 1, order 3, heads 0-7. -/
def v41ModsOrder3 : List ℕ :=
  [16000189, 16000207, 16000211, 16000253, 16000277, 16000289, 16000307, 16000321]
/-- Layer 1, order 4, heads 0-7 (the binding case: `w = 4`). -/
def v41ModsOrder4 : List ℕ :=
  [16000339, 16000381, 16000393, 16000399, 16000403, 16000409, 16000447, 16000463]

theorem v41ModsOrder2_coprime : v41ModsOrder2.Pairwise Nat.Coprime := by native_decide
theorem v41ModsOrder3_coprime : v41ModsOrder3.Pairwise Nat.Coprime := by native_decide
theorem v41ModsOrder4_coprime : v41ModsOrder4.Pairwise Nat.Coprime := by native_decide

/-- **The capacity condition holds with room to spare.** The three ratios below are the *slack the coprime
construction buys*: the product of 8 primes dominates the window space by ~28 (order 4) to ~37 (order 2)
orders of magnitude: **47.6** (order 2), **42.6** (order 3), **37.6** (order 4). Recording them is the
point — the overhead is not an excuse for a loose theorem, it is the margin the theorem's hypothesis
accounts for, and it is a function of the coprime construction rather than a free parameter. (First written
as "~28 to ~37", which was wrong in both numbers; computed here instead.) -/
theorem v41Order2_capacity : v41Alphabet ^ 2 ≤ v41ModsOrder2.prod := by native_decide
theorem v41Order3_capacity : v41Alphabet ^ 3 ≤ v41ModsOrder3.prod := by native_decide
theorem v41Order4_capacity : v41Alphabet ^ 4 ≤ v41ModsOrder4.prod := by native_decide

/-- **What the shipped head structure buys, at the binding order.** With 8 pairwise-coprime moduli whose
product covers `V^4`, the CRT step is available for V4.1's own constants.

**SCOPE — read this before citing it.** This instantiates the contract on the **positional** map `gramVal`
with V4.1's moduli and alphabet. It therefore establishes that the *head structure is sufficient*; it does
**not** yet certify V4.1's **XOR** fold, whose own injectivity-and-bound hypotheses are the owed obligation
(`xorFold_inj`, `xorFold_bound`). The contract is what separates those two halves. -/
theorem v41_addr_inj_order4 (l₁ l₂ : List ℕ) (hlen : l₁.length = l₂.length)
    (hd : ∀ x ∈ l₁ ++ l₂, x < v41Alphabet) (hw₁ : l₁.length ≤ 4) (hw₂ : l₂.length ≤ 4)
    (hk : ∀ m ∈ v41ModsOrder4, gramVal v41Alphabet l₁ % m = gramVal v41Alphabet l₂ % m) :
    l₁ = l₂ :=
  gramVal_addr_inj (V := v41Alphabet) (w := 4) (by decide) v41ModsOrder4
    v41ModsOrder4_coprime v41Order4_capacity l₁ l₂ hlen hd hw₁ hw₂ hk

end LaserCortex.ConditionalMemory.AddressingContract
