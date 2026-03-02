# CT-2.12 Context

## Relevant Files

### Specs

- `features/line-management.md` -- Defines the labeling system: labels are optional short name segments on any move node, aggregate display name is computed by walking root-to-leaf and joining labels with " -- ". Labels are free-text with no explicit length constraint in the spec. Risk #7 in CT-2.3 plan identified the need for a max-length constraint.

### Source files (to be modified)

- `src/lib/widgets/inline_label_editor.dart` -- The shared `InlineLabelEditor` widget used by both the Add Line screen and the Repertoire Manager screen. Contains the `TextField` for label input. Currently has no `maxLength` property or input length validation. This is the **primary file to modify** -- adding `maxLength` here enforces the constraint in both screens simultaneously.

### Source files (reference / verification only)

- `src/lib/screens/add_line_screen.dart` -- The Add Line screen. Uses `InlineLabelEditor` at line 369 via `_buildInlineLabelEditor()`. Does not directly construct the `TextField` -- it delegates to `InlineLabelEditor`. No changes needed here since the constraint is applied at the widget level.
- `src/lib/screens/repertoire_browser_screen.dart` -- The Repertoire Manager screen. Uses `InlineLabelEditor` at line 227 via `_buildInlineLabelEditor()`. Same as above -- no changes needed since the widget handles it.
- `src/lib/screens/home_screen.dart` -- Reference for existing `maxLength` pattern. Uses `maxLength: 100` on repertoire name `TextField` at lines 180 and 218. Demonstrates the established convention: Flutter's `TextField.maxLength` shows a built-in character counter and prevents input beyond the limit.
- `src/lib/repositories/local/database.dart` -- Drift schema. The `label` column on `RepertoireMoves` (line 24) is `text().nullable()()` with no length constraint at the database level. SQLite TEXT columns are inherently unbounded. The max-length enforcement happens at the UI layer.
- `src/lib/controllers/add_line_controller.dart` -- Contains `updateLabel()` (line 584) which calls `_repertoireRepo.updateMoveLabel()`. The label value flows from `InlineLabelEditor.onSave` through the controller to the repository. Trimming happens in the editor widget (`_confirmEdit()` at line 86 of `inline_label_editor.dart`), not in the controller.
- `src/lib/controllers/repertoire_browser_controller.dart` -- Contains `editLabel()` (line 264) which calls `_repertoireRepo.updateMoveLabel()`. Same flow as above.
- `src/lib/repositories/repertoire_repository.dart` -- Abstract repository interface with `updateMoveLabel(int moveId, String? label)` at line 17. No validation at the repository layer.
- `src/lib/repositories/local/local_repertoire_repository.dart` -- SQLite implementation of `updateMoveLabel` at line 65. Writes the label value directly to the database with no length check.

### Test files (to be modified)

- `src/test/widgets/inline_label_editor_test.dart` -- Existing widget tests for `InlineLabelEditor`. Contains tests for pre-fill, Enter-to-confirm, clear-to-remove, no-op on unchanged, multi-line warning, double-trigger guard, display name preview, and whitespace trimming. Needs new tests verifying the `maxLength` constraint.

### Test files (reference / verification only)

- `src/test/screens/add_line_screen_test.dart` -- Widget tests for AddLineScreen that exercise label editing via `InlineLabelEditor`. These existing tests enter labels like `'Branch Point'`, `'Leaf Label'`, `'Flipped Label'` -- all well under any reasonable max length. They should pass without modification.
- `src/test/screens/repertoire_browser_screen_test.dart` -- Widget tests for RepertoireBrowserScreen that exercise label editing. Existing tests enter labels like `'Sicilian'`, `'King Pawn'` -- also well under any reasonable max length.
- `src/test/repositories/local_repertoire_repository_test.dart` -- Tests for `updateMoveLabel`. Existing tests use labels like `'Sicilian'`, `'Sicilian Defense'`, `'Test Label'` -- all short.

## Architecture

### Subsystem overview

Label editing flows through a single shared widget (`InlineLabelEditor`) used in two screens:

1. **Add Line screen** -- The user taps a saved pill, re-taps to open the inline editor. The editor calls `AddLineController.updateLabel()`, which calls `RepertoireRepository.updateMoveLabel()`, then rebuilds the tree cache via `loadData()`.

2. **Repertoire Manager screen** -- The user selects a node and taps the Label button (or long-presses a tree node). The editor calls `RepertoireBrowserController.editLabel()`, which calls `RepertoireRepository.updateMoveLabel()`, then rebuilds the tree cache.

In both flows, the `InlineLabelEditor` is the single point of user input for labels. It trims whitespace on save and converts empty strings to `null` (remove label). There is currently no length constraint.

### Key constraints

- **Single enforcement point.** Because both screens use the same `InlineLabelEditor` widget, adding `maxLength` to that widget's `TextField` enforces the constraint everywhere labels can be entered. There is no other UI path for setting labels (PGN import does not set labels).
- **No database migration needed.** SQLite TEXT columns have no inherent length limit. The constraint is purely UI-layer. Existing labels that exceed the new limit (if any exist) will not be truncated -- they simply cannot be extended further. When the user opens the editor for an existing over-length label, they see it in full and can shorten it, but they cannot type beyond the limit.
- **Flutter's built-in maxLength behavior.** Setting `TextField.maxLength` to a value (e.g., 50) causes Flutter to: (a) display a character counter below the field showing `n/50`, (b) prevent additional input once the limit is reached (using `MaxLengthEnforcement.enforced` by default on most platforms), and (c) show the counter in an error color when the limit is reached. This matches the `home_screen.dart` pattern.
- **Existing labels are safe.** The task description notes "existing labels are not truncated or broken by the constraint." This is naturally satisfied: `maxLength` only prevents new input, it does not retroactively modify existing data. If a user has an existing label of 60 characters (unlikely but possible), it will display correctly everywhere. When editing, the TextField will show it in full and the counter will show `60/50` in error color, but the user can shorten it.
