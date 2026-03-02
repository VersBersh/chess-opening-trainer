---
id: CT-20
title: Extract Shared Test Fakes
depends: []
files:
  - test/screens/drill_screen_test.dart
  - test/screens/home_screen_test.dart
  - test/helpers/fake_repositories.dart
---
# CT-20: Extract Shared Test Fakes

**Epic:** none
**Depends on:** none

## Description

`FakeRepertoireRepository` and `FakeReviewRepository` are duplicated across test files (with slight differences). Extract them into a shared `test/helpers/fake_repositories.dart` file to reduce duplication and prevent drift.

## Acceptance Criteria

- [ ] Shared fake repositories in `test/helpers/fake_repositories.dart`
- [ ] All test files use the shared fakes
- [ ] No duplicate fake implementations remain
- [ ] All existing tests pass

## Notes

Discovered during CT-1.4. Duplication was chosen for speed but should be cleaned up.
