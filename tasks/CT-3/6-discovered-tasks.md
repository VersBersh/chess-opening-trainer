# CT-3 Discovered Tasks

## 1. Android File Picker Testing

- **Suggested ID:** CT-3.1
- **Title:** Manual Android testing for PGN file picker
- **Description:** The import screen uses `withData: true` and prefers `PlatformFile.bytes` over `File(path)`, but this needs manual testing on Android to confirm content URI handling works correctly across different Android versions and file sources (Downloads, Google Drive, etc.).
- **Why discovered:** The plan identified Android content URI as a risk area. Implementation handles it but needs real-device validation.

## 2. extendLine Return Value Enhancement

- **Suggested ID:** CT-2.11
- **Title:** Have `extendLine` return inserted move IDs
- **Description:** During PGN import merge, after calling `extendLine`, the importer must query `getChildMoves` to discover the IDs of newly inserted moves for its in-memory dedup index. If `extendLine` returned the list of inserted move IDs, this extra query could be eliminated.
- **Why discovered:** During implementation, the `extendLine` API didn't return enough information for the importer's dedup tracking.

## 3. Large File Size Warning

- **Suggested ID:** CT-3.2
- **Title:** Add file size warning for large PGN imports
- **Description:** Currently no file size check is performed before import. Add a warning dialog when the selected file exceeds 10MB, and consider implementing streaming/chunking for very large PGN databases.
- **Why discovered:** Plan Step 11 was explicitly deferred. The spec mentions graceful handling of large files.

## 4. Browse Mode Action Bar Overflow

- **Suggested ID:** CT-2.12
- **Title:** Handle action bar overflow on narrow screens
- **Description:** The browse-mode action bar now has 5 buttons (Edit, Import, Label, Focus, Delete). On narrow screens this may overflow. Consider moving less-frequent actions (Import, Delete) to an overflow menu or the AppBar.
- **Why discovered:** Adding the Import button to the action bar increased the button count beyond what comfortably fits on narrow mobile screens.

## 5. PGN Parser Edge Cases with Non-Standard Files

- **Suggested ID:** CT-3.3
- **Title:** Test PGN import with real-world PGN files
- **Description:** The dartchess `parseMultiGamePgn` splits games using a regex that may not handle all PGN formatting variants (missing blank lines between games, unusual header formatting). Test with PGN files from Lichess, Chess.com, TWIC, and other common sources.
- **Why discovered:** Plan Risk #1 identified `parseMultiGamePgn` regex reliability as a concern.
