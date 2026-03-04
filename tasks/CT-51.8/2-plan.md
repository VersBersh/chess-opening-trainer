# CT-51.8: Plan

## Goal

Anchor the Add Line action buttons to a fixed bottom position by moving them into `Scaffold.bottomNavigationBar`, and make the pill area between the board and the buttons independently scrollable.

## Steps

### Step 1 — Move action bar to `Scaffold.bottomNavigationBar` in `build()`

**File:** `src/lib/screens/add_line_screen.dart`

In the `build()` method, add `bottomNavigationBar` to the `Scaffold`. The `_localMessengerKey` ScaffoldMessenger wraps the Scaffold, so `bottomNavigationBar` is part of the Scaffold's own layout:

```dart
Scaffold(
  appBar: AppBar(title: const Text('Add Line')),
  bottomNavigationBar: state.isLoading ? null : _buildActionBar(context, state),
  body: state.isLoading
      ? const Center(child: CircularProgressIndicator())
      : _buildContent(context, state),
)
```

### Step 2 — Add `SafeArea` wrapper to `_buildActionBar`

**File:** `src/lib/screens/add_line_screen.dart`

Wrap the existing `Padding > Row` in `_buildActionBar` with a `SafeArea` so the buttons respect the iOS home indicator and Android nav bar:

```dart
Widget _buildActionBar(BuildContext context, AddLineState state) {
  final canEditLabel = _controller.canEditLabel;
  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [ /* same buttons as before */ ],
      ),
    ),
  );
}
```

### Step 3 — Restructure `_buildContent` to use bounded scrollable pill area

**File:** `src/lib/screens/add_line_screen.dart`

Replace the `SingleChildScrollView > Column` body with a `Column` body where only the pill area is wrapped in `Expanded > SingleChildScrollView`:

```dart
Widget _buildContent(BuildContext context, AddLineState state) {
  final displayName = state.aggregateDisplayName;

  return Column(
    children: [
      // Aggregate display name (CT-51.7 will move this below board)
      if (displayName.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            displayName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

      const SizedBox(height: kBoardFrameTopGap),

      // Chessboard — direct Column child, never displaced by pill count
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: AspectRatio(
          aspectRatio: 1,
          child: ChessboardWidget(
            controller: _boardController,
            orientation: state.boardOrientation,
            playerSide: PlayerSide.both,
            onMove: _onBoardMove,
          ),
        ),
      ),

      // Scrollable pill area — bounded by space between board and action bar
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MovePillsWidget(
                pills: state.pills,
                focusedIndex: state.focusedPillIndex,
                onPillTapped: _onPillTapped,
              ),
              if (_isLabelEditorVisible) _buildInlineLabelEditor(state),
              if (_parityWarning != null) _buildParityWarning(_parityWarning!),
              if (_controller.isExistingLine) _buildExistingLineInfo(context),
            ],
          ),
        ),
      ),
    ],
  );
}
```

Key changes vs current:
- Outer `SingleChildScrollView` removed; `Column` is now the direct return.
- `MovePillsWidget` + inline widgets wrapped in `Expanded > SingleChildScrollView`.
- `_buildActionBar(context, state)` removed from Column children (it's now in `bottomNavigationBar`).

Depends on: Steps 1 and 2.

## Risks / Open Questions

1. **Aggregate display name above board.** The current code and this plan leave the display name above the board — CT-51.7 is the correct task to move it below. No change here to avoid scope creep.

2. **ScaffoldMessenger snackbars.** The screen uses `_localMessengerKey` on a `ScaffoldMessenger` that wraps the `Scaffold`. Snackbars float above `bottomNavigationBar` automatically. No change needed.

3. **`state.isLoading` guard on `bottomNavigationBar`.** When loading, `bottomNavigationBar: null` hides the action bar — same as the body showing a spinner. This is correct behavior.

4. **iOS safe area.** Without `SafeArea`, buttons overlap the home indicator. Step 2 adds this fix.
