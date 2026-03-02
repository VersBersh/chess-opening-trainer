- **Verdict** — `Approved with Notes`
- **Issues**
1. **Major — Open/Closed + Hidden Semantic Coupling**  
   In [_MovePill.build()](C:/code/misc/chess-trainer-4/src/lib/widgets/move_pills_widget.dart:103), state styling is still partly hard-coded (`Colors.white` at lines 116/121 and mixed `ColorScheme` text colors at lines 126/132) while only fill/border tokens are theme-driven. Combined with [PillTheme](C:/code/misc/chess-trainer-4/src/lib/theme/pill_theme.dart:8) having just 3 fields, “global adjustment” of pill colors is not truly closed for modification: changing token brightness can force widget-code changes for contrast/readability.  
   Why it matters: visual behavior depends on assumptions outside the theme contract.  
   Suggested fix: move full state styling into abstraction (for example, extend `PillTheme` with text/border tokens per state, or add a resolver API returning a full style object per `(isSaved, isFocused)`).

2. **Minor — Embedded Design Principle (code communicates outdated architecture)**  
   The doc comment says “horizontal row” in [move_pills_widget.dart](C:/code/misc/chess-trainer-4/src/lib/widgets/move_pills_widget.dart:27), but implementation is now `Wrap` at line 65.  
   Why it matters: readers infer the wrong layout model from comments.  
   Suggested fix: update the class-level doc to describe wrapping, non-scrolling pill layout.

3. **Minor — Clean Code File Size Smell (>300 lines)**  
   [add_line_screen.dart](C:/code/misc/chess-trainer-4/src/lib/screens/add_line_screen.dart:1) is 468 lines, and [move_pills_widget_test.dart](C:/code/misc/chess-trainer-4/src/test/widgets/move_pills_widget_test.dart:1) is 353 lines.  
   Why it matters: large files reduce navigability and increase change-coupling risk.  
   Suggested fix: extract `AddLineScreen` dialog/build sections into focused widgets/helpers, and split widget tests into themed groups/files (layout, interactions, styling, fallback behavior).

4. **Minor — DRY / Test Coupling to implementation literals**  
   The same pill hex values are duplicated in [main.dart](C:/code/misc/chess-trainer-4/src/lib/main.dart:56) and test constants in [move_pills_widget_test.dart](C:/code/misc/chess-trainer-4/src/test/widgets/move_pills_widget_test.dart:11).  
   Why it matters: token changes require synchronized edits in multiple places and can create noisy failures.  
   Suggested fix: define a shared default token source (for example, a `pill_theme_defaults.dart`) imported by both app theme setup and tests.