**Verdict:** Approved

**Progress:**
- [x] Step 1 — Conditional banner above the board removed
- [x] Step 2 — Reserved-height `SizedBox(height: kLineLabelHeight)` added immediately after the board

**Confirmation:** Implementation exactly matches the plan. The conditional `Container` banner is gone from above the board. A fixed-height `SizedBox(height: kLineLabelHeight)` now appears after the board with the display name conditionally rendered inside. Uses `kLineLabelHeight`, `kLineLabelLeftInset`, `titleMedium` style — matching spacing constants and Drill screen pattern. No unplanned changes. No regressions introduced. Flutter analyze: no issues.
