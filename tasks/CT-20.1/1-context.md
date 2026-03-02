### Relevant Files

| File | Role |
|------|------|
| `src/lib/repositories/local/local_review_repository.dart` | Contains `LocalReviewRepository.getCardsForSubtree` -- the method with the bug. Builds a recursive CTE custom query with an inline ISO 8601 date string for the `dueOnly` filter. |
| `src/lib/repositories/review_repository.dart` | Abstract `ReviewRepository` interface. Defines the `getCardsForSubtree(int moveId, {bool dueOnly, DateTime? asOf})` contract. No changes needed. |
| `src/lib/repositories/local/database.dart` | Drift database definition. Defines `ReviewCards` table with `DateTimeColumn get nextReviewDate => dateTime()()`. Drift default stores as Unix epoch seconds (integer). |
| `src/lib/repositories/local/database.g.dart` | Generated Drift code. Shows `Variable<DateTime>(nextReviewDate)` pattern for binding DateTime values. Confirms `DriftSqlType.dateTime` type. |
| `src/lib/screens/repertoire_browser_screen.dart` | Primary caller of `getCardsForSubtree(moveId, dueOnly: true)`. Uses the result's `.length` to populate due-count badges on labeled tree nodes. |
| `src/test/repositories/local_repertoire_repository_test.dart` | Existing repo test file. Provides patterns for in-memory DB setup (`NativeDatabase.memory()`), `seedLineWithCard` helper, and test structure. |

### Architecture

The repository layer abstracts data access behind interfaces (`ReviewRepository`, `RepertoireRepository`). The only current implementation is `LocalReviewRepository`, which uses SQLite via Drift.

**Drift DateTime storage:** Drift 2.x stores `DateTime` columns as Unix epoch seconds (integer) by default. No `build.yaml` override exists, so the default applies.

**Type-safe queries work correctly:** Methods like `getDueCards` and `getDueCardsForRepertoire` use Drift's type-safe query builder (`c.nextReviewDate.isSmallerOrEqualValue(cutoff)`), which handles the DateTime-to-integer conversion automatically.

**Raw SQL query has the bug:** `getCardsForSubtree` uses `_db.customSelect` with a raw SQL string because it needs a recursive CTE (which Drift's query builder does not support). The `dueOnly` filter interpolates `cutoff.toIso8601String()` directly into the SQL, comparing an integer column (Unix seconds) against a text string — producing incorrect results.

**The fix:** Replace the string interpolation with a parameterized `Variable<DateTime>` bound to a `?` placeholder. Drift's `Variable<DateTime>` automatically serializes the `DateTime` to the correct storage format (integer seconds).
