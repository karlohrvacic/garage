import 'package:flutter/material.dart';

import '../widgets/adaptive.dart';
import 'garage_tokens.dart';

/// Builds Material themes from the design tokens.
///
/// Type roles follow the Night Shift identity: Inter for prose, a monospace
/// face with tabular figures for every number the user compares across rows,
/// and uppercase mono eyebrows for section labels.
abstract final class GarageTheme {
  static ThemeData light() => _build(GarageTokens.light, Brightness.light);

  static ThemeData dark() => _build(GarageTokens.dark, Brightness.dark);

  static ThemeData _build(GarageTokens tokens, Brightness brightness) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: tokens.accent,
          brightness: brightness,
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

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      pageTransitionsTheme: _pageTransitions,
    );

    return base.copyWith(
      scaffoldBackgroundColor: tokens.bg,
      extensions: <ThemeExtension<dynamic>>[tokens],
      textTheme: _textTheme(base.textTheme, tokens),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.bg,
        foregroundColor: tokens.fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
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
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: tokens.muted),
        labelStyle: TextStyle(color: tokens.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          borderSide: BorderSide(color: tokens.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          borderSide: BorderSide(color: tokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          borderSide: BorderSide(color: tokens.danger, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentOn,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.fg,
          side: BorderSide(color: tokens.border),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: tokens.accent),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, GarageTokens tokens) {
    final applied = base.apply(
      fontFamily: 'Inter',
      bodyColor: tokens.fg,
      displayColor: tokens.fg,
    );

    TextStyle? tighten(TextStyle? style) =>
        style?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5);

    return applied.copyWith(
      headlineLarge: tighten(applied.headlineLarge),
      headlineMedium: tighten(applied.headlineMedium),
      headlineSmall: tighten(applied.headlineSmall),
      titleLarge: tighten(applied.titleLarge),
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

  /// Categorical palette for charts, derived from the token colours so no
  /// raw hex lives outside garage_tokens.dart. Ordered for adjacent-slice
  /// contrast; index wraps for more series than colours.
  static List<Color> chartPalette(GarageTokens tokens) {
    Color dim(Color color) => Color.lerp(color, tokens.bg, 0.45)!;
    return [
      tokens.accent,
      tokens.success,
      tokens.danger,
      dim(tokens.accent),
      tokens.muted,
      dim(tokens.success),
      tokens.warn,
      dim(tokens.danger),
      tokens.fg,
      dim(tokens.muted),
    ];
  }

  /// Input style for numeric form fields: what the user types lines up with
  /// what the tables render.
  static TextStyle numericField(BuildContext context) =>
      numeric(Theme.of(context).textTheme.bodyLarge!);

  /// Uppercase mono label for card headers and section eyebrows. Callers
  /// render the text with `.toUpperCase()`.
  static TextStyle eyebrow(BuildContext context) {
    final tokens = context.tokens;
    final base = Theme.of(context).textTheme.labelSmall!;
    return base.copyWith(
      fontFamily: 'JetBrainsMono',
      color: tokens.muted,
      letterSpacing: 1.5,
    );
  }
}

/// Every platform's default transition, each wrapped so it only applies where
/// it makes sense. Derived from Flutter's own defaults rather than listed by
/// hand, so a platform whose default changes keeps its phone behaviour.
final _pageTransitions = PageTransitionsTheme(
  builders: {
    for (final entry in const PageTransitionsTheme().builders.entries)
      entry.key: _WindowAwarePageTransitions(entry.value),
  },
);

/// Picks a route transition by window size instead of by platform.
///
/// Above the wide breakpoint the sidebar is drawn *inside* every page rather
/// than around them, so the platform's push transition carries it: opening
/// Statistics slid the whole window — sidebar included — in from the right and
/// dragged the sidebar behind it out to the left. Wide windows therefore
/// cross-fade, which leaves the two identical sidebars indistinguishable and
/// animates only the part of the window that actually changed. It is also what
/// switching tabs already does, so a desktop window animates one way throughout.
///
/// Below the breakpoint a push really is a push onto a full-screen page, so the
/// platform's own transition is kept, along with the back gesture that comes
/// with it.
class _WindowAwarePageTransitions extends PageTransitionsBuilder {
  _WindowAwarePageTransitions(this.narrow);

  /// What a phone-sized window falls back to.
  final PageTransitionsBuilder narrow;

  @override
  Duration get transitionDuration => narrow.transitionDuration;

  @override
  Duration get reverseTransitionDuration => narrow.reverseTransitionDuration;

  /// How the page *below* is animated off, when it is a kind of page that does
  /// not already know how to sync with this one. A method rather than a closure
  /// so repeated reads give the framework the same function to compare.
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _animateBelowOff;

  Widget? _animateBelowOff(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    // Null hands the page below back to its own transition, which on a wide
    // window is the cross-fade below: it stays where it is.
    if (GarageBreakpoints.isWide(context)) {
      return null;
    }
    return narrow.delegatedTransition?.call(
      context,
      animation,
      secondaryAnimation,
      allowSnapshotting,
      child,
    );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!GarageBreakpoints.isWide(context)) {
      return narrow.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    // Deliberately blind to [secondaryAnimation]: a page that something else
    // was pushed over keeps its sidebar exactly where the new page draws one.
    return FadeTransition(
      opacity: CurveTween(curve: GarageTokens.easeStandard).animate(animation),
      child: child,
    );
  }
}

extension GarageThemeContext on BuildContext {
  /// The design tokens for the active theme. Falls back to the light tokens
  /// when the extension is absent — the app always registers it via
  /// [GarageTheme.light] or [GarageTheme.dark], but a widget hosted in a bare
  /// `MaterialApp` (e.g. a widget test) should degrade gracefully rather than
  /// crash on a null check.
  GarageTokens get tokens =>
      Theme.of(this).extension<GarageTokens>() ?? GarageTokens.light;
}
