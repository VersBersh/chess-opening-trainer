---
id: CT-12.2
title: Phone-sized debug window
epic: CT-12
depends: []
specs: []
files:
  - src/windows/runner/main.cpp
---
# CT-12.2: Phone-sized debug window

**Epic:** CT-12
**Depends on:** none

## Description

Investigate and implement running the debug window at phone dimensions (e.g., Pixel phone resolution) so the app can be previewed as it would appear on a mobile device during desktop development.

## Acceptance Criteria

- [ ] When running `flutter run -d windows` in debug mode, the window opens at approximately phone dimensions (e.g., 393x851 for Pixel 5, or similar)
- [ ] The window is resizable (the phone size is just the default, not a forced constraint)
- [ ] This only affects debug/development builds — release builds use normal windowing behavior
- [ ] Document the approach for other developers

## Notes

Options to investigate:
1. Set the initial window size in the Windows runner (`main.cpp` or equivalent)
2. Use a Flutter package (e.g., `window_manager`) to set the initial size programmatically
3. Use Flutter's `--dart-define` to pass phone dimensions at launch

The simplest approach is preferred. This is a developer-experience improvement, not a user-facing feature.
