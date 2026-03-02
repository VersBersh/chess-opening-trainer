# Task System

## Layout

Flat sibling folders under `tasks/`. A folder is a **task** if it has `task.md`, an **epic** if it has `epic.md`.

Epic membership is by ID prefix: `CT-1.1` belongs to epic `CT-1`. Standalone tasks (e.g. `CT-0`) have no dot.

## `task.md` Frontmatter

| Field | Required | Purpose |
|-------|----------|---------|
| `id` | yes | Must match folder name. Validated by `task-tool`. |
| `title` | yes | Human-readable title. |
| `epic` | no | Parent epic ID. Omit for standalone tasks. |
| `depends` | no | Task IDs that must complete first. Gates `task-tool claim`. |
| `specs` | no | Paths to spec/architecture docs (repo-relative). Read by `ImplementTask` for planning context. |
| `files` | no | Source files this task touches (repo-relative). `task-tool` deprioritises candidates that overlap locked files. |

Body: Description, Acceptance Criteria (checkboxes), Notes. See `task-template.md`.

## `epic.md`

No frontmatter. Sections: Goal, Background, Specs, Tasks list. Epics are never claimed or implemented — they provide shared context for subtasks. See `epic-template.md`.

## Lifecycle

- **`.complete`** — empty marker file in the task folder. Created by `ImplementTask` after merge. `task-tool` checks these to resolve `depends`.
- **Lock files** — managed by `task-tool`, stored in `<git-common-dir>/task-locks/`. See `COORDINATION.md`.

## Pipeline Artifacts

`ImplementTask` writes into the task folder:

| File | Contents |
|------|----------|
| `1-context.md` | Relevant files and architecture summary |
| `2-plan.md` | Implementation steps, goal, risks |
| `3-plan-review.md` | Plan review verdict and issues |
| `4-impl-notes.md` | Files changed, deviations, discovered work |
| `5-impl-review-consistency.md` | Implementation-vs-plan review |
| `5-impl-review-design.md` | Design principles review |
| `6-discovered-tasks.md` | Follow-up tasks found during implementation |

## Creating Tasks

1. Group related work into epics (`tasks/CT-N/epic.md`).
2. Decompose into tasks sized for one agent session. Each task should have testable acceptance criteria, explicit `depends`, and `files` for conflict avoidance.
3. Create `tasks/{id}/task.md` from `task-template.md`. Folder name must match `id`.
4. Or use `/AddTasks <source-id>` to create tasks from a completed task's `6-discovered-tasks.md`.

## Tools

- **`task-tool`** — `claim`, `status`, `unlock`. See `COORDINATION.md`.
- **`/ImplementTask [id]`** — Full pipeline: plan → review → implement → verify → code review → merge.
- **`/AddTasks <id> [numbers]`** — Create task folders from `6-discovered-tasks.md`.
