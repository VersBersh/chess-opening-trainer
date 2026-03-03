# CT-45.1: Implementation Notes

## Files Modified

- **`src/lib/widgets/move_tree_widget.dart`** — Changed 8 dimension values in `_MoveTreeNodeTile`:
  - Row min height: `kMinInteractiveDimension` (48) → `28`
  - Chevron hit area: `kMinInteractiveDimension` × `kMinInteractiveDimension` → `28` × `28`
  - Chevron icon size: `20` → `16`
  - Left base padding: `16.0` → `8.0`
  - Indent per depth: `24.0` → `20.0`
  - Non-chevron spacer: `kMinInteractiveDimension` → `28`
  - Label icon hit area: `kMinInteractiveDimension` × `kMinInteractiveDimension` → `28` × `28`
  - Label icon size: `18` → `14`

- **`src/test/widgets/move_tree_widget_test.dart`** — Updated 2 tests:
  - "tapping enlarged label icon area" — offset `Offset(0, -20)` → `Offset(0, -10)`, comments updated
  - "tapping enlarged chevron area" — offset `Offset(0, -20)` → `Offset(0, -10)`, comments updated

## Deviations from Plan

- Used `Offset(0, -10)` per plan revision (plan originally had `-12`, revised to `-10` after review).

## New Tasks / Follow-up Work

None discovered.
