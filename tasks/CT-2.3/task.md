---
id: CT-2.3
title: Position Labeling
epic: CT-2
depends: ['CT-2.1']
specs:
  - features/line-management.md
  - taxonomy.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/models/repertoire.dart
---
# CT-2.3: Position Labeling

**Epic:** CT-2
**Depends on:** CT-2.1

## Description

Add the ability to attach, edit, and remove labels on any move node in the repertoire tree. Labels are short name segments (e.g., "Sicilian", "Najdorf") used to build display names and define variation subtrees for focus mode.

## Acceptance Criteria

- [ ] Label input on any node (accessible from browse or edit mode)
- [ ] Aggregate display name preview while entering/browsing
- [ ] Label impact warning when node has labeled descendants
- [ ] Transposition conflict warning (same FEN, different labels)

## Notes

Labels are organizational only — they do not create cards and do not affect the tree structure. The display name is always derived, never stored.
