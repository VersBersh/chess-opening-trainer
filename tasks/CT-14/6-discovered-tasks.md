# CT-14: Discovered Tasks

## 1. Refactor drill_screen.dart into focused modules

- **Suggested ID:** CT-15
- **Title:** Split drill_screen.dart by responsibility
- **Description:** `drill_screen.dart` is 1129 lines and combines domain state types, async controller/orchestration, filtering logic, theme resolution, and full UI rendering. Split into `drill_controller.dart`, `drill_screen_view.dart`, `drill_feedback_widgets.dart`, keeping only composition at the screen entry point.
- **Why discovered:** Design review flagged the file as a Single Responsibility / file-size code smell (Major). The issue is pre-existing but was surfaced during the CT-14 dark theme review.

## 2. Extract shared theme factory to reduce duplication

- **Suggested ID:** CT-16
- **Title:** Extract theme factory method from main.dart
- **Description:** `main.dart` duplicates most `ThemeData` assembly for light/dark variants. Extract a shared `buildAppTheme(ColorScheme scheme, {required PillTheme pill, required DrillFeedbackTheme drill})` factory so adding future theme extensions only requires one edit point.
- **Why discovered:** Design review flagged DRY / Open-Closed pressure in theme construction (Minor). As more extensions are added, the duplication will grow.
