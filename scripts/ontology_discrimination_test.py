#!/usr/bin/env python3
"""Compact ontology discrimination test.

For each candidate ontology (P-PLAN, VerbNet, FrameNet, DUL), define a
small vocabulary of label+definition pairs. Embed them alongside our 6
CSG anchor centroids. Measure: does each category get a UNIQUE nearest
term? The ontology that discriminates best is the right schema.

No ontology downloads needed — we use known vocabulary.
"""
import json, time, urllib.request, sys, os

# ── Our 6 CSG categories (anchor centroids from previous run) ────────
CSG_ANCHORS = {
    "temporalMonad": [
        "Let me begin by exploring the problem space and understanding what we are working with.",
        "I should start by taking stock of the current situation before proceeding.",
        "I need to first understand the context and constraints before making changes.",
        "Let us now turn to the next step in the reasoning process.",
        "I will now examine the structure of this problem more carefully.",
    ],
    "computationAction": [
        "Run the experiment to compute the result and produce concrete output data.",
        "Execute the verification tool to check whether the certificate contraction path is valid.",
        "Parse the input file and build the output structure from the parsed components.",
        "Search the codebase for all references to this function and list the results.",
        "Lift the inference into the formal layer by calling the bridge lift operation.",
        "Ground the certificate back into the decision layer by decomposing the contraction path.",
    ],
    "scope": [
        "Run a targeted experiment focusing only on the specific module that is failing.",
        "First, check the most critical constraint before expanding the search.",
        "Carefully examine exactly the boundary condition where the error occurs.",
        "Limit the search to precisely the files that were modified in this commit.",
        "Apply this change only to the specific case mentioned, not globally.",
    ],
    "exploration": [
        "Investigate the Tamari lattice contraction structure to understand how trees contract.",
        "Explore the proof architecture and understand how the theorems connect to each other.",
        "Understand the codebase structure and how the different modules interact.",
        "Examine what happens when the friction barrier is crossed at the CD 2 to 3 boundary.",
        "Look into the algebraic structure of the split octonion and its basis vectors.",
        "Study how the generation and collapse duality produces candidate structures.",
    ],
    "idempotentTarget": [
        "I really want to make sure this is correct before moving forward.",
        "The key insight is definitely that the certificate must verify independently.",
        "This is certainly the right approach because the contraction path is decidable.",
        "I am confident that this result holds and the proof is complete.",
        "This must be exactly right — the system cannot proceed without certainty.",
    ],
    "certifiedGeometry": [
        "Figure this out by verifying that the contraction path exists from source to target.",
        "The certificate is valid because the proof carries a verified contraction path.",
        "The proof is complete when the tree reaches its right-comb normal form.",
        "The contraction path exists and decidable contracts to holds for this tree.",
        "This is correct because the audit channel independently verifies the result.",
        "The result holds because the friction barrier prevents invalid crossings.",
    ],
}

# ── Candidate ontology vocabularies (compact: label + 1-line gloss) ──

