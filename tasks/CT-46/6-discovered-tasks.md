# CT-46: Discovered Tasks

## 1. Extract shared LineLabelBanner widget
- **Suggested ID:** CT-50
- **Title:** Extract shared LineLabelBanner widget from drill and browser
- **Description:** The line-label rendering logic (SizedBox with fixed height, titleMedium text, onSurfaceVariant color, left inset padding) is duplicated in `drill_screen.dart` and `browser_board_panel.dart`. Extract a shared `LineLabelBanner` widget to eliminate duplication and prevent style divergence.
- **Why discovered:** Code review flagged DRY violation — both files implement identical styling and layout for the label area.

## 2. Fix pre-existing "back navigation from root move" test failure
- **Suggested ID:** CT-51
- **Title:** Fix failing "back navigation from root move" browser test
- **Description:** The test "back navigation from root move returns to initial position" in `repertoire_browser_screen_test.dart` fails because `find.text('1. e4')` can't find a widget. This was already failing before CT-46 changes and appears related to how the move tree renders move text.
- **Why discovered:** Test suite run during CT-46 verification revealed this pre-existing failure.
