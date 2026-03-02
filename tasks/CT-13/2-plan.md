# CT-13: Implementation Plan

## Goal

Remove the layout-shifting checkmark from the `ChoiceChip` in the piece set picker so that selecting a piece set does not cause surrounding chips to reflow.

## Steps

### 1. Disable the checkmark and style the selected-state border

**File:** `src/lib/screens/settings_screen.dart`

In `_buildPieceSetPicker`, add `showCheckmark: false` to the existing `ChoiceChip` and use the `side` property to give the selected chip a prominent primary-colored border (mirroring the board color picker's visual treatment). The unselected chips keep a subtle `outlineVariant` border.

Change the `ChoiceChip` from:

```dart
return ChoiceChip(
  label: Text(choice.label),
  selected: isSelected,
  onSelected: (_) =>
      ref.read(boardThemeProvider.notifier).setPieceSet(choice),
);
```

to:

```dart
return ChoiceChip(
  label: Text(choice.label),
  selected: isSelected,
  showCheckmark: false,
  side: BorderSide(
    color: isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant,
    width: isSelected ? 2 : 1,
  ),
  onSelected: (_) =>
      ref.read(boardThemeProvider.notifier).setPieceSet(choice),
);
```

**Design rationale:**
- `showCheckmark: false` eliminates the leading check icon that causes intrinsic width changes and layout shift.
- The `side` property provides a clear selected-state indicator via border color/width, consistent with the board color picker's border-based pattern.
- The widget remains a `ChoiceChip`, preserving all Material 3 theming, semantics, focus/keyboard handling, and tap-target behavior.

### 2. Verify no regressions

**File:** `src/lib/screens/settings_screen.dart`

No code changes. After implementing step 1, visually verify that:
- Selecting a piece set no longer causes chips to shift or reflow.
- The selected chip has a visible primary-colored border.
- The board color picker still renders correctly.
- The live preview board still updates when either picker is changed.
- Existing widget tests in `src/test/screens/settings_screen_test.dart` still pass (run `flutter test`).

## Risks / Open Questions

1. **Border width difference (2px vs 1px):** The selected chip border is 1px wider than the unselected border. In practice, `ChoiceChip` absorbs this into its internal padding/layout so it does not cause a visible shift, unlike the checkmark icon which adds an entire `Icon` widget. If any sub-pixel shift is observed during verification, set both states to `width: 2` and differentiate only by color.

2. **Accessibility is preserved by default.** Because we keep `ChoiceChip`, all built-in semantics, focus traversal, keyboard interaction, and minimum tap-target sizing are retained automatically. No additional accessibility work is needed.

3. **Test coverage:** Widget tests already exist for the settings screen (`settings_screen_test.dart`) and cover chip rendering and tap behavior. The existing tests should pass without modification since the widget type (`ChoiceChip`) is unchanged. No new test infrastructure is needed, though a future test asserting `showCheckmark: false` could guard against regression.
