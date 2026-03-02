# CT-9.2 Plan

## Goal

Update the move pills widget to use blue fill colors (via a theme extension token), reduce border radius from stadium to a modest rounding, and switch from horizontal scrolling to a wrapping layout.

## Steps

### 1. Define the `PillTheme` theme extension

**File:** `src/lib/theme/pill_theme.dart` (new file)

Create a `ThemeExtension<PillTheme>` subclass that holds the pill color tokens. This follows Flutter's idiomatic pattern for custom theme tokens and satisfies the requirement that pill color is "defined as a theme token for easy global adjustment."

```dart
@immutable
class PillTheme extends ThemeExtension<PillTheme> {
  final Color savedColor;
  final Color unsavedColor;
  final Color focusedBorderColor;

  const PillTheme({
    required this.savedColor,
    required this.unsavedColor,
    required this.focusedBorderColor,
  });

  @override
  PillTheme copyWith({ Color? savedColor, Color? unsavedColor, Color? focusedBorderColor }) {
    return PillTheme(
      savedColor: savedColor ?? this.savedColor,
      unsavedColor: unsavedColor ?? this.unsavedColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
    );
  }

  @override
  PillTheme lerp(PillTheme? other, double t) {
    if (other is! PillTheme) return this;
    return PillTheme(
      savedColor: Color.lerp(savedColor, other.savedColor, t)!,
      unsavedColor: Color.lerp(unsavedColor, other.unsavedColor, t)!,
      focusedBorderColor: Color.lerp(focusedBorderColor, other.focusedBorderColor, t)!,
    );
  }
}
```

The extension defines three tokens:
- `savedColor` -- blue fill for saved (existing) pills.
- `unsavedColor` -- a lighter/muted blue for unsaved (new/buffered) pills, keeping them visually distinguishable from saved pills.
- `focusedBorderColor` -- a darker/accent blue for the focused pill's border highlight.

**Depends on:** Nothing.

### 2. Register `PillTheme` in the app's `ThemeData`

**File:** `src/lib/main.dart`

In `ChessTrainerApp.build`, add the `PillTheme` instance to `ThemeData.extensions`:

```dart
theme: ThemeData(
  colorScheme: colorScheme,
  useMaterial3: true,
  extensions: [
    const PillTheme(
      savedColor: Color(0xFF5B8FDB),    // A medium, pleasant blue
      unsavedColor: Color(0xFFB0CBF0),  // A lighter, muted blue for unsaved
      focusedBorderColor: Color(0xFF1A56A8), // A darker accent blue for focus
    ),
  ],
  // ... existing appBarTheme, snackBarTheme ...
),
```

The exact blue shades should be tuned visually, but the intent is: saved pills get a medium blue, unsaved pills get a noticeably lighter/desaturated blue (maintaining the saved-vs-unsaved distinction), and the focused pill gets a darker border.

**Depends on:** Step 1.

### 3. Update `_MovePill` to use the new blue colors and reduced border radius

**File:** `src/lib/widgets/move_pills_widget.dart`

In `_MovePill.build`, replace the current 4-way color matrix with one that reads from the `PillTheme` extension:

```dart
final pillTheme = Theme.of(context).extension<PillTheme>();
```

New color logic (the 4-way matrix is preserved, but colors change):

| State                | Background                 | Text Color                | Border Color                     | Border Width |
|----------------------|----------------------------|---------------------------|----------------------------------|--------------|
| Saved + Focused      | `pillTheme.savedColor`     | `Colors.white`            | `pillTheme.focusedBorderColor`   | 2            |
| Saved + Unfocused    | `pillTheme.savedColor`     | `Colors.white`            | `pillTheme.savedColor` (no visible border, or a subtle darker shade) | 1 |
| Unsaved + Focused    | `pillTheme.unsavedColor`   | `colorScheme.onSurface`   | `pillTheme.focusedBorderColor`   | 2            |
| Unsaved + Unfocused  | `pillTheme.unsavedColor`   | `colorScheme.onSurfaceVariant` | `pillTheme.unsavedColor` (subtle) | 1 |

Key details:
- Text color on the saved (darker blue) pills should be white or near-white for contrast. On unsaved (lighter blue) pills, the standard on-surface color should work.
- The `PillTheme` can be null if the extension is not registered (defensive programming). Fall back to the current colorScheme-based colors if `pillTheme` is null. This keeps the widget usable in tests that don't provide the extension.
- Label text color below the pill (`colorScheme.primary` currently) should also be updated if it no longer looks good against the new blue background. Since labels render outside the pill container (below it), this likely still works fine.

