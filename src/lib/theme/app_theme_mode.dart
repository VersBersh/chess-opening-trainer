import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';

// ---------------------------------------------------------------------------
// Theme mode choices
// ---------------------------------------------------------------------------

/// User-selectable theme modes, each mapping to a [ThemeMode] value.
enum ThemeModeChoice {
  light('Light', ThemeMode.light),
  dark('Dark', ThemeMode.dark),
  system('System', ThemeMode.system);

  const ThemeModeChoice(this.label, this.themeMode);
  final String label;
  final ThemeMode themeMode;
}

// ---------------------------------------------------------------------------
// Theme mode provider
// ---------------------------------------------------------------------------

const _themeModeKey = 'themeMode';

final appThemeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  late SharedPreferences _prefs;

  @override
  ThemeMode build() {
    _prefs = ref.read(sharedPreferencesProvider);

    final persisted = _prefs.getString(_themeModeKey);
    final choice = persisted != null
        ? ThemeModeChoice.values
              .where((c) => c.name == persisted)
              .firstOrNull ??
            ThemeModeChoice.system
        : ThemeModeChoice.system;

    return choice.themeMode;
  }

  void setThemeMode(ThemeModeChoice choice) {
    _prefs.setString(_themeModeKey, choice.name);
    state = choice.themeMode;
  }
}
