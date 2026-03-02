---
id: CT-10.3
title: "Keep Going" button after all cards reviewed
epic: CT-10
depends: ['CT-10.1']
specs:
  - features/free-practice.md
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/services/drill_engine.dart
---
# CT-10.3: "Keep Going" button after all cards reviewed

**Epic:** CT-10
**Depends on:** CT-10.1

## Description

In Free Practice mode, when all cards in the current set have been reviewed, show a "Keep Going" button instead of ending the session. This allows the user to continue studying the same cards indefinitely.

## Acceptance Criteria

- [ ] When all cards in the Free Practice session have been reviewed, a "Keep Going" button is displayed
- [ ] Tapping "Keep Going" reshuffles the same card set and starts a new pass
- [ ] The user can keep going indefinitely (no limit on passes)
- [ ] The session only ends when the user explicitly exits (navigates away)
- [ ] The "Keep Going" button is only shown in Free Practice mode — regular Drill mode still ends normally after all due cards
- [ ] The progress indicator resets appropriately for each new pass

## Notes

This supports cramming and deep practice use cases. The "Keep Going" flow should feel seamless — minimal delay between tapping the button and the next card appearing.
