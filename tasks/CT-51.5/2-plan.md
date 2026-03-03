# CT-51.5: Plan

## Goal

Dismiss the "line saved/extended" snackbar the moment the user plays their first board move after a successful confirm, while leaving all other snackbar dismiss behaviour unchanged.

## Steps

### Step 1 — Add a dismiss-pending flag to `_AddLineScreenState`

**File:** `src/lib/screens/add_line_screen.dart`

Add one `bool` field to `_AddLineScreenState`:

```dart
bool _dismissSnackBarOnNextMove = false;
```

This flag acts as a one-shot: it is armed when a confirm succeeds and cleared the moment the first board move is accepted.

---

### Step 2 — Arm the flag in `_handleConfirmSuccess`

**File:** `src/lib/screens/add_line_screen.dart`

In `_handleConfirmSuccess(ConfirmSuccess result)`, after the snackbar is shown, set the flag:

```dart
_dismissSnackBarOnNextMove = true;
```

---

### Step 3 — Consume the flag in `_onBoardMove`

**File:** `src/lib/screens/add_line_screen.dart`

At the start of `_onBoardMove`, after the controller call returns `MoveAccepted`, check and consume the flag:

```dart
if (_dismissSnackBarOnNextMove) {
  _dismissSnackBarOnNextMove = false;
  _localMessengerKey.currentState?.clearSnackBars();
}
```

The flag is only consumed on `MoveAccepted`, not on `MoveBranchBlocked`. After it fires once it is cleared, so subsequent moves don't repeatedly call `clearSnackBars()`.

---

### Step 4 — Add widget tests

**File:** `src/test/screens/add_line_screen_test.dart`

Add two new test cases:

**Test A:** After confirm shows "Line saved" snackbar, playing a board move dismisses it.

**Test B:** After confirm shows "Line extended" snackbar, playing a board move dismisses it.

## Risks / Open Questions

1. **Pre-existing test failures:** The test suite already has ~12 failing tests before this change. New tests should be written carefully to not depend on those broken areas.
2. **Branching start:** When a user taps an intermediate pill and plays a new branch move (also `MoveAccepted`), the flag fires correctly — this is the right behaviour.
3. **No "New Line" button exists currently.** The spec mentions it "counts equally" if present, but no such button exists so nothing to handle there.
