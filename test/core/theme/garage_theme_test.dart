import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/theme/garage_tokens.dart';

void main() {
  test('light theme carries the GarageTokens extension', () {
    final theme = GarageTheme.light();
    final tokens = theme.extension<GarageTokens>();

    expect(tokens, isNotNull);
    expect(tokens!.bg, const Color(0xFFF4F4F2));
    expect(tokens.surface, const Color(0xFFFFFFFF));
    expect(tokens.fg, const Color(0xFF16181B));
    expect(tokens.muted, const Color(0xFF62686F));
    expect(tokens.border, const Color(0xFFE2E4E6));
    expect(tokens.accent, const Color(0xFF9C6300));
    expect(tokens.accentOn, const Color(0xFFFFFFFF));
    expect(tokens.success, const Color(0xFF178A46));
    expect(tokens.warn, const Color(0xFFB58900));
    expect(tokens.danger, const Color(0xFFD3261B));
  });

  test('dark theme carries the dark GarageTokens extension', () {
    final theme = GarageTheme.dark();
    final tokens = theme.extension<GarageTokens>();

    expect(tokens, isNotNull);
    expect(tokens!.bg, const Color(0xFF0F1114));
    expect(tokens.surface, const Color(0xFF1A1D21));
    expect(tokens.fg, const Color(0xFFF2F3F0));
    expect(tokens.muted, const Color(0xFF8A9098));
    expect(tokens.border, const Color(0xFF262B31));
    expect(tokens.accent, const Color(0xFFFFB020));
    expect(tokens.accentOn, const Color(0xFF1A1400));
    expect(tokens.success, const Color(0xFF35C46B));
    expect(tokens.warn, const Color(0xFFFFC94D));
    expect(tokens.danger, const Color(0xFFFF4D3D));
  });

  test('labelSmall keeps the Inter family alongside the muted colour', () {
    final theme = GarageTheme.light();
    final labelSmall = theme.textTheme.labelSmall;

    expect(labelSmall, isNotNull);
    expect(labelSmall!.fontFamily, 'Inter');
    expect(labelSmall.color, const Color(0xFF62686F));
  });

  test('neutral color scheme roles are pinned to the token palette', () {
    final scheme = GarageTheme.light().colorScheme;

    expect(scheme.onSurface, const Color(0xFF16181B));
    expect(scheme.onSurfaceVariant, const Color(0xFF62686F));
    expect(scheme.outlineVariant, const Color(0xFFE2E4E6));
  });

  test('themes seed the Material color scheme from the amber accent', () {
    final light = GarageTheme.light();
    final dark = GarageTheme.dark();

    expect(light.colorScheme.brightness, Brightness.light);
    expect(light.colorScheme.primary, const Color(0xFF9C6300));
    expect(light.scaffoldBackgroundColor, const Color(0xFFF4F4F2));
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.colorScheme.primary, const Color(0xFFFFB020));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF0F1114));
  });

  testWidgets('context.tokens resolves the extension', (tester) async {
    late GarageTokens resolved;

    await tester.pumpWidget(
      MaterialApp(
        theme: GarageTheme.light(),
        home: Builder(
          builder: (context) {
            resolved = context.tokens;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved.accent, const Color(0xFF9C6300));
  });
}
