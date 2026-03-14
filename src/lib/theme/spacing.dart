import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Vertical spacing between a screen's app bar / banner and its first content
/// element. See design/ui-guidelines.md "Banner gap" rule.
const double kBannerGap = 8;

/// [kBannerGap] as top-only EdgeInsets, for use with [Padding] widgets.
const EdgeInsets kBannerGapInsets = EdgeInsets.only(top: kBannerGap);

/// Top gap between the app-bar / banner and the board frame.
/// Applies unconditionally so the board sits at a fixed distance from
/// whatever element precedes it (app bar or display-name banner).
/// Currently equal to [kBannerGap] (8dp) -- change independently if needed.
const double kBoardFrameTopGap = kBannerGap; // 8dp -- same value, explicit name

/// [kBoardFrameTopGap] as top-only EdgeInsets, for use with [Padding] widgets.
const EdgeInsets kBoardFrameTopInsets = EdgeInsets.only(top: kBoardFrameTopGap);

/// Minimal horizontal margin on each side of the board on mobile.
/// On narrow screens the board width is `screenWidth - 2 * kBoardHorizontalInset`;
/// [kMaxBoardSize] only kicks in on wide viewports.
const double kBoardHorizontalInset = 4.0;

/// [kBoardHorizontalInset] as symmetric horizontal EdgeInsets.
const EdgeInsets kBoardHorizontalInsets =
    EdgeInsets.symmetric(horizontal: kBoardHorizontalInset);

/// Maximum board dimension (width and height). Acts as a desktop/tablet safety
/// cap to prevent absurdly large boards on wide screens. On mobile the board is
/// constrained by `screenWidth - 2 * kBoardHorizontalInset` which is smaller
/// than this value.
const double kMaxBoardSize = 600;

/// Fixed height reserved for the line-label area below the board.
/// Sized to fit one line of titleMedium text (24dp) + 8dp vertical padding.
const double kLineLabelHeight = 32;

/// Left inset for the line label (~16dp visual alignment with board edge).
const double kLineLabelLeftInset = 16;

/// Maximum fraction of screen height the board may consume on narrow layouts.
/// Applied uniformly to all screens via [boardSizeForNarrow] so boards remain
/// identical at every viewport. At 0.5, a standard 844dp phone is unaffected
/// (422 > 382), but short/landscape viewports get a height cap.
const double kBoardMaxHeightFraction = 0.5;

// ---------------------------------------------------------------------------
// Responsive board-sizing helpers
// ---------------------------------------------------------------------------

/// Returns the board size for a narrow layout given [availableWidth].
///
/// The board fills the available width minus a small margin on each side,
/// clamped to [kMaxBoardSize].
double boardSizeForWidth(double availableWidth) {
  return (availableWidth - 2 * kBoardHorizontalInset).clamp(0.0, kMaxBoardSize);
}

/// Returns the board size for a wide (side-panel) layout.
///
/// The board is sized as [widthFraction] of the available width, but never
/// taller than the available height, and never larger than [kMaxBoardSize].
/// This centralises the wide-layout board-size calculation so all screens use
/// the same formula and remain consistent with each other.
double boardSizeForConstraints(
  BoxConstraints constraints, {
  double widthFraction = 0.5,
}) {
  return math
      .min(constraints.maxHeight, constraints.maxWidth * widthFraction)
      .clamp(0.0, kMaxBoardSize);
}

/// Returns the board size for a narrow layout with an additional height guard.
///
/// Like [boardSizeForWidth], but the result is also clamped to
/// `availableHeight * maxHeightFraction`. This lets callers like the Browser
/// prevent the board from crowding out controls on short/landscape viewports.
/// Pass `maxHeightFraction: 1.0` (the default) to effectively disable the
/// height clamp.
double boardSizeForNarrow(
  double availableWidth,
  double availableHeight, {
  double maxHeightFraction = 1.0,
}) {
  return (availableWidth - 2 * kBoardHorizontalInset)
      .clamp(0.0, math.min(kMaxBoardSize, availableHeight * maxHeightFraction));
}
