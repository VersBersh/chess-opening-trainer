# CT-20.2 Plan

## Goal

Fix the `_formatNextDue` boundary logic so same-day next-review dates are labeled "Today" (not "Tomorrow"), next-day dates remain "Tomorrow", and overdue/past dates get a sensible label.

## Steps

1. **Fix the boundary condition in `_formatNextDue`**
   - **File:** `src/lib/screens/drill_screen.dart` (lines 1144-1157)
   - Change `if (difference <= 1) return 'Tomorrow'` to:
     - `if (difference <= 0) return 'Today'`
     - `else if (difference == 1) return 'Tomorrow'`
   - The remaining branches (`In $difference days` for 2-30, ISO date for 31+) are unchanged.
   - No dependencies.

2. **Update widget test comment**
   - **File:** `src/test/screens/drill_screen_test.dart` (line 811)
   - Change comment from `// Should show next review text (0 mistakes = quality 5, interval 1 day = "Tomorrow")` to `// Should show next review text (0 mistakes = quality 5, interval 1 day)`
   - The assertion `find.textContaining('Next review:')` does not match a specific label, so it remains valid.
   - Depends on: Step 1 (conceptually).

3. **Verify no other code depends on the "Tomorrow" string**
   - Grep for `Tomorrow` in context of drill summaries. Based on exploration, no production or test code parses the output.
   - Verification only — no code changes.

## Risks / Open Questions

1. **"Today" for typical SM-2 flow.** With minimum interval 1 day, `nextReviewDate` is always ~24h ahead. After date truncation, the difference is usually 1 (→ "Tomorrow"). "Today" only appears if `nextReviewDate` falls on the same calendar day (e.g., newly imported card, skipped update). This is rare but possible and correct.
2. **Negative differences (overdue).** Mapped to "Today" via `<= 0`. "Today" is reasonable — if a card is past due, the next review is effectively now.
3. **Relationship to CT-26/CT-27.** This task does not extract the method or inject a clock. The fix is minimal and survives extraction cleanly.
4. **Widget test determinism.** The existing test uses real `DateTime.now()` and can't predict the exact label. It correctly checks only that "Next review:" exists. Full branch coverage requires clock injection (CT-27) or extraction (CT-26).
