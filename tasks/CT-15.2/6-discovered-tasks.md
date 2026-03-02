# CT-15.2: Discovered Tasks

## CT-16: Extract shared test helpers

**Title:** Extract duplicated test helpers to shared utility file

**Description:** `sanToNormalMove`, `seedRepertoire`, `getMoveIdBySan`, and `createTestDatabase` are duplicated between `add_line_controller_test.dart` and `add_line_screen_test.dart`. Extract them to a shared file (e.g., `test/helpers/chess_test_utils.dart`) to reduce duplication and make future test files easier to set up.

**Why discovered:** During CT-15.2 implementation, `sanToNormalMove` was copied from the controller test file into the widget test file, adding to existing duplication of `seedRepertoire`, `getMoveIdBySan`, and `createTestDatabase`.
