# CT-11.7: Implementation Plan

## Goal

Replace the parity mismatch popup dialog with an inline warning widget below the board, preserving the same "flip and confirm" functionality while making the warning dismissible and non-blocking.

## Steps

### Step 1: Add parity warning state field to screen state

**File:** `src/lib/screens/add_line_screen.dart`

Add a nullable `ParityMismatch?` field to `_AddLineScreenState`:

```dart
ParityMismatch? _parityWarning;
```

### Step 2: Replace dialog call with inline state update in `_onConfirmLine`

**File:** `src/lib/screens/add_line_screen.dart`

In `_onConfirmLine()`, change the `ConfirmParityMismatch` case from showing a dialog to setting the state field:

```dart
case ConfirmParityMismatch(:final mismatch):
    setState(() {
      _parityWarning = mismatch;
    });
```

### Step 3: Add "Flip and confirm" and dismiss handler methods

**File:** `src/lib/screens/add_line_screen.dart`

```dart
Future<void> _onFlipAndConfirm() async {
    setState(() => _parityWarning = null);
    final result = await _controller.flipAndConfirm();
    if (mounted && result is ConfirmSuccess) {
      _handleConfirmSuccess(result);
    }
}

void _onDismissParityWarning() {
    setState(() => _parityWarning = null);
}
```

### Step 4: Clear parity warning on relevant user actions

**File:** `src/lib/screens/add_line_screen.dart`

Clear `_parityWarning` on these user actions, but only when the action actually changes the line/board state:

- `_onBoardMove` — clear `_parityWarning` **only when `result is MoveAccepted`** (not when `MoveBranchBlocked`, since the move was rejected and the line didn't change). Move the clearing to after the `result` check:

```dart
void _onBoardMove(NormalMove move) {
    setState(() => _isLabelEditorVisible = false);
    final result = _controller.onBoardMove(move, _boardController);
    if (result is MoveBranchBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(...);
    } else {
      setState(() => _parityWarning = null);
    }
}
```

- `_onTakeBack` — clear unconditionally (take-back always changes the line):

```dart
void _onTakeBack() {
    setState(() {
      _isLabelEditorVisible = false;
      _parityWarning = null;
    });
    _controller.onTakeBack(_boardController);
}
```

- `_onFlipBoard` — clear unconditionally (parity context has changed). Wrap in setState:

```dart
void _onFlipBoard() {
    setState(() => _parityWarning = null);
    _controller.flipBoard();
}
```

### Step 5: Build the inline parity warning widget

**File:** `src/lib/screens/add_line_screen.dart`

Add a private method `_buildParityWarning(ParityMismatch mismatch)` that constructs an inline warning widget using `errorContainer`/`onErrorContainer` theme colors, with:
- Warning icon and "Line parity mismatch" title
- Close (dismiss) IconButton
- Explanation text
- "Flip and confirm as [Color]" TextButton

### Step 6: Insert the inline warning widget into the column layout

**File:** `src/lib/screens/add_line_screen.dart`

In `_buildContent`, add the parity warning between the label editor and the action bar:

```dart
// Inline label editor
if (_isLabelEditorVisible) _buildInlineLabelEditor(state),

// Inline parity warning
if (_parityWarning != null) _buildParityWarning(_parityWarning!),

// Action bar
_buildActionBar(context, state),
```

### Step 7: Delete the `_showParityWarningDialog` method

**File:** `src/lib/screens/add_line_screen.dart`

Remove the `_showParityWarningDialog` method entirely (lines 229-256). It is no longer called.

### Step 8: Add widget tests for inline parity warning

**File:** `src/test/screens/add_line_screen_test.dart`

Tests to add:
1. Parity mismatch shows inline warning, not a dialog
2. Flip and confirm from inline warning persists the line
3. Inline warning is dismissible via close button
4. Warning auto-dismisses when user plays a new move
5. No warning when parity matches — confirm saves immediately
6. Manual board flip clears the inline warning

## Risks / Open Questions

1. **Warning placement in scrollable content.** On small screens, the warning might push the action bar below the fold. This is acceptable since the scroll view allows scrolling. The implementer should verify on a small viewport.

2. **No changes to controller or engine.** The controller already returns `ConfirmParityMismatch` as a sealed result. The screen simply changes how it responds (inline widget instead of dialog). `flipAndConfirm()` is called the same way. This keeps the change surface minimal.

3. **`_onFlipBoard` clearing the warning.** If the user sees a parity warning then manually flips the board, the warning is dismissed (stale). If they tap Confirm again, a fresh parity check runs.
