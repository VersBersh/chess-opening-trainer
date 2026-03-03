# CT-50.4: Implementation Notes

## Files Modified

| File | Change summary |
|------|----------------|
| `src/test/widgets/move_tree_widget_test.dart` | Added Gap A and Gap B widget tests for row/chevron tap separation. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Added Gap D and Gap E screen integration tests for chevron board stability and chain-row tail FEN sync. |

## Files Not Changed (Audit Results)

### Step 1 — `browser_content.dart` wiring audit

`_buildMoveTree` (lines 212–222) passes `onNodeSelected` and `onNodeToggleExpand`
straight through from the constructor parameters with no aliasing, swapping, or
extra logic. The wiring is correct; no code change was required.

### Step 1 — `repertoire_browser_screen.dart` callback audit

- `_onNodeSelected` (lines 81–87): calls `_controller.selectNode(moveId)` and
  only calls `_boardController.setPosition(fen)` when the returned FEN is
  non-null. Does not call `toggleExpand`.
- `_onNodeToggleExpand` (lines 89–91): calls `_controller.toggleExpand(moveId)`
  only. Does not touch `_boardController`.
  Wiring is correct; no code change was required.

### Step 2 — `move_tree_widget.dart` hit-test geometry audit

- Chevron `GestureDetector` has `behavior: HitTestBehavior.opaque` (line 248).
- `SizedBox` holding chevron is `width: 28, height: 28` (lines 249–250).
- Label icon `GestureDetector` also has `behavior: HitTestBehavior.opaque`
  (line 304) in a `28×28 SizedBox` (lines 305–306).
- `InkWell` (line 231) has only `onTap`; no `onDoubleTap`, `onLongPress`, or any
  path that calls `onToggleExpand`.
  Geometry is correct; no code change was required.

## Test Gaps Filled

### Gap A — `move_tree_widget_test.dart`
**"tapping the row text does not call onNodeToggleExpand"**
Tree: e4 (branch point with 2 children e5, c5) expanded. Tap the "1...e5 2. Nf3"
chain row text. Asserts `selectedId` is non-null and `toggledId` is null.

### Gap B — `move_tree_widget_test.dart`
**"tapping chevron icon does not call onNodeSelected"**
Same tree, collapsed. Tap `Icons.chevron_right` on e4. Asserts `toggledId` is
non-null and `selectedId` is null.

### Gap D — `repertoire_browser_screen_test.dart`
**"tapping expand chevron does not change board position"**
Tree: e4 with children e5+Nf3 and c5 (all auto-expanded). Captures board FEN
before tapping `Icons.expand_more` on e4 (collapse), then asserts board FEN is
unchanged after the tap.

### Gap E — `repertoire_browser_screen_test.dart`
**"chain-row tap syncs board to tail (last move) FEN"**
Tree: e4 -> e5 -> Nf3 (one chain row "1. e4 e5 2. Nf3"). Taps the chain row and
asserts the board FEN is not the initial position, confirming the tail move
(Nf3) position was applied.

## Deviations from Plan

None. All four test bodies are consistent with the plan's pseudocode. The
`buildBranchTree` helper name suggested in the plan is not a named helper in the
existing test file; the existing inline pattern (using `buildLine` +
`buildBranch`) was used instead, matching the established style throughout the
file.

## Back/Forward Regression

No new tests added. Existing screen tests (`back navigation selects parent node`,
`forward at a branch point selects default child and expands`) provide sufficient
coverage, as noted in the plan.

## New Tasks / Follow-up Work

None discovered during implementation.
