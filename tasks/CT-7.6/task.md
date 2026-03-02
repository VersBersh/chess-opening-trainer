---
id: CT-7.6
title: Move Pills Accessibility Semantics
epic: CT-7
depends: ['CT-7.1']
specs:
  - features/add-line.md
files:
  - src/lib/widgets/move_pills_widget.dart
---
# CT-7.6: Move Pills Accessibility Semantics

**Epic:** CT-7
**Depends on:** CT-7.1

## Description

Wrap each pill in a `Semantics` widget with descriptive labels (e.g., "Move 3: Nf3, saved") for screen reader support. Add semantic labels to interactive actions as well.

## Acceptance Criteria

- [ ] Each pill wrapped in `Semantics` with descriptive label
- [ ] Labels include move number, SAN notation, and status (saved/new)
- [ ] Interactive elements (tap, etc.) have semantic descriptions
- [ ] Screen reader can navigate pills meaningfully

## Notes

Discovered during CT-7.1. Both code reviews flagged the absence of `Semantics` wrappers. Should be addressed before release.
