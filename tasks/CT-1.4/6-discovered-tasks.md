# CT-1.4 Discovered Tasks

## 1. Extract shared test fakes

- **Suggested ID:** CT-0.5
- **Title:** Extract shared test fake repositories
- **Description:** `FakeRepertoireRepository` and `FakeReviewRepository` are duplicated in `drill_screen_test.dart` and `home_screen_test.dart` (with slight differences). Extract them into a shared `test/helpers/fake_repositories.dart` file to reduce duplication and prevent drift.
- **Why discovered:** Both test files needed the same fake implementations with minor variations. Duplication was chosen for speed during CT-1.4 but should be cleaned up.

## 2. Migrate RepertoireBrowserScreen to Riverpod

- **Suggested ID:** CT-3.1 (or append to CT-2 epic)
- **Title:** Migrate RepertoireBrowserScreen to Riverpod
- **Description:** `RepertoireBrowserScreen` is the last screen still taking `AppDatabase` directly as a constructor parameter. Once migrated to Riverpod (reading repositories from providers), the `db` parameter can be removed from `HomeScreen` and the `Widget home` parameter from `ChessTrainerApp`, completing the Riverpod migration across all screens.
- **Why discovered:** CT-1.4 had to keep `AppDatabase db` on `HomeScreen` as transitional plumbing solely to pass it to `RepertoireBrowserScreen` during navigation. This is a known architectural debt.

## 3. Move providers to dedicated module (DONE)

- **Note:** This was flagged by the design review and fixed during CT-1.4 implementation. Providers were moved from `main.dart` to `lib/providers.dart`. No further action needed.
