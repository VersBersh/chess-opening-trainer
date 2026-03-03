# CT-50.4: Plan

## Goal

Verify, clarify, and test the interaction contract that separates tree-row
selection from subtree expand/collapse. The implementation-level separation
already exists in `move_tree_widget.dart`; the work is to confirm that all
layers are correctly wired, that the spec-mandated rules hold under test, and
that there are no gaps in the test coverage for the stated acceptance criteria.

---

## Context: What is Already in the Code

Before listing steps it is important to understand that the structural
separation is already in place:

- `_MoveTreeNodeTile.build` (move_tree_widget.dart lines 231–262) wraps the
  entire row in `InkWell(onTap: onTap)` for selection. The chevron is a nested
  `GestureDetector(onTap: onToggleExpand, behavior: HitTestBehavior.opaque)`
  inside a `28×28 SizedBox`. Because `HitTestBehavior.opaque` consumes hits
  within the SizedBox region, chevron taps are not forwarded to the InkWell.
  The label icon uses the same pattern.
- `MoveTreeWidget.build` (lines 183–186) supplies `onTap` as
  `() => onNodeSelected(vn.lastMove.id)` and `onToggleExpand` as
  `() => onNodeToggleExpand(vn.lastMove.id)`. Both use the tail move ID,
  consistent with the spec.
- `BrowserContent._buildMoveTree` (browser_content.dart lines 213–222) passes
  `onNodeSelected` and `onNodeToggleExpand` straight through from the
  constructor — no logic added here.
- `RepertoireBrowserScreen._onNodeSelected` (screen lines 81–87) calls
  `_controller.selectNode(moveId)` and syncs the board with the returned FEN.
  `_onNodeToggleExpand` (line 89–91) calls `_controller.toggleExpand(moveId)`
  only — it does not touch the board.

The spec requirement "row taps never toggle expansion; chevron-only action" is
therefore already mechanically enforced. CT-50.4 must:

1. Confirm the wiring is correct end-to-end (no accidental coupling introduced
   by `BrowserContent`).
2. Fill the specific test gaps called out by the review.
3. Document any edge cases (chain-row tail, back/forward regression).

---

## Steps

### Step 1 — Audit the full callback wiring path

File: `src/lib/widgets/browser_content.dart`

Read `_buildMoveTree` (lines 213–222) and confirm:
- `onNodeSelected` is wired to the `onNodeSelected` constructor parameter
  without modification.
- `onNodeToggleExpand` is wired to the `onNodeToggleExpand` constructor
  parameter without modification.
- Neither callback is swapped or aliased.

If the wiring is correct (expected: yes), no code change is needed here.
Document the result in 4-impl-notes.md.

File: `src/lib/screens/repertoire_browser_screen.dart`

Confirm in `_onNodeSelected` (lines 81–87) that:
- `_controller.selectNode(moveId)` is called, returning a FEN.
- `_boardController.setPosition(fen)` is called only when FEN is non-null.
- `_onNodeToggleExpand` (lines 89–91) calls `_controller.toggleExpand(moveId)`
  and does NOT call `_boardController.setPosition`.

Again, this is a read audit; no code change expected.

### Step 2 — Audit the `_MoveTreeNodeTile` hit-test geometry

File: `src/lib/widgets/move_tree_widget.dart`, lines 244–264

Verify:
- Chevron `GestureDetector` has `behavior: HitTestBehavior.opaque`.
- The `SizedBox` holding the chevron is `width: 28, height: 28`.
- The same `HitTestBehavior.opaque` applies to the label icon.
- Row `InkWell` has no `onDoubleTap`, no `onLongPress`, and no `onTap` path
  that calls `onToggleExpand`.

If any of the above diverges from what is stated here, that divergence IS the
code change to make.

### Step 3 — Write missing widget tests in `move_tree_widget_test.dart`

File: `src/test/widgets/move_tree_widget_test.dart`

**Gap A — Row tap does not call `onNodeToggleExpand`.**

Add a test modelled after the existing `tapping the row itself does not trigger
onEditLabel` test:

```dart
testWidgets(
    'tapping the row text does not call onNodeToggleExpand', (tester) async {
  int? toggledId;
  int? selectedId;
  // Build a branch tree so chevron is shown (e4 has two children: e5, c5).
  // Tap the e5 row text — should fire onNodeSelected, not onNodeToggleExpand.
  ...
  await tester.tap(find.text(...)); // tap the row text, not the chevron
  expect(selectedId, isNotNull);
  expect(toggledId, isNull);
});
```

