# CT-51.1: Context

## Relevant Files

| File | Role |
|---|---|
| `src/lib/main.dart` | Defines the global `AppBarTheme` for both light and dark `ThemeData`. This is the single place that sets `backgroundColor` (currently `inversePrimary`) and `foregroundColor` for all app bars. No `titleTextStyle` is set here, so Flutter's Material 3 default (`titleLarge`) applies everywhere. |
| `src/lib/screens/home_screen.dart` | Home screen. Contains AppBar widgets in loading, error, and data states. None override `backgroundColor` locally. |
| `src/lib/screens/add_line_screen.dart` | Add Line screen. Has one `AppBar` that **overrides** `backgroundColor` locally with `Theme.of(context).colorScheme.inversePrimary` — this local override must be removed alongside the theme change. |
| `src/lib/screens/drill_screen.dart` | Drill / Free Practice screen. Contains AppBar widgets across loading, error, active-drill, and pass-complete states. None override `backgroundColor` locally. |
| `src/lib/screens/repertoire_browser_screen.dart` | Repertoire Manager screen. One `AppBar` with a multi-line title column (repertoire name + "Repertoire Manager" subtitle). No local `backgroundColor` override. |
| `src/lib/screens/import_screen.dart` | Import PGN screen. One `AppBar` with a `TabBar` in the `bottom` slot. No local `backgroundColor` override. |
| `src/lib/screens/settings_screen.dart` | Settings screen. One plain `AppBar`. No local `backgroundColor` override. |
| `src/lib/widgets/session_summary_widget.dart` | Session/Practice Complete screen rendered as a full-scaffold widget. One `AppBar`. No local `backgroundColor` override. |

## Architecture

App bars in this project are all plain Flutter `AppBar` widgets placed directly inside `Scaffold` widgets — there is no shared reusable app bar widget or mixin. Styling is driven almost entirely by a single global `AppBarTheme` declared twice inside `ChessTrainerApp.build` in `main.dart`: once for `lightTheme` and once for `darkTheme`.

The one exception is `add_line_screen.dart`, which applies a redundant local `backgroundColor: Theme.of(context).colorScheme.inversePrimary` that duplicates what the theme already provides.

No screen sets `titleTextStyle` locally or in the theme, so the app bar title currently defaults to Material 3's `titleLarge` style.
