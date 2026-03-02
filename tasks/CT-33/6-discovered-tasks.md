# CT-33: Discovered Tasks

## CT-34: Cap move tree indentation depth on narrow screens

**Title:** Cap move tree indentation depth on narrow screens
**Description:** The indentation formula `16.0 + depth * 24.0` grows unboundedly. With the enlarged 48dp tap targets (chevron + label icon = 96dp), text space on 360dp screens becomes tight at depth 4+ (only ~144dp remaining for text). Cap indentation at depth 5-6, or reduce per-level indent to 16-20px.
**Why discovered:** During CT-33, the horizontal space budget analysis (plan risk #2) revealed that enlarged tap targets exacerbate the existing indentation problem. Also noted by the plan reviewer as a separate UX concern that should not be bundled with tap target fixes.

## CT-35: Split move_tree_widget_test.dart into focused test files

**Title:** Split move_tree_widget_test.dart into focused test files
**Description:** The test file is ~554 lines and combines pure `buildVisibleNodes` unit tests with widget interaction tests. Split into `build_visible_nodes_test.dart` and `move_tree_widget_interaction_test.dart` (or similar) for better navigability and single-responsibility.
**Why discovered:** Flagged as a Minor code smell by the CT-33 design review (file exceeds 300-line threshold).
