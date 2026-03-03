# CT-51.2 Context

## Relevant Files

- `src/lib/controllers/repertoire_browser_controller.dart` — Owns `getCandidatesForMove` and `_filterByMove`, which are the site of the bug. Also owns `getChildArrows`, which correctly shows the arrow hint via `sanToMove`.
- `src/lib/services/chess_utils.dart` — Contains `sanToMove(position, san)`, a thin wrapper around `position.parseSan(san)` that returns the king-to-rook form for castling (e.g. `NormalMove(e1, h1)` for O-O).
- `src/lib/widgets/chessboard_widget.dart` — `_onUserMove` receives the move from chessground and calls `controller.playMove`, then fires `onMove` which feeds into `_onMovePlayed` in the screen. Does not normalize castling moves.
- `src/lib/screens/repertoire_browser_screen.dart` — `_onMovePlayed` receives the played move and routes it to `getCandidatesForMove`. This is the glue between the board gesture and the repertoire lookup.
- `src/test/controllers/repertoire_browser_controller_test.dart` — Existing unit tests for `getCandidatesForMove`; the castling case is missing and must be added.
- `src/test/services/chess_utils_test.dart` — Tests for `sanToMove`; new `normalizeMoveForPosition` tests go here.
- `dartchess-0.12.1/lib/src/position.dart` (pub cache) — `Position.normalizeMove(NormalMove)` converts king-to-destination castling gestures to king-to-rook canonical form (line 646). Returns `Move` (sealed base type).

## Architecture

The repertoire manager board interaction works in three layers:

**Layer 1 – chessground board widget.** Handles pointer events and constructs `NormalMove(from, to)` from the gesture. For castling, the destination square is the king's destination (g1 for O-O, c1 for O-O-O), not the rook square. Passes `validMoves` (computed by `makeLegalMoves`) which includes both castling forms so the board shows correct highlights.

**Layer 2 – ChessboardController.** `playMove(NormalMove(e1, g1))` calls `position.isLegal` and `position.play`. Both accept the king-to-destination form internally. The board state advances correctly. Fires `widget.onMove?.call(move)` with the **un-normalized** `NormalMove(e1, g1)`.

**Layer 3 – RepertoireBrowserController.** `_onMovePlayed(NormalMove(e1, g1))` calls `getCandidatesForMove`. Inside, `_filterByMove` converts each child SAN to a `NormalMove` via `sanToMove` (which uses `position.parseSan`, always yielding the king-to-rook form `e1→h1`), then compares `childMove.to == move.to` — i.e. `h1 == g1` — which is **false**. No candidates are found, "Not in repertoire" is shown, and the board resets.

**Key constraint:** dartchess stores castling moves internally as king-to-rook. `sanToMove("O-O")` always returns `NormalMove(e1, h1)`. The chessground board emits the king-destination form `NormalMove(e1, g1)`. The mismatch occurs in Layer 3. The fix must normalize the incoming move before comparing against the repertoire tree.
