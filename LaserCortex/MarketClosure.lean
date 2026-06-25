/-
# Module: MarketClosure

## Intent

Implements the hyperstitional market closure bridge: connects the institutional
closure pipeline (InstitutionalClosure.lean) with the AMM fair-price kernel
(AMM.lean) and the friction cost algebra (SplitOctonionCost.lean) to decide
which type of market a given norm+events+pool instantiates.

**The hyperstitional arc**: Diocletian's Edict on Maximum Prices (301 AD)
→ 1700 years of institutional closure → AMM's fair price today. IC's closure
pipeline IS the AMM's price discovery mechanism, run over historical time.
AMM is the closed-form limit.

**Three norm variants** (the capability ladder):
  - `.none` (Sorites): raw unmediated need for intelligence. FL hits cost
    wall immediately → open market, no closure.
  - `.arbitrary` (Edict): decree any threshold by fiat → black markets
    emerge → paradox market output.
  - `.fairPrice` (AMM kernel): Generation.reduce ∘ AMM.map. If FL < reserveB
    → closed market (certified price + cost deduction). If FL ≥ reserveB →
    paradox market (reserve saved from annihilation by the guard).

**Zero-divisor catch**: `Generation.revise` produces empty Superposition
(both poles vacuous) → classifies as paradox market. The reserve is saved
from being annihilated in a worthless transaction.

## Contracts

MarketType, CertifiedPrice, decideMarketType, marketClosure, blameToBudget

## Cross-refs

LaserCortex.EMLRegistry → CortexCertificate, certify; LaserCortex.AMM → Pool,
CloseResult, certifiedClose, reserveGuard; LaserCortex.InstitutionalClosure →
BlamePool, Norm, closure; LaserCortex.SplitOctonionCost →
NonAssociativeBudget; LaserCortex.KernelChoice → KernelChoice

## Tags

#lean4-type #market-closure #hyperstition #proof-bound
-/

import LaserCortex.EMLRegistry
import LaserCortex.LogicTypes
import LaserCortex.LogicMonad
import LaserCortex.InstitutionalClosure
import LaserCortex.AMM
import LaserCortex.SplitOctonionCost
import LaserCortex.KernelChoice

-- NOTE: LogicType is defined in BOTH EMLRegistry and LogicTypes (different types).
-- We open LogicTypes (uppercase constructors: Classical, Fuzzy, ...) and use
-- fully qualified names for EMLRegistry types (EMLRegistry.EMLTree, etc.).
open LogicTypes
open LogicMonad
open InstitutionalClosure
open AMM
open SplitOctonionCost

namespace MarketClosure

-- ============================================================================
-- Section 1: MarketType — the three possible outcomes of closure
-- ============================================================================

/-- The market type determined by institutional closure on a norm+kernel.

    | Variant         | Meaning                                        |
    |-----------------|------------------------------------------------|
    | `.openMarket`   | No norm selected (Sorites: FL hits wall, no closure). Equivalent to a free market — no certificate emitted, no cost deducted. |
    | `.paradoxMarket`| Arbitrary norm or ZD caught. Decree produces black markets, or the reserve would be annihilated by exceeding FL. No certificate emitted. |
    | `.closedMarket` | Fair-price norm satisfied. Certified price + deduction emitted. The AMM has successfully computed a fair price with positive residue. |

    The halting case (FL = reserve exactly) is postponed; currently lumped
    into `.paradoxMarket` pending further thought on smart-contract-equilibrium
    semantics. -/
inductive MarketType where
  | openMarket
  | paradoxMarket
  | closedMarket
  deriving DecidableEq, Repr

-- ============================================================================
-- Section 2: CertifiedPrice — the monoid-wrap receipt
-- ============================================================================

/-- The certified close receipt: wraps CortexCertificate with the AMM pricing
    fields, in the style of composable monoid carriers from functional
    programming.

    This is design (b): a separate structure that composes with
    CortexCertificate rather than extending it. CortexCertificate stays
    generic; CertifiedPrice layers AMM-specific fields on top.

    The `close` field carries the AMM's local CloseResult (price, costDeduction,
    residue). The `cert` field carries the EMLRegistry quench witness proving
    that the tree contracts to its rightComb normal form. -/
