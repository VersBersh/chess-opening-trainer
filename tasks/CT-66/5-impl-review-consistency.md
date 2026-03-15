**Verdict** — `Approved`

**Progress**
- [x] Done — Step 1: `_buildNarrowContent` now reads keyboard state and collapses the banner and board with `AnimatedSize` when `isKeyboardOpen && _isLabelEditorVisible`.
- [x] Done — Step 2: `_buildWideContent` remains a separate path and has no keyboard-collapse logic.
- [x] Done — Step 3: test helpers were extended as planned, and coverage was added for narrow collapse, keyboard dismissal, editor close with keyboard still open, wide-layout behavior, and banner collapse.

**Issues**
None. The implementation follows the plan, the code change is scoped correctly, and the added test-only keys/helpers are justified and consistent with the existing CT-55 pattern.