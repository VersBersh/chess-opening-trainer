---
id: {TASK-ID}
title: {Title}
epic: {EPIC-ID} # omit this line if standalone
depends: [{DEPENDENCY-IDS}] # or []
specs:
  - features/drill-mode.md
  - architecture/models.md
files:
  - src/lib/path/to/relevant_file.dart
  - src/lib/path/to/another_file.dart
---
# {TASK-ID}: {Title}

**Epic:** {EPIC-ID or "none"}
**Depends on:** {list of task IDs, or "none"}

## Description

What needs to be done, in plain terms.

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Notes

Any additional constraints, design decisions, or gotchas.