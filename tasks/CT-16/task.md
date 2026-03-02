---
id: CT-16
title: Responsive Layout Test Coverage
depends: ['CT-6']
specs:
  - design/ui-guidelines.md
files:
  - test/screens/drill_screen_test.dart
  - test/screens/repertoire_browser_screen_test.dart
---
# CT-16: Responsive Layout Test Coverage

**Epic:** none
**Depends on:** CT-6

## Description

Add widget tests for the wide (>= 600px) and narrow (< 600px) layout paths in the drill screen and repertoire browser. Currently all tests run at a fixed narrow viewport — the wide layout code path is entirely untested.

## Acceptance Criteria

- [ ] Widget tests with custom `MediaQuery` for wide viewport (>= 600px)
- [ ] Widget tests for narrow viewport (< 600px) explicitly set
- [ ] Both layout paths render correctly without errors
- [ ] Key interactive elements are accessible in both layouts

## Notes

Discovered during CT-6 test fix phase.
