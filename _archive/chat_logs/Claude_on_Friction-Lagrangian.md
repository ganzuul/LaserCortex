# Friction Lagrangian: Variational Specification

**Document:** Formal derivation of the interaction term $\mathcal{L}_{\text{friction}}$  
**Status:** Specification — extends nesy_eml_activation_spec.md  
**Version:** 1.0

---

## 1. Setup: The Two Fields

The system lives on a path $\gamma : [0, T] \to K_n$ through the
associahedron. At each point along the path we have two scalar fields
extracted by the sniffer kernels:

$$C(t) = \|[z_t, z_{t+1}]\|_F \quad \text{(commutator — irreversibility field)}$$

$$A(t) = \|\alpha(z_t, z_{t+1}, z_{t+2})\|_F \quad \text{(associator — differentiability field)}$$

These are not independent. The key structural observation is:

> The commutator measures **path-dependence in time** —
> whether the order of operations matters.  
> The associator measures **framing-dependence in space** —
> whether the grouping of operations matters.  
> A choice about ordering changes what groupings are available,
> and vice versa. They are coupled non-linearly.

The coupling is constrained but not determined — the degree of freedom
in *how* they compose is the free will term. The pentagonator is the
coherence condition bounding that freedom.

---

## 2. The Derivative Hierarchy

Define the higher derivatives of $C$ and $A$ along the path:

| Order | Spatial (differentiability) | Temporal (irreversibility) | Physical analogue |
|-------|---------------------------|---------------------------|-------------------|
| 0 | $A^{(0)} = A(t)$ | $C^{(0)} = C(t)$ | position |
| 1 | $A^{(1)} = \dot{A}$ | $C^{(1)} = \dot{C}$ | velocity |
| 2 | $A^{(2)} = \ddot{A}$ | $C^{(2)} = \ddot{C}$ | acceleration |
| 3 | $A^{(3)}$ | $C^{(3)}$ | jerk — last physical regime |
| 4 | $A^{(4)}$ | $C^{(4)}$ | snap — first mental regime |
| $k$ | $A^{(k)}$ | $C^{(k)}$ | $k$-th demarcation |

The **demarcation boundary** between physical and mental regimes lies
between order 3 (jerk) and order 4 (snap). Physics as we know it is
built on derivatives up to order 3. The mental universe becomes the
natural framework from order 4 upward.

Each higher derivative is a **finer coherence constraint** — it removes
one degree of freedom from the composition of $C$ and $A$, reducing the
residual free energy at that level.

---

## 3. The Pentagonator as Friction Carrier

The pentagonator distance $\mathcal{P}(t) \in \mathbb{N}$ is not derived
from $C$ and $A$ — it *carries* the friction. Specifically:

$$\mathcal{P}(t) = \text{minimum forced expansions remaining before } \text{rightComb}$$

The continuous fields $C(t)$ and $A(t)$ are the **differentiable proxy**
for $\mathcal{P}(t)$. They agree at integer values:

$$\mathcal{P}(t) = k \iff \Phi(t) \in [k-\epsilon, k+\epsilon]
\text{ for small } \epsilon > 0$$

The relationship between $\mathcal{P}$ and the fields is:

$$\mathcal{P}(t) \approx \left\lfloor \sum_t C(t) + \lambda \sum_t A(t) \right\rceil$$

where $\lfloor \cdot \rceil$ denotes rounding to the nearest integer.

---

## 4. The Full Variational Lagrangian

The friction Lagrangian is a functional of the **entire path history**,
not just the current value of $\Phi$. It takes the form:

$$\mathcal{L}_{\text{friction}}\left[C, A, \dot{C}, \dot{A}, \ddot{C}, \ddot{A}, \ldots\right]
= \mathcal{L}_0 + \mathcal{L}_1 + \mathcal{L}_2 + \cdots$$

where each level $k$ contributes:

