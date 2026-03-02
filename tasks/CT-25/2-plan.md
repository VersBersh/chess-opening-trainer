# 2-plan.md

## Goal

Split `drill_screen.dart` (1261 lines) into four focused files: a model file for `SessionSummary`, a widget file for the session-complete UI, a controller file for `DrillController`, and a slimmed-down `drill_screen.dart` that handles only widget composition.

## Steps

**Step 1: Create `src/lib/models/session_summary.dart`**

File to create: `src/lib/models/session_summary.dart`

Extract the `SessionSummary` class (currently lines 117-141 of drill_screen.dart) into this new file. This is a plain data class with no imports. No dependencies on other steps.

**Step 2: Create `src/lib/controllers/drill_controller.dart`**

File to create: `src/lib/controllers/drill_controller.dart`

Extract from drill_screen.dart:
- `DrillConfig` class (lines 30-55)
- `DrillScreenState` sealed class hierarchy (lines 61-164): `DrillLoading`, `DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`, `DrillSessionComplete`, `DrillPassComplete`, `DrillFilterNoResults`
- `drillControllerProvider` declaration (lines 170-171)
- `DrillController` class (lines 177-607)

Imports needed:
```dart
import 'dart:collection';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_summary.dart';
import '../models/repertoire.dart';
import '../providers.dart';
import '../repositories/local/database.dart' show ReviewCard;
import '../repositories/review_repository.dart';
import '../services/chess_utils.dart';
import '../services/drill_engine.dart';
import '../widgets/chessboard_controller.dart';
```

Note: `DrillConfig` and the `DrillScreenState` sealed hierarchy are placed in the same file as `DrillController` because: (a) they form a tightly coupled contract; (b) this matches the pattern in `add_line_controller.dart` and `repertoire_browser_controller.dart` where state classes live in the controller file; (c) splitting them further would create excessive tiny files with circular dependency risk.

The `DrillSessionComplete` state variant references `SessionSummary`, so this file imports `models/session_summary.dart` (from Step 1).

Depends on: Step 1.

**Step 3: Create `src/lib/widgets/session_summary_widget.dart`**

File to create: `src/lib/widgets/session_summary_widget.dart`

Extract from DrillScreen:
- `_buildSessionComplete` method -- becomes `SessionSummaryWidget`, a public `StatelessWidget`
- `_formatDuration` helper -- becomes a private function in the same file
- `_buildBreakdownRow` helper -- becomes a private function or private widget
- `_formatNextDue` helper -- becomes a private function in the same file

The widget takes `SessionSummary` as a constructor parameter and renders the full session-complete Scaffold (matching current behavior exactly for drop-in compatibility).

Imports needed:
```dart
import 'package:flutter/material.dart';
import '../models/session_summary.dart';
import '../theme/drill_feedback_theme.dart';
```

Depends on: Step 1.

**Step 4: Update `src/lib/screens/drill_screen.dart`**

File to modify: `src/lib/screens/drill_screen.dart`

Remove all extracted code. The file should retain:
- `DrillScreen` widget class
- `_DrillFilterAutocomplete` private widget (only used by DrillScreen)
- `_buildPassComplete` and related methods still tightly coupled to DrillScreen

Add imports:
```dart
import '../controllers/drill_controller.dart';
import '../models/session_summary.dart';
import '../widgets/session_summary_widget.dart';
```

Add re-export for backward compatibility:
```dart
export '../controllers/drill_controller.dart';
```

This re-export ensures that `home_screen.dart`, test files, and any other code importing `drill_screen.dart` continues to see `DrillConfig`, `DrillController`, `drillControllerProvider`, `DrillScreenState`, `DrillSessionComplete`, etc. without changing their import lines.

Remove imports that are no longer directly needed (verify each is truly unused before removing).

In `_buildForState`, replace the `DrillSessionComplete` case to use `SessionSummaryWidget(summary: drillState.summary)`.

Depends on: Steps 1, 2, 3.

**Step 5: Verify imports in consuming files**

Files to check (no changes expected if Step 4 uses re-export):
- `src/lib/screens/home_screen.dart` -- imports `drill_screen.dart` for `DrillScreen` and `DrillConfig`
- `src/test/screens/drill_screen_test.dart` -- imports `drill_screen.dart` for `DrillScreen`, `DrillConfig`, `drillControllerProvider`
- `src/test/screens/drill_filter_test.dart` -- imports `drill_screen.dart` for `DrillScreen`, `DrillConfig`, `drillControllerProvider`
- `src/test/screens/home_screen_test.dart` -- imports `drill_screen.dart` for `DrillScreen`

With the re-export approach, no changes to these files are needed.

Depends on: Step 4.

**Step 6: Run tests to verify no regressions**

Run: `flutter test` from `src/`.

All existing tests must pass with zero changes (assuming re-export approach).

Depends on: Step 5.

## Risks / Open Questions

1. **Re-export vs. explicit import updates.** Using `export '../controllers/drill_controller.dart'` in `drill_screen.dart` is the lowest-risk approach. A follow-up task can optionally update imports to point directly at the controller file.

2. **SessionSummaryWidget as full Scaffold vs. body-only.** The current `_buildSessionComplete` returns a full Scaffold including AppBar. Extract as full Scaffold to match current behavior exactly, minimizing risk.

3. **_buildPassComplete placement.** The pass-complete UI is small and references `_buildFilterBox`, which creates a `_DrillFilterAutocomplete`. These are tightly coupled. Leave in `drill_screen.dart`.

4. **DrillConfig location.** Placed in the controller file alongside state types, consistent with `add_line_controller.dart` pattern.

5. **Dependency on CT-5.** CT-5 is already complete. This task is a pure refactoring of that completed work.
