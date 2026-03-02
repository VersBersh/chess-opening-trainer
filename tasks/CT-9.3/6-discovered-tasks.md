# CT-9.3 Discovered Tasks

## ~~1. Extract shared label-edit dialog and confirmation~~ → SUPERSEDED by CT-11.2

- **Suggested ID:** ~~CT-10.1~~ → N/A
- **Title:** Extract shared label-edit dialog and multi-line confirmation widget
- **Description:** The `_showLabelDialog()` and `_showMultiLineWarningDialog()` methods are now duplicated in both `add_line_screen.dart` and `repertoire_browser_screen.dart`. Extract them into a shared widget/helper (e.g., `lib/widgets/label_edit_dialog.dart`) to reduce duplication and ensure future label-edit behavior changes are applied consistently.
- **Why discovered:** During CT-9.3 implementation and code review, the multi-line confirmation dialog was added to both screens, doubling the existing label dialog duplication.
- **Status:** Superseded — CT-11.2 replaces popup label dialogs with inline editing, eliminating the duplication at its source.
