# CT-27: Implementation Notes

## Files Modified

| File | Changes |
|------|---------|
| `src/lib/providers.dart` | Added `clockProvider` — a `Provider<DateTime Function()>` defaulting to `DateTime.now` |
| `src/lib/controllers/drill_controller.dart` | Replaced all 4 `DateTime.now()` calls with injected `_clock()`. Added `late DateTime Function() _clock` and `late DateTime _sessionStartTime` fields. Clock read from `clockProvider` in `build()`. |
| `src/test/screens/drill_screen_test.dart` | Added optional `clock` parameter to `buildTestApp`. Added deterministic duration test proving injected clock works (verifies "2m 30s" display). |
| `src/test/screens/drill_filter_test.dart` | Added optional `clock` parameter to `buildTestApp` for consistency. |

## Deviations from Plan

1. **Used `late DateTime _sessionStartTime` instead of `DateTime(0)` placeholder** — per reviewer feedback (issue #1 in 3-plan-review.md), `late` is cleaner and avoids an invalid sentinel state.
2. **Included `drill_filter_test.dart` update** — reviewer suggested it was optional, but added it for consistency since it was minimal effort.

## New Tasks / Follow-up Work

None discovered.
