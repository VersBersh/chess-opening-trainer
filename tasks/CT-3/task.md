---
id: CT-3
title: PGN Import
depends: ['CT-0']
specs:
  - features/pgn-import.md
files:
  - src/lib/services/pgn_importer.dart
  - src/lib/screens/import_screen.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/repositories/review_repository.dart
  - src/lib/models/repertoire.dart
---
# CT-3: PGN Import

**Epic:** none
**Depends on:** CT-0

## Description

Bulk-load opening lines from PGN files into the repertoire. Parse PGN with variations and branches, map the PGN tree to `RepertoireMove` nodes, skip duplicate paths, and create review cards for new leaf nodes.

## Acceptance Criteria

- [ ] Parse PGN with variations/branches (using dartchess PGN support)
- [ ] Map PGN tree to `RepertoireMove` nodes
- [ ] Skip duplicate paths that already exist in the repertoire
- [ ] Create cards for new leaf nodes
- [ ] Import summary: lines added, duplicates skipped

## Notes

The `dartchess` package provides PGN parsing support. The importer should handle standard PGN with recursive annotation variations (RAVs). File picker integration may be needed for selecting PGN files on Android vs desktop.
