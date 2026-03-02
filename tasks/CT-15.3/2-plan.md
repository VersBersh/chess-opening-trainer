# CT-15.3 Plan

## Goal

Define a shared action model (icon, label, enabled, handler) within `BrowserActionBar` so that each action is specified once, then rendered by two layout adapters (compact `IconButton` vs full-width `TextButton.icon`), eliminating the duplication and drift risk.

## Steps

**Step 1: Define `_ActionDef` data class in `browser_action_bar.dart`**

Add a private data class at the top of `src/lib/widgets/browser_action_bar.dart`:

```dart
class _ActionDef {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionDef({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}
```

The `onPressed` field being nullable naturally expresses enabled vs disabled, matching the existing convention. The `label` serves double duty: visible text in full-width mode and tooltip in compact mode. Private to the file.

**Step 2: Add a `_actions` getter to `BrowserActionBar` that builds the shared action list**

Add a getter inside the `BrowserActionBar` class:

```dart
List<_ActionDef> get _actions => [
  _ActionDef(icon: Icons.add, label: 'Add Line', onPressed: onAddLine),
  _ActionDef(icon: Icons.file_upload, label: 'Import', onPressed: onImport),
  _ActionDef(icon: Icons.label, label: 'Label', onPressed: onEditLabel),
  _ActionDef(icon: Icons.bar_chart, label: 'Stats', onPressed: onViewCardStats),
  _ActionDef(icon: Icons.delete, label: deleteLabel, onPressed: onDelete),
];
```

Each action is defined exactly once. `deleteLabel` is used for the delete action, preserving dynamic `'Delete'` / `'Delete Branch'` behavior.

Depends on: Step 1.

**Step 3: Rewrite `_buildCompact()` to iterate over `_actions`**

Replace the body with:

```dart
Widget _buildCompact() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (final action in _actions)
        IconButton(
          onPressed: action.onPressed,
          icon: Icon(action.icon),
          tooltip: action.label,
        ),
    ],
  );
}
```

Produces identical widget tree. Test finders like `find.widgetWithIcon(IconButton, Icons.add)` and `find.byTooltip('Add Line')` continue to match.

Depends on: Step 2.

**Step 4: Rewrite `_buildFullWidth()` to iterate over `_actions`**

Replace the body with:

```dart
Widget _buildFullWidth() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (final action in _actions)
        Flexible(
          child: TextButton.icon(
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: 18),
            label: Text(action.label),
          ),
        ),
    ],
  );
}
```

Produces identical widget tree. Test finders like `find.widgetWithText(TextButton, 'Add Line')` continue to match.

Depends on: Step 2.

**Step 5: Run existing tests, verify no regressions**

Run all repertoire browser tests. All should pass unchanged because the rendered widget tree is identical.

Depends on: Steps 3, 4.

## Risks / Open Questions

1. **No behavioral change** — purely structural refactor. Only risk is accidentally changing the widget tree. Mitigated by identical widget types, constructor arguments, and nesting.

2. **`_ActionDef` naming** — codebase uses `MovePillData` for similar models. `_ActionDef` better communicates this is a rendering template. Either name works; class is private to the file.

3. **Future extensibility** — if a future action needs different rendering per mode, `_ActionDef` would need extension. Simple model suffices for now.

4. **No changes to other files** — `BrowserActionBar` constructor signature stays the same. Refactor is entirely internal.

5. **Dynamic `deleteLabel`** — handled naturally by `_actions` being a getter (recomputed each build) that reads `deleteLabel` from the widget field.
