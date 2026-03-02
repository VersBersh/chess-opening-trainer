# CT-27: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/drill_controller.dart` | Primary target. Contains `DrillController` with `DateTime.now()` calls for session timing. |
| `src/lib/providers.dart` | Central Riverpod provider file. A new `clockProvider` will go here. |
| `src/lib/services/sm2_scheduler.dart` | Established `{DateTime? today}` injection pattern — the codebase convention for clock-dependent code. |
| `src/lib/services/format_utils.dart` | Already follows the `{DateTime? today}` pattern for `formatNextDue`. |
| `src/test/screens/drill_screen_test.dart` | Widget tests for `DrillScreen`. Uses `ProviderScope` overrides. Will need clock override support. |
| `src/test/screens/drill_filter_test.dart` | Additional drill widget tests. Same `buildTestApp` pattern. |
| `src/test/services/drill_engine_test.dart` | Unit tests for `DrillEngine`. No `DateTime.now()` usage (already accepts `{DateTime? today}`). No changes needed. |
| `src/lib/models/session_summary.dart` | `SessionSummary` data class. Receives `sessionDuration` as a `Duration`. No changes needed. |

## Architecture

### Subsystem: Drill Session Timing

`DrillController` is a Riverpod `AutoDisposeFamilyAsyncNotifier` parameterized by `DrillConfig`. It reads dependencies from `ref.read()` during its `build()` method.

**Where `DateTime.now()` is used in `DrillController`:**

1. **Field initializer** (~line 159): `DateTime _sessionStartTime = DateTime.now();` — overwritten in `build()`, effectively dead code but still runs.
2. **`build()` method** (~line 246): `_sessionStartTime = DateTime.now();` — records session start time.
3. **`_buildSummary()` helper** (~line 438): `DateTime.now().difference(_sessionStartTime)` — computes elapsed time for drill completion.
4. **`finishSession()` method** (~line 506): `DateTime.now().difference(_sessionStartTime)` — computes elapsed time for free practice finish.

All four calls measure session wall-clock duration. They are unrelated to SM-2 scheduling.

**DI pattern:** Riverpod providers are the standard DI mechanism. For clock-like deps, the existing pattern is `{DateTime? today}` optional parameters, but `DrillController` is constructed by Riverpod (no constructor args), so a Riverpod `Provider<DateTime Function()>` is the natural approach.

**Note:** `_formatNextDue` calling `DateTime.now()` was already addressed by CT-26 (extracted to `formatNextDue` in `format_utils.dart` with `{DateTime? today}` parameter). Out of scope.
