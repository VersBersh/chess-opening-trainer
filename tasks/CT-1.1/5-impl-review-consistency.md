# CT-1.1 Plan Validation Review

## Verdict

**Approved**

## Progress

- [x] **Step 1**: Add `fast_immutable_collections` as a direct dependency in `src/pubspec.yaml` -- Done. Added `fast_immutable_collections: ^11.0.0` under dependencies. `pubspec.lock` updated from `transitive` to `direct main`.
- [x] **Step 2**: Create `ChessboardController` class in `src/lib/widgets/chessboard_controller.dart` -- Done. ChangeNotifier with all specified getters (`position`, `fen`, `sideToMove`, `isCheck`, `validMoves`, `lastMove`) and mutators (`setPosition`, `playMove`, `resetToInitial`).
- [x] **Step 3**: Create `ChessboardWidget` StatefulWidget in `src/lib/widgets/chessboard_widget.dart` -- Done. All constructor parameters present (`controller`, `orientation`, `playerSide`, `onMove`, `lastMoveOverride`, `shapes`, `settings`). Adds `annotations` parameter beyond plan (justified). Handles promotion flow, user move validation, LayoutBuilder sizing, and listener lifecycle correctly.
- [x] **Step 4**: Create `sanToMove` utility in `src/lib/services/chess_utils.dart` -- Done. Delegates to `position.parseSan(san)` and type-checks for `NormalMove`. Fallback iteration over legal moves omitted per implementation notes (justified: `parseSan` handles all cases).
- [x] **Step 5**: Unit tests for `ChessboardController` in `src/test/widgets/chessboard_controller_test.dart` -- Done. Covers initial state, `setPosition`, `playMove` (legal/illegal), `resetToInitial`, listener notifications (including no-notify on illegal move), `isCheck`, `validMoves` count, and promotion.
- [x] **Step 6**: Unit tests for `sanToMove` in `src/test/services/chess_utils_test.dart` -- Done. Covers pawn move, piece move, invalid SAN, nonsensical input, promotion SAN, capture SAN, and castling SAN.
- [x] **Step 7**: Widget tests for `ChessboardWidget` in `src/test/widgets/chessboard_widget_test.dart` -- Done. Covers rendering, orientation, position updates via `setPosition`, programmatic `playMove`, `resetToInitial`, `playerSide.none`, shapes forwarding, default settings, and custom settings.

## Issues

No critical or major issues found. The implementation is clean, correct, and well-aligned with the plan.

1. **Minor -- `validMoves` recomputed on every access** (`src/lib/widgets/chessboard_controller.dart`, line 34). The `validMoves` getter calls `makeLegalMoves(_position)` every time it is accessed, which involves iterating all legal moves. During a single `build()` call this is only accessed once via chessground's `GameData`, so it is not a problem in practice. If future consumers access it multiple times per frame, caching it (invalidated on position change) would be a minor optimization. No fix required now.

2. **Minor -- Double legality check in `playMove`** (`src/lib/widgets/chessboard_controller.dart`, lines 57-58). The controller calls `_position.isLegal(move)` and then `_position.play(move)`, but `play()` internally also calls `isLegal()`. This is intentional (avoids exception-based control flow per implementation notes) and the overhead is negligible. No fix required.

3. **Minor -- `annotations` parameter added beyond plan** (`src/lib/widgets/chessboard_widget.dart`, line 26). The plan's Step 3 constructor parameters did not include `annotations`, but chessground's `Chessboard` accepts `IMap<Square, Annotation>? annotations`. Including it in the wrapper is sensible and forward-looking for correction hints in drill mode. This is a justified addition.

4. **Minor -- `onMove` callback signature deviation documented** (`src/lib/widgets/chessboard_widget.dart`, line 41). Changed from `{required bool isDrop}` to `{required bool isDrag}` per implementation notes. The rename is well-justified: `isDrag` better matches chessground's `viaDragAndDrop` semantics and avoids confusion with Crazyhouse piece drops.

## Summary

The implementation faithfully follows all 7 plan steps. All source files are well-structured, correctly use the chessground and dartchess APIs (verified against package source), and follow Flutter conventions consistent with the existing codebase. The deviations from the plan are minor, justified, and properly documented in `implementation-notes.md`. Test coverage is thorough for the scope of this task. No regressions to existing functionality -- no existing files were modified beyond `pubspec.yaml`/`pubspec.lock`.
