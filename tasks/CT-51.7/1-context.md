# CT-51.7: Context

## Relevant Files

- `src/lib/screens/add_line_screen.dart` — The Add Line screen widget and state class. Contains the offending `_buildContent` method that conditionally renders a variable-height `Container` banner with the aggregate display name ABOVE the board.
- `src/lib/controllers/add_line_controller.dart` — Business logic and immutable `AddLineState`. Owns `aggregateDisplayName` (a `String` on state). No layout concerns.
- `src/lib/theme/spacing.dart` — Shared layout constants: `kBoardFrameTopGap`, `kBoardFrameTopInsets`, `kLineLabelHeight` (32 dp), `kLineLabelLeftInset` (16 dp). The reserved-height label slot pattern uses these.
- `src/lib/screens/drill_screen.dart` — Reference implementation of the reserved-height label slot below the board. Builds a fixed-height `SizedBox(height: kLineLabelHeight)` that always renders, with the label text conditional inside it.
- `src/lib/widgets/browser_board_panel.dart` — Contains `BrowserDisplayNameHeader`, the Repertoire Manager's equivalent reserved-height widget below the board, also using `kLineLabelHeight`.
- `src/lib/widgets/browser_content.dart` — Shows how `BrowserDisplayNameHeader` is composed into a `Column` immediately after the `AspectRatio` board widget.
- `src/test/screens/add_line_screen_test.dart` — Widget test suite for the Add Line screen.

## Architecture

### Subsystem Overview

The Add Line screen is a single `ConsumerStatefulWidget` (`AddLineScreen`) backed by `AddLineController` (a `ChangeNotifier`). The screen's body delegates to `_buildContent`, which builds a `SingleChildScrollView > Column`. The column currently contains:

1. **Conditional banner (the bug):** `if (displayName.isNotEmpty) Container(...)` — variable-height widget rendered ABOVE the board. Its presence/absence shifts the board vertically.
2. `SizedBox(height: kBoardFrameTopGap)` — the top gap.
3. `ConstrainedBox > AspectRatio > ChessboardWidget` — the board.
4. `MovePillsWidget` — move pills below the board.
5. Inline label editor (conditional).
6. Parity warning (conditional).
7. Existing line info (conditional).
8. Action bar.

### Board Layout Consistency Contract

No dynamic or variable-height content may appear between the app bar and the board. All dynamic content must be below the board.

### The Correct Pattern (Drill / Repertoire Manager)

Both reference screens use a `SizedBox(height: kLineLabelHeight, width: double.infinity)` with an inner conditional child. The `SizedBox` always occupies its space (32 dp) regardless of whether a label exists. The text is rendered conditionally inside it.

- `DrillScreen`: inline `lineLabelWidget` built as `SizedBox(height: kLineLabelHeight, ...)`, placed immediately after the board.
- `BrowserDisplayNameHeader`: a `StatelessWidget` encapsulating the same `SizedBox` pattern, reusable.

### Key Constraints

- `aggregateDisplayName` is already computed correctly by `AddLineController`; no controller changes are needed.
- The label slot must use `kLineLabelHeight` to stay consistent with Drill and Repertoire Manager.
