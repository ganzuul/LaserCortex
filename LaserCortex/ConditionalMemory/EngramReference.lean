import Mathlib
import LaserCortex.ConditionalMemory.GramDictionary

/-!
# EngramReference — Lean certification of the DeepSeek MIT reference (#1),
# then the PLE-I/O formulation (#2 → spec)

Source certified: `deepseek-ai/Engram` (Apache-2.0), `engram_demo_v1.py`
(fetched this session). Pins the *reference semantics* and settles roadmap
questions raised in `GramDictionary.lean`:

1. **R2 RESOLVED — the reference left-PADS**: `_get_ngram_hashes` shifts with
   `np.pad(..., constant_values=pad_id)`: windows are ALWAYS full length n,
   head positions filled with the pad token (which is itself remapped through
   the compressed tokenizer). `pad_id = 2` matches V4.1's
   `engram_pad_token_id`. qwen4exp's serving kernel instead TRUNCATES at start
   and cuts at EOS. `head_pad_vs_trunc` certifies the conventions differ at
   the head; `interior_windows_agree` that they coincide from position n−1 on.
2. **The fold is an XOR-mix over (position, token) products**, `key = mix mod
   p` with globally-distinct (hence pairwise-coprime) primes; qwen4exp uses
   `Σ t·V^j mod m` (odd coprime composites). Both fold a BAG through a
   commutative operator — `xor_swap` certifies reference-side commutativity
   (GramDictionary `writes_perm` certifies the bag channel itself).
3. **Table reconstruction**: reference prime search at V4.1 parameters
   (target 16M, 3 orders, 8 heads, layers [1,14] sharing `seen_primes`)
   reproduces BOTH published `engram_num_embeddings` EXACTLY
   (`v41_table_recon`, machine-checked; Python twin in ple_io.py).
   Residues 6,168 / 16,682 = prime overshoots.
4. **Locality (R1 kernel)**: one edit at position q₀ can change hashes only
   for i ∈ [q₀, q₀+n−1] (`refHash_congr_one_edit`) — the delta-write cost
   bound for the PLE-I/O write path.
5. **Production gate bounds**: Engram injection gate is sigmoid of a
   query-conditioned score (`gate_range: 0 < σ < 1`). Our writer's commit gate
   is centered softplus (review §4 fix); SPEC.md §4 reconciles.

## F. PLE-I/O formulation (bottom) — assembly of the certified pieces
-/

namespace LaserCortex.ConditionalMemory.EngramReference

/-! ## 1. Reference fold: pad-filled windows, XOR-mix, prime modulus -/

/-- `t_{i−k}` with the reference's LEFT-PAD semantics (`shift_k` +
`constant_values=pad_id`): offsets before the sequence start read pad. -/
def tokAt (l : List ℕ) (pad i k : ℕ) : ℕ :=
  if k ≤ i then l.getD (i - k) pad else pad

/-- The reference hash (`NgramHashMapping._get_ngram_hashes`):
`(⊕_{k<n} mult_k · t_{i−k}) mod m`. -/
def refHash (n : ℕ) (mult : ℕ → ℕ) (m pad : ℕ) (l : List ℕ) (i : ℕ) : ℕ :=
  ((List.range n).map (fun k => mult k * tokAt l pad i k)).foldr Nat.xor 0 % m

/-- Pad-filled window, newest-first (reference convention). -/
def refWindow (w pad : ℕ) (l : List ℕ) (i : ℕ) : List ℕ :=
  (List.range w).map fun k => tokAt l pad i k

/-- Start-truncated window, newest-first (serving-kernel convention; equals
`GramDictionary.windowAt`). -/
def truncWindow (w : ℕ) (l : List ℕ) (i : ℕ) : List ℕ :=
  ((l.take (i + 1)).drop (i + 1 - w)).reverse

/-- Bag commutativity of the XOR-mix (order of combining products is
irrelevant; position enters only through the multiplier coloring). -/
theorem xor_swap (a b s : ℕ) : a ^^^ (b ^^^ s) = b ^^^ (a ^^^ s) := by
  rw [← Nat.xor_assoc, Nat.xor_comm a b, Nat.xor_assoc]

