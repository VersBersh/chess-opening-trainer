# CT-61: Implementation Plan

## Goal

Wrap the disabled Label button in a `Tooltip` widget so users understand why it is disabled and what action to take.

## Steps

### 1. Wrap the Label button in a conditional Tooltip

**File:** `src/lib/screens/add_line_screen.dart`

In `_buildActionBar`, the Label button is currently:

```dart
// Label
TextButton.icon(
  onPressed: canEditLabel ? _onEditLabel : null,
  icon: const Icon(Icons.label, size: 18),
  label: const Text('Label'),
),
```

When `canEditLabel` is false, wrap the button in a `Tooltip` widget with the message `'Play or select a move to edit labels'`. When `canEditLabel` is true, render the plain `TextButton.icon` with no `Tooltip` wrapper.

Replace the inline Label button with a call to a helper:

```dart
// Label
_buildLabelButton(canEditLabel),
```

Add a helper method `_buildLabelButton(bool canEditLabel)`:

```dart
Widget _buildLabelButton(bool canEditLabel) {
  final button = TextButton.icon(
    onPressed: canEditLabel ? _onEditLabel : null,
    icon: const Icon(Icons.label, size: 18),
    label: const Text('Label'),
  );

  if (canEditLabel) return button;

  return Tooltip(
    message: 'Play or select a move to edit labels',
    child: button,
  );
}
```

The `Tooltip` widget responds to long-press gestures on its own detector, so it will fire even though the child `TextButton` is disabled (its `onPressed` is null). No special gesture handling is needed.

When the button is enabled, no `Tooltip` wrapper is added -- returning the plain button avoids unnecessary wrapper/semantics noise.

### 2. Add a widget test verifying the tooltip on the disabled Label button

**File:** `src/test/screens/add_line_screen_test.dart`

Add a new test near the existing `'label button disabled when no pill focused'` test (around line 388):

```
testWidgets('disabled label button shows tooltip on long-press', ...)
```

Test steps:
1. Seed an empty repertoire (no moves). Pump the `buildTestApp`.
2. Verify the Label button is disabled (`onPressed` is null).
3. Find the `Tooltip` widget that is an ancestor of the Label `TextButton` by using a scoped finder: `find.ancestor(of: find.widgetWithText(TextButton, 'Label'), matching: find.byType(Tooltip))`.
4. Extract the `Tooltip` widget and assert its `message` property equals `'Play or select a move to edit labels'`. This property-based assertion follows the existing pattern used for `IconButton.tooltip` checks in the hint-arrows toggle test (line 2755).
5. Long-press the Label button area.
6. After `pumpAndSettle`, verify the tooltip text appears on screen: `expect(find.text('Play or select a move to edit labels'), findsOneWidget)`.

### 3. Add a separate test verifying no tooltip when Label button is enabled

**File:** `src/test/screens/add_line_screen_test.dart`

Add a **separate** test (not folded into the disabled-state test) to avoid tooltip overlay lingering from a prior long-press:

```
testWidgets('enabled label button has no tooltip wrapper', ...)
```

Test steps:
1. Seed a repertoire with at least one move (e.g., `['e4']`) so that a pill is focused on load.
2. Pump the `buildTestApp` and `pumpAndSettle`.
3. Verify the Label button is enabled (`onPressed` is not null).
4. Assert that no `Tooltip` ancestor wraps the Label button: `expect(find.ancestor(of: find.widgetWithText(TextButton, 'Label'), matching: find.byType(Tooltip)), findsNothing)`.

Using a separate test avoids flakiness from tooltip overlay state leaking between the disabled and enabled assertions.

## Risks / Open Questions

1. **Tooltip text reflects the real disabled condition.** The Label button is disabled when no pill is focused (`focusedPillIndex` is null or out of range), which happens on the initial empty board or when the user deselects. It is NOT gated by unsaved-moves or confirm/take-back state -- the spec explicitly says labels are editable regardless of save state (`add-line.md`, line 58). The original plan's text `"Confirm or take back new moves to edit labels"` was misleading because it implied the user must confirm before editing labels, which is false. The revised text `"Play or select a move to edit labels"` accurately describes what the user needs to do: either play a new move or tap an existing pill to focus it.

2. **Tooltip on `TextButton.icon`:** Flutter's `TextButton` does not have a built-in `tooltip` parameter (unlike `IconButton`). Wrapping in a `Tooltip` widget is the standard approach. The `Tooltip` widget's long-press detection works independently of the child widget's enabled state, so no workaround is needed.

3. **No spec changes needed:** The `features/add-line.md` spec does not mention tooltip behavior on disabled buttons. This is a UX enhancement that does not change when the button is enabled/disabled -- it only adds feedback for the disabled state.
