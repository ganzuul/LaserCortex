# Discipline of the Open Notebook

These articles are not suggestions. They are the creed. Violation means the
system is broken and must stop until corrected.

## I. Know the Ground

Before any operation that touches the working tree, read the full landscape:

- `git status` — what is modified, staged, untracked
- `git stash list` — any stashes that would be affected
- `git log --oneline -3` — where we are relative to the last commit
- For each target file: is it tracked or untracked? If untracked, it has no
  history — a single overwrite and it is gone.

A blind operation on unknown ground is a landmine. Step on it once and you
lose work.

## II. One Change, One Verify

An atomic change is:

- One definition added or modified
- One theorem statement and its proof
- One import added
- One field added to a structure
- One configuration line in lakefile.toml, lean-toolchain, etc.

After each atomic change:
- Build (`lake build Target.Module`)
- If it compiles, proceed.
- If not, fix before the next change.
- If the fix takes more than three attempts, stop and reassess.

Never batch multiple structural edits before a build. The build is the
compass. Without it you are walking blind.

## III. Backup Before Overwrite

Any file that is NOT tracked by git shall be backed up before being written
to. The backup goes to `/tmp/` with a timestamp:

```
cp /path/to/untracked_file.lean /tmp/untracked_file.lean.$(date +%s)
```

This applies to:
- `write` calls that overwrite an existing file
- `edit` calls that replace large blocks (>50 lines)
- Any operation that could destroy content

Tracked files can be recovered via `git checkout`. Untracked files have no
safety net. You are the safety net.

## IV. Never Stash Without Inspection

`git stash` is a sledgehammer. It moves ALL tracked-file changes out of the
working tree. It does NOT touch untracked files, which means the working tree
becomes a mix of reverted tracked files and orphaned untracked files — a
state that is confusing at best and lossy at worst.

Before any `git stash` or `git checkout`:
- List what will change: `git diff --stat HEAD`
- List untracked files: `git ls-files --others --exclude-standard`
- If untracked files exist, do NOT use `git stash` — use targeted `git
  checkout <file>` or `git restore <file>` instead.
- If you must stash, add `--include-untracked` and verify after pop that
  nothing was lost.

## V. Data-Risk Is Resource-Risk

SAFETY.md P1 guards against resource consumption (≥1 GB RAM, >30 s runtime).
But data-loss operations carry a different kind of risk — irrecoverable
instead of slow.

The following operations require explicit approval regardless of speed:
- `git stash`, `git reset`, `git checkout` on dirty trees
- `write` on an existing file that is not in git
- `edit` replacing >50 lines
- `rm` or `mv` on any file
- `lake clean`, `rm -rf` on build artifacts

Ask before each one. State what will be lost if it goes wrong.

## VI. No Theory Before Baseline

Uncommitted work is not real. It can vanish with a wrong keystroke.

Before adding any new definition, theorem, or structural change:
- The current working tree must either be clean or committed as a WIP
- The build must pass on the current state
- If a new dependency has been added (e.g. mathlib), commit that change
  *before* writing code that relies on it

A known-good committed state is the only safe place to work from. Everything
else is provisional.

## VII. Staging Sequence

The correct sequence for any non-trivial change:

1. **Survey** — read the relevant files, check git status, check deps
2. **Backup** — copy untracked files to /tmp/
3. **Plan** — state the atomic changes in order, get approval if needed
4. **Execute one atom** — make the smallest possible edit
5. **Build** — `lake build` on the target module
6. **Fix** — if it fails, fix; if stuck >3 tries, stop
7. **Repeat** — go to step 4 for the next atom
8. **Commit** — when a coherent unit of work compiles and tests pass

Skipping any step invalidates all subsequent steps. The sequence is a chain.

## VIII. When Something Goes Wrong

If you realize you have broken a rule:

1. **Stop immediately.** Do not try to fix while still operating.
2. **State what happened.** Describe the broken rule and the current state.
3. **Assess the damage.** Check what was lost, what can be recovered, what
   needs to be rebuilt.
4. **Recover.** Restore from backup (/tmp/), from git, or from memory with
   verification.
5. **Fix the process.** Identify the gap in instructions or the lapse in
   discipline. Document it.
6. **Proceed only when the baseline is verified.** Build must pass. Git
   status must be understood. The user must confirm.

Speed is not a virtue here. Correctness is.
