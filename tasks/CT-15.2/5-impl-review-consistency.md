**Verdict** — `Needs Fixes`

**Progress**
- [x] Step 1 — AddLineScreen controller injection + ownership-aware dispose (`done`)
- [x] Step 2 — `buildTestApp` accepts optional injected controller (`done`)
- [x] Step 3 — helper sets up extension scenario after `pumpAndSettle()` (`done`)
- [x] Step 4 — snackbar appears after confirming extension (`done`)
- [~] Step 5 — undo rollback test exists but assertions are weaker than planned (`partially done`)
- [ ] Step 6 — timeout dismissal test does not actually test timeout behavior (`not started` for intended behavior)
- [x] Step 7 — required test imports + `sanToNormalMove` helper added (`done`)
- [x] Step 8 — explicit teardown for injected controller/board added in each new test (`done`)

**Issues**
1. **Major** — Timeout behavior is not being tested; snackbar is manually dismissed.  
   In [`add_line_screen_test.dart:664`](C:\code\misc\chess-trainer-3\src\test\screens\add_line_screen_test.dart:664)-[`670`](C:\code\misc\chess-trainer-3\src\test\screens\add_line_screen_test.dart:670), the test calls `ScaffoldMessenger.hideCurrentSnackBar()` instead of advancing fake time past 8 seconds. This validates manual dismissal, not expiration timeout, so the core plan goal (“dismisses after timeout”) is unmet.  
   **Fix:** Replace manual hide with `await tester.pump(const Duration(seconds: 9)); await tester.pumpAndSettle();` and assert disappearance afterward.

2. **Minor** — Extension DB assertions are count-based, not identity-based, in undo/timeout tests.  
   In [`add_line_screen_test.dart:625`](C:\code\misc\chess-trainer-3\src\test\screens\add_line_screen_test.dart:625)-[`629`](C:\code\misc\chess-trainer-3\src\test\screens\add_line_screen_test.dart:629) and [`678`](C:\code\misc\chess-trainer-3\src\test\screens\add_line_screen_test.dart:678)-[`683`](C:\code\misc\chess-trainer-3\src\test\screens\add_line_screen_test.dart:683), assertions only check lengths. The plan called for verifying old `e4` card removed and new `e5` card present (and preserved after timeout).  
   **Fix:** Assert specific SAN/card linkage (e.g., find `e5` move id and verify card `leafMoveId == e5Id` after confirm/timeout; after undo verify `leafMoveId == e4Id`).