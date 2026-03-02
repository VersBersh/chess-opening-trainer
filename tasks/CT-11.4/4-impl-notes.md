# CT-11.4: Remove X on pills -- Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/widgets/move_pills_widget.dart` | Removed `onDeleteLast` param/field from `MovePillsWidget`; removed `onDelete`, `isLast`, `showDelete` from `_MovePill`; removed delete icon (`Icons.close`) GestureDetector block; simplified pill to a single `GestureDetector` wrapping a `Container` with symmetric padding; cleaned up comments. |
| `src/lib/screens/add_line_screen.dart` | Removed `onDeleteLast:` argument from `MovePillsWidget` constructor call in `_buildContent`. |
| `src/test/widgets/move_pills_widget_test.dart` | Removed `onDeleteLast` parameter from `buildTestApp` helper and from `MovePillsWidget` constructor call; deleted four delete-icon tests; added one negative test (`'pills do not render a delete icon'`). |

## Deviations from Plan

1. **Simplified pill structure beyond plan scope:** The plan described keeping the `Row` and inner `GestureDetector` structure, just removing the delete icon child. Instead, since the `Row` and separate tap targets were only needed to isolate the delete icon tap from the SAN text tap, I simplified the entire pill to a single `GestureDetector` wrapping the `Container` directly (no `Row` needed). This is cleaner and removes unnecessary nesting now that there is only one tap target. The `Container` receives `padding` directly instead of an inner `Padding` widget.

## Follow-up Work

None discovered. The Take Back button in `_buildActionBar` continues to provide delete-last-move functionality independently. No other consumers of the removed API exist.
