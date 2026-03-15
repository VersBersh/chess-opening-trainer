- **Verdict** — `Approved`
- **Progress**
  - [x] Step 1 — done. [`src/lib/screens/add_line_screen.dart`](C:/code/draftable/chess-1/src/lib/screens/add_line_screen.dart#L893) now routes the Label action through `_buildLabelButton`, and the disabled state is wrapped in a `Tooltip` with the planned message while the enabled state remains a plain `TextButton.icon`.
  - [x] Step 2 — done. [`src/test/screens/add_line_screen_test.dart`](C:/code/draftable/chess-1/src/test/screens/add_line_screen_test.dart#L402) adds the disabled-state widget test, verifies the `Tooltip.message`, and checks that a long-press shows the tooltip text.
  - [x] Step 3 — done. [`src/test/screens/add_line_screen_test.dart`](C:/code/draftable/chess-1/src/test/screens/add_line_screen_test.dart#L438) adds the separate enabled-state test and confirms there is no `Tooltip` wrapper when a pill is focused.
- **Issues**
  1. None. The diff is limited to the planned screen change and the two planned tests. The implementation matches the controller/spec behavior for `canEditLabel`, introduces no unplanned behavior changes, and does not present any obvious regression risk from code inspection.
