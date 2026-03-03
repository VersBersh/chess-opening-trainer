# CT-49.1: Discovered Tasks

## CT-49.4: Enable confirm for label-only edits

**Title:** Allow Confirm when only labels changed (no new moves)
**Description:** Currently, if the user follows an existing line and only edits labels (no new moves), the Confirm button remains disabled and pending labels are silently discarded. Enable Confirm when `_pendingLabels.isNotEmpty` even without new moves, by adding a label-only persist path.
**Why discovered:** The deferred label persistence design revealed that label-only edits on fully-existing lines cannot be saved because `hasNewMoves` is `false`.

## CT-49.5: Extract shared repository transaction helpers

**Title:** DRY up extendLine/saveBranch and their WithLabelUpdates variants
**Description:** `extendLineWithLabelUpdates` and `saveBranchWithLabelUpdates` duplicate substantial logic from `extendLine` and `saveBranch`. Extract private helpers for chain insertion and card creation to reduce the 4-way duplication and maintenance risk.
**Why discovered:** Code review flagged the duplication as a Minor DRY violation with future maintenance risk.

## CT-49.6: Pending-aware display name preview in label editor

**Title:** Make InlineLabelEditor preview reflect pending labels on other pills
**Description:** The `previewDisplayName` callback for saved pills uses `cache.previewAggregateDisplayName(move.id, text)`, which doesn't account for pending labels on other pills. The aggregate banner above the board correctly shows pending labels, but the inline editor preview may be inaccurate.
**Why discovered:** Identified as a minor UX imperfection during plan design, confirmed during implementation.
