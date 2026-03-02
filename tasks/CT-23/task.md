---
id: CT-23
title: Add Orphan Dialog Dismiss Test
depends: ['CT-2.4']
files:
  - test/screens/repertoire_browser_screen_test.dart
---
# CT-23: Add Orphan Dialog Dismiss Test

**Epic:** none
**Depends on:** CT-2.4

## Description

Add a widget test that verifies: when the orphan prompt is dismissed (e.g., via system back), the orphaned move is preserved (not deleted). This tests the post-review fix for the Critical null-result bug where null dialog result was treated as delete.

## Acceptance Criteria

- [ ] Test: dismissing orphan dialog (null result) preserves the orphaned move
- [ ] The move is not deleted when dialog is dismissed without selection

## Notes

Discovered during CT-2.4. The Critical bug fix was added during code review but has no dedicated test.
