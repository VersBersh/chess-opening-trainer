- **Verdict** — Approved

- **Progress**
  - [x] **Step 1 (done):** `_formatNextDue` boundary logic updated exactly as planned in `src/lib/screens/drill_screen.dart` (now `<= 0 => Today`, `== 1 => Tomorrow`).
  - [x] **Step 2 (done):** Widget-test comment updated in `src/test/screens/drill_screen_test.dart:811` to remove the hardcoded `"Tomorrow"` claim.
  - [x] **Step 3 (done):** No code paths/tests were found that parse or depend on `"Tomorrow"` as a required literal (display-only string remains in formatter).

- **Issues**
  1. None.

Implementation matches the plan, is logically correct for same-day/next-day/overdue boundaries, and introduces no functional regressions in dependents. Unplanned source changes were not found in `git diff HEAD` beyond the two expected files.