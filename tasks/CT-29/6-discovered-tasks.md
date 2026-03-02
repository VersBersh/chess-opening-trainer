# CT-29: Discovered Tasks

## CT-29.1: Manual Android File Picker Testing

**Title:** Manual Android File Picker Testing
**Description:** Test PGN file import on at least 2 Android versions using files from Downloads and Google Drive. Verify that `withData: true` correctly provides `file.bytes` for content URIs across Android 10+ (scoped storage) and Android 11+ (enforced scoped storage).
**Why discovered:** CT-29 acceptance criteria require manual device testing that cannot be automated in the CI pipeline.

## CT-29.2: Real-World PGN File Compatibility Testing

**Title:** Real-World PGN File Compatibility Testing
**Description:** Import PGN exports from Lichess (game export, study export), Chess.com (game archive), and TWIC (weekly database). Document number of games detected, imported, and any parser errors. Fix any formatting variants not handled by the normalization step.
**Why discovered:** CT-29 acceptance criteria require testing with real-world PGN files. The normalization handles known variants (missing blank lines, CRLF, BOM) but novel formatting may surface.
