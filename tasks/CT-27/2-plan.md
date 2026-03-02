# CT-27: Implementation Plan

## Goal

Inject a clock abstraction into `DrillController` so all `DateTime.now()` calls go through a testable, overridable function, enabling deterministic session-duration testing.

## Steps

### 1. Add `clockProvider` to `src/lib/providers.dart`

Add a new Riverpod provider:

```dart
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
```

Type `DateTime Function()` avoids adding a package dependency and follows the project's existing minimal-abstraction style. Default is `DateTime.now` (tear-off).

### 2. Replace `DateTime.now()` calls in `DrillController`

**File:** `src/lib/controllers/drill_controller.dart`

**2a.** Add a `late` field for the clock and replace the field initializer:

```dart
// Before:
DateTime _sessionStartTime = DateTime.now();

// After:
late DateTime Function() _clock;
DateTime _sessionStartTime = DateTime(0); // overwritten in build()
```

**2b.** In `build()`, read the clock provider and use it:

```dart
_clock = ref.read(clockProvider);
_sessionStartTime = _clock();
```

**2c.** In `_buildSummary()`, replace `DateTime.now()` with `_clock()`.

**2d.** In `finishSession()`, replace `DateTime.now()` with `_clock()`.

Depends on: Step 1.

### 3. Update `buildTestApp` in `src/test/screens/drill_screen_test.dart`

Add optional `clock` parameter to `buildTestApp`:

```dart
DateTime Function()? clock,
```

Add to `ProviderScope.overrides`:

```dart
if (clock != null) clockProvider.overrideWithValue(clock),
```

Depends on: Step 1.

### 4. Update `buildTestApp` in `src/test/screens/drill_filter_test.dart`

Apply the same optional `clock` parameter pattern as Step 3.

Depends on: Step 1.

### 5. Add a deterministic duration test

**File:** `src/test/screens/drill_screen_test.dart`

Add a test that uses an advancing clock to verify the summary shows the correct elapsed time (e.g., advance by 2m 30s, verify "2m 30s" appears).

Depends on: Steps 2, 3.

### 6. Run tests and verify

- Run all drill-related tests
- Verify no `DateTime.now()` calls remain in `drill_controller.dart`
- Verify all existing tests still pass

Depends on: Steps 2, 3, 4, 5.

## Risks / Open Questions

1. **Field initializer timing.** `_sessionStartTime` field initializer runs before `build()`. Replacing with `DateTime(0)` placeholder is safe because `build()` always overwrites it before any read. Verify no code path reads it before `build()`.

2. **`package:clock` vs `DateTime Function()`.** Using `DateTime Function()` because: no new dependency, consistent with existing `{DateTime? today}` pattern, avoids global mutable state. Migration to `package:clock` is straightforward later if desired.

3. **`formatNextDue` in `SessionSummaryWidget`.** Already addressed by CT-26. Widget call site still uses default `DateTime.now()` — injecting clock into widget layer is a separate concern, out of scope.

4. **Riverpod `overrides` list with `if`.** Dart collection `if` in list literals is supported. If Riverpod's type checking is strict, may need to always include the override with a default.
