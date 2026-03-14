# CT-52 Implementation Plan

## Goal

Make the chessboard nearly edge-to-edge on mobile by replacing the hard-coded `kMaxBoardSize = 300` cap with responsive sizing based on available screen width (minus a small margin), while keeping all board screens consistent at every breakpoint — narrow and wide — and keeping desktop layouts sane.

## Steps

### 1. Update specs

**Files:** `architecture/board-layout-consistency.md`, `design/ui-guidelines.md`

**Changes to `architecture/board-layout-consistency.md`:**
- Under "Board Frame", change "Use one shared horizontal inset for the board container across screens" to specify that the shared horizontal inset should be minimal on mobile (e.g. 4dp per side) so the board is as large as possible.
- Relax the "Boards must not render flush to the screen edge" constraint: a small inset (4dp) is acceptable and intentional on mobile.
- Add a note that on narrow layouts the board width should be `screenWidth - 2 * kBoardHorizontalInset`, capped by `kMaxBoardSize`.
- Add a section on wide-layout consistency: all screens must use the same shared sizing function at wide breakpoints too, not independent ad-hoc formulas. The board size on a wide layout is computed by the same `boardSizeForConstraints` helper so that navigating between screens at a given viewport never changes the board dimensions.

**Changes to `design/ui-guidelines.md`:**
- Under "Spacing", add a "Board padding" subsection:
  - On mobile, horizontal board padding should be minimal (near-zero, e.g. 4dp per side) to maximise board size.
  - On desktop/wide layouts, the board may have more generous padding or be sized as a fraction of available space with a sensible maximum, but must use the shared sizing helper.

**Dependencies:** None. Do this first so the implementation has a clear target.

### 2. Add responsive board sizing constants and helpers to `spacing.dart`

**File:** `src/lib/theme/spacing.dart`

**Changes:**
- Add a new constant `kBoardHorizontalInset = 4.0` — the minimal horizontal margin on each side of the board on mobile.
- Add a corresponding `EdgeInsets` constant: `kBoardHorizontalInsets = EdgeInsets.symmetric(horizontal: kBoardHorizontalInset)`.
- Increase `kMaxBoardSize` from `300` to `600`. This is now a desktop/tablet safety cap to prevent absurdly large boards on wide screens. On mobile, the board will be constrained by `screenWidth - 2 * kBoardHorizontalInset` which is smaller than 600.
- Add a doc comment explaining the relationship: on narrow screens the board is `screenWidth - 2 * kBoardHorizontalInset`; `kMaxBoardSize` only kicks in on wide viewports.
- Add a **narrow-layout helper:** `double boardSizeForWidth(double availableWidth)` that returns `(availableWidth - 2 * kBoardHorizontalInset).clamp(0.0, kMaxBoardSize)`.
- Add a **wide-layout helper:** `double boardSizeForConstraints(BoxConstraints constraints, {double widthFraction = 0.5})` that returns `min(constraints.maxHeight, constraints.maxWidth * widthFraction).clamp(0.0, kMaxBoardSize)`. This centralises the wide-layout board-size calculation so all screens use the same formula and remain consistent with each other. The height clamp ensures the board never exceeds available vertical space.
- Add a **narrow-layout helper with height guard:** `double boardSizeForNarrow(double availableWidth, double availableHeight, {double maxHeightFraction = 1.0})` that returns `(availableWidth - 2 * kBoardHorizontalInset).clamp(0.0, min(kMaxBoardSize, availableHeight * maxHeightFraction))`. This allows callers like Browser to apply a secondary height clamp without re-inventing the formula. Screens that do not need a height clamp can either call `boardSizeForWidth` directly or pass `maxHeightFraction: 1.0` (effectively no height constraint).

**Dependencies:** None.

### 3. Update Add Line screen — narrow layout

**File:** `src/lib/screens/add_line_screen.dart`

