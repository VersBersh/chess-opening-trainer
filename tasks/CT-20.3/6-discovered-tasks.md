# Discovered Tasks

## CT-20.6: Extract shared test helpers from repository test files

**Title:** Extract shared test helpers into a common test fixture module

**Description:** Both `local_review_repository_test.dart` and `local_repertoire_repository_test.dart` contain independent copies of `createTestDatabase` and `seedLineWithCard`. Extract these into a shared `test/helpers/` module to reduce duplication and make future test files easier to set up.

**Why discovered:** During CT-20.3 implementation, the design review flagged the test file at 674 lines (above the 300-line threshold) and noted meaningful duplication of setup helpers across repository test files. Consolidating helpers would reduce file sizes and improve maintainability.
