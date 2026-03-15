---
id: CT-66
title: Fix keyboard covering label editor in Add Line on mobile
depends: []
specs:
  - features/add-line.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/widgets/inline_label_editor.dart
---
# CT-66: Fix keyboard covering label editor in Add Line on mobile

**Epic:** none
**Depends on:** none

## Description

On Android (and likely iOS), when the user opens the inline label editor in the Add Line screen, the on-screen keyboard covers the text input so the user cannot see what they are typing.

The narrow layout stacks: board (large) + Expanded(SingleChildScrollView(pills + label editor)) + bottomNavigationBar. When the keyboard opens, the Scaffold shrinks the body but the board still claims most of the vertical space, leaving the Expanded area too small to display the label editor visibly.

Apply the same approach used in CT-55 for Free Practice: detect when the keyboard is open and the label editor is active, and collapse the board with an AnimatedSize to make room for the editor. The board should reappear when the keyboard is dismissed or the label editor is closed.

## Acceptance Criteria

- [ ] Label editor text field is fully visible above the keyboard when editing on mobile
- [ ] Board collapses with animated transition when label editor keyboard is open (narrow layout only)
- [ ] Board reappears when keyboard is dismissed or label editor is closed
- [ ] Wide (desktop/tablet) layout is unaffected
- [ ] Widget test verifying board collapse during label editing on narrow layout

## Notes

Same class of bug as CT-55 (keyboard covering filter input in Free Practice). The InlineLabelEditor already auto-focuses on mount, so the keyboard will open immediately when the editor appears.