**Changes:**
- In `_buildContent`, obtain `screenWidth` from `MediaQuery.of(context).size.width`.
- Replace `const BoxConstraints(maxHeight: kMaxBoardSize)` with `BoxConstraints(maxHeight: boardSizeForWidth(screenWidth))`.
- Wrap the `ConstrainedBox` + `AspectRatio` board in a `Padding` with `kBoardHorizontalInsets` so the board has 4dp margin on each side.
- Add Line currently has no wide-layout branch. Add one: check `isWide = screenWidth >= 600`, and when wide, use a `LayoutBuilder` + `boardSizeForConstraints(constraints)` to size the board, adopting the same Row-based side-panel pattern used by Drill and Browser. This ensures wide-viewport consistency across all screens. The right panel can hold the move pills and action buttons already present below the board in the narrow layout.

**Dependencies:** Step 2.

### 4. Update Drill screen — narrow and wide layouts

**File:** `src/lib/screens/drill_screen.dart`

**Changes (narrow branch, line ~273):**
- Obtain `screenWidth` from `MediaQuery`.
- Replace `const BoxConstraints(maxHeight: kMaxBoardSize)` with `BoxConstraints(maxHeight: boardSizeForWidth(screenWidth))`.
- Wrap the board `ConstrainedBox` in `Padding(padding: kBoardHorizontalInsets)` for the 4dp side margins.

**Changes (wide branch, line ~240):**
- Replace the ad-hoc `constraints.maxWidth * 0.6` formula with `boardSizeForConstraints(constraints, widthFraction: 0.6)`. This applies the shared `kMaxBoardSize` cap and uses the height-aware formula, preventing absurdly large boards on ultrawide monitors (e.g. 1920px * 0.6 = 1152px would now be clamped to 600).

**Dependencies:** Step 2.

### 5. Update Browser content — narrow and wide layouts

**File:** `src/lib/widgets/browser_content.dart`

**Changes (narrow branch, `_buildNarrow`):**
- Replace `(screenHeight * 0.4).clamp(0.0, kMaxBoardSize.toDouble())` with `boardSizeForNarrow(screenWidth, screenHeight, maxHeightFraction: 0.4)` (using `MediaQuery` for both dimensions). This switches the primary driver to width-based sizing while preserving the existing height guard — the board will never exceed 40% of screen height, which prevents it from crowding out the controls and move tree on short/landscape viewports. The `boardSizeForNarrow` helper applies both constraints in a single call.
- Wrap the board `ConstrainedBox` in `Padding(padding: kBoardHorizontalInsets)`.

**Changes (wide branch, `_buildWide`):**
- Replace the ad-hoc `constraints.maxHeight.clamp(0.0, constraints.maxWidth * 0.5)` formula with `boardSizeForConstraints(constraints, widthFraction: 0.5)`. This applies the shared `kMaxBoardSize` cap and uses the centralised formula.

**Dependencies:** Step 2.

### 6. Update the board layout test

**File:** `src/test/layout/board_layout_test.dart`

**Changes to the existing test:**
- The existing test at `_phoneSize = Size(390, 844)` asserts that all four screens produce the **same** board size (equality assertion against the AddLine board). This assertion structure is correct and must be kept — it verifies the consistency contract, not a specific pixel value.
- With the new sizing, the board will naturally resolve to a different (larger) size, but the equality assertion will still pass as long as all screens use the shared helper. Do **not** replace the equality assertion with a hard-coded `382x382` check.
- If an absolute-size sanity check is desired, derive the expected value from the shared constants: `expect(referenceSize.width, equals(boardSizeForWidth(_phoneSize.width)))`. This ties the assertion to the source of truth rather than duplicating a magic number.

**New wide-viewport test:**
- Add a second test case at a wider viewport (e.g. `Size(1024, 768)`) that pumps all four screens (Add Line now has a wide branch per Step 3) and asserts board-size equality across screens. This verifies the wide-layout consistency fix from issue 1. Since all screens use `boardSizeForConstraints`, the boards should be identical.
- Only add this test after all four screens have wide-layout branches using the shared helper.

**Dependencies:** Steps 3, 4, 5 (test validates the implementation).

### 7. Manual verification

