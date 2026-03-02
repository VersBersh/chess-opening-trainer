# CT-6 Discovered Tasks

## CT-14: Dark Theme Support _(renamed from CT-8 — CT-8 now assigned to Line Label Display)_
**Title:** Add dark theme and user-selectable theme mode
**Description:** Add `darkTheme` to `MaterialApp`, create an `appThemeModeProvider` backed by SharedPreferences, add a theme-mode picker (light/dark/system) to the settings screen, and audit hardcoded colors (e.g., `Colors.red`, `Colors.green` in drill feedback) for dark-mode compatibility.
**Why discovered:** Deferred from CT-6 Step 11 during plan revision because it requires its own state model, provider, storage keys, settings UI, and tests — mixing it with the styling cleanup created scope risk.

## CT-15: Repertoire Browser Refactor — Extract Board Panel and Action Bars _(renamed from CT-9 — CT-9 now assigned to UI Polish epic)_
**Title:** Extract board panel and action bars from repertoire browser screen
**Description:** `repertoire_browser_screen.dart` is now ~1300 lines. Extract the board panel (chessboard + controls), browse-mode action bar, and edit-mode action bar into separate widget files to improve readability and SRP.
**Why discovered:** File size exceeded 300-line threshold noted in plan risk item 8. The responsive layout refactor added extracted methods but the file is still too large.

## CT-16: Responsive Layout Test Coverage _(renamed from CT-10 — CT-10 now assigned to Free Practice Rework)_
**Title:** Add widget tests for responsive layout branches
**Description:** The wide (>= 600px) and narrow (< 600px) layout paths in drill screen and repertoire browser are not directly tested. Add widget tests with custom `MediaQuery` to verify both layout paths render correctly.
**Why discovered:** During test fix phase, noticed that all tests run at a fixed narrow viewport. The wide layout code path is untested.
