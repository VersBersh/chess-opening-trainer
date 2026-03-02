# CT-11.7: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/screens/add_line_screen.dart` | Replaced parity mismatch dialog with inline warning widget. Added `_parityWarning` state field, `_buildParityWarning()` widget builder, `_onFlipAndConfirm()` and `_onDismissParityWarning()` handlers. Deleted `_showParityWarningDialog()`. Updated `_onBoardMove`, `_onTakeBack`, and `_onFlipBoard` to clear the warning on relevant actions. |
| `src/test/screens/add_line_screen_test.dart` | Added 6 widget tests for inline parity warning: shows inline warning (not dialog), flip-and-confirm persists, dismissible via close button, auto-dismiss on new move, no warning when parity matches, manual board flip clears warning. |

## Files Created

| File | Summary |
|------|---------|
| `tasks/CT-11.7/4-impl-notes.md` | This file. |

## Deviations from Plan

None from the initial implementation. During code review, three fixes were applied:
1. **Pill tap clearing warning** — `_onPillTapped` now clears `_parityWarning` to prevent stale warnings when navigating pills.
2. **TextButton theming** — "Flip and confirm" button now uses `onErrorContainer` foreground color for consistency.
3. **Test helper extraction** — Extracted `triggerParityMismatchWarning()` helper to reduce test duplication. Added a 7th test for pill tap clearing the warning.

## Follow-up Work

- `AddLineScreen` is now 430+ lines. Design review flagged this as a file size smell. See `6-discovered-tasks.md`.
