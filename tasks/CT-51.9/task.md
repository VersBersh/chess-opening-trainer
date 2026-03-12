---
id: CT-51.9
title: Board shifts from centered to left-aligned after first move (Add Line)
epic: CT-51
depends: []
specs:
  - features/add-line.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/widgets/chessboard_widget.dart
  - src/lib/theme/spacing.dart
---
# CT-51.9: Board shifts from centered to left-aligned after first move (Add Line)

**Epic:** CT-51
**Depends on:** none

## Description

In the Add Line screen, the chessboard is correctly centered on initial load. After the user plays the first move, the board shifts to become left-aligned, touching the left edge of the window. Subsequent moves do not cause further shifts — the misalignment is introduced on the first move and persists.

This violates the board-layout-consistency contract. The board's horizontal position should remain stable regardless of moves played.

## Reproduction

1. Open the Add Line screen (any repertoire, from the initial position)
2. Observe the board is centered horizontally
3. Play any legal move (e.g. 1. e4)
4. Observe the board snaps to the left edge of the window

## Current Layout Chain

The board's centering relies on this widget hierarchy in `_buildContent` (add_line_screen.dart:392-459):

```
Column (default crossAxisAlignment: center)
  [conditional banner]
  SizedBox(height: kBoardFrameTopGap)
  ConstrainedBox(maxHeight: kMaxBoardSize=300)
    AspectRatio(1)
      ChessboardWidget
        LayoutBuilder
          Chessboard(size: min(maxWidth, maxHeight))
  Expanded
    SingleChildScrollView
      Column(crossAxisAlignment: start)
        MovePillsWidget
        ...
```

The outer `Column` uses `CrossAxisAlignment.center` (default), which should center the 300x300 board within the wider screen. The board's constraints (`ConstrainedBox(maxHeight: 300) -> AspectRatio(1)`) should produce a 300x300 widget regardless of state. Static analysis confirms the layout structure is identical before and after the first move.

## Investigation Notes

### What changes on first move

- `AddLineController.onBoardMove()` updates state: pills go from `[]` to `[1 pill]`, `focusedPillIndex` from `null` to `0`, FEN updates
- Two `setState` calls fire: one in `_onBoardMove` (line 132), one in `_onControllerChanged` (line 126)
- `MovePillsWidget` switches from an empty-state placeholder (`SizedBox(height: 48)` with centered text) to a `Padding > Wrap` with one pill
- The `aggregateDisplayName` does NOT change (new buffered moves have no label), so the conditional banner does not appear/disappear

### What was ruled out

- **Banner toggle**: the conditional `if (displayName.isNotEmpty)` banner above the board does not appear/disappear on the first move in the common case (empty repertoire, no starting move). Widget indices in the Column stay stable.
- **ConstrainedBox / AspectRatio sizing**: static analysis confirms the board should always size to 300x300 (when screen > 300px wide and > 308px tall). The `ConstrainedBox(maxHeight: 300)` + `AspectRatio(1)` chain is deterministic.
- **ChessboardWidget LayoutBuilder**: constraints from AspectRatio are tight 300x300 regardless of board state. `size = min(300, 300) = 300`.
- **chessground Chessboard render**: the widget renders `SizedBox.square(dimension: 300)` inside a `Stack`. No border, no brightness filter in use.
- **Expanded / ScrollView interaction**: the `Expanded > SingleChildScrollView` area below the board has an independent layout that cannot affect the board's horizontal position in the outer Column.

### Possible root causes to investigate

1. **Flutter LayoutBuilder rebuild timing**: after `setState`, the LayoutBuilder's builder function may run with stale or different constraints during a transitional layout pass
2. **Column cross-axis constraint propagation**: verify the actual `BoxConstraints` the ConstrainedBox receives before vs after the first move (add debug logging or use DevTools)
3. **chessground Chessboard `didUpdateWidget`**: the FEN change triggers piece animation setup in `didUpdateWidget` (board.dart:487-528), which may interact with the sizing in an unexpected way on Windows
4. **Widget tree reconciliation**: if the banner conditionally appears (when starting from a labeled move), the Column children shift indices, causing the ChessboardWidget State to be recreated — add `Key` widgets to prevent this

## Acceptance Criteria

- [ ] The board remains horizontally centered after playing the first move
- [ ] The board remains horizontally centered after playing 5+ moves
- [ ] Add a widget test that verifies the board's horizontal center position is stable before and after a move (extend `board_layout_test.dart` or add to `add_line_screen_test.dart`)
- [ ] If the root cause is the conditional banner shifting widget indices, add `Key` annotations to the Column's children to ensure stable reconciliation

## Notes

The board-layout-consistency test (`test/layout/board_layout_test.dart`) currently checks board SIZE but not POSITION. Extending it to assert horizontal centering before and after a move would catch this class of regression.
