# CT-2.2 Discovered Tasks

## 1. Undo Snackbar After Line Confirm

- **Suggested ID:** CT-2.7
- **Title:** Undo snackbar after line confirmation
- **Description:** Show a transient undo snackbar (~8 seconds) after confirming a new line or line extension. On tap, reverse the persisted changes (delete inserted moves, restore old card SR values for extensions). Requires capturing pre-confirm state.
- **Why discovered:** The spec (`line-management.md`, "Undo Line Extension" section) requires this feature. Deferred from CT-2.2 to keep the confirm flow simple for v1.

## 2. Confirm Flow Error Handling

- **Suggested ID:** CT-2.8
- **Title:** Error handling in line entry confirm flow
- **Description:** Add try/catch around the persistence logic in `_onConfirmLine` to handle database errors (e.g., unique constraint violations from duplicate sibling SANs). Show user-facing error messages via SnackBar.
- **Why discovered:** During implementation, the confirm flow was written without error handling. Database constraint violations could cause unhandled exceptions.

## 3. Extract Persistence Logic from Browser Screen

- **Suggested ID:** CT-2.9
- **Title:** Extract line persistence logic into a service
- **Description:** The `_onConfirmLine` method in `repertoire_browser_screen.dart` mixes high-level orchestration with low-level persistence detail (companion construction, parent-ID chaining). Extract into a dedicated service or repository method (e.g., `saveNewBranch`) to reduce screen complexity and improve testability. Flagged by design review as a Major issue.
- **Why discovered:** Design review (5-impl-review-design.md, issue #1) identified SRP violation in the 701-line screen file.
