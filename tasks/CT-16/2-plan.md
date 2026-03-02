# CT-16: Implementation Plan

## Goal

Add widget tests for both the wide (≥ 600px) and narrow (< 600px) layout paths in the drill screen and repertoire browser, ensuring both code paths render without errors and key interactive elements remain accessible.

## Steps

### Step 1: Add viewport size parameter to `buildTestApp` in `drill_screen_test.dart`

**File:** `src/test/screens/drill_screen_test.dart`

Add an optional `Size? viewportSize` parameter to `buildTestApp`. When provided, wrap the `MaterialApp.home` with a `MediaQuery` widget overriding the size. When null, leave existing behavior (default 800×600 test surface).

```dart
Widget buildTestApp({
  required FakeRepertoireRepository repertoireRepo,
  required FakeReviewRepository reviewRepo,
  DrillConfig config = _defaultConfig,
  Size? viewportSize,
}) {
  Widget home = DrillScreen(config: config);
  if (viewportSize != null) {
    home = MediaQuery(
      data: MediaQueryData(size: viewportSize),
      child: home,
    );
  }
  return ProviderScope(
    overrides: [...],
    child: MaterialApp(home: home),
  );
}
```

No dependencies.

### Step 2: Add viewport size parameter to `buildTestApp` in `repertoire_browser_screen_test.dart`

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

Add an optional `Size viewportSize` parameter with default `const Size(400, 800)`:

```dart
Widget buildTestApp(AppDatabase db, int repertoireId, {Size viewportSize = const Size(400, 800)}) {
  ...
  child: MediaQuery(
    data: MediaQueryData(size: viewportSize),
    child: RepertoireBrowserScreen(repertoireId: repertoireId),
  ),
}
```

No dependencies.

### Step 3: Add narrow-viewport test group to `drill_screen_test.dart`

**File:** `src/test/screens/drill_screen_test.dart`

Add a new `group('DrillScreen — narrow layout', ...)` at the end of `main()` with these tests (all use `viewportSize: const Size(400, 800)`):

1. **`renders board and status in column layout at narrow width`** — Pump with narrow viewport, pump through intro, verify `ChessboardWidget` and "Your turn" text render without overflow. **Branch-distinguishing assertion**: verify that no `Row` containing both the board and status exists (narrow uses `Column`), and verify that `TextButton` action bar buttons with text labels like "Add Line" do NOT exist (narrow drill has no action bar, only the board+status column).
2. **`line label appears above board in narrow layout`** — Build with labeled line, narrow viewport. Verify the line label widget (key `drill-line-label`) is present.
3. **`skip button works in narrow layout`** — Pump with narrow viewport, pump through intro, tap skip, verify session complete.
4. **`filter box renders in narrow layout (free practice)`** — Build with `isExtraPractice: true` and narrow viewport. Verify filter box (key `drill-filter-box`) renders.

Depends on Step 1.

### Step 4: Add explicit wide-viewport test group to `drill_screen_test.dart`

**File:** `src/test/screens/drill_screen_test.dart`

Add a new `group('DrillScreen — wide layout', ...)` with tests that explicitly set `viewportSize: const Size(900, 600)`:

1. **`renders board and status side by side in wide layout`** — Pump with wide viewport, pump through intro. Verify board and status render without overflow. **Branch-distinguishing assertion**: verify that the widget tree contains a `Row` with both the board and status/label widgets as descendants (confirming the wide side-by-side layout, not the narrow `Column` layout).
2. **`line label appears in side panel in wide layout`** — Build with labeled line and wide viewport. Verify label widget (key `drill-line-label`).
3. **`filter box renders in wide side panel (free practice)`** — Build with `isExtraPractice: true` and wide viewport. Verify filter box (key `drill-filter-box`).

Depends on Step 1.

### Step 5: Add wide-viewport test group to `repertoire_browser_screen_test.dart`

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

Add a new `group('RepertoireBrowserScreen — wide layout', ...)` with these tests (all use `viewportSize: const Size(900, 800)`):

1. **`renders board and tree side by side in wide layout`** — Seed repertoire, pump at wide viewport. Assert `ChessboardWidget` and `MoveTreeWidget` both render without overflow. **Branch-distinguishing assertion**: assert that `IconButton` with tooltip "Add Line" exists (compact action bar unique to wide layout) AND that `find.widgetWithText(TextButton, 'Add Line')` finds nothing (text-labeled buttons are unique to narrow layout).
2. **`compact action bar shows icon buttons in wide layout`** — Seed repertoire, pump wide. Assert `IconButton` widgets with tooltips "Add Line", "Import", "Label", "Stats" exist. For the delete button, assert tooltip is "Delete Branch" when no selection. Assert `TextButton` widgets with text labels "Add Line", "Label", "Stats" do NOT exist (confirms compact branch).
3. **`action bar buttons have correct enabled/disabled state in wide layout`** — Seed with moves and cards (`createCards: true`), pump wide. Verify: Add Line icon always tappable; Label icon disabled when no selection; select a leaf node, verify Stats and Delete icons become enabled and Delete tooltip changes to "Delete".
4. **`board flip works in wide layout`** — Seed, pump wide, tap flip icon, verify orientation changes.
5. **`node selection updates board in wide layout`** — Seed with moves, pump wide, tap a node, verify board FEN changes.

Depends on Step 2.

## Risks / Open Questions

1. **Flutter default test surface**: Default is 800×600 logical pixels. Drill screen tests currently exercise wide path by accident. Making this explicit with `viewportSize` makes tests resilient to future Flutter changes.

2. **LayoutBuilder constraints**: Wide layout uses `LayoutBuilder` to size the board. At `Size(900, 600)` the board is clamped to `min(600, 900*0.6)=540` for drill and `min(600, 900*0.5)=450` for repertoire browser. Should fit without overflow but may need viewport dimension tuning if tests fail.

3. **Compact action bar finders**: In wide mode, action buttons are `IconButton` with tooltips, not `TextButton` with text labels. Tests must use `find.byTooltip('Add Line')` or `find.byIcon(Icons.add)` rather than `find.widgetWithText(TextButton, 'Add Line')`.

4. **Test duplication**: Plan adds new test groups rather than parameterizing across viewports. Keeps tests readable. Some test logic is similar between narrow/wide groups.
