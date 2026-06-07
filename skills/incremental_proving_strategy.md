# Incremental Proving Strategy for Lean 4

**Status**: Skill - Active  
**Date**: 2026-06-07  
**Author**: Mistral Vibe (synthesizing AlphaProof Nexus approach)  
**Pattern**: compile → error → fix → repeat  

---

## Executive Summary

This skill encodes the **incremental proving strategy** used by AlphaProof Nexus to formalize 500+ theorems. The core principle: **let the Lean compiler be your guide**.

**Key Insight**: Instead of writing complete proofs upfront, add one definition/lemma at a time, compile immediately, and let Lean's error messages tell you what's missing next.

---

## Core Workflow: compile → error → fix → repeat

```
┌─────────────────┐
│ Add ONE thing   │  (definition, lemma, or theorem statement)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Compile         │  (lake build or lean file.lean)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Read errors     │  (what's missing? what type mismatch?)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Fix ONE thing   │  (add missing lemma, fix type, import module)
└────────┬────────┘
         │
         └──────┐
                │
                ▼
         (repeat until no errors)
```

---

## Phase 1: Start Minimal

**Rule**: Begin with the smallest possible compiling foundation.

### Example: EMLRegistry

```lean
-- STEP 1: Just the core type (compile after this!)
inductive EMLTree : Type where
  | Leaf : EMLTree
  | Node : EMLTree → EMLTree → EMLTree
  deriving DecidableEq, Repr

-- ✅ COMPILE: Make sure this builds before continuing

-- STEP 2: Add one function (compile after this!)
def EMLTree.size : EMLTree → Nat
  | .Leaf       => 0
  | .Node l r   => 1 + l.size + r.size

-- ✅ COMPILE: Verify before continuing

-- STEP 3: Add one relation (compile after this!)
inductive contracts_one : EMLTree → EMLTree → Prop where
  | rotate : ∀ (a b c : EMLTree),
      contracts_one (.Node (.Node a b) c) (.Node a (.Node b c))

-- ✅ COMPILE: Verify before continuing
```

### Why This Works

1. **Early error detection**: Catch syntax/type errors immediately
2. **Small commits**: Each successful compile is a checkpoint
3. **Clear causality**: If compilation breaks, you know exactly what caused it
4. **Momentum**: Frequent small wins maintain progress

---

## Phase 2: Add Theorems Incrementally

**Rule**: Prove one theorem at a time, in dependency order.

### Example: contracts_to_rightComb

```lean
-- STEP 1: State the main theorem (don't prove yet)
theorem contracts_to_rightComb (t : EMLTree) :
    contracts_to t (rightComb t.size) := by
  sorry

-- ✅ COMPILE: Make sure the statement is well-typed

-- STEP 2: Try to prove it
theorem contracts_to_rightComb (t : EMLTree) :
    contracts_to t (rightComb t.size) := by
  induction t with
  | Leaf => exact .refl .Leaf
  | Node l r ihl ihr =>
    -- Now Lean will tell you what's missing

-- ❌ ERROR: Unknown identifier 'rightComb'
-- FIX: Add the definition

def rightComb : Nat → EMLTree
  | 0     => .Leaf
  | n + 1 => .Node .Leaf (rightComb n)

-- ✅ COMPILE: Verify

-- ❌ ERROR: Type mismatch at 'ihl'
--   Expected: contracts_one l (rightComb l.size)
--   Actual:   contracts_to l (rightComb l.size)
-- FIX: You need a lemma that lifts contracts_to through Node

-- STEP 3: Add the missing lemma
lemma contracts_to_node_left {l l' r : EMLTree} :
    contracts_to l l' → contracts_to (.Node l r) (.Node l' r) := by
  intro h
  induction h with
  | refl _ => exact .refl _
  | step s t u h ih => exact .step _ _ _ h ih

-- ✅ COMPILE: Verify

-- ❌ ERROR: Type mismatch at 'key'
--   Expected: contracts_to (Node (rightComb l.size) r) ...
--   Actual:   contracts_to (Node (rightComb l.size) (rightComb r.size)) ...
-- FIX: You need a composition lemma

-- STEP 4: Add the composition lemma
lemma node_of_rightCombs_contracts_to_rightComb (a b : Nat) :
    contracts_to (Node (rightComb a) (rightComb b)) (rightComb (1 + a + b)) := by
  sorry  -- Prove this separately

-- ✅ COMPILE: Now the main theorem can use this lemma
```

