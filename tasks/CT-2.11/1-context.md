# CT-2.11: Transposition Conflict Warning — Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` — in-memory indexed view of the move tree. Contains `movesByFen` map and `getMovesAtPosition(fen)` for O(1) FEN lookups. Also has `movesByPositionKey` and `normalizePositionKey()` for transposition-aware matching (strips halfmove/fullmove clocks). |
| `src/lib/widgets/inline_label_editor.dart` | `InlineLabelEditor` widget — the shared inline editor used by both AddLine and Browser screens. Receives `onSave` callback, triggers label persistence. This is where the user types and confirms a label. |
| `src/lib/controllers/add_line_controller.dart` | `AddLineController` — business logic for the Add Line screen. Has `updateLabel(pillIndex, label)` which calls `_repertoireRepo.updateMoveLabel()` then `loadData()`. Holds the `RepertoireTreeCache` in state. |
| `src/lib/controllers/repertoire_browser_controller.dart` | `RepertoireBrowserController` — business logic for the Repertoire Browser screen. Has `editLabel(moveId, label)` which calls `_repertoireRepo.updateMoveLabel()` then `loadData()`. Holds the `RepertoireTreeCache` in state. |
| `src/lib/screens/add_line_screen.dart` | `AddLineScreen` — UI for line entry. Wires `InlineLabelEditor.onSave` to `_controller.updateLabel()`. Shows the label editor when a saved pill is re-tapped. |
| `src/lib/screens/repertoire_browser_screen.dart` | `RepertoireBrowserScreen` — UI for browsing/managing the repertoire. Wires `InlineLabelEditor.onSave` to `_controller.editLabel()`. Shows the label editor when the user taps the label action on a selected node. |
| `src/lib/widgets/repertoire_dialogs.dart` | Shared dialog functions used by the browser screen (delete confirmation, branch delete, orphan prompt, card stats). Provides the dialog pattern to follow. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract `RepertoireRepository` interface — defines `updateMoveLabel()`, `getMovesAtPosition()`, `getMovesForRepertoire()`. |
| `src/lib/repositories/local/local_repertoire_repository.dart` | `LocalRepertoireRepository` — concrete Drift/SQLite implementation. `updateMoveLabel()` writes a single column update. |
| `src/lib/repositories/local/database.dart` | Drift database schema — defines `RepertoireMoves` table with `fen`, `san`, `label` columns. |
| `src/test/controllers/add_line_controller_test.dart` | Tests for `AddLineController` including the existing `updateLabel` test. |
| `src/test/controllers/repertoire_browser_controller_test.dart` | Tests for `RepertoireBrowserController` including the existing `editLabel` test. |
| `features/line-management.md` | Spec for labeling, including the "Transposition Label Conflict Warning" section — advisory, non-blocking, shows conflicting labels at same FEN. |
| `architecture/models.md` | Documents `RepertoireTreeCache` structure including `moves_by_fen` map. |

## Architecture

### Label Save Flow

Labeling a position follows a two-step pattern in both screens:

1. **UI layer** — `InlineLabelEditor` collects the label text. On confirm (Enter key or focus loss), it calls `onSave(label)`, an async callback.
2. **Controller layer** — The callback delegates to either `AddLineController.updateLabel(pillIndex, label)` or `RepertoireBrowserController.editLabel(moveId, label)`. Both call `_repertoireRepo.updateMoveLabel(moveId, label)` to persist, then `loadData()` to rebuild the tree cache.

The `InlineLabelEditor` itself has no knowledge of transpositions or conflicts. It simply calls `onSave` and waits for the future to complete (or fail). On success, it calls `onClose()` to dismiss itself.

### FEN Lookup for Transposition Detection

`RepertoireTreeCache` maintains two FEN-indexed maps:
- `movesByFen` (`Map<String, List<RepertoireMove>>`) — keyed by full FEN string. Used by `getMovesAtPosition(fen)`.
- `movesByPositionKey` (`Map<String, List<RepertoireMove>>`) — keyed by normalized FEN (first 4 fields only, stripping halfmove/fullmove clocks). Used for transposition-aware sibling detection in the drill engine.

For label conflict detection, `movesByFen` (exact FEN match) is the appropriate map — if the same exact position is reached via different move orders, those nodes will share the same FEN and appear in the same list. The `movesByPositionKey` variant is a looser match (ignoring move counters) which could also be used, but the spec says "same FEN position" so `getMovesAtPosition(fen)` is the right choice.

### Dialog Conventions

The app uses `showDialog<T>()` with `AlertDialog` for all confirmation/warning dialogs. The pattern is:
- A free function in `repertoire_dialogs.dart` (for browser) or an inline `_show*Dialog` method on the screen state (for AddLine).
- Returns `Future<T?>` where `T` encodes the user's choice (bool, enum, or void).
- Cancel/dismiss returns `null` or `false`; confirm returns `true` or a specific value.

### Key Constraints

- The warning is **advisory and non-blocking** per the spec. The user can always proceed with their chosen label.
- The warning should appear **before** the label is persisted, so the user can cancel.
- Both screens (AddLine and Browser) need this warning since both allow label editing.
- The tree cache is already available in both controllers' state when label editing occurs — no additional data loading is needed.
