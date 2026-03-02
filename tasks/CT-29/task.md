---
id: CT-29
title: PGN Import — Android File Picker & Real-World Testing
depends: ['CT-3']
files:
  - src/lib/screens/pgn_import_screen.dart
---
# CT-29: PGN Import — Android File Picker & Real-World Testing

**Epic:** none
**Depends on:** CT-3

## Description

Two testing tasks for PGN import:

1. **Android file picker:** Manual testing on Android to confirm content URI handling works correctly across different Android versions and file sources (Downloads, Google Drive, etc.). The import uses `withData: true` and prefers `PlatformFile.bytes` over `File(path)`.

2. **Real-world PGN files:** Test with files from Lichess, Chess.com, TWIC, and other common sources. The `parseMultiGamePgn` regex may not handle all formatting variants (missing blank lines, unusual headers).

## Acceptance Criteria

- [ ] Tested on at least 2 Android versions with files from Downloads and Google Drive
- [ ] Tested with PGN exports from Lichess, Chess.com, and at least one database (TWIC or similar)
- [ ] Any parser failures documented and fixed

## Notes

Discovered during CT-3. Plan identified Android content URI and parser regex as risk areas.
