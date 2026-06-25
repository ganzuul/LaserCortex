# Plan: Hyperstitional Institutional Closure → AMM Bridge

## 1. Architecture (post-formalization)

```
                                                  NormCode .ncd plan
                                                         │
                                                         ▼
                      InstitutionalClosure              MarketClosure
                     (abstract closure pipeline) ──► (concrete AMM application)
                              │                              │
              ┌───────────────┼──────────────┐      ┌────────┴────────┐
              ▼               ▼              ▼      ▼                 ▼
          Sorites         Edict/IC       AMM Kernel   certified
          (no norm,       (arbitrary      (Generation.reduce ∘ AMM.map)  CertifiedPrice
           open market)    norm, paradox)              closed market    (CortexCertificate
                                                                          + price + costDeduction)

Generation.lean = WFC (formal wavefunction collapse):
  inflate  : ProblemClass → AntiCoherentPair
  temporalConflate : AntiCoherentPair → EMLTree
  revise   : AntiCoherentPair → Superposition    (zero-divisor = paradox closure)

AMM.lean (with EMLTree-crossImpact generalization):
  swapOut : Pool → Nat → Nat                    (fair price formula)
  crossImpact : LogicType → EMLTree → EMLTree → Nat   (generalized from Route)
  associatorCost : LogicType → EMLTree → EMLTree → EMLTree → Nat (generalized)

SplitOctonionCost.lean (super-logic, agnostic to named logics):
  NonAssociativeBudget { local_residue, max_capacity }
  engine_to_nodecost : EngineState → NodeCost
  branch_lightening (debt monotonically reduces weight)

FrictionLagrangian.lean:
  Φ : LogicType → EMLTree → Nat   (the cost function used by AMM)
  frictionDensity, layerCost

EMLRegistry.lean (already has):
  CortexCertificate { source, target, proof: contracts_to source target }
  certify : EMLTree → CortexCertificate
```

## 2. Three norm variants (the capability ladder)