ONTOLOGIES = {

    "P-PLAN": {
        "desc": "Process planning: steps, variables, plans, decomposition",
        "terms": {
            "Plan": "A set of steps intended by agents to achieve some goals in a process.",
            "Step": "An action in a plan, executed as part of a process, producing output.",
            "Variable": "An input or output of a step execution in a planned process.",
            "MultiStep": "A step that can be decomposed into a sub-plan with multiple steps.",
            "isPrecededBy": "A step that precedes the current step in the execution order.",
            "hasInputVar": "A step takes a variable as input for the planned execution.",
            "hasOutputVar": "A step produces a variable as output from the planned execution.",
            "isDecomposedAsPlan": "A multistep is decomposed into a sub-plan with its own steps.",
            "Activity": "The execution process planned in a step, acting on entities.",
            "Entity": "The input and output of the execution of an activity in a plan.",
        },
    },

    "VerbNet": {
        "desc": "Verb classes with subevent predicates and thematic roles",
        "terms": {
            "compute-10.4": "An agent performs a calculation to determine a numerical result.",
            "investigate-35.4": "An agent searches and examines to discover information about a topic.",
            "plan-62.1": "An agent formulates a sequence of intended actions to achieve a goal.",
            "verify-36.2": "An agent checks and confirms whether a claim or condition is true.",
            "restrict-72.1": "An agent limits or narrows the scope of an action to a specific target.",
            "conclude-37.1": "A thinker arrives at certainty about a proposition after reasoning.",
            "search-35.1": "A seeker looks for something in a specific location or domain.",
            "transform-26.1.1": "An agent changes an entity into a different form or state.",
            "prepare-26.3": "An agent makes arrangements for a future event or action.",
            "assess-34.1": "An agent evaluates and judges the state or quality of something.",
        },
    },

    "FrameNet": {
        "desc": "Semantic frames with roles for situational understanding",
        "terms": {
            "INVESTIGATION": "A searcher attempts to find out information about a topic by examining evidence.",
            "SCRUTINY": "A cognizer examines an object closely to determine its properties.",
            "VERIFICATION": "A verifier checks whether a claim is true by testing it against evidence.",
            "COMPUTATION": "A computer performs calculations to determine a numerical result.",
            "PLANNING": "A planner develops a plan for future actions to achieve a goal.",
            "INTENTION": "A thinker intends and commits to performing a future action.",
            "RESTRICTION": "A limiter restricts the scope or extent of something to a specific range.",
            "CERTAINTY": "A cognizer is certain about the truth of a proposition.",
            "TRANSFORMATION": "An agent transforms an entity from one state into another.",
            "ASSESSMENT": "An assessor evaluates the quality or state of an entity.",
        },
    },

    "DUL": {
        "desc": "DOLCE+DnS Ultralite: process, action, plan, situation, task",
        "terms": {
            "Process": "A process is an event in time where something happens or changes.",
            "Action": "An action is a process carried out by an agent with intention.",
            "Task": "A task is an action that an agent is assigned or committed to perform.",
            "Plan": "A plan is a description of actions to be executed to achieve a goal.",
            "Situation": "A situation is a view of the world that satisfies a description.",
            "Design": "A design is a description of how something should be constructed.",
            "Parameter": "A parameter is a region that defines a constraint on a quality.",
            "Method": "A method is a plan that describes how to achieve a task.",
            "Function": "A function is a capacity of an entity to perform a role in a process.",
            "Role": "A role is a concept that classifies an entity in the context of a plan.",
        },
    },

    "PROV-O-Properties": {
        "desc": "PROV-O object properties (relations, not classes) — verb-oriented",
        "terms": {
            "used": "An activity used an entity as input in a process.",
            "wasGeneratedBy": "An entity was produced by an activity during execution.",
            "wasInformedBy": "An activity was informed by and dependent on another activity.",
            "wasAssociatedWith": "An activity was associated with an agent who had responsibility.",
            "wasAttributedTo": "An entity was attributed to an agent who bore responsibility.",
            "wasDerivedFrom": "An entity was transformed from a pre-existing entity.",
            "wasStartedBy": "An activity was started by a trigger entity.",
            "wasEndedBy": "An activity was ended by a trigger entity.",
            "hadPlan": "An association had a plan adopted by an agent for an activity.",
            "hadRole": "An entity assumed a role in the context of an activity.",
        },
    },
}

# ── Embedding helpers ─────────────────────────────────────────────────

EMBED_URL = "http://localhost:8082/v1/embeddings"

def embed(texts, batch=2):
    all_emb = []
    for i in range(0, len(texts), batch):
        batch_texts = texts[i:i+batch]
        payload = json.dumps({"input": batch_texts, "max_length": 500}).encode()
        req = urllib.request.Request(EMBED_URL, data=payload,
            headers={"Content-Type": "application/json"})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    data = json.loads(r.read())
                all_emb.extend(d["embedding"] for d in data["data"])
                break
            except Exception as e:
                if attempt < 2: time.sleep(1)
                else: all_emb.extend([[0.0]*1024]*len(batch_texts))
    return all_emb

def cos(a, b):
    d = sum(x*y for x,y in zip(a,b))
    na = sum(x*x for x in a)**0.5
    nb = sum(y*y for y in b)**0.5
    return d/(na*nb) if na and nb else 0.0

def centroid(embs):
    n = len(embs)
    return [sum(e[i] for e in embs)/n for i in range(1024)] if n else [0.0]*1024

# ── Main ──────────────────────────────────────────────────────────────

