- **Verdict** — `Approved`
- **Progress**
  - [x] **Done** — Step 1: Added `isExistingLine` getter in `AddLineController` (`_state.pills.isNotEmpty && !hasNewMoves`), matching plan intent.
  - [x] **Done** — Step 2: Added conditional “Existing line” info text in `AddLineScreen` between parity warning and action bar, with `bodySmall` + `onSurfaceVariant` styling and planned padding.
  - [x] **Done** — Step 3: Added controller unit-test group `isExistingLine` with all 5 planned scenarios.
  - [x] **Done** — Step 4: Added widget-test group for existing-line info text with all 3 planned scenarios.
- **Issues**
  1. None.

Implementation matches the plan, appears logically correct for the specified edge cases, introduces no unplanned source changes, and shows no obvious regressions in callers/dependents from code inspection.