### Why This Works

1. **Error-driven development**: Each error tells you exactly what lemma/definition is missing
2. **Natural decomposition**: The proof structure reveals the necessary helper lemmas
3. **No wasted work**: You only prove what's actually needed
4. **Clear dependencies**: Lemma ordering emerges from compilation order

---

## Phase 3: Handle Dependencies

**Rule**: When you hit a missing dependency, add it immediately and recompile.

### Common Missing Dependencies

| Error | Fix | Priority |
|-------|-----|----------|
| `Unknown identifier 'X'` | Add definition/lemma for X | 🔴 Immediate |
| `Type mismatch: expected A, got B` | Add conversion lemma A ↔ B or fix usage | 🔴 Immediate |
| `Unknown module prefix 'Mathlib'` | Add import or postpone feature | 🟡 Can postpone |
| `Failed to synthesize instance` | Add instance or import module | 🟡 Can postpone |
| `Don't know how to synthesize` | Add explicit type annotation | 🟡 Can postpone |

### Decision Tree

```
Missing dependency?
    │
    ├─→ Is it core to the current proof?
    │   │
    │   ├─ Yes → Add it NOW (even if sorry'd)
    │   └─ No  → Mark as TODO, continue
    │
    ├─→ Does it require Mathlib?
    │   │
    │   ├─ Yes → Can you work around it?
    │   │   ├─ Yes → Use workaround
    │   │   └─ No  → Mark as TODO, get Mathlib working
    │   └─ No  → Add it
    │
    └─→ Is it a lemma from another file?
        │
        ├─ Yes → Import that file
        └─ No  → Define it inline
```

---

## Phase 4: Manage Sorries

**Rule**: Sorries are temporary placeholders, not permanent solutions.

### Sorry Hierarchy

```
Level 0: No sorries (goal)
    ↑
Level 1: Helper lemmas sorry'd, main theorem proved
    ↑
Level 2: Main theorem sorry'd, all helpers proved
    ↑
Level 3: Everything sorry'd but compiles (starting point)
```

### Sorry Elimination Strategy

