---
id: CT-14
title: Dark Theme Support
depends: ['CT-6']
specs:
  - design/ui-guidelines.md
files:
  - src/lib/main.dart
  - src/lib/screens/settings_screen.dart
---
# CT-14: Dark Theme Support

**Epic:** none
**Depends on:** CT-6

## Description

Add dark theme and user-selectable theme mode. Add `darkTheme` to `MaterialApp`, create an `appThemeModeProvider` backed by SharedPreferences, add a theme-mode picker (light/dark/system) to the settings screen, and audit hardcoded colors (e.g., `Colors.red`, `Colors.green` in drill feedback) for dark-mode compatibility.

## Acceptance Criteria

- [ ] `darkTheme` defined in `MaterialApp`
- [ ] `appThemeModeProvider` backed by SharedPreferences (light/dark/system)
- [ ] Theme-mode picker on the settings screen
- [ ] Hardcoded colors audited and replaced with theme-aware alternatives
- [ ] Drill feedback colors (red/green) work in both light and dark mode

## Notes

Discovered during CT-6 (Settings & Theme Audit). Deferred because it requires its own state model, provider, storage keys, settings UI, and tests — mixing it with the styling cleanup created scope risk.
