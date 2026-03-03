# CT-50.1: Discovered Tasks

## New Tasks

### CT-50.x: Remove or reassign `kBannerGapInsets` from spacing.dart

**Title:** Clean up orphaned `kBannerGapInsets` constant

**Description:** After migrating `browser_content.dart` to use `kBoardFrameTopInsets`, the `kBannerGapInsets` constant in `spacing.dart` has no remaining usages in the codebase. Audit whether it is used anywhere else (e.g. tests, other widgets), and either remove it or add a deprecation note pointing to `kBoardFrameTopInsets`.

**Why discovered:** The sole call-site of `kBannerGapInsets` was updated to use the new semantic constant as part of CT-50.1. The constant now appears dead.

---

### CT-50.x: Extract focused layout sub-widgets from drill_screen.dart and add_line_screen.dart

**Title:** Reduce file size in drill_screen.dart and add_line_screen.dart

**Description:** Both `drill_screen.dart` (552 lines) and `add_line_screen.dart` (611 lines) exceed the 300-line threshold and mix layout composition with event handling and feedback logic. Incrementally extract focused widget builders (board section, action/status section, feedback/snackbar presenters) to keep each file under ~300 lines and reduce future regression risk.

**Why discovered:** Flagged by the design review (Review B) as a pre-existing file size smell. While not caused by CT-50.1, the review highlighted it as a source of ongoing review cost when making layout changes.
