---
id: CT-51.6
title: Flip board + confirm silently truncates line instead of showing parity warning (Add Line)
epic: CT-51
depends: []
specs:
  - features/add-line.md
files: []
---
# CT-51.6: Flip board + confirm silently truncates line instead of showing parity warning

**Epic:** CT-51
**Depends on:** none

## Description

When the user has a valid white line (ending on a white move) in the Add Line screen, flips the board to black orientation, and then presses Confirm, the app silently removes the last white move and saves a shorter line instead of showing the parity-mismatch warning. The buffer must never be modified as a side effect of flipping; the warning must always be shown instead.

## Acceptance Criteria

- [ ] Flipping the board never removes, truncates, or modifies the in-memory move buffer.
- [ ] On confirm with a parity mismatch, the inline warning is shown regardless of how the user arrived at the mismatch (including via board flip).
- [ ] No moves are silently saved or removed during the confirm + parity-mismatch path.
- [ ] After dismissing or ignoring the warning, the full original line is still present in the builder.

## Notes

See updated Board Orientation and Color section and Confirmation Behavior section in features/add-line.md.
