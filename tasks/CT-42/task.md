---
id: CT-42
title: "Unify pill colors (saved and unsaved look identical)"
depends: []
specs:
  - features/add-line.md
  - design/ui-guidelines.md
files:
  - src/lib/theme/pill_theme.dart
  - src/lib/widgets/move_pills_widget.dart
---
# CT-42: Unify pill colors (saved and unsaved look identical)

**Epic:** none
**Depends on:** none

## Description

Currently, saved and unsaved move pills have different background colors (e.g., saved is a darker blue, unsaved is a lighter/muted blue). Remove this distinction so all pills use the same styling regardless of save state.

## Acceptance Criteria

- [ ] Saved and unsaved pills render with the same background color, text color, and border
- [ ] The `unsavedColor` property in `PillTheme` is removed (or both properties resolve to the same value)
- [ ] The `isSaved` flag on `MovePillData` no longer influences pill styling (it may still exist for other logic)
- [ ] Focused-pill highlighting still works as before
- [ ] Both light and dark themes are updated

## Notes

- `PillTheme` (pill_theme.dart) defines `savedColor` and `unsavedColor` with distinct values for light and dark modes.
- `_MovePill` in move_pills_widget.dart picks the color based on `isSaved`. Simplify this to always use the single pill color.
- The `isSaved` boolean on `MovePillData` is also used by label display logic and the Label button, so don't remove the field itself — just stop using it for color selection.