Change the border radius from `BorderRadius.circular(16)` to `BorderRadius.circular(6)`:

```dart
borderRadius: BorderRadius.circular(6),
```

This gives a visibly squared-off look that is still softly rounded, matching the design guideline "modest border radius."

**Depends on:** Step 1 (imports the `PillTheme` class).

### 4. Switch pill layout from horizontal scroll to `Wrap`

**File:** `src/lib/widgets/move_pills_widget.dart`

In `MovePillsWidget.build`, replace the current `SizedBox(height: 56) > SingleChildScrollView > Row` structure with a `Wrap` widget:

```dart
@override
Widget build(BuildContext context) {
  if (pills.isEmpty) {
    return const SizedBox(
      height: 48,
      child: Center(
        child: Text('Play a move to begin'),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < pills.length; i++)
          _MovePill(
            data: pills[i],
            isFocused: i == focusedIndex,
            isLast: i == pills.length - 1,
            onTap: () => onPillTapped(i),
            onDelete: i == pills.length - 1 ? onDeleteLast : null,
          ),
      ],
    ),
  );
}
```

Key changes:
- Remove the `SizedBox(height: 56)` -- the `Wrap` has dynamic height based on content.
- Remove `SingleChildScrollView` and `Row` -- replaced by `Wrap`.
- `Wrap.spacing` controls horizontal gap between pills (was `Padding(right: 4)` on each pill, now use `spacing: 4`).
- `Wrap.runSpacing` controls vertical gap between rows of pills when they wrap.
- Remove the per-pill `Padding(right: 4)` since `Wrap.spacing` handles it.

**Depends on:** Nothing (can be done independently of color changes, but combined in the same file).

### 5. Make the Add Line screen body scrollable

**File:** `src/lib/screens/add_line_screen.dart`

In `_buildContent`, wrap the `Column` body in a `SingleChildScrollView` so that when pills wrap onto multiple lines, the entire screen remains scrollable. Without this, the `Column` will overflow when pills + action buttons exceed the viewport.

```dart
Widget _buildContent(BuildContext context, AddLineState state) {
  final displayName = state.aggregateDisplayName;

  return SingleChildScrollView(
    child: Column(
      children: [
        // ... display name banner, chessboard, pills, action bar ...
      ],
    ),
  );
}
```

The chessboard has `ConstrainedBox(maxHeight: 300) > AspectRatio(1)` which already constrains its size, so wrapping in `SingleChildScrollView` should not cause unbounded height issues. The pills section now has dynamic height (from `Wrap`), and the action bar is a fixed-height row. All of these work fine inside a `Column` inside a `SingleChildScrollView`.

**Depends on:** Step 4 (the Wrap change is what necessitates scrollability).

### 6. Update widget tests for new colors and layout

**File:** `src/test/widgets/move_pills_widget_test.dart`

Update the `buildTestApp` helper to include the `PillTheme` extension in the test `ThemeData`:

```dart
Widget buildTestApp({...}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      extensions: [
        const PillTheme(
          savedColor: Color(0xFF5B8FDB),
          unsavedColor: Color(0xFFB0CBF0),
          focusedBorderColor: Color(0xFF1A56A8),
        ),
      ],
    ),
    home: Scaffold(
      body: SizedBox(
        width: 400,
        child: MovePillsWidget(...),
      ),
    ),
  );
}
```

Update or replace the following tests:

- **`'focused saved pill has primaryContainer background'`** -- Change the assertion from `colorScheme.primaryContainer` to the `PillTheme.savedColor` value (`Color(0xFF5B8FDB)`).
- **`'focused unsaved pill has tertiaryContainer background'`** -- Change the assertion from `colorScheme.tertiaryContainer` to `PillTheme.unsavedColor` value (`Color(0xFFB0CBF0)`).
- **`'saved vs unsaved pills have different styling'`** -- Update border color assertions from `colorScheme.outline`/`colorScheme.outlineVariant` to the new border colors. Also verify that saved and unsaved pills have different background colors (the new blue shades).
- **`'empty list shows no pills'`** -- The current test asserts `find.byType(SingleChildScrollView), findsNothing`. Since `SingleChildScrollView` is removed entirely from `MovePillsWidget`, update this to check that no `Wrap` is rendered (or simply that the placeholder text is shown and no pills are present).
- **Add a new test: `'pills wrap onto multiple lines'`** -- Create a test with many pills (e.g., 15-20) in a narrow container (width: 200). Verify that a `Wrap` widget is present and that pills are laid out across multiple "runs." This can be verified by checking that the last pill's vertical position is greater than the first pill's vertical position.
- **Add a new test: `'border radius is reduced'`** -- Find the `Container` decoration on a pill and assert that `borderRadius` is `BorderRadius.circular(6)` (not the old `16`).

