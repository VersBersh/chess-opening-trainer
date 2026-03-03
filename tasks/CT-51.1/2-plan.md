# CT-51.1: Plan

## Goal

Change the global `AppBarTheme` so the app bar background matches the screen's surface colour and the title uses `titleMedium`, then remove the redundant local `backgroundColor` override in the Add Line screen.

## Steps

### Step 1 — Update the global `AppBarTheme` in `src/lib/main.dart`

File to modify: `src/lib/main.dart`

In both `lightTheme` and `darkTheme`, update the `AppBarTheme` block:
- Change `backgroundColor` from `colorScheme.inversePrimary` to `colorScheme.surface`
- Add `titleTextStyle` using `Typography.material2021()` to get `titleMedium` with appropriate colour

For light theme:
```dart
appBarTheme: AppBarTheme(
  backgroundColor: lightColorScheme.surface,
  foregroundColor: lightColorScheme.onSurface,
  titleTextStyle: Typography.material2021().black.titleMedium
      ?.copyWith(color: lightColorScheme.onSurface),
),
```

For dark theme:
```dart
appBarTheme: AppBarTheme(
  backgroundColor: darkColorScheme.surface,
  foregroundColor: darkColorScheme.onSurface,
  titleTextStyle: Typography.material2021().white.titleMedium
      ?.copyWith(color: darkColorScheme.onSurface),
),
```

### Step 2 — Remove the local `backgroundColor` override in `src/lib/screens/add_line_screen.dart`

File to modify: `src/lib/screens/add_line_screen.dart`

Locate the `AppBar` that has a local `backgroundColor: Theme.of(context).colorScheme.inversePrimary` property and remove that property so the widget inherits the new theme value.

Depends on: Step 1 (the line is redundant under either the old or new theme, but removing it only produces the correct visual result once Step 1 is done).

## Risks / Open Questions

1. **`Colors.transparent` vs `surface`**: Using `surface` is safer than `transparent` because it gives the `AppBarTheme` a concrete colour for elevation overlays and scrolled state tinting.

2. **`titleTextStyle` construction timing**: `AppBarTheme` is constructed before `ThemeData` is returned, so `titleTextStyle` cannot be sourced from the finished theme's `textTheme`. Using `Typography.material2021()` directly is the idiomatic solution.

3. **Import screen `TabBar` visual regression**: The `TabBar` in `import_screen.dart`'s `AppBar.bottom` slot will also become surface-coloured — this should look fine with Material 3 guidance.

4. **Repertoire Manager two-line title**: The subtitle is styled explicitly with `textTheme.bodySmall`, so it is unaffected by the `titleTextStyle` change.
