# CT-2.11: Transposition Conflict Warning — Design Review

## Verdict

**Approved with Notes**

The implementation is well-structured and follows the plan closely. Responsibilities are properly separated: conflict detection lives in the data layer (`RepertoireTreeCache`), dialog presentation is in a self-contained file, and the `InlineLabelEditor` remains ignorant of conflict specifics via a generic callback. The code is readable, testable, and well-tested. The issues below are minor.

## Issues

### 1. Minor — DRY: Duplicated `onCheckConflicts` callback body across two screens

**Principle:** DRY (Don't Repeat Yourself)

**Files:**
- `src/lib/screens/add_line_screen.dart` (lines 383-400)
- `src/lib/screens/repertoire_browser_screen.dart` (lines 241-258)

**Code:** Both screens contain an identical 16-line `onCheckConflicts` callback:
```dart
onCheckConflicts: (newLabel) async {
  final conflicts = cache.findLabelConflicts(move.id, newLabel);
  if (conflicts.isEmpty) return true;
  final conflictInfos = conflicts
      .map((c) => ConflictInfo(
            label: c.label!,
            path: cache.getPathDescription(c.id),
          ))
      .toList();
  final result = await showTranspositionConflictDialog(
    context,
    newLabel: newLabel,
    conflicts: conflictInfos,
  );
  return result == true;
},
```

The only variation is the source of the move ID (`move.id` vs `moveId`).

**Why it matters:** If the conflict check logic changes (e.g., adding aggregate display name fallback as noted in the plan's risk #5, or changing the dialog call signature), both sites must be updated in lockstep.

**Suggested fix:** Extract a free function (e.g., in `label_conflict_dialog.dart` alongside the dialog and `ConflictInfo`):
```dart
Future<bool> checkLabelConflicts(
  BuildContext context,
  RepertoireTreeCache cache,
  int moveId,
  String? newLabel,
) async { ... }
```
Both screens would then pass `onCheckConflicts: (label) => checkLabelConflicts(context, cache, moveId, label)`. This is a minor issue because the duplication is small and contained to two call sites, but it is worth consolidating before any future iteration on conflict display.

### 2. Minor — Unused parameter: `newLabel` in `showTranspositionConflictDialog`

**Principle:** Clean Code / Interface Segregation

**File:** `src/lib/widgets/label_conflict_dialog.dart` (line 16)

**Code:**
```dart
Future<bool?> showTranspositionConflictDialog(
  BuildContext context, {
  required String? newLabel,   // <-- never read inside the function body
  required List<ConflictInfo> conflicts,
})
```

The `newLabel` parameter is declared as `required` but is never referenced in the dialog body. The dialog text does not mention what label the user is about to apply -- it only lists existing conflicting labels.

**Why it matters:** A required-but-unused parameter is misleading. Readers (and the analyzer with stricter lint rules) will wonder what it is for. If the intent is to display it in the future (e.g., "You are applying 'X' but..."), then it should be used now or documented with a TODO. If it is not needed, it should be removed.

**Suggested fix:** Either remove `newLabel` from the signature (and from both call sites), or incorporate it into the dialog body text, e.g., `'You are applying "$newLabel" but this position appears elsewhere...'`. The second option is arguably better UX.

### 3. Minor — Test readability: Dead-code preamble in AddLineScreen test

**Principle:** Clean Code / Readability

**File:** `src/test/screens/add_line_screen_test.dart` (lines 877-920)

**Code:** The "Apply anyway" test begins with a ~40-line block that seeds a repertoire with `labelsOnSan`, discovers the approach does not work for this scenario, includes extensive comments explaining the problem, closes the database, recreates it, and re-seeds. The block reads like a debugging session left in the code.

**Why it matters:** Tests should clearly communicate intent. The lengthy false-start-and-retry obscures what the test is actually verifying. Other tests in the same group (Cancel, clearing) use the clean pattern directly.

**Suggested fix:** Delete the first seed attempt and its explanatory comments. Start the test directly with the clean seed-then-manual-label pattern used by the other tests.

---

**Summary:** The design is sound. The new `findLabelConflicts` and `getPathDescription` methods are well-placed in `RepertoireTreeCache`, the dialog file is correctly isolated to avoid transitive dependency issues, and `InlineLabelEditor` remains generic through its callback-based extension point. The deviation from the plan (using `movesByPositionKey` instead of exact FEN) is a reasonable improvement documented in the code comments. Test coverage is comprehensive across unit and widget layers.
