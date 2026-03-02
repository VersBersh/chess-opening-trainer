# 4-impl-notes.md

## Files Modified

- `src/windows/runner/main.cpp` — Wrapped window size in `#ifdef _DEBUG` to use 393x851 (Pixel 5) in debug builds, keeping 1280x720 for release/profile builds.
- `src/README.md` — Added "Development" section documenting the debug window size behavior.

## Deviations from Plan

None. Both steps implemented as planned.

## Discovered Tasks / Follow-up Work

None.
