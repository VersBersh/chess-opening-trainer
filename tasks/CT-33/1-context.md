# CT-33: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/widgets/move_tree_widget.dart` | Contains `_MoveTreeNodeTile` with the GestureDetector-wrapped label icon (lines 241-258) and chevron (lines 188-202). Primary file to modify. |
| `src/lib/screens/repertoire_browser_screen.dart` | Screen that hosts `BrowserContent` and wires `onEditLabelForMove` to the tree widget. |
| `src/lib/widgets/browser_content.dart` | Responsive layout composing board, action bar, inline label editor, and `MoveTreeWidget`. |
| `src/lib/widgets/inline_label_editor.dart` | Inline label editor shown when the label icon is tapped. |
| `src/test/widgets/move_tree_widget_test.dart` | Widget tests for `MoveTreeWidget`, including 6 tests for the label icon. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` model — tree walking, display names, depth computation. |
| `src/lib/theme/spacing.dart` | Shared spacing constants (`kBannerGap`). Tap target constant could live here. |

## Architecture

The move tree rendering subsystem:

1. **`RepertoireBrowserScreen`** (ConsumerStatefulWidget) owns the controller and all event handlers. Delegates layout to `BrowserContent`.

2. **`BrowserContent`** handles responsive layout, composing chessboard, controls, action bar, optional inline label editor, and `MoveTreeWidget`.

3. **`MoveTreeWidget`** (StatelessWidget) receives tree cache, expand/selection state, and callbacks. Calls `buildVisibleNodes()` to flatten the tree, renders a `ListView.builder` of `_MoveTreeNodeTile`.

4. **`_MoveTreeNodeTile`** — per-row widget: `Material` > `InkWell` > `Padding` > `Row` containing:
   - **Chevron**: `GestureDetector` wrapping 20px `Icon` with 4px right padding (~28dp tap area)
   - **Move notation**: `Expanded` > `Text.rich` (SAN + optional label text)
   - **Label icon**: `GestureDetector` wrapping 18px `Icon` with 4px horizontal padding (~26dp tap area)
   - **Due count badge**: pill-styled `Container`

### Key Constraints

- **Indentation**: `left: 16.0 + depth * 24.0`. At depth 5 = 136px, leaving ~224px on a 360px phone.
- **Label icon tap area**: ~26×26dp, well below Material's 48×48dp minimum.
- **GestureDetector inside InkWell**: `HitTestBehavior.opaque` absorbs hits within bounds, but the small bounds mean near-miss taps trigger the InkWell (row selection) instead.
- **Chevron has the same pattern**: 20px icon, ~28dp tap area.
