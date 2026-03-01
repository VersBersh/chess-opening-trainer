# CT-1.1 Context

## Relevant Files

- `src/lib/widgets/` — Empty directory where `chessboard_widget.dart` will be created
- `src/lib/screens/home_screen.dart` — Existing screen showing current widget patterns (StatefulWidget receiving `AppDatabase` directly)
- `src/lib/models/repertoire.dart` — Contains `RepertoireTreeCache` for repertoire move tree in memory
- `src/lib/models/review_card.dart` — Contains `DrillSession` and `DrillCardState` transient models (primary consumers of chessboard widget)
- `src/lib/repositories/local/database.dart` — Drift database definition including `RepertoireMoves` table schema with `fen` and `san` fields
- `src/pubspec.yaml` — Declares `chessground: ^8.0.1` and `dartchess: ^0.12.1` dependencies
- `features/drill-mode.md` — How the board is used during drills: intro moves, correction arrows, mistake icons, orientation per card color
- `features/line-management.md` — How the board is used for move entry: free play of both sides, flip board toggle, take-back
- `architecture/state-management.md` — Riverpod state management approach; widgets don't call repositories directly

## Architecture

The chessboard widget is a thin, stateful wrapper around two libraries:

1. **chessground** (v8.0.1) — rendering layer: a `Chessboard` Flutter widget that displays pieces from a FEN string, handles tap/drag interaction, shows last-move highlights, draws shapes (arrows, circles), and animates piece transitions. Does not understand chess rules.

2. **dartchess** (v0.12.1) — rules engine: a `Position` class (specifically `Chess`) that tracks game state, validates move legality, generates legal moves, and produces FEN strings. Also provides `makeLegalMoves()` to bridge into chessground's `ValidMoves` type.

The wrapper bridges these libraries into a single widget with an API tailored to the app's needs:
- Maintain a `Position` (dartchess) as the current game state
- Derive `fen`, `validMoves`, `sideToMove`, `isCheck`, and `lastMove` from that position
- Pass these to `Chessboard` (chessground) along with `GameData` routing user moves back to the wrapper
- When a user move arrives, validate/play it on the `Position`, update state, notify parent via callback

Two consumer patterns:
- **Drill mode**: restricts moves to one side, shows correction arrows/annotations, auto-plays opponent moves
- **Line entry mode**: allows both sides to move freely, supports take-back

Key constraints:
- Widget does not know about repertoire concepts — it exposes generic chess operations
- `fast_immutable_collections` needed for `IMap`, `ISet` types used by chessground's API
- Promotion handling via chessground's built-in promotion selector UI
- Animation built into chessground when FEN changes
