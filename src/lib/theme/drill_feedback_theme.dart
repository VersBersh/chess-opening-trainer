import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// DrillFeedbackTheme — semantic colors for drill feedback overlays
// ---------------------------------------------------------------------------

/// Theme extension that defines drill feedback color tokens.
///
/// Registered in [ThemeData.extensions] so that the drill screen can read
/// feedback colors from the theme rather than hard-coding them.
@immutable
class DrillFeedbackTheme extends ThemeExtension<DrillFeedbackTheme> {
  /// Arrow color for correct-move feedback (green).
  final Color correctArrowColor;

  /// Arrow color for sibling-line corrections (blue).
  final Color siblingArrowColor;

  /// Circle/annotation color for wrong-move feedback (red).
  final Color mistakeColor;

  /// Dot color for "Perfect" rows in the session summary.
  final Color perfectColor;

  /// Dot color for "Hesitation" rows in the session summary.
  final Color hesitationColor;

  const DrillFeedbackTheme({
    required this.correctArrowColor,
    required this.siblingArrowColor,
    required this.mistakeColor,
    required this.perfectColor,
    required this.hesitationColor,
  });

  @override
  DrillFeedbackTheme copyWith({
    Color? correctArrowColor,
    Color? siblingArrowColor,
    Color? mistakeColor,
    Color? perfectColor,
    Color? hesitationColor,
  }) {
    return DrillFeedbackTheme(
      correctArrowColor: correctArrowColor ?? this.correctArrowColor,
      siblingArrowColor: siblingArrowColor ?? this.siblingArrowColor,
      mistakeColor: mistakeColor ?? this.mistakeColor,
      perfectColor: perfectColor ?? this.perfectColor,
      hesitationColor: hesitationColor ?? this.hesitationColor,
    );
  }

  @override
  DrillFeedbackTheme lerp(DrillFeedbackTheme? other, double t) {
    if (other is! DrillFeedbackTheme) return this;
    return DrillFeedbackTheme(
      correctArrowColor:
          Color.lerp(correctArrowColor, other.correctArrowColor, t)!,
      siblingArrowColor:
          Color.lerp(siblingArrowColor, other.siblingArrowColor, t)!,
      mistakeColor: Color.lerp(mistakeColor, other.mistakeColor, t)!,
      perfectColor: Color.lerp(perfectColor, other.perfectColor, t)!,
      hesitationColor:
          Color.lerp(hesitationColor, other.hesitationColor, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// Light and dark variants
// ---------------------------------------------------------------------------

/// Light-mode drill feedback colors (existing hardcoded values).
const drillFeedbackThemeLight = DrillFeedbackTheme(
  correctArrowColor: Color(0xFF44CC44),
  siblingArrowColor: Color(0xFF4488FF),
  mistakeColor: Color(0xFFCC4444),
  perfectColor: Color(0xFF4CAF50),
  hesitationColor: Color(0xFF8BC34A),
);

/// Dark-mode drill feedback colors — slightly desaturated/lighter variants
/// that remain legible on dark surfaces.
const drillFeedbackThemeDark = DrillFeedbackTheme(
  correctArrowColor: Color(0xFF66DD66),
  siblingArrowColor: Color(0xFF6699FF),
  mistakeColor: Color(0xFFEE6666),
  perfectColor: Color(0xFF66BB6A),
  hesitationColor: Color(0xFFA5D64A),
);

/// Default fallback used when the extension is not present in the theme
/// (e.g. in tests that build a bare [MaterialApp] without theme extensions).
const drillFeedbackThemeDefault = drillFeedbackThemeLight;
