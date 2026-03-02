# CT-7.2: Discovered Tasks

1. ~~**CT-7.6: Extract Shared Dialogs**~~ → SUPERSEDED by CT-11.2
   - Title: Extract parity, discard, and label dialogs to shared utilities
   - Description: The parity warning, discard confirmation, and label editing dialogs are duplicated between `AddLineScreen` and `RepertoireBrowserScreen`. Extract to shared utility functions (e.g., `src/lib/widgets/dialogs.dart`).
   - Discovered because: Code review flagged duplication between the new Add Line screen and existing repertoire browser.
   - **Status:** Superseded — CT-11.2 replaces label dialogs with inline editing. Remaining parity/discard dialogs can be addressed as part of CT-11.7 (inline confirmation warning).

2. ~~**CT-7.7: Add Line Auto-Scroll Pills**~~ → SUPERSEDED by CT-9.2
   - Title: Auto-scroll MovePillsWidget to keep focused pill visible
   - Description: As pills accumulate in the horizontal `MovePillsWidget`, the focused pill may scroll off-screen. Implement auto-scrolling to keep the focused pill visible.
   - Discovered because: Noted as deferred from CT-7.1 and confirmed during CT-7.2 implementation.
   - **Status:** Superseded — CT-9.2 changes pills from horizontal scrolling to wrapping (`Wrap` widget), making auto-scroll moot.
