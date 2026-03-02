---
id: CT-2.7
title: Undo Snackbar After Line Confirm
epic: CT-2
depends: ['CT-2.2']
specs:
  - features/line-management.md
files:
  - src/lib/screens/add_line_screen.dart
---
# CT-2.7: Undo Snackbar After Line Confirm

**Epic:** CT-2
**Depends on:** CT-2.2

## Description

Show a transient undo snackbar (~8 seconds) after confirming a new line or line extension. On tap, reverse the persisted changes (delete inserted moves, restore old card SR values for extensions). Requires capturing pre-confirm state.

## Acceptance Criteria

- [ ] Undo snackbar appears after confirming a new line
- [ ] Tapping undo reverses all persisted changes
- [ ] Snackbar dismisses after ~8 seconds
- [ ] After dismissal, changes are final
- [ ] Works for both new lines and extensions

## Notes

Discovered during CT-2.2. The spec (`line-management.md`, "Undo Line Extension" section) requires this feature. Deferred to keep the confirm flow simple for v1.
