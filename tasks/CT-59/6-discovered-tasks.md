# CT-59: Discovered Tasks

## CT-60: Add "Labels saved" snackbar feedback for label-only confirms

**Title:** Show brief snackbar feedback after label-only confirm

**Description:** When the user confirms label-only edits (no new moves), the confirm succeeds silently — no snackbar or feedback is shown. Users may not realize their changes were saved. Add a brief "Labels saved" snackbar (similar to the existing "Line saved" / "Line extended" snackbars) for the label-only confirm path.

**Why discovered:** During CT-59 implementation, the label-only confirm returns `ConfirmSuccess` with empty `insertedMoveIds`, which correctly skips the undo snackbar. But this means zero user feedback. The plan noted this as an optional enhancement (risk #4).
