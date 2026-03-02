---
id: CT-33
title: Inline Label Icon QA on Devices
depends: ['CT-9.5']
files:
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-33: Inline Label Icon QA on Devices

**Epic:** none
**Depends on:** CT-9.5

## Description

Verify inline label icon tap targets and visual crowding on physical devices. The `GestureDetector` approach (replacing `IconButton`) has no enforced minimum tap target. Check on phone-sized screens that:
1. The label icon is easily tappable
2. Tapping the icon doesn't accidentally trigger row selection
3. The added icon doesn't cause excessive text truncation on deeply indented nodes

## Acceptance Criteria

- [ ] Label icon comfortably tappable on phone screens
- [ ] No accidental row selection when tapping the icon
- [ ] No excessive text truncation on deep nodes
- [ ] If issues found, document and fix tap target size

## Notes

Discovered during CT-9.5. The `IconButton` approach was replaced with `GestureDetector` for compact layout, trading enforced tap target size.
