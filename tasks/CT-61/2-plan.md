# 2-plan.md — CT-61

## Goal

Add a tooltip to the Label button that explains why it is disabled, so users understand they need to tap a move pill first.

## Steps

### 1. Wrap the Label button in a `Tooltip` when disabled

**File:** `src/lib/screens/add_line_screen.dart`

In `_buildActionBar()`, wrap the Label `TextButton.icon` in a `Tooltip` widget when `canEditLabel` is false. The tooltip message should be clear and actionable:

```
"Tap a move to edit its label"
```

When the button is enabled (`canEditLabel` is true), no tooltip is needed on the button itself (the label editor opens on tap).

**Concrete change:** Replace the current Label button block (lines 919-924). Build the `TextButton.icon` once into a local variable, then conditionally wrap it in a `Tooltip` when disabled. This avoids duplicating the button constructor across both branches. Example structure:

```dart
// Label
final labelButton = TextButton.icon(
  onPressed: canEditLabel ? _onEditLabel : null,
  icon: const Icon(Icons.label, size: 18),
  label: const Text('Label'),
);
if (canEditLabel)
  labelButton
else
  Tooltip(
    message: 'Tap a move to edit its label',
    child: labelButton,
  ),
```

This keeps the widget tree clean: the `Tooltip` is only present when the button is disabled, which is the only time the user needs the hint. Flutter's `Tooltip` activates on long-press, which works even when the child button is disabled.

**Dependencies:** None.

### 2. Add a widget test verifying the tooltip works when the button is disabled

**File:** `src/test/screens/add_line_screen_test.dart`

Add a test in the existing `group('AddLineScreen', ...)` block, near the existing `'label button disabled when no pill focused'` test (around line 388). The test should:

1. Seed an empty repertoire (no starting moves, so no pills are displayed).
2. Pump the `AddLineScreen` and settle.
3. Verify the Label button is disabled (`onPressed` is null).
4. Verify a `Tooltip` with message `'Tap a move to edit its label'` exists in the tree using `find.byTooltip('Tap a move to edit its label')` (structural check).
5. Long-press the disabled Label button using `tester.longPress(find.widgetWithText(TextButton, 'Label'))`.
6. Pump the widget tree with `await tester.pump(const Duration(seconds: 2))` to allow the tooltip overlay to appear (Flutter's default `Tooltip` `waitDuration` / long-press trigger needs time to elapse and animate in).
7. Assert the tooltip text is visible on screen: `expect(find.text('Tap a move to edit its label'), findsOneWidget)`.

The structural check (step 4) confirms the `Tooltip` widget is wired up, and the long-press check (steps 5-7) confirms that a user long-pressing the disabled button actually sees the tooltip text rendered as an overlay. This is important because a `Tooltip` wrapping a disabled Material button is not a pattern tested elsewhere in the codebase, so we need to verify the gesture reaches the `Tooltip` through the disabled button's hit-test area.

**Dependencies:** Step 1 must be complete first.

## Risks / Open Questions

1. **Task description vs. current code:** The original task title references "disabled due to unsaved moves," but the current `canEditLabel` implementation no longer has a `hasNewMoves` guard. The spec (line 58 of `add-line.md`) explicitly says labels are editable regardless of save state. The Label button is now disabled only when no pill is focused. The tooltip message should reflect the actual reason ("Tap a move to edit its label") rather than the outdated reason ("Confirm or take back new moves"). If the task author intended a different behavior, this should be clarified before implementation.

2. **Tooltip trigger:** Flutter's `Tooltip` shows on long-press by default (mobile) or on hover (desktop). On mobile, a long-press on a disabled `TextButton` will trigger the tooltip. A quick tap will not show the tooltip — this is standard Flutter behavior and may require additional UX consideration (e.g., wrapping in a `GestureDetector` to show a snackbar on tap of the disabled button). However, long-press tooltip is the approach explicitly requested by the acceptance criteria ("tooltip on long-press").

3. **Tooltip pump duration in test:** The test uses `tester.pump(const Duration(seconds: 2))` rather than `tester.pumpAndSettle()` because `Tooltip` animations may not fully settle in all cases. If the tooltip does not appear with 2 seconds, try adjusting to match Flutter's default tooltip `waitDuration` (typically 0ms for long-press-triggered tooltips, but the animation itself takes time). The exact duration may need tuning during implementation.