structure CertifiedPrice where
  cert  : EMLRegistry.CortexCertificate   -- the quench witness (proof-carrying)
  close : AMM.CloseResult                 -- the AMM pricing result

-- ============================================================================
-- Section 3: decideMarketType — choose the market type from kernel + guard
-- ============================================================================

/-- The institutional closure decides the market type by applying the kernel.

    KernelChoice.none → openMarket (Sorites: FL hits wall, no closure)
    KernelChoice.arbitrary → paradoxMarket (Edict: decree produces paradox)
    KernelChoice.fairPrice →
      if AMM.reserveGuard (FL ≥ reserveB) → paradoxMarket (reserve annihilated)
      else → closedMarket (certified price emitted)

    The halting case (FL = reserveB exactly) is currently lumped into
    paradoxMarket (the guard returns `true` for `cost ≥ reserveB`). -/
def decideMarketType (kernel : KernelChoice) (pool : AMM.Pool)
    (L : LogicTypes.LogicType) (tree : EMLRegistry.EMLTree)
    : MarketType :=
  match kernel with
  | .none => .openMarket
  | .arbitrary => .paradoxMarket
  | .fairPrice =>
    if AMM.reserveGuard pool L tree then
      .paradoxMarket
    else
      .closedMarket

-- ============================================================================
-- Section 4: marketClosure — the complete hyperstitional bridge
-- ============================================================================

/-- The complete market closure: takes a KernelChoice and externally-supplied
    pool, decides the market type, and (if closed) emits a CertifiedPrice.

    Pipeline:
    1. Run InstitutionalClosure.closure at the given cdStep on the events
       to produce a Norm (norm revision after closure).
    2. Decide the MarketType using decideMarketType.
    3. If closedMarket: call AMM.certifiedClose to get a CloseResult, then
       certify the tree via EMLRegistry.certify, and package as CertifiedPrice.
    4. If openMarket or paradoxMarket: no certificate emitted.

    This is the formal target of the .ncd plan — the NormCode plan dispatches
    inference through this Lean specification.

    The pool reserves (`reserveB`) are externally supplied per Q5. No cache
    for precomputed FL costs (TODO). -/
def marketClosure (kernel : KernelChoice) (pool : AMM.Pool)
    (L : LogicTypes.LogicType)
    (cdStep : Nat) (history : LogicM InstitutionalClosure.GameOutcome)
    (tree : EMLRegistry.EMLTree) (dx : Nat)
    (initialNorm : InstitutionalClosure.Norm)
    : LogicM InstitutionalClosure.Norm × MarketType × Option CertifiedPrice :=
  -- Step 1: Run IC closure
  let finalNorm : LogicM InstitutionalClosure.Norm :=
    InstitutionalClosure.closure cdStep history initialNorm
  -- Step 2: Decide market type based on the kernel
  let mkt : MarketType := decideMarketType kernel pool L tree
  -- Step 3: If closed, emit certified price
  let priceOpt : Option CertifiedPrice :=
    match mkt with
    | .closedMarket =>
      let closeRes := AMM.certifiedClose pool L tree dx
      let cert := EMLRegistry.certify tree
      some { cert := cert, close := closeRes }
    | _ => none
  (finalNorm, mkt, priceOpt)

-- ============================================================================
-- Section 5: blameToBudget — bridge BlamePool to NonAssociativeBudget
-- ============================================================================

/-- Maps an IC BlamePool to a SplitOctonionCost NonAssociativeBudget.

    The minimal version: total defects become local residue, clamped to
    max_capacity (= 10, matching the SO pentagon bound) via `min`.

    TODO: realistic versions would derive max_capacity from the specific
    norm in use rather than hardcoding 10, and might use a more
    sophisticated mapping (e.g. weighted by roundCount or totalImpact). -/
def blameToBudget (blame : InstitutionalClosure.BlamePool) : NonAssociativeBudget :=
  {
    local_residue := min blame.totalDefects 10
    max_capacity := 10
    h_capacity_pos := by decide
    h_pentagon_bound := Nat.min_le_right blame.totalDefects 10
  }

end MarketClosure
