---
id: CT-30
title: PGN Import Polish — File Size Warning & extendLine API
depends: ['CT-3']
specs:
  - features/pgn-import.md
files:
  - src/lib/screens/pgn_import_screen.dart
  - src/lib/repositories/repertoire_repository.dart
---
# CT-30: PGN Import Polish — File Size Warning & extendLine API

**Epic:** none
**Depends on:** CT-3

## Description

Two improvements for PGN import:

1. **File size warning:** Add a warning dialog when selected file exceeds 10MB. Consider streaming/chunking for very large PGN databases.

2. **extendLine return value:** Have `extendLine` return the list of inserted move IDs. Currently the importer must call `getChildMoves` after `extendLine` to discover IDs for its dedup index.

## Acceptance Criteria

- [ ] Warning dialog for files > 10MB with option to proceed or cancel
- [ ] `extendLine` returns inserted move IDs
- [ ] PGN importer uses returned IDs instead of extra query

## Notes

Discovered during CT-3. Plan Step 11 and spec both reference these improvements.
