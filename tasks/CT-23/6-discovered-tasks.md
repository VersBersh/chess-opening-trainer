# CT-23 Discovered Tasks

1. **CT-24: Add controller-level unit test for orphan dialog null dismiss**
   - **Title:** Add handleOrphans null-result unit test
   - **Description:** Add a unit test in `test/controllers/repertoire_browser_controller_test.dart` that verifies `handleOrphans` correctly breaks out of the loop when the `promptUser` callback returns `null`. The existing test group covers `keepShorterLine` and `removeMove` choices but not the null/dismiss case.
   - **Why discovered:** During CT-23 implementation, the widget test covers the null-dismiss path end-to-end, but the controller-level unit test is missing. A companion test would provide faster, isolated coverage of the bug fix at line 304 of `repertoire_browser_controller.dart`.
