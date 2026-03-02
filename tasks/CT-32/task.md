---
id: CT-32
title: Extract Shared Banner Gap Constant
depends: ['CT-9.1', 'CT-9.4']
specs:
  - design/ui-guidelines.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-32: Extract Shared Banner Gap Constant

**Epic:** none
**Depends on:** CT-9.1, CT-9.4

## Description

CT-9.1 and CT-9.4 both independently add `EdgeInsets.only(top: 8)` for banner gaps. Extract to a shared constant (e.g., `kBannerGap`) in a design-system/theme constants file, and update both screens to reference it.

## Acceptance Criteria

- [ ] Shared constant defined in a theme/constants file
- [ ] Both screens reference the shared constant
- [ ] No hardcoded banner gap values remain

## Notes

Discovered during CT-9.4. Both tasks address the same guideline independently.
