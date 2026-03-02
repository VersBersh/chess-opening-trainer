---
id: CT-2.12
title: Label Validation / Max Length
epic: CT-2
depends: ['CT-2.3']
specs:
  - features/line-management.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-2.12: Label Validation / Max Length

**Epic:** CT-2
**Depends on:** CT-2.3

## Description

Add `TextField.maxLength` (e.g., 50 characters) to label input to prevent excessively long labels that break UI layout. Currently labels are free-text with no validation beyond whitespace trimming.

## Acceptance Criteria

- [ ] Label text field has a maxLength constraint
- [ ] Excessively long labels are prevented at input time
- [ ] Existing labels are not truncated or broken by the constraint

## Notes

Discovered during CT-2.3. Plan Risk #7. No constraint was specified in the original spec, but UX testing may reveal the need.
