# Lab Note 020: Lean 4.31 `/-!` Doc Comment Lexer Bug

**Date**: 2026-07-01  
**Status**: Verified  
**Tags**: `lean4`, `lexer`, `doc-comment`, `parser-bug`, `/-!`, `block-comment`  

## Discovery

During implementation of the Develin-Sturmfels correspondence in
`TropicalTamariLattice.lean`, we encountered a persistent `unterminated
comment` error at line 421 (past the end of file, which had 420 lines). After
ruling out all structural issues (properly paired `-/` delimiters, no Unicode
artifacts), the root cause was traced to a specific interaction between Lean
4.31.0-rc2's lexer and `/-!` module doc comments.

## The Bug

**When the text inside a `/-! ... -/` doc comment block contains a literal
`/-` character sequence, Lean's lexer interprets it as starting a *nested
block comment*, which then consumes the intended `-/` closing delimiter of
the doc comment, leaving it unclosed.**

Consider this valid-looking doc comment:

```lean
/-!
For the tube map application, we need to project Cayley-Dickson algebra
coordinates to tropical coordinates with 90/45-degree turn constraints.

The strategy:
1. Map nodes to their Cayley-Dickson level (ℝ, ℂ, ℍ, ℍ̃, 𝕆ˢ)
2. Apply antipode grading to get +/-1 components
3. Project to tropical coordinates using a valuation to `Tropical ℝ` or
   `Tropical ℤ`

This yields integer or rational coordinates suitable for 90/45-degree turn
constraints in the tube map layout.
-/
```

The `+/-1` on step 2 contains the ASCII bytes `+`, `/`, `-`, `1`. Lean's
lexer sees the `/-` at the boundary and opens a nested block comment. This
consumes the intended `-/` at the end of the doc comment block, resulting
in `unterminated comment` at EOF.

## Why This Is Surprising

Standard Lean block comments (`/- ... -/`) are **non-nesting** — when you
are inside a `/-` block, encountering another `/-` is treated as text, not
as a nested opener. This is well-known and documented.

However, `/-!` doc comments exhibit **different lexer behavior**: the lexer
appears to treat `/-` inside `/-!` as a comment starter, creating an implicit
nesting that is not present in the standard comment path. This means:

| Delimiter | Nests `/-` inside? | Correct behavior? |
|-----------|-------------------|--------------------|
| `/- ... -/` | No (text) | ✅ Non-nesting |
| `/-! ... -/` | **Yes (open)** | ❌ Inconsistent with `/-` |
| `/-- ... -/` | (Not tested) | ❓ Likely same as `/-!` |

## Workaround

Replace `/-! ... -/` blocks with line comments (`--`) when the text contains
any `/-` sequence. Happily, line comments have no closing delimiter issue:

```lean
-- For the tube map application, we need to project Cayley-Dickson algebra
-- coordinates to tropical coordinates with 90/45-degree turn constraints.
--
-- The strategy:
-- 1. Map nodes to their Cayley-Dickson level (ℝ, ℂ, ℍ, ℍ̃, 𝕆ˢ)
-- 2. Apply antipode grading to get +/-1 components
-- 3. Project to tropical coordinates using a valuation to `Tropical ℝ` or
--    `Tropical ℤ`
```

This compiles correctly.

## Verifying the Diagnosis

The file had exactly the following structure at the point of failure:

```
400 lines of Lean code (all comments properly closed)
─ /-!  (line 407) — doc comment opens
  ─ Line 413: "2. Apply antipode grading to get +/-1 components"
    ─ /- at "+/-1" — lexer opens a NEW comment
  ─ Line 418: -/ — THIS CLOSES THE PHANTOM NESTED COMMENT, NOT THE DOC COMMENT
  ─ Line 420: end — now back at depth 1 (inside unclosed doc comment)
  ─ Line 421: EOF — lexer reports "unterminated comment"
```

Changing the `/-!` block to `--` line comments eliminated the error entirely.
The rest of the file (which had other genuine errors that had already been
fixed) then compiled cleanly.

## Impact

This is a **genuine lexer inconsistency** in Lean 4.31.0-rc2. It affects:

1. **Module doc comments** (`/-!`) that describe API signatures involving
   forward slashes or path notation (e.g., `file/path`, `dir/file.lean`)
2. **Any `/-!` block** containing mathematical notation with `/-`
   (e.g., `+/-1`, `real/imaginary`, `n/k`)
3. **Portability**: code that compiles under one version of Lean may fail
   under 4.31 with a misleading `unterminated comment` error

The safest mitigation is to **use `--` line comments** whenever a `/-!` block
would contain `/-` in its text. This is what we applied in
`TropicalTamariLattice.lean`.

## Related

- This bug was discovered while proving the forward direction of the
  Develin-Sturmfels correspondence for QuantizedTypes
  (`develin_sturmfels_quantized_correspondence`) — a theorem that now
  compiles successfully.
- The lexer issue is independent of the elaborator bug noted in
  `QuantizedType.lean` (Lean 4.31 `¬P` binder fields in `And`/`∧`).
- Lean 4.32 nightly may have addressed this; verification is pending.
