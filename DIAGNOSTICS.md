# Diagnostic Discipline

A companion to SAFETY.md. Where SAFETY.md prevents harm, this document
prevents wasted time — specifically, the kind of circular troubleshooting
where you change things, can't tell what helped, and end up knowing less
than when you started.

## Principles

### D1: Measure first, reason second

It is tempting to identify a root cause from symptoms and jump straight to
a fix. Resist. A measurement that contradicts your hypothesis is the most
valuable data point you can get; a measurement that confirms it is the
only one that counts.

**Before changing anything:**
1. Establish a baseline — measure the current behavior with a reproducible
   test. Record the numbers. If you don't have a "before," you can never
   claim an "after."
2. If you cannot measure the thing you want to fix (RSS, latency, throughput,
   error rate), stop and build the measurement first. A fix without a
   measurement is a guess.
3. Form a hypothesis, then design the smallest test that could **falsify**
   it. A test that can only confirm is not a test — it's a story.

**Rules of thumb:**
- No baseline = no before/after. Write it down.
- "I think it's X" → your next action is a test that would show it's *not* X.
- If you can't reproduce the problem on demand, you can't verify the fix.

### D2: One change at a time

Changing multiple parameters in one edit feels efficient. It isn't. If the
situation improves, you don't know which change helped. If it worsens, you
don't know which change hurt. Either way, you learn nothing.

**Rules of thumb:**
- One parameter, one edit, one test. Then the next parameter.
- If you must change two things that are entangled (e.g., a client-server
  protocol change), treat the pair as one change and document why they
  cannot be separated.
- If you find yourself editing three things "while you're in there," stop.
  Commit (or revert) what you have, then make the next change.

### D3: Smallest test first

The "real" test — the full pipeline, the production workload, the end-to-end
scenario — is the slowest and noisiest way to get information. Start with
the smallest test that could answer your question.

**Rules of thumb:**
- Single-batch before full ranking. One request before concurrency. Unit
  test before integration test. 2-minute test before 15-minute test.
- If you cannot think of a small test, you do not yet understand the
  problem well enough to fix it. Keep investigating.
- The time you save on a quick negative result (ruling out a hypothesis
  in 2 minutes) pays for the extra overhead of running it separately.

### D4: Research before you edit

You have tools for a reason. Use them. Before changing code you don't fully
understand, read the documentation, search for known issues, check what
others have done.

**Rules of thumb:**
- If you are changing a library parameter, read the library's docs for
  that parameter first. A 2-minute web search beats a 30-minute debugging
  session based on a wrong assumption.
- If you are changing a numeric constant (buffer size, thread count, token
  limit), understand what it controls before choosing a new value.
- If multiple people could investigate in parallel (e.g., one researching
  docs while another builds a benchmark), do that.

### D5: Validate quality, not just function

A change that makes the system faster or leaner but silently degrades output
quality is a regression, not an improvement. Always define what "correct"
means before optimizing.

**Rules of thumb:**
- If you change a model parameter (max tokens, quantization, truncation),
  verify that the output is still fit for purpose — not just that it runs.
- Compare before/after outputs on the same input. If you don't have a
  quality metric, create one (even a manual spot-check on 10 examples).
- A faster wrong answer is worse than a slower right answer.

### D6: Keep the user in the loop

When a test runs for minutes, the user is watching a blank screen. That
silence is indistinguishable from "it's broken" or "nothing is happening."

**Rules of thumb:**
- Before a long-running test, state: what you expect, how long it should
  take, and what you'll check if it doesn't finish on time.
- During a long-running test, report progress at intervals — even just
  "still running, batch 12/28, RSS stable at 2.1 GB."
- If something unexpected happens (slower than expected, higher RSS than
  baseline), say so immediately. Don't wait for the test to finish to
  report a surprise.

### D7: Guards must guard against the actual risk

A safety check that blocks benign states while missing the real threat is
worse than no check — it creates false confidence and wastes time on
workarounds.

**Rules of thumb:**
- Before writing a guard, name the specific risk it prevents. "Swap > 1 GB"
  is not a risk. "Insufficient free RAM for the process" is.
- After writing a guard, ask: can this trigger in a state where the real
  risk is absent? If yes, the guard is too broad.
- A guard that fires on every startup is a nuisance. Either fix the
  condition it checks, or fix the guard.

## Incident Log

Specific incidents illustrating these principles. Cross-referenced by
principle — an incident rarely violates just one.

### INC-1: ONNX embed server diagnostic session

| Error | Principles violated | Impact |
|-------|-------------------|--------|
| Assumed root cause without measuring alternatives | D1 | Never verified `enable_mem_pattern` was actually the cause |
| Changed 4+ parameters in one edit | D2, D5 | Cannot attribute effects; unknown quality loss from max_length=512 |
| Full ranking before single-batch benchmark | D3 | 15 min for 1 data point instead of 12 min for 6 |
| No baseline measurement | D1 | No before/after comparison possible |
| No web search or doc reading | D4 | Decisions from incomplete information |
| No real-time progress reporting | D6 | User frustration, premature abort |
| ulimit set without measuring peak VSZ | D1, D3 | Three rounds of tuning instead of one measurement |
| Swap check blocked on wrong metric | D7 | Guard fired on benign state, missed actual risk |
