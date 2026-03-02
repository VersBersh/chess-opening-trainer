---
id: CT-31
title: Browse Mode Action Bar Overflow
depends: ['CT-3']
specs:
  - design/ui-guidelines.md
  - features/repertoire-browser.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-31: Browse Mode Action Bar Overflow

**Epic:** none
**Depends on:** CT-3

## Description

The browse-mode action bar has 5 buttons (Edit, Import, Label, Focus, Delete). On narrow screens this may overflow. Consider moving less-frequent actions (Import, Delete) to an overflow menu or the AppBar.

## Acceptance Criteria

- [ ] Action bar renders correctly on narrow screens (320dp width)
- [ ] Less-frequent actions accessible via overflow menu or similar
- [ ] No truncation or visual overflow of buttons
- [ ] Behavior unchanged on wider screens

## Notes

Discovered during CT-3. Adding the Import button pushed the count beyond comfortable narrow-screen limits.