**Gap B — Chevron tap does not call `onNodeSelected`.**

Add a test tapping `find.byIcon(Icons.chevron_right)` (or `expand_more`) and
asserting `selectedId == null`:

```dart
testWidgets(
    'tapping chevron icon does not call onNodeSelected', (tester) async {
  int? toggledId;
  int? selectedId;
  ...
  await tester.tap(find.byIcon(Icons.expand_more));
  expect(toggledId, isNotNull);
  expect(selectedId, isNull);
});
```

Follow the exact test helper pattern used in the existing widget tests
(e.g. `buildLine`, `buildBranchTree` helpers).

### Step 4 — Write missing screen integration tests in `repertoire_browser_screen_test.dart`

File: `src/test/screens/repertoire_browser_screen_test.dart`

**Gap D — Chevron tap does not change board position.**

Add a test that captures the board FEN before and after a chevron tap and
asserts they are equal:

```dart
testWidgets(
    'tapping expand chevron does not change board position', (tester) async {
  // Seed: e4 with two children (e5, c5) so chevron appears.
  ...
  await tester.pumpAndSettle();
  final boardBefore = /* capture current board FEN */;

  await tester.tap(find.byIcon(Icons.expand_more).first);
  await tester.pump();

  final boardAfter = /* capture current board FEN */;
  expect(boardAfter, boardBefore,
      reason: 'Expand/collapse must not alter board position');
});
```

**Gap E — Chain-row tap syncs board to tail FEN, not initial FEN.**

Strengthen the existing chain-row test or add a new one that verifies the board
is at the deepest move's position:

```dart
testWidgets(
    'chain-row tap syncs board to tail (last move) FEN', (tester) async {
  // Seed: e4 -> e5 -> Nf3, all single-child -> one chain row.
  ...
  await tester.tap(find.text('1. e4 e5 2. Nf3'));
  await tester.pump();
  // Board should not be at initial FEN.
  expect(board.fen, isNot(kInitialFEN));
});
```

Follow the test seeding and board-capture pattern from existing tests in the
file (e.g. the `selecting a node updates the board position` test).

### Step 5 — Confirm outcome

After completing Steps 1–4, document in `4-impl-notes.md`:

a. Whether any production code was changed (expected: none), or the specific
   divergence found and fixed.
b. Which test gaps were filled (Gaps A, B, D, E).
c. Confirmation that back/forward tests still pass (existing coverage is
   sufficient — no new tests needed).

---

## Non-Goals

- No change to tree data model.
- No changes to branch scoring, cards, or repository access.
- No compile/test execution as part of this planning task set.

---

## Risks

- **Review issue #1 (plan abstraction):** The original plan did not name
  concrete target files or actual code locations. This revised plan specifies
  exact files, line numbers, and expected test bodies. If the code has diverged
  from what was read during planning, line numbers will need re-checking.

- **Review issue #2 (browser_content.dart missing):** `browser_content.dart`
  is now covered in Step 1. The wiring audit confirms it is a pass-through
  layer that adds no logic of its own.

- **Review issue #3 (no test updates):** Steps 3–4 now include explicit test
  bodies for: row-only select does not expand (Gap A), chevron-only expand does
  not select (Gap B), board stability under expand/collapse (Gap D), and
  chain-row tail board sync (Gap E). Back/forward regression is already covered
  by existing tests.

- **Accidental double-fire risk:** The chevron `GestureDetector` sits inside an
  `InkWell`. Flutter's gesture arena resolves this in favor of the inner
  `GestureDetector` due to `HitTestBehavior.opaque`. If Flutter changes this
  behavior in a future release, the tests added in Steps 3–4 will catch the
  regression.

- **Dense row layout:** The 28dp `minHeight` ConstrainedBox means the chevron
  28×28 SizedBox can overlap adjacent rows on very small displays. This is a
  pre-existing constraint and is unchanged by this task.

- **Controller tests note:** `repertoire_browser_controller_test.dart` already
  has `selectNode` and `toggleExpand` unit tests. No new controller tests are
  required; the widget and screen tests verify end-to-end behavior.
