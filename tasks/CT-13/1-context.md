# CT-13: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/settings_screen.dart` | The settings screen containing the piece set picker (`_buildPieceSetPicker`) that uses `ChoiceChip` with a layout-shifting checkmark. This is the only file to modify. |
| `src/lib/theme/board_theme.dart` | Defines `BoardThemeState`, `BoardColorChoice`, `PieceSetChoice` enums, and `boardThemeProvider`. The piece set picker iterates `PieceSetChoice.values` and reads `choice.label`. No changes needed here. |
| `src/lib/main.dart` | App entry point. Configures `ThemeData` with `useMaterial3: true` and no custom `chipTheme`. The default Material 3 chip theming applies to all `ChoiceChip` widgets. No changes needed. |
| `design/ui-guidelines.md` | Design spec. The "Settings & Selection Indicators" section mandates no layout-shifting checkmarks; recommends border/outline, background highlight, or overlay. |

## Architecture

The settings screen is a single `ConsumerStatefulWidget` (`SettingsScreen`) that watches the `boardThemeProvider` (a Riverpod `Notifier`). It renders a live chessboard preview at the top, then two picker sections:

1. **Board color picker** (`_buildBoardColorPicker`): A `Wrap` of fixed-size 64x64 `Container` widgets. Selection is indicated by a thicker primary-colored border (3px selected vs 1px unselected). The container size is constant regardless of selection state, so there is zero layout shift.

2. **Piece set picker** (`_buildPieceSetPicker`): A `Wrap` of Flutter `ChoiceChip` widgets. Each chip shows the piece set's `label` text. When `selected: true`, Flutter's Material 3 `ChoiceChip` renders a leading checkmark icon, which increases the chip's intrinsic width and causes all subsequent chips in the `Wrap` to reflow -- the "janky visual effect" described in the task.

Both pickers mutate state through `ref.read(boardThemeProvider.notifier).setBoardColor(...)` / `.setPieceSet(...)`, which persists the choice to `SharedPreferences` and rebuilds the widget tree.

Key constraints:
- The app uses Material 3 (`useMaterial3: true`). There is no custom `chipTheme` overriding default chip behavior.
- No other screen in the codebase uses `ChoiceChip`; this is the only occurrence.
- The board color picker already demonstrates the project's preferred "border-based selection indicator" pattern.
