# 2-plan.md

## Goal

Set the Windows runner's initial window size to phone dimensions (393x851, Pixel 5) in debug builds only, using the `_DEBUG` preprocessor macro already available in the C++ runner.

## Steps

1. **Modify `src/windows/runner/main.cpp` to use phone dimensions in debug builds.**
   - File: `src/windows/runner/main.cpp`
   - Wrap the existing `origin` and `size` declarations in an `#ifdef _DEBUG` / `#else` / `#endif` block.
   - Debug build: `Win32Window::Size size(393, 851)` and `Win32Window::Point origin(10, 10)` (origin unchanged).
   - Release/Profile build: Keep the existing `Win32Window::Size size(1280, 720)` and `Win32Window::Point origin(10, 10)`.
   - Add a comment explaining the phone dimensions (e.g., "Pixel 5 logical resolution for mobile layout testing").
   - The exact change:
     ```cpp
     FlutterWindow window(project);
     Win32Window::Point origin(10, 10);
     #ifdef _DEBUG
       // Pixel 5 logical resolution for mobile layout preview during development.
       // The window is still resizable — this is just the default size.
       Win32Window::Size size(393, 851);
     #else
       Win32Window::Size size(1280, 720);
     #endif
     ```
   - No dependencies on other steps.

2. **Update `src/README.md` with a short developer note about the debug window behavior.**
   - File: `src/README.md`
   - Add a section titled "Development" that explains:
     - In debug builds (`flutter run -d windows`), the window opens at Pixel 5 phone dimensions (393x851) to preview mobile layout.
     - The window is fully resizable; the phone size is just the default.
     - Release builds use the standard 1280x720 default.
     - To change the debug dimensions, edit the `#ifdef _DEBUG` block in `windows/runner/main.cpp`.
   - Depends on step 1 being decided/finalized (so the dimensions quoted are accurate).

## Risks / Open Questions

1. **Outer vs. client area dimensions.** The `size` parameter passed to `Win32Window::Create()` is used as the outer window size (including title bar and borders), not the client area. This means the actual Flutter rendering surface will be slightly smaller than 393x851. For approximate phone-dimension previewing, this is acceptable.

2. **DPI scaling interaction.** The `Win32Window::Create()` method scales the provided size by the monitor's DPI factor. At 100% scaling (96 DPI), 393x851 produces a 393x851 pixel window. At 150% scaling (144 DPI), it produces a 590x1277 pixel window, which still represents 393x851 logical pixels to Flutter. This is correct behavior.

3. **Window exceeding screen height.** On a 1080p monitor at 150% DPI scaling, the physical window height becomes ~1277 pixels, which exceeds 1080p. Windows will clip or adjust the window position. The window is resizable so developers can manually adjust. No mitigation needed.

4. **No Dart-side changes needed.** The window sizing is purely a native runner concern -- no Dart code needs to know about or coordinate with the window size.

5. **Simplest approach confirmed.** Of the three options in the task notes -- (1) native runner `main.cpp`, (2) `window_manager` package, (3) `--dart-define` -- option 1 is the simplest. It requires no new dependencies, no Dart code changes, and uses infrastructure (`_DEBUG` macro) that is already in place.
