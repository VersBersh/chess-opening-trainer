import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/theme/app_theme_mode.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer({SharedPreferences? overridePrefs}) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider
            .overrideWithValue(overridePrefs ?? prefs),
      ],
    );
  }

  group('ThemeModeNotifier — default values', () {
    test('defaults to ThemeMode.system on fresh prefs', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final state = container.read(appThemeModeProvider);
      expect(state, ThemeMode.system);
    });
  });

  group('ThemeModeNotifier — setThemeMode', () {
    test('updates state when setThemeMode is called with dark', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeModeChoice.dark);

      final state = container.read(appThemeModeProvider);
      expect(state, ThemeMode.dark);
    });

    test('updates state when setThemeMode is called with light', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeModeChoice.light);

      final state = container.read(appThemeModeProvider);
      expect(state, ThemeMode.light);
    });

    test('persists themeMode to SharedPreferences', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeModeChoice.dark);

      expect(prefs.getString('themeMode'), 'dark');
    });
  });

  group('ThemeModeNotifier — persistence round-trip', () {
    test('loads persisted value on rebuild', () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': 'light',
      });
      final persistedPrefs = await SharedPreferences.getInstance();
      final container = createContainer(overridePrefs: persistedPrefs);
      addTearDown(container.dispose);

      final state = container.read(appThemeModeProvider);
      expect(state, ThemeMode.light);
    });

    test('falls back to system for unknown persisted string', () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': 'nonexistent_mode',
      });
      final badPrefs = await SharedPreferences.getInstance();
      final container = createContainer(overridePrefs: badPrefs);
      addTearDown(container.dispose);

      final state = container.read(appThemeModeProvider);
      expect(state, ThemeMode.system);
    });
  });
}
