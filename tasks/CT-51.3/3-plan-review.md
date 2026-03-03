# CT-51.3 Plan Review

**Verdict:** Approved

Plan verified against `home_screen.dart`, `home_screen_test.dart`, and `add_line_screen.dart`.

- **Step 1** (import): `home_screen.dart` currently imports `drill_screen.dart` and `repertoire_browser_screen.dart`. Adding `add_line_screen.dart` alphabetically between them is correct.
- **Step 2** (_onAddLine): The navigation pattern matches `_onRepertoireTap` exactly. `AddLineScreen` takes `required int repertoireId` with optional `startingMoveId` — omitting `startingMoveId` is correct for root navigation.
- **Step 3** (button): The `_buildActionButtons` method uses `OutlinedButton.icon` with `minimumSize: const Size(double.infinity, 48)` for Free Practice and Manage Repertoire. Adding an identical-styled Add Line button between them matches the spec order.
- **Step 4** (test update): The existing presence test at line 258 checks for the three current buttons. Adding `find.text('Add Line')` is correct.
- **Step 5** (empty state): The empty-state test at line 722 asserts `Start Drill`, `Free Practice`, and `Manage Repertoire` are absent. Adding `Add Line` is correct.
- **Step 6** (navigation test): The `Manage Repertoire navigates to RepertoireBrowserScreen` test at line 289 is the correct pattern — uses in-memory `AppDatabase`, `LocalRepertoireRepository`, `LocalReviewRepository`. The same approach works for `AddLineScreen`.

No issues found.