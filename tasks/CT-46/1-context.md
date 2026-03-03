# CT-46: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/widgets/browser_content.dart` | Responsive narrow/wide layout for the Repertoire Browser; composes the board, controls, action bar, label header, and move tree |
| `src/lib/widgets/browser_board_panel.dart` | Defines `BrowserDisplayNameHeader` (the label widget), `BrowserChessboard`, and `BrowserBoardControls` |
| `src/lib/screens/drill_screen.dart` | Drill/Free Practice screen; contains the `lineLabelWidget` implementation that currently uses `horizontal: 16` padding |
| `src/lib/screens/repertoire_browser_screen.dart` | The top-level browser screen scaffold; instantiates `BrowserContent` with all state and callbacks |
| `src/lib/widgets/chessboard_widget.dart` | Wraps `chessground`'s `Chessboard`; no coordinate gutter -- coordinates are rendered inside the board area |
| `src/lib/theme/spacing.dart` | Defines `kBannerGap` (8dp) and `kBannerGapInsets` used for top padding in `BrowserContent` |
| `src/lib/theme/board_theme.dart` | Board theme state/provider; `toSettings()` produces `ChessboardSettings` without coordinate configuration |
| `features/repertoire-browser.md` | Spec for Repertoire Browser; "Line Display Name" section specifies label below board, fixed reserved space, plain text styling, left-aligned with ~16-24dp inset |
| `features/drill-mode.md` | Spec for Drill Mode; "Line Label Display" section specifies label below board with always-reserved vertical space |
| `features/free-practice.md` | Spec for Free Practice; references drill-mode.md for identical line name display |
| `src/test/screens/drill_screen_test.dart` | Contains tests for line label positioning (below board), both narrow and wide layouts |
| `src/test/screens/repertoire_browser_screen_test.dart` | Browser screen integration tests; includes display name header tests that will need updating |
| `design/ui-guidelines.md` | Global UI conventions; the banner gap rule applies here |

## Architecture

The Repertoire Browser uses a two-layer architecture:

1. **`RepertoireBrowserScreen`** (in `repertoire_browser_screen.dart`) is the top-level `ConsumerStatefulWidget`. It owns the controller, board controller, and state management. It passes everything into `BrowserContent` as props.

2. **`BrowserContent`** (in `browser_content.dart`) is a pure `StatelessWidget` that handles the responsive layout decision (narrow: `screenWidth < 600`, wide: `screenWidth >= 600`). It composes child widgets from `browser_board_panel.dart`.

The widgets in `browser_board_panel.dart` are extracted, reusable pieces:
- **`BrowserChessboard`** -- thin wrapper around `ChessboardWidget`
- **`BrowserDisplayNameHeader`** -- the label banner (currently styled with a colored background, renders `SizedBox.shrink()` when empty)
- **`BrowserBoardControls`** -- flip/back/forward button row

**Current label placement:**
- **Narrow layout:** `BrowserDisplayNameHeader` is the first child in the `Column`, above the board.
- **Wide layout:** `BrowserDisplayNameHeader` is the first child in the right-panel `Column`, above the board controls.

**Drill screen label:** The drill screen builds its own `lineLabelWidget` inline (not a shared widget). It uses `titleMedium`, `onSurfaceVariant`, `FontWeight.normal`, with `horizontal: 16, vertical: 4` padding. It conditionally renders `null` when the label is empty.

**Key constraints:**
- The `Chessboard` from the `chessground` package paints coordinates inside the board area -- there is no external coordinate gutter. The ~16-24dp inset is a purely visual alignment.
- The board is always square (constrained by `AspectRatio(1)` in narrow layout, and explicit `SizedBox` in wide layout).
- The board resizes today because `BrowserDisplayNameHeader` returns `SizedBox.shrink()` when empty (0 height) versus a full container when non-empty, changing available space in the `Column`.
