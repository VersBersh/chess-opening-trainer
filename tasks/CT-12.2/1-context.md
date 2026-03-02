# 1-context.md

## Relevant Files

- `src/windows/runner/main.cpp` -- Entry point for the Windows runner; creates the `FlutterWindow` with hardcoded `origin(10, 10)` and `size(1280, 720)`. This is the primary file to modify.
- `src/windows/runner/win32_window.cpp` -- Implements `Win32Window::Create()` which receives the `Size` parameter and applies DPI scaling via `FlutterDesktopGetDpiForMonitor` before calling Win32 `CreateWindow`. Must understand this to set correct logical dimensions.
- `src/windows/runner/win32_window.h` -- Defines `Win32Window::Size` and `Win32Window::Point` structs used by `Create()`.
- `src/windows/CMakeLists.txt` -- Top-level CMake configuration for the Windows build. Defines `Debug`, `Profile`, and `Release` build configurations. Already defines `_DEBUG` preprocessor symbol for Debug builds via `$<$<CONFIG:Debug>:_DEBUG>` in the `APPLY_STANDARD_SETTINGS` function.
- `src/windows/runner/CMakeLists.txt` -- Runner CMake configuration. Calls `apply_standard_settings(${BINARY_NAME})` which propagates the `_DEBUG` define.
- `src/windows/runner/Runner.rc` -- Resource script that already uses `#ifdef _DEBUG` to set version info file flags, confirming the `_DEBUG` preprocessor symbol is available in Debug builds.
- `src/lib/main.dart` -- Flutter app entry point; uses `kDebugMode` from `package:flutter/foundation.dart` for debug-only behavior (dev seed data).
- `src/README.md` -- Default Flutter README; a natural place to add developer documentation about the debug window behavior.

## Architecture

The Windows runner is the standard Flutter Windows embedding. The flow is:

1. **`main.cpp` (wWinMain)** -- Creates a `FlutterWindow` with an explicit `Size(1280, 720)` and `Point(10, 10)`, calls `window.Create(title, origin, size)`, then enters the Win32 message loop.

2. **`Win32Window::Create()`** -- Receives the logical size, reads DPI from the target monitor via `FlutterDesktopGetDpiForMonitor`, computes a scale factor (`dpi / 96.0`), and calls `CreateWindow` with the scaled pixel values. The size passed from `main.cpp` is in logical units, not physical pixels -- the DPI scaling is handled internally.

3. **`FlutterWindow::OnCreate()`** -- Called after the Win32 window is created. Gets the client area rect and passes it to `FlutterViewController` to create the Flutter rendering surface at the correct resolution.

4. **Build configurations** -- CMake defines three build types: Debug, Profile, Release. The `_DEBUG` preprocessor macro is automatically defined for Debug builds. This macro is already used in `Runner.rc`, confirming it is available in `main.cpp` as well.

Key constraints:
- The size values in `main.cpp` are **logical pixels** -- DPI scaling is applied inside `Win32Window::Create()`.
- The window uses `WS_OVERLAPPEDWINDOW` style -- fully resizable by default.
- No existing mechanism to pass dimensions from Dart/Flutter back to the native runner at startup.
