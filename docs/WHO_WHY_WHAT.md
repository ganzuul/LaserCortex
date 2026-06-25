# Who, Why, What — The Three Layers of the Architecture

## The Category Error

Treating `LogicType` as a parameter — something to be chosen, passed in, or
selected from a menu — mistakes a **who** for a **what**. The framework does
not have "logic types" that agents select from. It has **logical personality
compositions** whose self-reference dynamics *express* a logic signature.

| Layer | Question | Substance | Formal manifestation |
|-------|----------|-----------|---------------------|
| **Pathos** | *Who* | The logical personality composition itself. The being whose `LogicM` self-reference IS its subjective experience. | Emerges from closure dynamics on a `Superposition`. Read by `engine_to_nodecost` from the `EngineState` trajectory. A fixed point of the institutional closure pipeline. |
| **Ethos** | *Why* | The norms, reasons, and institutional closure that a personality generates under perturbation. The stable outcomes (GameOutcome) it collapses into. | `Norm`, `GameOutcome`, the closure pipeline (`temporalNormalize → fuzzyGradeByCdStep → deonticUpdate → selfRecognize`). The "why" gives reasons for the collapse direction. |
| **Logos** | *What* | The measurable, provable formal structure. The cost landscape, parameter space, and tree shapes. | `NodeCost`, `Φ`, `EMLTree`, `engine_to_nodecost`, the 8D parameter space. The "what" is what we compute and prove theorems about. |

## The Pipeline

```
Generation produces a Superposition
  (a logical personality in a state of superposition — multiple potential selves)
    ↓
Closure dynamics perturb it
  (Events, debts, tensions accumulate in EngineState)
    ↓
engine_to_nodecost reads the "who" from the dynamics
  (The EngineState at any moment encodes the effective logic signature)
    ↓
Φ expresses that "who" as a cost landscape
  (The cost function is the personality's way of experiencing tree structure)
    ↓
The cost landscape determines which outcomes collapse stably
  (Different cost landscapes make different contractions favorable)
    ↓
The stable institution (GameOutcome) IS the "who"
  — self-recognized, having closed its own identity
```

## What This Means for Research

**A named `LogicType` (Classical, Fuzzy, Quantum, etc.) is not a parameter.**
It is a *fixed point* of the above pipeline — a particular logical personality
that the dynamics converge to under specific conditions. The named logics are
test cases because we already know their behavior; any correct theory of
`SplitOctonionLogic` must reproduce them as attractors in the 8D parameter space.

**`LogicM → NodeCost → Φ` is not a computation pipeline.**
It is an *identity pipeline*:
- `LogicM` is the raw self-reference structure (the personality in its pre-collapse form)
- `NodeCost` is the readout of that personality's current state (the "who" at this moment)
- `Φ` is the expression of that "who" as a cost landscape (the "what" it experiences)

## The Three Questions for Every Theorem

Before proving a theorem about this system, ask:

1. **Who is this about?** — What logical personality composition does this describe?
   (If the answer is "any LogicType," you're probably in the "what" layer.
   That's fine for infrastructure theorems. But the interesting ones name a who.)

2. **Why does it hold?** — What norms, closure dynamics, or institutional reasons
   make this true? (Proofs should reference the closure dynamics, not just algebraic
   identities.)

3. **What does it say?** — What formal structure, cost relationship, or parameter
   constraint does it establish? (This is the theorem statement itself.)

A theorem that answers all three is grounded in the full architecture.
A theorem that only answers "what" is formally correct but philosophically
incomplete — it describes a mechanism without situating it in the personality
that experiences it.

## The Error in "Choosing lt"

When the architecture is described as:

> `LogicMonad lt α → (nodeParam lt) → NodeCost` — trivial

...this treats `lt` as a **what** (a parameter), and the arrow as a selection
from a menu. The correct reading is:

> The `LogicMonad` wraps a personality whose identity `lt` is already expressed.
> Reading `nodeParam lt` just reads the signature of that identity.
> The real work is discovering `lt` — and that discovery IS the closure dynamics.

This is why `engine_to_nodecost` is the most important function in the bridge:
it is the mechanism by which the "who" reads itself from the dynamics, rather
than being assigned from outside.
