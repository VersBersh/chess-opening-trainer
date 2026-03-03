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

/// Fixed height reserved for the line-label area below the board.
/// Sized to fit one line of titleMedium text (24dp) + 8dp vertical padding.
const double kLineLabelHeight = 32;

/// Left inset for the line label (~16dp visual alignment with board edge).
const double kLineLabelLeftInset = 16;
