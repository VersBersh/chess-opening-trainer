---
id: CT-37
title: "Improve parity mismatch warning"
depends: []
files:
  - src/lib/services/line_entry_engine.dart
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
---
# CT-37: Improve parity mismatch warning

**Epic:** none
**Depends on:** none

## Description

The current "parity mismatch" warning is not user-friendly. Replace it with plain language that an average player can understand: "Lines for black should end on a black move" (and vice versa for white).

Also tone down the styling — the current dark red is too aggressive. Use a subtler, less alarming warning color.

## Acceptance Criteria

- [ ] Warning message reads something like "Lines for black should end on a black move" (or equivalent for white)
- [ ] No technical jargon like "parity mismatch" is shown to the user
- [ ] Warning styling uses a subtler color instead of dark red
- [ ] Warning still clearly communicates the issue without being alarming

## Notes

Parity validation is in `line_entry_engine.dart` (`validateParity()` around lines 193-204). The `ParityMismatch` result type is defined around lines 50-54. The warning is displayed in `add_line_screen.dart` around lines 149-152.
