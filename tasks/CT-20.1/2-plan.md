### Goal

Replace the inline ISO 8601 string interpolation in `LocalReviewRepository.getCardsForSubtree` with a parameterized `Variable<DateTime>` bound variable so that `dueOnly: true` correctly filters cards by their `next_review_date`.

### Steps

#### Step 1: Replace string-interpolated due filter with parameterized query variable

**File:** `src/lib/repositories/local/local_review_repository.dart`

In the `getCardsForSubtree` method, make the following changes:

**Remove** the string-interpolated `dueFilter` construction:
```dart
final dueFilter = dueOnly
    ? "AND rc.next_review_date <= '${cutoff.toIso8601String()}'"
    : '';
```

**Replace** with a conditional SQL clause that uses a `?` placeholder:
```dart
final dueFilter = dueOnly ? 'AND rc.next_review_date <= ?' : '';
```

**Update** the `variables` list to conditionally include the DateTime variable:
```dart
variables: [
  Variable.withInt(moveId),
  if (dueOnly) Variable<DateTime>(cutoff),
],
```

**Why this works:** Drift's `Variable<DateTime>` serializes the Dart `DateTime` to an integer (Unix epoch seconds) before binding it to the SQL `?` placeholder. This matches the storage format of the `next_review_date` column, so the `<=` comparison operates on integers, producing correct results.

**Why `if (dueOnly)` in the list is safe:** Dart's collection `if` conditionally includes the element. When `dueOnly` is false, `$dueFilter` is an empty string (no `?` placeholder in the SQL), and the `Variable<DateTime>` is omitted from the list. The positional binding stays correct.

#### Step 2: Verify no other callers are affected

**Files to verify (no changes expected):**
- `src/lib/screens/repertoire_browser_screen.dart` — calls with `dueOnly: true` and `dueOnly: false`
- Test mocks implement the interface and return empty lists, unaffected by the internal query change

The method signature (`getCardsForSubtree(int moveId, {bool dueOnly, DateTime? asOf})`) is unchanged.

#### Step 3: Run existing tests to verify no regression

Run `cd src && flutter test` to confirm all existing tests pass.

### Risks / Open Questions

1. **Drift default DateTime storage format.** Plan assumes Drift 2.x uses Unix epoch seconds (integer) as default. The `Variable<DateTime>` approach works in both integer and text storage modes since Drift handles serialization automatically.

2. **No direct test coverage for the fix.** CT-20.1 deliberately scopes out test hardening (handled by CT-20.3). The fix can be manually verified via due-count badges in the Repertoire Browser screen.

3. **Positional variable binding ordering.** The `?` placeholders in `customSelect` are bound positionally. The `if (dueOnly)` collection-if pattern ensures the variable list length matches the number of `?` placeholders.
