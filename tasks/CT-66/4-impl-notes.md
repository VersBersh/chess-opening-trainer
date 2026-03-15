# CT-66: Implementation Notes

## Files modified

| File | Summary |
|------|---------|
| `src/lib/screens/add_line_screen.dart` | Added keyboard detection and `AnimatedSize`-based board/banner collapse in `_buildNarrowContent` when the label editor is active and the keyboard is open. |

## Changes detail

In `_buildNarrowContent`:

1. **Keyboard detection** (3 new lines at top of method): reads `MediaQuery.of(context).viewInsets.bottom` to determine `isKeyboardOpen`, then computes `shouldCollapseBoard = isKeyboardOpen && _isLabelEditorVisible`.

2. **Display name banner collapse**: wrapped the existing `Container` banner in `AnimatedSize` (200ms, easeInOut, hardEdge clip) + `SizedBox` with `height: shouldCollapseBoard ? 0 : null`. The `if (displayName.isNotEmpty)` guard is preserved.

3. **Chessboard collapse**: wrapped the existing `Padding > ConstrainedBox > AspectRatio > ChessboardWidget` in `AnimatedSize` + `SizedBox` with `key: ValueKey('add-line-board-container')` and the same conditional height. The board widget stays in the tree (clipped, not removed), preserving controller state.

## Deviations from plan

None. The implementation matches the plan exactly. Step 2 (verify wide layout unaffected) was confirmed by inspection -- `_buildWideContent` has no references to keyboard state or `AnimatedSize`.

## Follow-up work

- The display name banner is currently rendered above the board in `_buildNarrowContent`, which conflicts with the feature spec (spec says only the static app bar may appear above the board). Moving the banner below the board is a separate task, as noted in the plan's risks section.
