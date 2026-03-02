# CT-9.5 Discovered Tasks

## ~~1. Extract shared label dialog utility~~ → SUPERSEDED by CT-11.2

- **Suggested ID:** ~~CT-10.1~~ → N/A
- **Title:** Extract `_showLabelDialog` to shared utility
- **Description:** The `_showLabelDialog` method is duplicated identically in `repertoire_browser_screen.dart` and `add_line_screen.dart`. Extract it to a shared top-level function in `src/lib/widgets/label_dialog.dart` and update both callers.
- **Why discovered:** Noticed during implementation that the same label dialog code exists in two places, violating DRY.
- **Status:** Superseded — CT-11.2 replaces popup label dialogs with inline editing, eliminating the duplication at its source.

## 2. Manual QA — inline label icon on device

- **Suggested ID:** (manual testing, not a code task)
- **Title:** Verify inline label icon tap targets and visual crowding on physical devices
- **Description:** The inline label icon uses a `GestureDetector` with no enforced minimum tap target. On small screens, the icon may be hard to tap. Verify on phone-sized screens that (1) the label icon is easily tappable, (2) tapping the icon doesn't accidentally trigger row selection, and (3) the added icon doesn't cause excessive text truncation on deeply indented nodes.
- **Why discovered:** The `IconButton` approach was replaced with `GestureDetector` to avoid row height inflation, but this trades enforced tap target size for compact layout.
