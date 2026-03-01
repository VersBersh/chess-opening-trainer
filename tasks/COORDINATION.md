# Task Coordination Protocol

How parallel agents coordinate task selection across git worktrees.

## Canonical Interface

Use `task-tool` as the only task selection/locking interface. Do not manually read/write lock files.

Core commands:

```bash
task-tool claim
task-tool status
task-tool unlock <task-id>
```

## Agent Workflow

When an agent starts work:

1. Run `task-tool claim` from the repo root (or any path inside the repo).
2. If it prints a task ID, start that task.
3. If it fails with no claimable task, run `task-tool status` and report blocked/locked state.

After merging completed work to main:

1. Run `task-tool unlock <task-id>` to release the lock.
2. If ownership changed or recovery is needed, a human may run `task-tool unlock <task-id> --force`.

## What task-tool Enforces

`task-tool` already handles:

- Reading task metadata from YAML frontmatter (`id`, `depends`, `files`, `specs`, etc.).
- Dependency gating using `.complete` markers.
- Priority ranking by downstream unblock count.
- File-conflict-aware claim ordering (deprioritizes candidates that overlap locked files).
- Atomic lock creation to avoid race conditions.
- Stale lock cleanup based on active owner branch/worktree.
- Lock ownership checks on unlock.

## Lock Storage

Lock files are stored in the repo git common dir:

```
<git-common-dir>/task-locks/<task-id>.lock
```

This is implementation detail; agents should not manipulate these files directly.

## Merge Discipline

Dependency availability is based on what is merged to `main`. Keep using the existing cycle:

1. Rebase branch onto `main`.
2. Fast-forward merge into `main`.
3. Unlock the task with `task-tool unlock <task-id>`.

This keeps history linear and makes dependency resolution deterministic for all worktrees.