import 'package:flutter/material.dart';

/// Theme extension that defines pill color tokens.
///
/// Registered in [ThemeData.extensions] so that pill widgets can read
/// colours from the theme rather than hard-coding them.
@immutable
class PillTheme extends ThemeExtension<PillTheme> {
  /// Fill colour for all pills regardless of save state.
  final Color pillColor;

  /// Border colour applied to the currently focused pill.
  final Color focusedBorderColor;

  /// Text colour for pills. Defaults to [Colors.white] so that
  /// existing call sites (including tests) remain valid without modification.
  final Color textOnPillColor;

  const PillTheme({
    required this.pillColor,
    required this.focusedBorderColor,
    this.textOnPillColor = Colors.white,
  });

  /// Light-mode pill colors.
  const PillTheme.light()
      : pillColor = const Color(0xFF5B8FDB),
        focusedBorderColor = const Color(0xFF1A56A8),
        textOnPillColor = Colors.white;

  /// Dark-mode pill colors — slightly muted to suit dark surfaces.
  const PillTheme.dark()
      : pillColor = const Color(0xFF3A6BB5),
        focusedBorderColor = const Color(0xFF7ABAFF),
        textOnPillColor = const Color(0xFFE0E0E0);

  @override
  PillTheme copyWith({
    Color? pillColor,
    Color? focusedBorderColor,
    Color? textOnPillColor,
  }) {
    return PillTheme(
      pillColor: pillColor ?? this.pillColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
      textOnPillColor: textOnPillColor ?? this.textOnPillColor,
    );
  }

  @override
  PillTheme lerp(PillTheme? other, double t) {
    if (other is! PillTheme) return this;
    return PillTheme(
      pillColor: Color.lerp(pillColor, other.pillColor, t)!,
      focusedBorderColor:
          Color.lerp(focusedBorderColor, other.focusedBorderColor, t)!,
      textOnPillColor:
          Color.lerp(textOnPillColor, other.textOnPillColor, t)!,
    );
  }
}
