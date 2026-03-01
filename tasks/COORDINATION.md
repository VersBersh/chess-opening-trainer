# Task Coordination Protocol

How parallel agents coordinate task selection across git worktrees.

## Agent Identity

Each agent is identified by its branch name:

```bash
git branch --show-current
```

Branch names are unique per worktree, so they serve as natural agent IDs.

## Lock File Location

Lock files live inside `.git/`, shared across all worktrees but not tracked by git:

```
<git-common-dir>/task-locks/<task-id>.lock
```

Discover the common dir with:

```bash
git rev-parse --git-common-dir
```

Create the directory if it doesn't exist:

```bash
mkdir -p "$(git rev-parse --git-common-dir)/task-locks"
```

## Lock File Format

Two lines — branch name and ISO-8601 timestamp:

```
parallel_1
2026-03-01T14:30:00Z
```

## Task Selection Protocol

When an agent needs to pick a task:

1. **Scan tasks:** Find all `tasks/*/task.md` files. Skip folders containing `epic.md` — those are epics, not tasks.

2. **Check completion:** For each task, check whether `.complete` exists in the **main worktree** (not the current worktree). A task isn't "done" until it's merged to main, because other agents can't build on unmerged work.

   Find the main worktree path from the first `worktree` entry in:
   ```bash
   git worktree list --porcelain
   ```

3. **Check dependencies:** Parse the `**Depends on:**` line from each `task.md`. A task is blocked if any of its dependencies are incomplete (no `.complete` in the main worktree).

4. **Check locks:** Read `<git-common-dir>/task-locks/*.lock`. A task is locked if a corresponding lock file exists and is not stale.

5. **Filter candidates:** Candidates = incomplete + unblocked + unlocked.

6. **Rank candidates:**
   - Primary: downstream unblock count (descending) — tasks that unblock the most other tasks go first.
   - Tiebreaker: task ID (ascending) — alphabetical/numerical order.

   To compute downstream unblock count: for each candidate, count how many incomplete tasks list it (directly or transitively) in their dependency chain.

7. **Lock the top candidate:** Write the lock file with branch name + timestamp.

8. **Proceed** with the selected task.

If no candidates are available, report what's locked and what's blocked, then stop.

## Downstream Unblock Count Reference

With CT-0 and CT-1.1 complete, the current ranking is:

| Rank | Task | Downstream count | Why |
|------|------|-----------------|-----|
| 1 | CT-2.1 | 5 | Unblocks CT-2.2, CT-2.3, CT-2.4, CT-2.5, CT-4 |
| 2 | CT-1.2 | 4 | Unblocks CT-1.3, CT-1.4, CT-4, CT-5 |
| 3 | CT-2.6 | 0 | No downstream |
| 4 | CT-3 | 0 | No downstream |
| 5 | CT-6 | 0 | No downstream |

This table is illustrative — agents compute rankings dynamically at selection time.

## Lock Lifecycle

- **Created** when an agent selects a task (Step 7 above).
- **Removed** after the agent merges the completed task to main (part of the merge cycle below).

## Stale Lock Detection

A lock is stale if the branch recorded in it no longer exists:

```bash
git branch -l <branch-name>
```

If the branch doesn't exist, the lock is stale — the agent that created it is gone. Treat the task as unlocked.

## Branch Reuse & Merge Cycle

Worktrees and branches are long-lived. After completing a task, the same branch is reused for the next task. The merge cycle is:

1. **Rebase onto main:** `git rebase main` — puts the task's commits on top of the current main tip. Ensures fast-forward is possible even if main moved (from other branches merging).

2. **Fast-forward merge:** `git -C <main-worktree-path> merge --ff-only <branch>` — runs the merge in the main worktree (which has `main` checked out) without leaving the current worktree. Keeps history linear, no merge commits.

3. **Clean up lock:** Delete `<git-common-dir>/task-locks/<task-id>.lock`.

4. **Return to branch:** The branch is now at the same commit as main. Ready for the next task.

If the rebase has conflicts, the agent resolves them (it has full context of the task it just completed). If `--ff-only` fails after rebase, something went wrong — investigate, don't force.

## Why Main Worktree for Dependency Checking?

Each worktree creates `.complete` locally. But agent B can't build on agent A's work until it's merged to main — agent B's worktree doesn't have agent A's code. So dependency resolution must check the main worktree.

Flow: Agent A completes CT-1.2 → merges to main (ff) → lock removed → `.complete` now in main → Agent B can now select CT-1.3 (depends on CT-1.2).

## Why Fast-Forward Only?

- **Linear history** — easy to read, bisect, and revert.
- **No merge commits** cluttering the log.
- **Rebase before merge** guarantees the branch is ahead of main.
- **If ff-only fails**, it's a signal something unexpected happened — forcing would hide the problem.
