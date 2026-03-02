# CT-7.2: Context

## Relevant Files

### Specs

- `features/add-line.md` — Spec for the Add Line screen: layout, move pills, entry flow, board orientation, aggregate name preview, and branching behavior.
- `features/line-management.md` — Spec for line entry mechanics: in-memory buffer, confirm-to-save, take-back, parity validation, branching, card creation, extension/undo, labeling, and orphan handling.

### Source files (to be created)

- `src/lib/screens/add_line_screen.dart` — New: the Add Line screen widget, wiring the controller, chessboard, move pills, action bar, and dialogs.
- `src/lib/controllers/add_line_controller.dart` — New: core business logic controller for the Add Line screen.

### Source files (primary references)

- `src/lib/screens/repertoire_browser_screen.dart` — Existing screen with edit-mode line entry flow (to be replaced). Contains edit-mode handlers, parity/discard/label dialogs, persistence logic. Primary extraction source.
- `src/lib/services/line_entry_engine.dart` — Pure business-logic service (`LineEntryEngine`) tracking existing path, followed moves, and buffered moves. Provides `acceptMove`, `canTakeBack`, `takeBack`, `validateParity`, `getConfirmData`, `getCurrentDisplayName`, `hasNewMoves`.
- `src/lib/widgets/move_pills_widget.dart` — CT-7.1 deliverable: `MovePillData` data class and `MovePillsWidget` stateless widget.
- `src/lib/widgets/chessboard_widget.dart` — Reusable chessboard widget wrapping chessground+dartchess.
- `src/lib/widgets/chessboard_controller.dart` — `ChangeNotifier`-based controller managing position state.

### Source files (reference only)

- `src/lib/models/repertoire.dart` — `RepertoireTreeCache` with `getLine`, `getChildren`, `getRootMoves`, `isLeaf`, `getAggregateDisplayName`, `previewAggregateDisplayName`.
- `src/lib/repositories/local/database.dart` — Drift schema: `Repertoires`, `RepertoireMoves`, `ReviewCards` tables.
- `src/lib/repositories/repertoire_repository.dart` — Abstract `RepertoireRepository` interface.
- `src/lib/repositories/review_repository.dart` — Abstract `ReviewRepository` interface.
- `src/lib/repositories/local/local_repertoire_repository.dart` — Concrete Drift-based `RepertoireRepository`.
- `src/lib/repositories/local/local_review_repository.dart` — Concrete Drift-based `ReviewRepository`.
- `src/lib/providers.dart` — Riverpod providers: `repertoireRepositoryProvider`, `reviewRepositoryProvider`.
- `src/lib/main.dart` — App entry point, route structure.
- `src/lib/screens/home_screen.dart` — Home screen, navigation patterns.
- `src/lib/screens/drill_screen.dart` — Reference for Riverpod AsyncNotifier + sealed state pattern.
- `src/lib/services/chess_utils.dart` — `sanToMove` utility.

### Test files

- `src/test/screens/repertoire_browser_screen_test.dart` — Test patterns: `createTestDatabase()`, `seedRepertoire()`, `buildTestApp()`, in-memory Drift DB.
- `src/test/services/line_entry_engine_test.dart` — Test helpers: `buildLine()`, `buildLineWithLabel()`, `computeFens()`.
- `src/test/widgets/move_pills_widget_test.dart` — Widget test patterns for `MovePillsWidget`.

## Architecture

### Subsystem overview

The Add Line screen is a new dedicated screen for building repertoire lines, replacing the edit-mode toggle in the existing repertoire browser. It spans three layers:

1. **Service layer** — `LineEntryEngine` (existing) is the pure business-logic core. It tracks existing tree path, followed moves, and buffered (new) moves. It handles `acceptMove`, `takeBack`, parity validation, and `getConfirmData`. It has no Flutter or database dependencies.

2. **Controller layer** — `AddLineController` (new) is a `ChangeNotifier` that owns a `LineEntryEngine`, a `RepertoireTreeCache`, and the screen state (pill list, focused index, board orientation, display name). It translates user actions (board moves, pill taps, take-back, confirm) into engine calls and state updates. It also handles persistence (saving moves, creating review cards, undo).

3. **Screen layer** — `AddLineScreen` (new) is a `StatefulWidget` that owns the `AddLineController` and `ChessboardController`. It renders the AppBar, aggregate display name banner, chessboard, move pills widget, and action bar. It shows dialogs (parity, discard, label) and snackbars (undo).

### Data flow

```
User plays move on board
  → AddLineScreen._onBoardMove(NormalMove)
    → AddLineController.onBoardMove(san, fen, boardController)
      → LineEntryEngine.acceptMove(san, fen)
      → Rebuild pills list from engine state
      → Update focusedPillIndex, aggregateDisplayName
      → notifyListeners()
    → Screen rebuilds with new state

User taps pill
  → MovePillsWidget.onPillTapped(index)
    → AddLineController.onPillTapped(index, boardController)
      → Set focusedPillIndex, update board FEN
      → notifyListeners()

User confirms line
  → AddLineScreen._onConfirmLine()
    → AddLineController.confirmAndPersist(db)
      → LineEntryEngine.validateParity() / getConfirmData()
      → Repository: extendLine() or saveMove() calls
      → Rebuild tree cache, reset engine
      → Return ConfirmResult for snackbar/dialog
```

### Key constraints

- `LineEntryEngine` is created fresh for each entry session (or branch). It cannot be reused across sessions.
- `MovePillsWidget` is stateless — all state is passed in by the controller via the screen.
- The confirm flow is async and involves multiple DB operations. Extension uses transactional `extendLine`; branching uses sequential inserts.
- The `ChessboardController` must be updated synchronously with controller state to avoid desync.
- Branching requires creating a new `LineEntryEngine` from a different starting point in the tree.
