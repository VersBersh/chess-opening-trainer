# CT-21: Plan

## Goal

Remove the `Widget home` parameter from `ChessTrainerApp`, completing the Riverpod migration by eliminating the last transitional plumbing.

## Steps

### 1. Remove `home` field and parameter from `ChessTrainerApp`

**File:** `src/lib/main.dart`

- Remove `final Widget home;` (line 45)
- Change `const ChessTrainerApp({super.key, required this.home});` to `const ChessTrainerApp({super.key});` (line 47)
- Change `home: home` to `home: const HomeScreen()` in the `build` method (line 96)

### 2. Update `main()` call site

**File:** `src/lib/main.dart`

- Change `const ChessTrainerApp(home: HomeScreen())` to `const ChessTrainerApp()` (line 39)
- The `import 'screens/home_screen.dart'` (line 10) is still needed since `ChessTrainerApp.build()` now references `HomeScreen` directly.

**Depends on:** Step 1

### 3. Verify no regressions

Run `flutter analyze` and `flutter test` to confirm all tests pass. No test file references `ChessTrainerApp`, so no test changes are needed.

**Depends on:** Steps 1, 2

## Risks / Open Questions

1. **Most acceptance criteria already met.** `RepertoireBrowserScreen` already uses Riverpod providers (no `AppDatabase` param). `HomeScreen` already has no `db` param. The actual remaining work is solely removing `Widget home` from `ChessTrainerApp`.

2. **Minimal blast radius.** This is a single-file, ~3-line change. No test file uses `ChessTrainerApp`.