| Norm | What it requests | Closure outcome | Consequence variable |
|------|-----------------|------------------|---------------------|
| `.none` (Sorites) | undefined — raw need for intelligence | `openMarket` | None (heap doesn't protest) |
| `.arbitrary` (Edict) | any threshold by decree | `paradoxMarket` | Black markets emerge (but no FL bridge) |
| `.fairPrice` (AMM kernel) | certified fair price + cost deduction | `closedMarket` (if FL<reserve), `paradoxMarket` (if ZD), or halting (postponed) | `crossImpact` measured by FL |

Future norms (TODO): "request fair price" is the first of potentially many kernel norms — each backed by a verified kernel that gives certified answers to specific request types.

## 3. File-by-file formalization plan

### 3a. `LaserCortex/AMM.lean` — generalize crossImpact to EMLTree

**Imports added**: `LaserCortex.Generation`, `LaserCortex.FrictionLagrangian`

**Comment out (preserved wisdom)**: existing `crossImpact (L : LogicType) (r1 r2 : Route) : Nat` and `associatorCost (L : LogicType) (r1 r2 r3 : Route) : Nat`. Wrap in `/- ... -/` block with header comment: *"Generalized to EMLTree below — these Route-typed versions are preserved here for design wisdom until the assimilation is verified. Once EMLTree version is fully tested, these can be removed."*

**New generalized definitions** (added in same file):
```lean
/-- Generalized cross-impact: the cost difference between composing two trees
    vs treating them independently. Replaces the Route-specific version above,
    which is preserved for design reference.

    EMLTree is the natural habitat because Generation.temporalConflate produces
    EMLTrees directly; Route was an intermediate form that lost information. -/
def crossImpactTree (L : LogicTypes.LogicType) (t1 t2 : EMLTree) : Nat :=
  Φ L (.Node t1 t2) - (Φ L t1 + Φ L t2)

/-- Generalized associator cost: the cost difference between the two bracketings
    of a triple composition. The discrete analogue of the pentagon defect norm. -/
def associatorCostTree (L : LogicTypes.LogicType)
    (t1 t2 t3 : EMLTree) : Nat :=
  absDiff (Φ L (.Node (.Node t1 t2) t3))
          (Φ L (.Node t1 (.Node t2 t3)))
```

**New**: `certifiedClose` definition skeleton (the AMM-side of the bridge):
```lean
/-- The reserve-vs-FL guard. Returns true if attempting to compute the fair
    price would annihilate the reserve (ZD detected) or hit the halting case
    (FL = reserve exactly). Callers should check this before calling swapOut.

    TODO (amortization): in a realistic system this guard would consult a
    cached library of precomputed costs rather than calling Φ directly. -/
def reserveGuard (pool : Pool) (L : LogicType) (tree : EMLTree) (dx : Nat) :
    Bool := ...
/-- The certified close step: AMM computes fair price; FL provides cost;
    EMLRegistry.certify produces a proof-carrying certificate.

    Precondition (caller responsibility): not reserveGuard (FL ≥ reserve).
    The pool reserves are externally supplied; this function does not derive
    them from ProblemClass or BlamePool. (TODO: cached amortization of the
    guard would avoid recomputing Φ on identical trees.) -/
def certifiedClose (pool : Pool) (L : LogicType) (tree : EMLTree) (dx : Nat)
    : CertifiedPrice := ...
```

### 3b. `LaserCortex/MarketClosure.lean` — NEW FILE

Imports: `EMLRegistry`, `LogicTypes`, `InstitutionalClosure`, `AMM`, `Generation`, `FrictionLagrangian`, `EMLRegistry` (for `CortexCertificate`)

**MarketType** (three cases, halting postponed):
```lean
inductive MarketType where
  | openMarket    -- no norm: Sorites-style, FL hits cost wall immediately
  | paradoxMarket -- arbitrary norm or ZD caught: decree produces black markets
  | closedMarket  -- fairPrice norm satisfied: certified price + deduction emitted
```

**KernelChoice** (tag only, reserve flows in externally per Q-B):
```lean
/-- The kernel norm tells IC what kind of intelligence is being certified.

    This is the (a) tag-only design. The (b) tag-plus-carrier design
    (embedding pool/request/ProblemClass in the inductive) is the natural
    extension and is tracked as a TODO.

    TODO (scaffold for (b)): KernelChoice.arbitrary could carry
    `decree : String → Nat` (the arbitrary threshold function);
    KernelChoice.fairPrice could carry `pool : AMM.Pool` and
    `request : Nat`. See AMM.lean and Generation.lean for the
    relevant types. -/
inductive KernelChoice where
  | none        -- no kernel selected (Sorites default)
  | arbitrary   -- arbitrary threshold by decree (Edict default)
  | fairPrice   -- AMM kernel: Generation.reduce ∘ AMM.map
```

**Decide market type**:
```lean
/-- The institutional closure decides the market type by applying the kernel.

    KernelChoice.none → openMarket (Sorites: FL hits wall, no closure)
    KernelChoice.arbitrary → paradoxMarket (Edict: decree produces paradox)
    KernelChoice.fairPrice →
      if AMM.reserveGuard (FL ≥ reserve) → paradoxMarket (ZD caught)
      else → closedMarket (certified price emitted)

    The halting case (FL = reserve exactly) is postponed; it's currently
    lumped into paradoxMarket pending further thought, but should become
    its own case once we understand the smart-contract-equilibrium
    semantics better.

    The pool reserve is externally supplied (Q5) per the user's call.
    Cache lookup for the reserve guard is a TODO (realistic systems would
    have vast libraries of precomputed Φ costs; we start with no cache). -/
def decideMarketType (kernel : KernelChoice) (pool : AMM.Pool)
    (L : LogicType) (tree : EMLTree) (dx : Nat) : MarketType := ...
```

**CertifiedPrice** (Q-D (b) — the monoid-wrap structure):
```lean
/-- The certified close receipt: wraps CortexCertificate with the AMM
    pricing fields, in the style of composable monoid carriers from
    functional programming.

    This is design (b): a separate structure that composes with
    CortexCertificate rather than extending it. CortexCertificate
    stays generic; CertifiedPrice layers AMM-specific fields on top. -/
structure CertifiedPrice where
  cert           : CortexCertificate    -- the quench witness (proof-carrying)
  price          : Nat                  -- fair price (swapOut output)
  costDeduction  : Nat                  -- FL cost deducted (= Φ L tree)
  residue        : Nat                  -- price - costDeduction (net value)
  h_nonnegative  : residue ≥ 0          -- closure condition: net value non-negative
```

**Bridge from BlamePool / NonAssociativeBudget** (kept minimal here):
```lean
/-- Maps an IC BlamePool to a SplitOctonionCost NonAssociativeBudget.
    This is the minimal version: total defects become local residue;
    a fixed max_capacity (= 10, matching the SO pentagon bound) is used.

    TODO: realistic versions would derive max_capacity from the
    specific norm in use rather than hardcoding 10. -/
def blameToBudget (blame : BlamePool) : NonAssociativeBudget := ...
```

**Tying it together**:
```lean
/-- The complete market closure: takes a KernelChoice and externally-supplied
    pool, runs the closure pipeline, decides the market type, and (if closed)
    emits a CertifiedPrice.

    This is the formal target of the .ncd plan — the NormCode plan dispatches
    inference through this Lean specification. -/
def marketClosure (kernel : KernelChoice) (pool : AMM.Pool)
    (L : LogicType) (tree : EMLTree) (dx : Nat)
    (blame : BlamePool) (norm : Norm)
    : MarketType × Option CertifiedPrice := ...
```

### 3c. `LaserCortex/InstitutionalClosure.lean` — minor edits

Imports added: `LaserCortex.SplitOctonionCost` (for `NonAssociativeBudget`), `LaserCortex.Cost` (for `Φ`).

**New field on Norm** (minimal addition, doesn't break existing theorems):
```lean
/-- The kernel norm: which pre-computed intelligent kernel is appropriate
    for the kind of intelligence being certified. Defaults to .none (Sorites).

    The ClosureLevel auditor (V1→V2→V3) is a separate kind of closure
    applied to IC, not a fourth kernel case — see MarketClosure.lean. -/
structure Norm where
  rule      : String
  threshold : Nat
  kernel    : KernelChoice := .none   -- defaults to Sorites (no kernel)
```
(This requires `import LaserCortex.MarketClosure` — creates a slight circular concern. **Resolved by:** moving `KernelChoice` to a small shared file `LaserCortex/KernelChoice.lean` that both IC and MarketClosure import, since IC shouldn't pull AMM into its import graph. New file size: ~30 lines.)

**`fuzzyGrade` could (TODO) use `engine_to_nodecost`** — but per Q5 "start with purely external and no cache", we leave the existing hardcoded grading logic and add a comment:
```lean
/- TODO: in the (b) development of KernelChoice, fuzzyGrade could delegate
   to SplitOctonionCost.engine_to_nodecost rather than hardcoding the
   D→impact mapping. The current hardcoded version is the (a) minimal
   scaffold; the (b) version would unify BlamePool and NonAssociativeBudget. -/
```

### 3d. `LaserCortex/KernelChoice.lean` — NEW FILE (small, breaks IC↔MarketClosure cycle)

Imports: `Init` only (avoids pulling AMM/Generation into IC)

Contents: the `inductive KernelChoice` declaration with the same comment as above. Both `InstitutionalClosure.lean` and `MarketClosure.lean` import this file. (~30 LOC)

### 3e. `LaserCortex.lean` (root) — register new module

Add: `import LaserCortex.KernelChoice`, `import LaserCortex.MarketClosure`. May need `lean-lsp_lean_build` after to refresh LSP cache.

### 3f. `LaserCortex/AMM.lean` — minor: deprecate-not-delete old crossImpact

Per Q-C, wrap the existing `Route`-typed `crossImpact` and `associatorCost` in a `/- ... -/` comment block (NOT deleted, NOT deprecated-warning, NOT instance-layer). Header comment block:
```lean
/-! ### Route-typed cross-impact (preserved for design wisdom)

    These Route-typed versions are commented out, NOT deleted. They carry
    design information about AMM's concept of binary-tree swap routes that
    should be assimilated before removal. Once the EMLTree generalizations
    below are fully verified, we can remove these or document their design
    wisdom in a separate doc.

    Kept as comments per project decision (Q-C): avoid duplicated
    functionality but preserve the wisdom until assimilation is verified.
-/

/-- [Original crossImpact definition, commented out] -/
-- def crossImpact (L : LogicTypes.LogicType) (r1 r2 : Route) : Nat := ...

-- [Original associatorCost definition, commented out]
-- def associatorCost (L : LogicTypes.LogicType) (r1 r2 r3 : Route) : Nat := ...

/- The EMLTree generalizations below replace these. -/

def crossImpactTree (L : LogicTypes.LogicType) (t1 t2 : EMLTree) : Nat := ...

def associatorCostTree (L : LogicTypes.LogicType) (t1 t2 t3 : EMLTree) : Nat := ...
```

## 4. NormCode .ncd plan

Following Q-E ("start with minimal, then expand to (b) if implementation doesn't go perfectly smooth"), the .ncd plan is built in two phases:

### 4a. Minimal .ncd (covers AMM-Sorites-Edict triple only)

**File**: `LaserCortex/examples/market_closure/market_closure.ncd` (new directory)

**Concepts**:
```
/: Market Closure — the dual-capability Fuzzy→Nat plan

/: Phase 1: minimal version (Sorites + Edict + AMM triple)
/: Phase 2: expand to include auditor (V1→V2→V3) as a fourth path
/:          see TODO at bottom of file

concept market_events, degree, blame, fair_price, threshold, closure_cost

relation fuzzy_grade : market_events -> degree         /: Fuzzy→Nat (dual capability)
relation classifies_vagueness : degree -> outcome     /: Sorites path (no blame)
relation classifies_blame : degree -> blame           /: Edict path (with blame)
relation deontic_update : blame × threshold -> threshold  /: revise threshold
relation compute_price : market_events -> fair_price  /: AMM short-circuit
relation measure_cost : fair_price -> closure_cost   /: FL deduction
relation self_recognize : norm -> norm                /: fixed point check
```

**Paths** (three inferences):

```
/: Sorites path (open-loop, no closure)
path: sorites_classification(market_events) -> outcome
    <- degree
    <= fuzzy_grade(market_events)
    <= no consequence variable (Sorites has no blame feedback)

/: Edict path (closed-loop would require mutual information;
    arbitrary norm produces paradox)
path: edict_closure(market_events, initial_threshold) -> norm
    <= temporal_normalize(market_events)
    <= fuzzy_grade(market_events)
    <- blame
    <= deontic_update(blame, initial_threshold)
    <= self_recognize(norm)
    :closure:

/: AMM kernel path (closed-loop with consequence = crossImpact)
path: amm_close(market_events, pool) -> certified_price
    <= generate_tree(market_events)  /: Generation.temporalConflate
    <- fair_price
    <= compute_price(pool)            /: AMM.swapOut
    <= measure_cost(generated_tree)  /: FrictionLagrangian.Φ
    <- closure_cost
    <= reserve_guard(fair_price, closure_cost)   /: ZD check
    <= certify(generated_tree, fair_price)        /: EMLRegistry.certify
    :closure:
```

**Coupling**: commutative-associative (rightComb canonical form for closure) for AMM path; commutative for Sorites path (no ordering); non-commutative for Edict path (time matters).

### 4b. Expanded .ncd (add auditor as fourth path) — TODO at bottom of file

```
/: ==========================================================================
/: TODO Phase 2 — expand to (b): include the meta-reasoning auditor
/: (V1→V2→V3) as a fourth path running the same closure pipeline on
/: architectural findings.

/: The LLM that NormCode relies on acts as the sensor from the continuous
/: domain (architectural quality) to the discrete domain (V1 findings).
/: The auditor's "domain-norm prompt" is its kernel — analogous to AMM
/: being the kernel for fair-price requests.

/: New concepts and a fourth path would be added here, running the
/: same temporalNormalize → fuzzyGrade → deonticUpdate → selfRecognize
/: pipeline but on V1 findings instead of market events. The fuzzyGrade
/: would use confidence × severity; the deonticUpdate would tighten
/: domain-norm thresholds when patterns accumulate.

/: See scripts/meta_reason/run.py for the current runtime implementation
/: and .open-notebook/prompts/0{1,2,3}_*.md for the domain-norm kernel.
/: ==========================================================================
```

## 5. Verification & build plan

After formalization:

1. **Build check**: `lean-lsp_lean_build` (clean=false, fetch_cache=false) — verify all modules compile
2. **LSP check**: `lean-lsp_lean_diagnostic_messages` on new files — verify no errors
3. **Parse check**: `normcode_parse_file` on the new `.ncd` — verify plan parses
4. **Lift check**: `normcode_lift_inference` on one inference (e.g., the AMM path) — verify the cortex bridge accepts it
5. **End-to-end smoke**: `normcode_orch_load_plan` then `orch_get_state` — verify the plan loads without runtime error

## 6. Open questions / intentional deferrals

- **Halting case (Q3)**: FL = reserve exactly is its own MarketType case. Postponed — currently lumped into `paradoxMarket`. Revisit when we understand the smart-contract-equilibrium semantics.
- **KernelChoice (b)**: tag-plus-carrier design where `KernelChoice.arbitrary` carries the decree function and `KernelChoice.fairPrice` carries the pool/request. Tracked as TODO in the inductive declaration.
- **BlamePool ↔ NonAssociativeBudget unification**: `fuzzyGrade` could delegate to `engine_to_nodecost` in the (b) design. Currently hardcoded in IC. Tracked as TODO in IC.
- **Cache for reserveGuard**: realistic systems precompute Φ costs; we start with no cache. Tracked as TODO in AMM.certifiedClose.
- **Auditor as fourth path**: Phase 2 of .ncd (TODO at file bottom). The LLM-as-sensor framing is in the comments but not implemented in the plan structure.

## 7. Order of execution

When implementation begins (in a fresh session, given context budget here):

1. Create `LaserCortex/KernelChoice.lean` (~30 LOC)
2. Add `kernel : KernelChoice := .none` field to `InstitutionalClosure.Norm`; add `import LaserCortex.KernelChoice`
3. Comment-out existing `crossImpact`/`associatorCost` in `AMM.lean`; add EMLTree-typed versions; add `import LaserCortex.Generation`, `import LaserCortex.FrictionLagrangian`
4. Create `LaserCortex/MarketClosure.lean` (MarketType, CertifiedPrice, decideMarketType, marketClosure, blameToBudget — roughly ~150 LOC total)
5. Update `LaserCortex.lean` root to import new modules
6. Run `lean-lsp_lean_build` to verify
7. Create the `.ncd` plan at `LaserCortex/examples/market_closure/market_closure.ncd`
8. Verify with `normcode_parse_file` and `normcode_lift_inference`
9. (Phase 2) Expand `.ncd` with auditor path if (1)-(8) went smoothly
