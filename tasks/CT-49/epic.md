# CT-49: Add-line builder pattern for save semantics

## Goal

Make the Add Line screen behave as a true builder: the user assembles moves and labels, then confirms to persist everything at once. Currently, labels save immediately to the DB, take-back is restricted to buffered moves only, and there's no indication when following an existing line.

## Background

User feedback identified three violations of the builder pattern:

1. **Labels save immediately** — `updateLabel()` writes to DB and reloads the tree. Should be deferred to confirm.
2. **Take-back restricted** — `canTakeBack()` only works on buffered moves. Should work on all visible pills.
3. **No existing-line indicator** — Following an existing line exactly disables Confirm with no explanation.

## Specs

- `features/add-line.md` — updated: deferred label persistence, entry flow steps 6-7
- `features/line-management.md` — updated: unrestricted take-back, deferred label persistence subsection

## Tasks

- CT-49.1: Deferred label persistence
- CT-49.2: Unrestricted take-back through all pills
- CT-49.3: Existing-line info text