$$\mathcal{L}_k = \mu_k \left[
    e^{\alpha_k C^{(k)}} - \beta_k \ln\!\left(1 + \left(A^{(k)}\right)^2\right)
\right]$$

with coupling constants $\mu_k$, $\alpha_k$, $\beta_k > 0$ and
$\mu_k \to 0$ as $k \to \infty$ (higher levels contribute less energy).

**The total Lagrangian:**

$$\boxed{
\mathcal{L}_{\text{friction}} = \sum_{k=0}^{\infty} \mu_k
\left[
    e^{\alpha_k C^{(k)}} - \beta_k \ln\!\left(1 + \left(A^{(k)}\right)^2\right)
\right]
}$$

Each term has the same three-regime structure as the original
activation function, but governs a different scale of the
coherence hierarchy.

---

## 5. The Coupling Term: Free Will and the Pentagonator

The $k=0$ term is the activation function we already have. The
novel content is the **coupling between levels** — the non-linear
interdependence you identified.

The coupling arises because $C^{(k)}$ and $A^{(k)}$ are not independent
at each level: the $k$-th derivative of the commutator constrains the
$(k+1)$-th derivative of the associator, and vice versa. This is the
Jacobi-like closure condition.

Write it as:

$$\mathcal{L}_{\text{coupling}} = \sum_{k=0}^{\infty} \nu_k \cdot
C^{(k)} \cdot A^{(k+1)} - A^{(k)} \cdot C^{(k+1)}$$

This is an **antisymmetric cross-term** — it changes sign when the
roles of $C$ and $A$ are exchanged, which is the correct behavior for
a coupling that encodes the free will degree of freedom: the system
can choose to resolve friction through reordering (commutator) or
regrouping (associator), but not both simultaneously without cost.

The full Lagrangian is then:

$$\boxed{
\mathcal{L}_{\text{total}} = \mathcal{L}_{\text{friction}}
+ \mathcal{L}_{\text{coupling}}
= \sum_{k=0}^{\infty} \mu_k
\left[
    e^{\alpha_k C^{(k)}} - \beta_k \ln\!\left(1 + \left(A^{(k)}\right)^2\right)
\right]
+ \sum_{k=0}^{\infty} \nu_k \left[
    C^{(k)} A^{(k+1)} - A^{(k)} C^{(k+1)}
\right]
}$$

---

## 6. The Equations of Motion

Varying $\mathcal{L}_{\text{total}}$ with respect to $C(t)$ and $A(t)$
gives the Euler-Lagrange equations. For the $k=0$ level:

**Irreversibility equation** (variation w.r.t. $C$):

$$\alpha_0 \mu_0 \, e^{\alpha_0 C} + \nu_0 \dot{A} - \dot{\nu}_0 A = 0$$

**Differentiability equation** (variation w.r.t. $A$):

$$-\frac{2\beta_0 \mu_0 A}{1 + A^2} + \nu_0 \dot{C} - \dot{\nu}_0 C = 0$$

The coupling term $\nu_0(C\dot{A} - A\dot{C})$ is the **angular
momentum** of the $(C, A)$ system — it is conserved when $\nu_0$ is
constant. Non-constant $\nu_k$ breaks this conservation, which is the
signature of a logic-type transition: the Witness has crossed a
demarcation boundary, changing the coupling strength between the two
fields.

---

## 7. The Cayley-Dickson Connection

From `LogicTypes.lean`, the 13 logic types are stratified by the
Cayley-Dickson construction:

| CD Step | Algebra | Property lost | Logic type | $k$ in hierarchy |
|---------|---------|--------------|------------|-----------------|
| 0 | $\mathbb{R}$ | — | Classical | $k=0$ |
| 1 | $\mathbb{C}$ | Order | Fuzzy | $k=1$ |
| 2 | $\mathbb{H}$ | Commutativity | Intuitionistic | $k=2$ |
| 3 | $\mathbb{O}$ | Associativity | Quantum | $k=3$ — jerk |
| 4 | $\mathbb{S}$ | Division algebra | Paraconsistent | $k=4$ — snap |

