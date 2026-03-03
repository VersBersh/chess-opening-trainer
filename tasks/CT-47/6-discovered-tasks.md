# CT-47: Discovered Tasks

## 1. Remove unused RepertoireCard widget

- **Suggested ID:** CT-50
- **Title:** Remove unused RepertoireCard widget
- **Description:** `src/lib/widgets/repertoire_card.dart` is no longer referenced by the home screen after CT-47. Verify no other screen uses it, and if so, delete the file and any associated tests.
- **Why discovered:** The CT-47 implementation replaced the per-repertoire card layout with direct action buttons, leaving `RepertoireCard` unused.

## 2. Split home screen test file

- **Suggested ID:** CT-51
- **Title:** Split home_screen_test.dart into focused test files
- **Description:** The home screen test file is ~690 lines mixing fake repositories, widget builders, and multiple behavioral areas. Split into focused files (e.g., `home_screen_actions_test.dart`, `home_screen_empty_state_test.dart`) and extract shared test helpers.
- **Why discovered:** Flagged in the design review as a maintainability concern after the CT-47 test rewrite.
