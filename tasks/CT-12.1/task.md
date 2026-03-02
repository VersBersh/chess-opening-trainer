---
id: CT-12.1
title: Always seed review cards in debug mode
epic: CT-12
depends: []
specs:
  - architecture/testing-strategy.md
files:
  - src/lib/main.dart
---
# CT-12.1: Always seed review cards in debug mode

**Epic:** CT-12
**Depends on:** none

## Description

When starting the app in debug mode, always ensure some review cards are available for testing drill mode. The current dev seed function may not always create due cards (e.g., if seed data has already been inserted with future review dates). Ensure that on every debug startup, there are cards with `next_review_date <= today` so drill mode can be tested immediately.

## Acceptance Criteria

- [ ] In debug mode, the app always has at least some review cards due for review on startup
- [ ] If seed data already exists, update the `next_review_date` of existing cards to make some due today
- [ ] If no seed data exists, create the standard seed repertoire with due cards
- [ ] The seed behavior does not affect release/production builds
- [ ] Drill mode can be entered immediately after a debug launch without manual data setup

## Notes

The dev seed function was established in CT-1 (Phase 2) as temporary scaffolding. This task ensures it remains useful for ongoing development. The key change is making the seed idempotent and always resulting in due cards, not just inserting data once.
