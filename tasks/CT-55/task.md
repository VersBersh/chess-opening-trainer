---
id: CT-55
title: Fix keyboard covering filter input in Free Practice on mobile
depends: []
specs:
  - features/free-practice.md
files: []
---
# CT-55: Fix keyboard covering filter input in Free Practice on mobile

**Epic:** none
**Depends on:** none

## Description

In Free Practice mode, when the user taps the filter input box to type a line name, the on-screen keyboard pops up and covers both the input box and the dropdown suggestions. The user cannot see what they are typing or select from the filtered results.

**New behavior:** When the filter input is focused (keyboard is open), the layout should adapt so that the input box and dropdown are visible above the keyboard. One approach: temporarily hide the board to shift the filter to the top of the screen, making room for both the typed text and the dropdown list. Once the user selects a filter or dismisses the keyboard, the board reappears.

### Spec updates required

**`features/free-practice.md`** — In the Inline Filter section, add a subsection for mobile keyboard handling:
- When the filter input gains focus and the soft keyboard is visible, the layout must ensure the input field and suggestion dropdown remain fully visible.
- One approach: temporarily collapse or hide the board while the keyboard is open, repositioning the filter near the top of the screen.
- Once a filter is selected or the keyboard is dismissed, the board is restored to its normal position.
- The filter dropdown direction guidance (prefer upward) may need revisiting if the board is hidden — with more vertical space available, the dropdown can open downward.

## Acceptance Criteria

- [ ] Update `features/free-practice.md` Inline Filter section with mobile keyboard handling requirements
- [ ] When the filter input is focused on mobile, the input and dropdown are fully visible above the keyboard
- [ ] User can see what they are typing in the filter
- [ ] User can see and select from the dropdown suggestions
- [ ] When the filter is dismissed or a selection is made, the board returns to its normal layout
- [ ] Desktop behavior is unaffected (no board hiding needed when there is no soft keyboard)

## Notes

- `MediaQuery.of(context).viewInsets.bottom` can detect keyboard height in Flutter.
- Alternatively, wrapping the screen in a `SingleChildScrollView` with `reverse: true` might auto-scroll to keep the input visible, but this may not be sufficient if the board takes most of the screen height.
- The cleanest UX is probably to hide the board entirely when the keyboard opens, since the user doesn't need the board while filtering — they need to see the text field and results.
- Consider an `AnimatedSwitcher` or similar transition so the board doesn't just pop in/out abruptly.
