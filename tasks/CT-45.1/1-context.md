# CT-45.1: Context

## Relevant Files

- **`src/lib/widgets/move_tree_widget.dart`** — Contains `_MoveTreeNodeTile` (lines 145-294), the sole widget being restyled. All eight dimension values live here: row min-height, chevron hit area, chevron icon size, left base padding, indent-per-depth, non-chevron spacer width, label-icon hit area, and label-icon size. Also contains `VisibleNode`, `buildVisibleNodes`, and the parent `MoveTreeWidget` (all unchanged by this task).
- **`src/test/widgets/move_tree_widget_test.dart`** — Unit tests for `buildVisibleNodes` (unchanged) and widget tests for `MoveTreeWidget`. Two tests use hardcoded pixel offsets that depend on the current 48dp hit areas and must be updated: "tapping enlarged label icon area outside visual icon" (line 519, uses `Offset(0, -20)` relative to a 48x48 / 18px icon) and "tapping enlarged chevron area outside visual icon" (line 544, uses `Offset(0, -20)` relative to a 48x48 / 20px icon).
- **`features/repertoire-browser.md`** — Feature spec for the repertoire browser. The "Compact Rows" section (line 33) specifies ~28-32dp row height and correspondingly smaller touch targets, providing the design rationale for this task.

## Architecture

The move tree widget is a stateless display component. `MoveTreeWidget` receives a `RepertoireTreeCache`, expand/select state, and callbacks from a parent screen. It calls `buildVisibleNodes()` to flatten the tree into a `List<VisibleNode>`, then renders them via `ListView.builder`, delegating each row to `_MoveTreeNodeTile`.

`_MoveTreeNodeTile` is a single `StatelessWidget` that builds the following structure for each row:

```
Material (selected highlight)
  InkWell (tap handler)
    Padding (left indent = base + depth * perLevel, right = 8)
      ConstrainedBox (minHeight)
        Row
          [Chevron GestureDetector + SizedBox + Icon] or [Spacer SizedBox]
          Expanded Text.rich (move notation + optional label)
          [Label icon GestureDetector + SizedBox + Icon] (if onEditLabel)
          [Due count badge Container] (if dueCount > 0)
```

All eight values being changed are literal constants or references to `kMinInteractiveDimension` (48dp) within this single widget. There is no shared constants file, theme extension, or inherited widget involved -- all values are inline.

Key constraints:
- This is a pure styling change. No logic in `buildVisibleNodes`, `VisibleNode`, or any controller changes.
- The two "enlarged hit area" widget tests tap at pixel offsets that assume 48dp boxes. With 28dp boxes, a 20px offset from center would land outside the box (14px half-height), so these offsets must be reduced.
- Right padding (8dp) is explicitly unchanged.
- No files outside `move_tree_widget.dart` and `move_tree_widget_test.dart` are affected.
