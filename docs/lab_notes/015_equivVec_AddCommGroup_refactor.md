# 015: equivVec AddCommGroup Refactor — Transporting Structure via `SplitOctonion ≃ ℤ⁸`

**Date**: 2026-06-28  
**Status**: Planned (not yet implemented)  
**Deprecates**: The `simp`/`dsimp` + `omega` approach in `Hopf.lean:AddCommGroup`

## Problem

`SplitOctonion` is an 8-field structure, but `+`/`0`/`-` notation goes through
`HAdd.hAdd`/`instAdd`/`HNeg.hNeg` wrappers that `dsimp`/`simp` **cannot unfold**
back to the underlying `split_add`/`split_zero`/`split_neg`. This forces every
`AddCommGroup` axiom proof to fight definitional opacity:

- `dsimp [split_add]` makes no progress on `(a + b + c).e0 = (a + (b + c)).e0`
  because `a + b` is syntactically `HAdd.hAdd a b`, not `split_add a b`.
- `omega` can't close the goal because it hasn't been reduced to ℤ arithmetic.
- Each field needs 8 `ext_components` subgoals × `omega` calls = fragile boilerplate.

The same opacity afflicts `-` and `0` notation.

## Solution: Transport via ℤ⁸ Isomorphism

Mathematically, `SplitOctonion ≃ ℤ⁸` as ℤ-modules. Lean can transport the
`AddCommGroup` structure across this isomorphism, giving us every axiom for
free from `Pi.instAddCommGroup (Fin 8 → ℤ)`.

### Infrastructure (`SplitOctonionCost.lean`)

Add ~20 lines:

```lean4
def toVec (x : SplitOctonion) : Fin 8 → ℤ := λ
  | 0 => x.e0 | 1 => x.e1 | 2 => x.e2 | 3 => x.e3
  | 4 => x.e4 | 5 => x.e5 | 6 => x.e6 | 7 => x.e7

def ofVec (v : Fin 8 → ℤ) : SplitOctonion :=
  { e0 := v 0, e1 := v 1, e2 := v 2, e3 := v 3,
    e4 := v 4, e5 := v 5, e6 := v 6, e7 := v 7 }

@[simp] theorem toVec_ofVec (v : Fin 8 → ℤ) : toVec (ofVec v) = v := by
  ext i; fin_cases i <;> rfl

@[simp] theorem ofVec_toVec (x : SplitOctonion) : ofVec (toVec x) = x := by
  cases x; rfl

def equivVec : SplitOctonion ≃ (Fin 8 → ℤ) :=
  { toFun := toVec, invFun := ofVec, left_inv := ofVec_toVec, right_inv := toVec_ofVec }
```

Then update `SplitOctonion.ext_components` proof to use `equivVec.injective`
(removes `omega` from its proof entirely).

### `AddCommGroup` Instance (`Hopf.lean`)

Replace the current 23-line `omega` block (~50% which errors) with:

```lean4
instance : AddCommGroup SplitOctonion :=
  { zero := ofVec 0
    add := λ x y => ofVec (toVec x + toVec y)
    neg := λ x => ofVec (-toVec x)
    add_assoc := by intro x y z; apply equivVec.injective; simp [add_assoc]
    zero_add := by intro x; apply equivVec.injective; simp
    add_zero := by intro x; apply equivVec.injective; simp
    add_comm := by intro x y; apply equivVec.injective; simp
    neg_add_cancel := by intro x; apply equivVec.injective; simp
    nsmul := nsmulRec; nsmul_zero := λ x => by apply equivVec.injective; simp
    nsmul_succ := λ n x => by apply equivVec.injective; simp
    zsmul := zsmulRec; zsmul_zero' := λ x => by apply equivVec.injective; simp
    zsmul_succ' := λ n x => by apply equivVec.injective; simp
    zsmul_neg' := λ n x => by apply equivVec.injective; simp
    sub_eq_add_neg := λ x y => by apply equivVec.injective; simp
  }

instance : DecidableEq SplitOctonion := equivVec.decidableEq
```

Every axiom is a one-liner `apply equivVec.injective; simp` — the `simp`
delegates to `Pi.instAddCommGroup`'s existing proofs on `Fin 8 → ℤ`.
**No `omega` anywhere.**

### Backward Compatibility

- `split_add`, `split_zero`, `split_neg` remain as standalone `def`s (they're
  used in `split_oct_mul`'s 64-term formula, `antipode`, `counit`, etc.)
- `SplitOctonion.ext_components` keeps its original signature — all 14 existing
  calls still work, just the proof changes to `equivVec.injective`
- All theorem statements unchanged

## Why Not Other Approaches

| Approach | Problem |
|---|---|
| `simp [split_add]` | Can't unfold `HAdd.hAdd` |
| `dsimp [split_add]` | Same — definitional opacity of `+` |
| `calc` with `rfl`-lemmas | Works but verbose across 8 components |
| `omega` | Fragile, `simp` must fully reduce first |
| `ext <;> native_decide` | Rejects free ℤ variables |
| Product type `ℤ × ... × ℤ` | Unwieldy at 8-deep nesting |
| `Pi` type `Fin 8 → ℤ` | Loses `.e0`/`.e1` accessor ergonomics |

The `equivVec` transport combines the **ergonomics** of the 8-field structure
with the **algebraic automation** of `Pi.instAddCommGroup`.

## Implementation Order

1. Add `toVec`/`ofVec`/`equivVec` to `SplitOctonionCost.lean` (~20 lines)
2. Update `SplitOctonion.ext_components` proof via `equivVec.injective`
3. Replace `AddCommGroup` instance in `Hopf.lean` (~30 lines changed)
4. Remove now-redundant `Neg`/`Add`/`Zero` wrappers, `DecidableEq` instance
5. Verify all theorems still compile via `lake build`
6. Clean up `omega` imports if no longer needed

## Risk Assessment

- **Low**: `toVec`/`ofVec` add only ~20 lines, all existing APIs unchanged
- **Medium**: `AddCommGroup` rewrite touches 30 lines in `Hopf.lean`;
  regressions caught by `lake build`
- **Low**: No changes to `split_oct_mul`, `antipode`, `counit`, or theorem
  statements — they compute on the same field accessors as before
- **Bonus**: `decidableEq` becomes automatic via `equivVec.decidableEq`,
  removing 10 lines of manual `DecidableEq` proof
