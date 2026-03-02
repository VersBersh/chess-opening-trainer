# CT-32: Implementation Plan

## Goal

Extract the hardcoded banner gap spacing values from `add_line_screen.dart` and `browser_content.dart` into a shared constant in a new theme constants file, and update both files to reference it.

## Steps

### 1. Create `src/lib/theme/spacing.dart` with the shared constant

**File to create:** `src/lib/theme/spacing.dart`

The two current implementations use different values (12dp in add_line_screen, 8dp in browser_content). Standardize on `8.0` to match the task description's reference to `EdgeInsets.only(top: 8)`.

Export two forms for ergonomic use in both call sites:

```dart
import 'package:flutter/widgets.dart';

/// Vertical spacing between a screen's app bar / banner and its first content
/// element. See design/ui-guidelines.md "Banner gap" rule.
const double kBannerGap = 8;

/// [kBannerGap] as top-only EdgeInsets, for use with [Padding] widgets.
const EdgeInsets kBannerGapInsets = EdgeInsets.only(top: kBannerGap);
```

**Depends on:** Nothing.

### 2. Update `browser_content.dart` to use the shared constant

**File to modify:** `src/lib/widgets/browser_content.dart`

Add import for spacing file. At line 92, replace `const EdgeInsets.only(top: 8)` with `kBannerGapInsets`.

**Depends on:** Step 1.

### 3. Update `add_line_screen.dart` to use the shared constant

**File to modify:** `src/lib/screens/add_line_screen.dart`

Add import for spacing file. At line 314, replace `const SizedBox(height: 12)` with `const SizedBox(height: kBannerGap)`.

This changes the gap from 12dp to 8dp. If 12dp is preferred, adjust the constant in step 1.

**Depends on:** Step 1.

### 4. Verify no other hardcoded banner gap values remain

Search codebase for other `EdgeInsets.only(top: 8)` and `SizedBox(height: 12)` that serve as banner gaps. Based on exploration, no other banner-gap-specific usages exist.

**Depends on:** Steps 2 and 3.

### 5. Run existing tests

Run `flutter test` to confirm no regressions. No tests currently assert on exact banner gap pixel values.

**Depends on:** Steps 2 and 3.

## Risks / Open Questions

1. **Value discrepancy: 8dp vs 12dp.** CT-9.1 chose 12dp, CT-9.4 chose 8dp. The task description references `EdgeInsets.only(top: 8)` for both, suggesting 8dp is the target. The Add Line screen will visually shrink its gap from 12dp to 8dp.

2. **Different gap semantics.** The Add Line screen's gap is conditional (only when banner visible), while the browser's gap is unconditional. The shared constant captures the value, not the conditional logic.

3. **File naming convention.** `spacing.dart` in `src/lib/theme/` is a slight departure from the existing ThemeExtension pattern, but is the natural home for design-system tokens.
