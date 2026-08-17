import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_theme.dart';

/// Stands in for a tab route, which the app builds as a cross-fading page of
/// its own rather than a [MaterialPageRoute]. A pushed page has to leave one of
/// these where it is too, and it reaches it by a different path in the
/// framework: the page below adopts the incoming page's delegated transition.
Route<void> _fadeRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) =>
        const Scaffold(key: Key('below'), body: SizedBox.expand()),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Pushes a page over [below] and stops halfway through the transition,
/// returning how far each page has been carried sideways.
Future<({double below, double above})> _midPush(
  WidgetTester tester, {
  required Size surface,
  Route<void> Function()? below,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.reset);

  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: GarageTheme.dark(),
      navigatorKey: navigator,
      home: const Scaffold(key: Key('below'), body: SizedBox.expand()),
    ),
  );

  if (below != null) {
    navigator.currentState!.push(below());
    await tester.pumpAndSettle();
  }

  navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) =>
          const Scaffold(key: Key('above'), body: SizedBox.expand()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));

  return (
    below: tester.getTopLeft(find.byKey(const Key('below')).last).dx,
    above: tester.getTopLeft(find.byKey(const Key('above'))).dx,
  );
}

/// The web build reports macOS in a Mac browser, which is where the sliding
/// sidebar was seen, and iOS is the phone whose push transition has to survive
/// the fix.
final _applePlatforms = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.iOS,
  TargetPlatform.macOS,
});

void main() {
  group('page transitions', () {
    testWidgets(
      'a pushed page slides in over a phone-width window',
      (tester) async {
        final offsets = await _midPush(tester, surface: const Size(400, 900));

        expect(offsets.above, greaterThan(0));
        expect(offsets.below, lessThan(0));
      },
      variant: _applePlatforms,
    );

    testWidgets(
      'a pushed page does not slide a desktop-width window',
      (tester) async {
        final offsets = await _midPush(tester, surface: const Size(1400, 900));

        // The sidebar is drawn inside every page, so a page that slides in
        // slides a sidebar in with it and drags the identical one behind it
        // out — which is what opening Statistics looked like.
        expect(offsets.above, 0);
        expect(offsets.below, 0);
      },
      variant: TargetPlatformVariant.all(),
    );

    testWidgets(
      'a pushed page leaves a tab page below it where it is on a desktop-width '
      'window',
      (tester) async {
        final offsets = await _midPush(
          tester,
          surface: const Size(1400, 900),
          below: _fadeRoute,
        );

        expect(offsets.above, 0);
        expect(offsets.below, 0);
      },
      variant: TargetPlatformVariant.all(),
    );

    testWidgets(
      'a tab page below a pushed page still slides off a phone-width window',
      (tester) async {
        final offsets = await _midPush(
          tester,
          surface: const Size(400, 900),
          below: _fadeRoute,
        );

        expect(offsets.above, greaterThan(0));
        expect(offsets.below, lessThan(0));
      },
      variant: _applePlatforms,
    );
  });
}
