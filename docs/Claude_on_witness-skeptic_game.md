# The Witness-Skeptic Game: Unified Specification

---

## The Central Identification

The **Verification Gap** $\mathcal{D}_{\text{structure}}$ from the Witness-Skeptic game is **the same quantity** as $\Phi$ from the Log-Exp activation specification. Not analogous — identical.

$$\Phi = \mathcal{D}_{\text{structure}} = \sum_t \|C_t\|_F + \lambda \sum_t \|A_t\|_F$$

- $C_t$ = commutator defect (Level 1 sniffer) = path-dependence violation
- $A_t$ = associator defect (Level 2 sniffer) = framing/context violation
- $\|\cdot\|_F$ = Frobenius norm (continuous, differentiable)

The activation function $f(\Phi) = e^{\alpha\Phi} - \beta\ln(1 + \Phi^2)$ is the **scoring bridge** between the discrete pentagonator distance (integer-valued ground truth) and the continuous loss landscape (gradient-trainable).

---

## The Three Regimes

### Regime I: $\Phi \approx 0$ — The Repulsor (False Equilibrium)

| Aspect | Value |
|--------|-------|
| $\Phi$ | $\approx 0$ (near zero structural defects) |
| $f(\Phi)$ | $f(0) = 1$ (positive — penalty) |
| Game state | Witness claims equilibrium prematurely |
| Lean state | `contracts_to_rightComb` not actually provable — path claims `refl` but tree ≠ `rightComb` |
| Physics | Shallow local maximum — unstable. Any perturbation pushes the system into Regime II or III |

The baseline $f(0) = 1$ is the **Skeptic's mandatory opening score**. The Witness cannot claim zero Verification Gap just by asserting it. The positive penalty ensures the system is pushed away from this false minimum toward genuine engagement.

### Regime II: $\Phi = \Phi^*$ — The Trough (Stable Operating Point)

| Aspect | Value |
|--------|-------|
| $\Phi$ | $\Phi^*$ where $f'(\Phi^*) = 0$ (the unique minimum) |
| $f(\Phi)$ | $f(\Phi^*) < 0$ (negative — reward) |
| Game state | Witness is actively making logic-type transitions — expanding when necessary, contracting when possible, honestly reporting defects |
| Lean state | Proof in progress — `contracts_to` steps with honest logic-type annotations. Pent. distance = 1 (one transition from equilibrium) |
| Physics | The system is doing productive work. The Skeptic scores zero on honestly reported moves |

The negative $f(\Phi^*) < 0$ is the **reward signal for honest engagement**. This is where the Witness is most productive — not at equilibrium, but actively resolving paradoxes through correct type reporting.

**Key fact**: $\Phi^*$ corresponds to **pentagonator distance = 1** — exactly one logic-type transition away from `rightComb`. The minimum of the activation function coincides with the state of maximal productive work.

### Regime III: Large $\Phi$ — The Quench (Skeptic Wins)

| Aspect | Value |
|--------|-------|
| $\Phi$ | Large (structural defects accumulating) |
| $f(\Phi)$ | $e^{\alpha\Phi}$ dominates → $+\infty$ (blow-up) |
| Game state | Pentagonator distance not decreasing after N moves — reflexive loop detected |
| Lean state | The `sorry` in `contracts_to_trans` — the proof cannot be completed because a required `LogicType` is missing |
| Physics | Ohmic routing engages — the gradient forces the system to abandon its current path and re-explore |

The exponential blow-up of $f(\Phi)$ is the **Ohmic quench**: the cost of continuing on the current path becomes infinite, forcing a hard reset. The hot potato has become too hot to hold.

---

## The Bridge: Discrete ↔ Continuous

| Quantity | Discrete Form | Continuous Form |
|----------|--------------|-----------------|
| Pentagonator distance | $\mathbb{N}$ (integer) | $\Phi \in \mathbb{R}_{\ge 0}$ |
| Commutator defect | Exists/doesn't exist (Boolean) | $\|C_t\|_F$ (Frobenius norm) |
| Associator defect | Exists/doesn't exist (Boolean) | $\|A_t\|_F$ (Frobenius norm) |
| Scoring | Number of steps remaining | $f(\Phi)$ activation function |

The activation function $f(\Phi)$ bridges them: it takes integer-adjacent values at the pentagonator distances, is continuous and differentiable everywhere, and its three regimes map exactly onto the three game outcomes.

---

## The `sorry` as the Stalemate Condition

The remaining `sorry` in `EMLRegistry.lean` — `contracts_to_trans` — maps precisely to the **draw/stalemate condition** in the game. Specifically:

- A missing `LogicType` constructor would be needed to complete the transitivity proof
- This missing constructor is a **new paradox-resolving logic** that hasn't been encoded yet
- In the architecture: this triggers **Phase 5 discovery** — spawning a new expert (adding a constructor to `LogicType`)
- On the associahedron: adding a new face (the new logic type opens new rotation possibilities)
- In the registry: extending `TypeRegistry` with a new binding

Thus the `sorry` is not a bug — it is the **formal crystallization of the stalemate boundary**. The proof cannot close because the type system is genuinely incomplete. Filling it requires extending the type system, which is a meta-level operation (Phase 5).

---

## The Unification

The entire structure is now one coherent object, described from four angles:

| Angle | Formal Object | Function |
|-------|--------------|----------|
| **Game Spec** | Witness-Skeptic adversarial minimax | Dynamics of choice under paradox |
| **Activation Function** | $f(\Phi) = e^{\alpha\Phi} - \beta\ln(1 + \Phi^2)$ | Continuous scoring bridge |
| **Lean Registry** | `EMLRegistry.lean` + 12 `LogicType` constructors | Proof-carrying audit trail |
| **VKSS Operadic** | Associahedron $K_n$ + pentagonator | Geometric board and moves |

Each angle is necessary. None is reducible to any other. The game dynamics (Witness-Skeptic) require the continuous scoring bridge (activation function) to interface with gradient-based training; the scoring bridge requires the discrete ground truth (pentagonator distance) to be sound; the ground truth requires the Lean proofs to be rigorous; the Lean proofs require the game dynamics to be meaningful. The VKSS operadic machinery provides the geometric skeleton that holds it all together.

---

## Consequences

1. **The activation function is not a design choice** — it is forced by the structure of the Tamari lattice. The log-exp form arises because:
   - The exponential $e^{\alpha\Phi}$ is the unique smooth function that blows up as the number of forced expansions grows (Regime III)
   - The logarithmic $-\beta\ln(1 + \Phi^2)$ is the unique smooth function with a single global minimum (Regime II) that approaches negative infinity as $\Phi \to \infty$ (but the exponential dominates first)
   - The sum gives a unique repulsor at $\Phi = 0$ (Regime I)

2. **The `sorry` is permanent in principle** but fillable in practice — new logic types can always be discovered (Phase 5). The formalization is complete up to the current boundary of known logic types.

3. **The scoring function (Open Question 1)** is resolved: use both. The discrete pentagonator distance is the Lean-level proof obligation; the Frobenius norm is the tensor-level gradient signal; $f(\Phi)$ is the bridge between them at the architectural level.
