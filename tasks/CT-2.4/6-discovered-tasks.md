# CT-2.4 Discovered Tasks

## 1. Fix SR defaults discrepancy for new review cards

- **Suggested ID:** CT-0.6
- **Title:** Align intervalDays default with spec (0 vs 1)
- **Description:** The `line-management.md` spec says new cards should have "interval 0," but the DB schema (`database.dart` line 36) defaults `intervalDays` to `1`. Either update the schema default to `0` via migration, or update the spec to match the current schema. This affects card creation in both line entry (CT-2.2) and orphan handling (CT-2.4).
- **Why discovered:** Plan review #5 flagged the mismatch between spec and DB defaults during CT-2.4 planning.

## 2. Extract deletion orchestration from browser screen

- **Suggested ID:** CT-2.6
- **Title:** Extract deletion/orphan workflow into application service
- **Description:** The browser screen now contains deletion orchestration, orphan policy, and direct concrete repository access. Extract the delete-leaf, delete-branch, and handle-orphans logic into a dedicated service class that depends on repository abstractions, keeping the widget focused on interaction and presentation.
- **Why discovered:** Design review flagged SRP/DIP drift as a Major issue. The screen file is ~900 lines.

## 3. Add orphan dialog dismiss test

- **Suggested ID:** (part of CT-2.4 follow-up)
- **Title:** Test that dismissing orphan dialog does not delete the move
- **Description:** Add a widget test that verifies: when the orphan prompt is dismissed (e.g., via system back), the orphaned move is preserved (not deleted). This tests the post-review fix for the Critical null-result bug.
- **Why discovered:** The Critical bug fix (null dialog result treated as delete) was added during code review but has no dedicated test.
