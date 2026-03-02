# CT-11.7: Discovered Tasks

## 1. Extract AddLineScreen inline widgets into separate widget files

- **Suggested ID:** CT-11.8
- **Title:** Extract AddLineScreen inline widgets to reduce file size
- **Description:** `AddLineScreen` has grown to 430+ lines, mixing board orchestration, inline warning, inline label editor integration, undo snackbar, discard dialog, and action bar. Extract the inline parity warning and related confirm flow into a dedicated widget (e.g., `ParityWarningBanner`) to reduce the screen file's responsibility surface.
- **Why discovered:** Code design review flagged file size > 300 lines as a code smell. The file was already borderline before CT-11.7; adding the inline warning pushed it further over.
