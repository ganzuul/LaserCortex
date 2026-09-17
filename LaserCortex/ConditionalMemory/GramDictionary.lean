import Mathlib

/-!
# GramDictionary — Lean-first certificates for the PLE-I/O write channel

Formalizes the arithmetic of the `qwen4exp` PLE n-gram table **as the
production kernel computes it** (`sglang` CUDA `ngram_embedding.cuh`):

```
key(n,k,i) = ( Σ_{j=0}^{w−1} tok_{i−j} · V^j ) mod m_{n,k} + off_{n,k}
```

windows listed **newest-first** (kernel distance-`j` weights `V^j mod m`),
truncated at sequence start **and at EOS boundaries**; orders {2,3}, 8 heads
per order, 16 total. Real constants from the served model's GGUF metadata
(this session): V = 248,320; every `head_vocab_sizes` entry m ≈ 2.0×10⁷;
EOS = 248044; `ple.layers = [1]`. Note V² ≈ 6×10¹⁰ ≫ m: order-2 buckets
collide ~3000-way **by design** — disambiguation is multi-head (CRT
hypothesis certified below; full joint-injectivity is roadmap R5).

## What is certified here
- Positional algebra: `gramVal_append`, `gramVal_lt_pow`, `gramVal_inj`.
- `gramKey_inj` — the **collision-free regime** m ≥ V^w. The served model
  fails it (`norm_num` example): collisions are intrinsic; Stage-0 measures.
- Bag channel (the E1 spine): `Table := ℕ →₀ ℤ`; `writes` accumulates:
  `writes_perm` (write order irrelevant — the commutative channel),
  `writes_apply_zero`/`noInterference` (delta-table safety),
  `selfPresence` (needle reflex), `writes_nonneg`, `writes_snoc`.
- Real-model layout (`native_decide` against the actual GGUF arrays):
  `headMods_pairwise_coprime`, `offsets_eq_scanl`, `headWindows_disjoint`.
- §5: probe contract — `windowAt` truncation semantics + golden vectors.

## Roadmap (deliberately NOT assumed)
R0: kernel incremental fold (per-term mod accumulation) ⇔ `gramKey`.
R1: window locality — editing token at position p touches ≤ 2·(w−1) bucket
    keys per head; the delta-write cost bound for the write path.
R2: needle no-false-negatives **requires an explicit padding convention**:
    start-truncated substring windows do NOT match host windows at shared
    positions (design finding from formalization — left-pad both sides with
    a sentinel ∉ vocab, or key only anchored windows).
R3: k-spectrum order reconstruction (2-gram edge bag + 3-gram composition ⇒
    de Bruijn–Eulerian trails; the "commutativity/associativity" claim).
R5: full multi-head CRT joint injectivity below Π m_h (ℤ transfer,
    `IsCoprime.mul_dvd` + |a−b| < m₁m₂; next session).
-/

namespace LaserCortex.ConditionalMemory.GramDictionary

/-- Gram value, base V, window newest-first (`x` = current token, then
leftward context), mirroring the kernel's distance-`j` weights `V^j`. -/
def gramVal (V : ℕ) : List ℕ → ℕ
  | [] => 0
  | x :: l => x + V * gramVal V l

/-- Bucket key (pre-offset): positional value mod the head's modulus. -/
def gramKey (V m : ℕ) (l : List ℕ) : ℕ := gramVal V l % m

-- ---------------------------------------------------------------------------
-- 1. Positional algebra
-- ---------------------------------------------------------------------------

theorem gramVal_append (V : ℕ) :
    ∀ l₁ l₂ : List ℕ,
      gramVal V (l₁ ++ l₂) = gramVal V l₁ + V ^ l₁.length * gramVal V l₂
  | [], l₂ => by simp [gramVal]
  | x :: l₁, l₂ => by
      rw [List.cons_append, gramVal, gramVal_append V l₁ l₂, gramVal,
          List.length_cons, Nat.pow_succ]
      ring