1. **Start at Level 3**: Get everything to compile with sorries
2. **Move to Level 2**: Prove helper lemmas first (they're usually easier)
3. **Move to Level 1**: Use helper lemmas to prove main theorem
4. **Reach Level 0**: No sorries remaining

### Example Progression

```lean
-- LEVEL 3: Everything sorry'd (but compiles)
theorem contracts_to_rightComb (t : EMLTree) :
    contracts_to t (rightComb t.size) := by
  sorry

lemma node_of_rightCombs (a b : Nat) :
    contracts_to (Node (rightComb a) (rightComb b)) (rightComb (1 + a + b)) := by
  sorry

-- LEVEL 2: Helper lemma proved
lemma node_of_rightCombs (a b : Nat) :
    contracts_to (Node (rightComb a) (rightComb b)) (rightComb (1 + a + b)) := by
  induction a with
  | zero => simp [rightComb]; exact .refl _
  | succ a ih =>
    -- ... full proof ...

-- LEVEL 1: Main theorem uses proved helper
theorem contracts_to_rightComb (t : EMLTree) :
    contracts_to t (rightComb t.size) := by
  induction t with
  | Leaf => exact .refl .Leaf
  | Node l r ihl ihr =>
    have key := node_of_rightCombs l.size r.size  -- ✓ Uses proved lemma
    -- ... rest of proof ...

-- LEVEL 0: Complete!
```

---

## Phase 5: Learn from Errors

**Rule**: Every error message is a teaching moment.

### Common Error Patterns

#### 1. Type Mismatch in Proof
```
error: Application type mismatch: The argument
  h
has type
  contracts_to l (rightComb l.size)
but is expected to have type
  contracts_one l (rightComb l.size)
```

**Interpretation**: You're using a `contracts_to` (multi-step) where `contracts_one` (single-step) is expected.

**Fix**: Either:
- Change the proof to use `contracts_one`
- Add a lemma that lifts `contracts_to` through the constructor

#### 2. Unknown Identifier
```
error: Unknown identifier 'Node'
```

**Interpretation**: You're using a constructor without the type prefix.

**Fix**: Use `EMLTree.Node` or open the namespace.

#### 3. Failed to Synthesize Instance
```
error: Failed to synthesize implicit argument 'n'
```

**Interpretation**: Lean can't infer a parameter from context.

**Fix**: Make the parameter explicit or restructure the definition.

#### 4. Unexpected Token
```
error: unexpected token '<'; expected term
```

**Interpretation**: Syntax error, often in structure construction.

**Fix**: Check structure field syntax (use `{ field := value }` not `⟨value⟩` for named fields).

---

## Phase 6: Checkpoint Frequently

**Rule**: Every successful compile is a checkpoint.

### Checkpoint Triggers

- ✅ File compiles with no errors
- ✅ A theorem is fully proved (no sorry)
- ✅ A major milestone is reached (all core definitions, all helpers proved, etc.)

### Checkpoint Actions

1. **Git commit**: `git add file.lean && git commit -m "Description"`
2. **Document progress**: Update a PROGRESS.md or similar
3. **Backup**: Copy working version to safe location if needed

### Example Commit Messages

```
"Add minimal compiling EMLRegistry with core types"
"Prove node_of_rightCombs_contracts_to_rightComb lemma"
"Complete contracts_to_rightComb theorem proof"
"Add decidability instance for contracts_to"
"Add CortexCertificate structure and certify function"
```

---

## Tools

### Compilation Commands

```bash
# Build single file
lake build LaserCortex.EMLRegistry

# Build entire project
lake build

# Check single file (faster)
lake env lean LaserCortex/EMLRegistry.lean

# Clean and rebuild
rm -rf .lake/build && lake build
```

### Error Inspection

```bash
# Get detailed error messages
lake build 2>&1 | grep -A 5 "error:"

# See full compiler output
lake build --verbose
```

### Progress Tracking

```bash
# Count sorries
grep -r "sorry" LaserCortex/*.lean | wc -l

# List all sorries
grep -n "sorry" LaserCortex/*.lean
```

---

## Heuristics from AlphaProof Nexus

### 1. Start with Concrete Examples
Before proving general theorems, define specific examples:
```lean
def exampleRegistry : TypeRegistry 2 where
  toTree := fun i => if i.val = 0 then .Leaf else .Node .Leaf .Leaf
```

### 2. Use Automation When Possible
Try tactics in order: `rfl` → `simp` → `decide` → `omega` → manual proof

### 3. Break Complex Proofs into Lemmas
If a proof is > 50 lines, you're probably missing a helper lemma.

### 4. Name Lemmas Descriptively
`node_of_rightCombs_contracts_to_rightComb` is better than `lemma1`.

### 5. Document as You Go
Add docstrings (`/-- ... -/`) to every definition and theorem.

---

## Anti-Patterns to Avoid

### ❌ Don't Write Everything at Once
```lean
-- BAD: 500 lines, then try to compile
-- (You'll get 50 errors and won't know where to start)
```

### ❌ Don't Ignore Errors
```lean
-- BAD: Add sorry to make it compile, move on
theorem foo : bar := by sorry  -- Never come back to this
```

### ❌ Don't Change Multiple Things Between Compiles
```lean
-- BAD: Add 5 definitions, 3 lemmas, 2 theorems, then compile
-- (When it breaks, what caused it?)
```

### ❌ Don't Postpone Mathlib Imports Indefinitely
```lean
-- BAD: Keep using sorry for Finset operations
-- FIX: Get Mathlib working or implement your own version
```

---

## Summary Checklist

Before moving to the next feature:

- [ ] Current code compiles with no errors
- [ ] All sorries are documented with TODOs
- [ ] Git checkpoint is created
- [ ] Next dependency is identified
- [ ] Error messages are understood (not just suppressed)

---

## References

- [AlphaProof Nexus Procedure](alphaproof_nexus_procedure.md) - Broader formalization workflow
- [Lean 4 Skill](../.agents/skills/lean4/SKILL.md) - Lean-specific tooling and commands
- [Mathlib Style Guide](https://leanprover-community.github.io/style.html) - Conventions for Lean proofs

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-07 | Mistral Vibe | Initial creation from EMLRegistry bootstrap experience |

**Status**: Active - Used for EMLRegistry.lean development  
**Next Review**: After completing contracts_to_rightComb proof  

*End of skill*