Not a code step, but verify:
- On a phone-sized emulator (390px wide): the board is ~382px and nearly touches the edges.
- On a tablet/desktop (>600px wide): the board does not stretch to absurd widths; it is capped at 600 and all screens show the same size.
- All four board screens show identical board dimensions at any given viewport width, in both narrow and wide breakpoints.
- The line-label area, move pills, and action buttons below the board still lay out correctly with the larger board.
- On a short phone (e.g. iPhone SE 375x667): verify vertical space is not too tight. The board would be ~367px, leaving ~300dp for everything else. If this is problematic, the `boardSizeForNarrow` helper can accept a `maxHeightFraction` to add a secondary height clamp for all screens (not just Browser).

## Risks / Open Questions

1. **Vertical space pressure on small phones.** A 382px board on a 390x844 screen leaves only ~462dp for the app bar, top gap, line label, move pills, and action bar. This should be fine (the current 300px board leaves ~544dp), but it should be verified on a short phone (e.g. iPhone SE at 375x667 — the board would be 367px, leaving only ~300dp for everything else). If vertical space is too tight on any screen, those screens can use `boardSizeForNarrow` with a `maxHeightFraction` to add a secondary height clamp.

2. **Browser content height guard is preserved, not removed.** The browser narrow layout currently uses `screenHeight * 0.4` as a height clamp. The plan preserves this via `boardSizeForNarrow(..., maxHeightFraction: 0.4)` rather than dropping it. This ensures short/landscape viewports do not have the board crowd out the controls and move tree.

3. **Wide layout consistency is now enforced.** The drill wide branch uses `constraints.maxWidth * 0.6`, the browser wide branch uses `constraints.maxHeight.clamp(0.0, constraints.maxWidth * 0.5)`, and Add Line has no wide branch at all. These inconsistencies are resolved by: (a) introducing `boardSizeForConstraints` as a shared wide-layout sizing function, (b) migrating drill and browser wide branches to use it, and (c) adding a wide branch to Add Line. The different `widthFraction` values (0.6 for drill, 0.5 for browser) are intentional layout choices that affect how much of the row the board occupies, but the underlying formula and cap are shared. Note: even with different `widthFraction` values, the boards will be the same size at a given viewport only if the `BoxConstraints` passed to `boardSizeForConstraints` are the same. Since drill and browser have different surrounding chrome (app bar, padding), their `constraints.maxWidth` and `constraints.maxHeight` inside `LayoutBuilder` may differ slightly. To guarantee pixel-identical boards at wide breakpoints, all three screens should use the **same** `widthFraction` value. Recommend standardising on `0.5` for all wide layouts. If drill needs the board to appear larger, that can be achieved via padding on the side panel rather than a different board size.

4. **Line label left inset (`kLineLabelLeftInset = 16`).** With near-zero board margins, the 16dp left inset for the line label may look visually misaligned relative to the board edge (which is now only 4dp from the screen edge). Consider reducing `kLineLabelLeftInset` to `kBoardHorizontalInset` (4dp) for consistency. This is a minor visual polish item and could be deferred.

5. **Test fragility.** The board layout test compares exact pixel sizes via equality. The shared `boardSizeForWidth` and `boardSizeForConstraints` functions mitigate divergence, but care must be taken that all screens pass equivalent inputs. The test's equality-based assertion (not a hard-coded pixel value) is the correct approach — it will catch any screen that diverges without being brittle to constant changes.

6. **Add Line dynamic banner above the board (out of scope).** The Add Line screen renders a dynamic `aggregateDisplayName` banner above the board (line ~398 in `add_line_screen.dart`). This conflicts with the board-layout-consistency spec, which states "No dynamic content above the board." This pre-existing divergence is **not addressed by CT-52** — it is a separate issue. CT-52 only changes the board's width-based sizing and adds a wide-layout branch to Add Line. The banner does not affect horizontal sizing. A follow-up task should reconcile this spec violation (e.g. by moving the banner below the board or into the app bar subtitle). Reviewers should not assume CT-52 restores full contract compliance on this point.