**Depends on:** Steps 1, 3, 4.

### 7. Verify Add Line screen integration tests still pass

**File:** `src/test/screens/add_line_screen_test.dart`

Run the existing tests. They should pass without modification since they do not assert pill colors or layout specifics. The `'MovePillsWidget is rendered'` test uses `find.byType(MovePillsWidget)` which is unaffected. The `'empty pills shows "Play a move to begin"'` test checks text content, which is unchanged.

If any test fails because the `buildTestApp` in this file does not include the `PillTheme` extension and the widget falls back to null-safety defaults, update that file's `buildTestApp` to include the extension in `ThemeData` -- or verify that the fallback in the widget (Step 3) handles the missing extension gracefully.

**Depends on:** Steps 2, 3, 4, 5.

## Risks / Open Questions

1. **Exact blue shade.** The specific hex values for `savedColor`, `unsavedColor`, and `focusedBorderColor` are estimates. They should be tuned visually on a real device/emulator. The `ThemeExtension` approach makes it easy to adjust these values in one place (`main.dart`) without touching the widget code.

2. **Text contrast on blue backgrounds.** Using white text on the saved (medium blue) pill assumes sufficient contrast. If the chosen blue is too light, white text may not meet accessibility contrast ratios (WCAG AA requires 4.5:1 for normal text). The unsaved (lighter blue) pill uses dark text, which should be fine. Worth a manual contrast check.

3. **Fallback when PillTheme is absent.** The widget should handle `Theme.of(context).extension<PillTheme>()` returning null gracefully. This happens in tests that do not set up the extension and in any context where the widget is used outside the app's theme. The fallback should use reasonable defaults (e.g., the colorScheme-based colors currently in use) so the widget does not crash.

4. **Scrollability of Add Line screen.** Wrapping the body `Column` in `SingleChildScrollView` (Step 5) changes the layout behavior. The chessboard's `AspectRatio(1)` inside `ConstrainedBox(maxHeight: 300)` should still work correctly because `AspectRatio` resolves its height from its width, and the `ConstrainedBox` provides the max-height ceiling. However, if the `SingleChildScrollView` gives the Column unbounded height, `AspectRatio` might behave unexpectedly. This needs to be verified; if it is an issue, the chessboard can be given an explicit `SizedBox(height: ...)` instead of relying on `AspectRatio`.

5. **Label text below pills.** The rotated label text beneath each pill currently uses `colorScheme.primary` as its color. This color is independent of the pill background and renders outside the pill container. It should still look fine visually, but if it clashes with the new blue background of adjacent pills (in the wrapping layout, labels from one row could visually overlap with pills on the row below), the `runSpacing` in the `Wrap` should be increased to provide enough vertical space for labels.

6. **Per-pill Column with label and Wrap interaction.** Each `_MovePill` returns a `Column(mainAxisSize: MainAxisSize.min)` containing the pill container and optionally a label `Text`. When placed inside a `Wrap`, each `_MovePill` Column will be treated as a single Wrap child, and the Wrap will compute row breaks based on the width of the widest element (the pill container). This should work correctly since labels are short text rendered at small font size (10sp) and are typically narrower than the pill itself.

7. **CT-9.1 interaction.** CT-9.1 changes action button grouping from `MainAxisAlignment.spaceEvenly` to a centered `Row` with minimal spacing. Both CT-9.1 and CT-9.2 touch the Add Line screen layout but in different areas (action bar vs. pills section). If CT-9.1 also wraps the body in a `SingleChildScrollView`, this step can skip the redundant wrapping or coordinate with CT-9.1's changes. Since CT-9.2 has no dependency on CT-9.1, assume CT-9.1 has not been applied yet and add the scroll wrapper in Step 5.
