import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/theme/garage_tokens.dart';

void main() {
  test('light theme carries the GarageTokens extension', () {
    final theme = GarageTheme.light();
    final tokens = theme.extension<GarageTokens>();

    expect(tokens, isNotNull);
    expect(tokens!.bg, const Color(0xFFFAFAFA));
    expect(tokens.surface, const Color(0xFFFFFFFF));
    expect(tokens.fg, const Color(0xFF111111));
    expect(tokens.muted, const Color(0xFF6B6B6B));
    expect(tokens.border, const Color(0xFFE5E5E5));
    expect(tokens.accent, const Color(0xFF2F6FEB));
    expect(tokens.accentOn, const Color(0xFFFFFFFF));
    expect(tokens.success, const Color(0xFF17A34A));
    expect(tokens.warn, const Color(0xFFEAB308));
    expect(tokens.danger, const Color(0xFFDC2626));
  });

  test('labelSmall keeps the Inter family alongside the muted colour', () {
    final theme = GarageTheme.light();
    final labelSmall = theme.textTheme.labelSmall;

    expect(labelSmall, isNotNull);
    expect(labelSmall!.fontFamily, 'Inter');
    expect(labelSmall.color, const Color(0xFF6B6B6B));
  });

  test('neutral color scheme roles are pinned to the token palette', () {
    final scheme = GarageTheme.light().colorScheme;

    expect(scheme.onSurface, const Color(0xFF111111));
    expect(scheme.onSurfaceVariant, const Color(0xFF6B6B6B));
    expect(scheme.outlineVariant, const Color(0xFFE5E5E5));
  });

  test('light theme seeds the Material color scheme from the cobalt accent', () {
    final theme = GarageTheme.light();

    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, const Color(0xFF2F6FEB));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAFA));
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

    expect(resolved.accent, const Color(0xFF2F6FEB));
  });
}
