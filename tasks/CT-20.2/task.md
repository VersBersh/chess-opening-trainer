---
id: CT-20.2
title: Fix drill summary next-review date wording boundary
epic: CT-20
depends: []
specs:
  - code-base-health-review.md
  - features/drill-mode.md
files:
  - src/lib/screens/drill_screen.dart
---
# CT-20.2: Fix drill summary next-review date wording boundary

**Epic:** CT-20
**Depends on:** none

## Description

The drill session summary currently formats `difference <= 1` as "Tomorrow", which incorrectly labels same-day (`difference == 0`) reviews as tomorrow. Update the date-label boundary logic so output is accurate for today/tomorrow/future dates.

## Acceptance Criteria

- [ ] Same-day next review is not labeled "Tomorrow"
- [ ] Next-day next review is labeled "Tomorrow"
- [ ] Longer future intervals continue to render correctly (e.g., "In N days" or date)
- [ ] Existing summary UI remains unchanged apart from corrected wording

## Notes

Include edge cases around midnight/date truncation in tests if existing tests cover `_formatNextDue` behavior indirectly.

