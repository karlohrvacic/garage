import 'package:flutter/material.dart';

/// Design tokens bound verbatim from the design export's `css/tokens.css`
/// ("Neutral Modern"). This is the only file in the app permitted to contain
/// raw hex colour literals.
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
    bg: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    fg: Color(0xFF111111),
    muted: Color(0xFF6B6B6B),
    border: Color(0xFFE5E5E5),
    accent: Color(0xFF2F6FEB),
    accentOn: Color(0xFFFFFFFF),
    success: Color(0xFF17A34A),
    warn: Color(0xFFEAB308),
    danger: Color(0xFFDC2626),
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
