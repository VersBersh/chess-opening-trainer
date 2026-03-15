# CT-65: Implementation Plan

## Goal

Cap the visual indentation of move tree rows so that deep lines remain readable on narrow (360dp) screens, without changing the appearance of shallow trees.

## Steps

### 1. Add indentation constants to `move_tree_widget.dart`

**File:** `src/lib/widgets/move_tree_widget.dart`

Add three named constants near the top of the file (after the imports, before the `VisibleNode` class):

```dart
/// Base left padding for all tree rows.
const double kTreeRowPaddingLeft = 8.0;

/// Indentation per depth level.
const double kIndentPerLevel = 20.0;

/// Maximum depth level that receives additional indentation.
/// Depths beyond this value are indented the same as this depth.
const int kMaxIndentDepth = 5;
```

These are top-level (library-private naming is not needed because the test file must reference them). Choosing `kMaxIndentDepth = 5` means the maximum left padding is `8 + 5*20 = 108dp`, leaving `360 - 108 - 8 (right) - 28 (chevron) = 216dp` for text on a 360dp screen -- sufficient for chain notation.

### 2. Add `import 'dart:math'` and extract a top-level indentation helper

**File:** `src/lib/widgets/move_tree_widget.dart`

Add `import 'dart:math';` to the imports.

Add a **top-level** helper function (next to `buildVisibleNodes`, which is already top-level for the same testability reason -- see review issue #9). It must be top-level, not a static method on `_MoveTreeNodeTile`, because the test file cannot access members of a private class.

The helper must reuse the constants from Step 1, and must avoid `int.clamp()` (which returns `num` in some Dart versions / analysis contexts). Use `min`/`max` from `dart:math` instead:

```dart
/// Returns the left padding for a tree row at the given [depth].
///
/// Indentation grows linearly up to [kMaxIndentDepth], then stays constant.
double computeTreeIndent(int depth) {
  final effectiveDepth = max(0, min(depth, kMaxIndentDepth));
  return kTreeRowPaddingLeft + effectiveDepth * kIndentPerLevel;
}
```

No magic numbers -- all values come from the constants defined in Step 1.

### 3. Update `_MoveTreeNodeTile.build()` to use the helper

**File:** `src/lib/widgets/move_tree_widget.dart`

Replace lines 234-236:

```dart
// Before:
padding: EdgeInsets.only(
  left: 8.0 + node.depth * 20.0,
  right: 8.0,
),

// After:
padding: EdgeInsets.only(
  left: computeTreeIndent(node.depth),
  right: 8.0,
),
```

This is the only behavioral change in production code. Shallow trees (depth 0-5) produce the exact same pixel values as before. Depth 6+ is capped at the depth-5 indentation.

### 4. Add unit tests for `computeTreeIndent`

**File:** `src/test/widgets/move_tree_widget_test.dart`

Add a new `group('computeTreeIndent', ...)` at the top level of `main()`, containing:

- **depth 0 returns base padding:** `expect(computeTreeIndent(0), kTreeRowPaddingLeft)` (i.e. 8.0)
- **depth 1 returns base + one level:** `expect(computeTreeIndent(1), kTreeRowPaddingLeft + kIndentPerLevel)` (i.e. 28.0)
- **depth at max (5) returns base + 5 levels:** `expect(computeTreeIndent(5), kTreeRowPaddingLeft + kMaxIndentDepth * kIndentPerLevel)` (i.e. 108.0)
- **depth beyond max is capped:** `expect(computeTreeIndent(6), 108.0)` and `expect(computeTreeIndent(10), 108.0)`
- **negative depth clamps to 0:** `expect(computeTreeIndent(-1), kTreeRowPaddingLeft)` (i.e. 8.0)

Because `computeTreeIndent` is a top-level function in `move_tree_widget.dart`, and the test file already imports that file (for `buildVisibleNodes`), the helper is directly callable from tests with no additional setup.

### 5. Add a widget test verifying the indentation cap

**File:** `src/test/widgets/move_tree_widget_test.dart`

Add a widget test inside the existing `group('MoveTreeWidget', ...)`:

**Test: "indentation is capped for deeply nested nodes"**

Build a tree with a branch at every level to force depth increases (e.g., depth 0 branches into two children, one of which branches again, etc., reaching depth 7+). Expand all branch nodes. Then:

1. Pump the widget inside a constrained `SizedBox(width: 360, height: 600)` to simulate a narrow screen.
2. Find the `Padding` widget for the deepest row (depth 7+).
3. Assert that `padding.left` equals `computeTreeIndent(5)` (i.e., 108.0), not `8.0 + 7*20.0`.
4. Also assert that a shallow row (depth 1) still has `padding.left == 28.0` to confirm no regression.

To build a tree reaching depth 7, use nested `buildBranch` calls. Each branch point adds depth. The test helper `buildBranch` already supports arbitrary parent chaining.

## Risks / Open Questions

1. **Choice of max depth (5 vs 6):** The value 5 is conservative. At depth 5 the left padding is 108dp, consuming 30% of a 360dp screen. Depth 6 would consume 36% (128dp). Either works -- 5 gives more text room. This could be made configurable per-widget if needed later, but a hardcoded constant is sufficient for now.

2. **Visual differentiation of deep nodes:** Once indentation is capped, nodes at depth 5, 6, and 7 will be visually at the same indent level. This could theoretically confuse users about hierarchy. In practice, chess repertoire trees rarely branch more than 4-5 levels deep (branching depth, not move depth), so this is unlikely to be a real issue. If it becomes one, a future enhancement could add a subtle depth indicator (e.g., a small depth number or a vertical guide line).

3. **No model changes needed:** The `VisibleNode.depth` field retains its true value. The cap is purely visual (in the padding computation). This keeps tree semantics correct for any future features that depend on accurate depth.

4. **Note on `int.clamp` return type (review issue #1):** In Dart 3.x, `int.clamp(int, int)` technically returns `int`, so the original code would likely pass analysis. However, this has been a source of confusion across Dart versions (it returned `num` before Dart 2.1), and some linter configurations still flag it. Using `min`/`max` from `dart:math` is clearer and avoids any ambiguity, so the plan uses that approach.