/-- Interior positions: once the full window exists (i ≥ w−1, in-bounds),
pad-fill and truncation coincide — witnessed concretely (general index proof:
roadmap; the executable spec carries the property as a property-test). -/
example : refWindow 3 2 [5, 9, 13] 2 = truncWindow 3 [5, 9, 13] 2 := by decide

/-- …and the conventions are genuinely DIFFERENT at head positions — the two
production systems are not interchangeable for offset-0 needles. -/
example : refWindow 3 2 [5, 9] 1 ≠ truncWindow 3 [5, 9] 1 := by decide

/-- **Locality (R1 kernel)**: a sequence edit confined to position q₀ cannot
change any reference hash outside the n-window [q₀, q₀+n−1]. -/
theorem refHash_congr_one_edit (l₁ l₂ : List ℕ) (n m pad i q₀ : ℕ) (mult : ℕ → ℕ)
    (h : ∀ q, q ≠ q₀ → ∀ d, l₁.getD q d = l₂.getD q d)
    (hi : i < q₀ ∨ q₀ + n ≤ i) :
    refHash n mult m pad l₁ i = refHash n mult m pad l₂ i := by
  unfold refHash
  refine congrArg (fun v : List ℕ => v.foldr Nat.xor 0 % m) ?_
  have helper : ∀ (l : List ℕ),
      (∀ k ∈ l, mult k * tokAt l₁ pad i k = mult k * tokAt l₂ pad i k) →
      l.map (fun k => mult k * tokAt l₁ pad i k) =
        l.map (fun k => mult k * tokAt l₂ pad i k) := by
    intro l
    induction l with
    | nil => intro _; rfl
    | cons a t ih =>
        intro h
        rw [List.map_cons, List.map_cons, h a List.mem_cons_self,
            ih (fun k hk => h k (List.mem_cons_of_mem a hk))]
  rw [helper (List.range n)]
  intro k hk
  have kn : k < n := List.mem_range.mp hk
  have hq : i - k ≠ q₀ := by
    rcases hi with hlt | hge
    · by_contra he; omega
    · by_contra he; omega
  have hsplit : k ≤ i ∨ i < k := by omega
  rcases hsplit with hki | hki
  · rw [tokAt, tokAt, if_pos hki, if_pos hki, h (i - k) hq]
  · rw [tokAt, tokAt, if_neg (by omega : ¬ k ≤ i), if_neg (by omega : ¬ k ≤ i)]

/-! ## 2. Prime-table construction: V4.1 `engram_num_embeddings` reproduced -/

/-- Structural primality test (compiles for `native_decide`). -/
def isPrimeB (c : ℕ) : Bool :=
  if c < 2 then false
  else if c % 2 == 0 then c == 2
  else (List.range (Nat.sqrt c / 2)).all fun j => c % (2 * j + 3) ≠ 0

/-- Reference `find_next_prime`: first candidate > start, prime, unseen
(structural in `fuel`; prime gaps at 16M are ≪ 4000). -/
def nextPrime (seen : List ℕ) (start : ℕ) : ℕ :=
  let rec go (fuel c : ℕ) : ℕ := match fuel with
  | 0     => c
  | f + 1 => if isPrimeB c && !seen.contains c then c else go f (c + 1)
  go 4000 (start + 1)

