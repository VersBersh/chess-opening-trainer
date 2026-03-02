---
id: CT-15.3
title: DRY up action bar compact/full-width duplication
epic: CT-15
depends: []
specs:
  - features/repertoire-browser.md
  - design/ui-guidelines.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-15.3: DRY up action bar compact/full-width duplication

**Epic:** CT-15
**Depends on:** none

## Description

The `_buildBrowseModeActionBar` method defines the same 5 actions (Add Line, Import, Label, Stats, Delete) twice — once as `IconButton`s and once as `TextButton.icon`. Define a shared action model (icon, label, enabled, handler) and render with two layout adapters. This reduces drift risk when adding or changing actions.

## Acceptance Criteria

- [ ] Shared action model defines each action once
- [ ] Compact layout renders IconButtons from the model
- [ ] Full-width layout renders TextButton.icon from the model
- [ ] No behavioral change — visual output identical
- [ ] Adding a new action requires a single definition, not two

## Notes

Discovered during CT-7.3 code review. Flagged as DRY violation.
