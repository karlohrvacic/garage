import 'package:flutter/material.dart';

import 'garage_tokens.dart';

/// Builds Material themes from the design tokens.
///
/// Type roles follow the design export: Inter for prose, a monospace face with
/// tabular figures for every number the user compares across rows.
abstract final class GarageTheme {
  static ThemeData light() {
    const tokens = GarageTokens.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: tokens.accent,
      onPrimary: tokens.accentOn,
      surface: tokens.surface,
      onSurface: tokens.fg,
      onSurfaceVariant: tokens.muted,
      error: tokens.danger,
      outline: tokens.border,
      outlineVariant: tokens.border,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      scaffoldBackgroundColor: tokens.bg,
      extensions: const <ThemeExtension<dynamic>>[tokens],
      textTheme: _textTheme(base.textTheme, tokens),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
          side: BorderSide(color: tokens.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          borderSide: BorderSide(color: tokens.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, GarageTokens tokens) {
    final applied = base.apply(
      fontFamily: 'Inter',
      bodyColor: tokens.fg,
      displayColor: tokens.fg,
    );

    return applied.copyWith(
      labelSmall: applied.labelSmall?.copyWith(color: tokens.muted),
    );
  }

  /// Style for figures the user compares down a column: monospace, tabular.
  static TextStyle numeric(TextStyle base) {
    return base.copyWith(
      fontFamily: 'JetBrainsMono',
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }
}

extension GarageThemeContext on BuildContext {
  /// The design tokens for the active theme. Falls back to the light tokens
  /// when the extension is absent — the app always registers it via
  /// [GarageTheme.light], but a widget hosted in a bare `MaterialApp` (e.g. a
  /// widget test) should degrade gracefully rather than crash on a null check.
  GarageTokens get tokens =>
      Theme.of(this).extension<GarageTokens>() ?? GarageTokens.light;
}