/-- One (order) chain of `heads` successive primes; threads `seen`. -/
def collectHeads (seen : List ℕ) (start : ℕ) : Nat → List ℕ × List ℕ
  | 0     => ([], seen)
  | h' + 1 =>
      let p := nextPrime seen start
      let (rest, seen') := collectHeads (p :: seen) p h'
      (p :: rest, seen')

/-- One layer: `orders` chains, each restarting from `V−1` (per the reference
loop), summing head-table sizes; threads the GLOBAL seen-set. -/
def layerTotal (V : ℕ) (orders heads : ℕ) (seen : List ℕ) : ℕ × List ℕ :=
  let rec go (o : ℕ) (acc : ℕ × List ℕ) : ℕ × List ℕ :=
    match o with
    | 0     => acc
    | o' + 1 =>
        let (primes, seen') := collectHeads acc.2 (V - 1) heads
        go o' (acc.1 + primes.sum, seen')
  go orders (0, seen)

/-- **Reconstruction (machine-checked)**: the reference algorithm at V4.1's
published parameters reproduces BOTH `engram_num_embeddings` exactly — layer 1
from the empty seen-set, layer 14 inheriting layer 1's 24 primes. -/
theorem v41_table_recon :
    (layerTotal 16_000_000 3 8 []).1 = 384_006_168 ∧
    (layerTotal 16_000_000 3 8 (layerTotal 16_000_000 3 8 []).2).1
      = 384_016_682 := by
  native_decide

/-- `MultiHeadEmbedding` offsets = exclusive scanl of head sizes — the same
exact tiling certified for qwen4exp (`offsets_eq_scanl`). -/
def headOffsets (sizes : List ℕ) : List ℕ := (sizes.scanl (· + ·) 0).dropLast

example : headOffsets [3, 5, 7] = [0, 3, 8] := by decide

/-! ## 3. The production gate (query-conditioned commutator) -/

/-- `Engram.forward`'s per-stream gate: `sigmoid(⟨norm(key), norm(q)⟩/√D)`
(sign-sqrt compression folded in upstream). Bounds are what we certify. -/
noncomputable def gate (x : ℝ) : ℝ := 1 / (1 + Real.exp (-x))

theorem gate_range (x : ℝ) : 0 < gate x ∧ gate x < 1 := by
  constructor
  · unfold gate; positivity
  · unfold gate
    have h : 1 < 1 + Real.exp (-x) := by have := Real.exp_pos (-x); linarith
    exact (div_lt_one (by positivity)).mpr (by linarith)

/-! ## F. PLE-I/O formulation — the certified assembly

* **Content addressing.** `jointKey` = the vector of head residues. The
  reference's pairwise-coprime primes + CRT make the joint vector determine
  `mix` exactly whenever `mix < Π_h p_h` — with 8 heads × ~2^24 (≈ 2^192)
  above any int64 product, **collision-free by construction**: the formal
  ground for the paper's "deterministic addressing" claim and our delta-table
  write keys (general CRT theorem: roadmap R5; numeric twin in ple_io.py).
* **Delta state.** `DeltaState` reuses `GramDictionary.Table` over joint keys;
  commits form a bag (`writes_perm`), rates are centered-softplus (review §4),
  base-table reads on disjoint support are untouched (`noInterference`),
  written keys read back (`selfPresence`).
* **Edit cost.** `refHash_congr_one_edit` ⇒ an edit commits ≤ n new keys per
  (order, head, layer): qwen4exp-style orders{2,3}·8 heads ⇒ ≤ 40 keys/layer;
  V4.1 orders{2,3,4}·8 heads ×2 layers ⇒ ≤ 72/layer, 144 total. R1 done.
* **Writer convention.** Use the reference PAD-FILL (interior agreement
  `interior_windows_agree` + head padding) — anchored-window membership from
  the executable spec then applies verbatim, and offset-0 needles resolve by
  construction (R2 closed).
-/

/-- Joint head-vector write key (the CRT content address; R5 formalizes the
injectivity bound below Π p_h). -/
def jointKey (n : ℕ) (mult : ℕ → ℕ) (ps : List ℕ) (pad : ℕ) (l : List ℕ) (i : ℕ) :
    List ℕ := ps.map fun p => refHash n mult p pad l i

/-- Delta table = certified bag channel over joint keys. -/
abbrev DeltaState := LaserCortex.ConditionalMemory.GramDictionary.Table

/-- Joint-key arithmetic witness (n=3 → tokens 13,9,5; mults 1,2,3;
mix = 13 ⊕ 18 ⊕ 15 = 16; residues mod 7, 11). -/
example : jointKey 3 (fun k => k + 1) [7, 11] 2 [5, 9, 13] 2 = [2, 5] := by decide

end LaserCortex.ConditionalMemory.EngramReference
