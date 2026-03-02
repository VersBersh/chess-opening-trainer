# 6-discovered-tasks.md

## Discovered Tasks

### CT-7.7: Split move pills test file into focused groups

- **Title:** Split move_pills_widget_test.dart into focused test files
- **Description:** The test file is 410 lines and growing. Split into separate files for rendering/style tests vs accessibility/semantics tests to improve readability.
- **Why discovered:** Both code reviews flagged the file size (>300 lines) as a code smell. Adding the 3 new accessibility tests pushed it further past the threshold.
