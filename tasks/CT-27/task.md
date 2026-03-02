---
id: CT-27
title: Inject Clock Abstraction
depends: ['CT-5']
files:
  - src/lib/screens/drill_screen.dart
---
# CT-27: Inject Clock Abstraction

**Epic:** none
**Depends on:** CT-5

## Description

`DrillController` uses `DateTime.now()` directly for session start time and summary duration. `_formatNextDue` also calls `DateTime.now()`. Inject a clock abstraction (e.g., `DateTime Function()` or `package:clock`) to enable deterministic duration testing.

## Acceptance Criteria

- [ ] Clock abstraction injected into DrillController
- [ ] All `DateTime.now()` calls go through the abstraction
- [ ] Tests can provide a fixed or advancing clock
- [ ] Existing behavior unchanged with default clock

## Notes

Discovered during CT-5 design review. Flagged as Minor temporal coupling issue.
