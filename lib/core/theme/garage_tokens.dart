import 'package:flutter/material.dart';

/// Design tokens for the "Night Shift" identity (dark-first instrument
/// cluster; see docs/superpowers/specs/2026-07-28-night-shift-visual-identity-design.md).
/// This is the only file in the app permitted to contain raw hex colour
/// literals.
@immutable
class GarageTokens extends ThemeExtension<GarageTokens> {
  const GarageTokens({
    required this.bg,
    required this.surface,
    required this.fg,
    required this.muted,
    required this.border,
    required this.accent,
    required this.accentOn,
    required this.success,
    required this.warn,
    required this.danger,
  });

  final Color bg;
  final Color surface;
  final Color fg;
  final Color muted;
  final Color border;
  final Color accent;
  final Color accentOn;
  final Color success;
  final Color warn;
  final Color danger;

  static const GarageTokens light = GarageTokens(
    bg: Color(0xFFF4F4F2),
    surface: Color(0xFFFFFFFF),
    fg: Color(0xFF16181B),
    muted: Color(0xFF62686F),
    border: Color(0xFFE2E4E6),
    accent: Color(0xFF9C6300),
    accentOn: Color(0xFFFFFFFF),
    success: Color(0xFF178A46),
    warn: Color(0xFFB58900),
    danger: Color(0xFFD3261B),
  );

  static const GarageTokens dark = GarageTokens(
    bg: Color(0xFF0F1114),
    surface: Color(0xFF1A1D21),
    fg: Color(0xFFF2F3F0),
    muted: Color(0xFF8A9098),
    border: Color(0xFF262B31),
    accent: Color(0xFFFFB020),
    accentOn: Color(0xFF1A1400),
    success: Color(0xFF35C46B),
    warn: Color(0xFFFFC94D),
    danger: Color(0xFFFF4D3D),
  );

  // Spacing scale.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space12 = 48;
  static const double space20 = 80;

  // Radius scale.
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 9999;

  // Motion.
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 200);
  static const Curve easeStandard = Cubic(0.2, 0, 0, 1);

  @override
  GarageTokens copyWith({
    Color? bg,
    Color? surface,
    Color? fg,
    Color? muted,
    Color? border,
    Color? accent,
    Color? accentOn,
    Color? success,
    Color? warn,
    Color? danger,
  }) {
    return GarageTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      fg: fg ?? this.fg,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentOn: accentOn ?? this.accentOn,
      success: success ?? this.success,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
    );
  }

  @override
  GarageTokens lerp(ThemeExtension<GarageTokens>? other, double t) {
    if (other is! GarageTokens) {
      return this;
    }
    return GarageTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentOn: Color.lerp(accentOn, other.accentOn, t)!,
      success: Color.lerp(success, other.success, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