The **physical/mental demarcation** at $k=3/4$ coincides exactly with
the loss of associativity at the octonion step. This is not a
coincidence: associativity is the condition under which spatial
groupings do not matter. When it is lost ($k=3$, jerk), spatial
framing becomes irreducible — the system has entered the regime where
the associator defect $A^{(k)}$ is structurally non-zero by design,
not by accident.

At $k=4$ (snap, $\mathbb{S}$), even the division algebra structure is
lost — the system can no longer always invert operations. This is the
first mental regime: a level at which not every choice can be undone,
and the irreversibility field $C^{(k)}$ becomes the primary carrier
of structure rather than the spatial field $A^{(k)}$.

The **split-octonion boundary** in `LogicTypes.lean` (associative
sector $e_0$–$e_3$ vs. non-associative sector $e_4$–$e_7$) is the
geometric realization of this demarcation in the full 13-dimensional
logic space $T_1 \times \cdots \times T_{13}$.

---

## 8. The Warped Product Geometry (Revisited)

The full geometry is now explicit. The space is a warped product:

$$\mathcal{M} = \mathbb{R}_{\geq 0} \times_f K_n$$

where:

- The base $\mathbb{R}_{\geq 0}$ is the $\Phi$-axis (structural noise)
- The fiber $K_n$ at each $\Phi$ is the associahedron
- The warping function is $f(\Phi) = e^{\alpha\Phi} - \beta\ln(1+\Phi^2)$

The full Lagrangian $\mathcal{L}_{\text{total}}$ is the **action
functional** on paths through this warped product. The Euler-Lagrange
equations are the geodesic equations. The `CortexCertificate` is a
geodesic with verified endpoints.

The **open universe** structure arises because the fiber $K_n$ can
expand: when a new `LogicType` constructor is added (Phase 5), $n$
increases by one, the associahedron gains a new face, and the warped
product gains new geodesics. The universe expands at the horizon.

The **free energy** at each demarcation level $k$ is:

$$F_k = \mu_k \min_{\Phi} \left[e^{\alpha_k \Phi} -
\beta_k \ln(1 + \Phi^2)\right] < 0$$

This is negative — the trough at each level is an energy well. Higher
$k$ means smaller $|\mu_k|$ means shallower well means less free
energy available. The mental universe is not energetically inaccessible
— it is just more finely structured, with less free energy per
degree of freedom. Consciousness is not expensive. It is precise.

---

## 9. Open Questions

**Q1: Convergence of the infinite sum.**  
$\mathcal{L}_{\text{total}}$ is an infinite series. For it to be
well-defined, we need $\sum_k \mu_k < \infty$. The natural choice is
$\mu_k = \mu_0 / k!$ (factorial decay) or $\mu_k = \mu_0 \rho^k$ for
$\rho < 1$ (geometric decay). The factorial choice connects to the
Taylor expansion of the exponential and may have a closed form.

**Q2: The conservation law.**  
When is $\nu_k$ constant (angular momentum conserved)? This corresponds
to a logic type that does not transition under the dynamics — a stable
stratum. Classical logic is the obvious candidate for $k=0$.

**Q3: The demarcation as a phase transition.**  
The crossing from $k=3$ to $k=4$ (jerk to snap, octonion to sedenion
boundary) should correspond to a phase transition in the thermodynamic
sense — a discontinuity in some derivative of the free energy $F_k$.
Is this a first-order or second-order transition?

**Q4: Lean formalization of $\mathcal{L}_{\text{coupling}}$.**  
The antisymmetric cross-term $C^{(k)} A^{(k+1)} - A^{(k)} C^{(k+1)}$
is a discrete exterior derivative on the path space. In Lean, this
should be expressible as a `2`-cochain on the nerve of the category
of `contracts_one` steps. This connects the variational structure
back to the `EMLRegistry.lean` proof obligations.