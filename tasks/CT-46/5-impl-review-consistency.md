- **Verdict** — Needs Fixes

- **Progress**
  - [x] Step 1: Define shared label constants in `spacing.dart` — **Done**
  - [x] Step 2: Restyle `BrowserDisplayNameHeader` in `browser_board_panel.dart` — **Done**
  - [x] Step 3: Move label below board in narrow browser layout — **Done**
  - [x] Step 4: Move label below board in wide browser layout — **Done**
  - [x] Step 5: Adjust drill screen label to always reserve space — **Done**
  - [ ] Step 6: Update tests for always-present reserved label area + empty-text behavior — **Partially done**

- **Issues**
  1. **Major** — Drill unlabeled tests still validate old key-based behavior instead of the planned reserved-space behavior.  
     References: [src/test/screens/drill_screen_test.dart:939](C:/code/misc/chess-trainer-1/src/test/screens/drill_screen_test.dart:939), [src/test/screens/drill_screen_test.dart:952](C:/code/misc/chess-trainer-1/src/test/screens/drill_screen_test.dart:952), [src/test/screens/drill_screen_test.dart:1742](C:/code/misc/chess-trainer-1/src/test/screens/drill_screen_test.dart:1742), [src/test/screens/drill_screen_test.dart:1761](C:/code/misc/chess-trainer-1/src/test/screens/drill_screen_test.dart:1761)  
     What’s wrong: These tests were renamed but still only assert `find.byKey('drill-line-label') == findsNothing`. That does not verify the new requirement that the label area always reserves vertical space when unlabeled.  
     Suggested fix: Add assertions that confirm reserved space exists even when text is empty (for example, assert a fixed-height container/widget predicate below the board, or assert layout spacing between board and status region includes `kLineLabelHeight`).

  2. **Minor** — Browser unlabeled-case test doesn’t assert text absence, only header presence.  
     References: [src/test/screens/repertoire_browser_screen_test.dart:238](C:/code/misc/chess-trainer-1/src/test/screens/repertoire_browser_screen_test.dart:238), [src/test/screens/repertoire_browser_screen_test.dart:256](C:/code/misc/chess-trainer-1/src/test/screens/repertoire_browser_screen_test.dart:256)  
     What’s wrong: Plan calls for asserting both “header area always rendered” and “label text absent when display name is empty.” Current test only checks header presence.  
     Suggested fix: Add an assertion that no text is rendered within `BrowserDisplayNameHeader` for the unlabeled selection (e.g., no `Text` descendant in header or no expected label string present).