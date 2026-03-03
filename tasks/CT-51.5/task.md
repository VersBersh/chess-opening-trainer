---
id: CT-51.5
title: Line-saved feedback not dismissed on new line start (Add Line)
epic: CT-51
depends: []
specs:
  - features/add-line.md
files: []
---
# CT-51.5: Line-saved feedback not dismissed on new line start (Add Line)

**Epic:** CT-51
**Depends on:** none

## Description

After confirming a line, the "line extended/saved" feedback message persists indefinitely. It should be dismissed when the user starts entering a new line on the same screen (plays the first move of a new sequence).

## Acceptance Criteria

- [ ] The "line saved/extended" feedback message is automatically dismissed when the user makes their first move after a successful confirm (i.e. begins a new line).
- [ ] The feedback is still dismissed on route navigation (existing behaviour).
- [ ] The 4–6 second auto-dismiss timer (from existing spec) continues to apply.

## Notes

See updated Undo Feedback Lifetime section in features/add-line.md.