def main():
    print("=" * 70)
    print("Ontology Discrimination Test")
    print("Which ontology's vocabulary best separates our 6 CSG categories?")
    print("=" * 70)

    # Embed anchor centroids
    all_anchor_texts = []
    for cat, anchors in CSG_ANCHORS.items():
        all_anchor_texts.extend(anchors)
    print(f"\nEmbedding {len(all_anchor_texts)} anchor texts...")
    anchor_embs = embed(all_anchor_texts)

    # Build centroids
    cat_centroids = {}
    idx = 0
    for cat, anchors in CSG_ANCHORS.items():
        n = len(anchors)
        cat_centroids[cat] = centroid(anchor_embs[idx:idx+n])
        idx += n

    # Test each ontology
    results = {}
    for onto_name, onto_info in ONTOLOGIES.items():
        terms = onto_info["terms"]
        term_labels = list(terms.keys())
        term_texts = list(terms.values())

        print(f"\nEmbedding {len(term_texts)} {onto_name} terms...")
        term_embs = embed(term_texts)

        # For each CSG category, find nearest ontology term
        print(f"\n{'='*70}")
        print(f"  {onto_name}: {onto_info['desc']}")
        print(f"{'='*70}")

        nearest_assignments = {}  # cat -> (term, sim)
        term_to_cats = {}  # term -> list of (cat, sim)

        for cat in CSG_ANCHORS:
            sims = [(label, cos(cat_centroids[cat], term_embs[i]))
                    for i, label in enumerate(term_labels)]
            sims.sort(key=lambda x: -x[1])
            nearest = sims[0]
            nearest_assignments[cat] = nearest

            top3 = sims[:3]
            print(f"  {cat:22s} → {top3[0][0]:25s} ({top3[0][1]:.3f})  "
                  f"2nd: {top3[1][0]:20s} ({top3[1][1]:.3f})")

            for label, sim in top3:
                term_to_cats.setdefault(label, []).append((cat, sim))

        # Check uniqueness: does each category get a different nearest term?
        nearest_terms = [nearest_assignments[cat][0] for cat in CSG_ANCHORS]
        unique = len(set(nearest_terms))
        # Compute separation: mean(top1 - top2) across categories
        separations = []
        for cat in CSG_ANCHORS:
            sims = [(label, cos(cat_centroids[cat], term_embs[i]))
                    for i, label in enumerate(term_labels)]
            sims.sort(key=lambda x: -x[1])
            separations.append(sims[0][1] - sims[1][1])
        mean_sep = sum(separations) / len(separations)

        # Compute spread: std dev of top-1 sims (higher = more discriminative)
        top_sims = [nearest_assignments[cat][1] for cat in CSG_ANCHORS]
        mean_top = sum(top_sims) / len(top_sims)
        std_top = (sum((s - mean_top)**2 for s in top_sims) / len(top_sims))**0.5

        results[onto_name] = {
            "unique": unique,
            "mean_separation": mean_sep,
            "mean_top_sim": mean_top,
            "std_top_sim": std_top,
            "assignments": nearest_assignments,
        }

        # Check for term collisions
        collisions = {t: cats for t, cats in term_to_cats.items()
                      if len(cats) > 1}
        if collisions:
            print(f"\n  ⚠ Term collisions ({len(collisions)}):")
            for term, cats in collisions.items():
                cat_str = ", ".join(f"{c}({s:.3f})" for c, s in cats)
                print(f"    {term:25s} ← {cat_str}")
        else:
            print(f"\n  ✓ All 6 categories map to unique terms")

        print(f"  Unique assignments: {unique}/6")
        print(f"  Mean separation (top1-top2): {mean_sep:.3f}")
        print(f"  Mean top-1 similarity: {mean_top:.3f}")
        print(f"  Std top-1 similarity: {std_top:.3f} (higher=more discriminative)")

    # ── Summary comparison ───────────────────────────────────────────
    print(f"\n{'='*70}")
    print("SUMMARY: Ontology discrimination power")
    print(f"{'='*70}")
    print(f"  {'Ontology':25s} {'Unique':>7s} {'Sep':>7s} {'Mean':>7s} {'Std':>7s}")
    print(f"  {'─'*55}")
    for onto_name in sorted(results, key=lambda k: -results[k]["unique"]):
        r = results[onto_name]
        print(f"  {onto_name:25s} {r['unique']:>4d}/6 {r['mean_separation']:>7.3f} "
              f"{r['mean_top_sim']:>7.3f} {r['std_top_sim']:>7.3f}")

    # Best ontology
    best = max(results, key=lambda k: (results[k]["unique"],
                                        results[k]["std_top_sim"]))
    print(f"\n  Best: {best}")
    print(f"  {ONTOLOGIES[best]['desc']}")

    # Show the mapping
    print(f"\n  Category → Term mapping for {best}:")
    for cat in CSG_ANCHORS:
        term, sim = results[best]["assignments"][cat]
        print(f"    {cat:22s} → {term:25s} (sim={sim:.3f})")

if __name__ == "__main__":
    main()
