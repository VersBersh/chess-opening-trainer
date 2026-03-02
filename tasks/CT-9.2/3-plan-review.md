**Verdict** — `Approved with Notes`

**Issues**
1. **Minor — Step 6 (`empty list shows no pills` test rationale is inaccurate).**  
   The plan says the current `find.byType(SingleChildScrollView), findsNothing` assertion will break after removing `SingleChildScrollView`, but that assertion already expects none and should still pass.  
   **Suggested fix:** Keep the test focused on behavior (`'Play a move to begin'`, no pill SAN text), and only change it if the widget structure assertion is actually needed.

2. **Minor — Step 3/6 (fallback path is planned but not explicitly validated).**  
   Step 3 correctly proposes a null-safe fallback when `Theme.of(context).extension<PillTheme>()` is absent, and Step 7 depends on that implicitly in `add_line_screen_test.dart` (which does not inject `PillTheme`). But no explicit test is added for this fallback contract.  
   **Suggested fix:** Add a small widget test that builds `MovePillsWidget` without `ThemeData.extensions` and verifies it renders without exceptions.