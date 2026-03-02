**Verdict** — Needs Fixes

**Progress**
- [x] Step 1 (`withData: true` in import screen) — **Done**
- [ ] Step 2 (PGN normalization in importer) — **Partially done** (implemented, but introduces a parsing regression)
- [x] Step 3 (real-world PGN normalization tests) — **Done** (7 tests added)
- [ ] Step 4 (widget test + `FilePicker.platform` restore) — **Partially done** (`withData` assertion added, restore pattern missing)
- [x] Step 5 (manual testing requirements documented as post-merge) — **Done** (in impl notes)

**Issues**
1. **Critical** — Over-broad normalization can split a single game's header block into multiple games.  
   Files/lines: [pgn_importer.dart](/C:/code/misc/chess-trainer-4/src/lib/services/pgn_importer.dart:537), [pgn_importer.dart](/C:/code/misc/chess-trainer-4/src/lib/services/pgn_importer.dart:541)  
   Problem: `RegExp(r'(?<!\n)\n(\[)')` matches `\n[` between normal PGN header lines (`[Event]` then `[Site]`), inserts blank lines, and can cause `parseMultiGamePgn` to split within one game.  
   Suggested fix: Restrict pass 2 to actual game boundaries (movetext -> next header), not generic `\n[`. At minimum, avoid header-header boundaries (e.g., guard against preceding `]`), and add a test with multi-header single-game PGN to prevent regression.

2. **Major** — `FilePicker.platform` global override is not restored in test groups, contrary to plan and test hygiene requirements.  
   Files/lines: [import_screen_test.dart](/C:/code/misc/chess-trainer-4/src/test/screens/import_screen_test.dart:269), [import_screen_test.dart](/C:/code/misc/chess-trainer-4/src/test/screens/import_screen_test.dart:361)  
   Problem: Both `'File size warning'` and `'File picker withData'` set `FilePicker.platform = fakePicker` but do not restore original platform in `tearDown`. This can leak global state and create order-dependent failures.  
   Suggested fix: Save `originalPlatform` in `setUp` and restore in group `tearDown` for both groups (or combine into one group with shared setup/teardown).

3. **Minor** — Unplanned modified generated Windows files are present with no functional diff.  
   Files: [generated_plugin_registrant.cc](/C:/code/misc/chess-trainer-4/src/windows/flutter/generated_plugin_registrant.cc), [generated_plugin_registrant.h](/C:/code/misc/chess-trainer-4/src/windows/flutter/generated_plugin_registrant.h), [generated_plugins.cmake](/C:/code/misc/chess-trainer-4/src/windows/flutter/generated_plugins.cmake)  
   Problem: These are outside CT-29 scope and appear to be line-ending/metadata churn.  
   Suggested fix: Exclude from this task’s commit unless intentionally required by a dependency/plugin change.