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

  const PillTheme({
    required this.savedColor,
    required this.unsavedColor,
    required this.focusedBorderColor,
  });

  @override
  PillTheme copyWith({
    Color? savedColor,
    Color? unsavedColor,
    Color? focusedBorderColor,
  }) {
    return PillTheme(
      savedColor: savedColor ?? this.savedColor,
      unsavedColor: unsavedColor ?? this.unsavedColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
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
    );
  }
}
