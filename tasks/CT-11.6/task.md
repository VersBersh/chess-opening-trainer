---
id: CT-11.6
title: Equal-width pills
epic: CT-11
depends: []
specs:
  - features/add-line.md
  - design/ui-guidelines.md
files:
  - src/lib/widgets/move_pills_widget.dart
---
# CT-11.6: Equal-width pills

**Epic:** CT-11
**Depends on:** none

## Description

Move pills currently have variable width based on the SAN text (e.g., "e4" is narrower than "Nxd4"). This looks untidy. Make all pills the same width for a clean, uniform appearance.

## Acceptance Criteria

- [ ] All move pills have the same width, regardless of SAN text length
- [ ] The width accommodates the longest common SAN notation (e.g., "Nxd4+", "Qxe7#") without truncation
- [ ] Short SAN text (e.g., "e4") is centered within the pill
- [ ] The equal-width layout works correctly with the wrapping behavior (pills still wrap at row boundaries)
- [ ] The uniform width provides a clean grid-like appearance

## Notes

The pill width should be set to accommodate the longest realistic SAN move. Extremely rare long notations (e.g., "Qxa8=R+") can be handled with a slightly reduced font size or allowing a small overflow, but the pill width should not be driven by edge cases.
