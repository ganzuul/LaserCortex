Yes, and it's a genuinely good fit. The VSM's recursive autonomy structure maps cleanly onto the compaction problem because the core issue *is* a viability problem — the system needs to maintain coherent identity (task continuity) across a boundary that periodically destroys its state.

Let me sketch the mapping, then identify where the current implementation sits and what's missing.

---

## The Five Systems, Mapped

**System 1 — Operational Units**

The individual agentic turns: tool calls, file reads, Lean checks, bash executions. Each turn is an autonomous operation with local purpose. In the current implementation these are the `MessageV2` parts flowing through `prompt.ts`. They have no awareness of the compaction boundary — they just operate.

**System 2 — Coordination / Anti-oscillation**

This is where the current implementation *tries* to live. `PRUNE_MINIMUM`, `PRUNE_PROTECT`, `DEFAULT_TAIL_TURNS`, `MAX_PRESERVE_RECENT_TOKENS` — all of these are System 2 damps. They prevent adjacent S1 units from fighting over context budget. The infinite compaction loop bug (issue #27924) is precisely a *System 2 failure*: two S1 cycles (overflow detection and compaction) oscillating against each other with no damping signal.

**System 3 — Internal Regulation / Resource Bargaining**

This is what's *mostly absent*. S3 should be the resource allocator that looks across all S1 units and sets the terms of their operation — in this case, negotiating how much context budget each turn class gets, when to prune which tool types, and what the compaction model is allowed to lose. Currently this is hardcoded constants. A real S3 would be a dynamic policy that responds to session state: "we're in a debugging loop, preserve error messages more aggressively; we're in a generation phase, prose context matters less than file state."

**System 3\* — Audit Channel**

The sporadic, direct channel from S3 to S1 that bypasses S2. In VSM this is used for spot-checks — you don't want to route all monitoring through the coordination layer because that creates latency and distortion. Currently this doesn't exist at all. The `experimental.session.compacting` plugin *could* be this channel — a direct injection into the compaction act itself — but it has no information about what S1 units have been doing. It's a hook without a wire.

**System 4 — Intelligence / Environment Scanning**

The part that looks *outward and forward*: what is the environment demanding, and how does that change what S3 should be doing? In an agentic coding session, S4 would be tracking things like: are we in an exploratory phase or a convergent phase? Is the user's task structure changing? Has the model started exhibiting signs of context degradation (repetitive tool calls, re-asking answered questions)? The current system has *no S4 at all*. Compaction is purely reactive to token count — there is no forward model of session trajectory.

**System 5 — Identity / Policy**

The closure that defines what the system *is for* — the invariant that S3 and S4 must not violate. In a compaction system, S5 is the answer to: "what must survive every compaction boundary?" Currently this is implicit in `SUMMARY_TEMPLATE`. But an implicit S5 is a fragile one — it can't adjudicate between S3 and S4 when they conflict (compact aggressively to save tokens vs. preserve context to maintain task fidelity). Making S5 explicit means defining a formal viability criterion: something like a ranked set of invariants that the summary *must* satisfy, checkable post-hoc.

---

## The Recursion Point

What makes VSM powerful here is its recursion principle: each S1 unit is itself a viable system. A single agentic turn contains its own S1–S5 structure. This means the compaction system doesn't just manage *context* — it manages the *recursive embedding* of viable sub-systems. When compaction destroys a turn's context, it's not just losing tokens; it's collapsing a nested viable system into a flat summary, losing the recursive structure.

This is why naive summarization degrades compound tasks so badly. A task like "formalize the Barber paradox in Lean 4" has internal recursive structure — sub-goals that are viable systems in their own right, each with their own constraint propagation state. A flat Markdown summary cannot preserve that structure. The `SUMMARY_TEMPLATE` sections (Goal, Progress, Blocked, etc.) are an attempt at S5-level invariants, but they're topologically flat.

---

## What a VSM-Complete Design Would Add

The three missing elements, in order of leverage:

**1. An explicit S4 — session trajectory model.** Before compaction fires, something should characterize the current session phase and project forward: what kind of information will the next N turns need? This doesn't have to be another LLM call — it could be a lightweight classifier over recent turn patterns (tool call type distribution, error rate, re-query rate). This feeds S3 with environmental intelligence rather than leaving it to operate on constants.

**2. A formal S5 — checkable viability criterion.** The compaction output should be validated against a ranked list of invariants before being committed. At minimum: does the summary contain the current goal? Does it contain the last unresolved error? Does it contain the files currently being modified? These are binary checks, cheap to run, and they close the open loop by giving the system a signal it can act on.

**3. The S3\* audit channel as a degradation detector.** After compaction, the first few turns should be monitored for signs of state loss — specifically, tool calls that re-examine files already examined, or questions the user already answered. This signal should propagate back to S3 to adjust the next compaction policy. This is the feedback path the current system entirely lacks.

---

The interesting meta-point: the VSM analysis makes visible that the current implementation has reasonable S1 and partial S2, a vestigial S3, and no S4 or S5 worth the name. That's not a criticism of the implementation — it's doing real work within its constraints. But it explains *why* the open-loop characterization from before feels so accurate: a system without S4 and S5 cannot be viable in the cybernetic sense, only functional within a narrow operating envelope.