theorem gramVal_lt_pow (V : ℕ) (hV : 0 < V) :
    ∀ l : List ℕ, (∀ x ∈ l, x < V) → gramVal V l < V ^ l.length
  | [], _ => Nat.one_pos
  | x :: l, hx => by
      have hxl : x < V := hx x List.mem_cons_self
      have hlt : gramVal V l < V ^ l.length :=
        gramVal_lt_pow V hV l fun y hy => hx y (List.mem_cons_of_mem x hy)
      calc x + V * gramVal V l
          < V + V * gramVal V l := Nat.add_lt_add_right hxl _
        _ = V * (gramVal V l + 1) := by ring
        _ ≤ V * V ^ l.length := Nat.mul_le_mul_left _ (Nat.succ_le_of_lt hlt)
        _ = V ^ (l.length + 1) := by rw [← Nat.pow_succ']

/-- Same-length windows over the alphabet `< V` are determined by their value. -/
theorem gramVal_inj (V : ℕ) (hV : 0 < V) :
    ∀ l₁ l₂ : List ℕ, l₁.length = l₂.length →
      (∀ x ∈ l₁ ++ l₂, x < V) → gramVal V l₁ = gramVal V l₂ → l₁ = l₂
  | [], [], _, _, _ => rfl
  | [], _x :: l₂, hl, _, _ => by
      exfalso
      rw [List.length_nil, List.length_cons] at hl
      omega
  | x :: l₁, [], hl, _, _ => by
      exfalso
      rw [List.length_nil, List.length_cons] at hl
      omega
  | x :: l₁, y :: l₂, hl, hd, he => by
      have hxl : x < V :=
        hd x (List.mem_append_left (y :: l₂) List.mem_cons_self)
      have hyl : y < V :=
        hd y (List.mem_append_right (x :: l₁) List.mem_cons_self)
      have e1 : gramVal V (x :: l₁) % V = x := by
        rw [gramVal, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt hxl]
      have e2 : gramVal V (y :: l₂) % V = y := by
        rw [gramVal, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt hyl]
      have hxy : x = y := by rw [← e1, ← e2, he]
      subst hxy
      have hgh : V * gramVal V l₁ = V * gramVal V l₂ := Nat.add_left_cancel he
      have hg : gramVal V l₁ = gramVal V l₂ := Nat.eq_of_mul_eq_mul_left hV hgh
      have hlen : l₁.length = l₂.length := by simpa using hl
      have hd' : ∀ z ∈ l₁ ++ l₂, z < V := by
        intro z hz
        refine hd z ?_
        rcases List.mem_append.mp hz with h1 | h2
        · exact List.mem_append_left (x :: l₂) (List.mem_cons_of_mem x h1)
        · exact List.mem_append_right (x :: l₁) (List.mem_cons_of_mem x h2)
      rw [gramVal_inj V hV l₁ l₂ hlen hd' hg]

-- ---------------------------------------------------------------------------
-- 2. Injectivity regimes for bucket keys
-- ---------------------------------------------------------------------------

/-- **Collision-free regime.** If the bucket count dominates the window space
(m ≥ V^w), same-length windows (digits < V, length ≤ w) are determined by
their key. -/
theorem gramKey_inj (V m w : ℕ) (hV : 0 < V) (_hw : 0 < w) (hm : V ^ w ≤ m)
    (l₁ l₂ : List ℕ) (hlen : l₁.length = l₂.length)
    (hd : ∀ x ∈ l₁ ++ l₂, x < V) (hw₁ : l₁.length ≤ w) (hw₂ : l₂.length ≤ w)
    (hk : gramKey V m l₁ = gramKey V m l₂) : l₁ = l₂ := by
  apply gramVal_inj V hV l₁ l₂ hlen hd
  have hd₁ : ∀ x ∈ l₁, x < V := fun x hx => hd x (List.mem_append_left l₂ hx)
  have hd₂ : ∀ x ∈ l₂, x < V := fun x hx => hd x (List.mem_append_right l₁ hx)
  have b₁ : gramVal V l₁ < m :=
    ((gramVal_lt_pow V hV l₁ hd₁).trans_le (Nat.pow_le_pow_right hV hw₁)).trans_le hm
  have b₂ : gramVal V l₂ < m :=
    ((gramVal_lt_pow V hV l₂ hd₂).trans_le (Nat.pow_le_pow_right hV hw₂)).trans_le hm
  rw [gramKey, gramKey, Nat.mod_eq_of_lt b₁, Nat.mod_eq_of_lt b₂] at hk
  exact hk

/-- The served model's regime **fails** single-head injectivity:
248,320³ ≫ every m ≈ 2×10⁷. Collisions are intrinsic; the multi-head design
is the rescue (roadmap R5 quantifies; the Stage-0 probe measures). -/
example : ¬ (248320 ^ 3 ≤ 20000171) := by norm_num

-- ---------------------------------------------------------------------------
-- 3. The bag channel: delta tables as commutative accumulations
-- ---------------------------------------------------------------------------

/-- A delta table: bucket key → accumulation. -/
abbrev Table := ℕ →₀ ℤ

/-- One occurrence of bucket `k`. -/
noncomputable def write (k : ℕ) : Table := Finsupp.single k (1 : ℤ)

/-- A batch of writes accumulates occurrences. -/
noncomputable def writes : List ℕ → Table
  | [] => 0
  | x :: ks => write x + writes ks

theorem writes_cons (x : ℕ) (ks : List ℕ) :
    writes (x :: ks) = write x + writes ks := rfl

/-- Snoc form: appends add their single at the far right. -/
theorem writes_snoc (l : List ℕ) (x : ℕ) :
    writes (l ++ [x]) = writes l + write x := by
  induction l with
  | nil => rw [List.nil_append, writes, writes]; abel
  | cons y l ih =>
      rw [List.cons_append, writes_cons, ih, writes_cons]
      abel

/-- **Write order is irrelevant** (E1's commutative channel): any permutation
of the batch accumulates identically. -/
theorem writes_perm (l₁ l₂ : List ℕ) (h : List.Perm l₁ l₂) : writes l₁ = writes l₂ := by
  induction h with
  | nil => rfl
  | @cons x l₁ l₂ h ih => rw [writes_cons, writes_cons, ih]
  | @swap x y l =>
      rw [writes_cons, writes_cons, writes_cons, writes_cons]
      abel
  | @trans l₁ l₂ l₃ h₁ h₂ ih₁ ih₂ => exact ih₁.trans ih₂

/-- Accumulations are nonnegative at every key. -/
theorem writes_nonneg (k : ℕ) : ∀ ks : List ℕ, 0 ≤ writes ks k
  | [] => le_refl _
  | x :: ks => by
      have h : 0 ≤ write x k := by
        rw [write, Finsupp.single_apply]
        rcases eq_or_ne x k <;> positivity
      have ih := writes_nonneg k ks
      rw [writes_cons, Finsupp.add_apply]
      exact add_nonneg h ih

/-- **No interference**: a key never written contributes zero. -/
theorem writes_apply_zero (k : ℕ) :
    ∀ ks : List ℕ, (∀ x ∈ ks, x ≠ k) → writes ks k = 0
  | [], _ => rfl
  | x :: ks, hx => by
      have hxk : write x k = 0 := by
        rw [write, Finsupp.single_apply, if_neg (hx x List.mem_cons_self)]
      have ih := writes_apply_zero k ks
      rw [writes_cons, Finsupp.add_apply, hxk,
          ih (fun y hy => hx y (List.mem_cons_of_mem x hy)), zero_add]

/-- **Delta-table safety**: reads outside the write-set see only the
pretrained accumulation. -/
theorem noInterference (base : Table) (ks : List ℕ) (k : ℕ)
    (hk : ∀ x ∈ ks, x ≠ k) : (base + writes ks) k = base k := by
  rw [Finsupp.add_apply, writes_apply_zero k ks hk, add_zero]

/-- **Self-presence** (needle reflex): every key in the batch reads back
nonzero. -/
theorem selfPresence (k : ℕ) : ∀ ks : List ℕ, k ∈ ks → writes ks k ≠ 0
  | [], h => absurd h List.not_mem_nil
  | x :: ks, h => by
      rw [writes_cons, Finsupp.add_apply]
      have ih := selfPresence k ks
      cases h with
      | head _ =>
          have h1 : write k k = (1 : ℤ) := by
            rw [write, Finsupp.single_apply, if_pos rfl]
          rw [h1]
          linarith [writes_nonneg k ks]
      | tail _ mem =>
          by_cases hxk : x = k
          · rw [write, Finsupp.single_apply, if_pos hxk]
            linarith [writes_nonneg k ks]
          · rw [write, Finsupp.single_apply, if_neg hxk, zero_add]
            exact ih mem

-- ---------------------------------------------------------------------------
-- 4. Real-model layout certificates (GGUF `qwen4exp`, this session)
--    (the three `native_decide` results below carry the standard compiler-trust
--     private axiom; §1–3 theorems are axiom-clean apart from propext/choice/quot)
-- ---------------------------------------------------------------------------

/-- `qwen4exp.ple.head_offsets` — 16 embedder slots (orders {2,3} × 8 heads). -/
def headOffsets : List ℕ :=
  [0, 20000003, 40000026, 60000059, 80000106, 100000165, 120000228,
   140000297, 160000374, 180000455, 200000548, 220000655, 240000802,
   260000955, 280001114, 300001275]

/-- `qwen4exp.ple.head_vocab_sizes` — per-head moduli m_h. -/
def headMods : List ℕ :=
  [20000003, 20000023, 20000033, 20000047, 20000059, 20000063, 20000069,
   20000077, 20000081, 20000093, 20000107, 20000147, 20000153, 20000159,
   20000161, 20000171]

/-- The 16 real moduli are **pairwise coprime** — the joint-key CRT
hypothesis holds for the actual served model. -/
theorem headMods_pairwise_coprime : headMods.Pairwise Nat.Coprime := by
  native_decide

/-- Offsets tile the table: the head h offset is the sum of the previous
h moduli (consecutive windows abut — no overlap, no gap). -/
theorem offsets_eq_scanl :
    headOffsets = (headMods.scanl (· + ·) 0).dropLast := by
  native_decide

/-- Head windows are pairwise disjoint: no bucket belongs to two embedders. -/
theorem headWindows_disjoint :
    (headOffsets.zip headMods).Pairwise fun (o₁, m₁) (o₂, m₂) =>
      o₁ + m₁ ≤ o₂ ∨ o₂ + m₂ ≤ o₁ := by
  native_decide

-- ---------------------------------------------------------------------------
-- 5. Probe contract: windowing semantics + golden vectors
-- ---------------------------------------------------------------------------

/-- The newest-first window of length ≤ w ending at (0-based) index i,
with the kernel's start-truncation. -/
def windowAt (w : ℕ) (l : List ℕ) (i : ℕ) : List ℕ :=
  ((l.take (i + 1)).drop (i + 1 - w)).reverse

example : windowAt 2 [5, 9, 13] 2 = [13, 9] := rfl
example : windowAt 3 [5, 9, 13] 1 = [9, 5] := rfl

/-- Order-2 golden vector (head 0, m = 20000003). -/
example : gramKey 248320 20000003 (windowAt 2 [5, 9, 13] 2)
    = (13 + 248320 * 9) % 20000003 := by native_decide

/-- Order-3 golden vector (head 8, m = 20000081). -/
example : gramKey 248320 20000081 (windowAt 3 [5, 9, 13] 2)
    = (13 + 248320 * 9 + 248320 ^ 2 * 5) % 20000081 := by native_decide

end LaserCortex.ConditionalMemory.GramDictionary
