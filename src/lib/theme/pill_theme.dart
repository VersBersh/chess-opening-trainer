import 'package:flutter/material.dart';

/// Theme extension that defines pill color tokens.
///
/// Registered in [ThemeData.extensions] so that pill widgets can read
/// colours from the theme rather than hard-coding them.
@immutable
class PillTheme extends ThemeExtension<PillTheme> {
  /// Fill colour for saved (persisted) pills.
  final Color savedColor;

  /// Fill colour for unsaved (buffered) pills -- a lighter/muted variant
  /// so saved and unsaved pills remain visually distinguishable.
  final Color unsavedColor;

  /// Border colour applied to the currently focused pill.
  final Color focusedBorderColor;

  /// Text colour for saved pills. Defaults to [Colors.white] so that
  /// existing call sites (including tests) remain valid without modification.
  final Color textOnSavedColor;

  const PillTheme({
    required this.savedColor,
    required this.unsavedColor,
    required this.focusedBorderColor,
    this.textOnSavedColor = Colors.white,
  });

  /// Light-mode pill colors.
  const PillTheme.light()
      : savedColor = const Color(0xFF5B8FDB),
        unsavedColor = const Color(0xFFB0CBF0),
        focusedBorderColor = const Color(0xFF1A56A8),
        textOnSavedColor = Colors.white;

  /// Dark-mode pill colors — slightly muted to suit dark surfaces.
  const PillTheme.dark()
      : savedColor = const Color(0xFF3A6BB5),
        unsavedColor = const Color(0xFF2A3E5C),
        focusedBorderColor = const Color(0xFF7ABAFF),
        textOnSavedColor = const Color(0xFFE0E0E0);

  @override
  PillTheme copyWith({
    Color? savedColor,
    Color? unsavedColor,
    Color? focusedBorderColor,
    Color? textOnSavedColor,
  }) {
    return PillTheme(
      savedColor: savedColor ?? this.savedColor,
      unsavedColor: unsavedColor ?? this.unsavedColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
      textOnSavedColor: textOnSavedColor ?? this.textOnSavedColor,
    );
  }

  @override
  PillTheme lerp(PillTheme? other, double t) {
    if (other is! PillTheme) return this;
    return PillTheme(
      savedColor: Color.lerp(savedColor, other.savedColor, t)!,
      unsavedColor: Color.lerp(unsavedColor, other.unsavedColor, t)!,
      focusedBorderColor:
          Color.lerp(focusedBorderColor, other.focusedBorderColor, t)!,
      textOnSavedColor:
          Color.lerp(textOnSavedColor, other.textOnSavedColor, t)!,
    );
  }
}
