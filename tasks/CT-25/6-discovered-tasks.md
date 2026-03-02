# 6-discovered-tasks.md

## Discovered Tasks

### CT-25.1: Update consuming imports to point directly at drill_controller.dart
- **Title:** Remove drill_screen.dart re-exports and update consumer imports
- **Description:** Currently `drill_screen.dart` re-exports `drill_controller.dart` and `session_summary.dart` for backward compatibility. Update `home_screen.dart`, `drill_screen_test.dart`, `drill_filter_test.dart`, and `home_screen_test.dart` to import `controllers/drill_controller.dart` directly, then remove the `export` lines from `drill_screen.dart`.
- **Why discovered:** Intentional trade-off during CT-25 to minimize diff size and risk. The re-exports work but create a module boundary leak (flagged in design review).
