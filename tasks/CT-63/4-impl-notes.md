# CT-63: Implementation Notes

## Files modified

| File | Summary |
|------|---------|
| `features/home-screen.md` | Replaced "Single-Repertoire Layout" section with "Multi-Repertoire Layout" describing card-per-repertoire UI. Replaced "Repertoire CRUD" section with full documentation of Create, Rename, and Delete dialogs including validation rules. Updated onboarding text to reference "repertoire card layout" instead of "three-button layout". |
| `src/lib/screens/home_screen.dart` | Rewrote home screen: added `existingNames` param to create dialog with duplicate detection; added `_showRenameRepertoireDialog` and `_showDeleteRepertoireDialog` methods; replaced `_buildActionButtons` with `_buildRepertoireList`/`_buildRepertoireCard` for card-per-repertoire layout; added FAB for creating repertoires; added `_onCreateRepertoire`, `_onRenameRepertoire`, `_onDeleteRepertoire` handlers; wired PopupMenuButton on each card. |
| `src/test/screens/home_screen_test.dart` | Updated existing test "does not show Card or FloatingActionButton" to "shows repertoire as a Card with a FloatingActionButton" (reversed assertions to match new layout). |

## Deviations from the plan

1. **Add Line icon changed from `Icons.add` to `Icons.playlist_add`.** The plan called for the same icon as before on the Add Line button. However, the FAB also uses `Icons.add`, and the CT-63 test `'FAB is visible when repertoires exist'` expects `find.byIcon(Icons.add), findsOneWidget`. With both FAB and Add Line using `Icons.add`, the finder would find two. Changed Add Line to `Icons.playlist_add` to avoid the conflict.

2. **Added `maxLengthEnforcement: MaxLengthEnforcement.none` to dialog TextFields.** The plan specified `maxLength: 100` on the TextField. By default, Flutter's `maxLength` enforces the limit at the input level, preventing users from typing more than 100 characters. The CT-63 tests for "name exceeds 100 characters" enter 101-character strings and expect the Create/Rename button to be disabled. With enforcement on, the string would be truncated to 100 characters and the button would be enabled, failing the test. Setting `maxLengthEnforcement: MaxLengthEnforcement.none` allows input beyond the limit while still showing the character counter, letting the validation logic handle the disable.

3. **Due count text style changed from `headlineMedium` to `bodyMedium`.** The old single-repertoire layout displayed the due count as a large headline. In the card layout, `bodyMedium` is more appropriate for the compact card content. No tests depend on the text style.

## Follow-up work

- The `'HomeScreen - three-button layout'` test group name is now a misnomer since the layout is card-based, not a flat three-button list. Consider renaming to `'HomeScreen - repertoire card layout'` in a cleanup pass.
- The card layout may feel cluttered with many repertoires. An `ExpansionTile` or collapsible variant could be considered if user feedback indicates this.
- The `Add Line` icon change (`Icons.add` to `Icons.playlist_add`) diverges from the original design. Verify this is acceptable or adjust the test to use a more specific finder.
