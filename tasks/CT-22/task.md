---
id: CT-22
title: Fix intervalDays Default (0 vs 1)
depends: []
specs:
  - features/line-management.md
  - architecture/spaced-repetition.md
files:
  - src/lib/repositories/local/database.dart
---
# CT-22: Fix intervalDays Default (0 vs 1)

**Epic:** none
**Depends on:** none

## Description

The `line-management.md` spec says new cards should have "interval 0," but the DB schema (`database.dart` line 36) defaults `intervalDays` to `1`. Either update the schema default to `0` via migration, or update the spec to match the current schema.

## Acceptance Criteria

- [ ] Spec and DB schema agree on the default intervalDays value
- [ ] If schema changes, a migration is provided
- [ ] Card creation in line entry and orphan handling both use the correct default

## Notes

Discovered during CT-2.4. Plan review #5 flagged the mismatch.
